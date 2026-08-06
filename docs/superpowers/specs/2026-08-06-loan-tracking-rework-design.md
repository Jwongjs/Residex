# Loan tracking rework: drop the entry-method fork, unscale loans, add settlement

**Date:** 2026-08-06
**Status:** Approved design, ready for implementation planning
**Supersedes:** parts of `2026-08-05-loan-entry-method-design.md` (§1 partially, §2, §3, §5 gate)

## Problem

Four separate faults, surfaced while reviewing the loan-entry-method workstream.

**1. The entry-method fork was the wrong answer.** That workstream made "upload
statements or type the figures?" a property-level choice, hid the Loans &
Financing folder in manual mode, and gated the finance panel's loan row on
`loanInputMethod == 'manual'`. The result is a fork that has to be answered
before either route works, and a documented dead end: every existing property
has `loanInputMethod == null`, so a mortgaged property today has *no* route to
manual loan entry at all. Both routes should simply always exist — upload to the
folder, or type at the property panel.

**2. Loan interest and principal are scaled by ownership share.** Expense
amounts pass through a single per-property choke point
(`finance_engine.py:1179-1190`) that multiplies everything by
`ownership_share`. A landlord owning 50% who is the sole borrower on the
mortgage sees half their loan interest in Direct Expenses, statutory and net
P&L. The mortgage is the landlord's own borrowing, not a cost shared with
co-owners.

**3. "Not sure" silently does nothing on edit.** `structureType`,
`trackFromYear` and `hasMortgage` each have a "Not sure" chip that sets state to
`null`, but the edit-mode save coalesces every one with `?? existing.field`
(`add_property_dialog.dart:154-166`). Tapping "Not sure" on an already-answered
property is a no-op. Separately, "Not sure" does not describe anything a
property owner would say about their own mortgage.

**4. There is no way to say the mortgage is paid off.** A landlord who settles
their mortgage is nudged for loan documents forever. Answering "No" is not the
same thing — "No" means *never had one* and retroactively stops expecting loan
figures for every historical year, corrupting past reconciliation.

## Goals

1. Both loan routes permanently available, with no question gating either.
2. Loan interest and principal never scaled by ownership share.
3. "Not sure" either works or does not exist.
4. A landlord can record when their mortgage was settled, and stop being nudged
   from that point forward without losing history.

## Non-goals

- Not revisiting `loanInputCadence`.
- Not redesigning the manual-entry sheet or the loan figures block's layout —
  both were built in the previous workstream and are kept as-is except where
  named below.
- Not changing `Property.copyWith`'s null-coalescing. §3 is a call-site fix.
- Not touching upload behaviour for any other category.

---

## Design

### 1. Delete the `loanInputMethod` fork

The field is removed entirely rather than left dormant. A dead field that still
silently gates backend logic on a value nothing sets is the exact trap the
previous workstream spent thirteen commits escaping.

**Frontend**

| File | Change |
| --- | --- |
| `add_property_dialog.dart` | Remove `_loanInputMethod` (line 50), its seed from the existing property (86), the two-card question and its `_hasMortgage == true` wrapper (453), the card builder (~716), and the field from both the edit (169) and create (195) constructions |
| `documents_screen.dart:55` | Remove the `loanInputMethod == 'manual'` filter — Loans & Financing is always in the grid. The stale-selected-category fallback it guarded becomes dead code and goes with it |
| `finance_screen.dart:303-305` | Remove the missing-list filter. `'loan'` nudges like any other category |
| `finance_screen.dart:310-311` | Gate becomes `property?.hasMortgage == true` |
| `property.dart` | Remove the field from the entity, constructor, `copyWith`, `==`, `hashCode` |
| `property_model.dart` | Remove from `fromEntity` (23), `toEntity` (49), the named field (76), `fromJson` (114), `toJson` (155) |

The nudge never renders an "enter figures manually" affordance. `onEnterManually`
stays on `DocumentNudgeBanner` as a generic parameter; nothing passes it. The
panel row is the discoverable manual route, and the nudge stops mentioning loans
automatically once figures are booked by either route, because manual entries
already become loan expense lines that land in `contributing`
(`finance_engine.py:1200`).

**Backend**

- `finance_engine.py:911` → `if prop.get("has_mortgage") is not True: return False, {}`
- `property_directory.py:67` — remove the `loan_input_method` passthrough.

`_manual_loan_documents` (860) needs no change: it was never gated on the
method, so typed figures already reach the engine for any property.

**Expected consequence.** Loan-completeness tracking now applies to every
mortgaged property, not just manual-method ones. Mortgaged upload-mode
properties can newly show the incomplete-statutory caveat and the completeness
sub-line. This is intended — it is correct behaviour those properties never
received — but it is new output on existing data and should be called out in
testing.

### 2. Loan interest and principal are never scaled by ownership share

One rule, applied at every point `share` multiplies an expense-derived quantity:

```python
_LOAN_EXEMPT_SUBTYPES = {"loan_interest", "loan_principal"}


def _line_share(line: Dict[str, Any], share: float) -> float:
    """Loan interest and principal are the landlord's own borrowing, not a cost
    shared with co-owners, so they are never scaled by ownership share. Every
    other expense line scales normally."""
    return 1.0 if line.get("subtype") in _LOAN_EXEMPT_SUBTYPES else share
```

**All eight sites must change together.** The failure mode here is not a crash —
it is two totals on the same screen that quietly disagree. Missing one site
produces a Direct Expenses figure that does not reconcile against its own
expense-line breakdown.

| Site | Line | Change |
| --- | --- | --- |
| `_scaled_lines` | 427 | Keeps its `(lines, share)` signature and applies `_line_share` per line internally; `full_amount` is emitted only for lines actually scaled. The `share == 1.0` early return stays valid |
| unit `contribution` | 1106 | Income keeps `share *`; the `display_landlord_total` term becomes a per-line sum |
| unit `statutory_contribution` | 1109 | Same split against `display_deductible_total` |
| unit proration | 1074 | `unit_deductible_total` accumulates per-line-weighted |
| property-level proration | 1141 | Same, and `s_prorated` (1190) drops its `share *` |
| `landlord_paid` | 1147 | Accumulates per-line-weighted; `s_landlord_paid` (1189) drops its `share *` |
| `direct` | 1177 | Accumulates per-line-weighted; `s_direct` (1188) drops its `share *` |
| `expense_breakdown` | 1219 | `_line_share(line, share) * line["amount"]` |

`direct`, `landlord_paid` and `prorated_expenses` currently accumulate raw and
are scaled once at the end. They switch to accumulating already-weighted, and
the trailing `share *` is removed. **Income is unaffected** — `s_received`,
`s_derived` and `s_outstanding` keep scaling by `share` throughout. Only expense
lines go per-line.

**Copy that must change with it,** because both now overstate their reach:

- `finance_screen.dart:392-397` — "Shown at your 50% share" should say loan
  interest and principal are shown in full.
- `finance_engine.py:1213` `share_notes` — same, in the caveat text.

**Frontend figures row: no change.** `_buildLoanFiguresRow` already reads raw
booked entries rather than expense lines
(`finance_screen.dart:500-507`). That was a deliberate carve-out against
exactly this scaling; it now stops being a special case and simply agrees with
the engine.

**Observed but out of scope:** `excluded` (1222) sums non-deductible amounts
**unscaled** for its caveat note, while every other displayed figure is scaled.
`loan_principal` is non-deductible so it flows through here. This is a
pre-existing inconsistency, not introduced by this work, and is left alone
deliberately — do not "fix" it as part of this change without a separate
decision.

### 3. "Not sure" works, and leaves the mortgage question

**The mortgage question becomes Yes/No.** The "Not sure" chip
(`add_property_dialog.dart:657-661`) is removed. A property owner is not unsure
whether they have a mortgage; the option existed only because `null` was the
initial state. `structureType` and `trackFromYear` keep theirs — title type and
tracking start are real unknowns, and `trackFromYear`'s "Not sure" carries a
meaningful default.

Existing `null`-mortgage properties render with neither chip selected — an
honest "unanswered" — and the backend's conservative treatment of `null`
(`'loan'` stays expected, `finance_engine.py:717`) is untouched.

**Edit-mode save stops coalescing.** `structureType`, `trackFromYear` and
`hasMortgage` are written raw from state:

```dart
structureType: _selectedStructureType,
hasMortgage: _hasMortgage,
trackFromYear: _trackFromYear,
```

`initState` (83-85) already seeds all three from the existing property, so the
state variable *is* the landlord's current answer. The `?? existing.field`
coalescing could only ever undo a deliberate "Not sure". `effectiveHasMortgage`
(154) disappears with it, since the divergence it guarded against no longer
exists once `loanInputMethod` is gone.

**Yes → No raises a confirmation** when the property has booked loan figures for
the year:

> **Remove loan tracking for this property?**
> This property has RM 8,200 of 2026 loan figures recorded. They'll stay in your
> finance totals but will no longer be visible or editable.
> If your mortgage is fully repaid, mark it settled instead so your past years
> stay accurate.
> [Cancel] [Remove tracking]

Cancel restores Yes. The settled reference matters: "No" means never had one,
settlement means it ended, and pointing at the right tool is what stops
landlords from reaching for the destructive one.

### 4. Mortgage settlement

**Model.** One atomic field, `Property.mortgageSettledOn`, a `String?` in
`'YYYY-MM'` form — matching the period format `_manual_loan_documents` already
builds (`finance_engine.py:875`). Atomic rather than a year/month pair so it
cannot land half-set. Backend key `mortgage_settled_on`, carried through
`property_directory.py` beside the fields already there.

`hasMortgage` **stays `true`** on a settled property. The property did have a
mortgage; historical years must still expect and reconcile loan figures.

**The rule**, read by the whole engine from one place:

```python
def _loan_expected_for(
    prop: Dict[str, Any], year: int, month: Optional[int] = None
) -> bool:
    """Whether loan figures are expected for a period. A settled mortgage stops
    expecting them after its final month; history before it is unaffected.
    A malformed mortgage_settled_on is treated as unset — never silently
    suppress a year's expectation on unparseable data."""
    if prop.get("has_mortgage") is not True:
        return False
    settled = prop.get("mortgage_settled_on")
    if not settled:
        return True
    try:
        s_year, s_month = int(str(settled)[:4]), int(str(settled)[5:7])
    except (TypeError, ValueError):
        return True
    if year != s_year:
        return year < s_year
    return month is None or month <= s_month
```

**Call sites.** `_expected_categories` (706) is currently **year-agnostic** — it
takes only `prop` and feeds both the coverage grid (1150, which iterates years
internally) and the per-year `missing` list (1203). Making loan exclusion
year-aware means threading a year through it, or splitting the year-dependent
part out. This is the substantive work in this change and the plan must resolve
it explicitly rather than patching one caller.

`_loan_completeness` (897) must additionally:
- return resolved for years entirely after settlement,
- stop counting months past the settled month in the settlement year for
  `monthly` cadence.

**UI — the Loan figures block, all three states.** The control must be reachable
in both the empty and populated states, because a settled mortgage produces the
empty state in every later year, which is precisely when a landlord needs it.

- **Empty** — "Add loan figures", plus a quiet "Mortgage paid off?" control
  beside it.
- **Populated** — Modify stays on the title row; the settled control is a quiet
  line beneath the figures, so the title row never carries two actions.
- **Settled** — the block reads `Mortgage settled · March 2027` with a control to
  correct or clear the date. Nothing nudges for later years.

The settled *state* replaces the block's contents only for years **after** the
settlement year. In the settlement year and every year before it, the block
behaves normally — figures, Modify, completeness sub-line — because those years
still expect loan figures; the settled date is shown as a quiet line rather than
taking over the block. Only from the following year does the block collapse to
the settled state.

The month/year picker reuses the modal-list pattern `trackFromYear` already uses
(`add_property_dialog.dart:785-847`). Icons, not emoji — project convention.

**Completeness denominator.** The sub-line's hardcoded `12`
(`finance_screen.dart:635`) is already wrong — the backend requires only
*elapsed* months (`finance_engine.py:98-104`) — and settlement adds a third
bound. Since this line is being edited anyway, it reads the same bound the
backend uses rather than a literal.

---

## Behaviour matrix

| `hasMortgage` | `mortgageSettledOn` | Year | Loans folder | Nudge re: loans | Panel row |
| --- | --- | --- | --- | --- | --- |
| `true` | `null` | any | shown | offers upload | **shown** |
| `true` | `'2027-03'` | 2026 | shown | offers upload | shown |
| `true` | `'2027-03'` | 2027 | shown | offers upload (Jan–Mar only) | shown |
| `true` | `'2027-03'` | 2028 | shown | silent | shown, reads "Mortgage settled" |
| `false` | n/a | any | shown | silent | hidden |
| `null` | n/a | any | shown | offers upload | hidden |

The Loans & Financing folder is shown unconditionally in every row.

## Error handling

- A property that fails to load is treated as `null` method throughout: folder
  shown, upload nudge, no panel row. Never hide a surface because data has not
  arrived. (Unchanged from the previous workstream.)
- A malformed `mortgage_settled_on` is treated as unset, so a bad value can
  never silently suppress a year's loan expectation.
- Switching `hasMortgage` to `false` never deletes anything. Booked figures and
  uploaded loan documents remain stored and continue to feed the engine; only
  the panel row is hidden. The confirmation in §3 says so explicitly.
- The Save/prefill invariant from the previous workstream holds: on
  `manual_loan_entry_sheet.dart`, any gate deciding whether Save is live and any
  gate deciding whether prefill runs **must be the same expression**
  (`entriesAsync.value` / `.hasValue`). They diverged twice before and both
  times it was silent data corruption.

## Testing

**Fork removal**
- Loans & Financing tile present for every property: mortgaged, unmortgaged,
  `null`, and a failed property load
- Property dialog renders no loan-method question in create or edit
- Panel row shown for any `hasMortgage == true` property regardless of history
- Nudge offers upload for a mortgaged property with no loan figures, and never
  renders an enter-manually affordance
- Nudge stops listing loans once figures are booked by either route
- A mortgaged upload-mode property now receives completeness tracking

**Ownership share (§2)** — the highest-risk area
- A 50%-owned property with RM 8,200 loan interest **and** a RM 1,000 non-loan
  deductible expense: loan interest contributes 8,200 and the other contributes
  500, to Direct Expenses, statutory, net P&L and `expense_breakdown` alike
- `loan_principal` passes through unscaled in `landlord_paid` and net P&L
- Unit-level and property-level loan lines both pass through whole
- `expense_lines`, `property_expense_lines` and unit `expense_lines` render loan
  amounts at face value with no `full_amount`, while non-loan lines at share
  < 1.0 still carry `full_amount`
- **Reconciliation:** `direct_expenses` equals the sum of its own deductible
  expense lines, at share 1.0 and at share 0.5 — this is the assertion that
  catches a missed site
- A 100%-owned property is byte-identical to before the change

**"Not sure" (§3)**
- Mortgage selector offers Yes and No only
- A `null`-mortgage property shows neither chip selected
- Editing a property and selecting "Not sure" for structure type or track-from
  year persists `null`
- Yes → No with booked figures raises the confirmation; cancel restores Yes;
  confirm saves `hasMortgage: false` and leaves the figures stored
- Yes → No with no booked figures saves without a confirmation

**Settlement (§4)**
- Settled March 2027: 2026 expects a full year, 2027 expects Jan–Mar, 2028
  expects nothing and nudges nothing
- Monthly cadence in the settlement year is not flagged incomplete for months
  after the settled month
- The settled control is reachable from both the empty and populated block
  states
- Clearing the date restores nudging for every year
- A malformed stored value behaves as unset
- `hasMortgage` stays `true` after settling, and history still reconciles

**Regression:** full Flutter suite green and `py -3.11 -m pytest tests/ -q`
green, with `test/widget_test.dart`'s pre-existing boilerplate failure the only
Flutter failure.

## Success criteria

1. Both loan routes work for every mortgaged property with no question gating
   either, and the Loans & Financing folder always appears.
2. Loan interest and principal appear at face value in every figure the landlord
   sees, at any ownership share, and totals reconcile against their own lines.
3. "Not sure" persists where it is offered, and is not offered on the mortgage
   question.
4. A landlord can record settlement, keeps accurate history before it, and is
   never nudged about loans after it.
5. Answering "No" with figures booked warns before proceeding and points at
   settlement as the alternative.

## Execution routing

Not uniform. Splitting it:

- **§1 and §3 — direct.** Field deletions across known call sites and a
  call-site coalescing fix. Mechanical, and the existing suite covers them.
- **§2 and §4 — subagent-driven-development with independent review.** Both
  rewrite finance-engine logic that produces tax figures, and both fail
  silently: §2 by making totals disagree, §4 by suppressing a year's
  expectation. §2's reconciliation test is the gate.

Order matters: §1 first, since §2's and §4's call sites move once the method
gate at line 911 is gone.
