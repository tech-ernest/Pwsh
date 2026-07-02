"""Refresh the bundled Coin Metrics community daily datasets.

Source: https://github.com/coinmetrics/data (CC-BY-4.0-style community data,
updated daily). We use the PriceUSD column (Coin Metrics reference rate at
00:00 UTC) as the daily close for backtesting.
"""

import urllib.request
from pathlib import Path

ASSETS = ["btc", "eth"]
BASE = "https://raw.githubusercontent.com/coinmetrics/data/master/csv/{}.csv"
HERE = Path(__file__).resolve().parent


def main() -> None:
    for asset in ASSETS:
        url = BASE.format(asset)
        dest = HERE / f"{asset}.csv"
        print(f"downloading {url} -> {dest}")
        urllib.request.urlretrieve(url, dest)
        print(f"  {dest.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
