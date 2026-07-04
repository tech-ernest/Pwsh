# Pwsh — FlipKit

PowerShell toolkit for the reselling business described in [BUSINESS_PLAN.md](BUSINESS_PLAN.md): script-assisted sourcing on eBay with CeX price floors, phone alerts, and a flip ledger.

**The rule the tooling enforces: bots find, you buy.** Everything here is alert-only automation.

## What's in the box

| Function | What it does |
|---|---|
| `Get-EbaySoldComps 'rtx 3060 12gb'` | Sold-price stats (median, quartiles, range) — the buy/no-buy backbone |
| `Get-CexPrice 'rtx 3060'` | CeX prices; **CashBuy is your guaranteed exit** — buy below it and you can't really lose |
| `Test-FlipDeal -SearchTerm 'rtx 3060 12gb' -BuyPrice 140` | The decision engine: comps + fees + CeX floor → `BUY` / `RISKY` / `PASS` |
| `Find-EbayDeals -Query 'garmin' -MaxPrice 40` | Live listings under a price cap (official Browse API, newest first) |
| `New-MisspellingList 'garmin'` | Typo variants for badly-listed-item hunting |
| `Send-FlipAlert` | Push to your phone via ntfy (zero setup) or Telegram |
| `Add-FlipLedgerEntry` / `Complete-FlipLedgerEntry` / `Get-FlipLedgerStats` | The business's memory: profit, margins, days-to-sell, capital deployed, per category |
| `Invoke-FlipScan` / `scripts/Invoke-DealScan.ps1` | The scan loop: every saved search in config, alerts only on new listings |
| `app/Start-FlipKitApp.ps1` | **The interactive app** — local web dashboard over all of the above |

## The app

```powershell
pwsh -File app/Start-FlipKitApp.ps1     # opens http://localhost:8321
```

A dependency-free local dashboard (pure PowerShell HTTP server + one HTML page, localhost-only):

- **Deal checker** — type a model + buy price, get the BUY / RISKY / PASS verdict with comps, margins, and the CeX floor
- **Scanner** — run all saved searches on demand (dry run or live-with-alerts), then **Triage with Claude**: hits grouped into Hot / Worth a look / Skip by estimated net profit and repair difficulty
- **Ledger** — record purchases, mark items sold, see open stock at a glance
- **Stats** — profit tiles, net profit by category, days-to-sell — the "what deserves more capital" view
- **Market** — live supply/price pulse for any keyword, and Claude-suggested new search lanes checked against real eBay volume
- **Chat** — Claude as business copilot, with your live ledger, stats, and searches as context
- **Typos** — misspelling variants as chips that click straight through to eBay searches

Tabs are bookmarkable (`/#stats`). Light and dark mode follow your system.

### AI features (Chat, Triage, Suggest) — free by default

The AI backend is configurable via the `ai` section in `config/settings.json`. Three options:

**Ollama — free, local, private (recommended).** Install from [ollama.com](https://ollama.com), then:
```powershell
ollama pull llama3.1:8b     # or qwen2.5:14b if you have 12GB+ VRAM
```
```json
"ai": { "provider": "ollama", "model": "llama3.1:8b" }
```

**Free hosted tiers (better quality, needs a free account).** Any OpenAI-compatible API works, e.g. Groq's free tier runs Llama 3.3 70B fast:
```json
"ai": { "provider": "openai", "baseUrl": "https://api.groq.com/openai", "model": "llama-3.3-70b-versatile", "apiKey": "gsk_..." }
```
(Google Gemini's free tier also works: baseUrl `https://generativelanguage.googleapis.com/v1beta/openai`, model `gemini-2.5-flash`.)

**Claude API — paid, best quality.** Key from console.anthropic.com:
```json
"ai": { "provider": "anthropic", "model": "claude-opus-4-8", "apiKey": "sk-ant-..." }
```

Local-model caveat: an 8B model's price estimates in Triage are rougher than a frontier model's — treat them as a first-pass sort and sanity-check anything you'd actually buy.

## Setup (once, ~20 minutes)

1. **PowerShell 7+** ([install](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)).
2. **eBay API keys (free):** sign up at [developer.ebay.com](https://developer.ebay.com), create a **production** keyset. The App ID is your `clientId`, the Cert ID your `clientSecret`. Free tier is 5,000 calls/day — a 15-minute scan of a dozen searches uses ~1,200.
3. **Config:** `cp config/settings.sample.json config/settings.json`, add the keys, and edit the `searches` list to what you're hunting. This file is gitignored — keys never reach the repo.
4. **Phone alerts:** install the [ntfy](https://ntfy.sh) app, subscribe to a topic with a hard-to-guess name (e.g. `flips-e7k2m9x`), put the same name in `alerts.ntfyTopic`.
5. **Test drive:**
   ```powershell
   Import-Module ./FlipKit
   Get-EbaySoldComps 'rtx 3060 12gb'          # comps work?
   Get-CexPrice 'rtx 3060'                     # CeX floor works?
   Test-FlipDeal -SearchTerm 'rtx 3060 12gb' -BuyPrice 140
   pwsh -File scripts/Invoke-DealScan.ps1 -DryRun   # full loop, no alerts
   ```
6. **Schedule it:** `pwsh -File scripts/Register-DealScanTask.ps1` (Windows, every 15 min; prints the cron line on Linux/macOS). Needs a machine that's on during the day — an always-on mini PC / home server / Pi is ideal.

## Daily workflow

1. Phone buzzes with a hit → open the listing from the alert.
2. `Test-FlipDeal -SearchTerm '<model>' -BuyPrice <price>` → obey the verdict. **Never buy on gut.**
3. Bought? `Add-FlipLedgerEntry` the same day.
4. Sold? `Complete-FlipLedgerEntry` with the real fees/postage.
5. Before each sourcing session: `Get-FlipLedgerStats` — categories with slow turns or thin margins lose their capital.

## Ranked alerts

Scheduled scans no longer spam every hit. With an AI provider configured, new
hits are triaged first: skip-tier junk is silenced and only the top
`alerts.maxPerScan` (default 10) alert — hot deals at max priority with the
estimated net profit in the notification title. A low-priority summary tells
you how many were held back (they're always visible in the app's Scanner tab).

## Fixing CeX (if `Get-CexPrice` is Cloudflare-blocked)

CeX's site search runs on Algolia, which isn't bot-walled. One-time setup:

1. Open [uk.webuy.com](https://uk.webuy.com) in your browser, press **F12** → **Network** tab.
2. Type anything into the site's search box.
3. Click the request going to `...algolia.net...` (or `algolianet.com`), open **Headers**.
4. Copy two request-header values into `config/settings.json` → `cex`:
   - `x-algolia-application-id` → `algoliaAppId`
   - `x-algolia-api-key` → `algoliaApiKey` (this is the site's public search key, not a secret)
5. Check the request URL's `/1/indexes/<name>/query` part — if the index isn't
   `prod_cex_uk`, put the real name in `algoliaIndex`.

`Get-CexPrice` then falls back to Algolia automatically whenever the primary
API is blocked.

## Honest notes

- `Get-EbaySoldComps` reads eBay's **public sold-listings page** because the official sold-data API is approval-gated. Use it per purchase decision (human-speed), not in a loop. eBay tweaks its markup now and then — if it returns nothing, run with `-DumpHtml` and adjust `ConvertFrom-EbaySoldHtml`.
- `Get-CexPrice` uses CeX's unofficial (but long-stable) search endpoint.
- The scan loop only uses eBay's **official** Browse API, so it's the reliable backbone.
- Network calls were built against documented API shapes but need first-run validation on your machine (this repo's CI environment has no outbound access to eBay/CeX). Everything offline-testable is covered: `pwsh -File tests/Run-Tests.ps1`.

## Layout

```
FlipKit/            the module (Public/ = one function per file)
config/             settings.sample.json → copy to settings.json (gitignored)
scripts/            Invoke-DealScan.ps1 (the loop), Register-DealScanTask.ps1
tests/              offline test suite + eBay markup fixture
data/               gitignored runtime state: ledger.csv, seen-items.json
BUSINESS_PLAN.md    the plan this repo implements
```
