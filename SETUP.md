# Setup — from zero to scanning

Follow in order. Part A is accounts (do these first, some have small waits),
Part B is the PC, Part C is the always-on scanner, Part D is the business itself.

---

## Part A — Accounts (~30 min total)

### A1. eBay selling account
- [ ] If you don't have one, create an eBay account and complete seller registration.
- [ ] Register as a **business seller** (Account settings → convert to business
      account). Reselling for profit is business selling — doing this from day
      one keeps you clean with both eBay and HMRC (eBay reports seller data to
      HMRC automatically).
- [ ] Add your payout bank details and verify identity when prompted.

### A2. eBay developer account (for the scanner + deal finder)
- [ ] Sign up at [developer.ebay.com](https://developer.ebay.com) (free, separate
      from your selling account; approval is usually instant, occasionally a day).
- [ ] Go to **Your Account → Application Keys** and create a **Production** keyset.
- [ ] Note the two values you need:
      - **App ID (Client ID)** → `ebay.clientId` in config
      - **Cert ID (Client Secret)** → `ebay.clientSecret` in config
- [ ] Free tier is 5,000 Browse API calls/day — a dozen searches every 15 min
      uses ~1,200, so there's plenty of headroom.

### A3. Phone alerts (2 min, no account needed)
- [ ] Install the **ntfy** app ([ntfy.sh](https://ntfy.sh), iOS/Android).
- [ ] Subscribe to a topic with a hard-to-guess name, e.g. `flips-k7m2x9q4`
      (anyone who knows the topic name can read it — make it random).
- [ ] Put the same topic name in `alerts.ntfyTopic` in config.

### A4. HMRC (when trading starts, not today)
- [ ] Once your *turnover* passes £1,000/year (it will, quickly), register as
      self-employed at gov.uk and file self-assessment. The ledger in this
      toolkit is your record; profits are what's taxed. Registering before
      HMRC writes to you is the cheap, calm option.

---

## Part B — Your PC (~20 min)

Works on Windows, Linux, or macOS. Windows shown.

- [ ] **Install PowerShell 7** — in a terminal:
      `winget install Microsoft.PowerShell`
      (or download from Microsoft's PowerShell releases page). Windows'
      built-in "Windows PowerShell 5.1" is not enough.
- [ ] **Install git** if needed: `winget install Git.Git`
- [ ] **Get the code:**
      ```powershell
      git clone https://github.com/tech-ernest/Pwsh.git
      cd Pwsh
      git checkout claude/automated-business-idea-3vjy3n   # until merged to main
      ```
- [ ] **Allow local scripts** (once, Windows only):
      ```powershell
      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
      ```
- [ ] **Create your config:**
      ```powershell
      Copy-Item config/settings.sample.json config/settings.json
      notepad config/settings.json
      ```
      Fill in `ebay.clientId`, `ebay.clientSecret`, `alerts.ntfyTopic`, and
      edit the `searches` list to what you actually hunt. This file is
      gitignored — your keys stay on your machine.
- [ ] **Prove the offline logic works:**
      ```powershell
      pwsh -File tests/Run-Tests.ps1        # expect: 27 passed, 0 failed
      ```
- [ ] **First live smoke test** (this is the part the build environment
      couldn't reach the internet to verify — if anything errors here,
      capture the message):
      ```powershell
      Import-Module ./FlipKit
      Get-EbaySoldComps 'rtx 3060 12gb'                 # sold comps from eBay
      Get-CexPrice 'rtx 3060'                           # CeX floor prices
      Test-FlipDeal -SearchTerm 'rtx 3060 12gb' -BuyPrice 140   # full verdict
      Send-FlipAlert -Title 'FlipKit test' -Message 'hello'     # phone buzzes
      pwsh -File scripts/Invoke-DealScan.ps1 -DryRun    # full scan, prints hits
      ```
- [ ] **Start the app:**
      ```powershell
      pwsh -File app/Start-FlipKitApp.ps1               # opens localhost:8321
      ```
- [ ] **Schedule the scanner on this PC** (elevated PowerShell):
      ```powershell
      pwsh -File scripts/Register-DealScanTask.ps1      # every 15 min while PC is on
      ```

You are now operational: alerts while the PC is awake, app on demand.

---

## Part C — Always-on scanner (optional upgrade, ~£0–60)

The good mispriced listings appear during work hours; a machine that's awake
then is the whole edge. Any of: Raspberry Pi, old laptop, cheap used mini PC.

- [ ] Install PowerShell 7 for Linux (Microsoft's apt repo — one-time, or
      `snap install powershell --classic` on Ubuntu).
- [ ] Clone the repo, copy over your `config/settings.json`.
- [ ] Add the cron entry (the register script prints it ready to paste):
      ```
      */15 * * * * pwsh -File /home/you/Pwsh/scripts/Invoke-DealScan.ps1 >> /home/you/Pwsh/data/scan.log 2>&1
      ```
- [ ] **Dashboard from your phone (optional):** install
      [Tailscale](https://tailscale.com) (free) on the box and your phone,
      run the app on the box, open `http://<box-name>:8321` from anywhere.
      Don't port-forward the app to the open internet — it has no login.

---

## Part D — The business itself (week 1, before any stock buying)

- [ ] List 10–20 things you already own on eBay. This is deliberate practice:
      photos, pricing, packing, buyer messages — and it builds the feedback
      score buyers need before they'll trust you with £80 GPUs.
- [ ] Start the packaging stash (boxes, bubble wrap — hoard, don't buy).
- [ ] Set up eBay postage: Royal Mail 48 Tracked via eBay labels is the default.
- [ ] Record every buy in the ledger from purchase #1 — the stats tab only
      tells the truth if everything goes through it.
- [ ] First stock cycle: max £300, niches you can test, `Test-FlipDeal` verdict
      obeyed every single time.

## If something breaks

| Symptom | Likely cause / fix |
|---|---|
| `Get-EbaySoldComps` returns nothing | eBay changed page markup — re-run with `-DumpHtml`, inspect `data/last-sold-page.html`, adjust `ConvertFrom-EbaySoldHtml`. |
| `Find-EbayDeals` → 401 | Wrong/expired keys, or keyset is Sandbox not Production. |
| `Get-CexPrice` errors | CeX tweaked their unofficial endpoint — check the JSON shape. |
| No phone alerts | Topic name mismatch between config and the ntfy app subscription. |
| `running scripts is disabled` | The `Set-ExecutionPolicy` step in Part B. |
| Scheduled task never fires | PC asleep — Part C is the fix. |
