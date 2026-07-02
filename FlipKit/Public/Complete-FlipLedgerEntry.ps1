function Complete-FlipLedgerEntry {
    <#
    .SYNOPSIS
        Closes a ledger entry when the item sells; computes net profit and days-to-sell.
    .EXAMPLE
        Complete-FlipLedgerEntry -Id 3 -SoldPrice 215 -Fees 28.25 -Postage 3.35
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Id,
        [Parameter(Mandatory)][double]$SoldPrice,
        [Parameter(Mandatory)][double]$Fees,
        [Parameter(Mandatory)][double]$Postage,
        [datetime]$SoldDate = (Get-Date)
    )

    $path = Join-Path (Get-FlipDataDir) 'ledger.csv'
    if (-not (Test-Path $path)) { throw 'No ledger yet — record purchases with Add-FlipLedgerEntry first.' }

    $rows = @(Import-Csv $path)
    $row = $rows | Where-Object { [int]$_.Id -eq $Id }
    if (-not $row) { throw "No ledger entry with Id $Id." }
    if ($row.SoldDate) { throw "Entry #$Id ('$($row.Item)') is already closed (sold $($row.SoldDate))." }

    $row.SoldDate   = $SoldDate.ToString('yyyy-MM-dd')
    $row.SoldPrice  = $SoldPrice
    $row.Fees       = $Fees
    $row.Postage    = $Postage
    $row.Net        = [math]::Round($SoldPrice - $Fees - $Postage - [double]$row.BuyPrice, 2)
    $row.DaysToSell = [int]($SoldDate.Date - [datetime]$row.BuyDate).TotalDays

    $rows | Export-Csv -Path $path -NoTypeInformation
    Write-Host "Ledger: closed #$Id '$($row.Item)' — net £$($row.Net) in $($row.DaysToSell) days"
    $row
}
