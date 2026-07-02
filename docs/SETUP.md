# Setup Guide

## 1. Install

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e .
cp config.example.yaml config.yaml
```

## 2. Get a Trading 212 API key

1. In the T212 app/web: **Settings → API (Beta) → Generate key**.
2. Keys are **per-environment**: a Practice-account key only works against
   `demo.trading212.com`, a real-money key against `live.trading212.com`.
   Match `environment:` in `config.yaml` accordingly.
3. Export it (never put it in the YAML):

```bash
export T212_API_KEY="your-key"          # Windows: setx T212_API_KEY "your-key"
```

## 3. Verify instrument tickers (once)

T212's internal tickers differ from exchange symbols (e.g. `VUAGl_EQ`). Confirm
the three defaults exist on your account:

```bash
curl -s -H "Authorization: $T212_API_KEY" \
  https://demo.trading212.com/api/v0/equity/metadata/instruments | \
  python -c "import sys,json;[print(i['ticker'],'|',i['name']) for i in json.load(sys.stdin) if any(k in i['ticker'] for k in ('VUAG','SGLN','VAGP'))]"
```

Update `t212_ticker` values in `config.yaml` if your account shows different ones.

## 4. First runs (in this order)

```bash
trendpilot signal --config config.yaml     # 1. signal only — see the decision
# set environment: demo, mode: execute
trendpilot run --config config.yaml        # 2. real orders, practice money
trendpilot status --config config.yaml     # 3. inspect account + bot state
# after 1-2 satisfactory demo months: environment: live
```

Recommended even if you intend to go live immediately: one demo run to confirm
tickers resolve and orders fill, then switch `environment: live` the same day.

## 5. Schedule it

The bot is idempotent — run it daily; it only trades when the monthly target
changes (~1.7×/yr).

**Linux/macOS (cron):**
```
5 18 * * 1-5  cd /path/to/trendpilot && /path/to/.venv/bin/trendpilot run --config config.yaml >> trendpilot.log 2>&1
```

**Windows (Task Scheduler):** daily 18:05, action
`C:\path\.venv\Scripts\trendpilot.exe run --config C:\path\config.yaml`.

## 6. Telegram signals (optional)

1. Create a bot with [@BotFather](https://t.me/BotFather), copy the token.
2. Message your bot once, then get your chat id:
   `curl https://api.telegram.org/bot<TOKEN>/getUpdates`
3. ```bash
   export TELEGRAM_BOT_TOKEN="123:abc"
   export TELEGRAM_CHAT_ID="123456789"
   ```
4. Set `telegram_enabled: true` in `config.yaml`.

## 7. CFD leg (manual, optional)

When a **SWITCH** signal arrives, the message includes a CFD expression
(e.g. "long US500"). If you choose to mirror it in your CFD account:
- CFDs are leveraged; a 1× notional equivalent of the signal is the conservative
  interpretation. T212 CFD overnight interest makes long multi-month holds
  expensive — the Invest execution path is the primary product for a reason.
- 76%+ of retail CFD accounts lose money; treat this leg as optional expression,
  not the core.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `T212 API error 401` | Wrong environment for the key, or key revoked |
| `T212 API error 429` | The client backs off automatically; if persistent, increase `min_interval` |
| `price data is N days old` | Yahoo symbol wrong/delisted, or market holiday week — check `data_symbol` |
| Bot halted | Drawdown breached `drawdown_halt`. Investigate, then `trendpilot resume` |
