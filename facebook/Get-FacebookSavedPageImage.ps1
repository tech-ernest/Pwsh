<#
.SYNOPSIS
    Extracts image URLs from a saved Facebook page and downloads them locally.

.DESCRIPTION
    Facebook does not put its photos in plain <img src="..."> tags. They sit inside
    escaped JSON blobs in <script> elements, pointing at signed, short-lived URLs on
    scontent*.fbcdn.net. This script pulls those URLs back out of a page you saved
    from your own browser, sorts them into content photos vs. profile pictures and
    avatars, picks the largest variant of each image, and downloads them.

    How to get the input file:
        1. Open the Facebook page in your browser (the Photos tab gives the most).
        2. Scroll until everything you want has loaded.
        3. Ctrl+S -> "Webpage, HTML Only", or right-click -> View Source -> save that.

    Two things worth knowing before you run it:

    * The URLs expire. Each one carries an "oe" parameter holding its expiry as a hex
      Unix timestamp; the script decodes it and refuses to download anything already
      dead. A saved page is typically good for a few days. If downloads start failing
      with 403, re-save the page and run again.

    * The saved HTML can contain your own session tokens. This script only ever reads
      it and only ever extracts fbcdn.net media URLs - it writes nothing else out -
      but do not commit the saved HTML itself to a repo.

.PARAMETER Path
    One or more saved .html files. Accepts wildcards and pipeline input.

.PARAMETER OutputDirectory
    Where the images land. Created if missing. Defaults to .\fb-images.

.PARAMETER Category
    Which images to take:
      Content  - post photos, cover photos, video thumbnails (the default, and the
                 only ones normally worth having)
      Profile  - profile pictures and commenter avatars, mostly other people's
      All      - everything, including UI assets

.PARAMETER PreferOriginal
    Try the uncropped original first by stripping Facebook's stp/cstp/ctp resize
    parameters, falling back to the URL as found if that is rejected. On by default;
    use -PreferOriginal:$false to download exactly the variant the page referenced.

.PARAMETER ListOnly
    Extract and report, download nothing. Combine with -ManifestPath to get a CSV of
    the links on their own.

.PARAMETER ManifestPath
    CSV written with one row per image. Defaults to manifest.csv inside the output
    directory. The URLs it records are signed and expire, so treat it as a log, not
    as a reusable link list.

.PARAMETER MinimumBytes
    Discard anything smaller than this after download, which clears out tracking
    pixels and spacer images. Default 10240 (10 KB). Set to 0 to keep everything.

.EXAMPLE
    .\Get-FacebookSavedPageImage.ps1 -Path .\photos.html -OutputDirectory .\bruce-photos

.EXAMPLE
    Get-ChildItem .\saved\*.html | .\Get-FacebookSavedPageImage.ps1 -ListOnly

.EXAMPLE
    .\Get-FacebookSavedPageImage.ps1 -Path .\photos.html -Category All -MinimumBytes 0

.NOTES
    Windows PowerShell 5.1 and PowerShell 7+.

    Only download images you have the right to use. Photos on someone else's page
    belong to whoever took them, and automated collection is against Facebook's terms
    of service. Fine for your own page or with the owner's say-so; not fine as a way
    to help yourself to a competitor's portfolio.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('FullName')]
    [string[]]$Path,

    [Parameter(Position = 1)]
    [string]$OutputDirectory = (Join-Path (Get-Location).Path 'fb-images'),

    [ValidateSet('Content', 'Profile', 'All')]
    [string]$Category = 'Content',

    [switch]$PreferOriginal = $true,

    [switch]$ListOnly,

    [string]$ManifestPath,

    [int]$MinimumBytes = 10240
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Windows PowerShell 5.1 still defaults to SSL3/TLS1.0 here, which fbcdn refuses.
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Verbose "Could not raise the TLS version: $($_.Exception.Message)"
    }

    $userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
                 '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

    # The bit after /v/ in an fbcdn path says what kind of media it is.
    function Get-MediaCategory {
        param([string]$Tag)

        switch -Regex ($Tag) {
            '^t39\.30808-6'  { return 'Content' }   # photos attached to posts
            '^t39\.2093-6'   { return 'Content' }   # older post photos
            '^t15\.'         { return 'Content' }   # video thumbnails
            '^t51\.'         { return 'Content' }   # cross-posted media
            '^t39\.30808-1'  { return 'Profile' }   # profile pictures
            '^t1\.'          { return 'Profile' }   # legacy profile pictures
            '^t45\.'         { return 'Profile' }   # app and page icons
            default          { return 'Other'  }
        }
    }

    # Facebook encodes the requested size in stp/cstp/ctp: c0.169.1536.1536a,
    # p720x720, s206x206, mx1536x1536. Biggest number wins as a size estimate.
    function Get-SizeHint {
        param([string]$Url)

        $best = 0
        foreach ($name in 'stp', 'cstp', 'ctp') {
            $m = [regex]::Match($Url, "[?&]$name=([^&]+)")
            if (-not $m.Success) { continue }
            foreach ($n in [regex]::Matches($m.Groups[1].Value, '\d{2,5}')) {
                $v = [int]$n.Value
                if ($v -gt $best) { $best = $v }
            }
        }
        return $best
    }

    # oe=<hex> is the expiry as a Unix timestamp.
    function Get-UrlExpiry {
        param([string]$Url)

        $m = [regex]::Match($Url, '[?&]oe=([0-9A-Fa-f]{6,10})')
        if (-not $m.Success) { return $null }
        try {
            $seconds = [Convert]::ToInt64($m.Groups[1].Value, 16)
            return [DateTimeOffset]::FromUnixTimeSeconds($seconds).UtcDateTime
        } catch {
            return $null
        }
    }

    # Strips the resize parameters so the CDN hands back the uncropped original.
    function Get-OriginalUrl {
        param([string]$Url)

        $stripped = $Url
        foreach ($name in 'stp', 'cstp', 'ctp') {
            $stripped = [regex]::Replace($stripped, "([?&])$name=[^&]*", '$1')
        }
        $stripped = $stripped -replace '\?&', '?' -replace '&&+', '&' -replace '[?&]$', ''
        return $stripped
    }

    $found = @{}          # media filename -> best row for it
    $filesRead = 0
}

process {
    foreach ($pattern in $Path) {

        $items = @(Resolve-Path -Path $pattern -ErrorAction SilentlyContinue)
        if ($items.Count -eq 0) {
            Write-Warning "No file matched '$pattern'."
            continue
        }

        foreach ($item in $items) {
            $file = $item.Path
            Write-Verbose "Reading $file"
            $filesRead++

            $raw = Get-Content -LiteralPath $file -Raw -Encoding UTF8

            # Undo the three ways Facebook escapes a URL inside embedded JSON.
            $text = $raw -replace '\\/', '/'
            $text = $text -replace '\\u0026', '&'
            $text = $text -replace '\\u0025', '%'
            $text = [System.Net.WebUtility]::HtmlDecode($text)

            $hits = [regex]::Matches($text, 'https://[a-z0-9\-\.]*fbcdn\.net/[^\s"''<>\\)]+')
            Write-Verbose "  $($hits.Count) fbcdn references"

            foreach ($m in $hits) {
                $url = $m.Value.TrimEnd([char[]]@('\', ',', ';', ')'))

                $parts = [regex]::Match($url, '/v/([^/]+)/([^/?]+)')
                if (-not $parts.Success) { continue }

                $tag  = $parts.Groups[1].Value
                $name = $parts.Groups[2].Value
                if ($name -notmatch '\.(jpg|jpeg|png|webp|gif)$') { continue }

                $cat = Get-MediaCategory -Tag $tag
                if ($Category -ne 'All' -and $cat -ne $Category) { continue }

                $size = Get-SizeHint -Url $url

                # Same image can appear a dozen times at different sizes. Keep the biggest.
                # Keyed on category as well as name: a profile picture that has also been
                # posted appears under both tags, and keying on the name alone would let
                # the avatar variant evict the full-size post copy.
                $key = "$cat/$name"
                if ($found.ContainsKey($key)) {
                    $existing = $found[$key]
                    if ($size -lt $existing.SizeHint) { continue }
                    if ($size -eq $existing.SizeHint -and $url.Length -le $existing.Url.Length) { continue }
                }

                $found[$key] = [PSCustomObject]@{
                    FileName   = $name
                    Category   = $cat
                    Tag        = $tag
                    SizeHint   = $size
                    Expires    = Get-UrlExpiry -Url $url
                    Url        = $url
                    SourceFile = Split-Path -Leaf $file
                    Bytes      = 0
                    Status     = 'Pending'
                }
            }
        }
    }
}

end {
    $rows = @($found.Values | Sort-Object Category, FileName)

    if ($rows.Count -eq 0) {
        Write-Warning "No $Category images found in $filesRead file(s). Try -Category All, or re-save the page with the Photos tab fully scrolled."
        return
    }

    Write-Host "Found $($rows.Count) unique $Category image(s) across $filesRead file(s)." -ForegroundColor Cyan

    $now     = (Get-Date).ToUniversalTime()
    $expired = @($rows | Where-Object { $_.Expires -ne $null -and $_.Expires -lt $now })
    if ($expired.Count -gt 0) {
        Write-Warning "$($expired.Count) link(s) have already expired and will be skipped. Re-save the page to refresh them."
    }

    $soonest = $rows | Where-Object { $_.Expires -ne $null } | Sort-Object Expires | Select-Object -First 1
    if ($soonest) {
        Write-Host ("Earliest link expiry: {0:yyyy-MM-dd HH:mm} UTC" -f $soonest.Expires) -ForegroundColor DarkGray
    }

    if (-not $ListOnly) {
        if (-not (Test-Path -LiteralPath $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }
        $OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    }

    if (-not $ManifestPath) {
        $base = if ($ListOnly) { (Get-Location).Path } else { $OutputDirectory }
        $ManifestPath = Join-Path $base 'manifest.csv'
    }

    if (-not $ListOnly) {

        $index = 0
        foreach ($row in $rows) {
            $index++
            $target = Join-Path $OutputDirectory $row.FileName

            if ($row.Expires -ne $null -and $row.Expires -lt $now) {
                $row.Status = 'Expired'
                Write-Host ("[{0}/{1}] {2} - link expired" -f $index, $rows.Count, $row.FileName) -ForegroundColor Yellow
                continue
            }

            if (Test-Path -LiteralPath $target) {
                $row.Bytes  = (Get-Item -LiteralPath $target).Length
                $row.Status = 'Skipped (exists)'
                Write-Host ("[{0}/{1}] {2} - already here" -f $index, $rows.Count, $row.FileName) -ForegroundColor DarkGray
                continue
            }

            $attempts = @()
            if ($PreferOriginal) {
                $original = Get-OriginalUrl -Url $row.Url
                if ($original -ne $row.Url) { $attempts += $original }
            }
            $attempts += $row.Url

            $ok = $false
            foreach ($attempt in $attempts) {
                try {
                    $client = New-Object System.Net.WebClient
                    try {
                        # WebClient rather than Invoke-WebRequest: Referer is a restricted
                        # header that IWR will not always let you set on 5.1, and this is
                        # markedly faster for binaries.
                        $client.Headers['User-Agent'] = $userAgent
                        $client.Headers['Referer']    = 'https://www.facebook.com/'
                        $client.DownloadFile($attempt, $target)
                    } finally {
                        $client.Dispose()
                    }
                    $ok = $true
                    if ($attempt -ne $row.Url) { $row.Url = $attempt }
                    break
                } catch {
                    Write-Verbose "  $($_.Exception.Message)"
                    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
                }
            }

            if (-not $ok) {
                $row.Status = 'Failed'
                Write-Host ("[{0}/{1}] {2} - failed" -f $index, $rows.Count, $row.FileName) -ForegroundColor Red
                continue
            }

            $row.Bytes = (Get-Item -LiteralPath $target).Length

            if ($MinimumBytes -gt 0 -and $row.Bytes -lt $MinimumBytes) {
                Remove-Item -LiteralPath $target -Force
                $row.Status = 'Too small'
                Write-Host ("[{0}/{1}] {2} - {3} bytes, discarded" -f $index, $rows.Count, $row.FileName, $row.Bytes) -ForegroundColor DarkGray
                continue
            }

            $row.Status = 'Downloaded'
            Write-Host ("[{0}/{1}] {2} - {3:N0} KB" -f $index, $rows.Count, $row.FileName, ($row.Bytes / 1KB)) -ForegroundColor Green
        }
    }

    try {
        $rows | Select-Object FileName, Category, Tag, SizeHint, Expires, Bytes, Status, SourceFile, Url |
            Export-Csv -LiteralPath $ManifestPath -NoTypeInformation -Encoding UTF8
        Write-Host "Manifest: $ManifestPath" -ForegroundColor Cyan
    } catch {
        Write-Warning "Could not write the manifest: $($_.Exception.Message)"
    }

    if (-not $ListOnly) {
        $done = @($rows | Where-Object { $_.Status -eq 'Downloaded' })
        $totalMb = 0
        if ($done.Count -gt 0) {
            $totalMb = ($done | Measure-Object -Property Bytes -Sum).Sum / 1MB
        }
        Write-Host ("Downloaded {0} file(s), {1:N1} MB, into {2}" -f $done.Count, $totalMb, $OutputDirectory) -ForegroundColor Cyan
    }

    $rows
}
