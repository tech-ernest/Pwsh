function New-FlipListing {
    <#
    .SYNOPSIS
        Drafts an eBay listing (title, description, pricing) for an item you're selling.
    .DESCRIPTION
        The selling half of the flip. Feeds the item name, your notes and —
        when reachable — live sold-price stats to the AI, and returns a
        keyword-front-loaded 80-char title, an honest structured description,
        and a Buy-It-Now price with a floor for offers. Listing quality is
        worth 10-15% on the sale; this makes the good version the lazy version.
    .EXAMPLE
        New-FlipListing -Item 'HP EliteBook 840 G9 i5-1235U 16GB 512GB' -Notes 'new screen fitted, battery 92%, minor lid scuff'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Item,
        # Condition notes: faults fixed, cosmetic state, what's included.
        [string]$Notes = ''
    )

    # Ground the price in real solds when the comps route is available.
    $compsLine = ''
    try {
        $comps = Get-EbaySoldComps -SearchTerm $Item
        if ($comps) {
            $compsLine = "Live eBay UK sold stats for this search: median £$($comps.Median), P25 £$($comps.P25), P75 £$($comps.P75) across $($comps.Count) sales."
        }
    }
    catch { Write-Verbose "Comps unavailable for listing draft: $_" }

    $schema = @{
        type                 = 'object'
        additionalProperties = $false
        required             = @('title', 'description', 'bin_price_gbp', 'floor_price_gbp', 'keywords')
        properties           = @{
            title           = @{ type = 'string'; description = 'eBay title, max 80 chars, brand + model + key specs first, no ALL CAPS, no "L@@K" junk' }
            description     = @{ type = 'string'; description = 'plain-text listing description with short paragraphs: what it is, honest condition incl. any faults/marks, what is included, dispatch note' }
            bin_price_gbp   = @{ type = 'number'; description = 'Buy It Now price slightly under the typical sold price for a fast sale' }
            floor_price_gbp = @{ type = 'number'; description = 'lowest offer worth accepting' }
            keywords        = @{ type = 'array'; items = @{ type = 'string' }; description = 'search terms buyers use for this item' }
        }
    }

    $system = @'
You write eBay UK listings for a small refurb/reselling operation. Titles are keyword-front-loaded (brand, model, key specs), never clickbait. Descriptions are honest and specific: state exactly what was repaired or is faulty, cosmetic condition, what is in the box, and dispatch speed. Honest listings cut returns and disputes. Prices come from the sold stats when provided; price the BIN a touch under median for a fast sale.
'@

    $user = "Item: $Item"
    if ($Notes) { $user += "`nSeller notes: $Notes" }
    if ($compsLine) { $user += "`n$compsLine" }

    $draft = ConvertFrom-FlipAiJson -Text (Invoke-FlipAi -System $system -JsonSchema $schema `
        -Messages @(@{ role = 'user'; content = $user }))

    [pscustomobject]@{
        Title       = $draft.title
        Description = $draft.description
        BinPrice    = [math]::Round([double]$draft.bin_price_gbp, 2)
        FloorPrice  = [math]::Round([double]$draft.floor_price_gbp, 2)
        Keywords    = @($draft.keywords)
        CompsNote   = if ($compsLine) { $compsLine } else { 'No live sold stats available — prices are AI estimates.' }
    }
}
