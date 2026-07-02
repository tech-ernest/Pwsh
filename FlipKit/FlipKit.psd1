@{
    RootModule        = 'FlipKit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '7f6a2c1e-9b3d-4e8a-a1c5-2d0f4b6e8a91'
    Author            = 'tech-ernest'
    Description       = 'Reselling toolkit: eBay sold-price comps, CeX price floors, deal scanning with alerts, misspelling search terms, and a flip ledger.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-FlipConfig'
        'Get-CexPrice'
        'Get-EbaySoldComps'
        'ConvertFrom-EbaySoldHtml'
        'Test-FlipDeal'
        'New-MisspellingList'
        'Get-EbayToken'
        'Find-EbayDeals'
        'Invoke-FlipScan'
        'Send-FlipAlert'
        'Add-FlipLedgerEntry'
        'Complete-FlipLedgerEntry'
        'Get-FlipLedgerStats'
    )
    PrivateData       = @{ PSData = @{ Tags = @('reselling', 'ebay', 'arbitrage') } }
}
