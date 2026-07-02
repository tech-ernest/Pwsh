function Get-FlipConfig {
    <#
    .SYNOPSIS
        Loads FlipKit settings from config/settings.json (or $env:FLIPKIT_CONFIG).
    .DESCRIPTION
        Copy config/settings.sample.json to config/settings.json and fill in your
        keys. settings.json is gitignored so credentials never reach the repo.
    #>
    [CmdletBinding()]
    param()

    $path = if ($env:FLIPKIT_CONFIG) { $env:FLIPKIT_CONFIG }
            else { Join-Path $script:RepoRoot 'config/settings.json' }

    if (-not (Test-Path $path)) {
        throw "Config not found at '$path'. Copy config/settings.sample.json to config/settings.json and fill it in (or set FLIPKIT_CONFIG)."
    }

    Get-Content -Raw -Path $path | ConvertFrom-Json
}
