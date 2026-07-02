<#
.SYNOPSIS
    The scan loop: runs every saved search from config, alerts on new hits.
.DESCRIPTION
    Meant to run on a schedule (every 10-15 min) via Task Scheduler or cron —
    see Register-DealScanTask.ps1. Remembers what it has already alerted on in
    data/seen-items.json so you only hear about genuinely new listings.

    Alert-only by design: bots find, you buy.
.EXAMPLE
    pwsh -File scripts/Invoke-DealScan.ps1
.EXAMPLE
    pwsh -File scripts/Invoke-DealScan.ps1 -DryRun   # print hits, no alerts, no state update
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../FlipKit') -Force

$cfg = Get-FlipConfig
$seenPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'data/seen-items.json'
$seen = if (Test-Path $seenPath) { [System.Collections.Generic.HashSet[string]]@(Get-Content -Raw $seenPath | ConvertFrom-Json) }
        else { [System.Collections.Generic.HashSet[string]]::new() }

$newHits = 0

foreach ($search in $cfg.searches) {
    Write-Host "Scanning: $($search.name) — '$($search.query)' under £$($search.maxPrice)"

    $buyingOptions = if ($search.PSObject.Properties['buyingOptions'] -and $search.buyingOptions) { $search.buyingOptions } else { 'FIXED_PRICE' }

    $items = try {
        Find-EbayDeals -Query $search.query -MaxPrice $search.maxPrice -BuyingOptions $buyingOptions
    }
    catch {
        Write-Warning "Search '$($search.name)' failed: $_"
        continue
    }

    foreach ($item in @($items)) {
        if (-not $seen.Add($item.ItemId)) { continue }
        $newHits++

        $msg = 'Listed at £{0} ({1})' -f $item.Price, $item.Condition

        # Optional CeX floor check per search: flags near-risk-free buys.
        if ($search.PSObject.Properties['cexQuery'] -and $search.cexQuery) {
            try {
                $cex = Get-CexPrice -Query $search.cexQuery -Top 1
                if ($cex -and $item.Price -lt $cex[0].CashBuy) {
                    $msg += ' — BELOW CeX cash £{0}!' -f $cex[0].CashBuy
                }
            }
            catch { Write-Verbose "CeX check failed: $_" }
        }

        if ($DryRun) {
            Write-Host "  [HIT] $($item.Title) — $msg`n        $($item.Url)"
        }
        else {
            Send-FlipAlert -Title "$($search.name): £$($item.Price)" -Message "$($item.Title)`n$msg" -Url $item.Url
        }
    }

    # Small pause between searches — polite pacing, and spreads API quota.
    Start-Sleep -Seconds 2
}

if (-not $DryRun) {
    # Keep the seen-cache bounded; oldest entries fall off the front.
    $keep = [string[]]@($seen) | Select-Object -Last 5000
    ConvertTo-Json $keep | Set-Content -Path $seenPath
}

Write-Host "Done. $newHits new hit(s)."
