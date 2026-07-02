# Commercialisation Plan — TrendPilot

Goal: turn the bot into sellable products. You chose two routes: **software
licence** and **signal subscription**. They have very different legal profiles —
plan below reflects that.

## 0. The legal line that shapes everything (UK)

- **Selling software** that a customer runs themselves, with *their* API key and
  *their* configuration, is generally **not** a regulated activity — you are
  selling a tool, like selling Excel.
- **Selling signals** ("buy US500 now") to third parties **is investment advice**
  under FSMA 2000 s.19 when a reasonable recipient would read it as a
  recommendation. The High Court (24HR Trading v FCA) held exactly this for a
  WhatsApp signal service, and **disclaimers did not save them**. Unauthorised
  advice is a criminal offence, contracts become unenforceable, and the FCA
  publishes warnings against named firms.
- Consequence: **launch the software licence first** (Phase 1). Treat a paid
  signal feed as Phase 3, gated on FCA authorisation or an FCA-authorised
  partner (Appointed Representative arrangement). Interim workaround that stays
  on the right side of the line: sell the *bot that generates signals privately
  for each customer* — every subscriber runs their own instance; nobody is
  distributing recommendations to third parties.
- Also required regardless: clear risk warnings, no performance guarantees, no
  "get rich" marketing (ASA/FCA financial promotions rules apply to *how* you
  advertise even unregulated software), GDPR basics for the customer list.
- Budget item: 1–2 hours with a UK fintech solicitor (~£300–500) before first
  paid sale. Cheap insurance.

## 1. Product ladder

| Tier | Product | Price | What they get |
|---|---|---|---|
| Free | "TrendPilot Lite" | £0 | Signal mode only, console output, default universe, no Telegram. Lead generator. |
| Core | Software licence | **£49/yr or £99 lifetime** (launch price) | Full bot: T212 auto-execution, Telegram, config, updates for the licence period |
| Pro | Core + priority | £99/yr | Early features (multi-asset universes, conservative preset, weekly crash-check), setup support call |
| Phase 3 | Managed signals | £15–25/mo | Only after FCA route is resolved. Recurring revenue engine. |

Rationale: trading-tool buyers are sceptics; a cheap annual licence with a free
tier converts far better than a £500 one-off. Lifetime tier funds early cash flow.

## 2. Sales infrastructure (week 1–2, ~£0 fixed cost)

- **Merchant**: Lemon Squeezy or Gumroad (both handle UK/EU VAT as merchant of
  record — critical, don't do VAT yourself). Whop as a second storefront later;
  its trading-tools marketplace has the right audience.
- **Licensing**: Lemon Squeezy/Gumroad issue licence keys natively. v0.2 adds a
  30-second key check on startup (offline-tolerant, privacy-preserving).
- **Delivery**: private GitHub repo access per licence (or zip download).
  Docs already written (SETUP.md is the manual).
- **Landing page**: one page — the equity curve chart, the three rules, the
  honest numbers (14.9% CAGR / −25% worst drawdown / 70-year backtest), FAQ,
  risk warning, buy button. Host on Carrd/GitHub Pages.

## 3. Marketing (weeks 2–8)

Positioning: **"The anti-hype bot. Two trades a year. Seventy years of evidence."**
The honest-numbers angle is the differentiator in a market drowning in fake
Lambo screenshots — and it is also what keeps marketing compliant.

Channels, in order of expected ROI:
1. **Content**: write up the research (docs/RESEARCH.md is 80% of a viral post —
   especially "why RSI-2 loses money on T212"). Post to r/UKInvesting,
   r/algotrading, Hacker News, Medium. These communities reward negative results
   and cost honesty.
2. **YouTube walkthrough**: "I built a momentum bot for my £500 T212 account —
   here's 70 years of backtest" — screen-record setup → demo trade.
3. **T212 community** (forum, subreddit, Discord): the API is new and
   underserved; being *the* polished open-core T212 bot is a land grab.
4. **SEO**: "Trading 212 API bot", "Trading 212 automation" have buyer intent
   and almost no supply.
5. Publish the Lite tier on GitHub public → stars → inbound.

## 4. Operations & support

- Support: email + a private Discord for licence holders (also your community moat).
- Refunds: 14-day no-questions (required for UK consumer distance selling anyway).
- Updates: monthly patch cadence; strategy parameters never change silently —
  changelog discipline builds trust.
- Metrics to watch: Lite→paid conversion (target 3–5%), churn on annual renewal,
  support tickets per user (target <0.3).

## 5. Financial projection (conservative)

| Month | Lite users | Paid | MRR-equivalent |
|---|---|---|---|
| 1–2 | 100 | 5 | ~£25 |
| 3–6 | 500 | 30 | ~£150 |
| 7–12 | 1,500 | 100 | ~£500 |

Break-even is immediate (fixed costs ≈ £0); the constraint is marketing effort,
not capital. The £500 trading account doubles as the **public live track record**
— publish its monthly statements; verified live performance is the single
strongest sales asset in this niche.

## 6. Roadmap

- **v0.1 (done)**: strategy engine, T212 execution, signal mode, risk guards, tests, docs
- **v0.2**: licence-key check, equity-curve chart artifact, Windows one-click installer
- **v0.3**: conservative preset, weekly crash-check option, more universes (QQQ/EFA UCITS equivalents), Discord webhooks
- **v0.4**: simple web dashboard (status + history), multi-account
- **Phase 3**: FCA-clean signal subscription (authorisation or AR partnership); hosted SaaS evaluation

## 7. Risks

| Risk | Mitigation |
|---|---|
| T212 changes/kills the beta API | Data layer and executor are modular; add IBKR/Alpaca adapters (also widens the market) |
| Strategy has a bad year → refund wave / reputation | Honest marketing sets expectations (−25% DD is *in the sales page*); annual pricing spreads the relationship across regimes |
| FCA perimeter creep (e.g. marketing reads as advice) | Software-tool framing, no per-trade calls in public marketing, solicitor review of the landing page |
| Clones (it's 600 lines of Python) | The moat is the research, live track record, community and support — publish Lite, sell trust |
