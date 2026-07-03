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
        Polite HTTP wrapper for the scraping-side functions: browser-ish headers,
        timeout, and a single retry with backoff. Alert-only tooling — keep
        request rates low and back off on failure rather than hammering.

        -AsBrowser sends the full header set a real browser navigation sends —
        needed for HTML pages (eBay serves an error page to bare requests).
        -WebSession carries cookies across calls (warm-up pattern).
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers = @{},
        [int]$TimeoutSec = 20,
        [switch]$AsBrowser,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
    )

    $Headers['User-Agent'] = $script:BrowserUA
    $Headers['Accept-Language'] = 'en-GB,en;q=0.9'

    if ($AsBrowser) {
        $Headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
        $Headers['Upgrade-Insecure-Requests'] = '1'
        $Headers['Sec-Fetch-Dest'] = 'document'
        $Headers['Sec-Fetch-Mode'] = 'navigate'
        $Headers['Sec-Fetch-Site'] = 'none'
        $Headers['Sec-Fetch-User'] = '?1'
    }

    $params = @{
        Uri        = $Uri
        Headers    = $Headers
        TimeoutSec = $TimeoutSec
        ErrorAction = 'Stop'
    }
    if ($WebSession) { $params.WebSession = $WebSession }

    foreach ($attempt in 1..2) {
        try {
            return Invoke-WebRequest @params
        }
        catch {
            if ($attempt -eq 2) { throw }
            Start-Sleep -Seconds 5
        }
    }
}
