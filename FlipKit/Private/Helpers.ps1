function Get-FlipDataDir {
    $dir = Join-Path $script:RepoRoot 'data'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $dir
}

function ConvertTo-FlipUtcDate {
    <#
        Normalizes an eBay end-date value (already a [datetime], or an ISO-ish
        string) to a Kind=Utc [datetime], without ever treating an unmarked
        value as local time. eBay's itemEndDate is always UTC; PowerShell's
        JSON round-tripping sometimes hands it back as a string, sometimes
        auto-converts it to a [datetime] — and [datetime]::Parse on a non-string
        argument implicitly stringifies it via a culture-formatted ToString()
        that drops the Kind marker, so a later ToUniversalTime() wrongly
        re-shifts it by the local UTC/BST offset. This pins the Kind explicitly
        at every step instead of trusting whatever Kind survived the last hop.
    #>
    param($Value)
    if ($null -eq $Value -or $Value -eq '') { return $null }
    try {
        $dt = if ($Value -is [datetime]) { $Value } else {
            [datetime]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind)
        }
        if ($dt.Kind -eq [System.DateTimeKind]::Utc) { $dt } else { [datetime]::SpecifyKind($dt, [System.DateTimeKind]::Utc) }
    }
    catch { $null }
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

function Get-FlipTokenPattern {
    <#
        Regex for one search token. Digit/letter runs joined by optional
        space or dash, with type-aware boundaries: '3060' must not match
        '13060', but may sit inside 'RTX3060'; 'rtx' must not match 'rtxa'.
    #>
    param([Parameter(Mandatory)][string]$Token)
    $runs = @([regex]::Matches($Token, '\d+|[a-z]+') | ForEach-Object { [regex]::Escape($_.Value) })
    $lead  = if ($Token[0] -match '\d') { '(?<!\d)' } else { '(?<![a-z])' }
    $trail = if ($Token[-1] -match '\d') { '(?!\d)' } else { '(?![a-z])' }
    $lead + ($runs -join '[\s-]*') + $trail
}

function Select-FlipRelevantSolds {
    <#
        Filters parsed sold listings down to genuine comps for the term.
        A token that matches nothing in ANY title (a seller-specific suffix
        like "sl50") is noise — drop it and filter on the rest, instead of
        letting one junk token disable the whole filter and poison the stats
        with off-model results.
    #>
    param(
        [Parameter(Mandatory)][array]$Items,
        [Parameter(Mandatory)][string]$SearchTerm
    )

    $note = $null
    $term = $SearchTerm.ToLowerInvariant()
    $tokens = @([regex]::Split($term, '[^a-z0-9]+') | Where-Object { $_ })
    $dead = @($tokens | Where-Object {
        $p = Get-FlipTokenPattern $_
        -not @($Items | Where-Object { $_.Title -match $p })
    })
    if ($dead.Count -gt 0 -and $dead.Count -lt $tokens.Count) {
        $term = @($tokens | Where-Object { $dead -notcontains $_ }) -join ' '
        $note = "ignored '{0}' — matched no sold titles" -f ($dead -join "', '")
    }

    [pscustomobject]@{
        Items = @($Items | Where-Object { Test-FlipCompRelevant -Title $_.Title -SearchTerm $term })
        Term  = $term
        Note  = $note
    }
}

function Test-FlipCompRelevant {
    <#
        Decides whether a sold listing's title is a genuine comp for the search
        term. eBay's sold search is fuzzy: "rtx 3060" returns whole gaming PCs,
        laptops, Ti variants and replacement fans, all of which poison the
        price stats. Rules:
          - every search token must appear in the title (tolerant of spacing:
            "12GB"/"12 GB", "RTX3060"/"RTX 3060")
          - a Ti/Super suffix on a number the search didn't ask for is a
            different product
          - whole-system, accessory-only and faulty/parts wording disqualifies
            a title, unless the search itself is in that territory
            ("gaming pc", "garmin faulty")
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$SearchTerm
    )

    $t = $Title.ToLowerInvariant()
    $s = $SearchTerm.ToLowerInvariant()
    $tokens = @([regex]::Split($s, '[^a-z0-9]+') | Where-Object { $_ })

    foreach ($token in $tokens) {
        if ($t -notmatch (Get-FlipTokenPattern $token)) { return $false }
    }

    # Variant guard: search said "3060", title says "3060 Ti" — different card.
    foreach ($token in $tokens) {
        if ($token -notmatch '^\d{3,}$') { continue }
        foreach ($variant in 'ti', 'super') {
            if ($tokens -notcontains $variant -and $t -match "(?<!\d)$token\s*-?\s*$variant(?![a-z])") { return $false }
        }
    }

    # Off-item wording, grouped; a group is skipped entirely when the search
    # itself uses one of its phrases.
    $groups = @(
        # whole systems and bundles, when pricing a component
        @('gaming pc', 'gaming tower', 'pc tower', 'desktop', 'laptop', 'notebook', 'all-in-one', 'all in one', 'bundle', 'system unit', 'full system', 'ryzen', 'core i3', 'core i5', 'core i7', 'core i9', 'i3-', 'i5-', 'i7-', 'i9-'),
        # accessories and empty boxes masquerading as the item
        @('fan replacement', 'replacement fan', 'fan only', 'box only', 'empty box', 'shroud', 'backplate', 'waterblock', 'cable only'),
        # defective units — they sell cheap and drag the median down
        @('faulty', 'spares', 'repair', 'not working', 'no power', 'for parts', 'parts only', 'broken', 'damaged', 'untested', 'cracked')
    )
    # The whole-systems group exists to keep gaming PCs and laptops out of
    # *component* searches; when the search itself targets a machine
    # (EliteBook, ThinkPad, "laptop"...), those words are expected in titles.
    $systemish = 'elitebook|probook|zbook|thinkpad|latitude|precision|macbook|chromebook|ideapad|vivobook|pavilion|inspiron|aspire|laptop|notebook|desktop|tower|imac|nuc'

    foreach ($group in $groups) {
        $isSystemsGroup = $group -contains 'laptop'
        if ($isSystemsGroup -and $s -match $systemish) { continue }
        if (@($group | Where-Object { $s.Contains($_) }).Count -gt 0) { continue }
        foreach ($phrase in $group) {
            if ($t.Contains($phrase)) { return $false }
        }
    }

    $true
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

                # Body goes to a temp file, read back as UTF-8. Capturing stdout
                # through the console decodes it with the console codepage on
                # Windows, which mangles every non-ASCII char — '£' became '┬ú'
                # and price parsing silently found nothing.
                $tmp = [IO.Path]::GetTempFileName()
                try {
                    $args += @('-o', $tmp, $Uri)
                    $stderr = & $curl.Source @args 2>&1 | Out-String
                    if ($LASTEXITCODE -ne 0) { throw "curl failed (exit $LASTEXITCODE): $($stderr.Substring(0, [math]::Min(300, $stderr.Length)))" }
                    return [pscustomobject]@{ Content = [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8) }
                }
                finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
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
