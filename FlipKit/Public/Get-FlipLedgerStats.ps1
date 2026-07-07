function Get-FlipLedgerStats {
    <#
    .SYNOPSIS
        The monthly truth: profit, margins, speed, and capital tied up — overall and per category.
    .DESCRIPTION
        Run this before every sourcing session. Categories with slow turns or thin
        margins lose their capital allocation; the ledger decides, not gut feel.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-FlipDataDir) 'ledger.csv'
    if (-not (Test-Path $path)) { throw 'No ledger yet — record purchases with Add-FlipLedgerEntry first.' }

    $rows = @(Import-Csv $path)
    $closed = @($rows | Where-Object { $_.SoldDate })
    $open   = @($rows | Where-Object { -not $_.SoldDate })

    $summary = [pscustomobject]@{
        FlipsCompleted   = $closed.Count
        TotalNetProfit   = if ($closed) { [math]::Round((($closed.Net | Measure-Object -Sum).Sum), 2) } else { 0 }
        AvgNetPerFlip    = if ($closed) { [math]::Round((($closed.Net | Measure-Object -Average).Average), 2) } else { 0 }
        AvgMarginPct     = if ($closed) { [math]::Round(100 * ($closed | ForEach-Object { [double]$_.Net / [double]$_.BuyPrice } | Measure-Object -Average).Average, 1) } else { 0 }
        AvgDaysToSell    = if ($closed) { [math]::Round((($closed.DaysToSell | Measure-Object -Average).Average), 1) } else { 0 }
        OpenItems        = $open.Count
        CapitalDeployed  = [math]::Round((($open.BuyPrice | Measure-Object -Sum).Sum), 2)
    }

    # @() so a single category still serializes as a JSON array for the app.
    $byCategory = @($closed | Group-Object Category | ForEach-Object {
        [pscustomobject]@{
            Category      = $_.Name
            Flips         = $_.Count
            NetProfit     = [math]::Round((($_.Group.Net | Measure-Object -Sum).Sum), 2)
            AvgDaysToSell = [math]::Round((($_.Group.DaysToSell | Measure-Object -Average).Average), 1)
        }
    } | Sort-Object NetProfit -Descending)

    # Same cut by Source (which search lane / venue the buy came from) — this
    # is what decides where next month's capital goes.
    $bySource = @($closed | Group-Object Source | ForEach-Object {
        [pscustomobject]@{
            Source        = $_.Name
            Flips         = $_.Count
            NetProfit     = [math]::Round((($_.Group.Net | Measure-Object -Sum).Sum), 2)
            AvgDaysToSell = [math]::Round((($_.Group.DaysToSell | Measure-Object -Average).Average), 1)
        }
    } | Sort-Object NetProfit -Descending)

    [pscustomobject]@{
        Summary    = $summary
        ByCategory = $byCategory
        BySource   = $bySource
    }
}
