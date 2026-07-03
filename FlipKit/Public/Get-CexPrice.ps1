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

    $uri = 'https://wss2.cex.uk.webuy.io/v3/boxes?q={0}&firstRecord=1&count={1}' -f [uri]::EscapeDataString($Query), $Top

    # CeX's own site calls this API cross-origin from uk.webuy.com; sending the
    # same Origin/Referer/Accept is what gets requests past their Cloudflare.
    $headers = @{
        Accept  = 'application/json, text/plain, */*'
        Origin  = 'https://uk.webuy.com'
        Referer = 'https://uk.webuy.com/'
    }
    $resp = Invoke-FlipWebRequest -Uri $uri -Headers $headers
    $json = $resp.Content | ConvertFrom-Json

    $boxes = $json.response.data.boxes
    if (-not $boxes) {
        Write-Verbose "CeX: no results for '$Query'."
        return
    }

    foreach ($box in $boxes) {
        [pscustomobject]@{
            Name          = $box.boxName
            CexSells      = [double]$box.sellPrice
            CashBuy       = [double]$box.cashPrice
            VoucherBuy    = [double]$box.exchangePrice
            InStockOnline = -not [bool]$box.outOfEcomStock
            BoxId         = $box.boxId
        }
    }
}
