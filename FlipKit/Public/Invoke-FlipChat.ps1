function Get-FlipChatSystemPrompt {
    <#
    .SYNOPSIS
        Builds the business-context system prompt for the chat: live ledger
        stats, open stock, and the saved search config, so Claude discusses
        YOUR numbers rather than generalities.
    #>
    [CmdletBinding()]
    param()

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add(@'
You are FlipKit Copilot, the business assistant inside a self-hosted dashboard for a UK-based eBay/Vinted reselling side business, run solo alongside a full-time job (5-10 hours/week).

The business model: buy underpriced used items found by automated eBay scans, resell at a minimum 30% net margin after eBay fees (~13% + £0.30) and postage (~£3.35). Primary niches: PC hardware (GPUs, CPUs, faulty/untested listings, part-out desktop towers) and fitness tech (Garmin/Polar watches). Clothing is a small capped experiment. Working capital is limited (started around £750), so capital tied up in slow stock is the main risk; dead stock should be repriced or dumped rather than held.

Your job: help evaluate deals, think through pricing and margins, decide which categories deserve more capital, draft listing titles/descriptions, and answer business questions (including UK basics like eBay fees and HMRC self-assessment at a general-information level - recommend a professional for specific tax advice). Be direct and numeric: when a purchase idea does not clear the 30% margin rule, say so. Keep answers concise and practical - this is a working tool, not an essay generator.
'@)

    $lines.Add("Today's date: $(Get-Date -Format 'yyyy-MM-dd').")

    # Live ledger snapshot
    try {
        $stats = Get-FlipLedgerStats
        $s = $stats.Summary
        $lines.Add("Current ledger: $($s.FlipsCompleted) completed flips, total net profit GBP $($s.TotalNetProfit), average margin $($s.AvgMarginPct)%, average days-to-sell $($s.AvgDaysToSell). Open stock: $($s.OpenItems) items with GBP $($s.CapitalDeployed) capital deployed.")
        foreach ($c in @($stats.ByCategory)) {
            $lines.Add("Category '$($c.Category)': $($c.Flips) flips, GBP $($c.NetProfit) net, avg $($c.AvgDaysToSell) days to sell.")
        }
        $path = Join-Path (Get-FlipDataDir) 'ledger.csv'
        $open = @(Import-Csv $path | Where-Object { -not $_.SoldDate })
        if ($open) {
            $lines.Add('Open (unsold) items: ' + (($open | ForEach-Object { "#$($_.Id) $($_.Item) bought $($_.BuyDate) for GBP $($_.BuyPrice)" }) -join '; ') + '.')
        }
    }
    catch { $lines.Add('The ledger is empty so far - no purchases recorded yet.') }

    # Scanner config
    try {
        $cfg = Get-FlipConfig
        $searches = @($cfg.searches | ForEach-Object { "'$($_.name)' (query: $($_.query), max GBP $($_.maxPrice))" })
        if ($searches) { $lines.Add('Active scanner searches: ' + ($searches -join '; ') + '.') }
    }
    catch { }

    $lines -join "`n`n"
}

function Invoke-FlipChat {
    <#
    .SYNOPSIS
        Chat with the configured AI model with live business context; returns the reply text.
    .DESCRIPTION
        Uses the provider from config's "ai" section - Ollama (free, local),
        any OpenAI-compatible API (Groq/OpenRouter/Gemini free tiers), or the
        Claude API. See config/settings.sample.json.
    .EXAMPLE
        Invoke-FlipChat -Messages @(@{ role = 'user'; content = 'Is 40 quid sane for a faulty Forerunner 245?' })
    #>
    [CmdletBinding()]
    param(
        # Full conversation history: array of @{ role = 'user'|'assistant'; content = '...' }
        [Parameter(Mandatory)][array]$Messages
    )

    Invoke-FlipAi -System (Get-FlipChatSystemPrompt) -Messages $Messages
}
