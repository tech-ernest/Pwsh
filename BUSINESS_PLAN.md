# Business Plan: Paid PowerShell Admin Tools for Microsoft 365 / Intune Admins

**Owner profile:** Full-time employed (8–4), 5–10 hrs/week during setup, <£100/month budget, IT/scripting/sysadmin background. Wants low-effort, automatable income of £200–2,000/month within 12 months. Light async support only, no craft/Etsy business.

---

## 1. The Idea

Build small, polished, **paid PowerShell tools that solve painful recurring problems for Microsoft 365 / Intune / Entra ID administrators**, sold as instant digital downloads with licence keys. Marketing runs on autopilot: free scripts on GitHub + PowerShell Gallery and SEO blog posts that rank for the exact tasks admins google at work.

You are the target customer. You already know which tasks make admins swear, which is the hardest part of any product business solved for free.

### Why this wins for you specifically

| Requirement | How this fits |
|---|---|
| Low effort / automated | Digital delivery + licence keys are fully automated (Lemon Squeezy/Gumroad). Marketing funnel (SEO posts + GitHub) works while you sleep. |
| <£100/mo budget | Domain ~£10/year. Blog on Cloudflare Pages = £0. Store = £0 fixed + ~5–10% per sale. |
| 5–10 hrs/week | First product = 4–6 weeks of evenings writing PowerShell you already know how to write. Steady state = 2–4 hrs/week. |
| B2B pricing reaches the goal | £39–79 per tool, **expensed on a company card without approval**. £500/mo = ~10 sales/month. Compare: an Etsy shop needs ~150 sales for the same money. |
| Light async support | Support = email about install/licence issues. No calls, no personal brand required (a product brand name is fine). |
| Skill fit | It's literally your day-job skill set. Every tool you build also makes you better at your job. |

### Why the other three directions lose (for now)

- **Automated content + affiliate/ads:** post-2024 Google actively demotes AI-generated niche sites; 12+ months to meaningful income with high platform risk. Content is used *inside* this plan as marketing, where it doesn't need to earn money directly.
- **Reselling/arbitrage with automation:** scripts can find deals, but buying, storing, listing and shipping is a second job, not a low-effort business.
- **Fitness digital products:** selling to consumers needs an audience/personal brand; you wanted light-touch and low visibility. Park it — revisit only if you later want a content side-project.

---

## 2. What to Build (product line)

Pick pains that are: recurring, hated, and ignored or half-solved by Microsoft. Strong candidates, roughly in order:

1. **M365 Tenant Report** — one command produces a polished HTML report: licences and cost waste, MFA/CA coverage, stale accounts, mailbox sizes, admin roles, shared mailbox audit. *Buyer: every MSP tech and IT manager who needs to show something to the boss/client.*
2. **Employee Offboarding Tool** — disable account, revoke sessions, convert mailbox to shared, set forwarding/OOF, remove licences, remove from groups, transfer OneDrive, output an audit report. One of the most-googled admin tasks; getting it wrong has consequences, which is exactly when people pay.
3. **Intune Documentation & Backup** — export all Intune policies/profiles/apps to readable HTML/Markdown + JSON backup, with drift comparison between two exports. Intune admins complain about this constantly.
4. **Entra/AD Hygiene Toolkit** — stale devices/users/groups cleanup with report-first safety mode.

Rules of thumb:
- **Report-generating tools sell best** — output the buyer can forward to their boss justifies the price instantly.
- Free scripts exist for pieces of all of these. You're not selling the script; you're selling *polished, maintained, tested, one-command, with support* — that's what a business happily pays £49 to skip a day of glue work for.
- Each tool must be demoable: screenshots of the HTML report do the selling.

**Pricing:** £39–£79 per tool (one-time, current major version), MSP/multi-tenant licence at 2–3×, later a £129 all-tools bundle. Don't price under £29 — B2B buyers read cheap as untrustworthy.

---

## 3. The Automated Marketing Funnel

This is the part that makes it low-effort long-term. Three layers, all free:

1. **GitHub (free tier as bait):** publish genuinely useful free scripts — simplified single-purpose versions of your paid tools. README links to the pro version. Your existing Pwsh repo becomes the public portfolio.
2. **PowerShell Gallery:** publish the free modules there too — admins search it directly, zero competition for attention compared to Google.
3. **SEO blog (Cloudflare Pages + any static generator):** one post per week targeting long-tail queries admins type at work: "export intune configuration to html", "office 365 offboarding checklist script", "find unused m365 licenses powershell". Each post genuinely answers the question with a free script, then mentions the tool that does it all in one command. These queries have low competition and *commercial intent baked in*.

Optional accelerant: answer relevant questions on r/sysadmin, r/Intune, r/PowerShell (helpful first, link only when directly relevant). 20 min/week, and one good answer can outrank everything else you do for months.

---

## 4. Roadmap

### Month 1–2: First product (8 hrs/week)
- Week 1: pick product #1 (recommendation: **M365 Tenant Report** — broadest audience). Register a brand-y domain. Set up Lemon Squeezy (handles VAT/EU tax for you — this matters, don't use PayPal links).
- Weeks 2–6: build it. Graph API via `Microsoft.Graph` PowerShell SDK; ship as a signed module + simple installer + PDF quickstart. Test against a free M365 developer tenant.
- Weeks 7–8: landing page with report screenshots, buy button, FAQ. Publish the free lite version to GitHub + PSGallery. Write 3 launch blog posts.

### Month 3–4: Distribution (5 hrs/week)
- 1 SEO blog post/week (each with a working free script — that's what earns links and rankings).
- Post the free tool where admins gather; note which posts drive traffic.
- Expect first sales here. Single-digit months are normal; every sale at this stage validates pricing, not volume.

### Month 5–8: Second product + compounding
- Build product #2 (Offboarding Tool) using everything learned.
- Cross-sell: every tool's report footer and README links the others. Buyers of one admin tool are the best prospects for the next.
- Keep the weekly post cadence; old posts start ranking around month 4–6 — SEO compounds exactly when you'd otherwise plateau.

### Month 9–12: Bundle + steady state
- Bundle at £129, MSP licences, maybe a "new major version" paid upgrade path.
- Steady state effort: ~2–4 hrs/week (one post OR one feature + support emails).
- Target: £300–1,000/mo. £1k/mo ≈ 20 sales/month across 2–3 products and a bundle — a realistic figure for a two-product catalogue with 12 months of SEO behind it.

---

## 5. Costs

| Item | Cost |
|---|---|
| Domain | ~£10/year |
| Blog/landing hosting (Cloudflare Pages) | £0 |
| Lemon Squeezy / Gumroad | £0 fixed + ~5–10% per sale |
| M365 developer tenant (testing) | £0 |
| Code-signing cert (optional, later — buys trust) | ~£50–80/yr when revenue justifies it |
| **Total fixed** | **≈ £1–2/month** |

---

## 6. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Microsoft ships the feature natively | Pick pains MS has ignored for years (reporting polish, offboarding orchestration, Intune docs). Multi-product catalogue means no single kill-shot. |
| "Why pay? Free scripts exist" | You're selling the assembled, maintained, supported whole. Frame price against the buyer's day rate: £49 vs a day of duct tape. Some people will never pay — they were never customers. |
| Graph API / module changes break tools | Recurring maintenance is real (~monthly check). It's also your moat — free scripts rot, your product doesn't. |
| Slow start demoralises | Like any organic-traffic business, months 1–3 are quiet. Early KPI = posts published and free-tool downloads, not revenue. |
| Day-job conflict | Build on your own kit, own time, own tenant. Check your employment contract's IP/side-work clause **before launch** (UK contracts commonly claim work "related to" your role). |

---

## 7. Milestones

| When | Target |
|---|---|
| Month 2 | Product #1 shipped, store live, free lite version on GitHub + PSGallery |
| Month 3 | 6+ blog posts live, first sale |
| Month 6 | Product #2 shipped, £100–200/mo |
| Month 9 | Bundle live, 30+ posts ranking, £200–400/mo |
| Month 12 | £300–1,000/mo at 2–4 hrs/week maintenance |

**Upfront cash: ~£10.** Everything else is evenings — spent writing PowerShell, which you'd half-enjoy anyway.
