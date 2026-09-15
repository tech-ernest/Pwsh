# Landing page — groundworks business, South Lincolnshire

Static landing page for Raitis Uzuls' groundworks and home/garden improvement
business, based in Bourne, Lincolnshire.

## ⚠️ The trading name on this site is a PLACEHOLDER

The page currently reads **"Fenland Groundworks"**. That is a stand-in, not a decision.
Bruce is rebranding (see below) and hadn't picked a name when this was built. It is
deliberately not "Bourne Groundworks", so nothing here quietly commits him to Bourne as
the trading base while that is still unconfirmed.

**To rename**, replace the placeholder everywhere:

```bash
grep -rn "Fenland Groundworks" index.html privacy.html README.md
sed -i 's/Fenland Groundworks/NEW NAME/g' index.html privacy.html
# the logo is split for two-tone styling — fix it by hand:
#   <a class="logo" ...>Fenland <em>Groundworks</em></a>
```

Also update: `<title>`, the `og:` tags, the JSON-LD `name`, and the two `[trading name]`
placeholders in the footer disclosure.

## Why there is a rebrand

Two independent reasons, both his decision:

1. **The name is crowded.** At least four other trade businesses use "Bruce the Builder"
   or close to it — a US roofer, a general contractor in Springfield MA with a BBB
   profile, and two more American builders. He cannot control what surfaces under that
   name and never will.
2. **A disputed site already occupies it.** See below.

## ⚠️ brucethebuilderuk.com is not ours and is disputed

A previous developer built a site at `brucethebuilderuk.com`. Bruce did not pay, believed
it was never published, and it was published anyway. He does not want it. It carries his
phone number, email and job photos. It has no contact form, so no enquiries are being
diverted.

**Nothing on this site may be copied from that one.** Not the headline, not the service
descriptions, not a sentence. That copy is the unpaid developer's work and using it would
hand him a genuine grievance. Everything here was written independently from Bruce's
Facebook page and business card — the git history timestamps and documents that, which is
worth preserving as evidence of provenance.

The rebrand largely resolves the dispute commercially: under a new name on a new domain,
that site stops competing with him and stops mattering.

No build step, no dependencies. Open `index.html` in a browser, or drop the folder
onto Netlify / Cloudflare Pages / GitHub Pages.

```
bruce-the-builder/
├── index.html      ← the whole site (HTML + CSS + JS + schema markup)
├── privacy.html    ← UK GDPR privacy notice, self-contained
├── images/         ← 27 site photos + source/ with all 53 originals
└── README.md
```

No build step, no dependencies, no external fonts or scripts.

## Verified details (from the Facebook page and business card)

| | |
|---|---|
| Trading name | Bruce the Builder UK (**not** a limited company — see below) |
| Proprietor | Raitis Uzuls |
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

2. **Sole trader disclosure — name done, address incomplete.**
   Footer now reads "Raitis Uzuls trading as Bruce the Builder UK" (Companies Act 2006
   ss.1202-1204).

   **"Peterborough" on its own is not enough.** The requirement is an address at which
   documents can be *effectively served* — that means house/street and postcode.
   A town name would not let anyone serve a claim, so it does not satisfy s.1204.
   Two placeholders remain either side of "Peterborough" in the footer.

   It can be his home address. If he doesn't want that public, a mail-forwarding
   service is ~£30-50/year and gives a serviceable address that isn't his house.

3. **"Bruce" is a trading persona, not his name.** The proprietor is Raitis Uzuls.
   The sticky mobile bar currently says **"Call Bruce"**, which is warm, effective copy —
   *if* he actually answers to Bruce in business. If he doesn't, a customer ringing and
   asking for Bruce is an awkward first thirty seconds. Ask him which he prefers;
   changing it to "Call us" is a one-word edit.

4. **A cleaner Facebook URL (optional).** The share link `facebook.com/share/1DWqdMNwaY/`
   is wired in and works, but it's an opaque redirect. If the page has a vanity URL
   (`facebook.com/BruceTheBuilderUK` or similar), grab it from the browser address bar
   and swap it in — better for the `sameAs` structured data and less likely to rot.
5. **Bourne, Spalding or Peterborough?** Three locations now in play: the business card
   says Bourne, the Facebook location field says Spalding, and the proprietor's address is
   Peterborough. These can legitimately differ — trading base, page setting and home
   address are three different things — but the site says "Based in Bourne", so confirm
   that's the right one to lead with. Peterborough is ~25 miles from Bourne and outside
   the nine towns he lists as his service area.

   (Original note: Bourne or Spalding?) The card says Bourne, the Facebook location field says Spalding,
   and both are in his service area. Page is written Bourne-first to match the card.
   Confirm which is the trading base.
6. **Domain name** — `canonical` and `og:url` still point at `example.co.uk`.
7. **Verify "fully licensed & insured" before it stays on the page.** It's his own
   public claim, reused verbatim in the hero. Given the Ltd discrepancy, it's worth
   confirming: public liability insurer and cover amount, and what "licensed" refers to
   (UK builders aren't licensed as such — it usually means CPCS/NPORS plant tickets or a
   waste carrier licence, which he'd need for muck-away). If he can't evidence it, the
   claim comes off — an unsubstantiated one breaches the CPRs.
8. Optional but worth having: years trading, team size, CPCS/NPORS tickets, insurance
   cover amount, trade memberships (CHAS, TrustMark, FMB).

## Launch, costs and upkeep

See **[LAUNCH.md](LAUNCH.md)** — blocking items, what it costs to go live (about the
price of a domain), the step-by-step launch order, and ongoing upkeep.

## Outstanding work

| Item | Why |
|---|---|
| Wire up the contact form | It posts nowhere. Formspree / Netlify Forms / Web3Forms — see the comment above `<form>`. Point it at the gmail address. |
| Facebook link | ✅ Wired in — footer, reviews strip and contact list all point at the page. |
| Photo gallery | ✅ Built — 23 photos, filterable by trade, with a lightbox. Still needs his customers' permission for identifiable property shots before it goes live. |
| Before/after | ✅ Built — three verified pairs. More would be better; see the note below. |
| Mobile navigation | ✅ Built — burger menu. Previously there was none at all below 880px. |
| Trading name | ❌ Placeholder. Everything else waits on this. |
| Google Business Profile | He has none. For a local trade this drives more calls than a website will. Free, ~20 minutes. Do it alongside launch. |
| Privacy notice | ✅ Written — `privacy.html`, linked from the form and the footer. Three placeholders left: the service address, the form provider's name, and the host's name. Fill them when those are decided. |
| Footer trading disclosure | Name done (Raitis Uzuls). Street + postcode still needed — "Peterborough" alone is not a serviceable address. |
| Favicon | None yet. The hard-hat character from the business card would work. |
| Cookie banner | Only needed if analytics gets added. Skipping analytics avoids it entirely. |
| HTTPS | Free on any of the hosts above. Non-negotiable with a form on the page. |

## Design: deliberately not the other site

The disputed site is black and hi-vis yellow, with condensed all-caps headings, yellow
outline icons and numbered white service cards. Ours had converged on much the same look,
because both were built from the same business card and the same Facebook page.

This version moves away from it on every axis that reads at a glance:

| | Disputed site | This site |
|---|---|---|
| Ground | Black-dominant | Warm stone `#f5f2ed`, light |
| Accent | Hi-vis yellow `#f2c014` | Clay `#a8481f` — dug earth, not safety gear |
| Headings | ALL CAPS CONDENSED | Sentence case, large, tight tracking |
| Services | Icon cards, yellow rules | Plain numbered list, hairline rules |
| Corners | Rounded cards | Near-square, 3px |
| Photos | Inline per service | Before/after pairs + filterable gallery |

The hi-vis palette came off the business card, which is being reprinted anyway over the
Ltd problem — so the brand was already in flux and nothing was lost by moving.

## Built in already

- **Before and after** — three genuine same-property pairs, the one thing no template and
  no competitor can reproduce. See the note on pairs below.
- Responsive to 320px; sticky tap-to-call bar on mobile.
- `tel:` links throughout — a phone call is the conversion action for this business.
- Social proof strip using the real Facebook review count.
- Semantic HTML, labelled form fields, visible focus outlines.
- Spam honeypot on the form.
- `GeneralContractor` structured data with the full service catalogue, all nine
  service-area towns and a `sameAs` link to Facebook, for the Google map pack.

## Photos

23 of his own job photos are on the page, pulled from the Facebook page and sorted into
five trades. See [images/README.md](images/README.md) for what is used where, what was
cropped, and the resolution ceiling.

**Two things still open:**

1. **Permission.** The photos are of customers' property. A Facebook post is one thing, a
   commercial website another. Worth Bruce's say-so, and the customer's for anything with a
   visible house number.
2. **Resolution.** They are 590px Facebook renditions. Good enough for the gallery and the
   hero mosaic, which is why the hero is a mosaic and not a full-bleed banner. Originals off
   Bruce's phone would be 3000px+ and would allow a proper banner.

The extractor that got them off Facebook lives at
[`../facebook/Get-FacebookSavedPageImage.ps1`](../facebook) if more are needed later.

### Not used: the two branding images

The logo and banner shots both read "BRUCE THE BUILDER UK **LTD**". That is the Companies
Act s.1194 problem described above, so neither goes anywhere near the site until he either
incorporates or reprints. Details in [images/README.md](images/README.md).

## Note on the before/after pairs

Three pairs are genuine — same property, verified by matching fences, rooflines and
neighbouring houses:

| Pair | Source picks | Job |
|---|---|---|
| Garden base | `116` → `103` | Bare lawn → concrete base poured square to the fence |
| Gravel driveway | `199` → `218` | Rough hardcore and old fencing → finished gravel and new panels |
| Fascias | `070` → `079` | Ladder up, weathered boards → new fascias, soffits, guttering |

They are shown **side by side rather than as a drag slider**. A slider needs the two shots
framed from the same spot, and these are not — the fence line jumps between them, which
looks broken rather than impressive.

If Bruce can shoot future jobs from a **fixed position, before and after**, a slider
becomes possible and would be the strongest thing on the page. Worth asking him to stand
in the same place twice. It costs him nothing and it is the best marketing asset he could
generate.

Never pair photos of two different jobs to fake a before/after.
