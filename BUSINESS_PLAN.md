# Business Plan: Script-Assisted Reselling (eBay + Vinted)

**Owner profile:** Full-time employed (8–4), 5–10 hrs/week, £500–1,000 working capital for stock, IT/scripting background, knows PC hardware and fitness gear. Happy to pack and post; sells direct to buyers. Goal: £200–2,000/month profit within 12 months.

*(Previous iterations — laser-cut design files, paid admin tools — are in git history. This plan supersedes them.)*

---

## 1. The Model

Buy underpriced items online, resell them properly on eBay (and Vinted where it fits). The classic flipping business — but with two edges most resellers don't have:

1. **Automated sourcing.** Scripts watch the market 24/7 and ping your phone when something mispriced appears. Everyone else refreshes eBay manually at lunch; your bots do it every 10 minutes while you're at work. Sourcing is 80% of this game, and it's the part that automates best.
2. **Niche knowledge.** You know PC hardware and fitness gear. Knowing that a "PC no display, for parts" listing is probably a reseated-RAM or BIOS-reset fix, or that a "garmin watch spares repairs" just needs a £12 strap, is exactly the information gap flipping profits live in.

### Why this fits your constraints

| Requirement | How it fits |
|---|---|
| Works around 8–4 | Bots watch listings during the day; you review alerts and click buy from your desk/phone. Packing is a batched evening task. |
| £500–1,000 capital | Ideal range. Spread across 15–30 items at £15–50 each — enough to learn fast, no single mistake hurts. |
| 5–10 hrs/week | ~2 hrs sourcing/buying (mostly reacting to alerts), ~2–3 hrs listing and packing, at 10–25 flips/month. |
| Light async contact | Buyer messages are async; templates handle most. No calls, no brand-building. |
| Scripting skills | eBay's developer APIs are free. Sourcing scanners, sold-price comps, and relist automation are weekend PowerShell projects. |
| "I can add more money" | Capital compounds: profits recycle into stock. £750 at ~40% net margin turned ~1.5×/month grows fast if you keep reinvesting. |

---

## 2. What to Flip

**Rule: small, testable, brand-name items with liquid demand and a price you can verify from sold listings.**

- **PC hardware (primary niche):** GPUs, CPUs, RAM, SSDs, mechanical keyboards, mice, PSUs, retro parts. The most liquid used-goods category there is, with model numbers that make comps exact. Two plays are especially strong for you:
  - **"Faulty / no display / untested" listings** — a huge share are trivially fixable (reseat RAM, clear CMOS, new CR2032, driver DDU, PSU swap for testing). You can diagnose from the listing photos; other bidders can't.
  - **Part-outs** — buy a whole "old gaming PC" cheap, sell the GPU, CPU, RAM and case separately. The parts routinely total 1.5–2× the whole-system price. Highest profit-per-flip play in the niche.
  - Cautions: GPUs are the scam-magnet category on both sides — photograph serials before shipping, always tracked and signed-for above £80. Avoid full towers unless local pickup (courier damage + cost); parts post cheap, systems don't.
- **Fitness tech & gear:** Garmin/Polar/Suunto watches, heart-rate straps, smart scales, Concept2 accessories. High brand loyalty, constant demand, small parcels, and "untested/spares" listings are routinely fine or trivially fixable.
- **Clothing (secondary lane, Vinted-first):** viable *only* as a narrow brand whitelist you actually know — gym/outdoor labels hold value (Gymshark, Lululemon, Nike, Patagonia, Arc'teryx, Carhartt). Vinted's 0% seller fees offset clothing's weaknesses (low value density, returns, fakes). Run it as a capped experiment: £100 of the pot, 10–15 items, and let the ledger decide if it earns a bigger share. Don't touch hyped trainers or designer — authentication risk isn't worth it.
- **General "badly listed" plays (any category you can verify):** misspelled titles ("Gramin", "Legion 5 pro" typos, "i7 12700kf" formatting mangles), wrong categories, auctions ending 3am Tuesday, terrible photos. These sell under market *because buyers can't find them* — your bots can.

**Avoid:** anything you can't authenticate (hyped trainers, designer goods), large/heavy items unless collection-only bargains (couriers eat the margin), untested items you don't know how to test.

**Target per flip:** buy £15–50, sell £30–100, **net £10–30 profit after fees and postage**, minimum 30% net margin or you pass. Volume goal by month 4–6: 20–30 flips/month = £250–600/month profit.

---

## 3. The Automation Layer (your moat)

Build in this order — each is a small standalone script, and this repo is where they live:

1. **Sold-comp checker** (week 1): given a search term, pull recent eBay sold prices → median, range, sell-through. This is your buy/no-buy decision tool. Never buy without comps.
2. **Deal scanner** (weeks 2–3): scheduled job hitting the eBay Browse API every 10–15 min for your saved searches (niche keywords + "spares repairs", "untested", "job lot") with price-below-threshold filters → pushes alerts to Telegram/ntfy with a one-click buy link. First mover on an underpriced Buy-It-Now wins; bots are first movers.
3. **Misspelling generator** (week 3): feed it brand names, it expands to typo variants and searches those too. Decades-old trick, still works, because typos never stop.
4. **Ending-soon auction watcher** (week 4): auctions in your niches ending at low-traffic hours with low bids → alert 15 min before end.
5. **Listing helper** (later): template-based listing creation, and 30-day relist/reprice sweep for stale stock.

### Extending sourcing beyond eBay

Yes — and multi-site is where the edge compounds, because cross-platform price gaps are bigger than within-eBay ones. Add sources in this order (easiest/most reliable first):

| Source | How | Value |
|---|---|---|
| **CeX** | Unofficial but stable price API, widely used | Not a sourcing site — a **profit floor**. CeX buys used PC hardware at published prices; anything your scanner finds below CeX's buy-price is near-guaranteed profit. Bake it into the comp checker as an automatic "worst-case exit" column. |
| **hotukdeals** | RSS feeds + keyword alerts | Community-spotted clearance/price-glitch deals on new hardware; script filters for your niches. Trivial to integrate. |
| **Amazon Warehouse / clearance pages** | Scheduled page checks for target models | "Used - Like New" GPUs/peripherals periodically drop below eBay used prices. |
| **Vinted** | Unofficial API endpoints (the app's own JSON), scriptable with session cookies | Main lane for the clothing whitelist, and surprisingly good for fitness tech. Poor search UX on Vinted = more mispriced listings. Unofficial: expect occasional breakage, keep request rates human-speed. |
| **Gumtree / Freecycle / local** | Page scraping + keyword alerts | Where part-out PCs live ("gaming pc for sale no time wasters"). Collection-only means less competition from other resellers. |
| **Facebook Marketplace** | Hardest: aggressive anti-bot, no API | Best part-out bargains, worst automation target. Realistic approach: saved searches + FB's own alerts rather than scraping; treat it as manual-with-notifications, not a bot lane. |

Honesty note: only eBay offers an *official* API. The others range from tolerated-unofficial (CeX, Vinted) to actively-hostile (Facebook). Keep scrapers polite (low frequency, cache results, back off on errors) — the goal is a quiet personal alerting tool, not a crawler. Worst case is a blocked IP or broken script, so never build the business on a single source, and never automate *buying*, only alerting.

Total tooling cost: £0. eBay developer account is free; Telegram/ntfy push is free.

---

## 4. Roadmap

### Weeks 1–2: Sell before you buy
- List 10–20 things you already own and don't need (everyone has £200+ of this). Zero-risk practice at photos, pricing, packing, buyer messages — and it builds the feedback score you need before buyers trust you with £80 items. Also builds a packaging stash.
- Register as an **eBay business seller** from the outset (reselling for profit = business, and eBay now reports seller data to HMRC — do it clean from day one).
- Build script #1 (sold-comp checker).

### Weeks 3–6: First stock cycle (deploy ~£300 of the £750)
- Deal scanner live. Buy 10–15 items, strictly within your niches, strictly comp-verified, 30%+ margin rule.
- Expect 2–3 duds — that's tuition, and it's why the first cycle is only £300.
- Photograph well (daylight + plain background beats 90% of eBay), describe honestly including flaws (honest flaw descriptions *reduce* returns).

### Months 2–3: Full deployment
- All capital working. Refine scanner filters based on what actually sold fast vs sat.
- Batch operations: list Sundays, pack Tue/Thu evenings, drop parcels on the way to work.
- Track everything in a simple ledger (spreadsheet or script): buy price, fees, postage, net profit, days-to-sell per item. Kill any category with slow turns.

### Months 4–12: Compound
- Reinvest all profit until stock pot hits £2,000–3,000 — at ~40% net margin and monthly-ish turns, that's the £500–1,000/month profit zone.
- Scale what the ledger says works; add adjacent niches with the same playbook.
- If volume becomes the bottleneck (packing >3 hrs/week), *then* consider FBA/consolidation — not before.

---

## 5. Money

**Realistic trajectory (net profit, after fees/postage/duds):**

| Period | Expectation |
|---|---|
| Month 1 | ~£50–100 (own-stuff sales; learning) |
| Months 2–3 | £100–250/mo |
| Months 4–6 | £250–500/mo |
| Months 7–12 | £400–800/mo, capital-dependent |

**Cost structure per sale:** eBay business fees ~13% + ~£0.30, postage £2–4 (Royal Mail 48 via eBay labels), packaging pennies if you hoard boxes. Vinted (0% seller fees) for anything that fits its categories.

**Fixed costs: ~£0/month.** Capital is tied up in stock, not spent.

---

## 6. Rules, Risks & Compliance

| Risk | Mitigation |
|---|---|
| Buyer scams / "item not as described" | Photograph serials before shipping, tracked postage always, described-flaws honesty. Budget ~5% of revenue for returns/losses — it's a cost of business, not a crisis. |
| Dud purchases | £300 first cycle, comp-check discipline, niches you can actually test. |
| Stale stock (cash trapped) | 30-day reprice rule, ledger tracks days-to-sell, take the small loss and recycle capital — dead stock is worse than a 10% loss. |
| Fakes | Stick to categories you can authenticate; clothing only within the brand whitelist; avoid trainers/designer entirely. |
| Scraper breakage / blocks on unofficial sources | eBay API is the reliable backbone; other sources are bonus lanes. Low request rates, alert-only automation, expect to patch scripts occasionally. |
| Time creep | Hard cap: if it exceeds ~10 hrs/week, raise minimum profit-per-flip (fewer, better flips) rather than working more. |
| **HMRC** | Register as self-employed once past £1,000/year turnover (you will be, quickly). File self-assessment. eBay auto-reports to HMRC — being registered *before* they notice is the cheap option. Keep the ledger; profits are what's taxed. |
| Platform dependence | Feedback score is the asset; protect it. Vinted/FB Marketplace as secondary rails. |

---

## 7. Milestones

| When | Target |
|---|---|
| Week 2 | Business account live, 10+ own items listed, comp-checker script working |
| Week 6 | Deal scanner alerting to phone, first 10 flips bought |
| Month 3 | Full £750 deployed, ledger running, £150+/mo profit |
| Month 6 | £250–500/mo, stock pot grown past £1,500 via reinvestment |
| Month 12 | £400–800/mo at ≤10 hrs/week, sourcing ~90% automated |

**First action:** list something you already own tonight. The scripts make this business good, but the first sale makes it real.
