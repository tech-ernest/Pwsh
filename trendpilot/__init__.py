"""TrendPilot — trend-filtered dual-momentum trading bot for Trading 212.

Two operating modes:
  * execute: places real orders on a T212 Invest/ISA account via the public API
  * signal:  emits human-readable signals (console/Telegram) for manual execution,
             including CFD-expression of the same view

Capital at risk. This software is a tool, not investment advice.
"""

__version__ = "0.1.0"
