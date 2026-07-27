# Two-Tier Expense Accounting (Overall Net P/L vs. LHDN Statutory)

Date: 2026-07-27
Branch: `feat/finance-tab-restructure`
Status: Design — awaiting user review

## Problem

The finance engine classifies every expense line with a single boolean,
`deductible`, and **both** headline figures are computed from it:

- `finance_engine.compute_finance_summary` → `statutory_sum` and `net_pl`
  both subtract only `deductible` lines
  ([finance_engine.py:949-1001](../../../backend/rag/finance_engine.py)).

That conflates two different questions:

1. **Did the landlord actually pay this?** (drives *Overall Net P/L* — the
   landlord's real cash position)
2. **Does LHDN allow it as a deduction against rental income?** (drives
   *Statutory Rental Income*, s.4(d), Public Ruling 12/2018)

Consequences observed by the user:

- **Net P/L understates cost.** Landlord-paid-but-non-deductible outflows —
  loan **principal**, **late-payment penalties**, capital/renovation,
  first-letting costs — are excluded from Net P/L, though the landlord bore
  them.
- **Loan principal is not tracked at all** as a paid amount (only the loan
  *agreement's* original `principal`, and the statement's `interest_paid`,
  exist).
- **Fire insurance is double-counted.** An annual premium that appears as a
  line on both the JAN and FEB monthly statements has two different dates, so
  the exact-line dedup (`_dedup_expense_lines`, keyed partly on `date`) does
  not collapse it → counted twice.
- **No way to remove a bad extracted line** (a spotted duplicate, or a penalty
  the management later waived) from the review panel.
- **Statutory label** does not distinguish a provisional ("current") estimate
  from a settled one, and gives no per-property breakdown.

## LHDN basis (Public Ruling 12/2018, s.33(1) ITA)

Deductible against s.4(d) rental income: assessment tax, quit/parcel rent,
loan **interest** (not principal), fire insurance, genuine repairs &
maintenance (not improvements), maintenance fee & sinking fund, property
management fees, rent-collection legal/stamp, pest control, and **renewal**
agent commission/legal.

Not deductible: loan **principal**, first-letting costs (advertising, initial
legal, first-tenant agent commission), renovation/improvement/capital,
penalties/fines, depreciation, furniture.

Sources:
- <https://www.propertyguru.com.my/property-guides/rental-income-exempted-income-tax-malaysia-11868>
- <https://speedhome.com/blog/are-repairs-tax-deductible-in-malaysia/>
- <https://taxpod.com.my/articles/rental-income-tax/>

## Chosen approach: two independent flags per expense line

Each expense line carries two booleans (Approach A, user-approved):

- `paid_by_landlord` — the line is a cash outflow the landlord bears → feeds
  **Overall Net P/L**.
- `statutory_deductible` — LHDN allows it → feeds **Statutory Rental Income**.
  (This is today's `deductible`, renamed for clarity and kept backward
  compatible on the wire.)

They are orthogonal: a penalty is `paid_by_landlord=True,
statutory_deductible=False`; tenant-paid utilities are `False, False` (not the
landlord's cost at all); maintenance is `True, True`.

### Classification table (single source of truth)

| subtype / case | paid_by_landlord | statutory_deductible |
|---|---|---|
| maintenance, sinking_fund, management_fee, rent_collection, security_fee | ✓ | ✓ |
| assessment_tax, quit_rent, parcel_rent | ✓ | ✓ |
| insurance_premium (fire) | ✓ | ✓ |
| loan_interest | ✓ | ✓ |
| upkeep (genuine repair) | ✓ | ✓ |
| **loan_principal** | ✓ | ✗ |
| **late_penalty** | ✓ | ✗ |
| renovation / capital | ✓ | ✗ |
| first-letting (agent_commission, legal_fee, stamp_duty, advertising) — no renewal on file | ✓ | ✗ |
| first-letting — renewal on file for the year | ✓ | ✓ |
| utilities — `utilities_paid_by == "landlord"` | ✓ | ✓ |
| utilities — tenant pays (default) | ✗ | ✗ |

Derivation lives in `fact_extractor` alongside the existing
`NEVER_DEDUCTIBLE_SUBTYPES` / `LANDLORD_BORNE_SUBTYPES` / `RENEWAL_ONLY_SUBTYPES`
sets. `finance_engine._line_deductible` is joined by a sibling
`_line_paid_by_landlord`; each line gets both flags.

## Components & changes

### 1. Backend model / classification (`fact_extractor.py` + `finance_engine.py`)
- Introduce `_line_paid_by_landlord(subtype, utilities_paid_by)` beside the
  existing `_line_deductible`. Only tenant-paid utilities return False
  (`subtype in LANDLORD_BORNE_SUBTYPES and utilities_paid_by != "landlord"`);
  every other billed subtype — penalties, principal, capital, first-letting —
  is landlord cash out → True.
- No change to the LHDN set logic; `statutory_deductible` is exactly today's
  `_line_deductible` output, just renamed on the line dict.

### 2. Engine (`finance_engine.py`)
- `_expense_lines` sets both `paid_by_landlord` and `statutory_deductible` on
  every line (both typed and bundled paths).
- `_dedup_expense_lines`: add an **annual-collapse** rule for annual-cadence
  subtypes (`insurance_premium`, `quit_rent`, `parcel_rent`) — key them on
  `(unit_id, subtype, amount, year)` (year derived from date/period_year),
  ignoring the specific month, so the same premium on several monthly
  statements collapses to one. All other subtypes keep the existing
  exact-line key (installments stay separate).
- Totals:
  - `net_pl` (portfolio) = Σ received − Σ`paid_by_landlord`.
  - `statutory_rental_income` = Σ (complete properties) share·(received −
    prorated `statutory_deductible`); loss floor unchanged.
  - Per property block: add `net_pl` (received − landlord-paid) and
    `statutory_contribution` (received − statutory-deductible, or null when
    the property's year is incomplete).
- `expense_breakdown` continues to reflect statutory-deductible lines (tax
  view); add a parallel note or field only if the UI needs the landlord-paid
  breakdown (see Presentation).

### 3. Loan principal (`fact_extractor.py` + engine)
- Loan `interest_statement` extraction gains `principal_paid` ("principal
  portion paid in the statement period"), coerced as an amount.
- `_expense_lines` loan branch emits a second line `loan_principal` (amount =
  `principal_paid`, `paid_by_landlord=True`, `statutory_deductible=False`,
  dated by `period_year`) when present.
- Frequent uploads: each statement's `period_year` allocates its interest and
  principal to that year; multiple statements in a year sum naturally (same as
  interest does now).

### 4. API models (`documind_models.py`)
- `ExpenseLine`-shaped response gains `paid_by_landlord`; keep `deductible`
  on the wire (alias of `statutory_deductible`) for compatibility.
- `FinanceTotals`: add nothing new required, but property blocks expose
  `net_pl` and `statutory_contribution`.

### 5. Frontend entities/models (`finance_summary.dart` + model)
- `ExpenseLine`: add `paidByLandlord` (default true); keep `deductible`.
- `PropertyFinance`: add `netPl`, `statutoryContribution` (nullable).
- `FinanceTotals` already has `netPl`, `statutoryRentalIncome`,
  `statutoryNote`.

### 6. Presentation (`finance_screen.dart` + `unit_finance_detail_screen.dart` + `finance_logic.dart`)
- Dashboard shows both headline figures with correct sets: Net P/L (all
  landlord-paid) and Statutory (LHDN).
- Statutory label: "Current Statutory Rental Income" when any contributing
  property's year is incomplete, else the settled label. Per-property
  statutory contribution listed.
- **Per-unit accordion switches to the Net P/L basis** (user decision): the
  headline "net contribution" = gross − Σ`paid_by_landlord` (so principal,
  penalties, capital now reduce it). `landlordPaidExpenseTotal` is the
  accordion's "Direct expenses" total.
- **Add a second "Contributing statutory income" block** inside the same
  accordion: gross − Σ`statutory_deductible`, with its own list of the
  deductible expense lines that feed it. So the landlord sees both their real
  cash position (Net P/L) and the LHDN-deductible subset that drives tax, side
  by side, each with its own itemised expenses.
- `finance_logic`: `deductibleExpenseTotal` (statutory, already shipped) gains
  a sibling `landlordPaidExpenseTotal`. Excluded-line marking (already
  shipped) distinguishes "not deductible (still your cost)" — which now DOES
  count toward Net P/L — from "tenant pays — not your cost" — excluded from
  both.

### 7. Review panel — remove a line (`expense_lines_review_sheet.dart`)
- Add a per-row delete affordance; removing sets `_dirty` and drops the line
  from `_lines`. Existing `updateExpenseLines` PATCH already replaces the full
  list, so **no new endpoint**.
- Widen the type dropdown (`expenseSubtypeLabels`) to include `late_penalty`,
  `utilities`, `renovation`, `loan_principal`, so a waived penalty / spotted
  duplicate is editable and removable on the spot.
- Guard: confirm-before-delete for a single tap; empty list is allowed (means
  "none of these are real").

## Data flow

Upload → OCR → `fact_extractor` (assigns subtype + amounts; loan gains
`principal_paid`) → stored facts. Read time: `finance_engine._expense_lines`
builds lines with both flags → `_dedup_expense_lines` (annual-collapse) →
per-scope sums → `compute_finance_summary` totals (two figures) → API models →
Flutter entities → dashboard + accordion. Review panel edits/removes lines via
the existing facts PATCH, which re-runs the read path.

## Error handling / edge cases
- Missing `principal_paid` → no principal line (interest still counted).
- Annual-collapse must not merge two genuinely distinct policies; the
  `(subtype, amount, year)` key keeps different amounts separate, and the user
  can remove a false merge in the review panel.
- Tenant-paid utilities excluded from both figures (unchanged from the shipped
  fix) — verified by the invariant `gross − landlordPaidTotal == net
  contribution`-style checks.
- Incomplete properties excluded from statutory (as today) and surfaced by the
  "Current" label.

## Testing (TDD)
- `fact_extractor`: `principal_paid` coercion; `_line_paid_by_landlord`
  table (penalty/principal/capital = paid-not-deductible; tenant utility =
  neither).
- `finance_engine`: net_pl includes principal+penalty; statutory excludes
  them; annual-collapse removes the fire-insurance double count; per-property
  `net_pl` / `statutory_contribution`; loss floor still statutory-only.
- Flutter: `landlordPaidExpenseTotal`; statutory "Current" vs settled label;
  review-panel delete removes a line and saves the shorter list; widened
  dropdown.

## Out of scope
- Depreciation / capital allowances, furniture, e-invoicing.
- Changing the OCR/extraction model.
- Multi-currency.

## Resolved decisions (user, 2026-07-27)
- **Per-unit accordion → Net P/L basis**, and additionally show a
  "Contributing statutory income" block with its own deductible-expense list
  (see Presentation §6). Both figures visible per unit/property.
- **Loan documents vary** — both annual interest statements and monthly
  instalment slips occur. `interest_paid` and `principal_paid` are allocated
  to the statement's `period_year` and summed across however many statements a
  year has; no assumption of one-per-year.
