# Bruce the Builder UK — landing page

Single-file static landing page for **Bruce the Builder UK Ltd**, a groundworks and
home/garden improvement company based in Bourne, Lincolnshire.

No build step, no dependencies. Open `index.html` in a browser, or drop the folder
onto Netlify / Cloudflare Pages / GitHub Pages.

```
bruce-the-builder/
├── index.html      ← the whole site (HTML + CSS + schema markup)
├── images/         ← drop hero.jpg here (the hero looks for images/hero.jpg)
└── README.md
```

## Verified details (from the Facebook page and business card)

| | |
|---|---|
| Trading name | Bruce the Builder UK Ltd |
| Strapline | Home and Garden Improvements |
| Base | Bourne, Lincolnshire |
| Phone | 07770 064663 |
| Email | brucethebuilderuk@gmail.com |
| Hours | Always open |
| Price band | ££ |
| Reviews | 100% recommend, 11 reviews (Facebook) |
| Facebook | https://www.facebook.com/share/1DWqdMNwaY/ |
| Following | 2.9K followers, 144 posts |
| Areas served | Holbeach · Sleaford · Thurlby · Bourne · Market Deeping · Baston · Spalding · Stamford · Grantham |

**Services** (from the pinned Facebook post — groundworks is the specialism):
excavation & site preparation · foundations & concrete work · drainage & surface water
management · driveways & paths · landscaping & garden solutions · demolition & earthmoving.
Residential and commercial.

Claims he already makes publicly and which are reused on the page verbatim:
reliable & experienced team, fully licensed & insured, affordable & transparent pricing,
attention to detail, free no-obligation quotes.

## Still to confirm with Bruce

Placeholders are highlighted yellow on the page via the `.tbc` CSS class —
search `index.html` for `tbc`. Delete the `.tbc` rule from the `<style>` block
once they're all resolved.

1. **Company number, registered office and VAT number.** The card says "LTD" but no
   matching Companies House record could be found from here (the register itself was
   unreachable — this is not proof either way). If it *is* registered, the number,
   registered office address and VAT number are legally required on the website under
   the Companies Act 2006. If it *isn't*, the "Ltd" needs to come off the card and the
   site — trading as a limited company when you aren't is an offence. **Check this first.**
2. **A cleaner Facebook URL (optional).** The share link `facebook.com/share/1DWqdMNwaY/`
   is wired in and works, but it's an opaque redirect. If the page has a vanity URL
   (`facebook.com/BruceTheBuilderUK` or similar), grab it from the browser address bar
   and swap it in — better for the `sameAs` structured data and less likely to rot.
3. **Bourne or Spalding?** The card says Bourne, the Facebook location field says Spalding,
   and both are in his service area. Page is written Bourne-first to match the card.
   Confirm which is the trading base.
4. **Domain name** — `canonical` and `og:url` still point at `example.co.uk`.
5. Optional but worth having: years trading, team size, CPCS/NPORS tickets, insurance
   cover amount, trade memberships (CHAS, TrustMark, FMB).

## Outstanding work

| Item | Why |
|---|---|
| Wire up the contact form | It posts nowhere. Formspree / Netlify Forms / Web3Forms — see the comment above `<form>`. Point it at the gmail address. |
| Hero image | `images/hero.jpg`. Use one of his own job photos — there are 144 posts of them. Compress to under ~300KB. |
| Facebook link | ✅ Wired in — footer, reviews strip and contact list all point at the page. |
| Photo gallery | Not built yet. A before/after grid is the single highest-value addition for a groundworks firm — the work is visual and he already has the content. Needs his customers' permission for property shots. |
| Google Business Profile | He has none. For a local trade this drives more calls than a website will. Free, ~20 minutes. Do it alongside launch. |
| Privacy notice | UK GDPR — the form collects personal data, so a privacy notice must exist and be linked. |
| Favicon | None yet. The hard-hat character from the business card would work. |
| Cookie banner | Only needed if analytics gets added. Skipping analytics avoids it entirely. |
| HTTPS | Free on any of the hosts above. Non-negotiable with a form on the page. |

## Built in already

- Brand colours pulled from the business card: hi-vis yellow `#f2c014` on near-black `#14181d`.
- Responsive to 320px; sticky tap-to-call bar on mobile.
- `tel:` links throughout — a phone call is the conversion action for this business.
- Social proof strip using the real Facebook review count.
- Semantic HTML, labelled form fields, visible focus outlines.
- Spam honeypot on the form.
- `GeneralContractor` structured data with the full service catalogue, all nine
  service-area towns and a `sameAs` link to Facebook, for the Google map pack.
