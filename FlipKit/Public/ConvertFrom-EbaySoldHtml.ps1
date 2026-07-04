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

        # Strategy 3: eBay's minified/unified markup (unquoted attributes,
        # Marko components, no s-item/s-card classes). Class-agnostic: split
        # on the one invariant — each listing links to /itm/<id> — then pull
        # the first price from each card's block. A card usually yields two
        # chunks (image link + title link); we keep whichever has the price.
        if ($results.Count -eq 0) {
            $done = [System.Collections.Generic.HashSet[string]]::new()
            $chunks = [regex]::Split($Html, 'href="?https?://www\.ebay\.[a-z.]+/itm/') | Select-Object -Skip 1
            foreach ($chunk in $chunks) {
                $idMatch = [regex]::Match($chunk, '^(\d{9,15})')
                if (-not $idMatch.Success -or $done.Contains($idMatch.Groups[1].Value)) { continue }

                $slice = if ($chunk.Length -gt 4000) { $chunk.Substring(0, 4000) } else { $chunk }
                $priceMatch = [regex]::Match($slice, '£\s*([\d,]+(?:\.\d{2})?)')
                if (-not $priceMatch.Success) { continue }

                $title = ''
                $t = [regex]::Match($slice, 'su-styled-text[^>]*>\s*([^<]{10,150}?)\s*<')
                if (-not $t.Success) { $t = [regex]::Match($slice, 'alt="([^"]{10,150})"') }
                if (-not $t.Success) { $t = [regex]::Match($slice, '>\s*([^<>]{15,150}?)\s*</') }
                if ($t.Success) { $title = [System.Net.WebUtility]::HtmlDecode($t.Groups[1].Value.Trim()) }
                if ($title -eq 'Shop on eBay') { continue }

                [void]$done.Add($idMatch.Groups[1].Value)
                $results.Add([pscustomobject]@{
                    Title = $title
                    Price = [double]($priceMatch.Groups[1].Value -replace ',', '')
                })
            }
        }

        $results
    }
}
