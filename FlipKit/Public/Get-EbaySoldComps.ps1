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
        Write-Warning "No sold listings parsed for '$SearchTerm'. Either nothing has sold recently or eBay's markup changed (re-run with -DumpHtml to inspect)."
        return
    }

    if ($Raw) { return $items }

    $stats = Get-PriceStats -Prices $items.Price
    $stats | Add-Member -NotePropertyName SearchTerm -NotePropertyValue $SearchTerm -PassThru
}
