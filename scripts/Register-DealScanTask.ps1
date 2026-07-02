<#
.SYNOPSIS
    Registers the deal scan as a Windows scheduled task (every 15 minutes).
.DESCRIPTION
    Run once from an elevated PowerShell on the machine that will do the scanning.
    On Linux/macOS use cron instead:

        */15 * * * * pwsh -File /path/to/Pwsh/scripts/Invoke-DealScan.ps1 >> /path/to/Pwsh/data/scan.log 2>&1
#>
[CmdletBinding()]
param(
    [int]$EveryMinutes = 15,
    [string]$TaskName = 'FlipKit deal scan'
)

if (-not $IsWindows) {
    Write-Host 'Not Windows — add this cron line instead:'
    Write-Host "*/$EveryMinutes * * * * pwsh -File $(Join-Path $PSScriptRoot 'Invoke-DealScan.ps1') >> $(Join-Path (Split-Path $PSScriptRoot -Parent) 'data/scan.log') 2>&1"
    return
}

$scriptPath = Join-Path $PSScriptRoot 'Invoke-DealScan.ps1'

$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "Registered '$TaskName' to run every $EveryMinutes minutes."
