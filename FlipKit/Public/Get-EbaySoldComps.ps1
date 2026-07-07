function Get-EbaySoldComps {
    <#
    .SYNOPSIS
        Sold-price comps for a search term: count, median, quartiles, range.
    .DESCRIPTION
        Fetches eBay's public sold+completed listings page and summarises the
        prices. This is the buy/no-buy backbone: never buy stock without running
        this first. eBay's official sold-data API is approval-gated, so this
        reads the public search page instead — one request per call, so use it
        like a human would (per purchase decision), not in a tight loop.
    .EXAMPLE
        Get-EbaySoldComps 'rtx 3060 12gb'
    .EXAMPLE
        Get-EbaySoldComps 'garmin forerunner 245' -Raw | Sort-Object Price
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$SearchTerm,
        # Return individual sold listings instead of the stats summary.
        [switch]$Raw,
        # Save the fetched HTML next to the data dir for parser debugging.
        [switch]$DumpHtml,
        # Keep every parsed listing, including bundles/variants/faulty items
        # the relevance filter would normally drop.
        [switch]$NoFilter,
        [string]$Site = 'www.ebay.co.uk'
    )

    $uri = 'https://{0}/sch/i.html?_from=R40&_nkw={1}&_sacat=0&LH_Sold=1&LH_Complete=1&_ipg=60' -f $Site, [uri]::EscapeDataString($SearchTerm)

    # Warm-up: hit the homepage first to collect session cookies, then request
    # the search page on that session. Bare cookie-less search requests get
    # eBay's generic error page instead of results.
    $jar = Join-Path (Get-FlipDataDir) 'ebay-cookies.txt'
    try {
        Invoke-FlipWebRequest -Uri "https://$Site/" -AsBrowser -CookieJar $jar | Out-Null
        Start-Sleep -Milliseconds 800
    }
    catch { Write-Verbose "Homepage warm-up failed (continuing anyway): $_" }

    $html = (Invoke-FlipWebRequest -Uri $uri -AsBrowser -CookieJar $jar).Content

    if ($DumpHtml) {
        $dump = Join-Path (Get-FlipDataDir) 'last-sold-page.html'
        Set-Content -Path $dump -Value $html
        Write-Verbose "Saved HTML to $dump"
    }

    $items = @(ConvertFrom-EbaySoldHtml -Html $html)

    if ($items.Count -eq 0) {
        # Self-diagnose: record what eBay actually served so the failure is
        # explainable from the app UI without terminal spelunking.
        $dump = Join-Path (Get-FlipDataDir) 'last-sold-page.html'
        Set-Content -Path $dump -Value $html
        $pageTitle = [regex]::Match($html, '(?s)<title>(.*?)</title>').Groups[1].Value.Trim()
        $script:CompsDiagnosis = "eBay served '{0}' ({1} chars; s-item:{2} s-card:{3} itm-links:{4}) — page saved to data/last-sold-page.html" -f
            $pageTitle, $html.Length,
            [regex]::Matches($html, 's-item__price').Count,
            [regex]::Matches($html, 's-card__price').Count,
            [regex]::Matches($html, 'href="?https?://www\.ebay\.[a-z.]+/itm/').Count
        Write-Warning "No sold listings parsed for '$SearchTerm'. $script:CompsDiagnosis"
        return
    }
    $script:CompsDiagnosis = $null

    # eBay's sold search is fuzzy — a component search returns whole PCs,
    # laptops, Ti/Super variants and faulty units. Keep only titles that
    # genuinely match the term so the stats price the actual item.
    $script:CompsFilterNote = $null
    if (-not $NoFilter) {
        $sel = Select-FlipRelevantSolds -Items $items -SearchTerm $SearchTerm
        $extra = if ($sel.Note) { " ($($sel.Note))" } else { '' }
        if ($sel.Items.Count -gt 0 -and $sel.Items.Count -lt $items.Count) {
            $script:CompsFilterNote = 'Priced from {0} of {1} sold results — {2} off-item listings excluded (bundles, variants, faulty/parts){3}.' -f
                $sel.Items.Count, $items.Count, ($items.Count - $sel.Items.Count), $extra
            $items = $sel.Items
        }
        elseif ($sel.Items.Count -eq 0) {
            $script:CompsFilterNote = "Relevance filter matched none of $($items.Count) sold results — using all of them, treat the stats with care$extra."
        }
        elseif ($sel.Note) {
            $script:CompsFilterNote = "All $($items.Count) sold results kept$extra."
        }
    }

    if ($Raw) { return $items }

    $stats = Get-PriceStats -Prices $items.Price
    $stats | Add-Member -NotePropertyName SearchTerm -NotePropertyValue $SearchTerm -PassThru
}
