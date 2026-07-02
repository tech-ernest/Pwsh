"""Market data layer.

The T212 public API has no price-history endpoint, so signals are computed
from external data. Primary provider is Yahoo Finance (via yfinance, which
handles dividend-adjusted closes — required because the strategy compares
total returns). Stooq is the zero-dependency fallback (unadjusted closes for
ETCs, close enough for accumulating UCITS funds where price == total return).
"""

from __future__ import annotations

import io
import logging
import time

import pandas as pd
import requests

log = logging.getLogger("trendpilot.data")

MIN_YEARS = 3  # 12m momentum + 10m SMA need ~2y; fetch extra margin


class DataError(RuntimeError):
    pass


def fetch_history(symbols: list[str], years: int = MIN_YEARS) -> pd.DataFrame:
    """Daily adjusted closes, columns keyed by symbol."""
    try:
        return _fetch_yahoo(symbols, years)
    except Exception as exc:  # noqa: BLE001 - fall through to backup provider
        log.warning("yahoo fetch failed (%s), falling back to stooq", exc)
    return _fetch_stooq(symbols, years)


def _fetch_yahoo(symbols: list[str], years: int) -> pd.DataFrame:
    import yfinance as yf

    frame = yf.download(
        symbols,
        period=f"{years}y",
        interval="1d",
        auto_adjust=True,
        progress=False,
        group_by="column",
    )
    closes = frame["Close"] if isinstance(frame.columns, pd.MultiIndex) else frame[["Close"]]
    if not isinstance(frame.columns, pd.MultiIndex):
        closes = closes.rename(columns={"Close": symbols[0]})
    closes = closes.dropna(how="all")
    missing = [s for s in symbols if s not in closes or closes[s].dropna().empty]
    if missing:
        raise DataError(f"yahoo returned no data for {missing}")
    return closes[symbols]


def _stooq_symbol(symbol: str) -> str:
    # Yahoo suffix ".L" (London) -> stooq ".UK"; bare US symbols -> ".US"
    if symbol.upper().endswith(".L"):
        return symbol.upper().replace(".L", ".UK")
    if "." not in symbol:
        return f"{symbol.upper()}.US"
    return symbol.upper()


def _fetch_stooq(symbols: list[str], years: int) -> pd.DataFrame:
    out = {}
    start = (pd.Timestamp.now() - pd.DateOffset(years=years)).strftime("%Y%m%d")
    for sym in symbols:
        url = (
            "https://stooq.com/q/d/l/"
            f"?s={_stooq_symbol(sym).lower()}&i=d&d1={start}&d2={pd.Timestamp.now():%Y%m%d}"
        )
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        table = pd.read_csv(io.StringIO(resp.text), parse_dates=["Date"])
        if table.empty or "Close" not in table:
            raise DataError(f"stooq returned no data for {sym}")
        out[sym] = table.set_index("Date")["Close"]
        time.sleep(1.0)  # be polite, avoid stooq rate limiting
    return pd.DataFrame(out).dropna(how="all")


def validate_history(
    closes: pd.DataFrame, max_daily_move: float, max_age_days: int
) -> None:
    """Guardrails against acting on bad or stale data."""
    age = (pd.Timestamp.now().normalize() - closes.index[-1].normalize()).days
    if age > max_age_days:
        raise DataError(
            f"price data is {age} days old (limit {max_age_days}) — refusing to trade"
        )
    worst = closes.pct_change().abs().iloc[-5:].max().max()
    if worst > max_daily_move:
        raise DataError(
            f"suspicious {worst:.0%} daily move in recent data — refusing to trade"
        )
