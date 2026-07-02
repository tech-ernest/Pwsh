import pytest

from trendpilot.config import load_config
from trendpilot.risk import TradingHalted, check
from trendpilot.state import State


CFG = load_config()  # drawdown_halt = 0.30, max_allocation = 0.95


def test_hwm_ratchets_up():
    state = State(high_water_mark=400.0)
    result = check(CFG, state, account_equity=500.0)
    assert state.high_water_mark == 500.0
    assert result.allowed_value == pytest.approx(475.0)


def test_drawdown_halts_trading():
    state = State(high_water_mark=500.0)
    with pytest.raises(TradingHalted):
        check(CFG, state, account_equity=340.0)  # -32%
    assert state.halted


def test_halted_state_blocks_runs():
    state = State(halted=True, halt_reason="manual")
    with pytest.raises(TradingHalted):
        check(CFG, state, account_equity=500.0)


def test_normal_drawdown_passes():
    state = State(high_water_mark=500.0)
    result = check(CFG, state, account_equity=450.0)  # -10%
    assert result.allowed_value == pytest.approx(427.5)
