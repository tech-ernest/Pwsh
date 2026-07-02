function New-MisspellingList {
    <#
    .SYNOPSIS
        Generates typo variants of brand/model names for "badly listed" hunting.
    .DESCRIPTION
        Listings with misspelled titles sell under market because buyers can't
        find them. This produces the classic typo classes — dropped letter,
        doubled letter, swapped neighbours, adjacent-key slips — ready to feed
        into Find-EbayDeals or saved searches.
    .EXAMPLE
        New-MisspellingList 'garmin'
    .EXAMPLE
        'corsair','logitech' | New-MisspellingList -Top 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)][string]$Word,
        # Cap output per word — the most-likely variants first.
        [int]$Top = 20
    )

    begin {
        $keyboard = @{
            q = 'wa'; w = 'qes'; e = 'wrd'; r = 'etf'; t = 'ryg'; y = 'tuh'; u = 'yij'
            i = 'uok'; o = 'ipl'; p = 'ol'; a = 'qsz'; s = 'awdx'; d = 'sefc'; f = 'drgv'
            g = 'fthb'; h = 'gyjn'; j = 'hukm'; k = 'jil'; l = 'kop'; z = 'asx'; x = 'zsdc'
            c = 'xdfv'; v = 'cfgb'; b = 'vghn'; n = 'bhjm'; m = 'njk'
        }
    }

    process {
        $w = $Word.ToLowerInvariant().Trim()
        if ($w.Length -lt 3) { Write-Warning "Skipping '$w' — too short to typo usefully."; return }

        $variants = [System.Collections.Generic.List[string]]::new()

        for ($i = 0; $i -lt $w.Length; $i++) {
            # Dropped letter (most common real-world typo)
            $variants.Add($w.Remove($i, 1))
            # Doubled letter
            $variants.Add($w.Insert($i, $w[$i]))
            # Swapped with next
            if ($i -lt $w.Length - 1) {
                $chars = $w.ToCharArray()
                $chars[$i], $chars[$i + 1] = $chars[$i + 1], $chars[$i]
                $variants.Add([string]::new($chars))
            }
            # Adjacent-key substitution
            $c = [string]$w[$i]
            if ($keyboard.ContainsKey($c)) {
                foreach ($sub in $keyboard[$c].ToCharArray()) {
                    $variants.Add($w.Remove($i, 1).Insert($i, [string]$sub))
                }
            }
        }

        $variants |
            Where-Object { $_ -ne $w -and $_.Length -ge 3 } |
            Select-Object -Unique -First $Top
    }
}
