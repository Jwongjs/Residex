# Landlord-Testing Fixes — Finance Consistency, Loan Restructure, Retrieval Failure

Date: 2026-08-04
Branch: `feat/finance-tab-restructure`
Status: Design — awaiting user review
Builds on: `2026-07-27-per-unit-loans-design.md`, `2026-07-27-two-tier-expense-model-design.md`

## Problem

Six defects from a landlord testing session:

1. A loan figure entered at the property panel never appears as a unit expense.
2. Total Received and Total Expenses on the Finance tab ignore ownership share %.
3. Financial terms are inconsistent across the Finance tab, property panel and
   unit screen — the same word names different quantities at different levels.
4. Asking DocuMind "When is the tenancy agreement ended" returns *"I couldn't
   search your documents. Please check your Firestore vector index."* even
   though a tenancy agreement is uploaded.
5. The `2025 · 2 missing` / `2026 · 6 missing` coverage bubble on the property
   panel duplicates the bottom document-nudge panel.
6. The bottom-line figure should read **Overall Net Profit/Loss** on the Finance
   tab and **Net Profit/Loss** on the property panel.

Two further defects were found while investigating and are folded in, because
they are the same underlying problem as (1) and (3):

7. `property_expense_lines` is produced by the engine and parsed by the app but
   **rendered nowhere** — property-scope expenses (a building-wide loan, quit
   rent, assessment tax) move the aggregate totals while appearing in no
   drill-down at any level.
8. Property-block statutory income and the Finance-tab statutory total are
   computed on **different bases**, so the blocks do not sum to the headline
   (see §2.4).

---

## Part 1 — Ownership share applied at every level (fixes 2)

### Current behaviour

`share` is applied at exactly two sites, [finance_engine.py:1146-1153][fe-share]:

```python
statutory_sum += share * (received - prorated_expenses)
net_pl_sum    += share * (received - landlord_paid)
```

Everything else — `total_received`, `total_expenses`,
`total_landlord_expenses`, the property block's `received_rent` /
`direct_expenses` / `rental_income_or_loss`, every unit `contribution` and
`statutory_contribution`, and `expense_breakdown` — is the property's **full**
figure. The comment at [finance_engine.py:1150-1152][fe-share] records this as
deliberate, with the caption at
[finance_screen.dart:407-411][fs-caption] explaining the mixed basis to the
landlord. **This design reverses that decision.**

### Chosen approach

Every monetary figure the landlord sees is their own share. `share` is applied
**once**, at a single choke point per property, to:

| Field | Where |
|---|---|
| `received_rent`, `derived_rent`, `outstanding_rent` | totals + property block |
| `direct_expenses`, `landlord_expenses` | totals + property block |
| `rental_income_or_loss` | property block |
| `net_pl`, `statutory_contribution` | totals + property block |
| `contribution`, `statutory_contribution` | unit block |
| `expense_breakdown` values | totals |
| `amount` on every expense line | property + unit breakdowns |

**Implementation constraint — the choke point is per property, before
accumulation.** Each property carries its own `share`, so a cross-property total
cannot be scaled by any single factor. The shape is therefore:

1. Compute the property's figures on the **full-property basis**, exactly as
   today.
2. Scale that property's figures **once**, by its own `share` — every field in
   the table above, including its expense-line amounts.
3. Accumulate the **already-scaled** values into the cross-property totals.

The totals themselves are then never scaled again. `net_pl` and `statutory`
already multiply by `share` inside the loop today
([finance_engine.py:1146-1153][fe-share]); those two multiplications are
**removed** when the choke point is introduced, or they will double-apply.

`_round2` is applied **after** scaling, not before. The existing floor that
clamps a negative statutory total to `0.0`
([finance_engine.py:1230-1232][fe-floor]) operates on the accumulated total and
is unchanged — it still runs after scaling, because its input is now a sum of
scaled values.

### Expense-line amounts — the deliberate call

Individual expense lines are scaled along with their totals, so a breakdown
always sums to its own header. To keep each line tied to its source document,
a line under a share < 1.0 renders its provenance as secondary text:

```
Quit rent                RM 600.00
                         your 50% of RM 1,200.00
```

The rejected alternative — lines at document face value with scaled totals —
leaves the landlord looking at a breakdown that visibly does not add up.

At `share == 1.0` (the overwhelmingly common case) nothing changes: no
provenance text, no caption, identical numbers to today.

### Presentation

- The mixed-basis caption at [finance_screen.dart:407-411][fs-caption] is
  replaced by a plain `Shown at your 50% share`, rendered only when
  `share < 1.0`.
- The existing `50% share` chip on the property block header
  ([finance_screen.dart:336-349][fs-chip]) stays.
- The engine's `share_notes` caveat ("Ownership share applied: X at 50%.")
  stays.

---

## Part 2 — One glossary, three levels (fixes 3, 6)

### 2.1 The glossary

| Concept | Finance tab | Property panel | Unit screen |
|---|---|---|---|
| Bottom line | **Overall Net Profit/Loss** | **Net Profit/Loss** | — |
| Money in | **Overall Rental Income** | **Rental Income** | **Rental income** |
| Money out | **Overall Expenses** | **Expenses** | **Expenses** |
| Tax base | **Overall Statutory Income** | **Statutory Income** | **Statutory income** |

Rule: the aggregate level prefixes **Overall**; the property and unit levels use
the bare term. The provisional variant on the Finance tab keeps its existing
prefix behaviour — `Current Overall Statutory Income` when any property is
incomplete ([finance_summary_panel.dart:244-247][fsp-statutory]).

### 2.2 String changes

| File | Current | Becomes |
|---|---|---|
| [finance_summary_panel.dart:123][fsp-hero] | `TOTAL NET P/L · {year}` | `OVERALL NET PROFIT/LOSS · {year}` |
| [finance_summary_panel.dart:43][fsp-received] | `TOTAL RECEIVED` | `OVERALL RENTAL INCOME` |
| [finance_summary_panel.dart:48][fsp-expenses] | `TOTAL EXPENSES` | `OVERALL EXPENSES` |
| [finance_summary_panel.dart:245-247][fsp-statutory] | `Statutory Rental Income` | `Overall Statutory Income` |
| [finance_screen.dart:359][fs-received] | `RECEIVED` | `RENTAL INCOME` |
| [finance_screen.dart:360][fs-expenses] | `EXPENSES` | `EXPENSES` (value changes, §2.3) |
| [finance_screen.dart:369][fs-netpl] | `Net P/L · {year}` | `Net Profit/Loss · {year}` |
| [finance_screen.dart:391][fs-statutory] | `Statutory rental income/loss` | `Statutory Income` |
| [unit_finance_detail_screen.dart:179][ufd-net] | `Net contribution` | `Rental income` |
| [unit_finance_detail_screen.dart:194][ufd-stat] | `Contributing statutory income` | `Statutory income` |

Each unit dropdown gains a caption naming what it rolls into:
"Contributes to this property's Rental Income" / "…Statutory Income".

### 2.3 "Expenses" means one thing — landlord cash out

Today the Finance tab's `TOTAL EXPENSES` renders `totals.landlordExpenses`
(every ringgit the landlord paid) while the property panel's `EXPENSES` renders
`block.directExpenses` (LHDN-deductible lines only). Two different quantities
under near-identical labels.

**Resolution:** "Expenses" means **landlord cash out** at every level. The
property panel switches from `block.directExpenses` to a new
`block.landlordExpenses`, which the engine must now expose per property (it
currently computes `landlord_paid` per property but only accumulates it into
the totals, [finance_engine.py:1109][fe-landlordpaid]).

Consequence — and the point of the change: `Rental Income − Expenses = Net
Profit/Loss` becomes true at **both** the Finance tab and the property panel.

Deductible-only is not lost. It remains the basis of statutory income and is
labelled **Deductible expenses** inside the statutory breakdown, where
[unit_finance_detail_screen.dart:197][ufd-deductible] already names it that.

### 2.4 Statutory basis discrepancy (defect 8)

The Finance-tab statutory total and the property-block statutory figure are
computed on different expense bases:

```python
statutory_sum += share * (received - prorated_expenses)   # occupancy-prorated
"statutory_contribution": share * (received - direct)     # NOT prorated
```

`prorated_expenses` is deductible lines weighted by the occupancy fraction;
`direct` is all deductible lines. For any property under 100% occupancy the
property blocks do **not** sum to the Finance-tab headline.

**Proposed resolution:** align the property block to the prorated basis, so the
blocks sum to the headline. This changes displayed property-level statutory
figures for any property with a vacancy — upward, since less expense is
deducted.

> **Open for the reviewer.** This is a numbers-visible change that was not in
> the original six items. If it should be deferred, the rest of Part 2 stands
> on its own and this section is dropped.

---

## Part 3 — Loan restructure (fixes 1, 7)

### 3.1 Root cause of defect 1

Two independent bugs:

**(a) The engine blanks property-scope lines for the synthetic scope.**
[finance_engine.py:1044-1047][fe-unitlines]:

```python
unit_lines = (
    lines_by_unit.get(scope["unit_id"], [])
    if scope["unit_id"] is not None else []
)
```

The synthetic "Whole property" scope has `unit_id is None`, so it receives an
empty line list — even for a single-let house where that scope is the *only*
scope and the property's expenses are unambiguously its expenses.

**Fix:** give the synthetic scope `lines_by_unit.get(None, [])`.

**Safety:** unit blocks are display-only. `total_expenses`, `net_pl` and
`statutory` all sum from `expense_lines`, never from unit blocks
([finance_engine.py:1201-1205][fe-totals]), so no total can double-count. When
real units coexist with the synthetic scope, each still receives only its own
lines, so no line is attributed twice within the display either.

**(b) The scope dropdown offers "Whole property" where it is meaningless.**
A `Unit` is an individually rentable apartment in a building
([unit.dart:5-8][unit-doc]) — in Malaysia, separately titled with its own
mortgage. For a strata property with units, a whole-property loan scope has no
real-world referent.

### 3.2 Loan scope by structure type

The discriminator is `structureType`, **not** unit count — a landed house is one
title with one loan even when the landlord has created units for its rooms.

| `structureType` | Units? | Loan scope offered |
|---|---|---|
| `landed` | any | Whole property only — no dropdown |
| `strata` | yes | Units only — no "Whole property" option |
| `strata` | no | Whole property only — no dropdown |
| `null` (some commercial) | any | Both — dropdown as today |

Existing whole-property manual entries on strata properties remain valid data
and continue to compute; this rule governs only what new entry offers. The
doc_id scheme from `2026-07-27-per-unit-loans-design.md` is unchanged.

### 3.3 Property setup loses the loan questions

`_buildLoanInputSelectors` ([add_property_dialog.dart:636-680][apd-loan]) is
removed. `_buildMortgageSelector` ([add_property_dialog.dart:605-634][apd-mortgage])
stays — whether the property is mortgaged is a real fact about it, and it gates
which document categories the engine expects.

Asking a landlord to commit to "upload" vs "manual" during registration is
premature — they have not yet seen a statement — and it is sticky: choosing
"upload" today leaves no escape hatch when a PDF will not parse.

- `loan_input_method` is **retired as a UI gate**. The field stays on the model
  for back-compat; nothing reads it to decide what to show.
- `loan_input_cadence` is **kept** but relocated (§3.4).

### 3.4 Cadence, asked once, in the sheet

`loan_input_cadence` (`annual` | `monthly`) does two things and is therefore
kept:

1. Shows or hides the MONTH dropdown in the entry sheet
   ([manual_loan_entry_sheet.dart:203-219][mles-month]).
2. Sets the completeness bar in `_loan_completeness`
   ([finance_engine.py:916-918][fe-cadence]): `monthly` requires **every**
   in-scope month before a unit is resolved; `annual` requires one entry. This
   is what stops a landlord who entered January and stopped from being told the
   year is complete.

**Relocation:** the first time manual loan entry is used for a property, the
sheet asks "One annual figure, or monthly instalments?" and persists the answer
to `loan_input_cadence`. It is editable inside the sheet afterwards. The
question moves from registration to the moment it is meaningful;
`_loan_completeness` is unchanged.

### 3.5 Two entry points

- **In context, year-scoped:** `DocumentNudgeBanner` gains a third action,
  **Enter figures manually**, shown only when the missing category is `loan`.
  This sits beside the existing Upload documents / Mark unavailable actions
  ([finance_screen.dart:485-502][fs-nudge]).
- **Persistent:** **Enter figures manually** as a peer of Upload in the
  **Loans & Financing** folder ([document_categories.dart:14][dc-loan]). The
  nudge clears once figures exist, so without this there is no path back in to
  correct a typo.

The Finance-tab "Add loan figures" button ([finance_screen.dart:420-445][fs-loanbtn])
stops gating on `loanInputMethod == 'manual'`; it shows whenever a mortgaged
property has unresolved loan figures for the viewed year.

### 3.6 Property-level expenses become visible (defect 7)

`property_expense_lines` is emitted by the engine
([finance_engine.py:1220][fe-propexp]), parsed into the entity
([finance_summary.dart:58][fsum-propexp]), and rendered nowhere.

**Fix:** render it as a **Property-level expenses** section in the property
panel, with the same line treatment as unit expenses.

**Explicitly not doing:** pro-rating property-level expenses into units.
Splitting a building's quit rent across units produces a per-unit number the
landlord cannot tie to any document. Units show unit-attributable lines only;
property-scope costs are shown at the level they belong to.

---

## Part 4 — Coverage strip removed (fixes 5)

`_buildCoverageStrip` ([finance_screen.dart:269-313][fs-strip]) and its call
site ([finance_screen.dart:353-356][fs-stripcall]) are deleted.

- `block.coverage` **stays in the model** — `yearCoverageFor` still drives the
  "acknowledged unavailable" rows at [finance_screen.dart:504-527][fs-unavail].
- The strip's secondary role as a per-property year switcher is already served
  by the app-bar `FinanceYearButton` ([finance_screen.dart:109-114][fs-yearbtn]).
- `DocumentNudgeBanner` ([finance_screen.dart:485][fs-nudge]) remains the single
  place the app asks for missing documents.

---

## Part 5 — DocuMind retrieval failure (fixes 4)

### 5.1 Why this part is diagnosis-first

The handler catches **every** exception and reports all of them as a vector-index
problem, printing the real cause only to stdout
([ask_orchestrator.py:462-476][ao-catch]):

```python
except Exception as e:
    print(f"❌ Hybrid retrieval failed: {e}")
    return AskResponse(
        answer="I couldn't search your documents. Please check your Firestore vector index.",
```

The reported symptom therefore identifies almost nothing. No fix is specified
here until the actual exception is captured.

### 5.2 Candidate causes, most likely first

1. **Missing composite index.** Adding a `category` filter changes the required
   Firestore index shape ([retriever.py:74-85][ret-filter]). "When is the
   tenancy agreement ended" predicts category `lease`, so the filtered query
   needs an index the unfiltered one does not — consistent with other questions
   working. Would surface as `FailedPrecondition` carrying an index-creation URL.
2. **Embeddings provider unreachable.** `embed_query` ([retriever.py:47][ret-embed])
   throws if the local Ollama server is not running (this project embeds locally
   with `nomic-embed-text`).
3. **`KeyError` on a chunk** missing `doc_id` / `filename` / `text`
   ([retriever.py:95-101][ret-keys]) — these are unguarded subscripts, unlike
   the `.get()` calls beside them.
4. **CrossEncoder load failure** ([retriever.py:24][ret-ce]) when the model is
   not cached and the machine is offline.

### 5.3 Method

1. Start the backend, ask the failing question against the real property,
   capture the exception and traceback.
2. Fix that cause.
3. Confirm the same question returns a cited answer from the uploaded agreement.

### 5.4 Unconditional improvement

Independent of the root cause, the handler is split so the three failure classes
are distinguishable, because today they are not:

| Cause | Landlord-facing message |
|---|---|
| Index / `FailedPrecondition` | "Your document search index is still building. Try again in a minute." |
| Embeddings or reranker unavailable | "Document search is temporarily unavailable. Please try again shortly." |
| Anything else | "Something went wrong searching your documents." |

All three log the exception type and a full traceback server-side.

---

## Testing

### Backend (`cd backend && python -m pytest -q` — 476 passing baseline)

- `test_finance_engine.py` — ownership-share cases extended to assert **every**
  field is scaled and none is scaled twice; a `share == 1.0` case asserting
  figures are byte-identical to today (regression guard on the choke point).
- New: synthetic whole-property scope carries `lines_by_unit[None]` — asserted
  for a no-units property and for a property where units and property-wide
  income coexist.
- New: totals are unchanged by the above (no double-count).
- New: property block exposes `landlord_expenses`, and
  `received − landlord_expenses == net_pl` at both levels.
- If §2.4 is accepted: property blocks sum to the Finance-tab statutory total.
- `_loan_completeness` tests unchanged (cadence semantics are untouched).

### Flutter (`cd residex_app && flutter test` — 211 passing + 1 known failure)

The known failure is `widget_test.dart` "Counter increments" — template
boilerplate referencing a `MyApp` counter this app does not have. Pre-existing
and unrelated; it must still be the *only* failure at the end.

- `finance_screen_test.dart` — new labels; `EXPENSES` renders
  `landlordExpenses`; coverage strip absent; nudge still present; loan button
  no longer gated on `loanInputMethod`.
- `unit_finance_detail_test.dart` — dropdown titles and roll-up captions.
- `add_property_dialog_loan_prefs_test.dart` — loan method/cadence selectors
  gone, mortgage selector retained.
- New: loan scope options by `structureType` (all four rows of §3.2).
- New: cadence prompt appears on first manual entry, not on subsequent ones.
- New: property-level expenses section renders `propertyExpenseLines`.
- New: share provenance text appears at `share < 1.0` and is absent at `1.0`.

### Manual, on device

- Enter a loan figure on a landed property and on a strata unit; confirm each
  appears in the right drill-down and in Net Profit/Loss.
- A co-owned property: confirm every level reads at share and the levels
  reconcile.
- Ask the failing DocuMind question and confirm a cited answer.

---

## Sequencing

Part 5 is independent of Parts 1–4 (backend retrieval vs. finance display) and
can proceed in parallel. Within the finance work:

1. **Part 1** (share choke point) — touches the most engine surface; land first
   so later parts build on final numbers.
2. **Part 2.3** (`landlord_expenses` per property) — engine field the UI needs.
3. **Part 3.1a** (synthetic scope lines) — small engine fix, independent.
4. **Parts 2.1/2.2, 3.6, 4** — UI-only, safe to parallelise once the engine
   fields exist.
5. **Parts 3.2–3.5** (loan UX) — the largest UI change; last.
6. **Part 2.4** — only if the reviewer accepts it.

## Out of scope

- Pro-rating property-level expenses into units (§3.6).
- Removing `loan_input_method` from the data model — retired as a gate only.
- Any phase-2 production-hardening item.
- The pre-existing `widget_test.dart` boilerplate failure.

[fe-share]: ../../../backend/rag/finance/finance_engine.py#L1146-L1153
[fe-floor]: ../../../backend/rag/finance/finance_engine.py#L1230-L1232
[fe-unitlines]: ../../../backend/rag/finance/finance_engine.py#L1044-L1047
[fe-totals]: ../../../backend/rag/finance/finance_engine.py#L1201-L1205
[fe-landlordpaid]: ../../../backend/rag/finance/finance_engine.py#L1109
[fe-cadence]: ../../../backend/rag/finance/finance_engine.py#L916-L918
[fe-propexp]: ../../../backend/rag/finance/finance_engine.py#L1220
[fs-caption]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L407-L411
[fs-chip]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L336-L349
[fs-received]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L359
[fs-expenses]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L360
[fs-netpl]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L369
[fs-statutory]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L391
[fs-strip]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L269-L313
[fs-stripcall]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L353-L356
[fs-nudge]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L485-L502
[fs-loanbtn]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L420-L445
[fs-unavail]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L504-L527
[fs-yearbtn]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart#L109-L114
[fsp-hero]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/finance_summary_panel.dart#L123
[fsp-received]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/finance_summary_panel.dart#L43
[fsp-expenses]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/finance_summary_panel.dart#L48
[fsp-statutory]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/finance_summary_panel.dart#L244-L247
[ufd-net]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart#L179
[ufd-stat]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart#L194
[ufd-deductible]: ../../../residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart#L197
[apd-loan]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart#L636-L680
[apd-mortgage]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart#L605-L634
[mles-month]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart#L203-L219
[unit-doc]: ../../../residex_app/lib/features/landlord/domain/entities/unit.dart#L5-L8
[dc-loan]: ../../../residex_app/lib/features/landlord/presentation/widgets/common/document_categories.dart#L14
[fsum-propexp]: ../../../residex_app/lib/features/landlord/domain/entities/finance_summary.dart#L58
[ao-catch]: ../../../backend/rag/ask/ask_orchestrator.py#L462-L476
[ret-filter]: ../../../backend/rag/ask/retriever.py#L74-L85
[ret-embed]: ../../../backend/rag/ask/retriever.py#L47
[ret-keys]: ../../../backend/rag/ask/retriever.py#L95-L101
[ret-ce]: ../../../backend/rag/ask/retriever.py#L24
