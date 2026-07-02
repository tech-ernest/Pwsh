"""Orchestrator: one idempotent run = fetch data, decide, act, record.

Designed to run from cron/systemd/Task Scheduler. A run only *acts* when the
decision differs from what the account already holds, so running it daily is
safe; the strategy itself only changes state around month end.
"""

from __future__ import annotations

import datetime as dt
import logging

from . import data as datamod
from . import risk as riskmod
from .config import Config
from .executor import execute, plan_rebalance
from .signals import format_signal, send
from .state import State
from .strategy import decide
from .t212 import T212Client

log = logging.getLogger("trendpilot.bot")


def run_once(config: Config, force: bool = False) -> str:
    """Returns a short human summary of what happened."""
    state = State.load(config.state_file)

    symbols = [a.data_symbol for a in [*config.risk_assets, config.defensive_asset]]
    keys = [a.key for a in [*config.risk_assets, config.defensive_asset]]
    closes = datamod.fetch_history(symbols)
    closes.columns = keys[: len(closes.columns)] if len(closes.columns) != len(symbols) else keys
    datamod.validate_history(closes, config.max_daily_move, config.max_data_age_days)

    decision = decide(
        closes,
        risk_assets=[a.key for a in config.risk_assets],
        defensive_asset=config.defensive_asset.key,
        params=config.strategy,
    )
    log.info("decision: %s — %s", decision.target, decision.reason)

    signal_text = format_signal(config, decision, state.last_target)
    changed = decision.target != state.last_target

    if config.mode in ("signal", "both") and (changed or force):
        send(config, signal_text)

    summary = f"target={decision.target} ({'switch' if changed else 'hold'})"

    if config.mode in ("execute", "both"):
        client = T212Client(config.base_url, config.api_key)
        cash = client.account_cash()
        equity = float(cash.get("total", 0.0))
        try:
            allowance = riskmod.check(config, state, equity)
        except riskmod.TradingHalted as exc:
            send(config, f"TrendPilot: trading halted — {exc}")
            state.save(config.state_file)
            return f"halted: {exc}"

        positions = client.portfolio()
        orders = plan_rebalance(
            config,
            decision.target,
            positions,
            float(cash.get("free", 0.0)),
            allowance.allowed_value,
        )
        if orders:
            price_of = {
                p["ticker"]: float(p.get("currentPrice", 0.0)) for p in positions
            }
            target_ticker = config.asset_by_key(decision.target).t212_ticker
            if target_ticker not in price_of:
                price_of[target_ticker] = _instrument_price(client, target_ticker)
            results = execute(config, client, orders, price_of)
            summary += f", {len(results)} order(s) sent"
            log.info("orders: %s", results)
        else:
            summary += ", already positioned"

    state.last_target = decision.target
    state.last_run = dt.datetime.now(dt.timezone.utc).isoformat()
    state.last_signal = signal_text
    state.save(config.state_file)
    return summary


def _instrument_price(client: T212Client, ticker: str) -> float:
    """The public API exposes prices via portfolio/instrument metadata only.

    For a brand-new position we fall back to the instrument's last traded
    price if the metadata provides one; otherwise executor skips the buy and
    the user is alerted (better to miss a day than to size an order blind).
    """
    try:
        for inst in client.instruments():
            if inst.get("ticker") == ticker:
                price = inst.get("currentPrice") or inst.get("lastPrice") or 0.0
                return float(price)
    except Exception as exc:  # noqa: BLE001
        log.warning("could not resolve price for %s: %s", ticker, exc)
    return 0.0
