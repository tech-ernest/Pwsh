function Get-EbayQuota {
    <#
    .SYNOPSIS
        Shows how much of the daily eBay API allowance is used.
    .DESCRIPTION
        Asks eBay's developer-analytics endpoint for the app's rate limits.
        The scanner's calls (searches, typo variants, description fetches)
        all draw from the Browse API's daily pool — run this when scans start
        failing or before adding more lanes.
    .EXAMPLE
        Get-EbayQuota
    #>
    [CmdletBinding()]
    param(
        # Show every API eBay reports, not just the Browse API the scanner uses.
        [switch]$All
    )

    $resp = Invoke-RestMethod -Uri 'https://api.ebay.com/developer/analytics/v1_beta/rate_limit/' -Headers @{
        Authorization = "Bearer $(Get-EbayToken)"
    }

    if (-not ($resp.PSObject.Properties['rateLimits'] -and $resp.rateLimits)) {
        Write-Warning 'eBay returned no rate-limit data (analytics may lag a few minutes behind real usage).'
        return
    }

    foreach ($api in $resp.rateLimits) {
        if (-not $All -and $api.apiName -ne 'Browse') { continue }
        foreach ($resource in @($api.resources)) {
            foreach ($rate in @($resource.rates)) {
                $used = [long]$rate.limit - [long]$rate.remaining
                [pscustomobject]@{
                    Api       = "$($api.apiContext)/$($api.apiName)"
                    Resource  = $resource.name
                    Used      = $used
                    Limit     = [long]$rate.limit
                    UsedPct   = if ([long]$rate.limit -gt 0) { [math]::Round(100 * $used / [long]$rate.limit, 1) } else { $null }
                    Remaining = [long]$rate.remaining
                    ResetsAt  = try { [datetime]::Parse($rate.reset, [System.Globalization.CultureInfo]::InvariantCulture,
                                    [System.Globalization.DateTimeStyles]::RoundtripKind).ToLocalTime().ToString('ddd HH:mm') } catch { "$($rate.reset)" }
                }
            }
        }
    }
}
