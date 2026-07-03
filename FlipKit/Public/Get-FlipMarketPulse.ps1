function Get-FlipMarketPulse {
    <#
    .SYNOPSIS
        Quick demand check for a keyword: live supply and prices (official
        Browse API) plus recent sold data (comps scraper, when reachable).
    .DESCRIPTION
        LiveListings vs SoldCount is the rough sell-through read: lots of
        recent solds against modest live supply = hot; a wall of live
        listings and few solds = saturated. SoldCount covers roughly the
        last 60 sold results, so treat the ratio as a signal, not gospel.
    .EXAMPLE
        Get-FlipMarketPulse 'steam deck'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Query,
        [double]$MaxPrice = 10000
    )

    $cfg = Get-FlipConfig

    $filter = 'price:[..{0}],priceCurrency:GBP,buyingOptions:{{FIXED_PRICE}}' -f $MaxPrice
    $uri = 'https://api.ebay.com/buy/browse/v1/item_summary/search?q={0}&filter={1}&limit=50' -f
        [uri]::EscapeDataString($Query), [uri]::EscapeDataString($filter)

    $resp = Invoke-RestMethod -Uri $uri -Headers @{
        Authorization             = "Bearer $(Get-EbayToken)"
        'X-EBAY-C-MARKETPLACE-ID' = $cfg.ebay.marketplaceId
    }

    $livePrices = @()
    if ($resp.PSObject.Properties['itemSummaries'] -and $resp.itemSummaries) {
        $livePrices = @($resp.itemSummaries | Where-Object { $_.PSObject.Properties['price'] -and $_.price } |
            ForEach-Object { [double]$_.price.value })
    }
    $liveStats = if ($livePrices.Count -gt 0) { Get-PriceStats -Prices $livePrices } else { $null }

    # Sold side is best-effort: the comps scraper can be blocked on some networks.
    $sold = try { Get-EbaySoldComps -SearchTerm $Query } catch { $null }

    [pscustomobject]@{
        Query        = $Query
        LiveListings = [int]$resp.total
        LiveMedian   = if ($liveStats) { $liveStats.Median } else { $null }
        LiveMin      = if ($liveStats) { $liveStats.Min } else { $null }
        SoldCount    = if ($sold) { $sold.Count } else { $null }
        SoldMedian   = if ($sold) { $sold.Median } else { $null }
        SellThrough  = if ($sold -and $resp.total -gt 0) { [math]::Round($sold.Count / [double]$resp.total, 2) } else { $null }
    }
}

function Invoke-FlipSuggest {
    <#
    .SYNOPSIS
        Asks Claude to propose new scanner search lanes, then checks live
        supply for each via the eBay API.
    .DESCRIPTION
        Claude suggests lanes that fit the business (niches, capital, the
        30% rule) with concrete queries/categories/price caps; each lane is
        then enriched with a live-listing count so you can see which markets
        actually have volume before adding them to config.
    .EXAMPLE
        Invoke-FlipSuggest | Format-Table Name, Query, MaxPrice, LiveListings
    #>
    [CmdletBinding()]
    param([string]$Model)

    $schema = @{
        type                 = 'object'
        additionalProperties = $false
        required             = @('lanes')
        properties           = @{
            lanes = @{
                type  = 'array'
                items = @{
                    type                 = 'object'
                    additionalProperties = $false
                    required             = @('name', 'query', 'category_ids', 'min_price', 'max_price', 'why')
                    properties           = @{
                        name         = @{ type = 'string' }
                        query        = @{ type = 'string' }
                        category_ids = @{ type = 'string'; description = 'eBay UK category ids, comma separated, or empty string' }
                        min_price    = @{ type = 'number' }
                        max_price    = @{ type = 'number' }
                        why          = @{ type = 'string' }
                    }
                }
            }
        }
    }

    $system = (Get-FlipChatSystemPrompt) + @'


Task: propose 5-8 NEW scanner search lanes for this reseller - markets that are currently hot on eBay UK with strong resale demand, that fit the capital limits and the 30% margin rule, and that are not already covered by the active searches listed above. Prefer testable, brand-name, small-parcel goods. For each lane give: a short name; the eBay query string (space = AND, parentheses with commas = OR, e.g. "(faulty, spares, untested)"); category_ids where a category scope helps (27386 graphics cards, 164 CPUs, 1244 motherboards, 179 desktop PCs, 177 laptops, 175672 monitors, 139971 video game consoles - empty string if none fits); a sensible min_price (to filter accessory junk) and max_price; and one sentence on why the lane is hot right now and what the typical flip looks like.
'@

    $resp = Invoke-FlipClaudeApi -Model $Model -Body @{
        max_tokens    = 16000
        thinking      = @{ type = 'adaptive' }
        system        = $system
        output_config = @{ format = @{ type = 'json_schema'; schema = $schema } }
        messages      = @(@{ role = 'user'; content = 'Suggest new search lanes.' })
    }

    if ($resp.stop_reason -eq 'refusal') { throw 'Claude declined the suggestion request.' }

    $text = (@($resp.content) | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
    $parsed = $text | ConvertFrom-Json

    foreach ($lane in $parsed.lanes) {
        # Enrich with live supply so dead markets are visible before adding to config.
        $live = try { (Get-FlipMarketPulse -Query $lane.query -MaxPrice $lane.max_price).LiveListings } catch { $null }
        Start-Sleep -Milliseconds 500

        [pscustomobject]@{
            Name         = $lane.name
            Query        = $lane.query
            CategoryIds  = $lane.category_ids
            MinPrice     = $lane.min_price
            MaxPrice     = $lane.max_price
            Why          = $lane.why
            LiveListings = $live
        }
    }
}
