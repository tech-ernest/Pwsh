function Save-FlipRecentHits {
    <#
        Prepends new scan hits to the rolling history (data/recent-hits.json,
        capped at 300) so the app can show past deals, not just this scan's.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][array]$Hits)

    $path = Join-Path (Get-FlipDataDir) 'recent-hits.json'
    $existing = if (Test-Path $path) { @(Get-Content -Raw $path | ConvertFrom-Json) } else { @() }

    $opt = { param($o, $n, $d) if ($o.PSObject.Properties[$n]) { $o.$n } else { $d } }
    $incoming = foreach ($h in $Hits) {
        [pscustomobject]@{
            ItemId      = $h.ItemId
            Search      = $h.Search
            Title       = $h.Title
            Price       = $h.Price
            Condition   = $h.Condition
            Buying      = & $opt $h 'Buying' ''
            EndsAt      = & $opt $h 'EndsAt' ''
            BidCount    = & $opt $h 'BidCount' $null
            Description = & $opt $h 'Description' ''
            Url         = $h.Url
            Note        = $h.Note
            FoundAt     = $h.FoundAt
            Dismissed   = $false
        }
    }

    $known = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($h in $incoming) { [void]$known.Add([string]$h.ItemId) }
    $merged = @($incoming) + @($existing | Where-Object { -not $known.Contains([string]$_.ItemId) })

    ConvertTo-Json @($merged | Select-Object -First 300) -Depth 5 | Set-Content -Path $path
}

function Get-FlipRecentHits {
    <#
    .SYNOPSIS
        Returns the rolling scan-hit history (newest first).
    .EXAMPLE
        Get-FlipRecentHits -IncludeDismissed
    #>
    [CmdletBinding()]
    param([switch]$IncludeDismissed)

    $path = Join-Path (Get-FlipDataDir) 'recent-hits.json'
    if (-not (Test-Path $path)) { return @() }

    $all = @(Get-Content -Raw $path | ConvertFrom-Json)
    if ($IncludeDismissed) { return $all }
    @($all | Where-Object { -not $_.Dismissed })
}

function Clear-FlipRecentHits {
    <#
    .SYNOPSIS
        Dismisses every visible hit in the history (optionally one search's).
    .DESCRIPTION
        The "clear" behind the app's button: hits stay in the raw history for
        the record, but stop showing in Recent hits. Returns how many were
        cleared.
    #>
    [CmdletBinding()]
    param([string]$Search)

    $path = Join-Path (Get-FlipDataDir) 'recent-hits.json'
    if (-not (Test-Path $path)) { return 0 }

    $all = @(Get-Content -Raw $path | ConvertFrom-Json)
    $cleared = 0
    foreach ($h in $all) {
        if ($h.Dismissed) { continue }
        if ($Search -and $h.Search -ne $Search) { continue }
        $h.Dismissed = $true
        $cleared++
    }

    ConvertTo-Json $all -Depth 5 | Set-Content -Path $path
    $cleared
}

function Set-FlipHitDismissed {
    <#
    .SYNOPSIS
        Marks a hit in the history as not interested (hides it in the app).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ItemId)

    $path = Join-Path (Get-FlipDataDir) 'recent-hits.json'
    if (-not (Test-Path $path)) { throw 'No hit history yet.' }

    $all = @(Get-Content -Raw $path | ConvertFrom-Json)
    $target = $all | Where-Object { $_.ItemId -eq $ItemId }
    if (-not $target) { throw "No hit with ItemId '$ItemId' in history." }
    foreach ($t in @($target)) { $t.Dismissed = $true }

    ConvertTo-Json $all -Depth 5 | Set-Content -Path $path
}
