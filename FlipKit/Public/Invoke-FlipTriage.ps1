function Invoke-FlipTriage {
    <#
    .SYNOPSIS
        Has the configured AI model score scan hits by expected profit and repair difficulty.
    .DESCRIPTION
        Sends the hit list to Claude with a strict JSON schema (structured
        outputs) so every item comes back with a tier (hot / worth_a_look /
        skip), a fix-difficulty rating, and estimated resale + net profit.
        The app's Scanner tab uses this to group results.
    .EXAMPLE
        Invoke-FlipScan -DryRun | Invoke-FlipTriage
    #>
    [CmdletBinding()]
    param(
        # Scan hits: objects with Title, Price, Condition (Search/Url/Note optional)
        [Parameter(Mandatory, ValueFromPipeline)][array]$Hits
    )

    begin { $all = [System.Collections.Generic.List[object]]::new() }
    process { foreach ($h in $Hits) { $all.Add($h) } }
    end {
        # Bound the request: 40 items is plenty per triage round.
        $batch = @($all | Select-Object -First 40)
        if ($batch.Count -eq 0) { return }

        $itemLines = for ($i = 0; $i -lt $batch.Count; $i++) {
            $h = $batch[$i]
            $line = "[$i] $($h.Title) | asking GBP $($h.Price) | condition: $($h.Condition)"
            # The seller's own words — the real fault usually lives here.
            if ($h.PSObject.Properties['Description'] -and $h.Description) {
                $snippet = "$($h.Description)"
                if ($snippet.Length -gt 400) { $snippet = $snippet.Substring(0, 400) + '…' }
                $line += " | seller description: $snippet"
            }
            $line
        }

        $schema = @{
            type                 = 'object'
            additionalProperties = $false
            required             = @('items')
            properties           = @{
                items = @{
                    type  = 'array'
                    items = @{
                        type                 = 'object'
                        additionalProperties = $false
                        required             = @('index', 'tier', 'fix_difficulty', 'est_resale_gbp', 'est_parts_cost_gbp', 'est_net_profit_gbp', 'note')
                        properties           = @{
                            index               = @{ type = 'integer' }
                            tier                = @{ type = 'string'; enum = @('hot', 'worth_a_look', 'skip') }
                            fix_difficulty      = @{ type = 'string'; enum = @('none', 'easy', 'moderate', 'hard', 'unknown') }
                            est_resale_gbp      = @{ type = 'number' }
                            est_parts_cost_gbp  = @{ type = 'number' }
                            est_net_profit_gbp  = @{ type = 'number' }
                            note                = @{ type = 'string' }
                        }
                    }
                }
            }
        }

        $system = (Get-FlipChatSystemPrompt) + @'


Task: triage the numbered listings below for this reseller. For each item estimate:
- est_resale_gbp: realistic eBay UK sold price for the item once working (or parted out), based on the model in the title. Be conservative.
- est_parts_cost_gbp: likely cost of parts for the fix, UK prices (laptop screen 40-70, laptop battery 20-40, laptop keyboard/palmrest 15-30, GPU fan set 10-20, SSD 20-40, watch strap 5-10, thermal paste/pads 5; 0 when nothing is needed).
- est_net_profit_gbp: est_resale minus 13% + GBP 0.30 eBay fees, GBP 3.35 postage, the asking price, and est_parts_cost_gbp.
- fix_difficulty: none (works / cosmetic), easy (battery swap, reseat RAM, clear CMOS, new strap, basic solder-free fix), moderate (fan swap, screen replacement, minor soldering), hard (BGA/GPU core work, water damage, unknown-cause dead boards), unknown (too little information to judge).
- tier: hot = clears the 30% margin rule with an easy-or-none fix; worth_a_look = decent margin but moderate difficulty or uncertainty; skip = thin margin, hard fix, accessories/box-only junk, or scam-pattern listings.
Judge fixability from the fault described ("battery doesn't hold charge" = easy; "no display" on a GPU = moderate-to-hard; "artefacting" = hard). When a seller description is provided, trust it over the title — sellers bury the real fault there ("BIOS locked", "liquid damage", "no power"). BIOS/administrator-locked or activation-locked machines are skip. Box-only, cables, brackets and other accessories are skip unless genuinely profitable as accessories.
'@

        $text = Invoke-FlipAi -System $system -JsonSchema $schema `
            -Messages @(@{ role = 'user'; content = ($itemLines -join "`n") })
        $parsed = ConvertFrom-FlipAiJson -Text $text

        foreach ($t in $parsed.items) {
            if ($t.index -lt 0 -or $t.index -ge $batch.Count) { continue }
            $h = $batch[$t.index]
            [pscustomobject]@{
                ItemId        = if ($h.PSObject.Properties['ItemId']) { $h.ItemId } else { '' }
                Title         = $h.Title
                Price         = $h.Price
                Condition     = $h.Condition
                Url           = if ($h.PSObject.Properties['Url']) { $h.Url } else { '' }
                Search        = if ($h.PSObject.Properties['Search']) { $h.Search } else { '' }
                Buying        = if ($h.PSObject.Properties['Buying']) { $h.Buying } else { '' }
                EndsAt        = if ($h.PSObject.Properties['EndsAt']) { $h.EndsAt } else { '' }
                BidCount      = if ($h.PSObject.Properties['BidCount']) { $h.BidCount } else { $null }
                Description   = if ($h.PSObject.Properties['Description']) { $h.Description } else { '' }
                Tier          = $t.tier
                FixDifficulty = $t.fix_difficulty
                EstResale     = [math]::Round([double]$t.est_resale_gbp, 2)
                PartsCost     = [math]::Round([double]$t.est_parts_cost_gbp, 2)
                EstNetProfit  = [math]::Round([double]$t.est_net_profit_gbp, 2)
                Note          = $t.note
            }
        }
    }
}
