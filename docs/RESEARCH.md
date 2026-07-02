# Strategy Research & Selection

Date: July 2026. Objective: find the most defensible, profitable bot strategy for a
**£500 Trading 212 account** covering US stock markets, commodities and CFDs, then
build it.

## 1. Platform constraints (these drove everything)

| Constraint | Consequence |
|---|---|
| T212 public API covers **Invest/Stocks ISA only** — no CFD endpoints | Automated execution is possible for stocks/ETFs/ETCs; **CFDs are signal-mode only** (manual execution) |
| T212 API has **no price-history endpoint** | Signals are computed from external data (Yahoo Finance primary, Stooq fallback) |
| T212 charges **no commission** but **0.15% FX fee** per trade on non-GBP instruments | High-frequency strategies are structurally disadvantaged; GBP-denominated LSE instruments avoid the fee entirely |
| UK retail cannot buy US-domiciled ETFs (PRIIPs/KID rules) | Default universe uses **UCITS equivalents**: VUAG (S&P 500), SGLN (physical gold), VAGP (global bonds) — all GBP, all on T212 |
| £500 starting capital | Fractional shares make any allocation feasible; but per-trade costs and slippage must stay tiny relative to expected edge |

## 2. Candidates tested

All backtests apply a realistic cost model of **0.20% per side** (0.15% FX + ~0.05%
spread/slippage) — conservative, since the default GBP universe avoids the FX fee.

Data: Shiller S&P 500 total-return + Bundesbank gold + US 10Y yields (monthly,
1954–2026, bond total return approximated from yields with duration ~7.5); S&P 500
index + 20 large caps daily 1990–2022 (skfolio dataset).

| Strategy | Period | CAGR | Sharpe | MaxDD | Trades/yr | Verdict |
|---|---|---|---|---|---|---|
| **C. Dual momentum + trend filter (stocks/gold/bonds)** | 1954–2026 | **14.9%** | **1.05** | **−25%** | 1.7 | **WINNER** |
| A. Dual momentum, no trend filter | 1954–2026 | 14.7% | 1.01 | −30% | 1.4 | Runner-up (deeper DD) |
| B. 10-month SMA trend filter only (stocks/bonds) | 1954–2026 | 12.7% | 1.27 | −19% | 1.2 | Best Sharpe — shipped as "conservative" preset (set universe to equities-only) |
| F. Stock momentum top-3 of 20 | 1990–2022 | 19.8% | 0.91 | −32% | high | **Rejected**: survivorship-biased data, not trustworthy |
| E. Daily 200SMA trend on index | 1990–2022 | 6.1% | 0.58 | −24% | 2.8 | Inferior to monthly variant |
| D. RSI-2 mean reversion (Connors) | 1990–2022 | **0.7%** | 0.16 | −30% | 15.5 | **Rejected: costs destroy it** (negative since 2010) |
| Buy & hold S&P 500 TR | 1954–2026 | 11.4% | 0.95 | **−49%** | 0 | Benchmark |

### Winner's consistency across regimes (strategy C, net of costs)

| Period | CAGR | Sharpe | MaxDD |
|---|---|---|---|
| 1954–1989 | 17.4% | 1.04 | −25% |
| 1990–2009 | 12.7% | 1.15 | −13% |
| 2010–2026 | 12.2% | 1.05 | −21% |

### Overfitting check (parameter grid, 1954–2026)

Every combination of momentum lookback {6, 9, 12}m × SMA {8, 10, 12}m lands at
**CAGR 14.0–15.4%, Sharpe 1.01–1.07**. The edge does not depend on parameter
choice. The shipped default additionally averages the 6/9/12 lookbacks
(ensemble) to remove the single-window dependency entirely.

## 3. Why mean reversion lost (important negative result)

Published RSI-2 results (e.g. Sharpe ~2.8 with 75% winners) assume **zero
transaction costs**. At 232 trades with ~0.4% round-trip cost and only ~11–14%
market exposure, the entire edge is transferred to the broker/market maker. On a
£500 T212 account this class of strategy is **structurally unprofitable**. Any
vendor selling a high-frequency bot for small T212 accounts is selling cost decay.

## 4. Expectations for £500 (honest numbers)

- Historical average: ~12–15%/yr → **£60–75/yr** on £500. The bot's value is the
  discipline and the compounding, not fast riches.
- Realistic worst case from history: **−25% drawdown (−£125)**, roughly once a
  decade; the 30% drawdown kill-switch bounds catastrophe.
- Past performance does not guarantee future results. A ~73% median Sharpe decay
  from backtest to live has been documented across published strategies; this
  strategy's 70-year, multi-regime, parameter-insensitive record is the best
  available defence, not a guarantee.

## 5. Known limitations

- Monthly bond returns approximated from 10Y yields (duration model), not a bond
  fund's actual NAV series.
- Daily dataset ends Dec 2022; monthly dataset extends to May 2026.
- Gold monthly series is a London-fix price, not an ETC NAV (tracking difference
  ~0.1–0.4%/yr).
- The 20-stock daily dataset is survivorship-biased — which is exactly why the
  stock-rotation candidate was rejected rather than shipped.

## Sources

- [Trading 212 Public API docs](https://docs.trading212.com/api) — environments, Invest/ISA scope, order endpoints
- [StockCharts: RSI(2) strategy](https://chartschool.stockcharts.com/table-of-contents/trading-strategies-and-models/trading-strategies/rsi-2), [QuantifiedStrategies RSI mean reversion](https://www.quantifiedstrategies.com/rsi-mean-reversion-trading-strategy/) — published zero-cost results
- [Optimal Momentum: Whither Fragility (GEM)](https://www.optimalmomentum.com/whither-fragility-dual-momentum-gem/), [Newfound: Fragility Case Study](https://blog.thinknewfound.com/2019/01/fragility-case-study-dual-momentum-gem/) — dual momentum robustness debate
- [Grzegorz Link: Dual momentum enhanced](https://grzegorz.link/momentum-enhanced) — recent GEM-family results
- [FCA PERG 13](https://handbook.fca.org.uk/handbook/perg13), [Brodies: Advice or Education?](https://brodies.com/insights/corporate-crime-and-investigations/advice-or-education-a-reminder-to-not-get-on-the-wrong-side-of-the-fca/) — signal regulation (see COMMERCIAL_PLAN.md)
- Data: [Shiller S&P](https://github.com/datasets/s-and-p-500), [gold prices](https://github.com/datasets/gold-prices), [US 10Y yields](https://github.com/datasets/bond-yields-us-10y), skfolio bundled S&P daily dataset
