"""Signal formatting and delivery (console, file, Telegram).

Signal mode exists for two reasons:
  * CFD accounts have no public API, so CFD users act on signals manually
  * some users prefer to confirm every trade themselves

Legal note for anyone reselling signals: in the UK, distributing per-trade
signals to third parties can constitute regulated investment advice
(FSMA 2000 s.19; see 24HR Trading v FCA). Personal use is fine; selling a
signal feed is not, without FCA authorisation. See docs/COMMERCIAL_PLAN.md.
"""

from __future__ import annotations

import logging

import requests

from .config import Config
from .strategy import Decision

log = logging.getLogger("trendpilot.signals")


def format_signal(config: Config, decision: Decision, current_target: str) -> str:
    changed = decision.target != current_target
    lines = [
        "TrendPilot monthly signal",
        f"as of {decision.as_of:%Y-%m-%d}" if decision.as_of is not None else "",
        "",
        f"Target allocation: {decision.target.upper()}",
        f"Action: {'SWITCH — rebalance required' if changed else 'HOLD — no change'}",
        "",
        f"Why: {decision.reason}",
        "",
        "Momentum scores:",
    ]
    for asset, score in sorted(decision.momentum.items(), key=lambda kv: -kv[1]):
        trend = "above trend" if decision.above_sma.get(asset) else "BELOW trend"
        lines.append(f"  {asset:<10} {score:+7.1%}  ({trend})")

    target_asset = config.asset_by_key(decision.target)
    lines += ["", "Instruments:"]
    lines.append(f"  Invest/ISA: {target_asset.t212_ticker} ({target_asset.data_symbol})")
    if changed and target_asset.cfd_symbol:
        lines.append(
            f"  CFD expression: long {target_asset.cfd_symbol} "
            f"(manual — T212 has no CFD API; size conservatively, CFDs are leveraged)"
        )
    lines += ["", "Not investment advice. Capital at risk."]
    return "\n".join(line for line in lines if line is not None)


def send(config: Config, text: str) -> None:
    print(text)
    if config.telegram_enabled:
        if not (config.telegram_token and config.telegram_chat_id):
            log.warning("telegram enabled but TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID unset")
            return
        resp = requests.post(
            f"https://api.telegram.org/bot{config.telegram_token}/sendMessage",
            json={"chat_id": config.telegram_chat_id, "text": text},
            timeout=30,
        )
        if resp.status_code != 200:
            log.error("telegram send failed: %s %s", resp.status_code, resp.text[:200])
