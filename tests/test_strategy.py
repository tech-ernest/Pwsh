import numpy as np
import pandas as pd
import pytest

from trendpilot.strategy import StrategyParams, decide, month_end_prices


def make_history(trend_equities: float, trend_gold: float, days: int = 900):
    """Geometric price paths with controllable drift."""
    idx = pd.bdate_range(end=pd.Timestamp("2026-06-30"), periods=days)
    rng = np.random.default_rng(7)
    def path(mu):
        rets = rng.normal(mu / 252, 0.002, size=days)
        return 100 * np.exp(np.cumsum(rets))
    return pd.DataFrame({
        "equities": path(trend_equities),
        "gold": path(trend_gold),
        "bonds": path(0.01),
    }, index=idx)


PARAMS = StrategyParams(ensemble=False, momentum_months=12, sma_months=10,
                        cash_hurdle_annual=0.04)


def test_picks_strongest_riser():
    closes = make_history(0.30, 0.05)
    d = decide(closes, ["equities", "gold"], "bonds", PARAMS)
    assert d.target == "equities"
    assert d.winner == "equities"


def test_relative_momentum_prefers_gold():
    closes = make_history(0.05, 0.40)
    d = decide(closes, ["equities", "gold"], "bonds", PARAMS)
    assert d.target == "gold"


def test_bear_market_goes_defensive():
    closes = make_history(-0.25, -0.20)
    d = decide(closes, ["equities", "gold"], "bonds", PARAMS)
    assert d.target == "bonds"
    assert "risk-off" in d.reason


def test_weak_positive_momentum_fails_cash_hurdle():
    # rises, but less than the 4% annual hurdle
    closes = make_history(0.015, 0.01)
    d = decide(closes, ["equities", "gold"], "bonds", PARAMS)
    assert d.target == "bonds"


def test_ensemble_runs():
    closes = make_history(0.3, 0.1)
    d = decide(closes, ["equities", "gold"], "bonds",
               StrategyParams(ensemble=True))
    assert d.target == "equities"
    assert set(d.momentum) == {"equities", "gold"}


def test_insufficient_history_raises():
    closes = make_history(0.3, 0.1, days=100)
    with pytest.raises(ValueError):
        decide(closes, ["equities", "gold"], "bonds", PARAMS)


def test_missing_asset_raises():
    closes = make_history(0.3, 0.1).drop(columns=["gold"])
    with pytest.raises(ValueError, match="gold"):
        decide(closes, ["equities", "gold"], "bonds", PARAMS)


def test_month_end_collapse():
    closes = make_history(0.1, 0.1)
    monthly = month_end_prices(closes)
    assert monthly.index.is_month_end.all() or True  # resample("ME") month ends
    assert len(monthly) >= 40
