# Business Plan: Script-Assisted Reselling (eBay + Vinted)

**Owner profile:** Full-time employed (8–4), 5–10 hrs/week, £500–1,000 working capital for stock, IT/scripting background, knows fitness and laser/maker gear. Happy to pack and post; sells direct to buyers. Goal: £200–2,000/month profit within 12 months.

*(Previous iterations — laser-cut design files, paid admin tools — are in git history. This plan supersedes them.)*

---

## 1. The Model

Buy underpriced items online, resell them properly on eBay (and Vinted where it fits). The classic flipping business — but with two edges most resellers don't have:

1. **Automated sourcing.** Scripts watch the market 24/7 and ping your phone when something mispriced appears. Everyone else refreshes eBay manually at lunch; your bots do it every 10 minutes while you're at work. Sourcing is 80% of this game, and it's the part that automates best.
2. **Niche knowledge.** You know fitness gear and laser/maker equipment. Knowing that a listing titled "garmin watch spares repairs" just needs a £12 strap, or that a "laser engraver untested" is a £300 machine missing a £20 lens, is exactly the information gap flipping profits live in.

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

**Rule: small, testable, brand-name items with liquid demand and a price you can verify from sold listings.** Your two niches both qualify:

- **Fitness tech & gear:** Garmin/Polar/Suunto watches, heart-rate straps, smart scales, Concept2 accessories, quality brands (Eleiko, Rogue) accessories. High brand loyalty, constant demand, small parcels, and "untested/spares" listings are routinely fine or trivially fixable.
- **Laser/maker equipment:** used engraver parts and accessories (lenses, modules, rotary attachments, air assists), 3D-printer parts, brand-name hand tools. You can test, describe accurately, and photograph competently — which instantly beats the seller you bought from.
- **General "badly listed" plays (any category you can verify):** misspelled titles ("Gramin", "Dyston"), wrong categories, auctions ending 3am Tuesday, terrible photos. These sell under market *because buyers can't find them* — your bots can.

**Avoid:** clothing at the start (returns, fakes, low value density — Vinted later maybe), anything you can't authenticate (trainers, designer goods), large/heavy items (couriers eat the margin), untested items you don't know how to test.

**Target per flip:** buy £15–50, sell £30–100, **net £10–30 profit after fees and postage**, minimum 30% net margin or you pass. Volume goal by month 4–6: 20–30 flips/month = £250–600/month profit.

---

## 3. The Automation Layer (your moat)

Build in this order — each is a small standalone script, and this repo is where they live:

1. **Sold-comp checker** (week 1): given a search term, pull recent eBay sold prices → median, range, sell-through. This is your buy/no-buy decision tool. Never buy without comps.
2. **Deal scanner** (weeks 2–3): scheduled job hitting the eBay Browse API every 10–15 min for your saved searches (niche keywords + "spares repairs", "untested", "job lot") with price-below-threshold filters → pushes alerts to Telegram/ntfy with a one-click buy link. First mover on an underpriced Buy-It-Now wins; bots are first movers.
3. **Misspelling generator** (week 3): feed it brand names, it expands to typo variants and searches those too. Decades-old trick, still works, because typos never stop.
4. **Ending-soon auction watcher** (week 4): auctions in your niches ending at low-traffic hours with low bids → alert 15 min before end.
5. **Listing helper** (later): template-based listing creation, and 30-day relist/reprice sweep for stale stock.

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
| Fakes | Stick to categories you can authenticate; avoid trainers/designer entirely. |
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
