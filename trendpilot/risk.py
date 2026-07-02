"""Risk guardrails applied before any order is sent.

These exist because a bot that can place live orders needs hard stops that
do not depend on the strategy being right:

  * drawdown halt: if account equity drops X% below its high-water mark the
    bot liquidates nothing, stops trading entirely and demands human review
  * allocation cap: never deploy more than max_allocation of account value
  * order-value floor: skip dust orders that only generate noise
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from .config import Config
from .state import State

log = logging.getLogger("trendpilot.risk")


class TradingHalted(RuntimeError):
    pass


@dataclass(frozen=True)
class RiskCheck:
    equity: float
    allowed_value: float  # max value the bot may hold in the target asset


def check(config: Config, state: State, account_equity: float) -> RiskCheck:
    if state.halted:
        raise TradingHalted(
            f"bot is halted ({state.halt_reason}). Review the account, then "
            f"reset with `trendpilot resume`."
        )

    if account_equity > state.high_water_mark:
        state.high_water_mark = account_equity

    if state.high_water_mark > 0:
        drawdown = 1.0 - account_equity / state.high_water_mark
        if drawdown >= config.drawdown_halt:
            state.halted = True
            state.halt_reason = (
                f"drawdown {drawdown:.1%} breached halt threshold "
                f"{config.drawdown_halt:.0%}"
            )
            log.error("HALT: %s", state.halt_reason)
            raise TradingHalted(state.halt_reason)

    return RiskCheck(
        equity=account_equity,
        allowed_value=account_equity * config.max_allocation,
    )
