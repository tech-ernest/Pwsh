<#
.SYNOPSIS
    Registers the weekly data backup as a Windows scheduled task (Sundays 18:00).
.DESCRIPTION
    Run once from an elevated PowerShell. On Linux/macOS use cron instead:

        0 18 * * 0 pwsh -File /path/to/Pwsh/scripts/Backup-FlipData.ps1
#>
[CmdletBinding()]
param(
    [string]$TaskName = 'FlipKit weekly backup',
    [string]$At = '18:00'
)

if (-not $IsWindows) {
    Write-Host 'Not Windows — add this cron line instead:'
    Write-Host "0 18 * * 0 pwsh -File $(Join-Path $PSScriptRoot 'Backup-FlipData.ps1')"
    return
}

$scriptPath = Join-Path $PSScriptRoot 'Backup-FlipData.ps1'

$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "Registered '$TaskName' — Sundays at $At."
