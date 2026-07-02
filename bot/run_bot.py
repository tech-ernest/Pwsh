"""Daily trading bot entry point.

Run once per day shortly after 00:00 UTC (the daily candle close), e.g. via
cron:

    5 0 * * * cd /path/to/repo && python3 bot/run_bot.py >> bot/bot.log 2>&1

Or keep a process alive with `--loop`, which sleeps until the next close.

Modes (config.yaml):
- paper (default): simulated fills at the latest daily close, real market
  data, state in bot/state.json. No API keys needed.
- live: real market orders on Kraken. Needs KRAKEN_API_KEY /
  KRAKEN_API_SECRET env vars AND --i-understand-live on the command line.

`--offline` evaluates the signal against the bundled Coin Metrics CSV
instead of calling Kraken — useful for tests and sandboxes with no
exchange access (paper mode only).
"""

import argparse
import json
import sys
import time
from pathlib import Path

import pandas as pd
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from exchange import LiveBroker, PaperBroker, fetch_daily_closes, make_kraken  # noqa: E402
from strategy import StrategyParams, target_position  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def load_config(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def offline_closes(limit: int) -> pd.Series:
    df = pd.read_csv(ROOT / "data" / "btc.csv", usecols=["time", "PriceUSD"],
                     parse_dates=["time"])
    return df.set_index("time")["PriceUSD"].dropna().iloc[-limit:]


def risk_state(path: Path, starting: float) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return {"peak_equity": starting, "halted": False}


def run_once(cfg: dict, offline: bool, live_ack: bool) -> None:
    params = StrategyParams(sma_window=cfg["strategy"]["sma_window"],
                            band=cfg["strategy"]["band"])
    mode = cfg.get("mode", "paper")
    pair = cfg.get("pair", "BTC/GBP")

    if mode == "live" and not live_ack:
        raise SystemExit("refusing live mode without --i-understand-live")

    if offline:
        if mode == "live":
            raise SystemExit("--offline only works in paper mode")
        closes = offline_closes(params.sma_window + 20)
    else:
        exchange = make_kraken(need_keys=(mode == "live"))
        closes = fetch_daily_closes(exchange, pair, limit=params.sma_window + 20)
    price = float(closes.iloc[-1])

    if mode == "paper":
        broker = PaperBroker(ROOT / cfg["state_file"],
                             starting_gbp=cfg["capital_gbp"],
                             fee=cfg["risk"]["assumed_fee"])
        state = broker.state
    else:
        broker = LiveBroker(exchange, pair, cfg["risk"]["min_order_gbp"])
        rs_path = ROOT / cfg["state_file"]
        state = risk_state(rs_path, cfg["capital_gbp"])

    equity = broker.equity(price)
    state["peak_equity"] = max(state.get("peak_equity", equity), equity)
    drawdown = equity / state["peak_equity"] - 1.0

    log = {"utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "mode": mode, "close": round(price, 2), "equity_gbp": round(equity, 2),
           "drawdown": round(drawdown, 4)}

    # Kill switch: if the account draws down past the configured limit,
    # liquidate and refuse to trade again until a human deletes the flag.
    if state.get("halted"):
        log["action"] = "halted (manual reset required: remove 'halted' from state file)"
        print(json.dumps(log)); _save(mode, broker, state, cfg); return
    if drawdown < -cfg["risk"]["max_drawdown_stop"]:
        current = broker.position(price) if mode == "live" else broker.position()
        if current == 1:
            broker.sell_all(price)
        state["halted"] = True
        log["action"] = f"KILL SWITCH: drawdown {drawdown:.1%}, liquidated and halted"
        print(json.dumps(log)); _save(mode, broker, state, cfg); return

    current = broker.position(price) if mode == "live" else broker.position()
    target = target_position(closes, current, params)

    if target == current:
        log["action"] = f"hold (position={'long' if current else 'flat'})"
    elif target == 1:
        broker.buy_all(price)
        log["action"] = f"BUY at ~{price:.2f}"
    else:
        broker.sell_all(price)
        log["action"] = f"SELL at ~{price:.2f}"

    print(json.dumps(log))
    _save(mode, broker, state, cfg)


def _save(mode: str, broker, state: dict, cfg: dict) -> None:
    if mode == "paper":
        broker.save()
    else:
        (ROOT / cfg["state_file"]).write_text(json.dumps(state, indent=2))


def seconds_to_next_close() -> float:
    now = time.time()
    day = 86400
    return day - (now % day) + 300  # 5 min after 00:00 UTC


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=str(ROOT / "config.yaml"))
    ap.add_argument("--loop", action="store_true", help="run daily forever")
    ap.add_argument("--offline", action="store_true",
                    help="use bundled CSV data instead of Kraken (paper only)")
    ap.add_argument("--i-understand-live", action="store_true",
                    help="required acknowledgement for live trading")
    args = ap.parse_args()

    cfg = load_config(Path(args.config))
    while True:
        run_once(cfg, offline=args.offline, live_ack=args.i_understand_live)
        if not args.loop:
            break
        time.sleep(seconds_to_next_close())


if __name__ == "__main__":
    main()
