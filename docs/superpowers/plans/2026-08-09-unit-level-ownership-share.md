# Unit-Level Ownership Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a single unit carry its own ownership share, so a landlord who co-owns one unit in a block they otherwise own outright files a correct statutory figure.

**Architecture:** `ownership_share` stays on the property as the default; `Unit` gains an optional override. The engine stops applying one property-wide multiply and instead resolves a share per income scope and per expense line, then sums the already-scaled parts. Each unit block emits its resolved `ownership_share`, which the app renders as a badge on the property card, the unit row, and the unit drill-down.

**Tech Stack:** Python 3.11 + pytest (`backend/`), Flutter/Dart + Riverpod (`residex_app/`), Firestore, Pydantic response models.

## Global Constraints

- **Source spec:** `docs/superpowers/specs/2026-08-09-unit-level-ownership-share-design.md`. Every design decision comes from there; do not re-litigate them.
- **This plan assumes `docs/superpowers/plans/2026-08-09-unit-panel-share-reconciliation.md` is fully complete and committed.** It builds directly on that plan's output: the engine local `gross_income`, the emitted `gross_income` / `full_gross_income` keys, the `_scaled_month_rows` helper, `UnitFinance.grossIncome` / `fullGrossIncome`, and the recovery exemption in `s_received`. If any of those are missing, **stop and report** — do not implement them here.

> ### ⚠ CORRECTIONS — read before writing any code (added 2026-08-11)
>
> Plan 1 **landed 2026-08-10** (`88b0088..d91b653`), but **not as its own text
> specified** — four defects were found and fixed during execution. This plan was
> written against plan 1's *text*, so several of its code blocks below quote
> shapes that no longer exist. **Executing them verbatim would undo plan 1's
> fixes.** See plan 1's "Amendments during execution" section for the full
> reasoning.
>
> **C1 — `display_landlord_scaled` / `display_deductible_scaled` NO LONGER EXIST.**
> They were deleted. This plan reinstates them at `:392-396` and subtracts them at
> `:422-424`. Do not. The landed engine computes `scaled_lines = _scaled_lines(...)`
> **once**, emits that same list as `expense_lines`, and builds both totals by
> summing `l["amount"]` over it. Reinstating the unrounded sums reintroduces a
> one-cent column that does not add up — the exact defect plan 1 existed to remove.
>
> **C2 — `gross_income` is NOT `_round2(share * (actual_sum + derived_sum))`.**
> This plan uses that round-the-sum form at `:415`. The landed engine sums the
> **rounded rendered rows**: `scaled_months = _scaled_month_rows(...)` computed
> once, emitted as `months`, and `gross_income = _round2(sum(m["amount"] for m in
> scaled_months if m["source"] in ("actual","derived")))`. `full_gross_income` is
> built the same way from each row's `full_amount`. Round-the-sum and
> sum-the-rounded disagree at ordinary values (rent 1000.01 x12 at share 0.5:
> strip 6000.00 vs 6000.06), which renders a strip that does not sum to the
> header above it. Keep the sum-the-rounded form when you swap `share` for
> `scope_share`.
>
> **The general rule both corrections express: build every emitted total from the
> same rounded list you emit.** Apply it to any new per-scope arithmetic here.
>
> **C3 — every new payload field must be added to `backend/models/documind_models.py`
> in the same change.** `/documind/finance/summary` declares
> `response_model=FinanceSummaryResponse`, so FastAPI **silently drops** any key the
> schema does not declare. Plan 1 shipped four fields the app never received; the
> panel rendered `Gross income RM 0.00` with both suites green. This plan's Task 5
> already adds `ownership_share` there — good — but treat it as mandatory, not
> incidental. `backend/tests/test_finance_response_contract.py` now fails if any
> engine key is dropped, so you will be told; the running server must also be
> restarted to pick up schema changes.
>
> **C4 — fixture blindness bit plan 1 three times, inside its own tests.** Before
> accepting any test this plan hands you, ask "at these exact values, does this go
> red if I revert the implementation?" and watch it fail. One of plan 1's gate
> tests was *structurally* unfailable. This plan's own uniform-share warning below
> is the same rule; apply it to rounding fixtures too, not just share fixtures.
>
> **C5 — in scope for this plan, newly:** `finance_screen.dart:322-332` and
> `:387-390` do arithmetic on `block.ownershipShare`. Correct while share is
> property-level; they break the moment a unit overrides it. Fix them here.
>
> ### ⚠ SECOND ROUND OF CORRECTIONS (added 2026-08-11, after `2a43534..4a1179f`)
>
> C1–C5 were written against plan 1's output. Three further commits landed after
> them — the property-card reconciliation work (`2a43534`, `8bfec44`, `4a1179f`)
> — and moved the same ground again.
>
> **C6 — `landlord_paid` and `direct` NO LONGER CALL `_line_share` AT ALL.**
> Task 3 Step 4 item 3 quotes both as `sum(_line_share(l, share) * l["amount"]
> for l in expense_lines ...)`. That is pre-`2a43534` code. The landed engine
> builds `scaled_expense_lines = _scaled_lines(expense_lines, share)` **once**
> (`finance_engine.py:1281`) and sums `l["amount"]` off that rounded list for
> both `landlord_paid` (`:1285-1287`) and `direct` (`:1321-1323`) — the
> property-level mirror of what plan 1 did inside the unit block. Rewriting them
> as the plan says reinstates the unrounded round-the-sum totals and undoes all
> three of those commits. **This is C1/C2's defect class for the third time.**
>
> The correct edit at those two sites is **none**. Change only
> `_scaled_lines(expense_lines, share)` → `_scaled_lines(expense_lines,
> share_for)` at `:1281` and both totals become per-line correct for free,
> because they already sum the list `share_for` now weights.
>
> **The sites that DO still need the `share_for` swap** (each still passes the
> scalar `share`): `:1178` (the unit-scope proration), `:1270` (the
> property-level proration), `:1420-1422` (the `expense_breakdown`
> accumulator), and `:1458` (`property_expense_lines`). Task 3 Step 4's items 1,
> 2 and 4 are correct as written; only item 3 is superseded.
>
> **C7 — every line number in this plan is shifted by roughly +80.** The plan
> was written against a tree five commits older. Actual positions at `4a1179f`:
> `_line_share` `:437-441`, `_scaled_lines` `:444-466`, `_scaled_month_rows`
> `:469`, the scopes list ~`:1140`, the unit block's `scaled_lines` /
> `scaled_months` `:1217-1218`, `s_received` / `s_derived` / `s_outstanding`
> `:1336-1338` (NOT `:1274-1276`), the caveat ~`:1390`. **Locate every edit by
> reading the surrounding code, never by line number.**
>
> **C8 — Task 2 Step 6 must not disturb the round-once-then-subtract block.**
> `s_received`/`s_derived`/`s_outstanding` are now immediately followed by
> `r_received = _round2(s_received)` and siblings (`:1343-1360`), with a comment
> explaining why `s_prorated` alone stays exact. Task 2 Step 6 replaces only the
> three `s_*` assignments; everything below them stays exactly as it is.
>
> **C9 — accepted scope decision (human, 2026-08-11): the card-vs-unit rounding
> gap stays deferred.** The property card's `received_rent` is round-the-sum of
> raw scalars while each unit's `gross_income` is sum-the-rounded of its month
> rows (at share 0.5, rent 1000.01×12: card 6000.06, units 6000.00). Task 2
> makes `prop_actual`/`prop_derived` accumulate per-scope scaled scalars — still
> not the rounded month rows — so the gap survives this plan **by design**. Do
> not close it here; do not write a test that pins either side to the other.
> The two figures are not co-displayed on any screen this plan touches.

- **Manual precondition:** before Task 1, open a co-owned property in the running
  app and confirm plan 1 reconciles against **real** data — gross minus expenses
  equals the rendered total, the sub-label reads `your N% of RM …`, and the strip
  heading names the share. Plan 1's response-model defect was invisible to 631
  backend tests, 321 Flutter tests and nine code reviews, and visible instantly on
  screen. Do not build on an unverified base.
- **Never run `git add -A` on this branch.** An unrelated fact-aware-answering / citation-precision workstream is live and uncommitted in the working tree, including hunks inside `backend/rag/documind_service.py` and `backend/tests/test_documind_service_flows.py`. Every commit step below names its exact files; add only those.
- **Never touch** `backend/rexAI.txt` or `backend/scripts/{diagnose,fix}_ayer8_lease*.py`.
- `residex_app/test/widget_test.dart` — "Counter increments smoke test" is a **pre-existing boilerplate failure** and must never be fixed. Flutter runs are green at **1 failed**, that one.
- **The loan exemption is unchanged.** `_LOAN_EXEMPT_SUBTYPES` (`finance_engine.py:434`) and `_line_share`'s early return stay exactly as they are. A loan line is unscaled at any share, property or unit.
- **Firestore field naming:** the unit override is stored as **`ownership_share`** (snake_case), not `ownershipShare`. This is deliberate and matches the property document, whose share is also snake_case inside an otherwise camelCase collection (`property_model.dart:149`, read back at `property_directory.py:55`). The backend reads the snake_case key. Renaming it to match the unit's other camelCase fields silently breaks every engine calculation with a fully green Dart suite.
- **Test-fixture rule, from the spec:** a fixture where every unit resolves to the same share **cannot fail** against any part of this — uniform share is exactly the case where the old single-multiply and the new per-scope arithmetic agree. Every new backend test below gives two units different shares.
- Backend suite: `cd backend && py -3.11 -m pytest tests/ -q` → **0 failed**.
- Flutter suite: `cd residex_app && flutter test` → **1 failed** (the boilerplate one above).
- Analyzer: `cd residex_app && flutter analyze` → **0 errors** (warnings/infos are pre-existing and fine).

## File Structure

| File | Responsibility in this plan |
| --- | --- |
| `backend/rag/property_directory.py` | Reads the unit's stored `ownership_share` out of Firestore (Task 1) |
| `backend/rag/finance/finance_engine.py` | The whole engine change: `_share_for_unit`, per-scope income, per-line expenses, the caveat (Tasks 2–4) |
| `backend/models/documind_models.py` | `UnitFinance.ownership_share` on the API response (Task 5) |
| `residex_app/.../domain/entities/unit.dart` + `data/models/unit_model.dart` | The stored override, Dart side (Task 5) |
| `residex_app/.../domain/entities/finance_summary.dart` + `data/models/finance_summary_model.dart` | The emitted resolved share, Dart side (Task 5) |
| `residex_app/.../widgets/common/share_badge.dart` | **New.** One badge widget, so all three render sites share a vocabulary (Task 6) |
| `residex_app/.../screens/3-Finance/finance_screen.dart` | Range badge, footnote, unit-row badge (Task 6) |
| `residex_app/.../screens/3-Finance/unit_finance_detail_screen.dart` | Badge beside the property name (Task 7) |
| `residex_app/.../screens/4-Portfolio/units_screen.dart` | Where the landlord sets it (Task 8) |

---

### Task 1: The stored unit share reaches the engine

Nothing computes yet. This task only makes the value available: `list_property_units` currently returns `unit_id` + `label` and throws the rest away, so the engine cannot see a unit override even once one is stored.

**Files:**
- Modify: `backend/rag/property_directory.py:19-38`
- Modify: `backend/tests/test_documind_service_flows.py:98-112` (widen the unit fake) and append a test class
- Test: `backend/tests/test_documind_service_flows.py`

**Interfaces:**
- Consumes: nothing.
- Produces: each dict returned by `list_property_units` gains `"ownership_share": Optional[float]` — a float when the unit document stores one, **`None` when it does not**. Task 2 reads this key off the rows in `units_by_property`.

> **`None` is load-bearing.** It means "inherit the property's share". A missing override must **not** become `1.0` — a property at 50% whose units have never been touched would then render every unit at 100%, which is both wrong and the exact opposite of today's behaviour. Task 2's test 6 fails if this returns `1.0`.

- [ ] **Step 1: Widen the unit test fake**

In `backend/tests/test_documind_service_flows.py`, replace `_FakeUnitSnapshot` and `_FakeUnitsCollection` (`:98-112`) with:

```python
class _FakeUnitSnapshot:
    def __init__(self, unit_id, label, ownership_share=None):
        self.id = unit_id
        self._label = label
        self._ownership_share = ownership_share

    def to_dict(self):
        data = {"label": self._label}
        # Absent, not null: a unit that has never had a share set stores no
        # field at all, and `None` is what tells the engine to inherit.
        if self._ownership_share is not None:
            data["ownership_share"] = self._ownership_share
        return data


class _FakeUnitsCollection:
    def __init__(self, units):
        self._units = units

    def stream(self):
        return [
            _FakeUnitSnapshot(u["unit_id"], u["label"], u.get("ownership_share"))
            for u in self._units
        ]
```

Every existing caller passes `{"unit_id": ..., "label": ...}` dicts, so `u.get("ownership_share")` is `None` for all of them and their behaviour is unchanged.

- [ ] **Step 2: Write the failing test**

Append to `backend/tests/test_documind_service_flows.py`, at the end of the file:

```python
class UnitOwnershipShareLookupTests(unittest.IsolatedAsyncioTestCase):
    """The unit override has to survive the Firestore read. `None` means
    inherit the property's share — coercing it to 1.0 here would override a
    partial property share for every untouched unit."""

    async def test_stored_unit_share_is_returned(self):
        fake_db = _FakeDB(units=[
            {"unit_id": "u1", "label": "A-1", "ownership_share": 0.5},
        ])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertEqual(rows[0]["ownership_share"], 0.5)

    async def test_absent_unit_share_is_none_not_one(self):
        fake_db = _FakeDB(units=[{"unit_id": "u2", "label": "A-2"}])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertIsNone(rows[0]["ownership_share"])

    async def test_unparseable_unit_share_is_none(self):
        fake_db = _FakeDB(units=[
            {"unit_id": "u3", "label": "A-3", "ownership_share": "half"},
        ])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertIsNone(rows[0]["ownership_share"])

    async def test_label_and_id_still_returned(self):
        fake_db = _FakeDB(units=[{"unit_id": "u1", "label": "A-1"}])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertEqual(rows[0]["unit_id"], "u1")
        self.assertEqual(rows[0]["label"], "A-1")
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::UnitOwnershipShareLookupTests -v`
Expected: FAIL — `KeyError: 'ownership_share'` on the first three; `test_label_and_id_still_returned` passes already (it is a guard).

- [ ] **Step 4: Read the field**

In `backend/rag/property_directory.py`, replace the body of `list_property_units` (`:19-38`) with:

```python
def list_property_units(db, property_id: str) -> List[Dict]:
    """Unit ids + labels + optional ownership share for a property. Empty on
    lookup failure so a units outage degrades to unscoped search instead of
    blocking.

    `ownership_share` is None when the unit stores none, which means "inherit
    the property's share". It is deliberately NOT defaulted to 1.0: a unit
    that has never been touched inside a 50%-owned property must follow the
    property, not silently claim full ownership.
    """
    try:
        snapshots = (
            db.collection('properties')
            .document(property_id)
            .collection('units')
            .stream()
        )
        rows = []
        for snap in snapshots:
            data = snap.to_dict() or {}
            raw = data.get('ownership_share')
            try:
                share = None if raw is None else float(raw)
            except (TypeError, ValueError):
                share = None
            rows.append({
                "unit_id": snap.id,
                "label": data.get('label') or snap.id,
                "ownership_share": share,
            })
        return rows
    except Exception as e:
        print(f"⚠️ Unit lookup failed for property {property_id}: {e}")
        return []
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::UnitOwnershipShareLookupTests -v`
Expected: PASS, 4 tests.

- [ ] **Step 6: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** The new key also flows into the chat/ask path (`ask_orchestrator.py:110`), which only reads `unit_id` and `label` — if anything there breaks on an extra key, stop and report rather than removing the key.

- [ ] **Step 7: Commit**

```bash
git add backend/rag/property_directory.py backend/tests/test_documind_service_flows.py
git commit -m "feat(finance): read the unit-level ownership share override"
```

---

### Task 2: The engine resolves a share per income scope

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` — new module-level helper after `_line_share` (`:441`); the property loop's income section
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `units_by_property[pid][i]["ownership_share"]` from Task 1.
- Produces:
  - `_share_for_unit(unit_id: Optional[str], unit_shares: Dict[str, float], property_share: float) -> float`
  - a per-property local `share_for(unit_id) -> float`, which Task 3 also uses
  - each unit block gains `"ownership_share": float` — the resolved share for that scope. Task 5 maps it; Tasks 6–7 render it.
- Expenses are deliberately **not** converted here; they are Task 3. Between the two tasks the suite stays green because no existing fixture sets a unit share, so every scope resolves to the property's own share and every figure is unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_finance_engine.py`:

```python
class UnitLevelShareIncomeTests(unittest.TestCase):
    """Income is scaled per scope and summed, not summed and scaled once.
    Every fixture here gives the two units DIFFERENT shares — at a uniform
    share the old arithmetic and the new arithmetic agree exactly, so a
    same-share fixture cannot fail against any of this."""

    def _docs(self):
        return [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u1"),
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u2"),
        ]

    def _units(self, u1_share=None, u2_share=None):
        rows = [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]
        if u1_share is not None:
            rows[0]["ownership_share"] = u1_share
        if u2_share is not None:
            rows[1]["ownership_share"] = u2_share
        return {"p1": rows}

    def _blocks(self, property_share, u1_share=None, u2_share=None,
                payment_exceptions=None):
        result = _summary(
            self._docs(), [_prop("p1", "Block", share=property_share)],
            units=self._units(u1_share, u2_share),
            payment_exceptions=payment_exceptions,
        )
        block = result["properties"][0]
        by_id = {u["unit_id"]: u for u in block["units"]}
        return block, by_id

    def test_each_unit_uses_its_own_share_for_gross_income(self):
        # u1 co-owned at 50%, u2 owned outright inside a property at 100%.
        block, by_id = self._blocks(1.0, u1_share=0.5)
        self.assertAlmostEqual(by_id["u1"]["gross_income"], 6000.0, places=2)
        self.assertAlmostEqual(by_id["u2"]["gross_income"], 12000.0, places=2)

    def test_received_rent_is_the_sum_of_the_scaled_units(self):
        # NOT either share applied to the combined 24000. 6000 + 12000.
        block, _ = self._blocks(1.0, u1_share=0.5)
        self.assertAlmostEqual(block["received_rent"], 18000.0, places=2)

    def test_unit_block_emits_its_resolved_share(self):
        _, by_id = self._blocks(1.0, u1_share=0.5)
        self.assertEqual(by_id["u1"]["ownership_share"], 0.5)
        self.assertEqual(by_id["u2"]["ownership_share"], 1.0)

    def test_a_unit_without_an_override_inherits_the_property_share(self):
        # THE INHERIT GATE. Property at 50%, u1 explicitly owned outright,
        # u2 untouched. Reading the stored share as
        # `float(u.get("ownership_share") or 1.0)` gives u2 1.0 and makes this
        # 24000 — and nothing else in this file notices.
        block, by_id = self._blocks(0.5, u1_share=1.0)
        self.assertEqual(by_id["u2"]["ownership_share"], 0.5)
        self.assertAlmostEqual(by_id["u2"]["gross_income"], 6000.0, places=2)
        self.assertAlmostEqual(by_id["u1"]["gross_income"], 12000.0, places=2)
        self.assertAlmostEqual(block["received_rent"], 18000.0, places=2)

    def test_full_gross_income_follows_the_units_own_share(self):
        _, by_id = self._blocks(1.0, u1_share=0.5)
        self.assertAlmostEqual(by_id["u1"]["full_gross_income"], 12000.0, places=2)
        self.assertNotIn("full_gross_income", by_id["u2"])

    def test_month_rows_are_scaled_by_the_units_own_share(self):
        _, by_id = self._blocks(1.0, u1_share=0.5)
        jan_u1 = next(m for m in by_id["u1"]["months"] if m["month"] == 1)
        jan_u2 = next(m for m in by_id["u2"]["months"] if m["month"] == 1)
        self.assertAlmostEqual(jan_u1["amount"], 500.0, places=2)
        self.assertAlmostEqual(jan_u1["full_amount"], 1000.0, places=2)
        self.assertAlmostEqual(jan_u2["amount"], 1000.0, places=2)
        self.assertNotIn("full_amount", jan_u2)

    def test_outstanding_rent_sums_each_units_scaled_outstanding(self):
        # One unpaid month on the 50% unit and one on the 100% unit:
        # 500 + 1000, not the property share applied to 2000.
        block, _ = self._blocks(
            1.0, u1_share=0.5,
            payment_exceptions=[
                _exception("p1", "2025-03", unit_id="u1"),
                _exception("p1", "2025-04", unit_id="u2"),
            ],
        )
        self.assertAlmostEqual(block["outstanding_rent"], 1500.0, places=2)

    def test_whole_property_scope_uses_the_property_share(self):
        # A landed house has no unit rows at all; the synthetic scope must
        # still find the property's share.
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01",
                                     "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House", share=0.5)])
        unit = result["properties"][0]["units"][0]
        self.assertIsNone(unit["unit_id"])
        self.assertEqual(unit["ownership_share"], 0.5)
        self.assertAlmostEqual(unit["gross_income"], 6000.0, places=2)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitLevelShareIncomeTests -v`
Expected: FAIL — `KeyError: 'ownership_share'` on the two tests that read it, and wrong figures (24000 / 12000 / 2000) on the rest.

- [ ] **Step 3: Add the resolver**

In `backend/rag/finance/finance_engine.py`, immediately after `_line_share` ends at `:441`:

```python
def _share_for_unit(
    unit_id: Optional[str],
    unit_shares: Dict[str, float],
    property_share: float,
) -> float:
    """The ownership share that applies to an income scope or an expense line.

    A unit's own share wins. Anything not attributable to a unit — the
    synthetic whole-property income scope, a building-wide loan or quit rent —
    falls back to the property's own share, because it is not attributable to
    any one unit's co-ownership arrangement.

    A unit with no stored override is absent from `unit_shares` (not present
    as 1.0), so it inherits. That distinction is the whole point: a 50%-owned
    property whose units were never touched must stay at 50%.
    """
    if unit_id is None:
        return property_share
    return unit_shares.get(unit_id, property_share)
```

- [ ] **Step 4: Build the per-property share map**

In the property loop, immediately after the `scopes` list is built (after `finance_engine.py:1107`, the line `scopes.append({"unit_id": None, "label": "Whole property"})` and its closing `if` block), insert:

```python
        # Unit-level overrides for this property. Only units that actually
        # store a share appear here — absence means "inherit `share`", which
        # is why this is not a dict comprehension with a 1.0 default.
        unit_shares: Dict[str, float] = {}
        for u in units_by_property.get(pid, []):
            raw = u.get("ownership_share")
            if raw is None:
                continue
            try:
                unit_shares[u["unit_id"]] = float(raw)
            except (TypeError, ValueError):
                continue

        def share_for(unit_id: Optional[str]) -> float:
            # Closes over this iteration's `unit_shares` and `share`, and is
            # only ever called within this iteration.
            return _share_for_unit(unit_id, unit_shares, share)
```

- [ ] **Step 5: Scale income per scope**

Inside `for scope in scopes:`, immediately after the `_scope_income(...)` call that unpacks `month_rows, rented, actual_sum, derived_sum, vacant, derived, unpaid`, add:

```python
            scope_share = share_for(scope["unit_id"])
```

Then make these five edits inside the scope loop. Replace every `share` with `scope_share`:

1. The proration accumulator — `fraction * sum(_line_share(l, share) * ...)` becomes:

```python
            prorated_expenses += fraction * sum(
                _line_share(l, scope_share) * l["amount"] for l in unit_lines if l["deductible"]
            )
```

2. and 3. The two display sums:

> **SUPERSEDED — see correction C1.** These two locals were **deleted** by plan 1.
> Do not reinstate them. The landed engine sums the rounded amounts off the
> emitted `scaled_lines` list instead. Take only the `share` → `scope_share`
> substitution idea from this block, applied to the code that is actually there.

```python
            display_deductible_scaled = sum(
                _line_share(l, scope_share) * l["amount"]
                for l in display_lines if l["deductible"]
            )
            display_landlord_scaled = sum(
                _line_share(l, scope_share) * l["amount"]
                for l in display_lines if l["paid_by_landlord"]
            )
```

4. The two income accumulators, which now carry **already-scaled** values:

```python
            # Scaled here, per scope, instead of once at the property level —
            # each unit may carry its own share, so a total can no longer be
            # correctly scaled after the fact.
            prop_actual += scope_share * actual_sum
            prop_derived += scope_share * derived_sum
```

5. The unit block itself. Replace `share` with `scope_share` in the three places the previous plan left it, and add the new key:

> **SUPERSEDED — see corrections C1 and C2.** The block below quotes plan 1's
> *original* shape, not what landed. `gross_income` is now summed from the rounded
> `scaled_months` rows (not `_round2(scope_share * (actual_sum + derived_sum))`),
> and both totals are summed off the emitted `scaled_lines` (not
> `display_*_scaled`). Apply the `share` → `scope_share` substitution to the
> current code and keep both sum-the-rounded forms. `ownership_share` is the one
> genuinely new key here — and it must also go into
> `backend/models/documind_models.py` (correction C3).

```python
            gross_income = _round2(scope_share * (actual_sum + derived_sum))
            block = {
                "unit_id": scope["unit_id"],
                "label": scope["label"],
                "ownership_share": scope_share,
                "rented_months": rented,
                "gross_income": gross_income,
                "contribution": _round2(gross_income - display_landlord_scaled),
                "statutory_contribution": _round2(
                    gross_income - display_deductible_scaled
                ),
                "months": _scaled_month_rows(month_rows, scope_share),
                "missing_invoice_months": vacant,
                "expense_lines": _scaled_lines(display_lines, share),
                "loan_status": loan_status_by_unit.get(scope["unit_id"]),
            }
            if scope_share < 1.0:
                block["full_gross_income"] = _round2(actual_sum + derived_sum)
            unit_blocks.append(block)
```

> `"expense_lines": _scaled_lines(display_lines, share)` is left on the property share **on purpose** — `_scaled_lines` still takes a scalar until Task 3 changes its signature. Leaving it here keeps this task's diff to income only.

6. The outstanding accumulator, further down in the `for m, reason, state, billed in unpaid:` loop:

```python
                    if billed:
                        prop_outstanding += scope_share * billed
```

- [ ] **Step 6: Stop scaling the accumulated income again**

Below the scope loop, `prop_actual`, `prop_derived` and `prop_outstanding` are now already scaled, so the property-level multiply must go. Replace the three assignments (`finance_engine.py:1274-1276`, as left by the previous plan's Task 4):

```python
        s_received = share * (prop_actual + prop_derived) + prop_recovered
        s_derived = share * prop_derived
        s_outstanding = share * prop_outstanding
```

with:

```python
        # prop_actual / prop_derived / prop_outstanding arrive already scaled,
        # each by its own scope's share. Recovered rent is exempt (it is typed
        # in by the landlord at their own share — see the recovery sheet), so
        # nothing here is multiplied again.
        s_received = prop_actual + prop_derived + prop_recovered
        s_derived = prop_derived
        s_outstanding = prop_outstanding
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitLevelShareIncomeTests -v`
Expected: PASS, 8 tests.

- [ ] **Step 8: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** No existing fixture sets a unit share, so every scope resolves to the property's own share and every existing figure is unchanged. If anything fails, stop and report it — do not adjust the failing test.

- [ ] **Step 9: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): scale rental income per unit share, then sum"
```

---

### Task 3: The engine resolves a share per expense line

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` — `_scaled_lines` (`:444-466`) and the remaining property-level `_line_share` call sites
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `share_for(unit_id)` from Task 2.
- Produces: `_scaled_lines(lines: List[Dict[str, Any]], share_for: Callable[[Optional[str]], float]) -> List[Dict[str, Any]]` — **the second parameter changes from a float to a callable**. All four call sites change in this task; no later task calls it.

> **The trap, from the spec.** `direct`, `landlord_paid` and `expense_breakdown` each sum across *all* of a property's lines at once, mixing units. Leaving any one of them on the property share leaves a total that disagrees with the lines rendered beneath it — and at a uniform share every existing test still passes, because that is exactly where both formulas give the same answer. Test 1 below is the gate that catches it.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_finance_engine.py`:

```python
class UnitLevelShareExpenseTests(unittest.TestCase):
    """An expense line's share follows the unit it belongs to; a line with no
    unit follows the property. Mixed shares throughout — a uniform-share
    fixture cannot distinguish the per-line conversion from the old one."""

    def _units(self, u1_share=None, u2_share=None):
        rows = [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]
        if u1_share is not None:
            rows[0]["ownership_share"] = u1_share
        if u2_share is not None:
            rows[1]["ownership_share"] = u2_share
        return {"p1": rows}

    def _mixed(self):
        # u1 co-owned at 50%, u2 outright, inside a property owned outright.
        docs = [
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 1000.0, "period_year": 2025},
            ]}, unit_id="u1"),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 2000.0, "period_year": 2025},
            ]}, unit_id="u2"),
        ]
        result = _summary(docs, [_prop("p1", "Block", share=1.0)],
                          units=self._units(u1_share=0.5))
        return result, result["properties"][0]

    def test_each_line_is_scaled_by_its_own_units_share(self):
        _, block = self._mixed()
        by_amount = sorted(l["amount"] for l in block["expense_lines"])
        self.assertEqual(by_amount, [500.0, 2000.0])

    def test_direct_expenses_reconciles_against_the_rendered_lines(self):
        # THE GATE. `direct` sums across every unit at once. Left on the
        # property share it reads 3000 while the lines beneath it read
        # 500 + 2000, and no other assertion in this file notices.
        _, block = self._mixed()
        deductible = [l for l in block["expense_lines"] if l["deductible"]]
        self.assertAlmostEqual(
            block["direct_expenses"], sum(l["amount"] for l in deductible), places=2
        )
        self.assertAlmostEqual(block["direct_expenses"], 2500.0, places=2)

    def test_landlord_expenses_reconciles_against_the_rendered_lines(self):
        # A separate summation site from `direct` and it can regress alone.
        _, block = self._mixed()
        paid = [l for l in block["expense_lines"] if l["paid_by_landlord"]]
        self.assertAlmostEqual(
            block["landlord_expenses"], sum(l["amount"] for l in paid), places=2
        )

    def test_expense_breakdown_reconciles_against_the_rendered_lines(self):
        # Asserted structurally rather than per named category, so it holds
        # for whatever categories the subtypes map to.
        result, block = self._mixed()
        totals = {}
        for line in block["expense_lines"]:
            if line["deductible"]:
                totals[line["category"]] = round(
                    totals.get(line["category"], 0.0) + line["amount"], 2
                )
        self.assertEqual(result["expense_breakdown"], totals)

    def test_a_line_carries_the_face_value_of_its_own_scaled_amount(self):
        _, block = self._mixed()
        scaled = next(l for l in block["expense_lines"] if l["amount"] == 500.0)
        whole = next(l for l in block["expense_lines"] if l["amount"] == 2000.0)
        self.assertAlmostEqual(scaled["full_amount"], 1000.0, places=2)
        self.assertNotIn("full_amount", whole)

    def test_property_level_line_uses_the_property_share_not_a_units(self):
        # Property at 50%, its one unit owned outright. The building-wide
        # line belongs to no unit, so it takes the property's 50%.
        docs = [
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 800.0, "period_year": 2025},
            ]}),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 1000.0, "period_year": 2025},
            ]}, unit_id="u1"),
        ]
        result = _summary(docs, [_prop("p1", "Block", share=0.5)],
                          units=self._units(u1_share=1.0))
        block = result["properties"][0]
        property_level = next(l for l in block["property_expense_lines"])
        self.assertAlmostEqual(property_level["amount"], 400.0, places=2)
        unit_line = next(l for l in block["expense_lines"]
                         if l["unit_id"] == "u1")
        self.assertAlmostEqual(unit_line["amount"], 1000.0, places=2)

    def test_unit_block_lines_use_that_units_share(self):
        _, block = self._mixed()
        by_id = {u["unit_id"]: u for u in block["units"]}
        self.assertAlmostEqual(by_id["u1"]["expense_lines"][0]["amount"], 500.0, places=2)
        self.assertAlmostEqual(by_id["u2"]["expense_lines"][0]["amount"], 2000.0, places=2)

    def test_loan_lines_are_unscaled_at_a_unit_share_inside_a_full_property(self):
        # The exemption is unchanged and must survive the per-line rewrite in
        # the combination the old code could not even express.
        docs = [
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 1200.0, "principal_paid": 3000.0},
                 unit_id="u1"),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 1000.0, "period_year": 2025},
            ]}, unit_id="u1"),
        ]
        result = _summary(docs, [_prop("p1", "Block", share=1.0)],
                          units=self._units(u1_share=0.5))
        by_subtype = {l["subtype"]: l for l in result["properties"][0]["expense_lines"]}
        self.assertEqual(by_subtype["interest_statement"]["amount"], 1200.0)
        self.assertEqual(by_subtype["loan_principal"]["amount"], 3000.0)
        self.assertEqual(by_subtype["maintenance"]["amount"], 500.0)
        self.assertNotIn("full_amount", by_subtype["interest_statement"])

    def test_unit_contribution_reconciles_under_mixed_shares(self):
        # The unit-scope identity from the panel spec, re-asserted where the
        # two units disagree about their share.
        _, block = self._mixed()
        for unit in block["units"]:
            landlord_paid = sum(l["amount"] for l in unit["expense_lines"]
                                if l["paid_by_landlord"])
            self.assertAlmostEqual(
                unit["contribution"], unit["gross_income"] - landlord_paid, places=2
            )
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitLevelShareExpenseTests -v`
Expected: FAIL on the lines/reconciliation tests (lines read 1000/2000 unscaled, `direct_expenses` reads 3000). `test_loan_lines_are_unscaled_at_a_unit_share_inside_a_full_property` and `test_unit_contribution_reconciles_under_mixed_shares` may already pass — they are guards, not drivers.

- [ ] **Step 3: Make `_scaled_lines` resolve per line**

Replace `_scaled_lines` (`finance_engine.py:444-466`) entirely with:

```python
def _scaled_lines(
    lines: List[Dict[str, Any]],
    share_for: Callable[[Optional[str]], float],
) -> List[Dict[str, Any]]:
    """Copy expense lines with amounts at the share that applies to each line.

    Never mutates the input. The unscaled lines stay the basis for every
    property-level sum, so scaling is applied exactly once and no sum can be
    scaled twice. `share_for` maps a line's `unit_id` to its share — a unit's
    own override, or the property's for a line belonging to no unit.

    A line whose resolved share is 1.0 is copied through unchanged and carries
    no `full_amount`, so a wholly-owned property's payload is content-identical
    to before. Below 1.0 each scaled line also carries `full_amount`, the
    source document's face value, so the app can show "your 50% of RM 1,200.00"
    beside the scaled figure. Loan lines (see _line_share) resolve to 1.0 at
    any share and so take the same unchanged path — there is no second figure
    to show.
    """
    out: List[Dict[str, Any]] = []
    for line in lines:
        line_share = _line_share(line, share_for(line.get("unit_id")))
        if line_share == 1.0:
            out.append(dict(line))
            continue
        out.append({**line,
                    "amount": _round2(line_share * line["amount"]),
                    "full_amount": _round2(line["amount"])})
    return out
```

`Callable` is already in the file's `typing` import (`finance_engine.py:13`), so no import change is needed.

> The `if share == 1.0: return list(lines)` early-out is gone — a mixed property has no single share to test. The per-line `line_share == 1.0` branch replaces it and produces content-identical dicts (copies rather than the same objects, which no assertion in the suite depends on).

- [ ] **Step 4: Route the remaining call sites through `share_for`**

Four sites still pass the scalar `share`. Change each:

1. The unit block's display lines, in the block Task 2 built:

> **Adjusted per C1.** The landed engine does not call `_scaled_lines` inline in
> the block literal; it computes `scaled_lines = _scaled_lines(display_lines,
> share)` once at `finance_engine.py:1217` and emits that same list as
> `"expense_lines": scaled_lines` (`:1236`). Change the argument at `:1217`, not
> the block literal:
>
> ```python
>             scaled_lines = _scaled_lines(display_lines, share_for)
> ```

2. The property-level proration, below the scope loop:

```python
        prorated_expenses += avg_fraction * sum(
            _line_share(l, share_for(l.get("unit_id"))) * l["amount"]
            for l in property_level_lines if l["deductible"]
        )
```

3. `landlord_paid` and `direct` — both sum across every unit:

> **SUPERSEDED — see correction C6.** Neither site calls `_line_share` any
> more. Both sum `l["amount"]` off the single rounded `scaled_expense_lines`
> list (`finance_engine.py:1281`, `:1285-1287`, `:1321-1323`). **Leave both
> sums exactly as they are.** The only edit here is one argument:
>
> ```python
>         scaled_expense_lines = _scaled_lines(expense_lines, share_for)
> ```
>
> Writing the two blocks below instead reinstates unrounded round-the-sum
> totals and undoes commits `2a43534`, `8bfec44` and `4a1179f`.

```python
        landlord_paid = sum(
            _line_share(l, share_for(l.get("unit_id"))) * l["amount"]
            for l in expense_lines if l["paid_by_landlord"]
        )
```

```python
        direct = sum(
            _line_share(l, share_for(l.get("unit_id"))) * l["amount"]
            for l in expense_lines if l["deductible"]
        )
```

4. The `expense_breakdown` accumulator and the two property-block line lists:

```python
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0)
                + _line_share(line, share_for(line.get("unit_id"))) * line["amount"]
            )
```

```python
            "expense_lines": _scaled_lines(expense_lines, share_for),
            "property_expense_lines": _scaled_lines(property_level_lines, share_for),
```

> **Adjusted per C6.** Only the second of those two is still a live call site.
> The property block now emits `"expense_lines": scaled_expense_lines` (`:1457`)
> — the list already built at `:1281`, which item 3 above swaps to `share_for`.
> So the edit here is `"property_expense_lines": _scaled_lines(
> property_level_lines, share_for)` (`:1458`) and nothing else.

- [ ] **Step 5: Verify no scalar `_scaled_lines` call survives**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py -q`
Then grep the file for any remaining site. At `4a1179f` there are exactly **three** `_scaled_lines(` call sites, not four — `:1217` (unit block), `:1281` (`scaled_expense_lines`), `:1458` (`property_expense_lines`) — plus the `def`. Each must pass `share_for` as its second argument. A missed one raises `TypeError: 'float' object is not callable` on the first partial-share fixture, so the suite catches it — but check anyway, because a site reached only by an untested branch would not.

Also grep for `_line_share(`: after this task the only remaining call sites should be the `def` (`:437`), the one inside `_scaled_lines` (`:459`), and the two prorations (`:1178`, `:1270`) and the `expense_breakdown` accumulator (`:1420-1422`) — all three now resolving through `share_for(...)`. Any `_line_share(l, share)` left with the bare scalar is a mixed-share bug that a uniform fixture cannot catch.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitLevelShareExpenseTests -v`
Expected: PASS, 9 tests.

- [ ] **Step 7: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** `LoanShareExemptionTests` in particular must stay green — it is the existing property-share behaviour, which is now the "no unit overrides" case.

- [ ] **Step 8: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): scale each expense line by its own unit's share"
```

---

### Task 4: The share caveat describes mixed shares, and the inherit gate

The caveat still reads `if share < 1.0`, so a property owned outright containing one co-owned unit says nothing at all, and a mixed property names a single percentage that is true of only some of its figures.

**Files:**
- Modify: `backend/rag/finance/finance_engine.py:1308-1312`
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `unit_blocks[i]["ownership_share"]` from Task 2.
- Produces: no new keys. The `caveats` list's share note changes wording under mixed shares.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_finance_engine.py`:

```python
class UnitLevelShareCaveatTests(unittest.TestCase):
    def _docs(self):
        return [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u1"),
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u2"),
        ]

    def _units(self, u1_share=None, u2_share=None):
        rows = [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]
        if u1_share is not None:
            rows[0]["ownership_share"] = u1_share
        if u2_share is not None:
            rows[1]["ownership_share"] = u2_share
        return {"p1": rows}

    def _caveats(self, property_share, u1_share=None, u2_share=None):
        result = _summary(self._docs(), [_prop("p1", "Block", share=property_share)],
                          units=self._units(u1_share, u2_share))
        return result["caveats"]

    def test_uniform_partial_share_keeps_the_single_percentage_note(self):
        note = next(c for c in self._caveats(0.5) if "Ownership share applied" in c)
        self.assertIn("Block at 50%", note)
        self.assertNotIn("–", note)

    def test_mixed_shares_name_the_range_across_units(self):
        note = next(c for c in self._caveats(1.0, u1_share=0.5)
                    if "Ownership share applied" in c)
        self.assertIn("50%–100%", note)
        self.assertIn("across its units", note)

    def test_a_co_owned_unit_inside_a_full_property_still_warns(self):
        # THE GATE. Keyed on the property's own share this property is at
        # 100% and says nothing, while half of one unit's figures are missing.
        self.assertTrue(any("Ownership share applied" in c
                            for c in self._caveats(1.0, u1_share=0.5)))

    def test_full_ownership_throughout_says_nothing(self):
        self.assertFalse(any("Ownership share applied" in c
                             for c in self._caveats(1.0)))

    def test_loan_wording_survives_both_branches(self):
        for caveats in (self._caveats(0.5), self._caveats(1.0, u1_share=0.5)):
            note = next(c for c in caveats if "Ownership share applied" in c)
            self.assertIn("Loan interest and principal are shown in full", note)


class UnitShareInheritanceEquivalenceTests(unittest.TestCase):
    """A property whose units all inherit must be identical to the same
    property before unit-level share existed — which is the same thing as
    every unit storing the property's share explicitly."""

    def _docs(self):
        # doc_id AND uploaded are pinned so the two runs below build
        # byte-identical documents — `_doc` derives both from a module-level
        # counter that advances on every call.
        stamp = datetime(2026, 1, 1)
        return [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u1",
                 uploaded=stamp, doc_id="lease-u1"),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 1000.0, "period_year": 2025},
            ]}, unit_id="u1", uploaded=stamp, doc_id="exp-u1"),
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 1200.0},
                 uploaded=stamp, doc_id="loan-p1"),
        ]

    def _block(self, rows):
        return _summary(self._docs(), [_prop("p1", "Block", share=0.5)],
                        units={"p1": rows})["properties"][0]

    def test_inheriting_equals_storing_the_property_share(self):
        inherited = self._block([{"unit_id": "u1", "label": "A-1"}])
        explicit = self._block([{"unit_id": "u1", "label": "A-1",
                                 "ownership_share": 0.5}])
        self.assertEqual(inherited, explicit)

    def test_inherited_figures_match_the_single_multiply(self):
        block = self._block([{"unit_id": "u1", "label": "A-1"}])
        self.assertAlmostEqual(block["received_rent"], 6000.0, places=2)
        # 500 maintenance (halved) + 1200 loan interest (whole)
        self.assertAlmostEqual(block["direct_expenses"], 1700.0, places=2)
```

`datetime` is already imported at the top of the test file (`from datetime import date, datetime`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitLevelShareCaveatTests tests/test_finance_engine.py::UnitShareInheritanceEquivalenceTests -v`
Expected: FAIL on `test_mixed_shares_name_the_range_across_units` and `test_a_co_owned_unit_inside_a_full_property_still_warns` (`StopIteration` — no note is emitted). `UnitShareInheritanceEquivalenceTests` should already pass; it is the regression guard for Tasks 2–3. If it fails, stop and report — the inheritance path is broken, not the caveat.

- [ ] **Step 3: Rewrite the caveat**

Replace `finance_engine.py:1308-1312`:

```python
        if share < 1.0:
            share_notes.append(
                f"Ownership share applied: {name} at {share:.0%}. Loan interest "
                "and principal are shown in full — they are your own borrowing."
            )
```

with:

```python
        # Keyed on the shares actually rendered, not on the property's own:
        # a property owned outright can now contain a single co-owned unit,
        # and that unit's figures still need the warning.
        resolved_shares = {u["ownership_share"] for u in unit_blocks} or {share}
        if any(s < 1.0 for s in resolved_shares):
            if len(resolved_shares) == 1:
                only = next(iter(resolved_shares))
                share_notes.append(
                    f"Ownership share applied: {name} at {only:.0%}. Loan interest "
                    "and principal are shown in full — they are your own borrowing."
                )
            else:
                lo, hi = min(resolved_shares), max(resolved_shares)
                share_notes.append(
                    f"Ownership share applied: {name} at {lo:.0%}–{hi:.0%} across "
                    "its units. Loan interest and principal are shown in full — "
                    "they are your own borrowing."
                )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitLevelShareCaveatTests tests/test_finance_engine.py::UnitShareInheritanceEquivalenceTests -v`
Expected: PASS, 7 tests.

- [ ] **Step 5: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** `test_ownership_share_scales_both_net_and_statutory` (`test_finance_engine.py:281`) asserts only that some caveat contains "Ownership share applied", and its fixture is uniform, so it takes the single-percentage branch unchanged.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): warn about ownership share across mixed unit shares"
```

---

### Task 5: Models carry the share on both sides

Two separate fields land here and must not be conflated:
- `Unit.ownershipShare` — the **stored override**, nullable, `null` = inherit. Firestore key `ownership_share`.
- `UnitFinance.ownershipShare` — the **resolved** share the engine emits, non-nullable, defaults `1.0`.

**Files:**
- Modify: `backend/models/documind_models.py:194-204`
- Modify: `residex_app/lib/features/landlord/domain/entities/unit.dart`
- Modify: `residex_app/lib/features/landlord/data/models/unit_model.dart`
- Modify: `residex_app/lib/features/landlord/domain/entities/finance_summary.dart:134-156`
- Modify: `residex_app/lib/features/landlord/data/models/finance_summary_model.dart:104-126`
- Create: `residex_app/test/features/landlord/unit_model_ownership_test.dart`
- Test: `residex_app/test/features/landlord/finance_summary_model_test.dart`

**Interfaces:**
- Consumes: the JSON key `ownership_share` on each unit block, from Task 2.
- Produces:
  - `UnitFinance.ownershipShare` (`double`, default `1.0`) — read by Tasks 6 and 7.
  - `Unit.ownershipShare` (`double?`, default `null`) and `Unit.copyWith({double? ownershipShare})` — written by Task 8.

- [ ] **Step 1: Write the failing tests**

Create `residex_app/test/features/landlord/unit_model_ownership_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/unit_model.dart';

void main() {
  group('UnitModel ownership share', () {
    test('parses a stored ownership_share', () {
      final unit = UnitModel.fromJson({
        'label': 'A-1',
        'monthlyRent': 1200,
        'isOccupied': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'ownership_share': 0.5,
      }, 'u1', 'p1');

      expect(unit.ownershipShare, 0.5);
    });

    test('an absent ownership_share stays null, meaning inherit', () {
      final unit = UnitModel.fromJson({
        'label': 'A-2',
        'monthlyRent': 1200,
        'isOccupied': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }, 'u2', 'p1');

      expect(unit.ownershipShare, isNull);
    });

    test('an int ownership_share parses as a double', () {
      final unit = UnitModel.fromJson({
        'label': 'A-3',
        'monthlyRent': 1200,
        'isOccupied': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'ownership_share': 1,
      }, 'u3', 'p1');

      expect(unit.ownershipShare, 1.0);
    });

    test('toJson writes ownership_share only when set', () {
      final withShare = UnitModel(
        id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
        isOccupied: true, createdAt: DateTime(2026, 1, 1), ownershipShare: 0.5,
      );
      final without = UnitModel(
        id: 'u2', propertyId: 'p1', label: 'A-2', monthlyRent: 1200,
        isOccupied: true, createdAt: DateTime(2026, 1, 1),
      );

      expect(withShare.toJson()['ownership_share'], 0.5);
      expect(without.toJson().containsKey('ownership_share'), isFalse);
    });

    test('copyWith carries the share and can set one', () {
      final unit = UnitModel(
        id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
        isOccupied: true, createdAt: DateTime(2026, 1, 1),
      );

      expect(unit.copyWith(label: 'A-9').ownershipShare, isNull);
      expect(unit.copyWith(ownershipShare: 0.5).ownershipShare, 0.5);
    });
  });
}
```

Append to `residex_app/test/features/landlord/finance_summary_model_test.dart`, inside the existing top-level `main()`:

```dart
  group('unit resolved ownership share', () {
    // Every map literal is explicitly <String, dynamic>: the parser casts
    // nested maps with `as Map<String, dynamic>`, and an inferred
    // Map<dynamic, dynamic> fails that cast at runtime.
    Map<String, dynamic> summaryJson(Map<String, dynamic> unit) =>
        <String, dynamic>{
          'year': 2025,
          'properties': [
            <String, dynamic>{
              'property_id': 'p1',
              'name': 'Block',
              'units': [unit],
            },
          ],
        };

    test('maps ownership_share off a unit block', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson(
        <String, dynamic>{'unit_id': 'u1', 'label': 'A-1', 'ownership_share': 0.5},
      ));

      expect(summary.properties.first.units.first.ownershipShare, 0.5);
    });

    test('an absent ownership_share defaults to full ownership', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson(
        <String, dynamic>{'unit_id': 'u1', 'label': 'A-1'},
      ));

      expect(summary.properties.first.units.first.ownershipShare, 1.0);
    });
  });
```

`finance_summary_model_test.dart` already imports `FinanceSummaryModel` (`:2`); no import changes are needed. `totals` is omitted deliberately — `fromJson` defaults it.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/unit_model_ownership_test.dart test/features/landlord/finance_summary_model_test.dart`
Expected: FAIL to compile — `The named parameter 'ownershipShare' isn't defined` and `The getter 'ownershipShare' isn't defined for the class 'UnitFinance'`.

- [ ] **Step 3: Add the field to the Pydantic response model**

In `backend/models/documind_models.py`, inside `UnitFinance` (`:194-204`), after `label`:

```python
    ownership_share: float = 1.0  # resolved: the unit's override, else the property's
```

- [ ] **Step 4: Add the stored override to the Dart entity**

In `residex_app/lib/features/landlord/domain/entities/unit.dart`, add the field, constructor parameter and `copyWith` parameter:

```dart
  final bool isOccupied;

  /// This unit's own ownership share, 0–1. Null means "inherit the
  /// property's" — the overwhelmingly common case. An explicit 1.0 is a
  /// distinct, meaningful state: a unit owned outright inside a property
  /// that is otherwise co-owned.
  final double? ownershipShare;

  final DateTime createdAt;
```

```dart
    required this.isOccupied,
    this.ownershipShare,
    required this.createdAt,
```

```dart
    bool? isOccupied,
    double? ownershipShare,
    DateTime? createdAt,
```

```dart
      isOccupied: isOccupied ?? this.isOccupied,
      ownershipShare: ownershipShare ?? this.ownershipShare,
      createdAt: createdAt ?? this.createdAt,
```

> `copyWith` coalesces, so it cannot clear the share back to null. That is fine here — nothing in this feature clears it; Task 8 only ever writes a value.

- [ ] **Step 5: Serialize it**

In `residex_app/lib/features/landlord/data/models/unit_model.dart`:

```dart
    required super.isOccupied,
    super.ownershipShare,
    required super.createdAt,
```

```dart
      isOccupied: unit.isOccupied,
      ownershipShare: unit.ownershipShare,
      createdAt: unit.createdAt,
```

In `fromJson`, after `isOccupied`:

```dart
      // Snake_case deliberately: the backend reads 'ownership_share', matching
      // the property document's own share field. See the plan's constraints.
      ownershipShare: json['ownership_share'] == null
          ? null
          : _parseDouble(json['ownership_share']),
```

In `toJson`, inside the returned map:

```dart
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (ownershipShare != null) 'ownership_share': ownershipShare,
```

- [ ] **Step 6: Add the resolved share to `UnitFinance`**

In `residex_app/lib/features/landlord/domain/entities/finance_summary.dart`, in `UnitFinance` (`:134-156`), after `label`:

```dart
  final String label;

  /// The share the engine actually applied to this unit's figures — its own
  /// override, or the property's. A label for the scope; the panel's
  /// "your N% of RM X" sub-labels stay derived from the figure pairs.
  final double ownershipShare;

  final int rentedMonths;
```

and in the constructor, after `required this.label,`:

```dart
    this.ownershipShare = 1.0,
```

In `residex_app/lib/features/landlord/data/models/finance_summary_model.dart`, inside `_unit` (`:104-126`), after `label`:

```dart
      ownershipShare:
          json['ownership_share'] == null ? 1.0 : _d(json['ownership_share']),
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/unit_model_ownership_test.dart test/features/landlord/finance_summary_model_test.dart`
Expected: PASS.

- [ ] **Step 8: Run both suites**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (the boilerplate `widget_test.dart` only).

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.**

- [ ] **Step 9: Commit**

```bash
git add backend/models/documind_models.py \
  residex_app/lib/features/landlord/domain/entities/unit.dart \
  residex_app/lib/features/landlord/data/models/unit_model.dart \
  residex_app/lib/features/landlord/domain/entities/finance_summary.dart \
  residex_app/lib/features/landlord/data/models/finance_summary_model.dart \
  residex_app/test/features/landlord/unit_model_ownership_test.dart \
  residex_app/test/features/landlord/finance_summary_model_test.dart
git commit -m "feat(finance): carry unit ownership share through both models"
```

---

### Task 6: The property card shows the range, and each unit row its own share

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/widgets/common/share_badge.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:318-337` (badge), `:387-394` (footnote), `:419-439` (unit row)
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`

**Interfaces:**
- Consumes: `UnitFinance.ownershipShare` from Task 5.
- Produces: `ShareBadge({required String text})` — a `StatelessWidget`, used again by Task 7.

- [ ] **Step 1: Write the failing tests**

Append to `residex_app/test/features/landlord/finance_screen_test.dart`, inside `main()`. It needs two local helpers — a summary carrying units, and a pump that stubs `propertyByIdProvider` rather than letting it reach the real data source:

```dart
  Future<void> pumpShares(WidgetTester tester, FinanceSummary summary) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith((ref, y) async => summary),
          // Returns null: no property means no mortgage, so the loan figures
          // row stays out of the way of these assertions. Overridden rather
          // than left alone so the test never touches Firebase.
          propertyByIdProvider.overrideWith((ref, id) async => null),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  FinanceSummary summaryWithUnitShares(
    int year, {
    required double propertyShare,
    required List<UnitFinance> units,
  }) {
    return FinanceSummary(
      year: year,
      totals: FinanceTotals(
        receivedRent: 18000.0,
        derivedRent: 0.0,
        directExpenses: 0.0,
        netPl: 18000.0,
        statutoryRentalIncome: 18000.0,
        statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1',
          name: 'Ayer 8',
          ownershipShare: propertyShare,
          receivedRent: 18000.0,
          derivedRent: 0.0,
          directExpenses: 0.0,
          rentalIncomeOrLoss: 18000.0,
          netPl: 18000.0,
          statutoryContribution: 18000.0,
          units: units,
        ),
      ],
    );
  }

  testWidgets('uniform partial shares keep the single-percentage badge',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 0.5,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
          UnitFinance(unitId: 'u2', label: 'A-2', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
        ]));

    expect(find.text('50% share'), findsWidgets);
    expect(find.textContaining('Shown at your 50% share.'), findsOneWidget);
    expect(find.textContaining('share of each unit'), findsNothing);
  });

  testWidgets('mixed shares render a range badge and the per-unit footnote',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 1.0,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
          UnitFinance(unitId: 'u2', label: 'A-2', rentedMonths: 12,
              contribution: 12000.0, ownershipShare: 1.0),
        ]));

    expect(find.text('50–100% share'), findsOneWidget);
    expect(find.textContaining('Shown at your share of each unit.'),
        findsOneWidget);
  });

  testWidgets('a co-owned unit row is badged and a wholly-owned one is not',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 1.0,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
          UnitFinance(unitId: 'u2', label: 'A-2', rentedMonths: 12,
              contribution: 12000.0, ownershipShare: 1.0),
        ]));

    // One on the A-1 row; the property badge above reads '50–100% share'.
    expect(find.text('50% share'), findsOneWidget);
    expect(find.text('100% share'), findsNothing);
  });

  testWidgets('full ownership throughout renders no badge at all',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 1.0,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 12000.0, ownershipShare: 1.0),
        ]));

    expect(find.textContaining('% share'), findsNothing);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`
Expected: FAIL — the range badge, the per-unit footnote and the unit-row badge are not rendered.

- [ ] **Step 3: Create the badge widget**

Create `residex_app/lib/features/landlord/presentation/widgets/common/share_badge.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// The one way an ownership share is labelled anywhere in the app: on the
/// property card, on a unit row, and at the top of the unit drill-down.
///
/// This is a label for a *scope* — "which share applies to everything you are
/// looking at". It is deliberately distinct from the "your N% of RM X"
/// sub-labels beneath individual figures, which explain one figure's
/// arithmetic and are derived from the figure pair rather than from a share
/// field. The two do different jobs and correctly appear side by side.
class ShareBadge extends StatelessWidget {
  const ShareBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(text, style: AppTextStyles.labelSmall),
    );
  }
}
```

- [ ] **Step 4: Compute the range on the property card**

In `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart`, add the import:

```dart
import '../../widgets/common/share_badge.dart';
```

In the property-block builder, beside the existing `final showManualLoan = ...` (`:306`), add:

```dart
    // Every share rendered under this card. The property's own is always in
    // the set: it is what a building-wide loan or quit rent is scaled by, so
    // a property at 50% whose units are all owned outright still says so.
    final shares = <double>{
      block.ownershipShare,
      ...block.units.map((u) => u.ownershipShare),
    };
    final lowestShare = shares.reduce((a, b) => a < b ? a : b);
    final highestShare = shares.reduce((a, b) => a > b ? a : b);
    final sharesVary = lowestShare != highestShare;
    final showShare = lowestShare < 1.0;
```

- [ ] **Step 5: Render the badge and the footnote**

Replace the badge in the title `Row` (`:322-335`):

```dart
              if (showShare)
                ShareBadge(
                  text: sharesVary
                      ? '${(lowestShare * 100).toStringAsFixed(0)}–'
                          '${(highestShare * 100).toStringAsFixed(0)}% share'
                      : '${(lowestShare * 100).toStringAsFixed(0)}% share',
                ),
```

Replace the footnote (`:387-394`):

```dart
          if (showShare) ...[
            const SizedBox(height: 4),
            Text(
              sharesVary
                  ? 'Shown at your share of each unit. Loan interest and '
                      'principal are shown in full.'
                  : 'Shown at your ${(lowestShare * 100).toStringAsFixed(0)}% '
                      'share. Loan interest and principal are shown in full.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
```

- [ ] **Step 6: Badge the unit rows**

In the unit row `Row` (`:421-438`), between the label `Expanded` and the `rentedMonths` text:

```dart
                        Expanded(
                            child: Text(unit.label,
                                style: AppTextStyles.titleMedium)),
                        if (unit.ownershipShare < 1.0) ...[
                          ShareBadge(
                            text: '${(unit.ownershipShare * 100).toStringAsFixed(0)}'
                                '% share',
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${unit.rentedMonths} mo rented',
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`
Expected: PASS.

- [ ] **Step 8: Run the suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (boilerplate only).

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/share_badge.dart \
  residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart \
  residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat(finance): badge the ownership share range and each unit's share"
```

---

### Task 7: The unit drill-down states its own share

Opening a co-owned unit currently loses every mention of share — the screen shows halved figures with nothing saying so.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart:138`
- Test: `residex_app/test/features/landlord/unit_finance_detail_test.dart`

**Interfaces:**
- Consumes: `UnitFinance.ownershipShare` (Task 5) and `ShareBadge` (Task 6).
- Produces: nothing consumed later.

- [ ] **Step 1: Write the failing tests**

Append to `residex_app/test/features/landlord/unit_finance_detail_test.dart`, inside `main()`:

```dart
  testWidgets('a co-owned unit states its share beside the property name',
      (tester) async {
    await _pumpScreen(tester, 2026, UnitFinance(
      unitId: 'u1', label: 'Unit 1', rentedMonths: 12,
      ownershipShare: 0.5,
      grossIncome: 12800.0, fullGrossIncome: 25600.0,
      contribution: 12800.0, statutoryContribution: 12800.0,
    ));

    expect(find.text('50% share'), findsOneWidget);
  });

  testWidgets('a wholly-owned unit shows no badge', (tester) async {
    await _pumpScreen(tester, 2026, UnitFinance(
      unitId: 'u1', label: 'Unit 1', rentedMonths: 12,
      grossIncome: 25600.0,
      contribution: 25600.0, statutoryContribution: 25600.0,
    ));

    expect(find.textContaining('% share'), findsNothing);
  });

  testWidgets('the badge and the figure sub-label agree', (tester) async {
    // The two come from different sources on purpose: the badge reads the
    // emitted `ownership_share`, the sub-label divides gross by full gross.
    // If they ever disagree it is a bug, and nothing else would catch it.
    await _pumpScreen(tester, 2026, UnitFinance(
      unitId: 'u1', label: 'Unit 1', rentedMonths: 12,
      ownershipShare: 0.5,
      grossIncome: 12800.0, fullGrossIncome: 25600.0,
      contribution: 12800.0, statutoryContribution: 12800.0,
    ));

    expect(find.text('50% share'), findsOneWidget);
    expect(find.textContaining('your 50% of'), findsWidgets);
  });
```

> The third test depends on the gross sub-label built by the unit-panel plan's Task 7. If `your 50% of` renders nowhere, that plan is not complete — stop and report rather than adding the sub-label here.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`
Expected: FAIL — `50% share` is not found. The wholly-owned test may already pass; it is a guard.

- [ ] **Step 3: Render the badge**

In `unit_finance_detail_screen.dart`, add the import:

```dart
import '../../widgets/common/share_badge.dart';
```

Replace the property-name line in the `ListView` (`:138`):

```dart
          Text(widget.propertyName, style: AppTextStyles.bodyMedium),
```

with:

```dart
          Row(
            children: [
              Expanded(
                child: Text(widget.propertyName, style: AppTextStyles.bodyMedium),
              ),
              if (_displayedUnit.ownershipShare < 1.0)
                ShareBadge(
                  text: '${(_displayedUnit.ownershipShare * 100).toStringAsFixed(0)}'
                      '% share',
                ),
            ],
          ),
```

`_displayedUnit` rather than `widget.unit`: the screen re-resolves the unit when the year changes, and the share is read off whichever year is on screen.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (boilerplate only).

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart \
  residex_app/test/features/landlord/unit_finance_detail_test.dart
git commit -m "feat(finance): state the unit's ownership share on its drill-down"
```

---

### Task 8: The landlord can set a unit's share

Everything above reads a value nothing writes yet. This task adds the control, in the unit's own edit dialog beside monthly rent.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart:139-209` (`_editUnit`), `:225-226` and `:283` (pass the property share in)
- Create: `residex_app/test/features/landlord/units_screen_share_test.dart`
- Test: as above

**Interfaces:**
- Consumes: `Unit.ownershipShare` and `Unit.copyWith` from Task 5.
- Produces: nothing consumed later.

> **An explicit 100% on a unit is not the same as no value.** Inside a property at 50%, storing `1.0` on a unit means "I own this one outright" — the exact case the spec was written for. So the control writes whatever the landlord typed, including 100, and never clears the field back to null.

- [ ] **Step 1: Write the failing tests**

Create `residex_app/test/features/landlord/units_screen_share_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/domain/repositories/unit_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/4-Portfolio/units_screen.dart';

/// Captures what the edit dialog saves, through the real controller and use
/// case rather than a stubbed provider, so the write path is exercised.
class _FakeUnitRepository implements UnitRepository {
  _FakeUnitRepository(this._units);

  final List<Unit> _units;
  Unit? lastUpdated;

  @override
  Future<void> updateUnit(Unit unit) async {
    lastUpdated = unit;
  }

  @override
  Future<List<Unit>> getUnitsForProperty(String propertyId) async => _units;
  @override
  Stream<List<Unit>> streamUnitsForProperty(String propertyId) =>
      Stream.value(_units);
  @override
  Future<String> createUnit(Unit unit) async => 'u9';
  @override
  Future<void> deleteUnit(String propertyId, String unitId) async {}
  @override
  Future<void> deleteAllUnitsForProperty(String propertyId) async {}
}

// Mirrors the fixture in add_property_dialog_loan_prefs_test.dart:7-20.
Property _property({required double ownershipShare}) => Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Ayer 8',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      ownershipShare: ownershipShare,
      createdAt: DateTime(2026, 1, 1),
    );

Unit _unit({double? ownershipShare}) => Unit(
      id: 'u1',
      propertyId: 'p1',
      label: 'A-1',
      monthlyRent: 1200,
      isOccupied: true,
      ownershipShare: ownershipShare,
      createdAt: DateTime(2026, 1, 1),
    );

Future<_FakeUnitRepository> _pumpUnits(
  WidgetTester tester, {
  required Property property,
  required Unit unit,
}) async {
  final repository = _FakeUnitRepository([unit]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unitRepositoryProvider.overrideWithValue(repository),
        propertyByIdProvider.overrideWith((ref, id) async => property),
      ],
      child: const MaterialApp(
        home: UnitsScreen(propertyId: 'p1', propertyName: 'Ayer 8'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('a co-owned property shows the share field straight away',
      (tester) async {
    await _pumpUnits(tester,
        property: _property(ownershipShare: 0.5), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();

    expect(find.text('My share of this unit (%)'), findsOneWidget);
  });

  testWidgets('a wholly-owned property hides it behind an affordance',
      (tester) async {
    await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    expect(find.text('My share of this unit (%)'), findsNothing);

    await tester.tap(find.text('Set a different share for this unit'));
    await tester.pumpAndSettle();
    expect(find.text('My share of this unit (%)'), findsOneWidget);
  });

  testWidgets('saving writes the share the landlord typed', (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set a different share for this unit'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'My share of this unit (%)'), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdated?.ownershipShare, 0.5);
  });

  testWidgets('a unit already carrying a share prefills and keeps it',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0),
        unit: _unit(ownershipShare: 0.5));

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.lastUpdated?.ownershipShare, 0.5);
  });

  testWidgets('an untouched unit on a full property saves no share',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdated?.ownershipShare, isNull);
  });
}
```

> `PropertyAddress` lives inside `property.dart` — there is no separate `address.dart`. `photos` and every field below `ownershipShare` have defaults on the constructor (`property.dart:170-190`), which is why the fixture omits them.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/units_screen_share_test.dart`
Expected: FAIL — the field and the affordance do not exist.

- [ ] **Step 3: Pass the property's share into the dialog**

In `units_screen.dart`, add the import:

```dart
import '../../providers/property_providers.dart';
```

In `build` (`:225-226`):

```dart
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsForPropertyStreamProvider(propertyId));
    // Watched, not read: the dialog needs this resolved when it opens, and
    // this screen is otherwise the only thing that would ever load it.
    final propertyShare =
        ref.watch(propertyByIdProvider(propertyId)).value?.ownershipShare ?? 1.0;
```

and at the `ListTile`'s `onTap` (`:283`):

```dart
                              onTap: () =>
                                  _editUnit(context, ref, unit, propertyShare),
```

- [ ] **Step 4: Add the control to the dialog**

Replace `_editUnit` (`units_screen.dart:139-209`) with:

```dart
  Future<void> _editUnit(BuildContext context, WidgetRef ref, Unit unit,
      double propertyShare) async {
    final labelController = TextEditingController(text: unit.label);
    final rentController = TextEditingController(text: unit.monthlyRent.toString());
    final shareController = TextEditingController(
      text: ((unit.ownershipShare ?? propertyShare) * 100).toStringAsFixed(0),
    );
    // Shown up front when co-ownership is already in play here — either the
    // property is co-owned, or this unit already carries its own share.
    // Otherwise it stays behind an affordance so a landlord who owns
    // everything outright never has to think about it.
    var showShare = propertyShare < 1.0 || unit.ownershipShare != null;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Unit', style: AppTextStyles.titleMedium),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label'),
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly Rent'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final parsed = double.tryParse(v);
                    if (parsed == null) return 'Must be a number';
                    if (parsed < 0) return 'Must be positive';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (showShare)
                  TextFormField(
                    controller: shareController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'My share of this unit (%)',
                      hintText: '100 if you own this unit outright',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final parsed = double.tryParse(v);
                      if (parsed == null) return 'Must be a number';
                      if (parsed <= 0 || parsed > 100) return 'Between 1 and 100';
                      return null;
                    },
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setDialogState(() => showShare = true),
                      child: Text(
                        'Set a different share for this unit',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.registry),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.registry),
              child: Text('Save',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final controller = ref.read(unitControllerProvider);
      try {
        await controller.updateUnit(unit.copyWith(
          label: labelController.text.trim(),
          monthlyRent: double.parse(rentController.text),
          // Untouched and hidden means untouched: passing the existing value
          // back through copyWith leaves a never-set share unset, so the unit
          // keeps inheriting the property's.
          ownershipShare: showShare
              ? double.parse(shareController.text) / 100.0
              : unit.ownershipShare,
        ));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update unit: $e'),
                backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/units_screen_share_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Run both suites and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (boilerplate only).

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.**

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart \
  residex_app/test/features/landlord/units_screen_share_test.dart
git commit -m "feat(portfolio): let a unit carry its own ownership share"
```

---

## Manual verification

Automated tests cover the arithmetic and the widgets; this is the end-to-end path they cannot reach, because the stored override has to survive a real Firestore round trip.

1. Pick a property with at least two units and set its share to **100%**.
2. Open Portfolio → its units → edit one unit → "Set a different share for this unit" → **50%** → Save.
3. Finance tab, same year:
   - the property card badge reads **50–100% share**
   - the footnote reads **"Shown at your share of each unit."**
   - only the edited unit's row carries a **50% share** badge
4. Tap into the co-owned unit: the badge sits beside the property name, and the gross line reads `your 50% of RM …`. The percentage in the sub-label and the percentage in the badge must be the same number.
5. Tap into the other unit: no badge, and no `your N% of` sub-label anywhere.
6. Confirm the property's **Rental Income** equals the two units' gross figures added together — not either share applied to their total.

---

## Notes for whoever executes this

- **Tasks 2 and 3 are one behaviour split across two commits.** Between them the engine scales income per unit while expenses still follow the property. That intermediate state is green only because no existing fixture sets a unit share. Do not ship task 2 and stop.
- **If an existing test fails at any step, stop and report it.** Every existing fixture resolves to the property's own share, so nothing existing should move. A test that needs adjusting means the change did something the plan did not intend.
- The document-share-basis spec (`docs/superpowers/specs/2026-08-09-document-share-basis-design.md`) builds on this one and splits each scope's contribution into `full` / `mine` buckets inside the per-scope loop this plan establishes. Leaving `share_for` as a named seam rather than inlining it is what makes that cheap.
