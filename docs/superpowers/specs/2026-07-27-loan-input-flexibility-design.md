# Loan-Input Flexibility (cadence + method, with manual entry)

Date: 2026-07-27
Branch: `feat/finance-tab-restructure`
Status: Design — awaiting user review
Builds on: `2026-07-27-two-tier-expense-model-design.md` (loan interest = deductible; loan principal = Net-P/L-only)

## Problem

Landlords get their loan figures from the bank on different rhythms and in
different forms — some receive a monthly instalment slip (principal + interest +
total), some only a year-end interest statement, and some have neither handy and
would rather type the numbers in. Today the only way loan interest/principal
reaches the finance engine is by uploading a document the OCR + fact extractor
can read. There is no way to say "I'll enter these by hand" or to record the
cadence the landlord actually operates on.

## Chosen approach

Two per-property preferences, plus a manual-entry path that feeds the SAME loan
pipeline the two-tier model already built. Nothing about the loan math changes —
a manual entry becomes ordinary loan facts, so `_line_deductible` /
`_line_paid_by_landlord`, the `loan_principal` line, the doc-id dedup, and Net
P/L all apply unchanged.

### Preferences (on `Property`)

Shown in the add/edit-property dialog ONLY when the mortgage question is "Yes"
(`hasMortgage == true`); editable later through the same dialog. Serialized like
`has_mortgage` / `utilities_paid_by`:

- `loanInputCadence` — `'monthly' | 'annual'` (wire: `loan_input_cadence`).
- `loanInputMethod` — `'upload' | 'manual'` (wire: `loan_input_method`).

Defaults when mortgage = Yes but unanswered: method `upload`, cadence `annual`
(least-effort baseline; the upload path already works with zero extra input).
When `hasMortgage != true`, the preferences are hidden and ignored.

### Upload method

The existing document flow — no new work. The two-tier loan pipeline already
extracts `interest_paid` / `principal_paid` / `period_year` from monthly or
annual statements and sums distinct statements across the year (doc-id
discriminator). Cadence is informational for this method.

### Manual method

The landlord types interest + principal per period. Cadence shapes the form:
`annual` = one interest + one principal figure per year; `monthly` = a figure per
month. Each entry persists as a synthetic loan record (modeled on
`record_rent_recovery` / `set_document_unavailable`) and is fed into the engine
as a loan fact.

## Components & changes

### 1. Property entity/model (frontend + wire)
- `Property` / `PropertyModel`: add `loanInputCadence` (String?, default null) and
  `loanInputMethod` (String?, default null), through the entity, `copyWith`,
  `fromJson` (`loan_input_cadence` / `loan_input_method`), `toJson`.

### 2. Registration/edit UI (`add_property_dialog.dart`)
- When `_hasMortgage == true`, reveal two chip selectors beneath the mortgage
  selector: cadence (Monthly / Annual) and method (Upload statements / Enter
  manually), following the existing `AppChoiceChip` pattern. Persist both on
  save. Hidden/cleared when mortgage is not "Yes".

### 3. Backend manual-loan record (`documind_service.py`)
- New Firestore collection `documind_manual_loan_entries`. Deterministic doc_id:
  `{property_id}__{year}` (annual) or `{property_id}__{year}__{month:02d}`
  (monthly). Record: `{landlord_id, property_id, year, month?, interest_paid,
  principal_paid, cadence, updated_at}`. Ownership-validated against the property
  (same guard as `record_rent_recovery`). Idempotent set (re-entering the same
  period overwrites).
- Methods: `record_manual_loan_entry(...)`, `delete_manual_loan_entry(...)`,
  and read all entries for a landlord in `get_finance_summary`.

### 4. API (`rex_routes.py` + `documind_models.py`)
- `PUT /documind/finance/manual-loan-entry` (upsert) and
  `DELETE /documind/finance/manual-loan-entry` (or a `remove` flag), mirroring the
  `document-exception` route shape. Pydantic request/response models with
  validation: amounts ≥ 0; `month` required iff cadence monthly, 1–12; year
  sane.

### 5. Engine integration (`finance_engine.py`)
- `compute_finance_summary` gains a `manual_loan_entries` param (default `[]`),
  read and passed by `get_finance_summary` alongside `document_exceptions` /
  `rent_recoveries`.
- Each manual entry for the summary's year is turned into loan expense line(s):
  an interest line (`subtype` treated as loan interest → deductible=True,
  paid_by_landlord=True) and, when `principal_paid` present/non-zero, a
  `loan_principal` line (deductible=False, paid_by_landlord=True) — reusing the
  existing helpers so classification stays single-sourced. Keyed so a manual
  entry and an uploaded statement for the same period do not silently merge
  (manual entries carry a synthetic `doc_id` like `manual__{property}__{period}`,
  which the doc-id-discriminated loan dedup keeps distinct).
- A property should not double-count: if the method is `manual`, manual entries
  are the loan source; uploaded loan statements still count if present (the
  landlord can mix), and dedup prevents exact duplicates. (No hard exclusion —
  distinct sources sum, matching the two-tier "sum across statements" intent.)

### 6. Finance-tab manual-entry UI (frontend)
- On the property's finance view, when `loanInputMethod == 'manual'`, a
  dedicated "Add loan figures" action opens a small form: pick period (year, or
  year+month per cadence), enter interest + principal, save → calls the upsert
  endpoint → refreshes the summary. Existing entries are listed with edit/remove.
- No emojis; follows existing finance-tab widget/style patterns.

## Data flow

Registration → preferences stored on the property. Manual method → landlord books
interest/principal per period via the finance-tab form → upsert endpoint →
`documind_manual_loan_entries`. Read time: `get_finance_summary` loads documents +
exceptions + recoveries + manual loan entries → `compute_finance_summary` turns
manual entries into loan lines alongside extracted loan facts → existing two-tier
math, dedup, Net P/L, statutory. Upload method is unchanged.

## Error handling / edge cases
- Amounts default/clamp to ≥ 0; a zero principal emits no principal line.
- Monthly entry requires a valid month; annual entry ignores month.
- Editing a period overwrites (idempotent); removing deletes the record.
- Mixing upload + manual in one year: distinct sources sum; identical
  (period, amount) exact duplicates collapse via existing dedup — the landlord
  can remove a wrong one.
- `hasMortgage` later set to No: preferences hidden; existing manual entries are
  retained but the UI entry point is gone (they can be removed). Not deleted
  automatically (avoids silent data loss).

## Testing (TDD)
- Backend: manual-entry record upsert/delete + ownership guard + idempotency;
  engine turns a manual entry into interest + principal lines with correct
  two-tier flags; manual + uploaded distinct sources sum; monthly vs annual
  keying; zero principal emits no line.
- API: PUT/DELETE endpoints validate (month required for monthly, amount ≥ 0) and
  round-trip.
- Frontend: property entity parses/serializes the two prefs; dialog reveals the
  selectors only when mortgage=Yes and persists them; finance-tab form calls the
  upsert action and lists/edits/removes entries.

## Out of scope
- Amortization schedules / computing interest vs principal from a rate.
- Changing the OCR/extraction model or the upload flow.
- Auto-reminders/notifications for the chosen cadence (cadence only shapes the
  form + expectation here).

## Resolved decisions (user, 2026-07-27)
- Build the FULL feature now, including the manual-entry pipeline.
- Manual figures are entered from a dedicated Finance-tab entry point (registration
  sets only the preference).
- Preferences live on the property, revealed when mortgage = Yes, editable later.
