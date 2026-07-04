function Get-FlipConfigPath {
    if ($env:FLIPKIT_CONFIG) { return $env:FLIPKIT_CONFIG }
    Join-Path $script:RepoRoot 'config/settings.json'
}

function Get-FlipSettingsView {
    <#
    .SYNOPSIS
        Returns the config for the app's Settings tab with secrets blanked.
        secretsSet flags tell the UI which secrets exist without exposing them.
    #>
    [CmdletBinding()]
    param()

    $path = Get-FlipConfigPath
    if (-not (Test-Path $path)) { throw "Config not found at '$path'." }
    $cfg = Get-Content -Raw $path | ConvertFrom-Json

    $secretsSet = [ordered]@{
        ebayClientSecret = [bool]($cfg.ebay.clientSecret)
        aiApiKey         = [bool]($cfg.PSObject.Properties['ai'] -and $cfg.ai.apiKey)
        telegramBotToken = [bool]($cfg.alerts.telegramBotToken)
        cexAlgoliaApiKey = [bool]($cfg.PSObject.Properties['cex'] -and $cfg.cex.algoliaApiKey)
    }

    if ($cfg.ebay.clientSecret) { $cfg.ebay.clientSecret = '' }
    if ($cfg.PSObject.Properties['ai'] -and $cfg.ai.apiKey) { $cfg.ai.apiKey = '' }
    if ($cfg.alerts.telegramBotToken) { $cfg.alerts.telegramBotToken = '' }
    if ($cfg.PSObject.Properties['cex'] -and $cfg.cex.algoliaApiKey) { $cfg.cex.algoliaApiKey = '' }

    [pscustomobject]@{ config = $cfg; secretsSet = [pscustomobject]$secretsSet }
}

function Save-FlipSettings {
    <#
    .SYNOPSIS
        Writes settings from the app's Settings tab back to config/settings.json.
    .DESCRIPTION
        Secret fields submitted blank keep their existing values (the UI never
        sees them). Top-level sections not present in the submission (e.g. a
        legacy "anthropic" block) are preserved.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$New)

    $path = Get-FlipConfigPath
    $cur = if (Test-Path $path) { Get-Content -Raw $path | ConvertFrom-Json } else { [pscustomobject]@{} }

    # Blank secret = keep what's already saved.
    $keepSecret = {
        param($section, $prop)
        if ($New.PSObject.Properties[$section] -and -not $New.$section.$prop -and
            $cur.PSObject.Properties[$section] -and $cur.$section.$prop) {
            $New.$section.$prop = $cur.$section.$prop
        }
    }
    & $keepSecret 'ebay' 'clientSecret'
    & $keepSecret 'ai' 'apiKey'
    & $keepSecret 'alerts' 'telegramBotToken'
    & $keepSecret 'cex' 'algoliaApiKey'

    # Preserve any top-level sections the submission doesn't know about.
    foreach ($p in $cur.PSObject.Properties) {
        if (-not $New.PSObject.Properties[$p.Name]) {
            $New | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
        }
    }

    if (-not $New.PSObject.Properties['searches'] -or @($New.searches).Count -eq 0) {
        throw 'Refusing to save a config with no searches — the scanner would have nothing to do.'
    }

    ConvertTo-Json $New -Depth 12 | Set-Content -Path $path
    Write-Host "Config saved ($(@($New.searches).Count) searches)."
}
