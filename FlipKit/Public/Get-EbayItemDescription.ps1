function Get-EbayItemDescription {
    <#
    .SYNOPSIS
        Fetches a listing's description as plain text via the Browse API.
    .DESCRIPTION
        The search endpoint doesn't return descriptions — this hits the
        per-item endpoint and strips the seller's HTML down to readable text
        (capped at 1500 chars). Sellers bury the real fault in here, which is
        why the scanner attaches it to new hits and the AI triage reads it.
    .EXAMPLE
        Get-EbayItemDescription -ItemId 'v1|123456789012|0'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$ItemId,
        [string]$MarketplaceId
    )

    $cfg = Get-FlipConfig
    if (-not $MarketplaceId) { $MarketplaceId = $cfg.ebay.marketplaceId }

    $uri = 'https://api.ebay.com/buy/browse/v1/item/{0}' -f [uri]::EscapeDataString($ItemId)
    $resp = Invoke-RestMethod -Uri $uri -Headers @{
        Authorization             = "Bearer $(Get-EbayToken)"
        'X-EBAY-C-MARKETPLACE-ID' = $MarketplaceId
    }

    $html = ''
    if ($resp.PSObject.Properties['description'] -and $resp.description) { $html = [string]$resp.description }
    elseif ($resp.PSObject.Properties['shortDescription'] -and $resp.shortDescription) { $html = [string]$resp.shortDescription }
    if (-not $html) { return '' }

    $text = [regex]::Replace($html, '(?is)<(script|style)[^>]*>.*?</\1>', ' ')
    $text = [regex]::Replace($text, '(?s)<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    if ($text.Length -gt 1500) { $text = $text.Substring(0, 1500) + '…' }
    $text
}
