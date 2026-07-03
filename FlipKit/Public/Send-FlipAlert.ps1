function Send-FlipAlert {
    <#
    .SYNOPSIS
        Pushes a deal alert to your phone via ntfy (and/or Telegram).
    .DESCRIPTION
        ntfy needs zero setup: pick a hard-to-guess topic string, put it in config,
        and subscribe to it in the ntfy app. Telegram is optional (bot token + chat
        id in config). Alert failures warn but never throw — a dead phone app
        shouldn't kill the scan loop.
    .EXAMPLE
        Send-FlipAlert -Title 'RTX 3060 £140' -Message 'Median sold £210' -Url 'https://ebay.co.uk/itm/...'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message,
        [string]$Url,
        [ValidateRange(1, 5)][int]$Priority = 4
    )

    $cfg = Get-FlipConfig
    $sent = $false
    $configured = $false

    if ($cfg.alerts.ntfyTopic) {
        $configured = $true
        try {
            # JSON publish endpoint: HTTP headers are ASCII-only, and titles
            # carry £ signs and the odd emoji — the JSON body is full UTF-8.
            $payload = @{
                topic    = $cfg.alerts.ntfyTopic
                title    = $Title
                message  = $Message
                priority = $Priority
                tags     = @('moneybag')
            }
            if ($Url) { $payload.click = $Url }
            $body = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $payload -Compress))
            Invoke-RestMethod -Method Post -Uri 'https://ntfy.sh' -ContentType 'application/json; charset=utf-8' -Body $body | Out-Null
            $sent = $true
        }
        catch { Write-Warning "ntfy alert failed: $_" }
    }

    if ($cfg.alerts.telegramBotToken -and $cfg.alerts.telegramChatId) {
        $configured = $true
        try {
            $text = "*$Title*`n$Message"
            if ($Url) { $text += "`n$Url" }
            Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$($cfg.alerts.telegramBotToken)/sendMessage" -Body @{
                chat_id    = $cfg.alerts.telegramChatId
                text       = $text
                parse_mode = 'Markdown'
            } | Out-Null
            $sent = $true
        }
        catch { Write-Warning "Telegram alert failed: $_" }
    }

    if (-not $sent) {
        if (-not $configured) { Write-Warning 'No alert channel configured (set alerts.ntfyTopic in config).' }
        Write-Host "[ALERT] $Title — $Message $Url"
    }
}
