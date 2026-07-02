import sys
from pathlib import Path

import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backtest"))
sys.path.insert(0, str(ROOT / "bot"))

import engine  # noqa: E402
from exchange import PaperBroker  # noqa: E402


def test_costs_and_shift_are_applied():
    # Prices double on day 3; position turns on at close of day 2.
    close = pd.Series([100.0, 100.0, 100.0, 200.0, 200.0])
    pos = pd.Series([0.0, 0.0, 1.0, 1.0, 1.0])
    r = engine.run("t", close, pos, cost_per_side=0.01)
    # Entry cost 1% on day the position turns on (shifted to day 3),
    # then +100% on day 3: equity = 0.99 * 2 ... but cost applies same day
    # as the fill: (1 + 1.0 - 0.01) on day 3 => 1.99
    assert r.equity.iloc[-1] == pytest.approx(1.99)
    assert r.n_trades == 1


def test_no_lookahead():
    # Signal fires on the last day only: it can never earn that day's return.
    close = pd.Series([100.0, 100.0, 300.0])
    pos = pd.Series([0.0, 0.0, 1.0])
    r = engine.run("t", close, pos, cost_per_side=0.0)
    assert r.equity.iloc[-1] == pytest.approx(1.0)


def test_buy_and_hold_matches_price_ratio():
    close = pd.Series([100.0, 150.0, 120.0, 240.0])
    pos = pd.Series(1.0, index=close.index)
    r = engine.run("bh", close, pos, cost_per_side=0.0)
    # entered at the first close, so equity tracks price from there
    assert r.equity.iloc[-1] == pytest.approx(240 / 100)


def test_paper_broker_round_trip(tmp_path):
    b = PaperBroker(tmp_path / "s.json", starting_gbp=100.0, fee=0.004)
    b.buy_all(50000.0)
    assert b.state["gbp"] == 0.0
    assert b.state["btc"] == pytest.approx(100 / 50000 * 0.996)
    b.sell_all(60000.0)
    assert b.state["btc"] == 0.0
    assert b.state["gbp"] == pytest.approx(100 * 0.996 * (60000 / 50000) * 0.996)
    b.save()
    b2 = PaperBroker(tmp_path / "s.json", starting_gbp=100.0)
    assert b2.state["gbp"] == b.state["gbp"]
    assert len(b2.state["trades"]) == 2
