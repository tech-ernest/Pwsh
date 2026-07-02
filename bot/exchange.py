"""Exchange access: Kraken via ccxt, plus a paper-trading broker.

Live mode needs KRAKEN_API_KEY / KRAKEN_API_SECRET in the environment and
`mode: live` in config.yaml. Everything else (including market data for
paper mode) uses Kraken's public endpoints, no keys required.
"""

import json
import os
import time
from pathlib import Path

import ccxt
import pandas as pd


def make_kraken(need_keys: bool) -> ccxt.kraken:
    params = {"enableRateLimit": True}
    if need_keys:
        key = os.environ.get("KRAKEN_API_KEY")
        secret = os.environ.get("KRAKEN_API_SECRET")
        if not key or not secret:
            raise RuntimeError(
                "live mode needs KRAKEN_API_KEY and KRAKEN_API_SECRET env vars")
        params.update({"apiKey": key, "secret": secret})
    return ccxt.kraken(params)


def fetch_daily_closes(exchange: ccxt.kraken, pair: str, limit: int = 220) -> pd.Series:
    """Fetch completed daily candles (the still-forming candle is dropped)."""
    ohlcv = exchange.fetch_ohlcv(pair, timeframe="1d", limit=limit + 1)
    df = pd.DataFrame(ohlcv, columns=["ts", "open", "high", "low", "close", "vol"])
    df["ts"] = pd.to_datetime(df["ts"], unit="ms", utc=True)
    df = df.set_index("ts")
    # last row is the current, incomplete day: never trade on it
    if len(df) and df.index[-1].date() >= pd.Timestamp.now(tz="UTC").date():
        df = df.iloc[:-1]
    return df["close"]


class PaperBroker:
    """Simulates fills at the latest close, charging the configured fee.

    State (GBP cash, BTC held, trade log) persists to a JSON file so the
    paper account behaves like a real one across daily runs.
    """

    def __init__(self, state_file: Path, starting_gbp: float, fee: float = 0.0040):
        self.state_file = Path(state_file)
        self.fee = fee
        if self.state_file.exists():
            self.state = json.loads(self.state_file.read_text())
        else:
            self.state = {"gbp": starting_gbp, "btc": 0.0, "peak_equity": starting_gbp,
                          "halted": False, "trades": []}

    def save(self) -> None:
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        self.state_file.write_text(json.dumps(self.state, indent=2))

    def equity(self, price: float) -> float:
        return self.state["gbp"] + self.state["btc"] * price

    def position(self) -> int:
        return 1 if self.state["btc"] > 0 else 0

    def buy_all(self, price: float) -> None:
        gbp = self.state["gbp"]
        btc = gbp / price * (1 - self.fee)
        self.state.update({"gbp": 0.0, "btc": btc})
        self._log("buy", price, gbp)

    def sell_all(self, price: float) -> None:
        btc = self.state["btc"]
        gbp = btc * price * (1 - self.fee)
        self.state.update({"gbp": gbp, "btc": 0.0})
        self._log("sell", price, gbp)

    def _log(self, side: str, price: float, notional_gbp: float) -> None:
        self.state["trades"].append({
            "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "side": side, "price": price, "notional_gbp": round(notional_gbp, 2),
        })


class LiveBroker:
    """Real orders on Kraken spot. Market orders, full-balance flips."""

    def __init__(self, exchange: ccxt.kraken, pair: str, min_order_gbp: float):
        self.x = exchange
        self.pair = pair
        self.base, self.quote = pair.split("/")
        self.min_order_gbp = min_order_gbp

    def balances(self) -> tuple[float, float]:
        bal = self.x.fetch_balance()
        return (float(bal.get(self.quote, {}).get("free", 0) or 0),
                float(bal.get(self.base, {}).get("free", 0) or 0))

    def position(self, price: float) -> int:
        gbp, btc = self.balances()
        # treat sub-minimum BTC as dust, not a position
        return 1 if btc * price >= self.min_order_gbp else 0

    def equity(self, price: float) -> float:
        gbp, btc = self.balances()
        return gbp + btc * price

    def buy_all(self, price: float) -> dict:
        gbp, _ = self.balances()
        if gbp < self.min_order_gbp:
            raise RuntimeError(f"GBP balance {gbp:.2f} below minimum order")
        amount = self.x.amount_to_precision(self.pair, gbp / price * 0.998)
        return self.x.create_market_buy_order(self.pair, amount)

    def sell_all(self, price: float) -> dict:
        _, btc = self.balances()
        if btc * price < self.min_order_gbp:
            raise RuntimeError(f"BTC balance worth {btc * price:.2f} below minimum order")
        amount = self.x.amount_to_precision(self.pair, btc)
        return self.x.create_market_sell_order(self.pair, amount)
