function Test-FlipDeal {
    <#
    .SYNOPSIS
        The buy/no-buy decision engine: comps + fees + CeX floor → verdict.
    .DESCRIPTION
        Given a search term and the price you'd pay, pulls sold comps and (optionally)
        the CeX cash-buy floor, deducts eBay fees and postage, and returns margins with
        a verdict:
          BUY   — even the conservative (P25) sale price clears your minimum margin
          RISKY — the median clears it but the P25 doesn't; fine occasionally, not as a habit
          PASS  — below minimum margin, or too few comps to trust
        Pass -Comps / -CexCashFloor to skip the network calls (offline what-if maths).
    .EXAMPLE
        Test-FlipDeal -SearchTerm 'rtx 3060 12gb' -BuyPrice 140
    .EXAMPLE
        Test-FlipDeal -SearchTerm 'x' -BuyPrice 50 -Comps $savedComps -CexCashFloor 65
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SearchTerm,
        [Parameter(Mandatory)][double]$BuyPrice,
        [double]$Postage,
        [double]$FeeRate,
        [double]$FeeFixed,
        [double]$MinMarginPct,
        # Pre-fetched comps object (Get-EbaySoldComps output) — skips the eBay call.
        [pscustomobject]$Comps,
        # Known CeX cash-buy price — skips the CeX call. Use -SkipCex to not bother at all.
        [double]$CexCashFloor,
        [switch]$SkipCex,
        [int]$MinComps = 5
    )

    # Defaults come from config when present, hard fallbacks otherwise, so the
    # function still works before config exists.
    $cfg = try { Get-FlipConfig } catch { $null }
    if (-not $PSBoundParameters.ContainsKey('Postage'))      { $Postage      = if ($cfg) { $cfg.fees.defaultPostage } else { 3.35 } }
    if (-not $PSBoundParameters.ContainsKey('FeeRate'))      { $FeeRate      = if ($cfg) { $cfg.fees.feeRate }        else { 0.13 } }
    if (-not $PSBoundParameters.ContainsKey('FeeFixed'))     { $FeeFixed     = if ($cfg) { $cfg.fees.feeFixed }       else { 0.30 } }
    if (-not $PSBoundParameters.ContainsKey('MinMarginPct')) { $MinMarginPct = if ($cfg) { $cfg.rules.minMarginPct }  else { 30 } }

    $SearchTerm = $SearchTerm.Trim()

    $recentSolds = @()
    $compsNote = $null
    if (-not $Comps) {
        # Fetch raw sold listings once: stats for the verdict, plus the most
        # recent solds for display.
        $rawSolds = try { @(Get-EbaySoldComps -SearchTerm $SearchTerm -Raw) } catch { @() }
        $compsNote = $script:CompsFilterNote
        if ($rawSolds.Count -gt 0) {
            $Comps = Get-PriceStats -Prices $rawSolds.Price
            $Comps | Add-Member -NotePropertyName SearchTerm -NotePropertyValue $SearchTerm
            $recentSolds = @($rawSolds | Select-Object -First 8)
        }
    }

    # Scraped solds unavailable (bot-walled network / markup change): fall back
    # to an AI estimate of typical UK sold prices, clearly labelled as such.
    if (-not $Comps) {
        $aiReady = $null -ne (& { try { Get-FlipAiConfig } catch { $null } })
        if (-not $aiReady) { throw "No comps available for '$SearchTerm' and no AI provider configured for a fallback estimate." }

        $schema = @{
            type                 = 'object'
            additionalProperties = $false
            required             = @('median_gbp', 'p25_gbp', 'p75_gbp', 'note')
            properties           = @{
                median_gbp = @{ type = 'number'; description = 'typical eBay UK sold price for this item, used/working' }
                p25_gbp    = @{ type = 'number'; description = 'pessimistic sold price (25th percentile)' }
                p75_gbp    = @{ type = 'number'; description = 'optimistic sold price (75th percentile)' }
                note       = @{ type = 'string'; description = 'one short sentence on confidence and what drives the price' }
            }
        }
        $est = ConvertFrom-FlipAiJson -Text (Invoke-FlipAi -JsonSchema $schema `
            -System 'You estimate realistic eBay UK sold prices for second-hand items. Be conservative; base estimates on the specific model named.' `
            -Messages @(@{ role = 'user'; content = "Estimate eBay UK sold prices for: $SearchTerm" }))

        $why = if ($script:CompsDiagnosis) { " [$script:CompsDiagnosis]" } else { '' }
        $Comps = [pscustomobject]@{
            SearchTerm = $SearchTerm
            Count      = $MinComps   # AI estimate stands in for the sample-size gate
            Min        = [math]::Round([double]$est.p25_gbp * 0.8, 2)
            P25        = [math]::Round([double]$est.p25_gbp, 2)
            Median     = [math]::Round([double]$est.median_gbp, 2)
            P75        = [math]::Round([double]$est.p75_gbp, 2)
            Max        = [math]::Round([double]$est.p75_gbp * 1.2, 2)
            Mean       = [math]::Round([double]$est.median_gbp, 2)
            Source     = "AI estimate — $($est.note)$why"
        }
    }

    $cexNote = $null
    if (-not $PSBoundParameters.ContainsKey('CexCashFloor') -and -not $SkipCex) {
        # CeX is a bonus data source — a bot-wall block there must not sink the
        # verdict, but the reason for a missing floor should reach the UI.
        try {
            $cex = @(Get-CexPrice -Query $SearchTerm -Top 1)
            if (-not $cex) { $cexNote = 'no CeX product matched this search' }
            elseif (-not $cex[0].CashBuy) { $cexNote = "closest CeX match '$($cex[0].Name)' has no cash-buy price" }
            else { $CexCashFloor = $cex[0].CashBuy }
        }
        catch {
            $msg = "$($_.Exception.Message)"
            if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 160) + '…' }
            $cexNote = "CeX lookup failed: $msg"
            Write-Verbose "CeX floor unavailable: $_"
        }
    }

    $net = {
        param($salePrice)
        [math]::Round($salePrice - ($salePrice * $FeeRate) - $FeeFixed - $Postage - $BuyPrice, 2)
    }
    $marginPct = {
        param($netProfit)
        [math]::Round(100 * $netProfit / ($BuyPrice + $Postage), 1)
    }

    $expectedNet     = & $net $Comps.Median
    $conservativeNet = & $net $Comps.P25
    $expectedMargin     = & $marginPct $expectedNet
    $conservativeMargin = & $marginPct $conservativeNet

    $verdict =
        if ($Comps.Count -lt $MinComps)              { 'PASS (too few comps)' }
        elseif ($conservativeMargin -ge $MinMarginPct) { 'BUY' }
        elseif ($expectedMargin -ge $MinMarginPct)     { 'RISKY' }
        else                                           { 'PASS' }

    $result = [pscustomobject]@{
        SearchTerm         = $SearchTerm
        Verdict            = $verdict
        BuyPrice           = $BuyPrice
        CompsCount         = $Comps.Count
        MedianSold         = $Comps.Median
        P25Sold            = $Comps.P25
        ExpectedNet        = $expectedNet
        ExpectedMarginPct  = $expectedMargin
        ConservativeNet    = $conservativeNet
        ConservMarginPct   = $conservativeMargin
        CexCashFloor       = if ($PSBoundParameters.ContainsKey('CexCashFloor') -or $CexCashFloor) { $CexCashFloor } else { $null }
        BelowCexFloor      = if ($CexCashFloor) { $BuyPrice -lt $CexCashFloor } else { $null }
        CompsSource        = if ($Comps.PSObject.Properties['Source']) { $Comps.Source } else { 'eBay sold listings' }
        CompsNote          = $compsNote
        CexNote            = $cexNote
        RecentSolds        = @($recentSolds | ForEach-Object {
            @{
                Title = $_.Title
                Price = $_.Price
                Url   = if ($_.PSObject.Properties['Url']) { $_.Url } else { '' }
            }
        })
    }

    # A buy below what CeX pays cash for the item can't really lose — upgrade
    # the verdict so it stands out, whatever the eBay margin says.
    if ($result.BelowCexFloor) { $result.Verdict = 'BUY (below CeX cash floor)' }

    $result
}
