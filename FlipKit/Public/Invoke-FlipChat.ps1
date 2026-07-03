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

function Invoke-FlipClaudeApi {
    <#
        Shared Anthropic Messages API caller (PowerShell has no official SDK,
        so this is raw HTTP). $Body is the request hashtable minus model,
        which is resolved from config here.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Body,
        [string]$Model
    )

    $cfg = Get-FlipConfig
    $anthropic = if ($cfg.PSObject.Properties['anthropic']) { $cfg.anthropic } else { $null }
    if (-not $anthropic -or -not $anthropic.apiKey) {
        throw "Anthropic API key missing. Get one at console.anthropic.com and add it to config/settings.json under `"anthropic`": { `"apiKey`": `"sk-ant-...`" }."
    }

    if (-not $Model) {
        $Model = if ($anthropic.PSObject.Properties['model'] -and $anthropic.model) { $anthropic.model } else { 'claude-opus-4-8' }
    }
    $Body.model = $Model

    $json = $Body | ConvertTo-Json -Depth 12

    try {
        Invoke-RestMethod -Method Post -Uri 'https://api.anthropic.com/v1/messages' `
            -Headers @{ 'x-api-key' = $anthropic.apiKey; 'anthropic-version' = '2023-06-01' } `
            -ContentType 'application/json; charset=utf-8' `
            -Body ([Text.Encoding]::UTF8.GetBytes($json)) `
            -TimeoutSec 300
    }
    catch {
        # Surface the API's own error message (invalid key, overloaded, ...) instead of raw HTTP noise.
        $apiMessage = try { ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch { $null }
        if ($apiMessage) { throw "Claude API error: $apiMessage" }
        throw
    }
}

function Invoke-FlipChat {
    <#
    .SYNOPSIS
        Sends a chat conversation to Claude with live business context; returns the reply text.
    .DESCRIPTION
        Needs anthropic.apiKey in config/settings.json - create one at
        console.anthropic.com. Model defaults to claude-opus-4-8; set
        anthropic.model in config to change it (e.g. claude-haiku-4-5 for cheaper).
    .EXAMPLE
        Invoke-FlipChat -Messages @(@{ role = 'user'; content = 'Is 40 quid sane for a faulty Forerunner 245?' })
    #>
    [CmdletBinding()]
    param(
        # Full conversation history: array of @{ role = 'user'|'assistant'; content = '...' }
        [Parameter(Mandatory)][array]$Messages,
        [string]$Model
    )

    $resp = Invoke-FlipClaudeApi -Model $Model -Body @{
        max_tokens = 16000
        thinking   = @{ type = 'adaptive' }
        system     = Get-FlipChatSystemPrompt
        messages   = $Messages
    }

    if ($resp.stop_reason -eq 'refusal') {
        return '(Claude declined to answer that request.)'
    }

    # Thinking blocks come first; the reply is the text blocks.
    (@($resp.content) | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join "`n"
}
