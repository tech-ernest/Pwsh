function ConvertFrom-EbaySoldHtml {
    <#
    .SYNOPSIS
        Parses an eBay sold/completed search results page into title+price objects.
    .DESCRIPTION
        Split out from Get-EbaySoldComps so parsing is testable offline against a
        saved page. Handles both eBay markups in circulation: the classic
        "s-item" list and the newer "s-card" cards. If both strategies return
        nothing, save a page with Get-EbaySoldComps -DumpHtml and adjust below.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Html)

    process {
        $results = [System.Collections.Generic.List[object]]::new()

        # Strategy 1: classic markup — <li class="s-item ..."> blocks.
        $chunks = [regex]::Split($Html, '<li[^>]+class="[^"]*s-item[^"]*"') | Select-Object -Skip 1
        foreach ($chunk in $chunks) {
            $titleMatch = [regex]::Match($chunk, 's-item__title[^>]*>(?:\s*<[^>]+>)*([^<]+)')
            $priceMatch = [regex]::Match($chunk, 's-item__price[^>]*>(?:\s*<[^>]+>)*\s*£\s*([\d,]+(?:\.\d{2})?)')
            if (-not ($titleMatch.Success -and $priceMatch.Success)) { continue }

            $title = [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups[1].Value.Trim())
            # eBay pads results with a "Shop on eBay" placeholder card — skip it.
            if ($title -eq 'Shop on eBay') { continue }

            $results.Add([pscustomobject]@{
                Title = $title
                Price = [double]($priceMatch.Groups[1].Value -replace ',', '')
            })
        }

        # Strategy 2: newer card markup — class="s-card ..." blocks with
        # s-card__title / s-card__price descendants.
        if ($results.Count -eq 0) {
            $chunks = [regex]::Split($Html, '<[^>]+class="[^"]*\bs-card\b[^"]*"') | Select-Object -Skip 1
            foreach ($chunk in $chunks) {
                $titleMatch = [regex]::Match($chunk, 's-card__title[^>]*>(?:\s*<[^>]+>)*([^<]+)')
                $priceMatch = [regex]::Match($chunk, 's-card__price[^>]*>(?:\s*<[^>]+>)*\s*£\s*([\d,]+(?:\.\d{2})?)')
                if (-not ($titleMatch.Success -and $priceMatch.Success)) { continue }

                $title = [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups[1].Value.Trim())
                if ($title -match '^(Shop on eBay|New Listing)$') { continue }

                $results.Add([pscustomobject]@{
                    Title = $title
                    Price = [double]($priceMatch.Groups[1].Value -replace ',', '')
                })
            }
        }

        $results
    }
}
