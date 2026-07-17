# DocuMind — Financial Intelligence Setup & Test Guide

**Purpose:** Manually validate the **Finance tab, deterministic finance engine,
chat finance branch, expiry tile, and guided onboarding** end-to-end against a
clean two-property document set. All documents are synthetic.

**What "comes to life" and why upload matters:** the Finance tab computes nothing
from thin air — it folds the **structured facts extracted at ingest** (rent,
interest, tax, maintenance, dates) over the documents you upload. No documents →
empty Finance tab. Upload the set below and the numbers below appear, computed
live on every open (zero LLM, compute-on-read).

> **Before testing: RESTART THE BACKEND.** Extraction, the finance engine, and the
> new router intent are all backend-side and Python does not hot-reload. If you
> uploaded documents *before* this feature shipped, they carry no
> `extracted_facts` — **re-upload them** or they won't count.

**This guide supersedes** the older `SETUP_AND_TEST_GUIDE.md` (unit-intelligence
only, legacy `utility`/`receipt`/`warranty` categories). Unit-intelligence chat
tests are retained here (§9) since Damai is multi-unit.

---

## The two properties

| Property | Setting | Ownership | Units | Role in the demo |
|---|---|---|---|---|
| **Damai Residence** (KL) | Multi-unit residential condo | **50%** (co-owned) | 3 units | per-unit income, unit-scoped expenses, ownership scaling, renewal fee, actual-vs-derived months |
| **Ayer 8** (Putrajaya) | Single-unit commercial shoplot | **100%** (sole) | 1 unit "Shoplot" | whole-property let, income derived purely from the lease, reproduces the golden-test figures |

Two properties are deliberately enough: together they exercise both scoping modes
(per-unit vs whole-property), co-ownership vs sole ownership, invoiced (actual) vs
lease-derived income, every expense category, the loss-free statutory path, and
the completeness indicator.

**Ayer 8's numbers are the finance engine's golden test** (`test_finance_engine.py`):
Received 84,000 − Direct Expenses 59,516.87 = 24,483.13. If the Finance tab shows
those for Ayer 8, the engine is wired correctly end-to-end.

---

## 1. Files in this folder

```
demo_documents/
  1_damai_residence/                         (multi-unit residential, 50% owned)
    damai_unitA_lease.pdf                    lease → Unit A-12-03
    damai_unitA_rent_invoice_jan2025.pdf     rental_invoice → Unit A-12-03
    damai_unitA_rent_invoice_feb2025.pdf     rental_invoice → Unit A-12-03
    damai_unitA_upkeep_aircon.pdf            upkeep → Unit A-12-03
    damai_unitB_lease.pdf                    lease (renewal) → Unit B-08-11
    damai_unitC_lease.pdf                    lease → Unit C-05-07
    damai_loan_interest_2025.pdf             loan → Whole property
    damai_assessment_tax_2025.pdf            tax → Whole property
    damai_quit_rent_2025.pdf                 tax → Whole property
    damai_maintenance_2025.pdf               maintenance → Whole property
    damai_insurance.pdf                      insurance → Whole property
    _sources/*.txt                           (editable masters)
  ayer8_commercial/                          (single-unit commercial, 100% owned)
    ayer8_lease.pdf                          lease → Shoplot
    ayer8_loan_interest_2025.pdf             loan → Whole property
    ayer8_assessment_tax_2025.pdf            tax → Whole property
    ayer8_quit_rent_2025.pdf                 tax → Whole property
    ayer8_maintenance_2025.pdf               maintenance → Whole property
    _sources/*.txt
  generate_pdfs.py                           (regenerate PDFs after editing a source)
  FINANCE_SETUP_AND_TEST_GUIDE.md            (this file)
```

Regenerate PDFs after editing any `_sources/*.txt`:
```
uv run --with reportlab python demo_documents/generate_pdfs.py
```

**The 7 categories** (subtype is detected by extraction, never chosen at upload):
`lease`, `insurance`, `loan`, `tax`, `upkeep`, `maintenance`, `rental_invoice`.

---

## 2. Setup in the app

Use **fresh** properties so old uploads don't double-count. (If you already have a
"Damai Residence", either clear its documents or create a new property.)

1. **Create "Damai Residence"** (Portfolio → Add property):
   - Type: Condo. Address: any KL address.
   - **My share of this property: `50`** — this is the new ownership field; it
     makes the statutory figure differ from net P/L and shows a `50% share` badge.
   - **Number of units: `3`** (creates Unit 1/2/3 — you'll rename them next).
   - When the **guided "Add key documents" sheet** appears after creation, you may
     tap **"Do this later"** (that's onboarding scenario **O1**), then upload via
     the Docs tab; or upload the property-wide docs right there.
2. In **Damai → Portfolio → Units**, rename the three units **exactly**:
   `Unit A-12-03`, `Unit B-08-11`, `Unit C-05-07` (labels must match — the chat
   router matches unit references against them, and per-unit finance keys on them).
3. **Create "Ayer 8"**:
   - Type: Commercial. Address: any Putrajaya address.
   - **My share: `100`** (default). **Number of units: `1`** → rename it `Shoplot`.
4. Upload every PDF via the **DocuMind → Docs** tab per the matrices below. The
   upload snackbar should confirm the captured fact, e.g.
   *"Quit rent recorded — RM 480.00, 2025"* (scenario **O2**).

### Upload / assignment matrix — Damai Residence
| File | Category | Assign to |
|---|---|---|
| `damai_unitA_lease.pdf` | lease | **Unit A-12-03** |
| `damai_unitA_rent_invoice_jan2025.pdf` | rental_invoice | **Unit A-12-03** |
| `damai_unitA_rent_invoice_feb2025.pdf` | rental_invoice | **Unit A-12-03** |
| `damai_unitA_upkeep_aircon.pdf` | upkeep | **Unit A-12-03** |
| `damai_unitB_lease.pdf` | lease | **Unit B-08-11** |
| `damai_unitC_lease.pdf` | lease | **Unit C-05-07** |
| `damai_loan_interest_2025.pdf` | loan | **Whole property** |
| `damai_assessment_tax_2025.pdf` | tax | **Whole property** |
| `damai_quit_rent_2025.pdf` | tax | **Whole property** |
| `damai_maintenance_2025.pdf` | maintenance | **Whole property** |
| `damai_insurance.pdf` | insurance | **Whole property** |

### Upload / assignment matrix — Ayer 8
| File | Category | Assign to |
|---|---|---|
| `ayer8_lease.pdf` | lease | **Shoplot** |
| `ayer8_loan_interest_2025.pdf` | loan | **Whole property** |
| `ayer8_assessment_tax_2025.pdf` | tax | **Whole property** |
| `ayer8_quit_rent_2025.pdf` | tax | **Whole property** |
| `ayer8_maintenance_2025.pdf` | maintenance | **Whole property** |

> Both tax bills upload under the single `tax` category — the extractor detects
> `assessment` vs `quit_rent` from the content.

---

## 3. Ground truth — year **2025**

The Finance tab defaults to the **current** year. **Select the `2025` chip** — that
is the complete year these documents describe. (2026 is deliberately partial; see
§8/O4.)

### Damai Residence (50% owned)

**Income** (lease covers all of 2025 → derived; two Unit-A invoices override Jan/Feb → actual)
| Unit | Actual months | Derived months | Monthly rent | Received 2025 |
|---|---|---|---|---|
| Unit A-12-03 | Jan, Feb | Mar–Dec | RM 2,400 | **RM 28,800.00** |
| Unit B-08-11 | — | Jan–Dec | RM 3,200 | **RM 38,400.00** |
| Unit C-05-07 | — | Jan–Dec | RM 1,600 | **RM 19,200.00** |
| **Received rent** | | | | **RM 86,400.00** |

**Direct expenses**
| Line | Category | Scope | Amount |
|---|---|---|---|
| Loan interest | loan | Whole property | RM 30,000.00 |
| Assessment tax | tax | Whole property | RM 1,200.00 |
| Quit rent | tax | Whole property | RM 480.00 |
| Maintenance & sinking fund | maintenance | Whole property | RM 8,400.00 |
| Insurance premium | insurance | Whole property | RM 1,800.00 |
| Aircon service | upkeep | Unit A-12-03 | RM 922.20 |
| Tenancy renewal fee | lease | Unit B-08-11 | RM 500.00 |
| **Direct expenses** | | | **RM 43,302.20** |

**Damai block:** Received **86,400.00** − Direct Expenses **43,302.20** =
Rental Income/Loss **RM 43,097.80**. Statutory contribution (×50%) = **21,548.90**.

### Ayer 8 (100% owned, single commercial let)

**Income:** lease RM 7,000/mo covers all of 2025 → **12 derived months = RM 84,000.00**
(no rent invoices uploaded — income is derived from the lease; the "Shoplot" unit
row carries the full 84,000).

**Direct expenses**
| Line | Category | Amount |
|---|---|---|
| Loan interest | loan | RM 32,000.00 |
| Assessment tax | tax | RM 1,500.00 |
| Quit rent | tax | RM 316.87 |
| Maintenance & sinking fund | maintenance | RM 25,700.00 |
| **Direct expenses** | | **RM 59,516.87** |

**Ayer 8 block:** Received **84,000.00** − Direct Expenses **59,516.87** =
Rental Income/Loss **RM 24,483.13** *(the golden figure)*. Statutory contribution
(×100%) = **24,483.13**.

### Portfolio headline (2025)
| Figure | Value |
|---|---|
| **Received Rent** | **RM 170,400.00** |
| **Direct Expenses** | **RM 102,819.07** |
| **Net P/L** | **RM 67,580.93** |
| **Statutory Rental Income** | **RM 46,032.03** |

Statutory (46,032.03) is **lower** than Net P/L (67,580.93) because Damai is
50%-owned — only half of its RM 43,097.80 flows into the statutory figure
(21,548.90), while Ayer 8's 24,483.13 counts in full. This is the headline
teaching moment (chat scenario **C3**).

### Expense breakdown by category (portfolio)
| Category | Total |
|---|---|
| loan | RM 62,000.00 |
| maintenance | RM 34,100.00 |
| tax | RM 3,496.87 |
| insurance | RM 1,800.00 |
| upkeep | RM 922.20 |
| lease (renewal fee) | RM 500.00 |

### Unit A-12-03 month strip (drill-down, 2025)
Jan **actual** 2,400 · Feb **actual** 2,400 · Mar–Dec **derived** 2,400 (each).
No vacant months. Colours: actual = green, derived = ochre, vacant = grey.

### Dashboard expiry tile (next 90 days)
Landlord-wide, soonest first. Each row shows the **scope** (a unit label, or
"Property-wide") — not the property name. *("in N days" as of 16 Jul 2026 — your
run date shifts these.)*
| Row text | Ends | ~In | Urgency | (belongs to) |
|---|---|---|---|---|
| Property-wide · Policy expires | 15 Aug 2026 | 30 days | red (≤30) | Damai insurance |
| Unit B-08-11 · Lease ends | 30 Aug 2026 | 45 days | amber (≤60) | Damai |
| Shoplot · Lease ends | 30 Sep 2026 | 76 days | standard | Ayer 8 |

(Unit A's lease ended 31 Dec 2025 and Unit C's ends 28 Feb 2026 — both already
past, so neither shows.)

---

## 4. Finance tab tests

Open the **Finance** tab (4th bottom tab) and select the **2025** chip.

**F1 — Headline panel.** Received Rent **RM 170,400.00**, Direct Expenses
**RM 102,819.07**, Net P/L **RM 67,580.93**, Statutory Rental Income
**RM 46,032.03** with the sub-label **"Estimate — for your tax agent"**.

**F2 — Caveats sheet.** Tap the **info (i)** next to Statutory Rental Income. A
sheet lists the assumptions — including the billed-equals-received caveat and the
ownership-share note for Damai. The statutory figure is never shown bare.

**F3 — Per-property blocks (reference-sheet layout).**
- **Damai Residence** shows a **`50% share`** badge, Received **86,400.00**,
  Direct Expenses **43,302.20**, Rental Income/Loss **43,097.80**.
- **Ayer 8** shows no share badge, Received **84,000.00**, Direct Expenses
  **59,516.87**, Rental Income/Loss **24,483.13**.

**F4 — Unit contribution rows.** Under Damai: **Unit A-12-03** `12 mo rented`,
**Unit B-08-11** `12 mo rented`, **Unit C-05-07** `12 mo rented`. Under Ayer 8:
**Shoplot** `12 mo rented`, contribution **RM 84,000.00** (income only — the
property-level expenses sit on the block, not the unit).

**F5 — Unit drill-down + month strip.** Tap **Unit A-12-03**. The Jan–Dec strip
shows **Jan and Feb green (invoiced/actual)** and **Mar–Dec ochre (from lease
terms/derived)** — matching the two invoices you uploaded against the lease
backfill. A legend explains the colours.

**F6 — Expense line → source document.** In Unit A's drill-down, tap the **aircon
service RM 922.20** line → the CoolAir PDF opens in the viewer. (Property-level
lines like loan/tax open their source PDFs from the property block the same way.)

**F7 — Completeness indicator.** Under **Ayer 8**, a "Missing for 2025" row shows
chips for **Rent invoice**, **Upkeep receipt**, and **Insurance policy** — the
categories with no Ayer 8 document. This is expected and honest: Ayer 8's income
is derived from the lease (no invoices), and it had no landlord repairs and no
landlord insurance. **Damai shows no missing chips** (all six finance categories
are present). Tapping a chip opens a property-wide upload for that category.

**F8 — Year selector.** Switch to the **2026** chip. The picture goes partial
(§O4). Switch back to **2025** — figures return exactly.

**F9 — Refresh / compute-on-read.** Pull-to-refresh: the same numbers recompute
(no schedule, no cache staleness). Upload one more document and the affected
figures move on the next open.

---

## 5. Chat finance tests

In **DocuMind** chat (any property selected — the finance engine is landlord-wide),
the LLM **narrates the engine's figures and never does arithmetic**.

**C1 — Profit for a year.** Ask *"What was my rental profit in 2025?"*
Expect: a narrated answer quoting **Net P/L RM 67,580.93** and/or **Statutory
Rental Income RM 46,032.03** with **"Estimate — for your tax agent"** and the
billed-equals-received caveat. **No citations** (this is a computed answer, not a
document lookup).

**C2 — Year inference.** Ask *"How much did I spend on Ayer 8?"* (no year) →
answers for the current year unless you name one; ask *"...in 2025"* → uses 2025
(Ayer 8 direct expenses **RM 59,516.87**).

**C3 — Explain the gap (the demo beat).** Ask *"Why is my statutory income lower
than my net P/L?"*
Expect: it explains the **50% ownership share on Damai** — half of Damai's
income counts toward the statutory figure — narrated from the caveats, not
recomputed.

**C4 — Document question still works (contrast).** Ask *"When does Unit B's
tenancy end?"* → **30 August 2026**, **with a citation** to `damai_unitB_lease.pdf`
and a `UNIT B-08-11` badge. This is the retrieval path (glance vs ask): finance
questions compute; clause questions cite.

---

## 6. Expiry tile tests (Dashboard)

**E1 — Tile renders, soonest first.** On the **Dashboard**, the **UPCOMING
EXPIRIES** tile lists (top to bottom): **Property-wide · Policy expires 15 Aug
2026** (Damai's insurance), **Unit B-08-11 · Lease ends 30 Aug 2026**, **Shoplot ·
Lease ends 30 Sep 2026**, each with an "in N days" count and urgency colour
(red ≤30, amber ≤60, else standard). Rows show the scope (unit label or
"Property-wide"), not the property name.

**E2 — Tap-through to DocuMind.** Tap the **Unit B-08-11** entry → the app jumps
to the **DocuMind** tab **on Damai Residence** with a fresh greeting. Ask *"when
does this unit's tenancy end?"* → 30 Aug 2026, cited. (No unit filter exists — the
router scopes by your phrasing.)

**E3 — Empty state.** A property/landlord with nothing expiring in 90 days hides
the tile entirely (no "nothing expiring" noise).

---

## 7. Onboarding & completeness tests

**O1 — Guided checklist is skippable.** Creating a property pops the "Add key
documents" sheet. **"Do this later"** dismisses it; nothing blocks creation.
Uploading an item there shows the fact-confirming snackbar and ticks the row.

**O2 — Fact-confirming snackbar.** Every Docs-tab upload confirms what was
captured, e.g. *"Assessment tax recorded — RM 1,200.00, 2025"*,
*"Lease recorded — RM 3,200.00/mo, ends 2026-08-30"*,
*"Rent invoice recorded — RM 2,400.00 for 2025-01"*. If a scan yields nothing the
snackbar falls back to a generic success — that's the best-effort contract.

**O3 — Ownership share round-trips.** Edit **Damai → 50%**; the property block's
`50% share` badge and the statutory scaling both reflect it. Set it to 100 and
statutory rises to match net for Damai; set back to 50.

**O4 — Current-year partial view.** Select the **2026** chip. Because the expense
bills are all 2025-dated and Unit A's lease ended in 2025, 2026 shows: Unit A
**fully vacant** (grey strip), Unit C vacant from **March**, and completeness chips
for the un-provided 2026 categories. This demonstrates the **vacant** month colour
and the "No invoice recorded" one-tap upload affordance in a drill-down — without
any extra fixtures.

---

## 8. Unit-intelligence chat tests (retained)

Damai is multi-unit, so the phrasing-driven scoping still applies. Set property to
**Damai Residence**. There is **no unit dropdown** — scope comes from your wording.

**U1 — Explicit unit, shorthand.** *"What's Unit B's monthly rent?"* → **RM 3,200**
immediately, citation badge `UNIT B-08-11`, no question back.

**U2 — Conversational continuity.** Immediately after U1: *"And when does it end?"*
→ **30 August 2026** (Unit B's), inherited from the previous turn.

**U3 — Aggregate, per-unit attribution.** *"What's the total monthly rent across
all units?"* → per-unit breakdown **A 2,400 / B 3,200 / C 1,600** plus combined
**RM 7,200**, never a single blended number.

**U4 — Unknown unit, honest.** *"What's the rent for Unit E?"* → says Unit E does
not exist and lists the real units; no invented rent, no citation.

**U5 — Property-wide doc answers a unit-scoped question.** *"What's the insurance
deductible for Unit A?"* → **RM 1,500** from the property-wide Damai policy;
citation has **no unit badge**.

**U6 — Cross-property isolation.** Switch to **Ayer 8**: *"What's the monthly
rent?"* → **RM 7,000** (never Damai's numbers).

---

## 9. OCR (optional, needs a real scan)

The fixtures here are text PDFs, so they never trigger OCR. To exercise the
**Gemini OCR fallback**, upload a genuinely **scanned** bill (a phone photo of a
cukai/quit-rent notice exported to PDF, i.e. no text layer). Expect: the backend
log shows `🔍 OCR fallback transcribed N page(s)`, the document becomes
chat-searchable, and its facts populate the Finance tab like any other. OCR is
best-effort — a failed scan still indexes (with 0 chunks) and never blocks upload.

---

## 10. Pass checklist

| # | Pass criterion |
|---|---|
| F1 | 2025 headline: Received 170,400.00 · Expenses 102,819.07 · Net 67,580.93 · Statutory 46,032.03 (Estimate label) |
| F2 | Statutory info (i) opens caveats sheet; figure never shown bare |
| F3 | Damai block 86,400 / 43,302.20 / 43,097.80 + 50% badge; Ayer 8 84,000 / 59,516.87 / 24,483.13 |
| F4 | Unit rows: A/B/C each 12 mo; Shoplot 12 mo, RM 84,000 contribution |
| F5 | Unit A strip: Jan/Feb green (actual), Mar–Dec ochre (derived) |
| F6 | Tapping the RM 922.20 upkeep line opens the CoolAir PDF |
| F7 | Ayer 8 shows missing chips (rent invoice/upkeep/insurance); Damai shows none |
| F8 | 2026 chip → partial; back to 2025 → exact |
| C1 | "profit in 2025?" → narrated 67,580.93 / 46,032.03, Estimate label, no citations |
| C3 | "why is statutory lower than net?" → explains Damai 50% share |
| C4 | "when does Unit B's tenancy end?" → 30 Aug 2026 WITH citation + unit badge |
| E1 | Expiry tile: Property-wide policy 15 Aug, Unit B-08-11 lease 30 Aug, Shoplot lease 30 Sep, soonest first, urgency colours |
| E2 | Tapping an entry lands on DocuMind on the right property |
| O1 | Guided checklist appears after creation and is skippable |
| O2 | Upload snackbar states the captured fact |
| O3 | Ownership 50% ↔ badge + statutory scaling round-trip |
| O4 | 2026 view shows vacant months + "No invoice recorded" affordance |
| U1–U6 | Unit routing: explicit/continuity/aggregate/unknown/property-wide/cross-property |

---

## 11. Known caveats (by design, not bugs)

- **Statutory is an estimate, always caveated.** v1 stops at Statutory Rental
  Income (the hand-off to a tax agent) — no personal rates, reliefs, or chargeable
  income. It equates rent *billed* with rent *received* and says so.
- **Derived income is a projection.** Months without a rent invoice are backfilled
  from the lease's rent and period (shown ochre). Ayer 8's whole 84,000 is derived
  this way — realistic for a landlord who files the lease but not monthly invoices.
- **Ayer 8's "missing" chips are honest, not errors.** No rent invoices, no
  landlord repairs, no landlord insurance on that commercial let → those categories
  read as not-provided. Uploading them (or accepting the derived income) resolves
  it.
- **Statutory < Net is expected here.** It is the ownership-share effect (Damai
  50%), not a miscount. Vacant units' expenses still hit Net P/L (cash reality) but
  a fully-rented year prorates deductions at factor 1.0, so 2025 stays clean.
- **"in N days" drifts with the calendar.** The expiry table in §3 is computed for
  16 Jul 2026; on another date the counts and colours shift, and once a date passes
  it drops out of the 90-day window.
- **No hot reload.** Restart the backend after any backend change, and re-upload
  any documents ingested before this feature to give them `extracted_facts`.
