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
Assert ($items[0].Url -eq 'https://www.ebay.co.uk/itm/111') 'keeps the listing link for inspection'

Write-Host "`n== ConvertFrom-EbaySoldHtml (minified markup) =="
$html = Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures/ebay-sold-minified.html')
$items = @(ConvertFrom-EbaySoldHtml -Html $html)
Assert ($items.Count -eq 5) 'parses 5 listings from minified markup ("Shop on eBay" + duplicate /itm/ links skipped)'
Assert ($items[0].Title -eq 'NVIDIA GeForce RTX 3060 12GB GDDR6 Graphics Card & Original Box') 'decodes entities in minified titles'
Assert ($items[0].Price -eq 190.00) 'takes the item price, not the postage price that follows it'
Assert ($items[1].Price -eq 1150.00) 'thousands separators parsed; duplicate links to the same item deduped'
Assert ($items[4].Title -like 'ASUS Dual RTX 3060*') 'walks the whole page, not just the first card'
Assert ($items[0].Url -eq 'https://www.ebay.co.uk/itm/256111222333') 'builds a clean listing link from the item number'

Write-Host "`n== Comp relevance filter =="
$rel = { param($title, $term) & $module { param($t, $s) Test-FlipCompRelevant -Title $t -SearchTerm $s } $title $term }
Assert (& $rel 'NVIDIA GeForce RTX 3060 12GB GPU' 'rtx 3060') 'exact item passes'
Assert (& $rel 'GIGABYTE RTX3060 GAMING OC 12G rev 2.0' 'rtx 3060') 'tolerates RTX3060 written without a space'
Assert (-not (& $rel 'Gaming PC, Ryzen 5 5600X, RTX 3060 12GB, 32GB DDR4 3600, 1TB NVMe' 'rtx 3060')) 'whole gaming PC excluded'
Assert (-not (& $rel 'ROG ZEPHYRUS G14, RTX 3060, AMD Ryzen 9 5900HS' 'rtx 3060')) 'laptop with a CPU in the title excluded'
Assert (-not (& $rel 'Palit GeForce RTX 3060 Ti Dual 8GB GDDR6 Graphics Card' 'rtx 3060')) 'Ti variant excluded when not asked for'
Assert (& $rel 'Palit GeForce RTX 3060 Ti Dual 8GB GDDR6 Graphics Card' 'rtx 3060 ti') 'Ti passes when the search asks for Ti'
Assert (-not (& $rel 'NVIDIA GeForce RTX 3060 Ti / 3070 Founders Edition - GPU Fan Replacement (OEM)' 'rtx 3060')) 'accessory-only listing excluded'
Assert (-not (& $rel 'MSI RTX 3060 12GB - FAULTY spares or repair' 'rtx 3060')) 'faulty unit excluded for a working-item search'
Assert (& $rel 'Garmin Forerunner 245 GPS Watch - faulty, spares or repair' 'garmin faulty') 'faulty allowed when the search asks for faulty'
Assert (-not (& $rel 'Radeon RX 6600 8GB Graphics Card' 'rtx 3060')) 'unrelated model excluded'

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

$e3 = Add-FlipLedgerEntry -Item 'Typo entry' -Category 'Other' -Source 'ebay' -BuyPrice 1
Remove-FlipLedgerEntry -Id $e3.Id
$after = @(Import-Csv (Join-Path $tempRoot 'data/ledger.csv'))
Assert ($after.Count -eq 2 -and -not ($after.Id -contains "$($e3.Id)")) 'delete removes only the target row'
$delErr = $null
try { Remove-FlipLedgerEntry -Id 999 } catch { $delErr = $_ }
Assert ($null -ne $delErr) 'deleting a missing id throws'

$stats = Get-FlipLedgerStats
Assert ($stats.Summary.FlipsCompleted -eq 1) 'stats: completed count'
Assert ($stats.Summary.TotalNetProfit -eq 43.40) 'stats: total net'
Assert ($stats.Summary.OpenItems -eq 1 -and $stats.Summary.CapitalDeployed -eq 38) 'stats: open capital'
Assert ($stats.ByCategory[0].Category -eq 'PC hardware') 'stats: category breakdown'
Assert ($stats.BySource[0].Source -eq 'ebay' -and $stats.BySource[0].NetProfit -eq 43.40) 'stats: source (lane) breakdown'

Write-Host "`n== Invoke-FlipScan (mocked network) =="
$testCfg = Join-Path $tempRoot 'settings.json'
@{
    ebay     = @{ clientId = 'x'; clientSecret = 'y'; marketplaceId = 'EBAY_GB'; site = 'www.ebay.co.uk' }
    fees     = @{ feeRate = 0.13; feeFixed = 0.3; defaultPostage = 3.35 }
    rules    = @{ minMarginPct = 30 }
    alerts   = @{ ntfyTopic = ''; telegramBotToken = ''; telegramChatId = '' }
    searches = @(@{ name = 'Test search'; query = 'test'; maxPrice = 100; cexQuery = 'test'; buyingOptions = 'FIXED_PRICE' })
} | ConvertTo-Json -Depth 5 | Set-Content $testCfg
$env:FLIPKIT_CONFIG = $testCfg

& $module {
    function script:Find-EbayDeals { param($Query, $MaxPrice, $BuyingOptions, $MinPrice, $CategoryIds, $ConditionIds)
        [pscustomobject]@{ ItemId = 'v1|111|0'; Title = 'GPU A'; Price = 80.0; Condition = 'Used'; BuyingOpt = 'FIXED_PRICE'; EndsAt = ''; BidCount = $null; Url = 'https://a'; Query = $Query }
        [pscustomobject]@{ ItemId = 'v1|222|0'; Title = 'GPU B'; Price = 90.0; Condition = 'Used'; BuyingOpt = 'AUCTION'
            EndsAt = (Get-Date).ToUniversalTime().AddHours(3).ToString("yyyy-MM-ddTHH:mm:ss.fffZ"); BidCount = 3; Url = 'https://b'; Query = $Query }
    }
    # CeX blocked (the Cloudflare case) must not sink the scan
    function script:Get-CexPrice { param($Query, $Top) throw 'blocked' }
    function script:Send-FlipAlert { param($Title, $Message, $Url, $Priority) $script:AlertCount++; $script:AlertMsgs += @($Message) }
    $script:AlertCount = 0
    $script:AlertMsgs = @()
}

$dry = @(Invoke-FlipScan -DryRun)
Assert ($dry.Count -eq 2) 'dry run returns hits on first sight'
$dry2 = @(Invoke-FlipScan -DryRun)
Assert ($dry2.Count -eq 2) 'dry run does not mark items seen'

$live = @(Invoke-FlipScan)
Assert ($live.Count -eq 2) 'live run returns hits'
Assert ((& $module { $script:AlertCount }) -eq 2) 'live run sends one alert per hit'
$auctionHit = @($live | Where-Object { $_.Buying -eq 'AUCTION' })
Assert ($auctionHit.Count -eq 1 -and $auctionHit[0].EndsAt -and $auctionHit[0].BidCount -eq 3) 'auction hits carry end time and bid count'
Assert (@((& $module { $script:AlertMsgs }) | Where-Object { $_ -match 'AUCTION ends in 2h|AUCTION ends in 3h' }).Count -eq 1) 'alert message includes the auction countdown'
$live2 = @(Invoke-FlipScan)
Assert ($live2.Count -eq 0) 'second live run: everything already seen'
$alertsBefore = & $module { $script:AlertCount }
$rerun = @(Invoke-FlipScan -DryRun -IncludeSeen)
Assert ($rerun.Count -eq 2 -and -not @($rerun | Where-Object { -not $_.Seen })) 'IncludeSeen re-lists seen items, flagged'
$rerunLive = @(Invoke-FlipScan -IncludeSeen)
Assert ($rerunLive.Count -eq 2 -and ((& $module { $script:AlertCount }) -eq $alertsBefore)) 'IncludeSeen live scan does not re-alert seen items'

# An ending-soon lane keeps its own seen-keys: items already alerted by a
# newlyListed lane surface again when they enter the final-hours window.
$endCfg = Join-Path $tempRoot 'settings-ending.json'
@{
    ebay     = @{ clientId = 'x'; clientSecret = 'y'; marketplaceId = 'EBAY_GB'; site = 'www.ebay.co.uk' }
    alerts   = @{ ntfyTopic = ''; telegramBotToken = ''; telegramChatId = '' }
    searches = @(@{ name = 'Ending lane'; query = 'test'; maxPrice = 100; buyingOptions = 'AUCTION'; sort = 'endingSoonest'; endingWithinHours = 6 })
} | ConvertTo-Json -Depth 5 | Set-Content $endCfg
$env:FLIPKIT_CONFIG = $endCfg
$endingRun = @(Invoke-FlipScan)
Assert ($endingRun.Count -eq 2) 'ending-soon lane re-surfaces already-seen auctions under its own key'
$endingRun2 = @(Invoke-FlipScan)
Assert ($endingRun2.Count -eq 0) 'ending-soon lane alerts each auction only once'
$env:FLIPKIT_CONFIG = $testCfg

$hbFile = Join-Path $tempRoot 'data/last-scan.json'
Assert (Test-Path $hbFile) 'scan writes a heartbeat file'
$hb = Get-Content -Raw $hbFile | ConvertFrom-Json
Assert ($hb.At -and $null -ne $hb.Hits) 'heartbeat carries timestamp and hit count'

Write-Host "`n== Hit history =="
Assert (@(Get-FlipRecentHits).Count -eq 2) 'live scan persisted hits to history'
Set-FlipHitDismissed -ItemId 'v1|111|0'
Assert (@(Get-FlipRecentHits).Count -eq 1) 'dismiss hides a hit'
Assert (@(Get-FlipRecentHits -IncludeDismissed).Count -eq 2) 'dismissed hit still in raw history'

Write-Host "`n== Watchlist =="
& $module { $script:AlertCount = 0; $script:AlertMsgs = @() }
$soonIso = [datetime]::UtcNow.AddMinutes(10).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$oldIso  = [datetime]::UtcNow.AddHours(-3).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-FlipWatch -ItemId 'w1' -Title 'ZBook G9 cracked screen' -Url 'https://w1' -EndsAt $soonIso -MaxBid 110 -Price 80 | Out-Null
Add-FlipWatch -ItemId 'w2' -Title 'EliteBook 840 G8' -Url 'https://w2' -EndsAt $oldIso -MaxBid 60 -Price 50 | Out-Null
$watch = @(Get-FlipWatchlist)
Assert ($watch.Count -eq 1 -and $watch[0].ItemId -eq 'w1') 'watchlist lists live watches, hides long-ended ones'
Assert ($watch[0].MinutesLeft -ge 8 -and $watch[0].MinutesLeft -le 10) 'minutes-left computed'
$sent = Send-FlipWatchReminders
Assert ($sent -eq 1 -and (& $module { $script:AlertCount }) -eq 1) 'reminder fires for auction inside the window'
Assert (@(& $module { $script:AlertMsgs })[-1] -match 'final minute') 'reminder message has bidding guidance'
Assert ((Send-FlipWatchReminders) -eq 0) 'reminder fires only once per watch'
Assert (@(Get-FlipWatchlist -IncludeEnded).Count -eq 1) 'long-ended watches pruned on reminder pass'
Remove-FlipWatch -ItemId 'w1'
Assert (@(Get-FlipWatchlist).Count -eq 0) 'remove clears the watch'

Write-Host "`n== New-FlipListing (mocked AI) =="
& $module {
    function script:Get-EbaySoldComps { throw 'offline' }
    function script:Invoke-FlipAi { param($System, $Messages, $JsonSchema)
        '{"title":"HP EliteBook 840 G9 14in i5-1235U 16GB 512GB Win11 Laptop","description":"Fully working. New screen fitted.","bin_price_gbp":289.99,"floor_price_gbp":255,"keywords":["elitebook 840 g9","hp laptop 16gb"]}'
    }
}
$draft = New-FlipListing -Item 'HP EliteBook 840 G9' -Notes 'new screen'
Assert ($draft.Title -like 'HP EliteBook 840 G9*') 'listing draft returns a title'
Assert ($draft.BinPrice -eq 289.99 -and $draft.FloorPrice -eq 255) 'listing draft returns pricing'
Assert (@($draft.Keywords).Count -eq 2) 'listing draft returns keywords'
Assert ($draft.CompsNote -match 'No live sold stats') 'comps failure is labelled, not fatal'

Write-Host "`n== Find-EbayDeals filter construction (mocked HTTP) =="
& $module {
    function script:Get-EbayToken { 'fake-token' }
    function script:Invoke-RestMethod { param($Uri, $Headers) $script:CapturedUri = $Uri; [pscustomobject]@{} }
}
Find-EbayDeals -Query 'hp elitebook g8' -MaxPrice 260 -MinPrice 40 -ConditionIds '7000' -CategoryIds '177' | Out-Null
$uri = & $module { $script:CapturedUri }
Assert ($uri -like '*conditionIds%3A%7B7000%7D*') 'conditionIds lands in the API filter'
Assert ($uri -like '*category_ids=177*') 'categoryIds lands in the request'
Assert ($uri -like '*%5B40..260%5D*') 'min/max price range encoded'
Assert ($uri -like '*sort=newlyListed*') 'default sort is newlyListed'

& $module {
    function script:Invoke-RestMethod { param($Uri, $Headers)
        $script:CapturedUri = $Uri
        [pscustomobject]@{ itemSummaries = @(
            [pscustomobject]@{ itemId = 'v1|10|0'; title = 'Soon auction'; currentBidPrice = [pscustomobject]@{ value = '20.0' }
                condition = 'For parts'; buyingOptions = @('AUCTION'); bidCount = 1; itemWebUrl = 'https://s'
                itemEndDate = [datetime]::UtcNow.AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
            [pscustomobject]@{ itemId = 'v1|20|0'; title = 'Far auction'; currentBidPrice = [pscustomobject]@{ value = '25.0' }
                condition = 'For parts'; buyingOptions = @('AUCTION'); bidCount = 0; itemWebUrl = 'https://f'
                itemEndDate = [datetime]::UtcNow.AddHours(48).ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
            [pscustomobject]@{ itemId = 'v1|30|0'; title = 'Fixed price, no end date'; price = [pscustomobject]@{ value = '30.0' }
                condition = 'Used'; buyingOptions = @('FIXED_PRICE'); itemWebUrl = 'https://b' }
        ) }
    }
}
$ending = @(Find-EbayDeals -Query 'hp g9' -MaxPrice 200 -Sort endingSoonest -EndingWithinHours 6)
Assert ((& $module { $script:CapturedUri }) -like '*sort=endingSoonest*') 'endingSoonest sort lands in the request'
Assert ($ending.Count -eq 1 -and $ending[0].Title -eq 'Soon auction') 'ending window keeps only auctions closing within it'

Write-Host "`n== Get-CexPrice Algolia fallback (mocked HTTP) =="
$cexCfg = Join-Path $tempRoot 'settings-cex.json'
@{
    ebay = @{ clientId = 'x'; clientSecret = 'y'; marketplaceId = 'EBAY_GB'; site = 'www.ebay.co.uk' }
    cex  = @{ algoliaAppId = 'APPID'; algoliaApiKey = 'pubkey'; algoliaIndex = 'realindex'; algoliaHost = 'search.webuy.io' }
} | ConvertTo-Json -Depth 5 | Set-Content $cexCfg
$env:FLIPKIT_CONFIG = $cexCfg
& $module {
    function script:Invoke-FlipWebRequest { throw 'cloudflare 403' }
    function script:Invoke-FlipAiHttpPost { param($Uri, $Headers, $BodyJson)
        $script:CexUri = $Uri; $script:CexBody = $BodyJson
        # Real Algolia record shape: cashBuyPrice/exchangePrice are decoy
        # zeros; the live numbers are in the *Calculated fields.
        [pscustomobject]@{ results = @([pscustomobject]@{ hits = @([pscustomobject]@{
            boxName = 'Asus GeForce RTX 3060 Dual OC V2 12GB GDDR6'; sellPrice = 265
            cashBuyPrice = 0; exchangePrice = 0
            cashPriceCalculated = 145; exchangePriceCalculated = 177
            inStockOnline = 1; boxId = 'SGRAASU306012G07' }) })
        }
    }
}
$cexRows = @(Get-CexPrice 'rtx 3060')
Assert ($cexRows.Count -eq 1 -and $cexRows[0].CashBuy -eq 145) 'CashBuy taken from cashPriceCalculated, not the zero decoys'
Assert ($cexRows[0].VoucherBuy -eq 177 -and $cexRows[0].CexSells -eq 265) 'voucher/sell prices mapped'
Assert ($cexRows[0].InStockOnline -eq $true) 'online stock flag mapped from inStockOnline'
Assert ((& $module { $script:CexUri }) -like 'https://search.webuy.io/1/indexes/*') 'uses the configured search host'
Assert ((& $module { $script:CexBody }) -like '*"indexName": "realindex"*') 'queries the configured index'
$env:FLIPKIT_CONFIG = $testCfg

Write-Host "`n== Add-FlipSearch =="
$added = Add-FlipSearch -Name 'New lane' -Query 'steam deck (faulty)' -MaxPrice 150 -MinPrice 50
Assert ($added.name -eq 'New lane') 'returns the added search'
Assert (@((Get-FlipConfig).searches).Count -eq 2) 'config now has two searches'
$dupErr2 = $null
try { Add-FlipSearch -Name 'New lane' -Query 'x' -MaxPrice 1 } catch { $dupErr2 = $_ }
Assert ($null -ne $dupErr2) 'duplicate search name throws'

Write-Host "`n== Settings view/save =="
$view = Get-FlipSettingsView
Assert ($view.config.ebay.clientSecret -eq '') 'secret masked in view'
Assert ($view.secretsSet.ebayClientSecret -eq $true) 'secretsSet flag reports saved secret'
$patch = $view.config
$patch.fees.feeRate = 0.15
Save-FlipSettings -New $patch
Assert ((Get-FlipConfig).fees.feeRate -eq 0.15) 'edited value saved'
Assert ((Get-FlipConfig).ebay.clientSecret -eq 'y') 'blank secret kept existing value'
$nsErr = $null
$noSearch = [pscustomobject]@{ ebay = $patch.ebay; searches = @() }
try { Save-FlipSettings -New $noSearch } catch { $nsErr = $_ }
Assert ($null -ne $nsErr) 'refuses to save empty searches'

Write-Host "`n== Chat system prompt =="
$prompt = & $module { Get-FlipChatSystemPrompt }
Assert ($prompt -match 'FlipKit Copilot') 'prompt has persona'
Assert ($prompt -match '1 completed flips') 'prompt embeds live ledger stats'
Assert ($prompt -match 'Test search') 'prompt embeds scanner searches'
Assert ($prompt -match 'Garmin FR245') 'prompt lists open stock'

$env:FLIPKIT_CONFIG = $null
Remove-Item -Recurse -Force $tempRoot

Write-Host "`n$($script:Passed) passed, $($script:Failed) failed."
if ($script:Failed -gt 0) { exit 1 }
