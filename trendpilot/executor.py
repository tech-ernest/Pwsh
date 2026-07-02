"""Order planning and execution against a T212 Invest/ISA account.

The bot holds at most one strategy position at a time (plus incidental cash).
Rebalancing therefore reduces to: sell whatever strategy asset we no longer
want, then buy the target with available cash, respecting the allocation cap.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from .config import Config
from .t212 import T212Client

log = logging.getLogger("trendpilot.executor")


@dataclass(frozen=True)
class PlannedOrder:
    ticker: str
    quantity: float  # positive = buy, negative = sell
    est_value: float
    why: str


def plan_rebalance(
    config: Config,
    target_key: str,
    positions: list[dict],
    free_cash: float,
    allowed_value: float,
) -> list[PlannedOrder]:
    """Compute the orders needed to move the account to the target asset."""
    strategy_tickers = {
        a.t212_ticker: a.key for a in [*config.risk_assets, config.defensive_asset]
    }
    target = config.asset_by_key(target_key)
    orders: list[PlannedOrder] = []

    held_target_value = 0.0
    for pos in positions:
        ticker = pos.get("ticker")
        if ticker not in strategy_tickers:
            continue  # never touch positions the user opened themselves
        qty = float(pos.get("quantity", 0.0))
        price = float(pos.get("currentPrice", 0.0))
        value = qty * price
        if ticker == target.t212_ticker:
            held_target_value = value
            continue
        if qty > 0:
            orders.append(PlannedOrder(
                ticker=ticker,
                quantity=-qty,
                est_value=value,
                why=f"exit {strategy_tickers[ticker]} (no longer the target)",
            ))
            free_cash += value  # proceeds become buying power

    budget = min(free_cash, max(allowed_value - held_target_value, 0.0))
    if budget >= config.min_order_value:
        # T212 supports value-based fractional buys via quantity at market;
        # we convert to quantity with the position's current price at send time.
        orders.append(PlannedOrder(
            ticker=target.t212_ticker,
            quantity=0.0,  # resolved at execution from live price
            est_value=budget,
            why=f"enter/top-up {target.key}",
        ))
    return orders


def execute(
    config: Config,
    client: T212Client,
    orders: list[PlannedOrder],
    price_of: dict[str, float],
) -> list[dict]:
    """Send planned orders. Sells first so proceeds settle into buying power."""
    results = []
    for order in orders:
        qty = order.quantity
        if qty == 0.0:
            price = price_of.get(order.ticker, 0.0)
            if price <= 0:
                log.warning("no live price for %s, skipping buy", order.ticker)
                continue
            qty = round(order.est_value / price, 8)
        if config.dry_run:
            log.info("DRY RUN: would send %s qty=%s (%s)", order.ticker, qty, order.why)
            results.append({"dryRun": True, "ticker": order.ticker, "quantity": qty})
            continue
        results.append(client.place_market_order(order.ticker, qty))
    return results
