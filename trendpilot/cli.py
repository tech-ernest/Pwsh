"""Command-line interface.

  trendpilot run [--config path] [--force-signal]   one decision/execution cycle
  trendpilot signal [--config path]                 print signal only, never trade
  trendpilot status [--config path]                 show account + bot state
  trendpilot resume [--config path]                 clear a drawdown halt
"""

from __future__ import annotations

import argparse
import logging
import sys

from .bot import run_once
from .config import load_config
from .state import State
from .t212 import T212Client


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="trendpilot")
    parser.add_argument("command", choices=["run", "signal", "status", "resume"])
    parser.add_argument("--config", default=None, help="path to config YAML")
    parser.add_argument("--force-signal", action="store_true",
                        help="emit the signal even when nothing changed")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
    config = load_config(args.config)

    if args.command == "signal":
        config = type(config)(**{**config.__dict__, "mode": "signal"})
        print(run_once(config, force=True))
        return 0

    if args.command == "run":
        print(run_once(config, force=args.force_signal))
        return 0

    if args.command == "status":
        state = State.load(config.state_file)
        print(f"environment : {config.environment}")
        print(f"mode        : {config.mode}")
        print(f"halted      : {state.halted} {state.halt_reason}")
        print(f"last run    : {state.last_run or '-'}")
        print(f"last target : {state.last_target or '-'}")
        if config.api_key:
            client = T212Client(config.base_url, config.api_key)
            cash = client.account_cash()
            print(f"account     : total={cash.get('total')} free={cash.get('free')} "
                  f"invested={cash.get('invested')} P/L={cash.get('ppl')}")
        return 0

    if args.command == "resume":
        state = State.load(config.state_file)
        state.halted = False
        state.halt_reason = ""
        state.high_water_mark = 0.0  # reset HWM to re-arm from current equity
        state.save(config.state_file)
        print("halt cleared; high-water mark reset")
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
