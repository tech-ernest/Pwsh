"""Configuration loading: YAML file + environment variable overrides.

Secrets (API keys, Telegram token) are read from environment variables only,
never from the YAML file, so a shared config can't leak credentials.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .strategy import StrategyParams


@dataclass(frozen=True)
class Asset:
    key: str            # internal name, e.g. "equities"
    data_symbol: str    # market-data symbol, e.g. "VUAG.L"
    t212_ticker: str    # T212 instrument ticker, e.g. "VUAGl_EQ"
    cfd_symbol: str = ""  # optional CFD expression for signal mode, e.g. "US500"


@dataclass(frozen=True)
class Config:
    mode: str                      # "execute" | "signal" | "both"
    environment: str               # "live" | "demo"
    risk_assets: list[Asset]
    defensive_asset: Asset
    strategy: StrategyParams
    max_allocation: float          # fraction of account value to deploy (0-1]
    min_order_value: float         # skip dust orders below this (account ccy)
    drawdown_halt: float           # halt if equity falls this far below HWM
    max_daily_move: float          # data sanity: reject if any close moved more
    max_data_age_days: int         # data sanity: reject stale data
    dry_run: bool                  # log orders instead of sending them
    state_file: Path
    telegram_enabled: bool
    api_key: str = ""              # T212 API key (env T212_API_KEY)
    telegram_token: str = ""       # env TELEGRAM_BOT_TOKEN
    telegram_chat_id: str = ""     # env TELEGRAM_CHAT_ID

    @property
    def base_url(self) -> str:
        host = "live" if self.environment == "live" else "demo"
        return f"https://{host}.trading212.com/api/v0"

    def asset_by_key(self, key: str) -> Asset:
        for a in [*self.risk_assets, self.defensive_asset]:
            if a.key == key:
                return a
        raise KeyError(key)


DEFAULTS: dict = {
    "mode": "signal",
    "environment": "demo",
    "max_allocation": 0.95,
    "min_order_value": 1.0,
    "drawdown_halt": 0.30,
    "max_daily_move": 0.20,
    "max_data_age_days": 5,
    "dry_run": False,
    "state_file": "trendpilot_state.json",
    "telegram_enabled": False,
    "strategy": {},
    "assets": {
        "risk": [
            {"key": "equities", "data_symbol": "VUAG.L",
             "t212_ticker": "VUAGl_EQ", "cfd_symbol": "US500"},
            {"key": "gold", "data_symbol": "SGLN.L",
             "t212_ticker": "SGLNl_EQ", "cfd_symbol": "GOLD"},
        ],
        "defensive": {"key": "bonds", "data_symbol": "VAGP.L",
                      "t212_ticker": "VAGPl_EQ", "cfd_symbol": ""},
    },
}


def load_config(path: str | Path | None = None) -> Config:
    raw = dict(DEFAULTS)
    if path is not None:
        with open(path) as fh:
            user = yaml.safe_load(fh) or {}
        for k, v in user.items():
            raw[k] = v

    def _asset(d: dict) -> Asset:
        return Asset(key=d["key"], data_symbol=d["data_symbol"],
                     t212_ticker=d["t212_ticker"],
                     cfd_symbol=d.get("cfd_symbol", ""))

    assets = raw["assets"]
    strategy = StrategyParams(**raw.get("strategy", {}))

    mode = os.environ.get("TRENDPILOT_MODE", raw["mode"])
    environment = os.environ.get("TRENDPILOT_ENV", raw["environment"])
    if mode not in ("execute", "signal", "both"):
        raise ValueError(f"invalid mode {mode!r}")
    if environment not in ("live", "demo"):
        raise ValueError(f"invalid environment {environment!r}")

    return Config(
        mode=mode,
        environment=environment,
        risk_assets=[_asset(a) for a in assets["risk"]],
        defensive_asset=_asset(assets["defensive"]),
        strategy=strategy,
        max_allocation=float(raw["max_allocation"]),
        min_order_value=float(raw["min_order_value"]),
        drawdown_halt=float(raw["drawdown_halt"]),
        max_daily_move=float(raw["max_daily_move"]),
        max_data_age_days=int(raw["max_data_age_days"]),
        dry_run=bool(raw["dry_run"]),
        state_file=Path(raw["state_file"]),
        telegram_enabled=bool(raw["telegram_enabled"]),
        api_key=os.environ.get("T212_API_KEY", ""),
        telegram_token=os.environ.get("TELEGRAM_BOT_TOKEN", ""),
        telegram_chat_id=os.environ.get("TELEGRAM_CHAT_ID", ""),
    )
