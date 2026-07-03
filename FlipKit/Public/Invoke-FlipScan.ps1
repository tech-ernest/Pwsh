function Invoke-FlipScan {
    <#
    .SYNOPSIS
        Runs every saved search from config; returns hits and (optionally) alerts on new ones.
    .DESCRIPTION
        The scan engine shared by scripts/Invoke-DealScan.ps1 (scheduled) and the
        FlipKit app's "Scan now" button. Remembers already-seen listings in
        data/seen-items.json so alerts only fire for genuinely new items.
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

        $items = try {
            Find-EbayDeals -Query $search.query -MaxPrice $search.maxPrice -BuyingOptions $buyingOptions
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

            $hit = [pscustomobject]@{
                Search    = $search.name
                Title     = $item.Title
                Price     = $item.Price
                Condition = $item.Condition
                Url       = $item.Url
                Note      = $note
            }
            $hits.Add($hit)

            if (-not $DryRun) {
                $msg = 'Listed at £{0} ({1})' -f $item.Price, $item.Condition
                if ($note) { $msg += " — $note" }
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

    $hits
}
