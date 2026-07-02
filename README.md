# Kraken BTC/GBP Trend Bot

A low-frequency crypto trading bot for a small UK account (£100 starting
capital) trading **BTC/GBP spot on Kraken Pro**. The strategy — a 200-day
SMA trend filter with a 2% hysteresis band, long-only, ~3 trades/year —
was selected by backtesting seven candidates over 2015–2026 with
conservative costs and an untouched 2022+ out-of-sample window.
**Read [RESEARCH.md](RESEARCH.md) for the full analysis and its limitations.**

Out-of-sample (2022-01 → 2026-05, fees included): **+173%** vs +60% for
buy & hold, with max drawdown -33% vs -67%.

## How it works

Once a day, just after the 00:00 UTC daily close:

1. Fetch the last ~220 daily closes for BTC/GBP from Kraken.
2. If close > SMA200 × 1.02 → be **long** (all-in BTC).
   If close < SMA200 × 0.98 → be **flat** (all-in GBP).
   Otherwise keep yesterday's position.
3. If the account has fallen 35% from its peak → liquidate and **halt**
   until a human intervenes (kill switch).

```
config.yaml          settings (mode, pair, strategy params, risk limits)
bot/run_bot.py       daily entry point (paper + live)
bot/strategy.py      the trading rule (unit-tested against the backtest)
bot/exchange.py      Kraken via ccxt + paper broker
backtest/            engine, 8 candidate strategies, comparison runner
data/                Coin Metrics daily data + refresh script
tests/               pytest suite
```

## Quickstart

```bash
pip install -r requirements.txt
python3 -m pytest tests/            # all green before anything else

# Reproduce the research
python3 backtest/run_backtest.py --asset btc

# Paper trade (default mode, no keys needed) — run daily via cron:
#   5 0 * * * cd /path/to/repo && python3 bot/run_bot.py >> bot/bot.log 2>&1
python3 bot/run_bot.py              # or: --loop to keep a process alive
```

State (cash, BTC, trade log, peak equity) lives in `bot/state.json`.

## Going live (only after 1–2 months of paper trading)

1. Create a Kraken account (FCA-registered for UK), deposit £100 via
   Faster Payments, and create an API key with **only** "Query Funds" and
   "Create & Modify Orders" permissions — never withdrawal rights.
2. `export KRAKEN_API_KEY=... KRAKEN_API_SECRET=...`
3. Set `mode: live` in `config.yaml`.
4. Run with the explicit acknowledgement flag:
   `python3 bot/run_bot.py --i-understand-live`

## Disclaimers

- Not financial advice. Capital at risk; you can lose everything you
  deposit. Past performance (including the backtests here) does not
  guarantee future results.
- UK: crypto disposals are within scope of Capital Gains Tax — keep the
  trade log. Spot only; UK retail may not trade crypto derivatives.
