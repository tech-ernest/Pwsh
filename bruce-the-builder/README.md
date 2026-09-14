# Bruce the Builder — landing page

Single-file static landing page for a construction firm based in Spalding, Lincolnshire,
covering Bourne and the surrounding area.
No build step, no dependencies. Open `index.html` in a browser, or drop the folder
onto Netlify / Cloudflare Pages / GitHub Pages.

```
bruce-the-builder/
├── index.html      ← the whole site (HTML + CSS + schema markup)
├── images/         ← drop hero.jpg here (the hero looks for images/hero.jpg)
└── README.md
```

## ⚠️ Almost nothing here is verified

The business does exist: a Facebook page trading as **Bruce the Build UK**, a construction
company listed in **Spalding**, with ~2,900 followers. That's the only confirmed source.
There is no Companies House entry, no Checkatrade/MyBuilder/FMB profile and no website
that could be found.

**Location conflict — resolve this first.** The brief said Bourne; Facebook says Spalding.
They are ~10 miles apart. The page is currently written Spalding-first with Bourne as a
covered area, and phone placeholders use the Spalding 01775 dialling code (Bourne is 01778).
Flip it back if the brief was right.

Everything else — phone, email, address, years trading, insurance, the follower count —
is a placeholder, highlighted yellow on the page via the `.tbc` CSS class.
Search the file for `tbc`, `example.co.uk`, `000000`, `PE11 XXX` and `TBC`.
Once the real details are in, delete the `.tbc` rule from the `<style>` block.

Do not go live with fake numbers or invented accreditations — for a trade business
that is a legal problem (ASA/CPRs), not just a cosmetic one.

## First job: mine the Facebook page

A page with 2.9k followers is a content goldmine and it is the single best source
available. Pull from it before asking Bruce anything:

- **Photos of completed jobs** — already public, already his, no new shoot needed.
- **Reviews / recommendations** — real social proof for the page.
- **Contact details** — the About tab usually has the phone, email and service area.
- **Services actually offered** — the search trail suggests "extension and new build
  specialist", which is how the page is now written. Confirm it.
- **Posting activity** — tells you whether he'll keep a website updated or whether
  Facebook should stay his main channel with the site as a shopfront.

Link the Facebook page from the site footer (placeholder is in there) — for a trade
business with that following, it's a stronger trust signal than anything written copy does.

## Questions to ask the client before go-live

**Contact & identity**
- Landline, mobile, email — which is the one they actually want ringing?
- Sole trader or limited company? If Ltd: company number, registered address, VAT number
  (legally required on a UK business website).
- Full trading address / postcode, or does he only want the town shown?
- Bourne or Spalding — which is the base, and which is the service area?
- Is "Bruce the Build UK" the trading name, or is the website going out as "Bruce the Builder"?
- Opening hours, and whether they take emergency call-outs.

**Credibility (this is what converts on a trade site)**
- Years trading, size of team.
- Insurance: public liability cover amount, insurer.
- Memberships/accreditations: FMB, TrustMark, CHAS, NHBC, Gas Safe, NICEIC, Part P.
- Existing reviews — the Facebook page recommendations, plus Google Business Profile
  and Checkatrade if he has them. Link them.
- Photos of finished jobs. Ten decent before/after shots beat any amount of copy.
  Need the client's permission for any photo of a customer's property.

**Scope**
- Which services are real? The six on the page lead with extensions and new builds
  based on the Facebook trail — confirm, and cut what he doesn't do.
- Realistic travel radius. Towns listed are guesses around a Spalding base.
- Domain name — registered already or does it need buying?
- Who receives form enquiries, and does anyone check that inbox daily?

## Things that still need doing

| Item | Why |
|---|---|
| Wire up the contact form | It posts nowhere. Use Formspree, Netlify Forms or Web3Forms — see the comment above the `<form>` tag. |
| Google Business Profile | For a local trade this drives more calls than the website. Free. Do it first. |
| Privacy notice | UK GDPR — the form collects personal data, so a privacy notice must be linked. |
| Cookie banner | Only if analytics is added. No analytics = no banner needed. Keep it that way if possible. |
| Hero image | `images/hero.jpg` — a real photo of his work, not a stock photo. Compress it, keep under ~300KB. |
| Favicon | Currently none. |
| Fix the `og:` and canonical URLs | Both point at `example.co.uk`. |
| Link the real Facebook page | Footer placeholder. 2.9k followers is the best trust signal available. |
| Schema.org JSON-LD | At the bottom of `index.html`. Real data only — wrong structured data hurts local ranking. |
| HTTPS | Free on any of the hosts above. Non-negotiable if a form collects details. |

## Built-in already

- Responsive down to ~320px; sticky tap-to-call bar on mobile.
- Tap-to-call `tel:` links throughout (the main conversion action for a builder).
- Semantic HTML, labelled form fields, visible focus outlines.
- Spam honeypot field on the form.
- LocalBusiness structured data scaffold for the Google map pack.
