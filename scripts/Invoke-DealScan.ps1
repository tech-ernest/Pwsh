<#
.SYNOPSIS
    Scheduled entry point for the deal scan — thin wrapper around Invoke-FlipScan.
.DESCRIPTION
    Run every 10-15 min via Task Scheduler or cron — see Register-DealScanTask.ps1.
.EXAMPLE
    pwsh -File scripts/Invoke-DealScan.ps1
.EXAMPLE
    pwsh -File scripts/Invoke-DealScan.ps1 -DryRun   # print hits, no alerts, no state update
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../FlipKit') -Force

$hits = @(Invoke-FlipScan -DryRun:$DryRun -Verbose)

foreach ($hit in $hits) {
    Write-Host "[HIT] $($hit.Search): $($hit.Title) — £$($hit.Price) $($hit.Note)`n      $($hit.Url)"
}

Write-Host "Done. $($hits.Count) new hit(s)."
