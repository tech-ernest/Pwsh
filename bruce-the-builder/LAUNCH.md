# Launch plan — costs, steps and upkeep

Prices checked September 2026. All ex-VAT unless stated.

---

## 1. Blocking — needed from Bruce before anything goes live

| # | Item | Why it blocks |
|---|---|---|
| 1 | ~~Full name~~ → **street + postcode still needed** | Name done: Raitis Uzuls. "Peterborough" alone won't do — s.1204 needs an address where documents can be *effectively served*, so house/street and postcode are required. |
| 2 | **Decision on "Ltd"** | Not registered at Companies House. Card, invoices, signage and the Facebook page name all need the "Ltd" removing — or he incorporates. See §5. |
| 3 | **Insurance evidence** | The hero says "fully licensed & insured" (his own wording). Need insurer + public liability cover amount, and what "licensed" refers to. No evidence = claim comes off. |
| 4 | **Domain name choice** | Everything else depends on it. |
| 5 | **8–10 job photos, full resolution** | Not strictly blocking, but launching a groundworks site with no photos wastes the launch. |
| 6 | **Does he answer to "Bruce"?** | The proprietor is Raitis Uzuls; "Bruce" is a trading persona. The mobile call bar says "Call Bruce". One-word fix either way. |

Nice to have, not blocking: years trading, team size, CPCS/NPORS tickets, trade memberships.

---

## 2. Cost to launch

### Unavoidable

| Item | Cost | Notes |
|---|---|---|
| `.co.uk` domain | **£4–8/year** | Cloudflare Registrar sells at cost (~£4.20/yr, no renewal markup). Namecheap ~£5.20 first year then ~£7.85. Avoid registrars with a cheap first year and a £20 renewal. |
| Hosting | **£0** | Cloudflare Pages or Netlify free tier. A static single-page site will never exceed a free tier at this traffic. |
| SSL certificate | **£0** | Included and automatic on both hosts. |
| Contact form backend | **£0** | Web3Forms free tier: 250 submissions/month. (Formspree's free tier is only 50/month — Web3Forms is the better free pick.) |
| Privacy notice | **£0** | Written, not bought. |
| Google Business Profile | **£0** | |

### **Total to go live: the price of a domain. Roughly £6–10.**

### Optional

| Item | Cost | Worth it? |
|---|---|---|
| Email on the domain (`bruce@…co.uk`) | **£0–£85/yr** | Looks far more professional than a gmail on a business card. **Free route:** Cloudflare Email Routing forwards `bruce@domain` → his existing gmail, then set Gmail "send as" so replies come from the domain. **Paid route:** Google Workspace Business Starter £5.90/user/mo (£7.08 inc VAT) ≈ £85/yr. Start free. |
| Registered office / mail forwarding | **£30–50/yr** | Only if he refuses to publish a home address in the footer. Cheaper than the alternative, which is non-compliance. |
| Incorporation at Companies House | **£100 one-off** | Digital filing, rose from £50 on 1 Feb 2026. Plus £50/yr confirmation statement (was £34). See §5. |
| Logo redraw | £0–150 | The business card artwork is serviceable. Low priority. |
| Professional photography | £150–400 | Unnecessary — he has 144 posts of job photos already. |

---

## 3. Launch steps, in order

1. **Get the §1 items from Bruce.**
2. **Buy the domain.** Suggestions: `brucethebuilderuk.co.uk`, `brucethebuilder.co.uk`.
   Cloudflare Registrar if you want no renewal surprises.
3. **Fill the placeholders.** Search `index.html` for `tbc` and `example.co.uk`.
   Delete the `.tbc` CSS rule from the `<style>` block when they're all done —
   that removes the yellow highlighting.
4. **Wire the form.** Web3Forms access key into the `action`, delivering to his email.
   Send a test enquiry and confirm it arrives.
5. **Write the privacy notice.** One page: what's collected (name, email, phone, message),
   why (to reply to the enquiry), how long it's kept, and how to request deletion. Link it
   from the form note.
6. **Add the hero image** (`images/hero.jpg`, compressed under ~300KB) and the photo gallery.
7. **Deploy.** Connect the repo to Cloudflare Pages or drag the folder into Netlify.
   Point the domain at it.
8. **Test on a real phone.** The sticky call bar and the `tel:` links are the main
   conversion path — tap them and confirm they dial.
9. **Create the Google Business Profile.** Same name, phone, service area as the site.
   Consistency across the site, Facebook and Google is what feeds local ranking.
10. **Put the link on the Facebook page** and in the page's About section.

Realistic effort: **half a day**, most of it waiting on Bruce.

---

## 4. Ongoing upkeep

### Money

| Item | Recurring | |
|---|---|---|
| Domain renewal | £4–8/year | The only guaranteed cost. |
| Hosting | £0 | Free tiers are not promotional; static sites stay free. |
| Form backend | £0 | 250/month is far beyond what he'll receive. |
| Email (if on the free route) | £0 | |

**Expected annual running cost: under £10.**

For comparison, a WordPress build would be £100–200/year in hosting alone, plus plugin
licences, plus a security surface that needs patching. There is deliberately no CMS,
no database and no plugins here — nothing to update, nothing to get hacked, nothing
that breaks on its own. A static page left alone for three years still works.

### Time

| Task | How often | Effort |
|---|---|---|
| Add new job photos | Quarterly | 20–30 min |
| Refresh review count / add a quote | When it changes | 10 min |
| Check the form still delivers | Quarterly | 2 min — send a test |
| Google Business Profile post | Monthly | 5 min, and it measurably helps local ranking |
| Review the privacy notice | Annually, or if anything changes | 10 min |

### The question nobody asks until later

**Who makes the edits?** Bruce almost certainly can't edit HTML. Three options:

1. **You do it** — fine for a few changes a year, becomes a nuisance if he wants weekly updates.
2. **Leave it static and let Facebook be the "news" channel** — the site is the shopfront
   and the credibility check; Facebook carries the day-to-day. **This is the right answer
   for a one-man groundworks firm** and costs nothing.
3. **Add a CMS** (Decap, Sanity free tier) so he edits it himself — only worth the
   complexity if he genuinely wants to post regularly, which the Facebook activity
   suggests he does *there*, not here.

Agree this with him up front. "Who updates it" is what kills small business websites,
not hosting costs.

---

## 5. The "Ltd" decision

He has to pick one:

**Option A — drop it.** Free. Reprint cards, fix invoices, quotes, signage, vehicle
livery and the Facebook page name. The site already has "Ltd" removed.

**Option B — incorporate.** £100 one-off + £50/year confirmation statement, plus
accountancy costs (a sole trader's self-assessment is cheaper than company accounts
and corporation tax filings — budget £400–900/year for an accountant, versus perhaps
£150–300 for self-assessment). He then gets to use "Ltd" legitimately.

**Worth raising with him:** limited liability is not a vanity feature in groundworks.
He digs near buried services and alters drainage on other people's property. As a sole
trader, a serious claim that outruns his insurance reaches his personal assets. That —
not the look of the card — is the actual argument for incorporating.

Not your call to make, but he should hear it framed that way before deciding.
