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
        [switch]$DryRun
    )

    $cfg = Get-FlipConfig
    $seenPath = Join-Path (Get-FlipDataDir) 'seen-items.json'
    # Built imperatively: emitting a HashSet from an if-expression makes
    # PowerShell enumerate it (an empty set becomes $null).
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    if (Test-Path $seenPath) {
        foreach ($id in @(Get-Content -Raw $seenPath | ConvertFrom-Json)) { [void]$seen.Add([string]$id) }
    }

    $hits = [System.Collections.Generic.List[object]]::new()
    # Circuit breaker: when CeX is unreachable (bot-walled networks), fail once
    # and skip it for the rest of the run instead of paying retry+backoff per item.
    $cexAvailable = $true

    foreach ($search in $cfg.searches) {
        Write-Verbose "Scanning: $($search.name) — '$($search.query)' under £$($search.maxPrice)"

        $buyingOptions = if ($search.PSObject.Properties['buyingOptions'] -and $search.buyingOptions) { $search.buyingOptions } else { 'FIXED_PRICE' }

        $findParams = @{ Query = $search.query; MaxPrice = $search.maxPrice; BuyingOptions = $buyingOptions }
        if ($search.PSObject.Properties['minPrice'] -and $search.minPrice) { $findParams.MinPrice = $search.minPrice }
        if ($search.PSObject.Properties['categoryIds'] -and $search.categoryIds) { $findParams.CategoryIds = $search.categoryIds }

        $items = try {
            Find-EbayDeals @findParams
        }
        catch {
            Write-Warning "Search '$($search.name)' failed: $_"
            continue
        }

        foreach ($item in @($items)) {
            $isNew = if ($DryRun) { -not $seen.Contains($item.ItemId) } else { $seen.Add($item.ItemId) }
            if (-not $isNew) { continue }

            $note = ''
            # Optional CeX floor check per search: flags near-risk-free buys.
            if ($cexAvailable -and $search.PSObject.Properties['cexQuery'] -and $search.cexQuery) {
                try {
                    $cex = @(Get-CexPrice -Query $search.cexQuery -Top 1)
                    if ($cex -and $item.Price -lt $cex[0].CashBuy) {
                        $note = 'BELOW CeX cash £{0}!' -f $cex[0].CashBuy
                    }
                }
                catch {
                    $cexAvailable = $false
                    Write-Verbose "CeX unreachable — skipping CeX checks for the rest of this scan. ($_)"
                }
            }

            $hits.Add([pscustomobject]@{
                Search    = $search.name
                Title     = $item.Title
                Price     = $item.Price
                Condition = $item.Condition
                Url       = $item.Url
                Note      = $note
            })
        }

        # Small pause between searches — polite pacing, and spreads API quota.
        Start-Sleep -Seconds 2
    }

    if (-not $DryRun) {
        if ($hits.Count -gt 0) { Send-FlipRankedAlerts -Hits $hits -Config $cfg }

        # Keep the seen-cache bounded; oldest entries fall off the front.
        $keep = [string[]]@($seen) | Select-Object -Last 5000
        ConvertTo-Json $keep | Set-Content -Path $seenPath
    }

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

    $aiReady = $null -ne (& { try { Get-FlipAiConfig } catch { $null } })

    $ranked = $null
    if ($aiReady) {
        try { $ranked = @(Invoke-FlipTriage -Hits $Hits) }
        catch { Write-Warning "AI ranking failed, alerting unranked: $_" }
    }

    if ($ranked) {
        $worthAlerting = @($ranked | Where-Object { $_.Tier -ne 'skip' } |
            Sort-Object -Property @{ Expression = { $_.Tier -eq 'hot' }; Descending = $true }, @{ Expression = 'EstNetProfit'; Descending = $true })

        foreach ($h in @($worthAlerting | Select-Object -First $max)) {
            $tag = if ($h.Tier -eq 'hot') { '🔥 HOT' } else { '👀 Look' }
            Send-FlipAlert -Priority $(if ($h.Tier -eq 'hot') { 5 } else { 4 }) `
                -Title "$tag est £$($h.EstNetProfit): asking £$($h.Price)" `
                -Message "$($h.Title)`nest resale £$($h.EstResale) · fix: $($h.FixDifficulty)`n$($h.Note)" `
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
            if ($h.Note) { $msg += " — $($h.Note)" }
            Send-FlipAlert -Title "$($h.Search): £$($h.Price)" -Message "$($h.Title)`n$msg" -Url $h.Url
        }
        if ($Hits.Count -gt $max) {
            Send-FlipAlert -Priority 2 -Title "Scan: $($Hits.Count - $max) more hit(s) not alerted" `
                -Message 'Over the per-scan alert cap — open the FlipKit app Scanner tab to review.'
        }
    }
}
