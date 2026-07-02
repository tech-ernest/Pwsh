# TrendPilot Strategy Specification (TFDM)

**Trend-Filtered Dual Momentum** — long-only, one position at a time, monthly cadence.

## Universe (default)

| Leg | Instrument | LSE ticker | Why |
|---|---|---|---|
| US equities | Vanguard S&P 500 UCITS (Acc) | VUAG | GBP-quoted (no FX fee), accumulating (price = total return), PRIIPs-compliant |
| Commodities | iShares Physical Gold ETC | SGLN | The one commodity with a 70-year defensible momentum record; GBP-quoted |
| Defensive | Vanguard Global Agg Bond (GBP-hedged) | VAGP | Ballast when both risk legs are weak |

CFD signal expressions: `US500` (S&P 500 index CFD), `GOLD` (spot gold CFD).

## Rules

Evaluated on adjusted month-end closes; acted on at/after the last trading day of each month.

1. **Relative momentum** — score each risk asset by its trailing return.
   Default: mean of 6-, 9- and 12-month returns (ensemble). Pick the winner.
2. **Trend filter** — winner must close **above its 10-month SMA**.
3. **Absolute momentum** — winner's score must exceed the cash hurdle
   (4%/yr pro-rated to the lookback window).
4. If (2) or (3) fails → hold the **defensive asset**. Else hold the winner.
5. **Allocation**: `max_allocation` (default 95%) of account value in the single
   target asset, fractional shares.

## Risk management (independent of the strategy)

- **Drawdown kill-switch**: equity ≥30% below high-water mark → liquidation stops,
  bot halts, human must run `trendpilot resume`.
- **Data guards**: refuse to act on price data older than 5 days or containing a
  >20% single-day move (bad feed protection).
- **Position isolation**: the bot only ever touches the three configured tickers.
  Anything else in the account is invisible to it.
- **Dry-run and demo environment** for validation before live.

## Cadence & operations

- Run daily via cron (idempotent — it only trades when the target changes,
  which happens ~1.7×/year): `5 18 * * 1-5` (after LSE close).
- Expected costs: ~2 switches/yr × ~0.1% spread on GBP instruments ≈ **~0.2%/yr**.
- Taxes (UK): use a Stocks ISA where possible; outside an ISA, ~2 disposals/yr
  keeps CGT paperwork trivial.

## Why these rules (see RESEARCH.md for full numbers)

- 1954–2026 net backtest: **~14.9% CAGR, Sharpe 1.05, max DD −25%**, consistent
  across 1954–89 / 1990–2009 / 2010–26 sub-periods.
- Parameter-insensitive: all 9 lookback×SMA combinations within 1.4 CAGR points.
- Monthly cadence is what makes it survivable on a small account: the strategy
  spends its edge on holding trends, not on paying spreads.
