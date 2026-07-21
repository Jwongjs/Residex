# Document-First Expense Model — Design

**Date:** 2026-07-21
**Branch:** `docs/expense-model`
**Supersedes:** the derive-once maintenance design in `backend/EXPENSE_MODEL.md` (rows #2 and #3)
**Status:** design approved, implementation not started

---

## 1. The change in one sentence

The old rule was *"derive a cost if it is flat, self-known and frequent."* The new rule is:

> **Every ringgit on the dashboard traces back to a document the landlord uploaded.**

No typed amounts anywhere. The driver is the landlord's own reasoning: documents must be
stored regardless of payment frequency so they are retrievable later for income-tax
auditing. If the document must exist anyway, deriving a figure without one buys nothing
and costs consistency.

### What this deletes

Three tasks from `docs/superpowers/plans/2026-07-21-expense-model-backend.md` are void:

| Old task | Why it dies |
|---|---|
| 1 — `_maintenance_lines` derive + actual suppression | Nothing derives, so nothing can double-count |
| 2 — service fetches `documind_recurring_charges` | Collection is never created |
| 3 — `PUT`/`DELETE` recurring-charge API | No manual rate to store |

The double-count hazard that carried the heaviest test burden in that plan **ceases to
exist**. Tasks 4–8 survive and are folded into Stage A and Stage B below.

---

## 2. Expected rhythm per expense

For each property and each tracked year, the app knows what should be present. Coverage is
satisfied by **at least one extracted fact** per slot — not by a document count.

| Expense | Rhythm | Applies to |
|---|---|---|
| Rent | Covered by the tenancy agreement for its span; `missing` for any tracked year with no lease covering it | Any tenancy |
| Maintenance + sinking fund | Monthly (12 slots) | Strata only |
| Assessment tax | Semi-annual (2) — or the `x/N` the bill itself prints | All |
| Quit rent **or** parcel rent | Annual (1) — either satisfies the land-office slot | All |
| Fire insurance | Annual (1) | Landed only (strata's sits inside the MC bill) |
| Loan interest | Annual (1) | Only if mortgaged |
| Upkeep / repairs | Ad hoc | All — **never** flagged missing |

Two mechanisms keep this bearable:

1. **One document fills many slots.** A management statement of account can satisfy twelve
   months of maintenance plus the annual quit rent and insurance lines in a single upload.
2. **The property profile hides what does not apply.** A landed owner is never asked for
   maintenance or parcel rent; a cash buyer is never asked for a loan statement.

### Coverage states

Each (year, category) cell is one of:

- `present` — at least one extracted fact covers it
- `missing` — expected, nothing found
- `partial` — some slots filled (e.g. 4 of 12 months, or 1 of 2 installments)
- `unavailable` — landlord has acknowledged the document cannot be obtained
- **not applicable** — hidden entirely, never rendered as a row

States are conveyed by icon plus label, never colour alone.

### `present` means billed, not paid

Coverage answers *"do I have the document?"* It does not answer *"did the money move?"*
Two tempting inferences are both wrong:

- **Uploaded does not mean paid.** The Ayer@8 February statement shows **RM1,626.81
  outstanding** — it is a demand for payment, and uploading it proves only that the charge
  was raised.
- **Missing does not mean unpaid.** It almost always means not yet uploaded. The app never
  infers non-payment from an absent document; `missing` means unknown.

**Expenses therefore carry no paid/unpaid state.** Two reasons this is safe:

1. **Tax does not need it.** Malaysian deductions are for expenses *incurred*, not expenses
   paid, so an unpaid 2025 maintenance charge still deducts in 2025. The tax figure is
   unaffected by settlement.
2. **The signal already exists.** Late payment charges are an extracted subtype. When
   arrears accumulate, penalty lines appear on the statement by themselves — a real signal
   with no manual upkeep and no new mechanism.

**Rent is the deliberate exception.** It keeps its unpaid-month mechanism, because the
asymmetry is genuine: nobody issues a document when a tenant *fails* to pay, the landlord
is the party owed, and the shortfall is real money that no other source would reveal.

---

## 3. Expanded expense catalogue and deductibility

### New subtypes

Added to `EXPENSE_SUBTYPE_CATEGORY` in `backend/rag/fact_extractor.py`, each with Malay and
English synonyms in `_EXPENSE_SYNONYMS`:

`agent_commission`, `management_fee`, `legal_fee`, `stamp_duty`, `advertising`,
`pest_control`, `rent_collection`, `security_fee`, `sst`.

Two further subtypes exist solely to be captured and excluded, so the landlord sees the
full bill without the figure inflating a deduction: `renovation` (capital improvement) and
`loan_principal` (the non-interest portion of a mortgage payment).

### Three deductibility rules

Every extracted line carries `deductible: bool`. Only deductible lines feed
`direct_expenses`, the breakdown, and the statutory estimate. Non-deductible lines are
still captured, still displayed on the document, and shown greyed out.

| Rule | Subtypes | Basis |
|---|---|---|
| **Never deductible** | `late_penalty`, loan principal, renovations and improvements | Penalties and capital expenditure |
| **Deductible on renewal only** | `agent_commission`, `legal_fee`, `stamp_duty`, `advertising` | LHDN PR 12/2018 — first-letting costs are capital/preliminary |
| **Deductible only if the landlord bears it** | `utilities` | The `utilities_paid_by` profile field |

The renewal rule is decidable without asking the landlord: the lease extractor already
reads `subtype: new | renewal` (`fact_extractor.py:73`).

### A charge on your bill is not a charge you bear

Verified against the Ayer@8 documents. The February statement for unit B2-1-02 bills the
**landlord's account** for water meter (RM114.66) and sewerage (RM17.55). The tenancy
agreement makes both the tenant's liability:

> **Clause 5.2 — "Payment of Utilities":** *To pay all charges due and incurred in respect
> of electricity, water and all other utilities supplied to the Said Premises.*

Page 3 explains the mechanism: the landlord holds a **Utility Deposit** and the tenant
covers any shortfall on notification. The charge appears on the landlord's statement; the
tenant bears the cost.

The complementary landlord covenant:

> **Clause 6.1 — "To pay quit rent, assessment and service charges":** *To pay the Quit
> Rents, assessments, service charges and other outgoings relating the Said Premises other
> than those herein agreed to be paid by the Tenant.*
>
> **Clause 6.2:** landlord keeps the premises insured against fire and tempest.
>
> **Clauses 5.19 / 5.14:** tenant bears repairs for damage they caused; landlord bears fair
> wear and tear.

Therefore `utilities_paid_by` defaults to `tenant`, and extraction **classifies only** —
it never decides deductibility.

### Live defect this fixes

`_EXPENSE_SYNONYMS` currently routes *"Indah Water, utility bills paid by the owner"* into
`upkeep`, which is deductible. On the real Ayer@8 February statement that overstates
deductions by **RM137.92 of RM1,626.81 (~8.5%)**.

Expected post-fix `direct_expenses` for that statement: **RM840.40** by default
(maintenance path); **RM972.61** with `utilities_paid_by = landlord`. The late-payment
charge of RM5.71 is excluded either way.

---

## 4. Multi-period, multi-category extraction

One uploaded document may satisfy several periods and several categories at once.

- Each dated row on a statement of account becomes its own line item with its own period.
- Applies to all categories, not only strata statements.
- The existing expense-lines review sheet (`PATCH …/facts` → `update_expense_lines`) is the
  correction surface — the landlord checks the parsed rows before they are saved.
- A line whose period cannot be resolved to a specific month falls back to the year and
  satisfies no monthly slot; it is surfaced in the review sheet for the landlord to fix.

This is what makes backfilling realistic: one statement per year rather than twelve
invoices.

---

## 5. Property profile and history depth

Set at registration, all things the landlord already knows:

| Field | Values | Effect |
|---|---|---|
| `property_type` | `landed` \| `strata` | Which expenses are ever asked for |
| `has_mortgage` | bool | Cash buyers are never asked for a loan statement |
| `utilities_paid_by` | `tenant` (default) \| `landlord` | Whether utility lines deduct |
| `track_from_year` | integer, defaults to current tax year | Earliest year that counts as expected |

`track_from_year` is the answer to the backfill problem. Years before it can still be
uploaded and stored — they are simply never flagged missing. The landlord can move it
backwards later when they find old paperwork.

Missing profile → the engine falls back to today's generic behaviour, so existing
properties keep working.

---

## 6. Registration: guided, not compulsory

The property is created regardless of paperwork. Nothing blocks on documents.

### Step 1 — Three facts (required, no documents needed)

Property type, mortgage yes/no, track-from year. Each has a **"not sure"** escape that
falls back to generic behaviour. This step is required because it takes three taps, needs
nothing on hand, and is what makes every later list short and correct.

### Step 2 — The two unlock documents (skippable)

- **The tenancy agreement** — rent, span, and the utilities/repairs liability clauses. One
  upload resolves the entire income side plus the liability rules.
- **The latest management statement of account** (strata) — cumulative, so it can backfill
  many months of maintenance and sinking fund at once, and usually carries the quit rent
  and insurance lines too.

### Step 3 — Annual one-offs per tracked year (skippable)

Assessment tax installments, land-office tax, insurance if landed, loan interest if
mortgaged.

### Skipping

Every step past Step 1 offers **"I'll do this later"** with no penalty and no warning tone.
Unfinished work resurfaces in exactly four quiet places — no red badges, no push
notifications:

| Surface | What it shows |
|---|---|
| **Records grid** (Documents tab) | Year × expense grid, upload button in every empty cell |
| **Property card** (Portfolio) | Small completeness indicator — *"2025: 8 of 14"* |
| **Finance figures** | "So far" labelling, which makes gaps evident when they matter |
| **Resume setup** | Property card offers **"Continue setup"**, reopening at the exact step |

### In-app coaching

The app tells landlords the thing most do not know: **ask the management office for a
statement of account for the year** — one document, twelve months. Same for the bank's
annual interest statement. Backfill framed as three phone calls, not forty uploads.

---

## 7. Three guards against inaccurate figures

1. **Order missing documents by damage, and name the cost.** Not alphabetical. *"2025 is
   missing your loan interest statement — usually the largest single deduction."* Ranking:
   tenancy agreement, maintenance, loan interest, assessment and land tax, insurance;
   upkeep never flagged.

2. **An incomplete year never looks finished.** A year with 4 of 12 maintenance months
   shows **"RM 12,400 so far — 4 of 12 months"**, never a clean total. The statutory tax
   estimate is withheld entirely on incomplete years. A landlord can only be misled by a
   number that looks complete.

3. **A year can be closed with known gaps.** **"Mark unavailable"** mirrors the existing
   `documind_payment_exceptions` mechanism for unpaid rent months. The year settles as
   *complete, with 2 acknowledged gaps* rather than nagging permanently.

---

## 8. Agreement-assisted liability — suggest, never decide

**Feasibility verdict: a trust problem, not a cost problem.**

- **Cost:** negligible. One agreement per tenancy, OCR runs locally via the existing Ollama
  stack. A 15-page scan is about a minute of local compute.
- **Technical:** the agreement has no text layer (confirmed: 15 pages, 0 characters, 1
  embedded image each), but local OCR already exists. Malaysian tenancy agreements are
  heavily templated and this one carries **marginal note headings** beside every clause —
  literally *"Payment of Utilities"* and *"To pay quit rent, assessment and service
  charges"*. Those anchors make the clauses far easier to locate than free legal prose.
- **The risk:** the residual error rate is silent and lands in a tax filing.

**Therefore: pre-fill, then confirm.** On tenancy agreement upload, the app reads the
clauses and presents *"Your agreement says the tenant pays water and electricity
(clause 5.2). Correct?"* with the clause text quoted beneath. The landlord taps once.
`utilities_paid_by` is only ever set by a confirmed answer, never by an unconfirmed
extraction. The same treatment applies to the repairs threshold.

---

## 9. Navigation and the document store

### Documents becomes the fifth bottom tab

Documind drops its Chat/Documents switch and becomes purely the assistant. The Documents
tab holds the property selector, the three top-level folders, the upload button, and a
header action opening the **Records** grid. Records is a header action rather than a second
switch, so the switch just removed is not recreated.

### Rent records demoted

| | Today | Proposed |
|---|---|---|
| Expected monthly? | Yes — nags for 12 | **No.** The lease covers the span |
| Folder exists? | Yes | **Yes** — renamed **Rent records** |
| Contents | Invoices | Invoices, receipts, e-invoices, bank transfer slips |
| When it matters | Always | When reality differs from the lease, or for audit proof |

The lease already derives monthly income (`derived` in the existing precedence chain
`unpaid > actual > derived > vacant`), so requiring twelve invoices a year was redundant.
The folder stays because the lease states what rent *should* be, not what happened — which
is why the unpaid-month feature exists — and because under LHDN's e-Invoice rollout a
corporate tenant issues a self-billed e-invoice to the landlord for rent. **Open item:**
confirm current LHDN e-Invoice obligations for individual landlords before building to
them; nothing in this design depends on the answer.

### Sub-category tags

Every document in **Expenses** carries tags derived from its own extracted facts.

- **Derived, never hand-entered.** Correct a fact in the review sheet and the tags follow.
- **Recomputed, not stored.** Consistent with the existing compute-on-read architecture.
- **Visible as chips** on each document row, so contents are legible without opening it.

Tags are useful whether or not folders are switched on — search and filter come free.

### Auto-folders (opt-in, off by default)

Single toggle in the Documents header: **"Organise into folders."**

**The rule: documents that keep arriving together stay together.**

Stated generally — this applies to **every tag in the catalogue**, with no hardcoded list
and no special case for strata:

> **A document's folder identity is its *periodic* tags. One-off tags ride along and never
> split a folder. A document with no periodic tags is filed by its full tag set.**

The periodic/one-off classification is not new data — it is the rhythm each subtype already
carries in §2:

| Rhythm | Tags | Role in grouping |
|---|---|---|
| **Periodic** (monthly / quarterly) | `maintenance`, `sinking_fund`, `utilities`, `management_fee`, `security_fee`, `rent_collection` | **Define the folder** |
| **One-off** (annual or per-event) | `insurance_premium`, `quit_rent`, `parcel_rent`, `assessment_tax`, `loan_interest`, `stamp_duty`, `agent_commission`, `legal_fee`, `advertising` | **Ride along** — never split a folder |
| **Ad hoc** | `upkeep`, `pest_control`, `renovation` | Ride along; form their own folder when alone |

Worked examples across property types:

| Document | Tags | Result |
|---|---|---|
| Ayer@8 February statement | maintenance, sinking, utilities, insurance, quit rent | Periodic core `{maintenance, sinking, utilities}` |
| Ayer@8 March statement | maintenance, sinking, utilities | **Same folder** — annual riders did not split it |
| Landed guarded-scheme quarterly bill | security fee, rent collection | Own folder, all quarters together |
| Standalone fire policy | insurance | No periodic tags → own folder |
| Standalone assessment bill | assessment tax | No periodic tags → own folder |
| Plumbing receipt | upkeep | No periodic tags → own folder |
| Management statement with a one-off pest treatment | maintenance, sinking, utilities, pest control | Ad hoc rides along → **folder unchanged** |

Grouping is recomputed over the whole set rather than assigned on arrival, so **upload
order never changes the outcome**.

**Known limitation:** two documents with genuinely different periodic cores — say
`{maintenance, sinking}` and `{maintenance, sinking, utilities}` — land in separate folders
even where a person would merge them. The sticky manual move is the escape hatch.
Predictable and occasionally wrong beats clever and unexplainable.

| Control | Behaviour |
|---|---|
| **Rename** | App proposes a name from the repeating tags; landlord may change it |
| **Move a document** | Manual placement is **sticky** — re-clustering never moves it back |
| **Untagged documents** | Stay in a plain **Expenses** folder, never forced into a guess |
| **Toggle off** | Flat list returns; names and manual moves are remembered and restored |

Inside a folder: reverse-chronological with **year and month separator lines**, grouped by
the period the document *covers*, not its upload date.

Opt-in because grouping is a judgement call: a landlord with 6 documents does not need it,
one with 300 across 4 years badly does — and the flat list, which must never break, stays
untouched for anyone who never turns it on.

---

## 10. Build sequence

Six stages, each independently shippable, each leaving the app working.

### Stage A — Expense rules foundation (backend only)
1. Non-deductible utilities and penalties excluded from `direct_expenses` — the live defect
2. Expanded subtype catalogue with Malay/English synonyms
3. First-letting vs renewal deductibility off the lease's `new | renewal`
4. Property profile gates expected categories; land-office slot satisfied by either subtype

*(Absorbs old Tasks 6, 7, 8.)*

### Stage B — Coverage and multi-period capture (backend only)
5. Multi-row extraction — one document fills many periods and categories
6. Period-based coverage plus the `x/N` installment check
7. **Mark unavailable** exceptions collection
8. Incomplete years show no finished total and no tax estimate

*(Absorbs old Tasks 4, 5.)*

### Stage C — Registration and backfill (Flutter + light backend)
9. Three-step guided registration — skippable past Step 1, resumable
10. Records grid, used at registration and permanently after
11. Missing documents ordered by damage, labelled with what they cost

### Stage D — Agreement-assisted liability (backend + Flutter)
12. Extract the utilities and repairs clauses, retaining quoted evidence
13. Pre-filled confirm-once prompt

### Stage E — Documents tab (Flutter only, low risk)
14. Fifth bottom tab; Documind becomes chat-only
15. Rental invoices demoted to the optional **Rent records** folder

### Stage F — Tags and folders (backend + Flutter, largest UI build)
16. Derived sub-category tags with chips
17. Opt-in clustering, rename, sticky manual moves, year/month separators

**Ordering rationale:** A defines the vocabulary everything else speaks. B cannot track
categories that do not exist. C displays what B computes. D refines one rule from A. E is
nearly free and clears the way for F, which needs A's tags.

**Early value:** Stage A alone fixes a live overstatement in the tax figures. Stage B alone
makes backfilling possible.

---

## 11. Architecture invariants (unchanged)

- `compute_finance_summary` stays **pure and deterministic** — zero LLM, all time entering
  via a `today` parameter.
- **Compute-on-read.** Nothing precomputed or cached, including tags and folder grouping.
- `properties` is a **Flutter-owned** Firestore collection; the backend reads it.
- Collections: `documind_docs`, `documind_chunks`, `documind_payment_exceptions`, plus a new
  unavailable-document exceptions collection. **No** `documind_recurring_charges`.
- Tests use `unittest`, not pytest: `cd backend && python -m unittest discover tests -v`.

---

## 12. Out of scope

- Residential vs commercial split — does not change the quit/parcel rule.
- Loan repayment schedules — the annual statement absorbs them.
- Repairs vs capital improvements at the line level — captured as a deductibility rule for
  the named subtypes only; the engine does not adjudicate whether a given repair receipt is
  a capital improvement.
- Obligation tracking — no "did I pay this month" state or reminders for the landlord's own
  bills. Expenses are tracked as **billed**, never as settled; see §2. Rent keeps its
  unpaid-month mechanism as the sole exception.
- Extracting outstanding or arrears balances from statements. Considered and declined —
  accumulating arrears already surface as late-payment lines.
- Generating e-invoices. The app stores them; it does not issue them.

---

## 13. Evidence base

- `demo_documents/ayer8_commercial_real_docs/INV FEB 25 UNIT B2-1-02_….pdf` — Perbadanan
  Pengurusan Ayer@8, unit B2-1-02. All figures in §3 come from this file.
- `demo_documents/ayer8_commercial_real_docs/2023 Final Agreement Ayer 8 and JNT
  25102023 [Signed].pdf` — 15 scanned pages, no text layer. Clauses 5.2, 5.14, 5.19, 6.1
  and 6.2 read by rasterising the embedded page images (poppler unavailable; `pypdf` +
  Pillow used instead).
- LHDN Public Ruling 12/2018 on rental income, via public summaries, for the
  initial-versus-renewal deductibility rule.
