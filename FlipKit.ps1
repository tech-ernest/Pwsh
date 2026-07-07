#requires -Version 7.0
<#
.SYNOPSIS
    FlipKit control panel — a menu for the everyday commands.
.DESCRIPTION
    Double-click FlipKit.cmd (or run: pwsh -File FlipKit.ps1). Every option
    is something you'd otherwise type by hand: update, start the dashboard,
    scan, test, back up, health check.
#>
[CmdletBinding()]
param()

Set-Location $PSScriptRoot

function Pause-Menu { Write-Host ''; Read-Host 'Press Enter to return to the menu' | Out-Null }

function Show-Health {
    Import-Module ./FlipKit -Force
    try { Get-FlipConfig | Out-Null; Write-Host '  config:        OK' -ForegroundColor Green }
    catch { Write-Host "  config:        MISSING — $_" -ForegroundColor Red; return }

    try { Get-EbayToken | Out-Null; Write-Host '  eBay API:      OK' -ForegroundColor Green }
    catch { Write-Host "  eBay API:      FAILED — $_" -ForegroundColor Red }

    try {
        foreach ($q in @(Get-EbayQuota)) {
            $colour = if ($q.UsedPct -ge 80) { 'Yellow' } else { 'Gray' }
            Write-Host "  eBay quota:    $($q.Resource): $($q.Used)/$($q.Limit) used ($($q.UsedPct)%) — resets $($q.ResetsAt)" -ForegroundColor $colour
        }
    }
    catch { Write-Host "  eBay quota:    unavailable ($_)" -ForegroundColor Gray }

    $hbPath = 'data/last-scan.json'
    if (Test-Path $hbPath) {
        try {
            $hb = Get-Content -Raw $hbPath | ConvertFrom-Json
            $age = [int]([datetime]::UtcNow - [datetime]::Parse($hb.At, [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()).TotalMinutes
            $colour = if ($age -le 45) { 'Green' } else { 'Yellow' }
            Write-Host "  auto-scan:     last ran ${age}m ago$(if ($age -gt 45) { ' — scheduled task may be dead (menu option 7)' })" -ForegroundColor $colour
        }
        catch { Write-Host '  auto-scan:     heartbeat unreadable' -ForegroundColor Yellow }
    }
    else { Write-Host '  auto-scan:     never ran — register the task (menu option 7)' -ForegroundColor Yellow }

    $watch = @(try { Get-FlipWatchlist } catch { })
    Write-Host "  watchlist:     $($watch.Count) auction(s) being watched"
    $cfg = Get-FlipConfig
    Write-Host "  searches:      $(@($cfg.searches).Count) saved lanes"
}

while ($true) {
    Clear-Host
    Write-Host ''
    Write-Host '  FlipKit control panel' -ForegroundColor Cyan
    Write-Host '  =====================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1) Update FlipKit          (git pull — restart app after)'
    Write-Host '  2) Start the dashboard     (opens browser; leave its window running)'
    Write-Host '  3) Scan now — live         (alerts + marks seen)'
    Write-Host '  4) Scan now — dry run      (just list, no alerts)'
    Write-Host '  5) Health check            (config, eBay API, auto-scan heartbeat)'
    Write-Host '  6) Back up data now'
    Write-Host '  7) Set up auto-scan + weekly backup tasks   (run this menu as admin)'
    Write-Host '  8) Run the test suite'
    Write-Host '  Q) Quit'
    Write-Host ''
    $choice = (Read-Host '  Pick an option').Trim().ToUpper()
    Write-Host ''

    switch ($choice) {
        '1' {
            git pull --ff-only
            Write-Host "`nIf the dashboard is running, close its window and start it again (option 2) to pick up changes." -ForegroundColor Yellow
            Pause-Menu
        }
        '2' {
            Start-Process pwsh -ArgumentList '-NoProfile', '-File', (Join-Path $PSScriptRoot 'app/Start-FlipKitApp.ps1')
            Start-Sleep -Seconds 3
            Start-Process 'http://localhost:8321'
            Write-Host 'Dashboard starting in its own window — closing that window stops it.'
            Pause-Menu
        }
        '3' {
            Import-Module ./FlipKit -Force
            @(Invoke-FlipScan) | Format-Table Search, Title, Price, Condition -AutoSize
            Pause-Menu
        }
        '4' {
            Import-Module ./FlipKit -Force
            @(Invoke-FlipScan -DryRun) | Format-Table Search, Title, Price, Condition -AutoSize
            Pause-Menu
        }
        '5' { Show-Health; Pause-Menu }
        '6' { pwsh -NoProfile -File scripts/Backup-FlipData.ps1; Pause-Menu }
        '7' {
            try {
                pwsh -NoProfile -File scripts/Register-DealScanTask.ps1
                pwsh -NoProfile -File scripts/Register-BackupTask.ps1
            }
            catch { Write-Host "Failed — close this and re-run FlipKit.cmd by right-clicking → 'Run as administrator'. ($_)" -ForegroundColor Red }
            Pause-Menu
        }
        '8' { pwsh -NoProfile -File tests/Run-Tests.ps1; Pause-Menu }
        'Q' { return }
        default { }
    }
}
