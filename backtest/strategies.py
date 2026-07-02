"""Candidate strategy signal generators.

Every strategy is LONG-ONLY SPOT (position in {0, 1}) because UK retail
traders cannot legally access crypto derivatives (FCA ban, Jan 2021), so
shorting and leverage are off the table.

Each function takes a pandas Series of daily closes and returns a Series of
desired positions (0 = cash, 1 = fully invested), indexed like the input.
Signals are computed on the close of day t; the backtest engine applies them
to returns from day t+1, so there is no look-ahead.
"""

import numpy as np
import pandas as pd


def buy_and_hold(close: pd.Series) -> pd.Series:
    """Benchmark: always fully invested."""
    return pd.Series(1.0, index=close.index)


def sma_filter(close: pd.Series, window: int = 200) -> pd.Series:
    """Long when price is above its N-day simple moving average, else cash."""
    sma = close.rolling(window).mean()
    return (close > sma).astype(float)


def sma_band(close: pd.Series, window: int = 200, band: float = 0.02) -> pd.Series:
    """SELECTED PRODUCTION STRATEGY (see RESEARCH.md): SMA filter with a
    hysteresis band. Enter above SMA*(1+band), exit below SMA*(1-band),
    hold in between. Mirrors bot/strategy.py (consistency is unit-tested)."""
    sma = close.rolling(window).mean()
    pos = np.full(len(close), np.nan)
    pos[close.values > (sma * (1 + band)).values] = 1.0
    pos[close.values < (sma * (1 - band)).values] = 0.0
    return pd.Series(pos, index=close.index).ffill().fillna(0.0)


def ema_cross(close: pd.Series, fast: int = 20, slow: int = 100) -> pd.Series:
    """Long when the fast EMA is above the slow EMA, else cash."""
    ema_fast = close.ewm(span=fast, adjust=False).mean()
    ema_slow = close.ewm(span=slow, adjust=False).mean()
    return (ema_fast > ema_slow).astype(float)


def donchian(close: pd.Series, entry: int = 40, exit_: int = 20) -> pd.Series:
    """Breakout: enter on a new `entry`-day closing high, exit on a new
    `exit_`-day closing low. Close-based variant of the turtle system."""
    upper = close.shift(1).rolling(entry).max()
    lower = close.shift(1).rolling(exit_).min()
    pos = np.full(len(close), np.nan)
    pos[close.values > upper.values] = 1.0
    pos[close.values < lower.values] = 0.0
    out = pd.Series(pos, index=close.index).ffill().fillna(0.0)
    return out


def ts_momentum(close: pd.Series, lookback: int = 90) -> pd.Series:
    """Time-series momentum: long when the trailing N-day return is positive."""
    return (close > close.shift(lookback)).astype(float)


def rsi_mean_reversion(close: pd.Series, period: int = 14,
                       buy_below: float = 30.0, sell_above: float = 55.0) -> pd.Series:
    """Mean reversion: buy when RSI drops below `buy_below`, sell when it
    recovers above `sell_above`. Included as a fee-sensitivity contrast."""
    delta = close.diff()
    gain = delta.clip(lower=0).ewm(alpha=1 / period, adjust=False).mean()
    loss = (-delta.clip(upper=0)).ewm(alpha=1 / period, adjust=False).mean()
    rs = gain / loss.replace(0, np.nan)
    rsi = 100 - 100 / (1 + rs)
    pos = np.full(len(close), np.nan)
    pos[rsi.values < buy_below] = 1.0
    pos[rsi.values > sell_above] = 0.0
    return pd.Series(pos, index=close.index).ffill().fillna(0.0)


# Registry used by the backtest runner. Parameters are standard textbook
# values on purpose — heavy per-asset optimisation on a single history is
# how you manufacture an overfit "profitable" backtest.
STRATEGIES = {
    "buy_and_hold": lambda c: buy_and_hold(c),
    "sma_200": lambda c: sma_filter(c, 200),
    "sma_200_band2 (production)": lambda c: sma_band(c, 200, 0.02),
    "sma_100": lambda c: sma_filter(c, 100),
    "ema_20_100": lambda c: ema_cross(c, 20, 100),
    "ema_50_200": lambda c: ema_cross(c, 50, 200),
    "donchian_40_20": lambda c: donchian(c, 40, 20),
    "tsmom_90": lambda c: ts_momentum(c, 90),
    "rsi_meanrev": lambda c: rsi_mean_reversion(c),
}
