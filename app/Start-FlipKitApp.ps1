<#
.SYNOPSIS
    FlipKit's interactive app: a local web dashboard over the module.
.DESCRIPTION
    Pure PowerShell HTTP server (no dependencies) exposing the FlipKit functions
    as a JSON API, with a browser UI: deal checker, scanner, watchlist, ledger,
    stats, market, chat and settings. Binds to localhost only — it is a
    personal cockpit, not a website.
.EXAMPLE
    pwsh -File app/Start-FlipKitApp.ps1
    # then open http://localhost:8321
#>
[CmdletBinding()]
param(
    [int]$Port = 8321,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../FlipKit') -Force

$indexPath = Join-Path $PSScriptRoot 'wwwroot/index.html'

function Write-Json {
    param($Response, $Object, [int]$Status = 200)
    $Response.StatusCode = $Status
    $Response.ContentType = 'application/json; charset=utf-8'
    # -InputObject (not pipeline) keeps arrays as arrays, including empty and single-element ones.
    $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Object -Depth 6))
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

$listener = [System.Net.HttpListener]::new()
# Both spellings of loopback: HttpListener matches the Host header against the
# prefix literally, and "localhost" may resolve to either 127.0.0.1 or ::1.
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "FlipKit app running at http://localhost:$Port  (Ctrl+C to stop)"
if (-not $NoBrowser) {
    try { Start-Process "http://localhost:$Port" } catch { Write-Verbose 'Could not auto-open browser.' }
}

try {
    while ($listener.IsListening) {
        # Wait in short slices instead of blocking in GetContext(): PowerShell
        # can only honour Ctrl+C between statements, and a hard block inside
        # the listener call crashes the console on interrupt.
        $ctxTask = $listener.GetContextAsync()
        while (-not $ctxTask.Wait(250)) { }
        $ctx = $ctxTask.GetAwaiter().GetResult()
        $req = $ctx.Request
        $res = $ctx.Response
        $route = "$($req.HttpMethod) $($req.Url.AbsolutePath)"

        try {
            $body = if ($req.HasEntityBody) {
                [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd() | ConvertFrom-Json
            } else { $null }

            switch -Regex ($route) {
                '^GET /$' {
                    $res.ContentType = 'text/html; charset=utf-8'
                    $bytes = [IO.File]::ReadAllBytes($indexPath)
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                }

                '^GET /api/status$' {
                    $cfg = try { Get-FlipConfig } catch { $null }
                    $lastScanMinutes = $null
                    $hbPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'data/last-scan.json'
                    if (Test-Path $hbPath) {
                        try {
                            $hb = Get-Content -Raw $hbPath | ConvertFrom-Json
                            $at = [datetime]::Parse($hb.At, [System.Globalization.CultureInfo]::InvariantCulture,
                                [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
                            $lastScanMinutes = [int]([datetime]::UtcNow - $at).TotalMinutes
                        }
                        catch { }
                    }
                    Write-Json $res @{
                        configFound     = [bool]$cfg
                        ebayKeys        = [bool]($cfg -and $cfg.ebay.clientId -and $cfg.ebay.clientSecret)
                        alertsChannel   = [bool]($cfg -and ($cfg.alerts.ntfyTopic -or $cfg.alerts.telegramBotToken))
                        ai              = [bool]($cfg -and (($cfg.PSObject.Properties['ai'] -and $cfg.ai.provider) -or ($cfg.PSObject.Properties['anthropic'] -and $cfg.anthropic.apiKey)))
                        searches        = if ($cfg) { @($cfg.searches).Count } else { 0 }
                        lastScanMinutes = $lastScanMinutes
                    }
                }

                '^POST /api/chat$' {
                    $history = @($body.messages | ForEach-Object { @{ role = $_.role; content = $_.content } })
                    Write-Json $res @{ reply = (Invoke-FlipChat -Messages $history) }
                }

                '^POST /api/triage$' {
                    Write-Json $res @(Invoke-FlipTriage -Hits @($body.hits))
                }

                '^GET /api/pulse$' {
                    Write-Json $res (Get-FlipMarketPulse -Query $req.QueryString['q'])
                }

                '^POST /api/suggest$' {
                    Write-Json $res @(Invoke-FlipSuggest)
                }

                '^GET /api/comps$' {
                    $comps = Get-EbaySoldComps -SearchTerm $req.QueryString['q']
                    if (-not $comps) { throw 'No sold listings found for that search.' }
                    Write-Json $res $comps
                }

                '^GET /api/cex$' {
                    Write-Json $res @(Get-CexPrice -Query $req.QueryString['q'] -Top 5)
                }

                '^POST /api/deal-check$' {
                    $params = @{ SearchTerm = $body.searchTerm; BuyPrice = [double]$body.buyPrice }
                    if ($body.PSObject.Properties['postage'] -and "$($body.postage)" -ne '') { $params.Postage = [double]$body.postage }
                    Write-Json $res (Test-FlipDeal @params)
                }

                '^GET /api/ledger$' {
                    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'data/ledger.csv'
                    $rows = if (Test-Path $path) { @(Import-Csv $path) } else { @() }
                    Write-Json $res @($rows)
                }

                '^POST /api/ledger$' {
                    $entry = Add-FlipLedgerEntry -Item $body.item -Category $body.category -Source $body.source -BuyPrice ([double]$body.buyPrice) -Notes "$($body.notes)"
                    Write-Json $res $entry
                }

                '^POST /api/ledger/delete$' {
                    Remove-FlipLedgerEntry -Id ([int]$body.id)
                    Write-Json $res @{ ok = $true }
                }

                '^POST /api/ledger/complete$' {
                    $row = Complete-FlipLedgerEntry -Id ([int]$body.id) -SoldPrice ([double]$body.soldPrice) -Fees ([double]$body.fees) -Postage ([double]$body.postage)
                    Write-Json $res $row
                }

                '^GET /api/stats$' {
                    Write-Json $res (Get-FlipLedgerStats)
                }

                '^GET /api/settings$' {
                    Write-Json $res (Get-FlipSettingsView)
                }

                '^POST /api/settings$' {
                    Save-FlipSettings -New $body.config
                    Write-Json $res @{ ok = $true }
                }

                '^GET /api/hits$' {
                    Write-Json $res @(Get-FlipRecentHits)
                }

                '^POST /api/hits/dismiss$' {
                    Set-FlipHitDismissed -ItemId "$($body.itemId)"
                    Write-Json $res @{ ok = $true }
                }

                '^POST /api/hits/clear$' {
                    $search = if ($body -and $body.PSObject.Properties['search'] -and $body.search) { "$($body.search)" } else { '' }
                    $cleared = if ($search) { Clear-FlipRecentHits -Search $search } else { Clear-FlipRecentHits }
                    Write-Json $res @{ cleared = $cleared }
                }

                '^GET /api/description$' {
                    Write-Json $res @{ description = (Get-EbayItemDescription -ItemId $req.QueryString['itemId']) }
                }

                '^GET /api/watchlist$' {
                    Write-Json $res @(Get-FlipWatchlist)
                }

                '^POST /api/watchlist/add$' {
                    $w = Add-FlipWatch -ItemId "$($body.itemId)" -Title "$($body.title)" -Url "$($body.url)" `
                        -EndsAt "$($body.endsAt)" -MaxBid ([double]"0$($body.maxBid)") -Price ([double]"0$($body.price)")
                    Write-Json $res $w
                }

                '^POST /api/watchlist/remove$' {
                    Remove-FlipWatch -ItemId "$($body.itemId)"
                    Write-Json $res @{ ok = $true }
                }

                '^POST /api/listing$' {
                    Write-Json $res (New-FlipListing -Item "$($body.item)" -Notes "$($body.notes)")
                }

                '^POST /api/searches/add$' {
                    $params = @{ Name = $body.name; Query = $body.query; MaxPrice = [double]$body.maxPrice }
                    if ($body.PSObject.Properties['minPrice'] -and "$($body.minPrice)" -ne '' -and [double]$body.minPrice -gt 0) { $params.MinPrice = [double]$body.minPrice }
                    if ($body.PSObject.Properties['categoryIds'] -and $body.categoryIds) { $params.CategoryIds = $body.categoryIds }
                    Write-Json $res (Add-FlipSearch @params)
                }

                '^POST /api/scan$' {
                    $dry = -not ($body -and $body.PSObject.Properties['live'] -and $body.live)
                    $all = [bool]($body -and $body.PSObject.Properties['includeSeen'] -and $body.includeSeen)
                    # Surface per-search failures to the browser — the server
                    # window isn't visible from a phone.
                    $scanHits = @(Invoke-FlipScan -DryRun:$dry -IncludeSeen:$all -WarningVariable scanWarnings -WarningAction SilentlyContinue)
                    Write-Json $res @{
                        hits     = $scanHits
                        warnings = @($scanWarnings | ForEach-Object { "$_" })
                    }
                }

                default {
                    Write-Json $res @{ error = "No route: $route" } 404
                }
            }
        }
        catch {
            Write-Json $res @{ error = "$($_.Exception.Message)" } 500
        }
        finally {
            $res.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
