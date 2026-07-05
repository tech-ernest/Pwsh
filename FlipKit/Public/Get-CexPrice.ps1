function Get-CexPrice {
    <#
    .SYNOPSIS
        Looks up CeX (webuy.com) prices for an item — your guaranteed exit.
    .DESCRIPTION
        Queries CeX's public product-search endpoint. CashBuy is what CeX pays you
        in cash for the item: anything you can buy below that number is a
        near-risk-free flip, so Test-FlipDeal uses it as the profit floor.
        Unofficial endpoint — if it breaks, check the JSON shape has changed.
    .EXAMPLE
        Get-CexPrice -Query 'rtx 3060'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Query,
        [int]$Top = 5
    )

    $boxes = $null

    # Primary: CeX's own product API. Cloudflare blocks it on some networks.
    try {
        $uri = 'https://wss2.cex.uk.webuy.io/v3/boxes?q={0}&firstRecord=1&count={1}' -f [uri]::EscapeDataString($Query), $Top
        $headers = @{
            Accept  = 'application/json, text/plain, */*'
            Origin  = 'https://uk.webuy.com'
            Referer = 'https://uk.webuy.com/'
        }
        $resp = Invoke-FlipWebRequest -Uri $uri -Headers $headers
        $boxes = ($resp.Content | ConvertFrom-Json).response.data.boxes
    }
    catch { $primaryError = $_ }

    # Fallback: the Algolia search index behind uk.webuy.com's own search box.
    # Algolia isn't bot-walled; it needs the site's two PUBLIC keys in config
    # (see README "Fixing CeX" for how to copy them from browser dev tools).
    if ($null -eq $boxes) {
        $cfg = Get-FlipConfig
        $cex = if ($cfg.PSObject.Properties['cex']) { $cfg.cex } else { $null }
        if ($cex -and $cex.algoliaAppId -and $cex.algoliaApiKey) {
            $index = if ($cex.PSObject.Properties['algoliaIndex'] -and $cex.algoliaIndex) { $cex.algoliaIndex } else { 'prod_cex_uk' }
            # CeX routes site search through its own domain (search.webuy.io),
            # which swaps the public key for a real one server-side — the
            # public key is useless against algolia.net directly. algoliaHost
            # in config overrides the default Algolia endpoint for that case.
            $aHost = if ($cex.PSObject.Properties['algoliaHost'] -and $cex.algoliaHost) { $cex.algoliaHost }
                     else { '{0}-dsn.algolia.net' -f $cex.algoliaAppId.ToLower() }
            # Same batch-queries call, URL auth and headers as the site itself.
            $aUri = 'https://{0}/1/indexes/*/queries?x-algolia-agent=Algolia%20for%20JavaScript%20(5.52.1)%3B%20Browser&x-algolia-api-key={1}&x-algolia-application-id={2}' -f
                $aHost, $cex.algoliaApiKey, $cex.algoliaAppId
            $body = ConvertTo-Json -Depth 5 -InputObject @{
                requests = @(@{ indexName = $index; params = 'query={0}&hitsPerPage={1}' -f [uri]::EscapeDataString($Query), $Top })
            }
            $aResp = Invoke-FlipAiHttpPost -Uri $aUri -Headers @{
                'Origin'  = 'https://uk.webuy.com'
                'Referer' = 'https://uk.webuy.com/'
            } -BodyJson $body
            $boxes = $aResp.results[0].hits
        }
        elseif ($primaryError) {
            throw "CeX primary API blocked and no Algolia fallback configured (see README 'Fixing CeX'). Original error: $primaryError"
        }
    }

    if (-not $boxes) {
        Write-Verbose "CeX: no results for '$Query'."
        return
    }

    foreach ($box in @($boxes | Select-Object -First $Top)) {
        # Field names differ between the wss2 API (cashPrice/exchangePrice)
        # and the Algolia records (cashPriceCalculated/exchangePriceCalculated,
        # with cashBuyPrice/exchangePrice present but zero) — take the first
        # positive value.
        $firstPositive = {
            param($names)
            foreach ($n in $names) {
                $p = $box.PSObject.Properties[$n]
                if ($p -and $p.Value -and [double]$p.Value -gt 0) { return [double]$p.Value }
            }
            $null
        }
        [pscustomobject]@{
            Name          = $box.boxName
            CexSells      = & $firstPositive @('sellPrice')
            CashBuy       = & $firstPositive @('cashPrice', 'cashPriceCalculated', 'cashBuyPrice')
            VoucherBuy    = & $firstPositive @('exchangePrice', 'exchangePriceCalculated')
            InStockOnline = if ($box.PSObject.Properties['outOfEcomStock']) { -not [bool]$box.outOfEcomStock }
                            elseif ($box.PSObject.Properties['inStockOnline']) { [bool][int]$box.inStockOnline }
                            else { $null }
            BoxId         = if ($box.PSObject.Properties['boxId']) { $box.boxId } else { $null }
        }
    }
}
