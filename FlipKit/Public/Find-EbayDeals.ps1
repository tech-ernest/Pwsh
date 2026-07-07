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
        [double]$MinPrice = 0,
        # eBay category ids, comma-separated (e.g. '27386' = Graphics Cards) —
        # scopes the search so broad keyword sets stay on-topic.
        [string]$CategoryIds,
        # FIXED_PRICE, AUCTION, or 'FIXED_PRICE|AUCTION'
        [string]$BuyingOptions = 'FIXED_PRICE',
        # eBay condition ids, pipe-separated (e.g. '7000' = For parts or not
        # working) — the reliable way to hunt broken stock, since many sellers
        # never write "faulty" in the title.
        [string]$ConditionIds,
        # newlyListed catches fresh mispricings; endingSoonest surfaces
        # auctions approaching the hammer — snipe-shortlist mode.
        [ValidateSet('newlyListed', 'endingSoonest')][string]$Sort = 'newlyListed',
        # Only return auctions ending within this many hours (0 = no window).
        [double]$EndingWithinHours = 0,
        [int]$Limit = 50,
        [string]$MarketplaceId
    )

    $cfg = Get-FlipConfig
    if (-not $MarketplaceId) { $MarketplaceId = $cfg.ebay.marketplaceId }

    $priceRange = if ($MinPrice -gt 0) { '[{0}..{1}]' -f $MinPrice, $MaxPrice } else { '[..{0}]' -f $MaxPrice }
    $filter = 'price:{0},priceCurrency:GBP,buyingOptions:{{{1}}}' -f $priceRange, $BuyingOptions
    if ($ConditionIds) { $filter += ',conditionIds:{' + $ConditionIds + '}' }
    $uri = 'https://api.ebay.com/buy/browse/v1/item_summary/search?q={0}&filter={1}&sort={2}&limit={3}' -f
        [uri]::EscapeDataString($Query), [uri]::EscapeDataString($filter), $Sort, $Limit
    if ($CategoryIds) { $uri += '&category_ids=' + [uri]::EscapeDataString($CategoryIds) }

    $resp = Invoke-RestMethod -Uri $uri -Headers @{
        Authorization                = "Bearer $(Get-EbayToken)"
        'X-EBAY-C-MARKETPLACE-ID'    = $MarketplaceId
    }

    if (-not ($resp.PSObject.Properties['itemSummaries'] -and $resp.itemSummaries)) {
        Write-Verbose "No live listings for '$Query' under £$MaxPrice."
        return
    }

    foreach ($item in $resp.itemSummaries) {
        # Fixed-price listings carry 'price'; auctions carry 'currentBidPrice'.
        $priceValue =
            if ($item.PSObject.Properties['price'] -and $item.price) { [double]$item.price.value }
            elseif ($item.PSObject.Properties['currentBidPrice'] -and $item.currentBidPrice) { [double]$item.currentBidPrice.value }
            else { $null }
        if ($null -eq $priceValue) { continue }

        $endDateUtc = if ($item.PSObject.Properties['itemEndDate']) { ConvertTo-FlipUtcDate -Value $item.itemEndDate } else { $null }

        # Ending-soon window: only items with an end date inside it qualify.
        if ($EndingWithinHours -gt 0) {
            $endOk = $endDateUtc -and $endDateUtc -gt [datetime]::UtcNow -and $endDateUtc -le [datetime]::UtcNow.AddHours($EndingWithinHours)
            if (-not $endOk) { continue }
        }

        [pscustomobject]@{
            ItemId    = $item.itemId
            Title     = $item.title
            Price     = $priceValue
            Condition = if ($item.PSObject.Properties['condition']) { $item.condition } else { 'Unknown' }
            BuyingOpt = ($item.buyingOptions -join ',')
            # Auctions only: round-trippable ('o' format, keeps the UTC marker) end time and bid count.
            EndsAt    = if ($endDateUtc) { $endDateUtc.ToString('o') } else { '' }
            BidCount  = if ($item.PSObject.Properties['bidCount']) { [int]$item.bidCount } else { $null }
            Url       = $item.itemWebUrl
            Query     = $Query
        }
    }
}
