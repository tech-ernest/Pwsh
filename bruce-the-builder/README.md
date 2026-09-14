# Bruce the Builder — landing page

Single-file static landing page for a building firm based in Bourne, Lincolnshire.
No build step, no dependencies. Open `index.html` in a browser, or drop the folder
onto Netlify / Cloudflare Pages / GitHub Pages.

```
bruce-the-builder/
├── index.html      ← the whole site (HTML + CSS + schema markup)
├── images/         ← drop hero.jpg here (the hero looks for images/hero.jpg)
└── README.md
```

## ⚠️ Nothing here is verified

There is no public record of a company trading as "Bruce the Builder" in Bourne —
no Companies House entry, no Checkatrade/MyBuilder/FMB profile, no website.
So **every phone number, email, address and claim on the page is a placeholder.**

Placeholders are highlighted yellow on the page via the `.tbc` CSS class.
Search the file for `tbc`, `example.co.uk`, `000000` and `TBC`.
Once the real details are in, delete the `.tbc` rule from the `<style>` block.

Do not go live with fake numbers or invented accreditations — for a trade business
that is a legal problem (ASA/CPRs), not just a cosmetic one.

## Questions to ask the client before go-live

**Contact & identity**
- Landline, mobile, email — which is the one they actually want ringing?
- Sole trader or limited company? If Ltd: company number, registered address, VAT number
  (legally required on a UK business website).
- Full trading address / postcode, or do they only want "Bourne, Lincolnshire" shown?
- Opening hours, and whether they take emergency call-outs.

**Credibility (this is what converts on a trade site)**
- Years trading, size of team.
- Insurance: public liability cover amount, insurer.
- Memberships/accreditations: FMB, TrustMark, CHAS, NHBC, Gas Safe, NICEIC, Part P.
- Existing reviews — Checkatrade, Google Business Profile, Facebook. Link them.
- Photos of finished jobs. Ten decent before/after shots beat any amount of copy.
  Need the client's permission for any photo of a customer's property.

**Scope**
- Which services are real? The six on the page are assumptions — cut what he doesn't do.
- Realistic travel radius. Villages listed are guesses.
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
| Schema.org JSON-LD | At the bottom of `index.html`. Real data only — wrong structured data hurts local ranking. |
| HTTPS | Free on any of the hosts above. Non-negotiable if a form collects details. |

## Built-in already

- Responsive down to ~320px; sticky tap-to-call bar on mobile.
- Tap-to-call `tel:` links throughout (the main conversion action for a builder).
- Semantic HTML, labelled form fields, visible focus outlines.
- Spam honeypot field on the form.
- LocalBusiness structured data scaffold for the Google map pack.
