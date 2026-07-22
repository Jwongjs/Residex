# DocuMind — Property Expense Model

_How each Malaysian landlord expense is captured, what the app expects per property, and how it folds into the rental-income computation._ Line references point into `backend/` (paths relative to this file).

Companion to [END_TO_END_FLOW.md](END_TO_END_FLOW.md) (the upload→ingest→finance→chat pipeline) and [rag/DOCUMENT_TYPE_CATEGORIES_AND_FILE_FORMATS.md](rag/DOCUMENT_TYPE_CATEGORIES_AND_FILE_FORMATS.md) (the 7 upload categories and their extracted fields). This doc adds the layer those don't: the **capture-vs-derive decision**, **per-property expectations**, and the **recurring-charge + coverage design**.

> **Status: partially superseded.** Rows #2 and #3 (the derive-once maintenance
> rate and the `documind_recurring_charges` collection) are **void** — replaced by
> the document-first model in
> [`docs/superpowers/specs/2026-07-21-document-first-expense-model-design.md`](../docs/superpowers/specs/2026-07-21-document-first-expense-model-design.md),
> under which every figure traces to an uploaded document and nothing is derived
> from a typed rate. The remaining rows stand; see [Build status](#build-status).

---

## The one rule

Every expense is captured one of two ways, and a single test decides which:

> A cost may be **entered once and derived** across the year only if it is **flat, self-known, and frequent**. Everything else is **upload the bill**.

Only **strata maintenance + sinking fund** pass all three (a flat rate the owner already knows, billed monthly). They are the *only* derive-once expenses — not an arbitrary special case. Everything official, variable, or occasional (taxes, insurance, loan interest, repairs) is a document upload, because the document is both the amount *and* the LHDN audit proof.

Why the obvious neighbours don't qualify:
- **Loan interest** *declines* every year as principal is paid down → not flat → must read each year's statement.
- **Insurance** resets at renewal, **assessment tax** changes on reassessment → not reliably flat, and both are official bills worth keeping as proof.
- **Repairs** are ad-hoc → nothing to derive.

---

## Property profile (set at registration)

Two intrinsic, stable facts captured when the property is registered. They don't compute anything — they **tailor which expenses the app expects and how it labels them**, so each landlord sees a short, relevant list instead of a flat catalogue.

| Field | Values | Drives |
|---|---|---|
| `property_type` | `landed` \| `strata` | Quit-rent vs parcel-rent, maintenance/sinking applicability, insurance applicability, the water-pump/common-area boundary |
| `has_mortgage` | `yes` \| `no` | Whether loan interest is expected at all |
| `utilities_paid_by` | `tenant` (default) \| `landlord` | Whether water/sewerage lines on a bundled statement are deductible |

Missing/unknown → the engine falls back to today's generic behaviour (no property-type gating), so **existing properties keep working** until the owner sets the profile. The `properties` collection is Flutter-owned; registration writes these fields and the backend reads them in [`_list_landlord_properties`](rag/documind_service.py#L433) (which today reads only `name` + `ownership_share`).

### One Property, One Tax

Assessment tax is always payable to the council. The **land-office** tax depends on structure — and, for strata, on titling:

| Structure | Land-office tax | Council tax | Maintenance + sinking | Fire insurance |
|---|---|---|---|---|
| **Landed** (house, shop-office, factory, warehouse) | **Quit rent** (cukai tanah) | Assessment (always) | ❌ none¹ | Owner buys — **1 doc/yr** |
| **Strata** (condo, office lot, SoHo/SoVo, serviced apt) | **Quit rent _or_ parcel rent**² | Assessment (always) | ✅ MC-billed | MC master policy — **bundled line or inside maintenance; no standalone doc** |

¹ Unless a guarded/managed landed scheme charges a fee — the owner may still upload it; the app just won't *nag* for it.

² **Never assert which one.** Parcel rent (cukai petak) applies once individual strata titles are issued and the land office bills parcel owners directly. Where the development is still on a **master title**, the management apportions the land's **quit rent** to each parcel instead — verified against a real Ayer@8 statement (unit B2-1-02), which bills "QUIT RENT YEAR 2025" to a *strata* parcel. Coverage therefore expects *a land-office tax*, satisfied by **either**.

---

## The landlord's-eye interaction model

The nine-row engine view below is **not** what a landlord sees. They set two facts at registration, then their world is **"upload the bill when it arrives"** with exactly **one shortcut**: *set your monthly strata maintenance once so you aren't uploading it twelve times.* The profile hides everything irrelevant and picks the right labels (a strata owner never sees "quit rent" or a separate "insurance"; a landed owner never sees "maintenance" or "parcel rent").

| **Landed house, mortgaged** | **Condo unit, mortgaged** |
|---|---|
| Rent (or lease auto-fills) | Rent (or lease auto-fills) |
| Assessment tax — upload (2/yr) | Assessment tax — upload (2/yr) |
| Quit rent — upload (1/yr) | Parcel rent — upload (1/yr) |
| Fire insurance — upload (1/yr) | Maintenance — **set once** |
| Loan interest — upload (1/yr) | Loan interest — upload (1/yr) |
| Repairs — upload as they happen | Repairs inside unit — as they happen |

This is **simpler than today's flat coverage list**, which nags every property for every category (a landed owner is currently told they're "missing maintenance" they never pay).

---

## Bundled statements (strata) — the `expenses` path

A strata management statement usually lists **several charges on one document** (maintenance, sinking fund, sometimes fire insurance). This is handled by the combined **`expenses`** upload category, whose extractor is built for exactly this — *"one document may contain several distinct charge types"* ([fact_extractor.py:242](rag/fact_extractor.py#L242)). It splits the statement into per-charge **line items**, each with a `subtype` mapped to its finance category via `EXPENSE_SUBTYPE_CATEGORY` ([fact_extractor.py:118](rag/fact_extractor.py#L118)), then opens a **review sheet** so the landlord corrects any mis-parse before saving (`PATCH …/facts` → `update_expense_lines`).

- **Chunking + embedding are category-agnostic.** A bundled statement is chunked and embedded like any doc, so chat retrieval works regardless of how charges are grouped — bundling only matters to *fact extraction*.
- **Upload bundled statements under `Expenses`, not `Maintenance`.** The single-type extractors pull one amount and would silently drop the other charges.
- **Separate bills still use their typed folder.** Parcel/quit rent usually arrive as their own land-office bills; whatever is itemised together goes under `Expenses`, whatever arrives alone uses its category.

> **⚠️ Reconciliation hazard (maintenance).** Maintenance/sinking can now arrive **two ways** — a bundled `expenses` line *and* the manual rate (#2/#3), booked in different engine branches. `_maintenance_lines` must treat the **actual** figure — from *either* a `maintenance`-category doc *or* an `expenses`-subtype line — as the value that cancels the derived rate for those months, or a strata owner who uploads statements **and** set a rate is counted twice. The same "read subtypes from both sources" rule applies to subtype-aware tax coverage (#4–6).

---

## Non-deductible lines on a landlord's bill

A bundled statement carries charges the landlord is billed but **cannot deduct**. Verified against a real Ayer@8 statement (unit B2-1-02, Feb 2025) where **RM137.92 of RM1,626.81** outstanding is non-deductible:

| Line on the statement | Subtype | Deductible? |
|---|---|---|
| Water meter billing, water sewerage billing | `utilities` | **Only when the landlord bears them** — see below |
| Late payment charges / interest | `late_penalty` | **Never** — penalties are not deductible |

These subtypes are **captured, displayed, and reviewable, but excluded from the fold**: every line carries `deductible: bool`, and only deductible lines feed `direct_expenses`, the breakdown, and the statutory estimate. Capture-but-exclude beats dropping — the landlord still sees the water charges on their statement; they just don't inflate a tax deduction.

> **Before this rule, utilities were silently deducted.** The extractor's synonym table routed *"Indah Water, utility bills paid by the owner"* into `upkeep`, which **is** deductible. Utilities move to their own subtype.

### Who pays utilities is a setting, not an extraction

Whether the tenant or landlord bears utilities is fixed by the **tenancy agreement** — but the agreement never enters the computation:

- **Fact extraction only *classifies*** — "this line is a utility charge." It does **not** read the tenancy agreement and does **not** decide deductibility.
- **The engine applies the policy** from `utilities_paid_by` on the property profile, defaulting to `tenant` — the common Malaysian case, and the safe direction, since under-claiming beats over-claiming.
- **The agreement stays advisory.** DocuMind chat already answers *"who pays the water bill?"* from the scanned agreement via RAG. That is the right use of the document — informing the landlord, never silently driving a figure. Signed agreements are typically **scanned PDFs with no text layer** (the Ayer@8 tenancy is 15 such pages), so deciding a deduction from them would mean OCR plus legal interpretation, invisibly.

---

## Per-expense detail

All amounts are deductible against **s.4(d)** rental income (YA = calendar year); the statutory figure is an estimate for the landlord's tax agent (`STATUTORY_NOTE`). Expenses only deduct for the portion of the year the property was available to let — the engine already prorates by rented fraction ([finance_engine.py:434](rag/finance_engine.py#L434)).

### 1. Rental income ✅
- **Who / cadence:** tenant pays monthly.
- **Applies to:** any tenancy.
- **Capture:** a `rental_invoice` (actual) per month; a `lease` supplies `monthly_rent` + span and the engine **derives** months without an invoice; months can be **marked unpaid** (payment exception).
- **Folds via:** `_scope_income` ([finance_engine.py:81](rag/finance_engine.py#L81)), precedence *unpaid > actual > derived > vacant*.
- **Status:** live. This is the pattern the maintenance design mirrors on the expense side.

### 2. Maintenance fee — caj penyelenggaraan 🟡
- **Who / cadence:** JMB/MC bills monthly (or quarterly); a flat rate from the owner's share units.
- **Applies to:** **strata only.**
- **Capture (planned):** the manual monthly rate is a **fallback**, not the primary route. Strata owners who upload their periodic statement already supply *actual* maintenance/sinking figures — often via the bundled `expenses` path (see **Bundled statements** above); the rate only fills months with no uploaded figure. Per month, an **actual** figure — from *either* a `maintenance`-category doc *or* an `expenses`-subtype line — wins; otherwise the rate is **derived**, prorated by rented months like lease-derived rent. **The actual figure must cancel the derived rate for its months, or the two double-count.** Derived-without-doc lines carry `source:"derived"` and an *"estimated — upload bills to confirm"* caveat, parallel to derived rent.
- **Today:** each uploaded maintenance doc books a single line at `period_start`'s year ([finance_engine.py:225](rag/finance_engine.py#L225)); capturing a full year needs every period uploaded, with no rate/derive.
- **Storage (planned):** new backend-owned `documind_recurring_charges` collection (mirrors `documind_payment_exceptions`), threaded into `compute_finance_summary` as a new source.
- **Coverage:** a year an active rate covers counts as *maintenance present* — not flagged missing.

### 3. Sinking fund — kumpulan wang penjelas 🟡
- **Who / cadence:** JMB/MC, monthly alongside maintenance (typically ~10% of the maintenance charge).
- **Applies to:** **strata only.**
- **Capture:** identical to maintenance — its own recurring-charge `subtype: sinking_fund`, which **rolls into the `maintenance` breakdown category** (unchanged mapping in `EXPENSE_SUBTYPE_CATEGORY`, [fact_extractor.py:118](rag/fact_extractor.py#L118)).
- **Status:** planned, same build as #2.

### 4. Assessment tax — cukai taksiran / cukai pintu 🟡
- **Who / cadence:** local council (PBT), **two half-yearly installments** (due ~end-Feb and end-Aug), each half of an annual assessment on the annual value (*nilai tahunan*).
- **Applies to:** **all** properties.
- **Capture:** **upload each installment bill** — official proof, stays document-based. Each books its own line via the existing `installment` label ("1/2", "2/2"), summing naturally ([finance_engine.py:213](rag/finance_engine.py#L213)). The engine reads `amount` off the bill; it does **not** recompute from *nilai tahunan*.
- **Coverage (planned):** **installment-aware.** Parse `x/N` from each bill's `installment` field; expect `N`; if fewer distinct installments are present, flag *"Assessment tax — 1 of 2"*. Expectation comes from the bill's own text, never a hardcoded council table — so annual-billing councils (`1/1` or no `N`) never false-trigger. If no `N` is stated anywhere, falls back to today's per-year check.
- **Today:** any single tax doc marks "tax" covered for the year ([finance_engine.py:282](rag/finance_engine.py#L282)) — a forgotten second installment silently under-counts and isn't flagged.

### 5. Quit rent — cukai tanah 🟡
- **Who / cadence:** state land office, **annual** (due ~end-May). For strata on a **master title**, billed instead **via the management** as an apportioned parcel share.
- **Applies to:** **all landed**, and **strata on a master title** (`tax` subtype `quit_rent`).
- **Capture:** upload the annual bill, or let it arrive as a line on the bundled management statement.
- **Coverage (planned):** for landed, expected outright. For strata it satisfies the shared land-office slot — see #6.

### 6. Parcel rent — cukai petak 🟡
- **Who / cadence:** state land office, annual; billed directly to parcel owners **once individual strata titles are issued** (Strata Titles Act reforms, KL/Selangor from ~2018).
- **Applies to:** **strata with individual titles** (`tax` subtype `parcel_rent`).
- **Capture:** upload the annual bill (document-based).
- **Coverage (planned):** strata expects **one land-office tax**, satisfied by `parcel_rent` **or** `quit_rent` — never both demanded, and never a specific one named, because titling status decides which arrives. A landed property is never asked for parcel rent.

### 7. Fire insurance 🟡
- **Who / cadence:** **annual.**
  - **Landed:** owner buys — paid to the bank (bundled into the loan account once a year) or via an agent; the owner **receives an annual document**.
  - **Strata:** the MC buys a bulk **master fire policy**; the owner holds **no standalone policy.** If the management statement **itemises** an insurance charge it's captured as an `insurance_premium` line from the bundled `expenses` statement (see **Bundled statements** above); otherwise it's subsumed in the maintenance charge (#2).
- **Applies to:** **landed** as a standalone annual document; **strata** only as an itemised line within the bundled statement — never a separate upload.
- **Capture:** upload one policy/premium document per year (`insurance` category, [fact_extractor.py:52](rag/fact_extractor.py#L52)); folds at `policy_start`'s year ([finance_engine.py:234](rag/finance_engine.py#L234)).
- **Coverage (planned):** expected **only when `property_type = landed`.** Never nag a strata owner — it would be double-asking.

### 8. Loan interest — faedah pinjaman 🟡
- **Who / cadence:** the bank issues **one annual interest statement** (*penyata faedah*).
- **Applies to:** **only when `has_mortgage = yes`.**
- **Capture:** upload the annual statement (`loan` subtype `interest_statement`; only `interest_paid` is deductible, not principal — [finance_engine.py:208](rag/finance_engine.py#L208)). **One document per year, full stop.**
- **Explicitly not modelled:** payment schedules — monthly vs **bi-weekly**, **moratoriums**, restructuring. The annual statement already nets all of that into the deductible interest figure; modelling schedules adds complexity for zero tax impact.
- **Coverage (planned):** expected only for mortgaged properties; cash buyers are never nagged. Capture itself is unchanged from today.

### 9. Upkeep / repairs 🟡 (coverage) ✅ (capture)
- **Who / cadence:** ad-hoc, variable, unbilled (plumbing, water pump on landed title, aircon servicing…).
- **Applies to:** all — landed: whole property; **strata: inside the unit only** (common-area plant like the water pump is the MC's job, funded from sinking fund, so a strata owner does *not* book it as upkeep).
- **Capture:** **upload the receipt per event** — the one category where dynamic upload is unarguably correct; nothing to derive or schedule (`upkeep` category, folds at `service_date`'s year, [finance_engine.py:220](rag/finance_engine.py#L220)).
- **Not upkeep:** water and sewerage charges. They are `utilities` (see [Non-deductible lines](#non-deductible-lines-on-a-landlords-bill)) — previously mis-routed here and silently deducted.
- **Coverage:** soft only. Never hard-flagged (you can't predict repairs).
- **Known limitation (out of scope here):** Malaysian tax deducts *repairs* (restoring) but not *improvements/renovations* (capital); the engine treats all upkeep as deductible today.

---

## Coverage report — type + subtype + installment aware

Today `_property_coverage` ([finance_engine.py:301](rag/finance_engine.py#L301)) checks a flat `FINANCE_CATEGORIES` list ([finance_engine.py:28](rag/finance_engine.py#L28)) against every property, so it can't tell quit from parcel from assessment, and nags landed owners for maintenance. Planned per-year logic:

1. **Expected set from the profile** — assessment tax for all; quit rent iff landed; parcel rent iff strata; maintenance + sinking iff strata; insurance iff landed; loan interest iff mortgaged; rental invoice iff the lease covered that year (unchanged). Unknown profile → today's generic set.
2. **Subtype-aware tax** — check `assessment` separately from the **land-office slot** (reading subtypes from both `tax`-category docs and `expenses`-subtype lines). Landed expects `quit_rent`; strata expects `quit_rent` **or** `parcel_rent` and is satisfied by either.
3. **Installment-aware** — for tax subtypes present, run the `x/N` gap check (#4). A partial year surfaces distinctly from a fully-missing one (amber "incomplete" vs red "missing"), via a new `partial_installments` field on `YearCoverage` ([models/documind_models.py:182](models/documind_models.py#L182)).

Keep the two new checks in small isolated helpers (`_expected_categories(profile)`, `_installment_gaps(prop_docs, year)`, `_parse_installment("1/2")→(1,2)`) for unit-testability.

---

## Out of scope (YAGNI)

- **Residential vs commercial split** — doesn't change the quit/parcel rule. Deferred; would later affect commercial assessment rates and SST on commercial rent.
- **Loan repayment schedules** (bi-weekly, moratorium, restructuring) — the annual statement absorbs them.
- **Repairs vs capital improvements** deductibility — existing engine limitation, noted not fixed.
- **Obligation tracking** — no "did I pay this month" state or reminders for the landlord's own bills. Recurring charges *estimate* the expense; they don't track payment.

---

## Build status

| # | Expense | Applies to | Capture | Status |
|---|---|---|---|---|
| 0 | Profile: `property_type` + `has_mortgage` | Every property | 2 toggles at registration | ✅ Backend |
| 1 | Rental income | Any tenancy | Invoice + lease-derive + unpaid | ✅ Live |
| 2 | Maintenance | Strata | **Set rate once** + doc override | ❌ Void — superseded |
| 3 | Sinking fund | Strata | Same as maintenance (→ maintenance bucket) | ❌ Void — superseded |
| 4 | Assessment tax | All | Upload / installment `x/N` aware | 🟡 Designed |
| 5 | Quit rent | Landed · strata on master title | Upload (1/yr) or bundled line | ✅ Backend |
| 6 | Parcel rent | Strata with individual titles | Upload (1/yr) — shares #5's land-office slot | ✅ Backend |
| 7 | Insurance | Landed (standalone) · strata (bundled line only) | Upload (1/yr) | ✅ Backend |
| 8 | Loan interest | If mortgaged | Upload annual statement (no schedules) | ✅ Backend |
| 9 | Upkeep / repairs | All (strata: inside unit) | Upload per event | ✅ Live capture · 🟡 coverage gating |
| 10 | Utilities (water, sewerage) | Tenant by default | Captured, **not deducted** unless `utilities_paid_by=landlord` | ✅ Backend |
| 11 | Late payment penalties | — | Captured, **never deducted** | ✅ Backend |

Legend: ✅ live in the engine · 🟡 designed, pending build · ❌ void, superseded.

Stage A of the document-first plan is complete (deductibility rules, expanded
subtype catalogue, profile-gated coverage, land-office tax slot).

Stage B is complete: period-based coverage (installments, monthly-slot
maintenance), the mark-unavailable mechanism, the per-property statutory
gate on year completeness, and the three-state rent model with recovery are
all live in the engine. Registration/backfill UI, the Documents tab, and
tags/folders (Stages C–F) are pending.

---

## Implementation surface (planned)

- **Firestore:** new backend-owned `documind_recurring_charges` collection — `{landlord_id, property_id, unit_id?, subtype: maintenance|sinking_fund, monthly_amount, effective_from, effective_to?}`, dates as `YYYY-MM`. Clones the `documind_payment_exceptions` shape.
- **Routes** (clone payment-exception at [rex_routes.py:128](api/rex_routes.py#L128)): `PUT /documind/finance/recurring-charge`, `DELETE /documind/finance/recurring-charge`.
- **Service:** `get_finance_summary` ([documind_service.py:1358](rag/documind_service.py#L1358)) fetches the collection + reads `property_type`/`has_mortgage`, passing both into `compute_finance_summary`.
- **Engine:** `_maintenance_lines` — per-month reconciliation where an **actual** figure (from a `maintenance`-category doc **or** an `expenses`-subtype line) overrides the rate-derived amount, so bundled statements and the manual rate never double-count; `_expected_categories` + subtype/installment-aware `_property_coverage` (subtypes read from both `tax` docs and `expenses` lines). The `expenses` multi-line extractor already exists — no new extraction work.
- **Models:** `ExpenseLine.source` ([models/documind_models.py:160](models/documind_models.py#L160)); `YearCoverage.partial_installments`; `RecurringCharge` request/response; property-profile fields.
- **Flutter:** registration adds the two profile toggles; a maintenance-rate entry field; an "estimated" badge on derived lines.
- **Docs:** fold a finance-expenses section into [END_TO_END_FLOW.md](END_TO_END_FLOW.md) once built.

## Personal Question
I have came to know that:
- Maintenance and sinking funds are the only expenses paid monthly
- Assessment tax (cukai taksiran) are paid semi annually 
- Whereas expenses such as insurance types (fire...not sure applicable to all companies in malaysia) and upkeep (e.g. water pump...)

I was thinking that for maintenance and sinking funds, do we still need document uploads for this (report if there are mispayments like rental payment) or just allow landlord to manually input it during property registration

Assessment tax would still be needed documents as the value of rental income yearly (nilai tahunan) affects the total tax payment

And then yearly payments like insurance and upkeep just require one document per year?

Take into account which payment price is variable which may need frequent uploads