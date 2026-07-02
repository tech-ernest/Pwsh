function Add-FlipLedgerEntry {
    <#
    .SYNOPSIS
        Records a purchase in the flip ledger (data/ledger.csv).
    .DESCRIPTION
        The ledger is the business's memory: it decides which categories get more
        capital and which get killed. Record every buy the day you make it, then
        close it with Complete-FlipLedgerEntry when it sells.
    .EXAMPLE
        Add-FlipLedgerEntry -Item 'RTX 3060 12GB Zotac' -Category 'PC hardware' -Source 'ebay' -BuyPrice 140
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Item,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][double]$BuyPrice,
        [datetime]$BuyDate = (Get-Date),
        [string]$Notes = ''
    )

    $path = Join-Path (Get-FlipDataDir) 'ledger.csv'
    $rows = if (Test-Path $path) { @(Import-Csv $path) } else { @() }

    $nextId = if ($rows) { 1 + ($rows.Id | Measure-Object -Maximum).Maximum } else { 1 }

    $entry = [pscustomobject]@{
        Id         = $nextId
        Item       = $Item
        Category   = $Category
        Source     = $Source
        BuyDate    = $BuyDate.ToString('yyyy-MM-dd')
        BuyPrice   = $BuyPrice
        SoldDate   = ''
        SoldPrice  = ''
        Fees       = ''
        Postage    = ''
        Net        = ''
        DaysToSell = ''
        Notes      = $Notes
    }

    @($rows) + $entry | Export-Csv -Path $path -NoTypeInformation
    Write-Host "Ledger: added #$nextId '$Item' at £$BuyPrice"
    $entry
}
