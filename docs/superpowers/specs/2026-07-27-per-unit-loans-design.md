# Per-Unit Loans + Loan Document Folder

Date: 2026-07-27
Branch: `feat/finance-tab-restructure`
Status: Design — awaiting user review
Builds on: `2026-07-27-loan-input-flexibility-design.md` (manual loan entry, property-level)

## Problem

The manual loan-entry feature just shipped treats loan figures as
property-level. In reality each unit has its own loan (own account number, loan
amount, monthly payment schedule), so interest/principal should attribute to a
specific unit and land in that unit's Net P/L and statutory income — not a
property-wide bucket. Two follow-on needs surfaced:

1. The "Add loan figures" entry point should not linger forever. It should show
   only while the viewed year's loan figures are still incomplete, and must
   gracefully handle units that legitimately have no loan (owned outright).
2. Loan documents currently fall into the generic "Expenses" folder in the
   Documents tab (their tags are one-off, so they get no folder identity). The
   landlord wants loan documents in their own "Loan" folder.

## Chosen approach

Three parts, each building on existing pipelines. Nothing about the two-tier
loan math (interest = deductible + landlord-paid; principal = landlord-paid
only) changes — this adds a `unit_id` dimension, a per-unit "no loan"
acknowledgment that drives button visibility, and a display-only folder tweak.

### Part A — Per-unit attribution

A manual loan entry gains a `unit_id`. The finance engine already routes any
expense line carrying a `unit_id` into that unit's `contribution` (Net P/L
basis) and `statutory_contribution`, so once the synthetic loan document carries
the unit, the money lands in the right place with no engine-math changes.

- Firestore doc_id: `{property_id}__{unit_id}__{year}` / `…__{month:02d}` for a
  unit; **unchanged** `{property_id}__{year}[__mm]` when `unit_id` is null
  (whole-property, building-wide loan) — so existing entries stay valid.
- Engine synthetic loan-doc doc_id: `manual__{property}__{unit_id}__{period}`
  (whole-property keeps `manual__{property}__{period}`). This unit segment is
  required: the loan dedup keys on doc_id, so without it two units with the same
  period + amount would collapse into one line.

### Part B — Per-unit completeness, "No loan here", and button gating

The system never infers whether a unit has a loan — the landlord declares it.
A unit is **resolved** for a viewed year when it either has loan figures for
that year or is marked "no loan"; the "Add loan figures" button shows only
while some unit is unresolved.

- **"No loan here" mark:** a per-unit acknowledgment (a unit either carries a
  loan or it doesn't — the mark is not per-year). Stored as a synthetic record
  modeled on the manual-entry / document-exception pattern: collection
  `documind_unit_loan_exemptions`, doc_id `{property_id}__{unit_id}`, record
  `{landlord_id, property_id, unit_id}`, ownership-validated, idempotent.
  Methods `set_unit_loan_exemption` / `clear_unit_loan_exemption`, read in
  `get_finance_summary`.
- **Completeness rule (per property, per viewed year Y), computed in the
  engine** — the app never recomputes, so the backend decides and exposes it:
  - "Has loan figures" counts a loan line from **any source** — a manual entry
    or an uploaded loan statement assigned to that unit both resolve it.
  - For each real unit: **resolved** if marked no-loan, OR it has loan figures
    for Y — for **annual** cadence, at least one loan line for Y; for
    **monthly** cadence, a loan entry for every month in scope (Jan..Dec for a
    past year, Jan..current-month for the current year).
  - **Property with units:** loan-incomplete if any real unit is unresolved; the
    whole-property scope (unit_id null) is an *optional* extra for a
    building-wide loan and is not itself required for completeness.
  - **Property with no units (single-let / house):** the whole-property scope is
    the only scope; loan-incomplete until it has figures for Y. ("No loan here"
    is a per-unit action and does not apply here — a mortgaged single-let is
    expected to have loan figures.)
  - Only evaluated for a property with `has_mortgage == true` and
    `loan_input_method == 'manual'`; otherwise there is no manual button and the
    flag is false.
- **Backend surface:** `_list_landlord_properties` starts returning
  `loan_input_cadence` / `loan_input_method` (currently omitted) so the engine
  can be cadence-aware. `compute_finance_summary` adds, per property block, a
  `manual_loan_incomplete: bool` (for the viewed year) and, per unit block, a
  `loan_status` ∈ `"complete" | "incomplete" | "no_loan"` for display.
- **Frontend gating:** the property-block "Add loan figures" button is shown
  when `hasMortgage == true && loanInputMethod == 'manual' && manualLoanIncomplete`.
  (Supersedes the current gate, which was `hasMortgage && method == manual`.)

### Part C — Loan document folder

Display-only. In `document_folders.dart`, `folderKeyFor` gives a
loan-category document a dedicated folder key (a `loanFolderKey` sentinel)
instead of letting it fall through to `untaggedFolderKey`; `proposedFolderName`
maps that key to **"Loan"**. Loan-ness is detected from the document's
`category == 'loan'` (the frontend `DocuMindDocument` already carries
`category`). Finance is untouched — folders are derived from tags/category for
*display* only; `finance_engine.py` reads documents by `category` +
`extracted_facts` and never looks at folders, so P/L and statutory are
unaffected.

## Components & changes

### Backend
1. `documind_service.py`
   - `record_manual_loan_entry` / `delete_manual_loan_entry` gain
     `unit_id: Optional[str] = None`; doc_id includes the unit segment as above;
     record stores `unit_id`. `list_manual_loan_entries` returns `unit_id`.
   - New `set_unit_loan_exemption` / `clear_unit_loan_exemption` +
     `_unit_loan_exemption_doc_id`; read the collection in `get_finance_summary`
     and pass to the engine.
   - `_list_landlord_properties` adds `loan_input_cadence`, `loan_input_method`.
2. `finance_engine.py`
   - `_manual_loan_documents` sets `unit_id` from the entry and the unit-scoped
     synthetic doc_id.
   - `compute_finance_summary` gains a `unit_loan_exemptions` param; computes
     per-unit `loan_status` and per-property `manual_loan_incomplete` for the
     year (cadence-aware); includes them in the output blocks.
3. `documind_models.py` — `ManualLoanEntryRequest`/`Response` gain optional
   `unit_id`; `UnitFinance` gains `loan_status`; `PropertyFinance` gains
   `manual_loan_incomplete`. New request models for the exemption endpoints.
4. `rex_routes.py` — manual-loan PUT/DELETE carry `unit_id`; new
   `PUT`/`DELETE /documind/finance/unit-loan-exemption`.

### Frontend
5. Datasource/providers — `recordManualLoanEntry`/`deleteManualLoanEntry` gain
   `unitId`; new `setUnitLoanExemption`/`clearUnitLoanExemption` + action
   providers (invalidate `financeSummaryProvider`). `FinanceSummary` parsing
   gains `loanStatus` / `manualLoanIncomplete`.
6. `manual_loan_entry_sheet.dart` — lists every unit for the year with its
   `loan_status`; unresolved units show the interest/principal fields + a
   "No loan here" action; resolved units show their figures (with remove) or a
   "No loan" chip (with undo); a "Whole property" scope for a building-wide
   loan. Save/remove/mark call the matching providers with `unit_id`.
7. `finance_screen.dart` — gate the "Add loan figures" button on
   `manualLoanIncomplete` (plus the existing mortgage/method conditions).
8. `document_folders.dart` — the Loan folder (Part C).

## Data flow

Manual save → per-unit entry persisted with `unit_id` → `get_finance_summary`
loads entries + unit-loan exemptions → `compute_finance_summary` turns entries
into unit-scoped loan lines (existing two-tier math), and computes each unit's
`loan_status` + the property's `manual_loan_incomplete` for the year → frontend
shows the button only while incomplete, and the sheet reflects each unit's
status. Uploaded loan statements attribute per-unit via the existing
document→unit assignment and are surfaced by the existing coverage grid — no new
upload affordance. Folders are recomputed on the frontend from category/tags for
display; finance ignores them.

## Error handling / edge cases

- A unit both marked no-loan and given figures: figures win for the money
  (they're real lines); `loan_status` reports `complete`. Marking is an
  intent signal for gating, not a filter on real data.
- Single-unit / house properties (no units): no unit picker; the whole-property
  scope is the only one; completeness uses that scope.
- Monthly cadence, current (partial) year: only months up to the current month
  are required for `complete`.
- Turning a unit's no-loan mark off re-opens it (button can reappear).
- Existing property-level manual entries (pre-this-change) remain whole-property
  and continue to work.
- Exemptions and entries are ownership-validated against the property's
  `landlordId`; a stale `unit_id` never crosses landlords.

## Testing (TDD)

- Engine: a unit-scoped manual entry lands in that unit's contribution +
  statutory (not the property bucket); two units same period+amount stay
  distinct; `manual_loan_incomplete` true when a unit is unresolved, false when
  every unit has figures or is exempt; monthly cadence requires all in-scope
  months; a no-loan-marked unit is resolved with no figures.
- Service/API: entry upsert/delete with `unit_id`; exemption set/clear +
  ownership + idempotency; `_list_landlord_properties` returns the two prefs.
- Frontend: sheet renders per-unit rows with status, Save/mark/undo call the
  right providers with `unit_id`; button hidden when `manualLoanIncomplete`
  is false; loan document lands in the "Loan" folder, not "Expenses".

## Out of scope

- Loan account numbers, original loan amount, amortization schedules (still
  out — this is attribution + completeness only).
- Per-unit `hasMortgage` as a stored property field (the "no loan" mark covers
  the need without new schema on the unit).
- Changing OCR/extraction or the upload flow; changing how uploaded loan
  statements attribute (document→unit assignment already handles it).
- Inferring no-loan units from the absence of entries (explicitly rejected —
  absence is ambiguous).

## Resolved decisions (user, 2026-07-27)

- Scope = unit attribution only (no account number / amortization).
- Units without loans handled by an **explicit** per-unit "No loan here" mark,
  not inference.
- Button visibility = per viewed year; monthly cadence requires all in-scope
  months.
- Upload method needs no new entry point (coverage grid + document→unit
  assignment already cover it).
- Loan folder is display-only and does not affect P/L or statutory.
