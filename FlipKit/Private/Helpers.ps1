function Get-FlipDataDir {
    $dir = Join-Path $script:RepoRoot 'data'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $dir
}

function Get-PriceStats {
    <#
        Computes summary stats over a list of prices. Shared by comps and anything
        else that needs a quick distribution read.
    #>
    param([Parameter(Mandatory)][double[]]$Prices)

    $sorted = $Prices | Sort-Object
    $n = $sorted.Count

    $pct = {
        param($p)
        if ($n -eq 1) { return [math]::Round($sorted[0], 2) }
        $rank = $p * ($n - 1)
        $lo = [math]::Floor($rank); $hi = [math]::Ceiling($rank)
        [math]::Round($sorted[$lo] + (($rank - $lo) * ($sorted[$hi] - $sorted[$lo])), 2)
    }

    [pscustomobject]@{
        Count  = $n
        Min    = [math]::Round($sorted[0], 2)
        P25    = & $pct 0.25
        Median = & $pct 0.5
        P75    = & $pct 0.75
        Max    = [math]::Round($sorted[-1], 2)
        Mean   = [math]::Round(($sorted | Measure-Object -Average).Average, 2)
    }
}

$script:BrowserUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

function Invoke-FlipWebRequest {
    <#
        Polite HTTP wrapper for the scraping-side functions.

        Transport: prefers curl.exe when available (ships with Windows 10+).
        PowerShell's own HTTP stack has a TLS fingerprint Cloudflare and other
        bot walls flag; curl's passes as a normal client. Falls back to
        Invoke-WebRequest where curl.exe is missing.

        -AsBrowser adds the full header set a real browser navigation sends
        (needed for HTML pages; eBay error-pages bare requests).
        -CookieJar (a file path) carries cookies across calls for the warm-up
        pattern; used by both transports.

        Alert-only tooling — keep request rates low and back off on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers = @{},
        [int]$TimeoutSec = 25,
        [switch]$AsBrowser,
        [string]$CookieJar
    )

    $Headers['Accept-Language'] = 'en-GB,en;q=0.9'
    if ($AsBrowser) {
        if (-not $Headers.ContainsKey('Accept')) {
            $Headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
        }
        $Headers['Upgrade-Insecure-Requests'] = '1'
        $Headers['Sec-Fetch-Dest'] = 'document'
        $Headers['Sec-Fetch-Mode'] = 'navigate'
        $Headers['Sec-Fetch-Site'] = 'none'
        $Headers['Sec-Fetch-User'] = '?1'
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue

    foreach ($attempt in 1..2) {
        try {
            if ($curl) {
                # -4: residential IPv6 ranges score worse with bot walls (Cloudflare
                # blocked a user's IPv6 while IPv4 passed) — prefer IPv4 throughout.
                $args = @('-sS', '-4', '--fail-with-body', '--compressed', '--max-time', $TimeoutSec, '-A', $script:BrowserUA)
                foreach ($k in $Headers.Keys) { $args += @('-H', "${k}: $($Headers[$k])") }
                if ($CookieJar) { $args += @('-b', $CookieJar, '-c', $CookieJar) }
                $args += $Uri

                $content = & $curl.Source @args 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) { throw "curl failed (exit $LASTEXITCODE): $($content.Substring(0, [math]::Min(300, $content.Length)))" }
                return [pscustomobject]@{ Content = $content }
            }
            else {
                $params = @{ Uri = $Uri; Headers = $Headers; TimeoutSec = $TimeoutSec; ErrorAction = 'Stop' }
                $params.Headers['User-Agent'] = $script:BrowserUA
                if ($CookieJar) {
                    # Approximate the jar with an in-memory session per jar path.
                    if (-not $script:IwrSessions) { $script:IwrSessions = @{} }
                    if (-not $script:IwrSessions.ContainsKey($CookieJar)) {
                        $script:IwrSessions[$CookieJar] = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
                    }
                    $params.WebSession = $script:IwrSessions[$CookieJar]
                }
                return Invoke-WebRequest @params
            }
        }
        catch {
            if ($attempt -eq 2) { throw }
            Start-Sleep -Seconds 5
        }
    }
}
