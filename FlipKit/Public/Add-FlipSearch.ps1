function Add-FlipSearch {
    <#
    .SYNOPSIS
        Appends a new search lane to config/settings.json's searches array.
    .DESCRIPTION
        Used by the app's Market tab "Add to scanner" button. Rewrites the
        config file, so any JSON formatting/comment-keys are preserved as
        properties but re-indented.
    .EXAMPLE
        Add-FlipSearch -Name 'Steam Deck faulty' -Query 'steam deck (faulty, spares)' -MaxPrice 180 -MinPrice 60
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][double]$MaxPrice,
        [double]$MinPrice = 0,
        [string]$CategoryIds = '',
        [string]$BuyingOptions = 'FIXED_PRICE'
    )

    $path = if ($env:FLIPKIT_CONFIG) { $env:FLIPKIT_CONFIG }
            else { Join-Path $script:RepoRoot 'config/settings.json' }
    if (-not (Test-Path $path)) { throw "Config not found at '$path'." }

    $cfg = Get-Content -Raw $path | ConvertFrom-Json
    if (@($cfg.searches | Where-Object { $_.name -eq $Name }).Count -gt 0) {
        throw "A search named '$Name' already exists."
    }

    $new = [ordered]@{
        name          = $Name
        query         = $Query
        maxPrice      = $MaxPrice
        cexQuery      = ''
        buyingOptions = $BuyingOptions
    }
    if ($MinPrice -gt 0) { $new.minPrice = $MinPrice }
    if ($CategoryIds) { $new.categoryIds = $CategoryIds }

    $cfg.searches = @($cfg.searches) + [pscustomobject]$new
    $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $path

    Write-Host "Config: added search '$Name' ($(@($cfg.searches).Count) total)"
    [pscustomobject]$new
}
