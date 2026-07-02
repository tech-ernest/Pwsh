"""Production strategy: 200-day SMA trend filter with a hysteresis band.

Selected by the backtest in backtest/ (see RESEARCH.md for the full
analysis). Long-only spot, position is either 100% BTC or 100% GBP.

Rules, evaluated once per day on the daily close:
- ENTER (go long)  when close > SMA200 * (1 + band)
- EXIT  (go flat)  when close < SMA200 * (1 - band)
- otherwise keep the current position (the band suppresses whipsaws,
  which matters because every flip costs ~0.5% in fees + slippage).
"""

from dataclasses import dataclass

import pandas as pd


@dataclass
class StrategyParams:
    sma_window: int = 200
    band: float = 0.02


def target_position(closes: pd.Series, current_position: int,
                    params: StrategyParams = StrategyParams()) -> int:
    """Return the desired position (1 = long BTC, 0 = in GBP).

    `closes` must be a series of daily closes ending with the most recent
    *completed* daily candle, at least `sma_window` long.
    """
    if len(closes) < params.sma_window:
        raise ValueError(
            f"need at least {params.sma_window} daily closes, got {len(closes)}")
    sma = closes.rolling(params.sma_window).mean().iloc[-1]
    close = float(closes.iloc[-1])
    if close > sma * (1 + params.band):
        return 1
    if close < sma * (1 - params.band):
        return 0
    return current_position
