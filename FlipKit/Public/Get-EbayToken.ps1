function Get-EbayToken {
    <#
    .SYNOPSIS
        Gets (and caches) an eBay application OAuth token for the Browse API.
    .DESCRIPTION
        Uses the client-credentials flow with the keys from config. Register a free
        app at developer.ebay.com, create a production keyset, and put the App ID
        (client ID) and Cert ID (client secret) in config/settings.json.
    #>
    [CmdletBinding()]
    param([switch]$Force)

    if (-not $Force -and $script:EbayTokenCache -and $script:EbayTokenCache.Expires -gt (Get-Date).AddMinutes(2)) {
        return $script:EbayTokenCache.Token
    }

    $cfg = Get-FlipConfig
    if (-not $cfg.ebay.clientId -or -not $cfg.ebay.clientSecret) {
        throw 'eBay clientId/clientSecret missing from config. Create a free keyset at developer.ebay.com and add it to config/settings.json.'
    }

    $basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($cfg.ebay.clientId):$($cfg.ebay.clientSecret)"))

    try {
        $resp = Invoke-RestMethod -Method Post -Uri 'https://api.ebay.com/identity/v1/oauth2/token' `
            -Headers @{ Authorization = "Basic $basic" } `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body 'grant_type=client_credentials&scope=https%3A%2F%2Fapi.ebay.com%2Foauth%2Fapi_scope' `
            -ErrorAction Stop
    }
    catch {
        if ("$_" -match 'invalid_client') {
            throw 'eBay rejected the credentials (invalid_client): the clientSecret in config/settings.json does not match the current Cert ID on developer.ebay.com. Copy the Cert ID again (Application Keys -> Show) and re-save.'
        }
        throw
    }

    $script:EbayTokenCache = @{
        Token   = $resp.access_token
        Expires = (Get-Date).AddSeconds([int]$resp.expires_in)
    }

    $script:EbayTokenCache.Token
}
