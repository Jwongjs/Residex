# Handoff — Loan entry method workstream

**Date:** 2026-08-06
**Branch:** `feat/finance-tab-restructure`
**Status:** Implementation complete and reviewed clean. **Not pushed. Not manually verified.**

---

## What shipped

13 commits, `221672d..af4dfe8`. Flutter suite: **285 passed, 1 failed** — the failure is
`test/widget_test.dart` "Counter increments smoke test", pre-existing boilerplate that
predates this work and must never be "fixed".

The app used to ask "upload a statement, or type the figures?" at three different
surfaces, each rendering it as a primary button with an afterthought text link.
`Property.loanInputMethod` had existed since earlier loan work and `finance_engine.py:911`
already branched on it, but **no UI had ever written it**. This work makes the choice once,
at registration, and has every downstream surface honour it.

| Surface | Behaviour now |
| --- | --- |
| Property dialog | Two equally-weighted cards under the mortgage question, shown only when mortgage = Yes |
| Documents folder grid | Loans & Financing tile hidden when and only when method is `'manual'` |
| Finance nudge | Never offers manual entry; drops `'loan'` from the missing list for manual properties |
| Finance property panel | Permanent "Loan figures · YEAR" block with a Modify control, gated on method rather than completeness |
| Entry sheet | Prefills from the booked entry for the current scope; Save disabled until entries resolve |

**Inertness is the load-bearing constraint.** Every existing production property has
`loanInputMethod == null`. Only `'manual'` changes behaviour — `'upload'`, `null`, and a
property whose load fails all behave exactly as before. Verified end to end in the final review.

### Commits

```
af4dfe8  fix(loans): final-review fixes — "Not sure" no longer orphans figures, completeness sub-line
dea485f  fix(loans): unify the Save/prefill signal on hasValue, close the delete-stale gap
53b003d  fix(loans): stop the error state from walking landlords into a dead-end sheet
28f1454  fix(loans): disable Save until booked entries resolve, unify scope key
af68dbb  fix(loans): prefill the entry sheet so Modify cannot zero a figure
ab017dd  fix(loans): disabled loading state for the loan-figures row, invalidate on save
527ad45  fix(loans): bracket manualLoanIncomplete, fix hasFigures conflation, test non-tappable row
4990498  feat(loans): permanent loan figures row with a Modify control
ee3d5ef  feat(loans): the nudge stops re-asking how loan figures arrive
6c6411e  fix(loans): strengthen loan-folder tests, clear stale category on fallback
2212ad7  feat(loans): hide the Loans folder in manual mode, drop its manual entry
eeb0ab4  fix(loans): edit save actually clears loanInputMethod, add save-path tests
98b30a3  feat(loans): ask how loan figures arrive when the property has a mortgage
```

---

## The next thing to do

**Manual verification.** Nothing here has been run against the real app — only tests.
The plan's 7-step walkthrough is at the bottom of
`docs/superpowers/plans/2026-08-05-loan-entry-method.md`. Run it on a mortgaged property.

**Step 6 is the one that matters:** open Modify, change *only* the interest, save, and
confirm the principal is unchanged. If the principal became 0, the data-loss guard regressed
and that is a stop-everything finding.

Also worth eyeballing, because tests cannot judge it: the two cards should read as two real
options, not a button with a footnote. That was the original complaint.

---

## Deliberate decisions — do not "fix" these without asking

**`null`-method mortgaged properties have no route to manual loan entry.** Spec §2/§4
removed both old routes for every method, and the replacement panel row requires `'manual'`.
Any figures a landlord already booked through the old Loans-folder link are unreachable on
deploy while still counting in Direct Expenses. The final review raised this as Important;
**the user ruled ACCEPT AS SPECCED on 2026-08-06.** Recovery exists — edit the property and
pick "Enter figures myself" — it is simply not surfaced. This is a scope decision, not a bug.

**`Property.copyWith` null-coalescing is untouched on purpose.** `structureType` and
`trackFromYear` still cannot be set back to "Not sure" on an edit. Pre-existing, documented
in-code at `add_property_dialog.dart:145-146`. The `hasMortgage` half of that problem *was*
fixed, at the call site — see below.

---

## Parked minors, with rulings

None block merge. Ordered by how likely a landlord is to notice.

1. **`finance_screen.dart:594` — the completeness denominator is hardcoded 12**, but the
   backend only requires *elapsed* months (`finance_engine.py:98-104`). Jan–Jun booked in
   August reads "6 of 12 months recorded for 2026" when the actionable gap is 2 months.
   Never overstates completeness; it understates progress. **This is the only parked minor a
   landlord actually sees — best first follow-up.**
2. **`finance_screen.dart:84`** counts `'no_loan'` units as "recorded". Defensible (an exempt
   unit needs nothing) but the wording overstates what happened.
3. **`manual_loan_entry_sheet.dart:597`** — `value.toInt()` clamps above 2^63. Unreachable
   for an RM loan figure, still parses, never writes 0.
4. **Test gaps:** the per-unit completeness branch (`finance_screen.dart:82-85`) has no test;
   two refetch tests never assert `callCount == 2`; nothing pins the error copy on a
   never-resolved first load.
5. **`listManualLoanEntries` has no `.timeout(...)`** (`documind_remote_datasource.dart:552-570`,
   bare `http.Client()`). Pre-existing, but this workstream made it a render-path dependency
   for every manual property. Both consumers degrade visibly and pull-to-refresh recovers.
6. **`manualLoanIncomplete`** now has exactly one consumer again (the sub-line added in
   `af4dfe8`). It was consumerless before that fix.

---

## What cost the most time, and why

Task 5 took three fix rounds. Each round found a real data-loss path the previous one could
not see, so none of it was churn:

- **Round 1:** the Save button stayed live while entries were still loading or errored, so a
  pull-to-refresh mid-edit wrote `0` over booked figures. `_save` reads
  `double.tryParse(text) ?? 0` — a blank field is a zero.
- **Round 2:** the error state composed into a dead end *across two tasks* — the finance row
  rendered an enabled "Add loan figures", and the sheet it opened had Save disabled.
- **Round 3:** the controller's own round-2 instruction caused this one. Gating Save on
  `hasValue` without also moving prefill off `asData` made the two diverge during a refresh
  carrying a prior value; a strata landlord switching units after a failed refresh would have
  written the previous unit's figures onto the new one. **The reviewer found it by writing and
  running a throwaway probe test, not by reading the diff.** Both now read
  `entriesAsync.value` / `.hasValue`, which are the same signal.

**Lesson for whoever picks this up:** on this widget, any gate that decides *whether Save is
live* and any gate that decides *whether prefill runs* must be the same expression. They
diverged twice and both times it was silent corruption, never a crash.

The final review also found a Critical that only appeared when looking across all five tasks
at once: `add_property_dialog.dart` read the same `_hasMortgage` on two adjacent lines, one
coalescing and one not, so answering "Not sure" wrote `hasMortgage: true, loanInputMethod: null`
and orphaned the figures. Fixed in `af4dfe8` by computing `effectiveHasMortgage` once.

---

## Deviations from the plan, and why

- **Plan Task 3's assertions were vacuous.** It asserted `find.textContaining('Loans')`, but
  `DocumentNudgeBanner` renders `"<N> document(s) needed for <year>"` and never a category
  name. Replaced with count-based assertions, which actually pin the filtering.
- **Plan Task 5 put the prefill call in the wrong place.** It said "after `entriesAsync` is
  read" (line ~166), but `_selectedUnitId` is not resolved until ~line 197, where a strata
  property re-anchors it. Prefilling at the plan's location would key the lookup on the wrong
  scope. Moved after the derivation.
- **Plan Task 5's Step 4 snippet had a second bug** the implementer caught unprompted: calling
  `_prefillFor` during the loading frame stamps `_prefilledScope` against an empty placeholder
  and permanently blocks the real write. Gated on resolved data instead.
- **The spec's "Where the figures come from" says to sum loan `ExpenseLine`s. It is wrong** and
  the plan already overrode it. Expense amounts are ownership-share-scaled at the engine's
  per-property choke point, so a 50%-owned property would display half of what the landlord
  typed — in a row whose whole purpose is letting them verify their own entry. The row reads
  `manualLoanEntriesProvider`. **Do not "simplify" this back.**

---

## Separately outstanding — not this workstream's job

**The whole-branch review has never completed.** `git merge-base main HEAD` is `4ab8c69` —
**49 commits, ~9,400 insertions**, spanning several earlier workstreams (service
decomposition, upload progress, fact-aware answering, the earlier loan-input work). An
earlier attempt died on a weekly usage limit and returned no findings; the stale review
package from that attempt is now 12+ commits out of date and should not be reused.

The review run in this session was **plan-scoped** (`221672d..af4dfe8`, 12 files, ~1,800
insertions) and deliberately did not touch the rest of the branch.

**Also still open:**
- Nothing is pushed.
- `Remove-Item -Recurse -Force "C:\Users\user\Desktop\Documind\.venv"` — verified safe (and it
  actually fixes `run_all.ps1:59`, which otherwise prefers that broken interpreter). The
  permission layer blocked the deletion from this session.
- Three hosted LLM boundaries remain unscrubbed for PII: `_narrate_finance_summary`,
  `ConversationRouter`'s prompt, `CategoryPredictor`'s prompt. Documented honestly in
  `backend/rag/pii_scrub.py` rather than fixed.
- `backend/END_TO_END_FLOW.md` is stale regarding `CHAT_PROVIDER` (untracked file, left alone).

---

## Working notes for the next session

- Run tests as `flutter test` from `residex_app/`. Backend tests are
  `py -3.11 -m pytest tests/ -q` from `backend/`, system Python, **not** a venv.
- The full per-task record — every fix round, every finding, every ruling — is at
  `.superpowers/sdd/2026-08-05-loan-entry-method/progress.md`, with the individual task
  reports beside it. That directory is git-ignored scratch; `git clean -fdx` destroys it.
- **Never** `git add -A` on this branch. It carries unrelated uncommitted WIP
  (`backend/rexAI.txt`, `demo_documents/` churn) that must not be swept into a commit.
- Never touch, modify, or commit `backend/rexAI.txt`, `backend/scripts/diagnose_ayer8_lease.py`,
  or `backend/scripts/fix_ayer8_lease_facts.py`.
- `.env` files are permission-protected — do not read them.
- No emoji in the app UI; icon glyphs only. Project convention, applied retroactively.
