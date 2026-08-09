# Unit panel share reconciliation: emit the gross the engine used

**Date:** 2026-08-09
**Status:** Approved design, ready for implementation planning
**Origin:** `docs/superpowers/HANDOFF-unit-panel-share-reconciliation.md`, found
during manual verification of the loan tracking rework and held out of scope
there (pre-existing, not a regression).

## Problem

On a co-owned property the unit detail panel stacks an **unscaled** gross income
figure over **scaled** expenses and a **scaled** total, so the three numbers the
landlord is looking at do not add up. At 50% share both accordions render:

```
Gross income          25,600.00     <- the whole property's rent
Direct expenses       −3,000.00     <- already halved by the engine
─────────────────────────────
Rental Profit/Loss     9,800.00     <- (0.5 × 25,600) − 3,000
```

`25,600 − 3,000 = 22,600`, not `9,800`. The total is arithmetically correct as a
tax figure; the gross line above it is the one that lies. Reproduced live on
2026-08-07 on Damai Unit B-08-11 — a visible RM 12,800 contradiction.

The cause is that the engine applies ownership share at three separate moments
and the panel picks up two of them:

| Field the panel reads | Scaled? | Where |
| --- | --- | --- |
| `UnitFinance.months[].amount` | **No** | `finance_engine.py:188-199` — `_scope_income` runs before share is known and rows are stored verbatim at `:1189` |
| `UnitFinance.expenseLines[].amount` | **Yes** (loan lines exempt, by design) | `finance_engine.py:1191` via `_scaled_lines` |
| `contribution` / `statutoryContribution` | **Yes** | `finance_engine.py:1183-1189` |

The panel then computes gross itself by summing the *month* rows
(`unit_finance_detail_screen.dart:158-166`) and feeds that unscaled number into
both accordions (`:181`, `:197`).

Two further manifestations of the same root cause:

- **The month strip** renders the same unscaled `month.amount` (`:541`), while
  the property card's `outstanding_rent` has always been emitted *scaled*
  (`finance_engine.py:1276`, `:1353`). The strip already disagrees with a total
  the landlord can see one screen up.
- **The screen never mentions share at all.** The property card carries an
  `N% share` badge and a footnote (`finance_screen.dart:322-334`, `:387-392`);
  drilling into a unit loses both, leaving an unlabelled, unreconciled
  subtraction.

### Why no test caught it

Every fixture in `unit_finance_detail_test.dart` and
`unit_finance_detail_screen_test.dart` leaves `PropertyFinance.ownershipShare`
at its `1.0` default, where scaled and unscaled are the same number. Partial
share is covered on the property card, the model and the engine — never on this
screen.

## Goals

1. Every figure on the unit panel reconciles at any ownership share.
2. The panel renders the share treatment the engine *used*; it never computes
   its own.
3. The invoiced figure stays reachable, using the explanation idiom the screen
   already has.
4. At 100% ownership the payload and the rendered screen are byte-identical to
   today.

## Non-goals

- **Loan lines stay unscaled.** That is deliberate and settled (`_line_share`,
  `finance_engine.py:437-441`): loan interest and principal are the landlord's
  own borrowing, not a cost shared with co-owners. Do not "fix" it.
- **Per-document share basis** — whether an uploaded document reports the whole
  property's figure or one already split by the managing agent. Real and queued
  as its own spec; see Follow-ups.
- **Unit-level ownership share** — share currently lives on the property and
  cannot express "units A and C at 100%, unit B at 50%". Real and queued as its
  own spec; see Follow-ups.
- Not changing the two-accordion structure, the expense grouping, or the
  document tap-through.

---

## Design

### §1 Engine: the unit block emits its own gross

`_unit_block` assembly (`finance_engine.py:1179-1193`) gains two fields, built
from the values already in scope:

- `gross_income` = `_round2(share * (actual_sum + derived_sum))` — always
  present.
- `full_gross_income` = `_round2(actual_sum + derived_sum)` — present **only
  when `share < 1.0`**.

`actual_sum` and `derived_sum` are disjoint income *sources*, not two versions
of one number: `actual` is a month with an invoice, `derived` is a month with no
invoice but covered by a tenancy agreement, priced from `monthly_rent`
(`finance_engine.py:188-199`). Both are rent; gross is their sum. This is the
same pair `contribution` is already built from at `:1183-1184`.

> **Round once, then subtract.** `contribution` currently rounds
> `share * (actual_sum + derived_sum) - display_landlord_scaled` as a single
> expression. If `gross_income` rounds that first term independently, the two
> can disagree by a cent — and a panel rendering `12,800.00 − 3,000.00 =
> 9,800.01` is the very defect this spec exists to remove, just smaller.
> So compute the rounded gross **first** and build both totals from it:
>
> ```python
> gross_income = _round2(share * (actual_sum + derived_sum))
> contribution = _round2(gross_income - display_landlord_scaled)
> statutory_contribution = _round2(gross_income - display_deductible_scaled)
> ```
>
> This can move an existing unit figure by one cent. That is intended: it is
> what makes `gross − expenses == total` true as *rendered*, which is the goal.
> Property-level totals are computed separately at `:1263-1282` and are not
> touched by this.

Omitting `full_gross_income` at share 1.0 is not a new rule — it mirrors
`_scaled_lines`' existing contract for `full_amount` (`:444-466`), which is why
an expense row at full ownership shows no sub-label today. The absence of the
field is the panel's signal that no scaling happened.

### §2 Engine: month rows are scaled where the block is assembled

Add `_scaled_month_rows(rows, share)` next to `_scaled_lines`, with the same
contract — **never mutates the input**, returns the list unchanged at share 1.0,
and below 1.0 returns copies where:

- `amount` becomes `_round2(share * amount)`, and `full_amount` carries the
  original.
- `billed_amount`, when present, becomes `_round2(share * billed_amount)`, and
  `full_billed_amount` carries the original. This figure feeds an input that
  §3 redefines as the landlord's own share, so it must scale with it.
- `month`, `source`, `payment_state` and `reason` are copied through untouched.

Apply it at `:1189` (`"months": _scaled_month_rows(month_rows, share)`).

> **Trap — scale the rows only, never the tuples.** `_scope_income` also returns
> `unpaid_months` as `(month, reason, state, billed)` tuples, and `billed` from
> those tuples accumulates into `prop_outstanding` (`:1203-1209`), which is
> *already* scaled once at `:1276`. Scaling the tuple as well double-scales
> every property's outstanding rent, and no existing test would fail.
> `_scope_income` itself must stay share-free: its scalar returns
> (`actual_sum`, `derived_sum`) feed the property-level sums that are scaled
> separately at `:1274`.

### §3 Engine: recoveries are stored at the landlord's share

Today `s_received = share * (prop_actual + prop_derived + prop_recovered)`
(`:1263`, `:1274`). Change to:

```python
s_received = share * (prop_actual + prop_derived) + prop_recovered
```

The local `received` becomes unused and is removed; `s_received` is the only
consumer. This propagates to all six property figures and the grand total
(`:1281-1282`, `:1341`, `:1351`, `:1356-1358`), which is correct — under §7 the
stored recovery is already the landlord's money.

`recovered_lines[].amount` (`:1251-1256`) is likewise left unscaled: it is the
figure the landlord typed.

At share 1.0 this change is a no-op.

### §4 Flutter model

- `UnitFinance` gains `grossIncome` (required-with-default `0.0`) and
  `fullGrossIncome` (`double?`).
- `MonthIncome` gains `fullAmount` (`double?`) and `fullBilledAmount`
  (`double?`); `billedAmount`'s meaning changes to "at the landlord's share".
- `finance_summary_model.dart:103-127` maps `gross_income` and
  `full_gross_income`; `:112-119` maps `full_amount` and `full_billed_amount`,
  following the existing `l['full_amount'] == null ? null : _d(...)` idiom at
  `:138`.

### §5 Panel: the gross line

Delete `_grossIncome(UnitFinance)` (`unit_finance_detail_screen.dart:158-166`)
entirely. `_breakdownAccordion`'s `gross` argument becomes `unit.grossIncome`,
passed from both accordions (`:181`, `:197`).

When `unit.fullGrossIncome` is non-null, render beneath the figure:

```
your 50% of RM 25,600.00
```

styled exactly as the expense-row sub-label (`:457-465`) — `labelSmall`,
`textMuted`, right-aligned in a `Column` with `CrossAxisAlignment.end`.

**The percentage is derived from the figure pair, not from a share field:**
`((unit.grossIncome / unit.fullGrossIncome!) * 100).toStringAsFixed(0)`, the
same computation the expense rows already use at `:460`. The panel therefore
never reads `ownershipShare`, which is what makes it survive the unit-level
share spec without modification, and is why `UnitFinance` does not need to carry
a share field.

Guard the division: skip the sub-label when `fullGrossIncome` is null or `<= 0`,
matching the `line.fullAmount! > 0` guard at `:457`.

### §6 Panel: the month strip

Cells render the now-scaled `month.amount` with no code change at `:541` — the
value arrives scaled. Two additions:

- The `Monthly income` header (`:144`) gains `· your N% share` when **any** row
  in `unit.months` carries a non-null `fullAmount`. Percentage derived from that
  row's pair, as in §5.
- `OUTSTANDING`, `WRITTEN OFF` and vacant cells are untouched — they print a
  state, not a figure, and contribute nothing to gross either way.

The strip then sums to `gross_income` directly, and agrees with the property
card's `outstanding_rent`, which has always been scaled.

### §7 The Record-recovery sheet

Reachable only from a month the landlord marked outstanding and then written off
(`rent_payment_sheets.dart:140-148`). It is the one place on this screen where a
figure is typed back in and stored.

- The amount field prefills from `billedAmount`, which §2 now delivers scaled.
- The stored value is what the landlord typed, unscaled by the engine (§3).
- **The instruction adapts to whether a share applies**, keyed on
  `fullBilledAmount` being non-null:
  - full ownership → label `Amount received from tenant (RM)`
  - partial share → label `Your share of the amount received (RM)`, with helper
    text `Enter your 50% share, not the full RM 3,200.00 the tenant paid.`

At full ownership the two are the same number, so the landlord is asked for the
full invoiced amount exactly as today.

---

## Pre-flight check and data correction

§3 changes the meaning of already-stored data: every document in
`documind_rent_recoveries` (`finance_overrides_repository.py:119`, `:281`) was
entered at face value and is currently scaled on read. After §3 it is booked in
full.

**This only affects recoveries on properties with `ownership_share < 1.0`** — at
1.0 the change is a no-op. So:

1. Before any code, run a read-only query joining `documind_rent_recoveries` to
   its properties and report every recovery whose property has
   `ownership_share < 1.0`, with property name, month and amount.
2. If that returns zero rows, no correction is needed and this section closes.
3. If it returns rows, a one-off script multiplies each affected `amount` by its
   property's share, dry-run first, `--apply` second — mirroring
   `backend/scripts/backfill_fact_pages.py`.

Do not skip step 1 on the assumption the set is empty.

## Testing

**The load-bearing constraint: a test that leaves `ownershipShare` at 1.0 cannot
fail against this bug.** Every new test below sets a share under 1.0.

Backend (`backend/tests/test_finance_engine.py`):

1. Unit block at share 0.5 emits `gross_income == 0.5 * (actual + derived)` and
   `full_gross_income == actual + derived`.
2. At share 1.0, `full_gross_income` is **absent** from the payload and no month
   row carries `full_amount` or `full_billed_amount` — the byte-identical
   guarantee.
3. Month rows at share 0.5 carry scaled `amount` plus the original in
   `full_amount`; `_scope_income`'s own return values are unchanged.
4. `outstanding_rent` is unchanged by §2 at share 0.5 — the regression guard for
   the tuple-vs-row trap. Prove it has teeth by scaling the tuple and watching
   only this test fail.
5. A recovery on a 0.5-share property is booked **in full** into `received_rent`
   and `statutory_contribution`, not halved.
6. `contribution == gross_income − (landlord-paid scaled lines)` holds at 0.5,
   including a loan line, which stays unscaled.
7. **The rounding guard.** A fixture whose `share * (actual + derived)` lands on
   a half-cent (e.g. share 0.5 with an odd-cent rent) asserts
   `gross_income − expenses == contribution` exactly. Prove it has teeth by
   reverting to the single-expression form and watching this test fail while the
   others stay green.

Flutter:

8. `finance_summary_model_test.dart` — round-trip of the four new JSON fields,
   including their absence.
9. `unit_finance_detail_test.dart` — at share 0.5, the accordion's gross,
   expense subtotal and total satisfy `gross − expenses == total`; the
   `your 50% of RM …` sub-label is present. Assert on **both** accordions.
10. The same at share 1.0: no sub-label, no header qualifier.
11. The **synthetic whole-property scope** (`unitId == null`) at share 0.5 —
    same assertions as 9. It goes through the identical code path and has the
    identical defect.
12. `unit_finance_detail_screen_test.dart` — the strip header reads
    `· your 50% share` when rows carry `fullAmount`, and cells render the scaled
    amount.
13. The recovery sheet's label and helper switch on `fullBilledAmount`; the
    value submitted is what the field contains, unmodified.

Full suites only, never scoped. Baseline to beat: backend **613 passed /
0 failed**; Flutter **303 passed / 1 failed** (the `widget_test.dart` "Counter
increments smoke test" boilerplate failure, which must **never** be fixed);
`flutter analyze` 292 issues / **0 errors**, all pre-existing.

## Follow-ups (separate specs, not this one)

1. **Per-document share basis.** The engine assumes every document reports the
   whole property's figure. In reality a co-owner may receive a bill already
   split by the managing agent, which the engine then halves a second time. The
   fix is a per-document "amount basis" (full-property vs already-my-share),
   defaulted per category at property registration, with a per-upload prompt for
   the `expenses` bucket, whose combined statements are the unpredictable case
   (`categories.py:22-42`). Note that `loan` must stay hard-exempt: its
   exemption is an ownership decision, not a claim about what the document
   shows. Income and expenses scale at different places, so this touches both
   halves of the engine.
2. **Unit-level ownership share.** Share on the property cannot express "units A
   and C at 100%, unit B at 50%". Shape: keep `ownership_share` on the property
   as the default, let a unit override it, resolve per scope. This requires
   scaling per scope *before* summing rather than once per property at `:1274`,
   and property-level share must survive for the synthetic whole-property scope
   a landed house uses. §5's derive-the-percentage-from-the-pair rule is what
   keeps this spec's panel work valid when that lands.

## Branch constraints still in force

- Never `git add -A` on `feat/finance-tab-restructure` — an unrelated
  fact-aware-answering / citation-precision workstream is live and uncommitted
  in the working tree, including hunks inside `backend/rag/documind_service.py`
  and `backend/tests/test_documind_service_flows.py`.
- Never touch `backend/rexAI.txt` or
  `backend/scripts/{diagnose,fix}_ayer8_lease*.py`.
