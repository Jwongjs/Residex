# Handoff — Loan Tracking Rework execution

**Plan:** `docs/superpowers/plans/2026-08-06-loan-tracking-rework.md`
**Started:** 2026-08-06 · **ALL 8 TASKS COMPLETE:** 2026-08-07
**Branch:** `feat/finance-tab-restructure`

> **Status: complete. Manual verification run, both follow-up defects fixed,
> committed 2026-08-09.**
> Final counts — backend **613 passed / 0 failed**; Flutter **303 passed /
> 1 failed** (the known `widget_test.dart` boilerplate failure, which must
> never be fixed); `flutter analyze` 292 issues / **0 errors**, all pre-existing.

## Ground rules this run was executed under

- **Git workflows skipped by explicit user instruction — NOTHING IS COMMITTED.**
  Every task's "Commit" step was deliberately not run. All work below is
  uncommitted in the working tree.
- Routing via the `routing-plan-execution` skill: per-task DIRECT vs HEAVY.
  **sonnet implements, opus reviews.**
- Every task ran the **full** suite, never a scoped one.

## Routing table (unchanged, still the plan of record)

| # | Task | Mode | Why |
|---|---|---|---|
| 1 | Backend: remove `loan_input_method` gate | DIRECT | complete code given, loud failure |
| 2 | Frontend: delete `loanInputMethod` | **HEAVY** | 12 files, changes `Property`'s shape |
| 3 | Loan lines never scaled by share | **HEAVY** | tax math, 8 sites, silent failure |
| 4 | Yes/No mortgage + stop coalescing | DIRECT | 1 lib + 1 test file |
| 5 | Yes→No confirmation | DIRECT | additive UI, complete code given |
| 6 | `mortgageSettledOn` model + persistence | **HEAVY** | cross-language, consumed by 7 & 8 |
| 7 | `_loan_expected_for` engine predicate | **HEAVY** | suppresses expectations, silent failure |
| 8 | Settlement control + denominator | DIRECT | escalate if it leaves `finance_screen.dart` |

Two tasks were escalated above the plan's own recommendation: **2** (12 files +
the `Property` interface) and **6** (cross-language + the 21-field
`withMortgageSettledOn` transcription, a silent-data-loss trap this repo has hit
before).

## Status: all 8 tasks COMPLETE. Remaining work is manual verification + commit.

### Known-good verification counts
- **Backend:** `cd backend && py -3.11 -m pytest tests/ -q` → **610 passed, 0 failed**.
  The *total* drifts between runs because `tests/test_fact_locator.py` belongs to
  an unrelated in-flight workstream — judge by **zero failures** plus our own
  file's count.
- **Flutter:** `cd residex_app && flutter test` → **299 passed, 1 failed**.
  The one failure is `test/widget_test.dart` "Counter increments smoke test",
  a pre-existing boilerplate failure that must **never** be fixed.
- `flutter analyze` → 292 issues, **0 errors**, all pre-existing.

### Task 1 — complete (direct)
Gate in `_loan_completeness` reduced to `has_mortgage is not True`;
`loan_input_method` passthrough dropped from `property_directory.py`. Diff
hand-verified as minimal.

### Task 2 — complete (review clean)
`loanInputMethod` deleted across 12 files. Opus review found **no defects** and
verified all 20 `Property` fields survive across all 7 mappings (ctor,
`copyWith`, `fromEntity`, `toEntity`, `fromJson`, `toJson`, model ctor).
Fix loop closed 3 review items:
- `manualLoanEntriesProvider` override added to `_pumpScreenWithProperty` —
  three tests were reaching the real data source and only passing because the
  emulator host is unroutable from a desktop test runner.
- stale entry-method comment in `finance_screen.dart` rewritten.
- added a `hasMortgage: null` test; `_fakeProperty`'s `hasMortgage` widened to
  `bool?`.

### Task 3 — complete (review clean)
`_LOAN_EXEMPT_SUBTYPES = {"interest_statement", "loan_interest",
"loan_principal"}` + `_line_share`, applied at all 8 sites. **Use the plan's
three-element set, not the spec's two-element one** — the spec's version
silently misses every typed loan document's interest at partial share.

Opus review enumerated every remaining `share *` in the engine and found no
missed expense site, verified the subtype set against `fact_extractor.py`, and
re-derived the arithmetic by executing the engine.

Fix loop closed 2 coverage gaps + 1 comment error:
- **3 new unit-scope gate tests** in `LoanShareExemptionTests`. The unit
  `contribution` / `statutory_contribution` sites were completely unpinned —
  reverting them to `share * (income - expenses)` left all 572 tests green
  while a co-owner's unit figures silently dropped. **Proven to have teeth:**
  reintroduced that exact regression, all 3 failed, other 9 stayed green,
  reverted.
- comment claimed "all four spellings" over a three-element set.

### Task 4 — complete (direct)
Edit branch writes `structureType` / `hasMortgage` / `trackFromYear` **raw**
from state (no `?? existing.`); mortgage chips reduced to Yes/No.
`structureType` and `trackFromYear` correctly **keep** their "Not sure".

Safe because `initState` seeds all three from the existing property, so an
untouched field still round-trips — verified before the change.

> **The implementer agent was killed mid-task** (session stopped) after its
> edits but *before* it verified. Its red step was therefore reconstructed by
> hand: restoring `?? existing.` on all three made the two "Not sure persists
> null" tests fail; reverted, suite back to 277/1.
>
> **Caveat worth carrying forward:** the test `answering No on a mortgaged
> property writes hasMortgage false` does **not** fail under the old
> coalescing, because `false ?? x` is still `false`. Coalescing only ever broke
> the *null* case. That test is weaker than its name suggests — **Task 5's
> confirmation-dialog tests are the real gate on Yes→No.**

### Task 5 — complete (direct)
`_confirmRemovingLoanTracking`, awaited **before** `setState(_isLoading = true)`
so no spinner runs behind the modal; cancel restores `_hasMortgage = true`.

### Task 6 — complete (review clean, one significant fix)
Field threaded through all seven mappings + `property_directory.py`. Review
verified 21/21 field parity mechanically.

> **The guard was hollow.** The plan's `withMortgageSettledOn preserves every
> other field` test had near-zero detection power — the review proved it by
> deleting four fields from the constructor call and watching all six tests
> stay green. The fixture left 12 of 20 fields at their `fromJson` defaults, so
> a dropped field re-derived the *same* default and `expect(after.x, before.x)`
> compared a default to a default. Only the 8 `required` fields were really
> covered, and the compiler already guards those.
>
> Fixed with `_saturatedPropertyJson()` (every optional field non-default),
> plus "guard the guard" assertions so a future refactor back to defaults fails
> loudly. Also added `fromEntity carries mortgage_settled_on out to Firestore` —
> `fromEntity` is the **only** entity→Firestore path and no test exercised it
> with a real value.

### Task 7 — complete, **after fixing a defect in the plan itself**

> **The plan was self-contradictory and would have shipped a silent tax bug.**
> Steps 4–5 wired `_loan_expected_for` (which requires `has_mortgage == true`)
> in front of the *expectation* consumers; Step 7 then claimed this preserved
> conservatism for an unanswered mortgage. It did the opposite.
>
> Verified by execution before changing anything: a property with
> `has_mortgage` **unset** became byte-identical to one where the landlord had
> explicitly answered "no mortgage" — the loan nudge vanished, the year flipped
> to `complete`, and the statutory figure lost its provisional caveat. That is
> the state of **every property registered before the mortgage question
> existed**. A landlord would file with the interest statement never requested
> and the deduction silently omitted.
>
> **Fix — split the predicate:**
> - `_loan_settled_before(prop, year, month)` answers *only* "is this period
>   after a recorded settlement date", saying nothing about `has_mortgage`
>   (plus a `1 <= month <= 12` bounds check, so `"2027-00"` can't suppress).
> - `_loan_expected_for` = `has_mortgage is True AND not _loan_settled_before`,
>   and its docstring now forbids reusing it for expectation.
> - **Both expectation consumers use `_loan_settled_before` alone.**
>   `_expected_categories` already drops `'loan'` on an explicit `False`, so the
>   unanswered case stays conservative.
>
> The implementer had rewritten **four** pre-existing tests to bless the
> regression — including `test_unknown_profile_keeps_todays_behaviour`, whose
> entire purpose is to guard that case, inverted to assert the opposite. All
> four restored. The fifth changed test was legitimate and left alone. Added two
> dedicated tests so the unset case is pinned **by name**, not incidentally via
> a shared `_prop()` helper.

### Task 8 — complete (direct, one fix)
Settled state, the control reachable from **both** the empty and populated
states, two-sheet year→month picker writing via `withMortgageSettledOn`.

> **The implementer changed the formula to satisfy a bad test.** It replaced the
> plan's `min()` cap with a direct override (`monthsInScope = settled.month`),
> because the plan's own test used settlement year 2027 — *future* when the plan
> was written — making the elapsed bound 0 so `min(0, 3) = 0` failed.
>
> But the picker caps years at `currentYear`, so a future settlement *year* is
> unreachable: the test was wrong, not the formula. Meanwhile the override is
> wrong for a **reachable** state — the picker offers all 12 months of the
> current year, so `'2026-12'` in August rendered "1 of 12" while the backend
> (which intersects `_months_in_scope` **and** `_loan_expected_for`) wants 8.
> That is precisely the "3 of 12" mismatch Step 5 exists to remove.
>
> Restored the cap, rewrote the test to use a past settlement year, and added
> `the denominator never exceeds the elapsed months`. Proven by reapplying the
> override and watching it fail.

## Manual verification — RUN 2026-08-07, against the real app

Emulator `documind_light` + backend on :8000 (process started 09:23, after the
last engine edit at 09:14, so it served current code). Driven via `adb` +
`uiautomator dump`; figures cross-checked by calling
`documind_service.get_finance_summary` directly.

**All test data was reverted afterwards** — the engine returns figures
byte-identical to the pre-run baseline (2025 direct_expenses 44738.41 /
statutory 94461.59; 2026 250.0 / 78400.0; same `missing_categories`).

| # | Scenario | Result |
|---|----------|--------|
| 1 | Fork removal | **PASS** |
| 2 | New output on existing data | **PASS** |
| 3 | Ownership share | **PASS** on substance; plan text describes UI that does not exist |
| 4 | "Not sure" | **PASS** |
| 5 | Yes → No | **PASS**, but the guard is narrower than the scenario assumes |
| 6 | Settlement | **PASS** on engine; **FAIL** on immediate UI consistency |

### 1 — Fork removal · PASS
Loans & Financing folder present (Ayer 8, which still carries the legacy
`loan_input_method: 'manual'` in Firestore — harmless, nothing reads it).
Edit-property has **no** "How will loan figures arrive?" question. Damai
(`loan_input_method` null, `has_mortgage` true) shows its loan row.

### 2 — New output on existing data · PASS
Both properties show "20XX records are incomplete — this is a provisional
figure and will change as documents arrive." Completeness sub-line appears in
both forms: "Some 2026 loan figures are still missing" (property scope) and
"1 of 4 units recorded for 2026" (unit scope).

### 3 — Ownership share · PASS on substance
Decisive numeric check on Damai (50%): adding Interest 1,000 + Principal 2,000
moved Damai's EXPENSES from **250.00 → 3,250.00** (= 250 + 1,000 + 2,000).
Scaled loan lines would have given 1,750. Statutory income moved 14,400 →
13,400, i.e. interest deducted at **full face value** and principal not
deducted at all. Caveat renders: "Shown at your 50% share. Loan interest and
principal are shown in full."

> **Plan/implementation mismatch (not a code defect).** The scenario asks to
> check that non-loan lines "read the scaled value with *your N% of RM X*".
> No such per-line string exists anywhere in the app — `grep` for it returns
> nothing. The share is communicated once, at card level
> (`finance_screen.dart:389`). Either the plan describes UI that was descoped,
> or the scenario was written from an imagined design. The *substance* it was
> trying to test is verified above; the wording is not checkable as written.

### 4 — "Not sure" · PASS
Ayer 8 (commercial, `property_type: 'strata'`) → tap "Not sure" → Save →
Firestore `property_type = None`, **not** coalesced back to `'strata'`.
Reopened: chip still "Not sure". `has_mortgage` and `track_from_year` survived
untouched, confirming the initState-seeding safety argument for Task 4.

### 5 — Yes → No · PASS, with a narrower guard than the scenario assumes
With a current-year entry present, Save raised **"Remove loan tracking for this
property?"** naming **RM 3,000.00** and saying "If your mortgage is fully
repaid, mark it settled instead so your past years stay accurate." No spinner
behind the modal (Task 5's ordering holds). **Cancel** → chip back to Yes,
`has_mortgage` unchanged. **Remove tracking** → `has_mortgage: false`, and the
figures **stayed in the finance totals** (EXPENSES still 3,000.00, statutory
63,000.00) while the loan block disappeared — exactly what the dialog promises.

> **Found: the guard only looks at the current year.**
> `add_property_dialog.dart:113` reads
> `manualLoanEntriesProvider((propertyId, year: DateTime.now().year))` and
> returns `true` (save silently) when that list is empty. First attempt on
> Ayer 8 — which has **RM 90,074.52 of 2025 figures** but none for 2026 —
> flipped `has_mortgage` to false **with no confirmation at all**. That is the
> normal state of any property early in a calendar year, or any property whose
> loan history predates this year. The dialog's own rationale (line 102-105)
> is that "No" *retroactively stops expecting loan figures for every historical
> year* — but the guard only inspects one year. The plan supplied this code, so
> it is not an implementer error.
>
> **FIXED 2026-08-09.** `list_manual_loan_entries` now takes an optional year
> (`None` = every year), which costs nothing: the query already streamed all of
> the landlord's entries and filtered in Python. A new
> `allManualLoanEntriesProvider` reads it, and the guard uses that. The
> year-scoped `manualLoanEntriesProvider` was left alone rather than widened to
> a nullable key — widening it would have silently changed the argument type of
> every existing `overrideWith` in the tests. The dialog now also names the
> years it found ("RM 90,074.52 of 2025 loan figures"), so the warning is
> checkable against what the landlord remembers filing.

### 6 — Settlement · engine PASS, UI staleness FAIL
Set Damai settled **June 2025** through the two-sheet picker (year list capped
at 2026 = current year, down to `trackFromYear` 2025 — confirming Task 8's
"a future settlement year is unreachable"). Firestore took
`mortgage_settled_on: '2025-06'`, so the whole Flutter entity → model →
Firestore path of Task 6 is verified end-to-end.

- Settlement year **2025**: figures block still present, label became
  "Mortgage settled · June 2025". Engine unchanged — `loan` still expected,
  still missing, caveat intact. ✓
- Year **2026**: block collapsed to "Mortgage settled · June 2025" + Change.
  Engine dropped `loan` from `missing_categories`, dropped the "No loan
  document for 2026" caveat, and flipped `manual_loan_incomplete` to false.
  Ayer 8 (no settlement) was unaffected — a clean control. ✓
- **Clear** via "Still paying it off" → `mortgage_settled_on: None`. The
  `withMortgageSettledOn(null)` escape hatch works; `copyWith` would have
  silently kept the date. ✓

> **DEFECT — the settlement write does not invalidate `financeSummaryProvider`.**
> `_openSettlementSheet` (both branches) writes via
> `propertyControllerProvider.updateProperty`, which invalidates only
> `propertiesStreamProvider` and `propertyByIdProvider`. All **13** other
> finance-affecting writes in `documind_provider.dart` invalidate
> `financeSummaryProvider`; this one does not.
>
> Observed both directions: after marking settled, the nudge still read
> "5 documents needed for 2026" when the engine had already dropped to 4; after
> clearing, it still read 4 when the engine was back to 5. Meanwhile the loan
> block *does* update immediately (it reads the property object), so the screen
> shows **two statements that contradict each other** — the block saying loan
> figures are still wanted, the nudge counting as though they are not. Pull-to-
> refresh or an app restart corrects it. Confirmed by contrast: saving a manual
> loan entry updates the nudge instantly.
>
> Not a tax-math error — both halves are individually correct. It is precisely
> the "two totals on one screen quietly disagreeing" failure mode Task 3 exists
> to prevent, arriving through a different door.
>
> **FIXED 2026-08-09.** Both branches now route through `_saveSettlement`,
> which invalidates `financeSummaryProvider` after the write. Two tests drive
> the sheet for real against a `financeSummaryProvider` that answers
> differently on its second build, so the nudge count is a direct read of
> whether the summary rebuilt — one for marking settled, one for clearing.

## What remains

1. ~~Two defects found above, neither fixed.~~ **Both fixed 2026-08-09**
   (§5 and §6), each with a regression test proven to fail without its fix.
   The §5 fix was not frontend-only as predicted: the guard needed a backend
   query that spans years, so `list_manual_loan_entries` gained an optional
   year.
2. ~~Nothing is committed.~~ **Committed 2026-08-09** as one commit covering
   all 8 tasks plus the two fixes. The unrelated fact-aware-answering and
   citation-precision WIP was held back at hunk level — `documind_service.py`
   and `test_documind_service_flows.py` each carried hunks from both
   workstreams. The split was verified by building a scratch worktree from the
   index alone and running both suites against it, which is how a missing
   `documents_screen.dart` (Task 2's `loanInputMethod` removal, without which
   three test files would not compile) was caught before committing rather
   than after.
3. The out-of-scope unit-panel bug below — now **reproduced with figures**.
   Still open; needs its own spec.

### Do not touch / do not attribute to this plan
Unrelated uncommitted WIP shares this tree: the fact-aware answering and
citation-precision workstream (`backend/rag/ask/`, `backend/rag/documents/`,
`backend/rag/documind_service.py`, `tests/test_fact_context.py`,
`tests/test_document_facts_lookup.py`, `tests/test_fact_locator.py`), plus
`backend/rexAI.txt`, `backend/scripts/`, and `demo_documents/`.

## Open item for the user — found, not fixed, out of scope

`residex_app/lib/.../3-Finance/unit_finance_detail_screen.dart` (~158-206,
271-334) stacks three figures that do not reconcile on a co-owned property:
"Gross income" comes from `month_rows`, which the engine emits **unscaled**;
"− Direct expenses" is **scaled**; and the total (`contribution`) scales the
income term. At 50% share the panel reads **12,000 − 1,500 = 4,500**.

Confirmed **pre-existing** (the same panel showed 12,000 − 900 = 11,100 before
Task 3), so it is not a regression and is outside this plan's scope. Flagged
because it is exactly the "two totals on one screen quietly disagreeing"
failure Task 3 exists to prevent, and Task 3's reconciliation gate does not
reach it. Needs its own spec.

> **Reproduced live on 2026-08-07** with a loan entry on Damai's Unit B-08-11
> (50% share, 2026). The panel printed, in three stacked rows:
>
> ```
> Gross income            RM 25,600.00
> Direct expenses        −RM  3,000.00
> Rental Profit/Loss      RM  9,800.00
> ```
>
> 25,600 − 3,000 = 22,600, not 9,800 — a visible **RM 12,800** contradiction.
> The engine is right (0.5 × 25,600 − 3,000 = 9,800; statutory
> 0.5 × 25,600 − 1,000 interest = 11,800, both matching); only *Gross income*
> is rendered unscaled. The child lines do reconcile against their own header
> (principal 2,000 + interest 1,000 = the 3,000 shown). Adding loan figures
> makes the gap larger and more likely to be noticed, so this is worth
> scheduling rather than leaving indefinitely.
