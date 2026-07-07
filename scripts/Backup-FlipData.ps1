<#
.SYNOPSIS
    Zips the business records (ledger, hit history, watchlist, config) into a dated backup.
.DESCRIPTION
    The ledger is the operation's books — HMRC-relevant once you register as a
    sole trader — and it lives in one CSV on one disk. This keeps dated zips
    (last 8 by default) so a dead drive doesn't erase them.

    NOTE: the zip includes config/settings.json, which holds API keys. Keep
    the destination private (a personal OneDrive folder is fine; a shared
    drive is not).
.EXAMPLE
    pwsh -File scripts/Backup-FlipData.ps1
.EXAMPLE
    pwsh -File scripts/Backup-FlipData.ps1 -Destination "$env:OneDrive\FlipKit-backups"
#>
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path (Split-Path $PSScriptRoot -Parent) 'backups'),
    [int]$Keep = 8
)

$repo = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$stamp = Get-Date -Format 'yyyy-MM-dd-HHmm'
$zip = Join-Path $Destination "flipkit-backup-$stamp.zip"

# Stage into a temp folder and zip with the .NET API — Compress-Archive
# silently produces nothing for folders of zero-byte files, and a backup
# script must never silently succeed with no file.
$stage = Join-Path ([IO.Path]::GetTempPath()) "flipkit-backup-stage-$stamp"
New-Item -ItemType Directory -Path (Join-Path $stage 'data'), (Join-Path $stage 'config') -Force | Out-Null
try {
    if (Test-Path (Join-Path $repo 'data')) {
        Copy-Item -Path (Join-Path $repo 'data/*') -Destination (Join-Path $stage 'data') -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path (Join-Path $repo 'config/settings.json')) {
        Copy-Item -Path (Join-Path $repo 'config/settings.json') -Destination (Join-Path $stage 'config') -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $zip) { Remove-Item $zip }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
    if (-not (Test-Path $zip)) { throw "Backup zip was not created at $zip" }
}
finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}

# Prune: newest $Keep stay (stamped names sort chronologically).
Get-ChildItem -Path $Destination -Filter 'flipkit-backup-*.zip' |
    Sort-Object Name -Descending | Select-Object -Skip $Keep | Remove-Item

Write-Host "Backed up to $zip (keeping the newest $Keep)."
