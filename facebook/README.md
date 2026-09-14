# Facebook saved-page image extractor

`Get-FacebookSavedPageImage.ps1` pulls photo URLs out of a Facebook page you saved
from your own browser and downloads them.

## Why it needs a saved page

Facebook does not serve photos as plain `<img src="...">`. The URLs sit inside escaped
JSON in `<script>` blocks, pointing at `scontent*.fbcdn.net` with a signature and an
expiry baked into the query string. There is no stable link to bookmark, and fetching
the page with `Invoke-WebRequest` gets you a login wall instead of the content. Saving
the page in a logged-in browser is the only way to get the real markup.

Think of it like a car park ticket: the URL is valid, but only for a few days, and only
because it is stamped.

## Getting the input file

1. Open the page in your browser. The **Photos** tab yields the most.
2. Scroll until everything you want has loaded — Facebook only puts loaded images in the DOM.
3. `Ctrl+S` → **Webpage, HTML Only**. Or right-click → View Source → save that.

Saving the timeline as well as the Photos tab is worth it; they surface different images.
Point the script at both and it de-duplicates.

## Usage

```powershell
# Extract and download post photos
.\Get-FacebookSavedPageImage.ps1 -Path .\photos.html -OutputDirectory .\downloads

# Multiple saved pages at once
.\Get-FacebookSavedPageImage.ps1 -Path .\*.html -OutputDirectory .\downloads

# See what is there without downloading
.\Get-FacebookSavedPageImage.ps1 -Path .\photos.html -ListOnly | Format-Table FileName, SizeHint, Expires

# Everything, including avatars and UI assets
.\Get-FacebookSavedPageImage.ps1 -Path .\photos.html -Category All -MinimumBytes 0
```

If PowerShell refuses to run it:

```powershell
powershell -ExecutionPolicy Bypass -File .\Get-FacebookSavedPageImage.ps1 -Path .\photos.html
```

## What it does

| | |
|---|---|
| Categorises | The path segment after `/v/` says what the media is. `t39.30808-6` and `t39.2093-6` are post photos, `t15.*` are video thumbnails, `t39.30808-1` and `t1.*` are profile pictures. Default `-Category Content` keeps the first group and drops the several hundred commenter avatars a page load drags in. |
| De-duplicates | The same photo appears many times at different sizes. Keyed on the media filename, largest variant wins. |
| Upsizes | `-PreferOriginal` (on by default) strips Facebook's `stp`/`cstp`/`ctp` resize parameters to ask for the uncropped original, and falls back to the URL as found if the CDN rejects that. The difference is a 206px grid thumbnail versus a 2048px photo. |
| Checks expiry | The `oe` parameter is the expiry as a hex Unix timestamp. Already-dead links are reported and skipped rather than producing a wall of 403s. |
| Logs | `manifest.csv` in the output directory: filename, category, size hint, expiry, bytes, status, which saved page it came from. |

## Two warnings

**The saved HTML can contain your session tokens.** The script only reads it and only
ever extracts `fbcdn.net` media URLs — but do not commit the saved page itself to a
repo, and do not paste it anywhere public. `.gitignore` covers the usual output paths;
it does not know where you put your saved HTML.

**Only download images you have the right to use.** Photos on a page belong to whoever
took them, and automated collection breaches Facebook's terms of service. Your own page,
or a client's with their say-so, is fine. Helping yourself to a competitor's portfolio is not.
