# Residex — Business Positioning & Final Product Form

**Date:** 2026-07-08
**Context:** Follow-up to [`2026-07-06-documind-unit-scoping-and-product-evaluation.md`](2026-07-06-documind-unit-scoping-and-product-evaluation.md). With the two improvement specs written ([unit intelligence](superpowers/specs/2026-07-06-documind-unit-intelligence-design.md), [fact extraction](superpowers/specs/2026-07-06-documind-fact-extraction-design.md)), this document answers: (1) does the finished app hold a competitive advantage against full-service property management companies, (2) who exactly is the target customer, (3) what is the final form of the app, and (4) how the hackathon's SDG framing carries through.

---

## 1. The competitive question: Residex vs property management companies

Full-service property management companies (PMCs) take over daily rental operations: marketing vacant units, screening tenants, handling maintenance, collecting rent, and navigating legal compliance. Typical pricing (market-typical figures, for framing): in Malaysia, roughly **one month's rent** as a one-time tenant-placement fee plus **~5–10% of monthly rent** (or a flat RM200–500/month) for ongoing management; US equivalents run 8–12%.

### The strategic answer: this is not a head-to-head fight — it's an unbundling play

A PMC sells a **bundle of two very different things**:

1. **Physical and judgment services** — showings, screening decisions, maintenance dispatch, evictions. Software cannot do these. Residex should never pretend to.
2. **Information services** — remembering renewal dates, keeping documents findable, knowing what the lease says, tracking what was paid for. This is pure information work, and software automates it completely, at software margins.

Residex unbundles the information half and delivers it for a flat fee. The landlord keeps the physical half — which self-managing landlords were already doing themselves.

| PMC service | Nature | Residex (post-specs) |
|---|---|---|
| Marketing vacant units | Physical/market | Not offered — deliberate non-goal |
| Tenant screening | Judgment | Not offered — deliberate non-goal |
| Maintenance dispatch | Physical | Not offered (activity log only, future) |
| Rent collection | Financial ops | Not offered — landlord keeps direct control of cash flow |
| Renewal/expiry deadline tracking | **Information** | **Fully automated** — fact extraction → expiry dashboard |
| Document custody & retrieval | **Information** | **Fully automated** — categorized, unit-scoped vault |
| "What does my lease say?" | **Information** | **Automated** — unit-aware Q&A with page-level citations |
| Compliance awareness | Information/legal | Partial — documents and dates at hand; not legal advice |

### Who wins where — the honest version

- **Landlord who wants zero involvement** → PMC wins, full stop. Not our customer.
- **Landlord who already self-manages** (our market) → today they get *nothing*: no back office, no reminders, no recall. Residex gives them the PMC's entire information layer without the fee. The competition here is not the PMC — it's WhatsApp threads, a drawer, and memory.
- **Landlord on the fence** ("self-managing is getting too chaotic") → Residex's real competitive effect: it **raises the chaos threshold** at which a landlord gives up and surrenders 10% of rent. The pitch: *keep the margin, keep the control, keep your tenant relationship — let software carry the paperwork.*

### The cost argument, quantified (illustrative)

For a single RM1,500/month unit: full PMC management ≈ **RM900–1,800/year** plus a ~RM1,500 placement fee per new tenancy. A Residex subscription at ~RM20–30/month ≈ **RM240–360/year** covering an *entire portfolio*, not one unit. For a 5-unit investor the spread is roughly RM4,500–9,000/year vs RM360 — the landlord keeps ~95% of what delegation would cost.

Caveat for the pitch: our ICP's real alternative is free DIY chaos, not a PMC contract. So the message is *"a property manager's back office at DIY cost"*, not *"cancel your property manager"* — the PMC comparison is the value anchor, not the displacement claim.

### And versus generic AI (the other flank)

The evaluation's argument stands and strengthens post-specs: NotebookLM/ChatGPT can answer one-off questions about an uploaded PDF, but they are not a **system of record** — no property→unit→category structure, no persistent extracted facts, no expiry surveillance, no citations bound to *your* portfolio. Residex is defensible exactly to the degree the record+intelligence loop stays ahead of "drop a PDF in a chatbot."

---

## 2. Target segments — confirming the read

Yes: the direction of the app targets exactly the two segments named, with a clear primary.

**Segment A — "Accidental" / single-property landlords.** Inherited a unit, kept the old home after moving, or bought one condo as an investment. Pain: they don't know what they don't know — missed renewals, lost deposit records, no idea what their own lease permits. Value received: document vault, reminders, plain-language Q&A. Willingness to pay: low. **Role: free-tier funnel and word-of-mouth base.**

**Segment B — Multi-property independent investors (2–10 units). PRIMARY ICP.** Self-manage by choice (protecting margin), suffer chaos that scales with unit count. Every differentiating feature built or specced — unit filters, unit-ambiguity clarification, per-unit extracted facts, portfolio-wide expiry dashboard — *only shines when there is more than one unit and more than one lease*. Willingness to pay: real, because the PMC fee anchor is real money at their scale. **The demo, the pricing, and the roadmap should all be aimed here.**

**Explicit non-targets:** professional property managers (Buildium/AppFolio's market — they need trust accounting, owner statements, staff workflows), large/commercial portfolios, and tenants (the landlord-scope reduction already settled this).

---

## 3. The final form of the app

**One-sentence thesis:** *Residex is the back office for self-managing landlords — the paperwork brain of a property manager at a fraction of the fee, while the landlord keeps the control and the margin.*

Three layers, which are also the build order and the demo arc:

### Layer 1 — Records (built)
Auth · properties · units with per-unit rent/occupancy · categorized documents with optional unit scoping · deletion cascades. The system of record. Unglamorous, and the foundation everything defensible sits on.

### Layer 2 — Intelligence (specced, in flight)
Unit-aware cited Q&A, honest "which unit / which category?" clarification instead of guessing, structured fact extraction at ingest, portfolio-wide expiry dashboard. Specs: [unit intelligence](superpowers/specs/2026-07-06-documind-unit-intelligence-design.md), [fact extraction](superpowers/specs/2026-07-06-documind-fact-extraction-design.md). This layer is what converts "storage app" into "the app that catches what you'd miss."

### Layer 3 — Action (future, deliberately thin)
Only information-work actions, in rough order of value: FCM push for expiry reminders (roadmap Phase 3) → renewal workflow checklist → manual rent-payment log (mark-paid tracking, **not** payment rails) → maintenance activity log → **year-end tax pack** (rental income + deductible receipts export for the landlord's tax filing — a strong annual retention anchor for Malaysian landlords).

### The never-build list (scope discipline as strategy)
No payment processing, no tenant marketplace or screening service, no maintenance-contractor network, no community/social features, no gamification. Each of these drags a solo-built product into operations-heavy or regulated territory where PMCs and marketplaces genuinely win. The moat is the record→intelligence→reminder loop; everything else is a distraction dressed as a roadmap.

### Monetization sketch (slideware only — do not build pre-presentation)
Free tier: 1 property, up to 2 units, capped documents (Segment A funnel). Paid tier ~RM19–29/month: unlimited properties/units, fact extraction, expiry intelligence, tax pack (Segment B). Anchor line for the slide: *"under 2% of one unit's monthly rent — versus 10% for delegation."*

### Retention honesty (know your weakness before the judges find it)
Landlord engagement is naturally event-spiky — renewals, disputes, tax season — not daily. The answer is that the **reminder engine is the retention mechanism**: it re-engages the user precisely when the product's value peaks, and monthly receipt/utility uploads plus the annual tax pack create recurring cadence between lease events. A judge who asks "what's your DAU?" gets: "wrong metric — this product is measured by deadlines caught, and it re-summons its user by design."

---

## 4. SDG alignment (the hackathon thread, carried through honestly)

**Primary — SDG 11 (Sustainable Cities and Communities), target 11.1 (adequate, safe, affordable housing):** In SEA cities, small independent landlords supply the bulk of the affordable rental stock. Lowering the cost and competence barrier of self-management keeps small supply on the market and keeps the ~10% management overhead out of rents. And a system of record cuts both ways: documented tenancies — deposits, terms, dates on file — protect **tenants** in the most common tenancy conflicts (deposit disputes), even though the app is landlord-facing. That is a defensible, two-sided SDG-11 story rather than a badge.

**Secondary — SDG 8 (Decent Work and Economic Growth):** landlording at 1–10 units is micro-entrepreneurship. Proper records formalize it: documented rental income supports tax compliance and access to financing.

Presentation guidance (unchanged from the evaluation): one slide, framing not thesis. A sharp problem-solution fit wins more points than an SDG logo wall.

---

## 5. Judge-facing narrative — pulling it together

1. **Problem** — the self-managing landlord's chaos, backed by the collected questionnaire data (primary research on a slide).
2. **Market gap** — a 2×2: *delegate vs self-manage* × *professional tools vs nothing*. Buildium/AppFolio serve delegating professionals; PMCs serve delegators; the self-managing quadrant — the majority in Malaysia/SEA — has **nothing**. Residex sits alone in it.
3. **Demo** — the three layers as an arc: create property with units (Records) → upload Unit A's lease, ask a unit-scoped question, cited answer with unit badge (Intelligence) → dashboard: *"Unit A — lease expires in 60 days"* (the closing beat).
4. **"Why not ChatGPT / why not a PMC?"** — one slide each, using §1's unbundling table and the system-of-record argument. Pre-empting both kills the two most likely judge questions.
5. **SDG slide** — §4, one slide.
6. **Roadmap + engineering evidence** — Layer 3 futures, plus the RAG evaluation harness and test suite as proof of engineering rigor.

---

## Verdict

| Question | Answer |
|---|---|
| Advantage over full-service PMCs? | Not head-to-head — Residex unbundles the PMC's *information services* (deadlines, documents, answers) at ~1–5% of the cost, for landlords who keep the physical work themselves. The "lesser payment rate than property management" benefit is correct — as the value *anchor*; the true displaced competitor is DIY chaos. |
| Are the target segments right? | Yes: accidental/single-property landlords (free-tier funnel) and multi-property independent investors (primary ICP — every differentiating feature presumes multiple units). |
| Final form of the app? | A three-layer self-management operating system — Records (built) → Intelligence (specced) → thin Action layer (future) — with an explicit never-build list guarding the scope. |
| SDG thread? | SDG 11.1 primary (affordable rental stock + documented tenancies protecting both sides), SDG 8 secondary; one slide, framing not thesis. |
