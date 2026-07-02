from trendpilot.config import load_config
from trendpilot.executor import plan_rebalance


CFG = load_config()  # defaults: equities/gold risk, bonds defensive


def test_switch_sells_old_and_buys_new():
    positions = [
        {"ticker": "VUAGl_EQ", "quantity": 5.0, "currentPrice": 80.0},  # £400 equities
    ]
    orders = plan_rebalance(CFG, "gold", positions, free_cash=50.0,
                            allowed_value=450.0)
    assert len(orders) == 2
    sell, buy = orders
    assert sell.ticker == "VUAGl_EQ" and sell.quantity == -5.0
    assert buy.ticker == "SGLNl_EQ" and buy.est_value == 450.0  # 400 + 50 capped


def test_hold_no_orders_when_positioned():
    positions = [
        {"ticker": "SGLNl_EQ", "quantity": 10.0, "currentPrice": 47.0},  # £470 gold
    ]
    orders = plan_rebalance(CFG, "gold", positions, free_cash=0.5,
                            allowed_value=475.0)
    assert orders == []  # top-up of £0.50 is below min_order_value


def test_never_touches_user_positions():
    positions = [
        {"ticker": "AAPL_US_EQ", "quantity": 2.0, "currentPrice": 200.0},
        {"ticker": "VUAGl_EQ", "quantity": 1.0, "currentPrice": 80.0},
    ]
    orders = plan_rebalance(CFG, "bonds", positions, free_cash=0.0,
                            allowed_value=400.0)
    tickers = {o.ticker for o in orders}
    assert "AAPL_US_EQ" not in tickers
    assert any(o.quantity == -1.0 and o.ticker == "VUAGl_EQ" for o in orders)


def test_allocation_cap_limits_buy():
    orders = plan_rebalance(CFG, "equities", [], free_cash=500.0,
                            allowed_value=475.0)
    assert len(orders) == 1
    assert orders[0].est_value == 475.0
