# Handoff — Production Push & Current State (2026-08-04)

**One-line status:** The scope-reduced landlord finance/DocuMind app is now `origin/main`
on GitHub; the old broader product is archived; phase-1 security hardening is merged
and pushed. Work paused here for a round of fixes (see §5).

---

## 1. Git & remote state (post-push — VERIFIED against live remote)

Remote: `origin` = https://github.com/Jwongjs/Residex.git

| Remote branch | Commit | What it is |
|---|---|---|
| `main` | `4ab8c69` | **New source of truth.** The scope-reduced landlord finance/DocuMind back-office (271 commits of work). |
| `archive/full-product-main` | `ae4c52b` | **The OLD, broader Residex** — tenant app (64 files), community, gamification, maintenance ticketing, multi-panel REX AI (`1-Command`/`2-Finance`/`3-REX`/`5-Community`), lease generator, conversation router/store. Fully recoverable. |
| `feat/finance-tab-restructure` | `4ab8c69` | Same as `main` (the branch this all happened on). |

- **The two scopes were NOT merged.** `main` and `archive/full-product-main` share ancestor
  `7baf05b "Updated documind, create mock ups for other 3 rex panels"`, then diverged:
  main is 271 commits down the finance path, the archive is 11 commits down the full-product
  path. Overwriting main with the finance version was the deliberate Option B choice
  (archive first, then force-push) — chosen over merging the two product scopes.
- **To get the old product back** (any file or the whole thing):
  `git checkout archive/full-product-main -- <path>` or branch off it:
  `git switch -c full-product origin/archive/full-product-main`.
- Local `main` and `feat/finance-tab-restructure` both point at `4ab8c69`. Still checked
  out on `feat/finance-tab-restructure`.

## 2. What `main` contains now (today's work, newest first)

```
4ab8c69 feat(finance): missing-documents nudge, period_end folders, portfolio polish
943960f fix(units): degrade benign permission-denied to empty during property creation
bbcaff7 feat(finance): split unit view into separate Net contribution + Statutory dropdowns
1e53077 fix(finance): scale Net P/L by ownership share so statutory is never below it
42f729a refactor(finance): make Net P/L the property headline, statutory subtle
f25dc16 feat(documents): add a top-level Loans & Financing folder
43dc4ec feat(finance): restore statutory income display on unit and property views
a5e042c feat(finance): show a provisional statutory figure on incomplete years
```

## 3. Uncommitted local WIP (66 files — intentionally NOT committed)

These live only in the working tree; they were deliberately excluded from `4ab8c69`
(the rule was "commit genuine app changes, leave scratch/data out"). None are code
dependencies of anything committed (verified: no leftover `.dart`; the leftover `.py`
are imported by nothing committed).

- **Demo data:** all `demo_documents/**` add/delete churn, `backend/fact_chat.jsonl`, `netsim.ini`
- **STALE pre-decomposition duplicates — safe to delete:** `backend/rag/expense_scanner.py`,
  `backend/rag/groq_chat.py`. The live versions are the tracked `rag/documents/expense_scanner.py`
  and `rag/providers/groq_chat.py`.
- **Scratch diagnostics:** `backend/scripts/diagnose_ayer8_lease.py`, `backend/scripts/fix_ayer8_lease_facts.py`
- **Notes/docs:** `backend/rexAI.txt`, `backend/END_TO_END_FLOW.md`, and many `docs/**` SDD plan/spec/handoff `.md`

## 4. Production-hardening status

**Phase 1 (auth + rules) — DONE, merged, and now pushed.**
- Closed the critical IDOR: `landlord_id` removed from the wire on all 22 routes; router-level
  fail-closed Firebase auth; `AuthedClient` token chain (force-refresh + retry-once, 401/code
  interceptor wired to sign-out).
- Firestore + Storage rules deployed to project `residex-2ebd8` and **on-device verified 2026-08-03**:
  properties list, existing-property→units, `getPropertyById`, and create/update/delete all work
  under the owner-scoped rules.
- The units create-race `permission-denied` (parent property not yet visible to the rule) was
  fixed in `943960f` — `isBenignUnitsPermissionDenied` degrades that one error to an empty list.
- Leaked-keys item is **closed** — history was scrubbed last session; no key values remain.

**Phase 2 (deferred — the hosting fork):** where document processing runs (Cloud Run + hosted
models vs Oracle free VM), release signing (currently debug keystore — Play rejects), App Check
debug→playIntegrity + backend enforcement, real backend URL over TLS (currently `http://10.0.2.2:8000`),
rate limiting, privacy policy + Play data-safety, invite-only signup, pin requirements.txt,
tighten CORS. **No CI/CD exists** (`.github/workflows/` absent) — optional phase-2 add.

## 5. Pending fixes (this pause)

Six defects from a landlord testing session, specced in
[docs/superpowers/specs/2026-08-04-landlord-testing-fixes-design.md](superpowers/specs/2026-08-04-landlord-testing-fixes-design.md)
(commit `cd357b0`). Two further defects were found while investigating and are
folded into the same spec.

- [ ] **Loan figure entered at the property panel never reaches the unit.** Two
      causes: the engine blanks property-scope lines for the synthetic
      whole-property scope (`finance_engine.py:1044-1047`), and the scope
      dropdown offers "Whole property" on strata properties where a loan is
      per-title/per-unit.
- [ ] **Total Received and Total Expenses ignore ownership share %.** `share` is
      applied only to `net_pl` and `statutory` today (`finance_engine.py:1146-1153`);
      it moves to a per-property choke point covering every figure.
- [ ] **Financial terms inconsistent across the three levels.** One glossary:
      Finance tab prefixes "Overall", property/unit use the bare term.
      "Expenses" comes to mean landlord cash out everywhere (the property panel
      currently shows deductible-only under the same word).
- [ ] **DocuMind answers "I couldn't search your documents. Please check your
      Firestore vector index."** for a question about an uploaded tenancy
      agreement. Diagnosis-first — the handler reports every exception as an
      index problem (`ask_orchestrator.py:462-476`), so the symptom identifies
      nothing.
- [ ] **Remove the `2025 · 2 missing` coverage bubble** on the property panel
      (`finance_screen.dart:269-313`) — redundant with `DocumentNudgeBanner`.
- [ ] **Rename the bottom line** to "Overall Net Profit/Loss" (Finance tab) and
      "Net Profit/Loss" (property panel).

Found while investigating, same spec:

- [ ] **`property_expense_lines` is rendered nowhere** — property-scope expenses
      move the totals but appear in no drill-down.
- [ ] **Property-block statutory income and the Finance-tab statutory total use
      different expense bases**, so the blocks do not sum to the headline.
      Flagged in the spec as the reviewer's call (§2.4).

## 6. Resume / recovery

- **Tests (green baseline):** backend `cd backend && python -m pytest -q` → 476 passed;
  Flutter `cd residex_app && flutter test` → 211 passed + 1 pre-existing unrelated failure
  (`widget_test.dart` "Counter increments" template boilerplate — references a `MyApp` counter
  this app doesn't have).
- **Isolate task commits** on this branch: the working tree carries unrelated multi-session WIP —
  stage explicit paths, never `git add -A`.
- **Recover the old product:** `git switch -c full-product origin/archive/full-product-main`.
