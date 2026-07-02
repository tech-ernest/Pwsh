function ConvertFrom-EbaySoldHtml {
    <#
    .SYNOPSIS
        Parses an eBay sold/completed search results page into title+price objects.
    .DESCRIPTION
        Split out from Get-EbaySoldComps so parsing is testable offline against a
        saved page. eBay tweaks its markup periodically; if this starts returning
        nothing, save a page with Get-EbaySoldComps -DumpHtml and adjust the
        patterns below.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Html)

    process {
        # Each result is an <li class="s-item ..."> block. Split on those and
        # pull title + price out of each chunk independently, so one malformed
        # listing doesn't shift every match after it.
        $chunks = [regex]::Split($Html, '<li[^>]+class="[^"]*s-item[^"]*"') | Select-Object -Skip 1

        foreach ($chunk in $chunks) {
            $titleMatch = [regex]::Match($chunk, 's-item__title[^>]*>(?:\s*<[^>]+>)*([^<]+)')
            $priceMatch = [regex]::Match($chunk, 's-item__price[^>]*>(?:\s*<[^>]+>)*\s*£\s*([\d,]+(?:\.\d{2})?)')

            if (-not ($titleMatch.Success -and $priceMatch.Success)) { continue }

            $title = [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups[1].Value.Trim())

            # eBay pads results with a "Shop on eBay" placeholder card — skip it.
            if ($title -eq 'Shop on eBay') { continue }

            [pscustomobject]@{
                Title = $title
                Price = [double]($priceMatch.Groups[1].Value -replace ',', '')
            }
        }
    }
}
