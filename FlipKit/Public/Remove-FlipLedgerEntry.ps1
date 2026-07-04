function Remove-FlipLedgerEntry {
    <#
    .SYNOPSIS
        Deletes an entry from the flip ledger by Id.
    .DESCRIPTION
        For typos and test rows. Genuine losses should stay in the ledger and
        be closed with Complete-FlipLedgerEntry at the real (lower) sold price
        - profit stats only tell the truth if losses are counted.
    .EXAMPLE
        Remove-FlipLedgerEntry -Id 7
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Id)

    $path = Join-Path (Get-FlipDataDir) 'ledger.csv'
    if (-not (Test-Path $path)) { throw 'No ledger yet.' }

    $rows = @(Import-Csv $path)
    $victim = $rows | Where-Object { [int]$_.Id -eq $Id }
    if (-not $victim) { throw "No ledger entry with Id $Id." }

    $remaining = @($rows | Where-Object { [int]$_.Id -ne $Id })
    if ($remaining.Count -gt 0) { $remaining | Export-Csv -Path $path -NoTypeInformation }
    else { Remove-Item $path }

    Write-Host "Ledger: deleted #$Id '$($victim.Item)'"
}
