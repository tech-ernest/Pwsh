<#
.SYNOPSIS
    Offline test suite for FlipKit — covers everything that doesn't need the network.
.DESCRIPTION
    Run: pwsh -File tests/Run-Tests.ps1
    Network functions (Get-CexPrice, Find-EbayDeals, Get-EbaySoldComps fetch,
    Send-FlipAlert) are exercised on first real use; their logic layers
    (parsing, verdict maths) are tested here with fixtures.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../FlipKit') -Force

$script:Failed = 0
$script:Passed = 0

function Assert {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Name)
    if ($Condition) { $script:Passed++; Write-Host "  ok: $Name" }
    else { $script:Failed++; Write-Host "FAIL: $Name" -ForegroundColor Red }
}

# Isolate ledger tests from real data: point the module's repo root at a temp dir.
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "flipkit-tests-$(Get-Random)"
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$module = Get-Module FlipKit
& $module { param($root) $script:RepoRoot = $root } $tempRoot

Write-Host "`n== ConvertFrom-EbaySoldHtml =="
$html = Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures/ebay-sold-sample.html')
$items = @(ConvertFrom-EbaySoldHtml -Html $html)
Assert ($items.Count -eq 6) 'parses 6 real listings (placeholder skipped)'
Assert ($items[0].Title -eq 'NVIDIA RTX 3060 12GB Graphics Card & Box') 'decodes HTML entities in titles'
Assert ($items[2].Price -eq 1150.00) 'handles thousands separators in prices'

Write-Host "`n== Price stats =="
$stats = & $module { param($p) Get-PriceStats -Prices $p } @(189.99, 195.00, 205.00, 210.50, 220.00, 1150.00)
Assert ($stats.Count -eq 6) 'stat count'
Assert ($stats.Median -eq 207.75) 'median resists the £1150 outlier'
Assert ($stats.Min -eq 189.99 -and $stats.Max -eq 1150.00) 'min/max'
Assert ($stats.P25 -lt $stats.Median -and $stats.Median -lt $stats.P75) 'quartile ordering'

Write-Host "`n== Test-FlipDeal verdicts (offline comps) =="
$comps = [pscustomobject]@{ SearchTerm = 'x'; Count = 20; Min = 150; P25 = 190; Median = 207; P75 = 215; Max = 240; Mean = 205 }

$buy = Test-FlipDeal -SearchTerm 'x' -BuyPrice 100 -Comps $comps -SkipCex -Postage 3.35 -FeeRate 0.13 -FeeFixed 0.30 -MinMarginPct 30
Assert ($buy.Verdict -eq 'BUY') 'cheap buy against strong comps = BUY'
# £190 P25: 190 - 24.7 fees - 0.30 - 3.35 postage - 100 = 61.65 net on £103.35 cost
Assert ([math]::Abs($buy.ConservativeNet - 61.65) -lt 0.01) 'conservative net maths'

$risky = Test-FlipDeal -SearchTerm 'x' -BuyPrice 132 -Comps $comps -SkipCex -Postage 3.35 -FeeRate 0.13 -FeeFixed 0.30 -MinMarginPct 30
Assert ($risky.Verdict -eq 'RISKY') 'margin clears median but not P25 = RISKY'

$pass = Test-FlipDeal -SearchTerm 'x' -BuyPrice 170 -Comps $comps -SkipCex -Postage 3.35 -FeeRate 0.13 -FeeFixed 0.30 -MinMarginPct 30
Assert ($pass.Verdict -eq 'PASS') 'thin margin = PASS'

$thin = [pscustomobject]@{ SearchTerm = 'x'; Count = 3; Min = 150; P25 = 190; Median = 207; P75 = 215; Max = 240; Mean = 205 }
$fewComps = Test-FlipDeal -SearchTerm 'x' -BuyPrice 100 -Comps $thin -SkipCex -Postage 3.35 -FeeRate 0.13 -FeeFixed 0.30 -MinMarginPct 30
Assert ($fewComps.Verdict -like 'PASS*') 'too few comps = PASS regardless of margin'

$floor = Test-FlipDeal -SearchTerm 'x' -BuyPrice 100 -Comps $comps -CexCashFloor 120 -Postage 3.35 -FeeRate 0.13 -FeeFixed 0.30 -MinMarginPct 30
Assert ($floor.Verdict -eq 'BUY (below CeX cash floor)') 'buy below CeX cash = floor verdict'
Assert ($floor.BelowCexFloor -eq $true) 'floor flag set'

Write-Host "`n== New-MisspellingList =="
$typos = @(New-MisspellingList 'garmin' -Top 50)
Assert ($typos -contains 'garmn') 'dropped letter'
Assert ($typos -contains 'garmim') 'adjacent key'
Assert ($typos -contains 'gramin') 'swapped neighbours'
Assert ($typos -notcontains 'garmin') 'original excluded'
Assert (($typos | Select-Object -Unique).Count -eq $typos.Count) 'no duplicates'

Write-Host "`n== Ledger =="
$e1 = Add-FlipLedgerEntry -Item 'RTX 3060 Zotac' -Category 'PC hardware' -Source 'ebay' -BuyPrice 140 -BuyDate '2026-06-01'
$e2 = Add-FlipLedgerEntry -Item 'Garmin FR245' -Category 'Fitness tech' -Source 'vinted' -BuyPrice 38 -BuyDate '2026-06-05'
Assert ($e1.Id -eq 1 -and $e2.Id -eq 2) 'sequential ids'

$closed = Complete-FlipLedgerEntry -Id 1 -SoldPrice 215 -Fees 28.25 -Postage 3.35 -SoldDate '2026-06-15'
Assert ([double]$closed.Net -eq 43.40) 'net profit computed'
Assert ([int]$closed.DaysToSell -eq 14) 'days to sell computed'

$dupErr = $null
try { Complete-FlipLedgerEntry -Id 1 -SoldPrice 1 -Fees 1 -Postage 1 } catch { $dupErr = $_ }
Assert ($null -ne $dupErr) 'closing twice throws'

$stats = Get-FlipLedgerStats
Assert ($stats.Summary.FlipsCompleted -eq 1) 'stats: completed count'
Assert ($stats.Summary.TotalNetProfit -eq 43.40) 'stats: total net'
Assert ($stats.Summary.OpenItems -eq 1 -and $stats.Summary.CapitalDeployed -eq 38) 'stats: open capital'
Assert ($stats.ByCategory[0].Category -eq 'PC hardware') 'stats: category breakdown'

Remove-Item -Recurse -Force $tempRoot

Write-Host "`n$($script:Passed) passed, $($script:Failed) failed."
if ($script:Failed -gt 0) { exit 1 }
