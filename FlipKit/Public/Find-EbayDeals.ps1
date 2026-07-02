function Find-EbayDeals {
    <#
    .SYNOPSIS
        Searches live eBay listings under a price ceiling via the official Browse API.
    .DESCRIPTION
        The scanner's engine: newest listings first, price-capped, GBP. This uses
        eBay's official API (free tier: 5,000 calls/day), so it's the reliable
        backbone — run it as often as every 10 minutes without worry.
    .EXAMPLE
        Find-EbayDeals -Query 'rtx 3060' -MaxPrice 180
    .EXAMPLE
        New-MisspellingList 'garmin' | ForEach-Object { Find-EbayDeals -Query $_ -MaxPrice 50 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Query,
        [Parameter(Mandatory)][double]$MaxPrice,
        # FIXED_PRICE, AUCTION, or 'FIXED_PRICE|AUCTION'
        [string]$BuyingOptions = 'FIXED_PRICE',
        [int]$Limit = 50,
        [string]$MarketplaceId
    )

    $cfg = Get-FlipConfig
    if (-not $MarketplaceId) { $MarketplaceId = $cfg.ebay.marketplaceId }

    $filter = 'price:[..{0}],priceCurrency:GBP,buyingOptions:{{{1}}}' -f $MaxPrice, $BuyingOptions
    $uri = 'https://api.ebay.com/buy/browse/v1/item_summary/search?q={0}&filter={1}&sort=newlyListed&limit={2}' -f
        [uri]::EscapeDataString($Query), [uri]::EscapeDataString($filter), $Limit

    $resp = Invoke-RestMethod -Uri $uri -Headers @{
        Authorization                = "Bearer $(Get-EbayToken)"
        'X-EBAY-C-MARKETPLACE-ID'    = $MarketplaceId
    }

    if (-not ($resp.PSObject.Properties['itemSummaries'] -and $resp.itemSummaries)) {
        Write-Verbose "No live listings for '$Query' under £$MaxPrice."
        return
    }

    foreach ($item in $resp.itemSummaries) {
        [pscustomobject]@{
            ItemId    = $item.itemId
            Title     = $item.title
            Price     = [double]$item.price.value
            Condition = if ($item.PSObject.Properties['condition']) { $item.condition } else { 'Unknown' }
            BuyingOpt = ($item.buyingOptions -join ',')
            Url       = $item.itemWebUrl
            Query     = $Query
        }
    }
}
