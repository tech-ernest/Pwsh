function Invoke-FlipScan {
    <#
    .SYNOPSIS
        Runs every saved search from config; ranks new hits and alerts the best.
    .DESCRIPTION
        The scan engine shared by scripts/Invoke-DealScan.ps1 (scheduled) and the
        FlipKit app's "Scan now" button. Remembers already-seen listings in
        data/seen-items.json so alerts only fire for genuinely new items.

        Alerting is capped and ranked: when an AI provider is configured, new
        hits are triaged (estimated net profit + fix difficulty), "skip"-tier
        items are suppressed, and only the top alerts.maxPerScan (default 10)
        reach your phone - hot deals at max priority with the estimated profit
        in the title. Without AI, the first maxPerScan hits alert unranked.

        Alert-only by design: bots find, you buy.
    .EXAMPLE
        Invoke-FlipScan -DryRun    # returns hits, sends nothing, updates nothing
    #>
    [CmdletBinding()]
    param(
        # Report hits without sending alerts or updating the seen-cache.
        [switch]$DryRun,
        # Also return listings the scanner has already seen (each hit carries
        # a Seen flag). Alerts and history still only fire for new ones.
        [switch]$IncludeSeen
    )

    $cfg = Get-FlipConfig
    $seenPath = Join-Path (Get-FlipDataDir) 'seen-items.json'
    # Built imperatively: emitting a HashSet from an if-expression makes
    # PowerShell enumerate it (an empty set becomes $null).
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    if (Test-Path $seenPath) {
        foreach ($id in @(Get-Content -Raw $seenPath | ConvertFrom-Json)) { [void]$seen.Add([string]$id) }
    }

    # Items the user marked "not interested" never come back — not via
    # ending-soon re-alerts, not via IncludeSeen.
    $noInterest = Get-FlipNotInterestedSet

    $hits = [System.Collections.Generic.List[object]]::new()
    # Circuit breaker: when CeX is unreachable (bot-walled networks), fail once
    # and skip it for the rest of the run instead of paying retry+backoff per item.
    $cexAvailable = $true
    # Descriptions cost one API call per item — fetch for new hits only,
    # bounded per scan. Sellers bury the real fault in the description, so
    # triage wants it.
    $descFetched = 0

    foreach ($search in $cfg.searches) {
        Write-Verbose "Scanning: $($search.name) — '$($search.query)' under £$($search.maxPrice)"

        $buyingOptions = if ($search.PSObject.Properties['buyingOptions'] -and $search.buyingOptions) { $search.buyingOptions } else { 'FIXED_PRICE' }

        # Ending-soon lanes track their own seen-keys, so an auction can alert
        # once when listed (via a newlyListed lane) and once more when it
        # enters the final-hours window — the moment that actually matters.
        $endingLane = $search.PSObject.Properties['endingWithinHours'] -and $search.endingWithinHours -and [double]$search.endingWithinHours -gt 0

        # The saved query, plus typo variants when the search opts in with
        # "typoHunt": "<brand>" — automated misspelled-listing hunting.
        # The variant is substituted INTO the original query (not used bare):
        # a bare misspelling like "armin" (from "garmin") is also a common
        # first name and floods results with unrelated books/CDs. Keeping
        # the rest of the query's context (e.g. "watch (faulty, spares...)")
        # naturally excludes that noise the same way the real word does.
        $queries = @(@{ q = $search.query; typo = $false })
        if ($search.PSObject.Properties['typoHunt'] -and $search.typoHunt) {
            $wordPattern = '(?i)\b{0}\b' -f [regex]::Escape($search.typoHunt)
            foreach ($v in @(New-MisspellingList -Word $search.typoHunt -Top 6)) {
                $typoQuery = $search.query -replace $wordPattern, $v
                $queries += @{ q = $typoQuery; typo = $true }
            }
        }

        foreach ($entry in $queries) {
            $findParams = @{ Query = $entry.q; MaxPrice = $search.maxPrice; BuyingOptions = $buyingOptions }
            if ($search.PSObject.Properties['minPrice'] -and $search.minPrice) { $findParams.MinPrice = $search.minPrice }
            if ($search.PSObject.Properties['categoryIds'] -and $search.categoryIds) { $findParams.CategoryIds = $search.categoryIds }
            if ($search.PSObject.Properties['conditionIds'] -and $search.conditionIds) { $findParams.ConditionIds = $search.conditionIds }
            if ($search.PSObject.Properties['sort'] -and $search.sort) { $findParams.Sort = $search.sort }
            if ($endingLane) { $findParams.EndingWithinHours = [double]$search.endingWithinHours }

            $items = try {
                Find-EbayDeals @findParams
            }
            catch {
                Write-Warning "Search '$($search.name)' ('$($entry.q)') failed: $_"
                continue
            }

            foreach ($item in @($items)) {
                if ($noInterest.Contains([string]$item.ItemId)) { continue }
                $seenKey = if ($endingLane) { "$($item.ItemId)|ending" } else { $item.ItemId }
                $isNew = if ($DryRun) { -not $seen.Contains($seenKey) } else { $seen.Add($seenKey) }
                if (-not $isNew -and -not $IncludeSeen) { continue }

                $note = if ($entry.typo) { "MISSPELLED title ('$($entry.q)') — low visibility, less bidding!" } else { '' }
                # Optional CeX floor check per search: flags near-risk-free buys.
                if ($cexAvailable -and $search.PSObject.Properties['cexQuery'] -and $search.cexQuery) {
                    try {
                        $cex = @(Get-CexPrice -Query $search.cexQuery -Top 1)
                        if ($cex -and $item.Price -lt $cex[0].CashBuy) {
                            $note = ('BELOW CeX cash £{0}! ' -f $cex[0].CashBuy) + $note
                        }
                    }
                    catch {
                        $cexAvailable = $false
                        Write-Verbose "CeX unreachable — skipping CeX checks for the rest of this scan. ($_)"
                    }
                }

                $description = ''
                if ($isNew -and $descFetched -lt 25) {
                    $description = try { Get-EbayItemDescription -ItemId $item.ItemId } catch { '' }
                    $descFetched++
                }

                $hits.Add([pscustomobject]@{
                    ItemId    = $item.ItemId
                    Search    = $search.name
                    Title     = $item.Title
                    Price     = $item.Price
                    Condition = $item.Condition
                    Buying    = if ($item.PSObject.Properties['BuyingOpt']) { $item.BuyingOpt } else { '' }
                    EndsAt    = if ($item.PSObject.Properties['EndsAt']) { $item.EndsAt } else { '' }
                    BidCount  = if ($item.PSObject.Properties['BidCount']) { $item.BidCount } else { $null }
                    Url       = $item.Url
                    Note      = $note.Trim()
                    Postage   = if ($search.PSObject.Properties['postage'] -and $search.postage) { [double]$search.postage } else { $null }
                    Description = $description
                    Seen      = (-not $isNew)
                    FoundAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm')
                })
            }

            # Small pause between queries — polite pacing, and spreads API quota.
            Start-Sleep -Seconds 2
        }
    }

    if (-not $DryRun) {
        # Only genuinely new hits alert and enter history, even when the
        # caller asked to see everything.
        $newHits = @($hits | Where-Object { -not $_.Seen })
        if ($newHits.Count -gt 0) {
            Send-FlipRankedAlerts -Hits $newHits -Config $cfg
            Save-FlipRecentHits -Hits $newHits
        }

        # Keep the seen-cache bounded; oldest entries fall off the front.
        $keep = [string[]]@($seen) | Select-Object -Last 5000
        ConvertTo-Json $keep | Set-Content -Path $seenPath

        # Watched auctions entering their final minutes get their reminder on
        # the back of every live scan.
        try { Send-FlipWatchReminders | Out-Null }
        catch { Write-Warning "Watchlist reminders failed: $_" }
    }

    # Heartbeat: lets the app show whether the scheduled scan is actually
    # alive — a silent scheduler death otherwise goes unnoticed for days.
    ConvertTo-Json @{
        At     = [datetime]::UtcNow.ToString('o')
        Hits   = $hits.Count
        DryRun = [bool]$DryRun
    } | Set-Content -Path (Join-Path (Get-FlipDataDir) 'last-scan.json')

    $hits
}

function Send-FlipRankedAlerts {
    <#
        Ranked, capped alerting for a batch of new scan hits.
        With AI configured: triage -> drop 'skip' tier -> sort by estimated
        net profit -> alert the top N (hot = max priority). Without AI (or if
        triage fails): alert the first N unranked. Always ends with a summary
        line when anything was suppressed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][array]$Hits,
        [Parameter(Mandatory)]$Config
    )

    $max = 10
    if ($Config.alerts.PSObject.Properties['maxPerScan'] -and "$($Config.alerts.maxPerScan)" -ne '') {
        $max = [int]$Config.alerts.maxPerScan
    }

    # "AUCTION ends in 2h 05m (Sun 17:45), 3 bids" — empty for fixed-price.
    $auctionLine = {
        param($h)
        if (-not ($h.PSObject.Properties['Buying'] -and $h.Buying -match 'AUCTION')) { return '' }
        if (-not ($h.PSObject.Properties['EndsAt'] -and $h.EndsAt)) { return 'AUCTION' }
        try {
            $end = (ConvertTo-FlipUtcDate -Value $h.EndsAt).ToLocalTime()
            $left = $end - (Get-Date)
            $rel = if ($left.TotalMinutes -le 0) { 'ended' }
                   elseif ($left.TotalHours -ge 24) { 'in {0}d {1}h' -f $left.Days, $left.Hours }
                   elseif ($left.TotalHours -ge 1) { 'in {0}h {1:mm}m' -f [math]::Floor($left.TotalHours), $left }
                   else { 'in {0}m' -f [int]$left.TotalMinutes }
            $bids = if ($h.PSObject.Properties['BidCount'] -and $null -ne $h.BidCount) { ", $($h.BidCount) bids" } else { '' }
            'AUCTION ends {0} ({1}){2}' -f $rel, $end.ToString('ddd HH:mm'), $bids
        }
        catch { 'AUCTION' }
    }

    $aiReady = $null -ne (& { try { Get-FlipAiConfig } catch { $null } })

    $ranked = $null
    if ($aiReady) {
        try { $ranked = @(Invoke-FlipTriage -Hits $Hits) }
        catch { Write-Warning "AI ranking failed, alerting unranked: $_" }
    }

    if ($ranked) {
        # Real-comps-grounded net outranks the AI's flat guess when we have it.
        $bestNet = { param($h) if ($h.PSObject.Properties['GroundedNet'] -and $null -ne $h.GroundedNet) { $h.GroundedNet } else { $h.EstNetProfit } }
        $worthAlerting = @($ranked | Where-Object { $_.Tier -ne 'skip' } |
            Sort-Object -Property @{ Expression = { $_.Tier -eq 'hot' }; Descending = $true }, @{ Expression = { & $bestNet $_ }; Descending = $true })

        foreach ($h in @($worthAlerting | Select-Object -First $max)) {
            $tag = if ($h.Tier -eq 'hot') { '🔥 HOT' } else { '👀 Look' }
            $auction = & $auctionLine $h
            $parts = if ($h.PSObject.Properties['PartsCost'] -and $h.PartsCost -gt 0) { " · parts ~£$($h.PartsCost)" } else { '' }
            $msg = "$($h.Title)`nest resale £$($h.EstResale) · fix: $($h.FixDifficulty)$parts"
            if ($h.PSObject.Properties['CompsMedian'] -and $h.CompsMedian) {
                $msg += "`nreal solds: median £$($h.CompsMedian) ($($h.CompsCount) sales) → net ~£$($h.GroundedNet)"
            }
            if ($auction) { $msg += "`n⏳ $auction" }
            if ($h.Note) { $msg += "`n$($h.Note)" }
            Send-FlipAlert -Priority $(if ($h.Tier -eq 'hot') { 5 } else { 4 }) `
                -Title "$tag est £$($h.EstNetProfit): asking £$($h.Price)" `
                -Message $msg `
                -Url $h.Url
        }

        $suppressed = $Hits.Count - [math]::Min(@($worthAlerting).Count, $max)
        if ($suppressed -gt 0) {
            Send-FlipAlert -Priority 2 -Title "Scan: $suppressed more hit(s) not alerted" `
                -Message 'Ranked below the cut or skip-tier — open the FlipKit app Scanner tab to review.'
        }
    }
    else {
        foreach ($h in @($Hits | Select-Object -First $max)) {
            $msg = 'Listed at £{0} ({1})' -f $h.Price, $h.Condition
            $auction = & $auctionLine $h
            if ($auction) { $msg += "`n⏳ $auction" }
            if ($h.Note) { $msg += " — $($h.Note)" }
            Send-FlipAlert -Title "$($h.Search): £$($h.Price)" -Message "$($h.Title)`n$msg" -Url $h.Url
        }
        if ($Hits.Count -gt $max) {
            Send-FlipAlert -Priority 2 -Title "Scan: $($Hits.Count - $max) more hit(s) not alerted" `
                -Message 'Over the per-scan alert cap — open the FlipKit app Scanner tab to review.'
        }
    }
}
