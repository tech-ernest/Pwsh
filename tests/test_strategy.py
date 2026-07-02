import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bot"))
sys.path.insert(0, str(ROOT / "backtest"))

from strategy import StrategyParams, target_position  # noqa: E402

P = StrategyParams(sma_window=5, band=0.02)


def make(closes):
    return pd.Series(closes, dtype=float)


def test_enters_above_band():
    # SMA of last 5 = 100, last close 103 > 102 -> long
    s = make([100, 100, 100, 100, 100, 103])
    s = s.iloc[1:]  # keep window=5 with last close 103: sma=(100*4+103)/5=100.6
    assert target_position(s, current_position=0, params=P) == 1


def test_exits_below_band():
    s = make([110, 110, 110, 110, 90])  # sma=106, 90 < 106*0.98
    assert target_position(s, current_position=1, params=P) == 0


def test_holds_inside_band():
    s = make([100, 100, 100, 100, 100])  # close == sma, inside the band
    assert target_position(s, 1, P) == 1
    assert target_position(s, 0, P) == 0


def test_requires_enough_history():
    with pytest.raises(ValueError):
        target_position(make([1, 2, 3]), 0, P)


def test_matches_backtest_implementation():
    """The production rule must reproduce the backtested signal path."""
    rng = np.random.default_rng(42)
    close = pd.Series(np.exp(np.cumsum(rng.normal(0, 0.04, 800)))) * 100
    params = StrategyParams(sma_window=200, band=0.02)

    # reference: the vectorised signal as backtested in RESEARCH.md
    import strategies
    ref = strategies.sma_band(close, 200, 0.02)

    pos = 0
    for t in range(200, len(close)):
        pos = target_position(close.iloc[: t + 1], pos, params)
        assert pos == int(ref.iloc[t]), f"mismatch at t={t}"
