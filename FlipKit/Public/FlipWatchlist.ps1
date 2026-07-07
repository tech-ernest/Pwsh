function Get-FlipWatchlistPath { Join-Path (Get-FlipDataDir) 'watchlist.json' }

function Add-FlipWatch {
    <#
    .SYNOPSIS
        Puts an auction on the snipe watchlist with your maximum bid.
    .DESCRIPTION
        The watchlist closes the auction loop: the scanner flags a lot, you
        deal-check it and decide a ceiling, Add-FlipWatch remembers it, and
        the scheduled scan sends a reminder alert shortly before the hammer.
        Decide the max bid now, when you're calm — not in the last minute.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ItemId,
        [Parameter(Mandatory)][string]$Title,
        [string]$Url = '',
        # ISO end time from the scanner hit; empty means no reminder, list-only.
        [string]$EndsAt = '',
        [double]$MaxBid = 0,
        [double]$Price = 0
    )

    $path = Get-FlipWatchlistPath
    $list = if (Test-Path $path) { @(Get-Content -Raw $path | ConvertFrom-Json) } else { @() }
    $list = @($list | Where-Object { $_.ItemId -ne $ItemId })

    $entry = [pscustomobject]@{
        ItemId   = $ItemId
        Title    = $Title
        Url      = $Url
        EndsAt   = $EndsAt
        MaxBid   = $MaxBid
        Price    = $Price
        AddedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        Notified = $false
    }
    $list = @($entry) + $list
    ConvertTo-Json -InputObject $list -Depth 5 | Set-Content -Path $path
    $entry
}

function Get-FlipWatchlist {
    <#
    .SYNOPSIS
        The snipe list: watched auctions, soonest hammer first.
    #>
    [CmdletBinding()]
    param([switch]$IncludeEnded)

    $path = Get-FlipWatchlistPath
    if (-not (Test-Path $path)) { return }
    $now = [datetime]::UtcNow

    $items = foreach ($w in @(Get-Content -Raw $path | ConvertFrom-Json)) {
        $minutesLeft = $null
        $end = ConvertTo-FlipUtcDate -Value $w.EndsAt
        if ($end) { $minutesLeft = [int][math]::Floor(($end - $now).TotalMinutes) }
        if (-not $IncludeEnded -and $null -ne $minutesLeft -and $minutesLeft -lt -60) { continue }
        $w | Add-Member -NotePropertyName MinutesLeft -NotePropertyValue $minutesLeft -Force -PassThru
    }

    @($items) | Sort-Object @{ Expression = { if ($null -eq $_.MinutesLeft) { [int]::MaxValue } else { $_.MinutesLeft } } }
}

function Remove-FlipWatch {
    <#
    .SYNOPSIS
        Takes an auction off the watchlist.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ItemId)

    $path = Get-FlipWatchlistPath
    if (-not (Test-Path $path)) { return }
    $list = @(@(Get-Content -Raw $path | ConvertFrom-Json) | Where-Object { $_.ItemId -ne $ItemId })
    ConvertTo-Json -InputObject $list -Depth 5 | Set-Content -Path $path
}

function Send-FlipWatchReminders {
    <#
    .SYNOPSIS
        Alerts once for each watched auction entering its final minutes.
    .DESCRIPTION
        Called by every live scan (the scheduled task runs one every 15
        minutes), so a 20-minute window guarantees one reminder 5-20 minutes
        before the hammer. Long-ended entries are pruned while we're here.
    #>
    [CmdletBinding()]
    param([int]$WithinMinutes = 20)

    $path = Get-FlipWatchlistPath
    if (-not (Test-Path $path)) { return 0 }

    $list = @(Get-Content -Raw $path | ConvertFrom-Json)
    $now = [datetime]::UtcNow
    $sent = 0
    $keep = [System.Collections.Generic.List[object]]::new()

    foreach ($w in $list) {
        $minutesLeft = $null
        $end = ConvertTo-FlipUtcDate -Value $w.EndsAt
        if ($end) { $minutesLeft = ($end - $now).TotalMinutes }

        # Prune auctions that ended over 2 hours ago.
        if ($null -ne $minutesLeft -and $minutesLeft -lt -120) { continue }

        if (-not $w.Notified -and $null -ne $minutesLeft -and $minutesLeft -gt 0 -and $minutesLeft -le $WithinMinutes) {
            $maxBid = if ($w.MaxBid -gt 0) { " — your max £$($w.MaxBid)" } else { '' }
            Send-FlipAlert -Priority 5 -Title "⏰ Auction ends in $([int]$minutesLeft)m$maxBid" `
                -Message "$($w.Title)`nlast seen at £$($w.Price) — bid in the final minute, never above your max." `
                -Url $w.Url
            $w.Notified = $true
            $sent++
        }
        $keep.Add($w)
    }

    ConvertTo-Json -InputObject @($keep) -Depth 5 | Set-Content -Path $path
    $sent
}
