"""Run the strategy comparison on Coin Metrics daily data.

Usage:
    python backtest/run_backtest.py [--asset btc|eth] [--cost 0.005]

Produces a comparison table over the full period, plus an in-sample /
out-of-sample split (out-of-sample = 2022 onwards, which contains the
2022 bear market, the 2023 chop, and the 2024-2026 cycle) so the chosen
strategy is validated on data it was not selected on.
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import engine  # noqa: E402
import strategies  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
START = "2015-01-01"   # skip the thin pre-2015 market
OOS_START = "2022-01-01"


def load_close(asset: str) -> pd.Series:
    df = pd.read_csv(ROOT / "data" / f"{asset}.csv", usecols=["time", "PriceUSD"],
                     parse_dates=["time"])
    close = df.set_index("time")["PriceUSD"].dropna()
    return close.loc[START:]


def table(close: pd.Series, cost: float) -> pd.DataFrame:
    rows = []
    for name, fn in strategies.STRATEGIES.items():
        pos = fn(close)
        rows.append(engine.run(name, close, pos, cost).row())
    return pd.DataFrame(rows).set_index("strategy")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", default="btc", choices=["btc", "eth"])
    ap.add_argument("--cost", type=float, default=0.005,
                    help="fee+slippage per side (0.005 = 0.5%%)")
    args = ap.parse_args()

    close = load_close(args.asset)
    print(f"\n=== {args.asset.upper()} full period "
          f"{close.index[0].date()} -> {close.index[-1].date()}, "
          f"cost/side {args.cost:.3%} ===")
    full = table(close, args.cost)
    print(full.to_string())

    # Signals for the OOS window are computed on the full series (indicators
    # need warm-up history) but performance is measured on 2022+ only.
    print(f"\n=== {args.asset.upper()} out-of-sample {OOS_START} onwards ===")
    rows = []
    for name, fn in strategies.STRATEGIES.items():
        pos = fn(close)
        oos_close = close.loc[OOS_START:]
        oos_pos = pos.loc[OOS_START:]
        rows.append(engine.run(name, oos_close, oos_pos, args.cost).row())
    oos = pd.DataFrame(rows).set_index("strategy")
    print(oos.to_string())

    out = ROOT / "backtest" / "results" / f"{args.asset}_comparison.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as f:
        f.write(f"# {args.asset.upper()} backtest ({close.index[0].date()} to "
                f"{close.index[-1].date()}, cost/side {args.cost:.3%})\n\n")
        f.write("## Full period\n\n" + full.to_markdown() + "\n\n")
        f.write(f"## Out-of-sample ({OOS_START} onwards)\n\n" + oos.to_markdown() + "\n")
    print(f"\nWritten to {out}")


if __name__ == "__main__":
    main()
