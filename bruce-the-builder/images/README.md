# Site images

Photos from the Bruce the Builder UK Facebook page, sorted for use on the site.

```
images/
├── *.jpg      ← the 23 used on the site, cropped, compressed, named by subject
└── source/    ← all 54 originals as uploaded, plus _SELECTION_OVERVIEW.jpg
```

Nothing is thrown away: `source/` keeps every original under its Facebook filename with
its `NNN_` pick number, so any of them can be brought into the site later.

## ⚠️ "Ltd" — do not use the two branding images

`source/128_*.jpg` (logo) and `source/213_*.jpg` (banner) both read **"BRUCE THE BUILDER UK LTD"**.
No matching company exists on Companies House, so the business appears to be a sole trader,
and under **Companies Act 2006 s.1194** trading under a name ending in "ltd" when you are not
a limited company is a criminal offence. Both are deliberately excluded from the site, and
"Ltd" is absent from `index.html` for the same reason. See the main README.

(An earlier version of this file described the business as "Bruce the Builder UK Ltd". That
was taken from the Facebook page and is the thing being flagged, not a confirmed fact.)

## What's used where

| Where | File |
|---|---|
| Hero mosaic | `patio-pergola-decking.jpg`, `drive-block-paving-wide.jpg`, `groundworks-excavator.jpg` |
| Gallery | all 23, filtered by the `data-cat` attribute on each `.shot` button |

Gallery categories: `driveways` (6), `gardens` (4), `groundworks` (5), `roofing` (4), `bathrooms` (4).

## Processing applied

- **Watermark crop.** Five photos carried a "SHOT ON POCO X3 NFC" stamp and carousel dots
  along the bottom. Bottom 12% cropped off: picks 67, 85, 148, 151, 187.
- **Recompressed** to JPEG quality 82, progressive. 23 files, ~1.2MB total.
- **Renamed** by subject rather than by Facebook's numeric filenames, for the sake of anyone
  who has to edit this later.

## Resolution — the one real constraint

These are Facebook feed renditions: **590px on the long edge**, a couple slightly larger.
That is fine for gallery cards and for the hero mosaic, both of which display them at or
below native size. It is **not** enough for a full-width background photo, which is why the
hero is built as a mosaic rather than a banner — stretching a 590px image across a 1400px
viewport looks exactly as bad as it sounds.

To improve on this, get the originals off Bruce's phone. Facebook recompresses and strips
EXIF on upload, so even its "full size" copy is degraded; his originals will be 3000px+.
With those in hand the hero could become a proper full-bleed banner.

## Rights

These are Bruce the Builder UK's own photos, of customers' property. Fine to use with his
say-so. Anything showing an identifiable house — a visible number, a distinctive frontage —
is worth clearing with the customer before it goes on a commercial site.
