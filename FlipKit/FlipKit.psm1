Set-StrictMode -Version Latest

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:EbayTokenCache = $null

foreach ($scope in 'Private', 'Public') {
    Get-ChildItem -Path (Join-Path $PSScriptRoot $scope) -Filter '*.ps1' -ErrorAction SilentlyContinue |
        ForEach-Object { . $_.FullName }
}
