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

    if ($cfg.alerts.ntfyTopic) {
        try {
            $headers = @{ Title = $Title; Priority = $Priority; Tags = 'moneybag' }
            if ($Url) { $headers.Click = $Url }
            Invoke-RestMethod -Method Post -Uri "https://ntfy.sh/$($cfg.alerts.ntfyTopic)" -Headers $headers -Body $Message | Out-Null
            $sent = $true
        }
        catch { Write-Warning "ntfy alert failed: $_" }
    }

    if ($cfg.alerts.telegramBotToken -and $cfg.alerts.telegramChatId) {
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

    if (-not $sent) { Write-Warning 'No alert channel configured (set alerts.ntfyTopic in config) — printing instead.'; Write-Host "[ALERT] $Title — $Message $Url" }
}
