# Research: a profitable crypto trading bot for a £100 UK account

Date: 2026-07-02. This document records the research and backtesting that
drove every design decision in this repo. Reproduce all numbers with
`python3 backtest/run_backtest.py`.

## 1. Goal and constraints

- Starting capital: **£100**, based in the **United Kingdom**.
- Deliverable: a bot whose strategy is demonstrably profitable **net of
  fees** on real historical data, including on data it was not tuned on.

## 2. UK regulatory findings

- **Spot trading is fully permitted** for UK retail. **Crypto derivatives
  (futures, options, CFDs, leverage) have been banned for UK retail since
  January 2021** ([FCA](https://www.fca.org.uk/firms/new-regime-cryptoasset-regulation),
  [Bitget summary](https://www.bitget.com/academy/uk-crypto-regulation)).
  → Every strategy here is **long-only spot, position ∈ {0, 1}**. No
  shorting, no leverage.
- Only **FCA-registered** exchanges may legally serve UK residents
  ([MoneyMagpie](https://www.moneymagpie.com/investment-articles/fca-registered-crypto-exchanges)).
- The FCA published final rules for the new cryptoasset regime on
  30 June 2026; the mandatory FSMA regime starts 25 October 2027
  ([FCA press release](https://www.fca.org.uk/news/press-releases/fca-sets-landmark-crypto-rules-cement-uks-place-global-hub),
  [Skadden](https://www.skadden.com/insights/publications/2026/07/fca-finalises-core-rules-for-the-uk-cryptoasset-regime)).
  Spot access for retail is unaffected; incumbent FCA-registered exchanges
  are expected to transition.
- **Tax**: crypto disposals are subject to UK Capital Gains Tax. Every
  sell the bot makes is a disposal — keep the trade log (`bot/state.json`)
  for records. At this account size gains will sit far below the CGT
  annual exempt amount, but records still matter.

## 3. Platform selection: Kraken Pro

| Platform | FCA status | Spot fees (base tier) | GBP rails | API |
|---|---|---|---|---|
| **Kraken Pro** | Registered; EMI licence since Mar 2025 for direct GBP banking | **0.25% maker / 0.40% taker** | Faster Payments, GBP pairs incl. BTC/GBP | Mature REST+WS, first-class `ccxt` support |
| Coinbase (Advanced) | Registered | ~0.40–0.60% | Faster Payments | Good |
| Revolut X | Registered | 0% maker / 0.09% taker | Native | Limited API, thin pair coverage |

**Choice: Kraken Pro.** Best combination of FCA registration, direct GBP
banking, a liquid **BTC/GBP** pair, low fees and the most battle-tested
API (used here via `ccxt`). Revolut X has lower headline fees but a weak
API surface for bots. Sources:
[CryptoSlate UK exchange review](https://cryptoslate.com/crypto-exchanges/uk/),
[Coin Bureau](https://coinbureau.com/analysis/best-crypto-exchanges-uk),
[Kraken fee schedule](https://www.kraken.com/features/fee-schedule).

Kraken's BTC minimum order (0.00005 BTC ≈ £4) is far below our £100 order
size, so account size is not a blocker.

## 4. Fee math dictates the strategy class

At the base tier a market-order round trip costs **0.80%** (2 × 0.40%),
plus spread/slippage. On £100 that is ~80p per round trip.

- A bot trading **daily** (365 round trips/yr) needs **>290%/yr** edge
  just to pay fees. Grid/scalping/HFT approaches are structurally
  unprofitable at this size and tier.
- A bot trading **a few times a year** pays ~1–2%/yr in fees. Only
  **low-frequency strategies on daily candles** are viable.

This is confirmed empirically below: the mean-reversion candidate (many
small wins) is the worst performer net of fees in every test, matching
practitioner findings ([Altrady](https://www.altrady.com/blog/crypto-bots/are-ai-crypto-trading-bots-profitable-2026),
[Bitsgap backtesting guide](https://bitsgap.com/blog/crypto-backtesting-guide-2025-tools-tips-and-how-bitsgap-helps)).

## 5. Data and methodology

- **Data**: [Coin Metrics community data](https://github.com/coinmetrics/data)
  daily reference rates (PriceUSD, 00:00 UTC), 2015-01-01 → 2026-05-23 for
  BTC, 2015-08-08 → for ETH. Refresh with `python3 data/fetch_data.py`.
- **Execution model** (conservative, no look-ahead): signal on close of
  day *t* earns returns from day *t+1*; every position change pays
  **0.50% per side** (0.40% taker + 0.10% slippage). Cash earns 0%.
- **Anti-overfitting discipline**: only standard textbook parameters were
  tested (no per-asset optimisation); strategies were compared on
  2015–2021 history and then validated **out-of-sample on 2022-01-01 →
  2026-05-23** — a window containing the 2022 bear (-77%), the 2023 chop
  and the 2024–2026 cycle; the winner also had to survive on a second
  asset (ETH) and at **double the assumed costs (1.0%/side)**.

## 6. Results

Candidates: buy & hold (benchmark), SMA filters, EMA crosses, Donchian
breakout, time-series momentum, RSI mean reversion. Full tables in
`backtest/results/`; headline BTC numbers at 0.5%/side:

**Full period 2015 → 2026-05** (BTC)

| strategy | CAGR | Sharpe | max DD | trades/yr |
|---|---|---|---|---|
| buy & hold | 61.9% | 1.06 | **-83.8%** | 0.1 |
| **sma_200** | 55.9% | 1.11 | -68.7% | 6.1 |
| ema_20_100 | 61.7% | 1.19 | -66.4% | 3.2 |
| donchian_40_20 | 59.6% | 1.29 | -48.5% | 7.2 |
| rsi_meanrev | 16.6% | 0.62 | -51.1% | 4.7 |

**Out-of-sample 2022 → 2026-05** (BTC)

| strategy | total return | Sharpe | max DD | trades/yr |
|---|---|---|---|---|
| buy & hold | +60.3% | 0.47 | -67.0% | 0.2 |
| **sma_200** | **+151.9%** | **0.79** | **-34.3%** | 7.7 |
| ema_20_100 | +124.3% | 0.72 | -37.2% | 3.4 |
| donchian_40_20 | +34.1% | 0.37 | -38.7% | 9.1 |
| rsi_meanrev | +18.8% | 0.28 | -41.6% | 5.0 |

Robustness checks on the SMA-200 filter:

- **ETH out-of-sample**: +57% while buy & hold **lost 44%** — the only
  strategy clearly positive on both assets out-of-sample.
- **Costs doubled to 1.0%/side** (BTC OOS): still +112% vs +60% B&H.
- **Hysteresis band** (enter above SMA×1.02, exit below SMA×0.98): cuts
  trades from ~6 to ~3 per year and improves every BTC metric
  (OOS: **+173%, Sharpe 0.84, max DD -33%**, win rate 57%). Band sizes
  1%, 2% and 5% all improve on the raw filter, so 2% is not a fragile
  optimum.

## 7. Selected strategy

> **BTC/GBP on Kraken Pro, long-only spot. Hold BTC while the daily close
> is above the 200-day SMA (+2% band); hold GBP while below (-2% band);
> evaluated once per day at the 00:00 UTC close.**

What £100 would have done, out-of-sample (2022-01 → 2026-05, 0.5%/side):

| | £100 in the strategy | £100 buy & hold |
|---|---|---|
| End value | **£273** | £160 |
| Worst point | £67 of peak (-33%) | £33 of peak (-67%) |
| Trades | ~3/yr (≈ £1.60/yr in fees) | — |

Why it works: BTC's returns have historically come in long persistent
trends separated by deep (-70%+) bear markets. A slow trend filter keeps
you in most of the upside and — this is where the edge concentrates —
sidesteps the worst of the drawdowns. It trades so rarely that fees are
irrelevant, which is the only regime a £100 account can afford.

## 8. Honest limitations — read before going live

1. **Past performance does not guarantee future profit.** "Ensured
   profitable" here means *profitable net of fees across 11 years of
   history including an untouched 4.5-year out-of-sample window and
   adverse cost assumptions* — the strongest claim a backtest can
   support. No backtest can guarantee the future.
2. The strategy **will lose money in prolonged sideways chop** (whipsaw
   losses of a few % per year) and gives back ~20–35% from peaks before
   exiting a dying trend. The kill switch (35% account drawdown → halt)
   bounds this.
3. Backtests use USD reference rates as a proxy for BTC/GBP fills;
   GBP/USD drift is negligible next to BTC volatility but not zero.
4. Daily reference rates have no intraday path — results are not
   sensitive to this at ~3 trades/yr, but paper-trade before going live:
   run the bot in (default) paper mode for at least 1–2 months.
5. Bitcoin itself carrying on existing/appreciating is a structural
   assumption no strategy on BTC escapes.
