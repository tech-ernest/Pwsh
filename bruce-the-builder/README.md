# Bruce the Builder UK — landing page

Single-file static landing page for **Bruce the Builder UK**, a groundworks and
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
| Trading name | Bruce the Builder UK (**not** a limited company — see below) |
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

1. **The "LTD" on the business card is a legal problem.** No matching company could be
   found on Companies House, so the business appears to be a sole trader.

   Under **Companies Act 2006 s.1194** it is a criminal offence to carry on business in
   the UK under a name ending in "limited" or "ltd" when you are not a limited company.
   The business card says "BRUCE THE BUILDER UK LTD". That card needs reprinting, and the
   same applies to invoices, quotes, signage, vehicle livery and the Facebook page name.

   "Ltd" has been removed from this site entirely. **Do not put it back** unless he
   incorporates — which he can do for £50 at Companies House if he wants the name legitimately.

   Two things worth double-checking before treating this as settled:
   - Does he trade through a company registered under a *different* name (e.g. his own
     surname)? If so, that company's details are what belong in the footer.
   - Was a company registered and since dissolved? Dissolved still means he can't use "Ltd".

2. **Sole trader disclosure is now legally required in the footer.** Under
   **Companies Act 2006 ss.1202-1204**, trading under a business name that isn't his own
   personal name means his **full name** and an **address for service of documents** must
   appear on the website, letterheads and invoices. Two placeholders are in the footer for
   these. It can be a home address — there is no exemption, and no way to omit it.
   If he objects to publishing a home address, the fix is a cheap registered-office /
   mail-forwarding service, not leaving it off.

3. **A cleaner Facebook URL (optional).** The share link `facebook.com/share/1DWqdMNwaY/`
   is wired in and works, but it's an opaque redirect. If the page has a vanity URL
   (`facebook.com/BruceTheBuilderUK` or similar), grab it from the browser address bar
   and swap it in — better for the `sameAs` structured data and less likely to rot.
4. **Bourne or Spalding?** The card says Bourne, the Facebook location field says Spalding,
   and both are in his service area. Page is written Bourne-first to match the card.
   Confirm which is the trading base.
5. **Domain name** — `canonical` and `og:url` still point at `example.co.uk`.
6. **Verify "fully licensed & insured" before it stays on the page.** It's his own
   public claim, reused verbatim in the hero. Given the Ltd discrepancy, it's worth
   confirming: public liability insurer and cover amount, and what "licensed" refers to
   (UK builders aren't licensed as such — it usually means CPCS/NPORS plant tickets or a
   waste carrier licence, which he'd need for muck-away). If he can't evidence it, the
   claim comes off — an unsubstantiated one breaches the CPRs.
7. Optional but worth having: years trading, team size, CPCS/NPORS tickets, insurance
   cover amount, trade memberships (CHAS, TrustMark, FMB).

## Launch, costs and upkeep

See **[LAUNCH.md](LAUNCH.md)** — blocking items, what it costs to go live (about the
price of a domain), the step-by-step launch order, and ongoing upkeep.

## Outstanding work

| Item | Why |
|---|---|
| Wire up the contact form | It posts nowhere. Formspree / Netlify Forms / Web3Forms — see the comment above `<form>`. Point it at the gmail address. |
| Hero image | `images/hero.jpg`. Use one of his own job photos — there are 144 posts of them. Compress to under ~300KB. |
| Facebook link | ✅ Wired in — footer, reviews strip and contact list all point at the page. |
| Photo gallery | Not built yet. A before/after grid is the single highest-value addition for a groundworks firm — the work is visual and he already has the content. Needs his customers' permission for property shots. |
| Google Business Profile | He has none. For a local trade this drives more calls than a website will. Free, ~20 minutes. Do it alongside launch. |
| Privacy notice | UK GDPR — the form collects personal data, so a privacy notice must exist and be linked. |
| Footer trading disclosure | Two `.tbc` placeholders — his full name and an address for service. Legally required, see above. |
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
