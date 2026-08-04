# Landlord-Testing Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix six defects found in landlord testing (ownership share ignored, inconsistent financial terminology, a loan figure that never reaches its unit, a broken DocuMind query, a redundant coverage bubble, and bottom-line naming) plus two defects found while investigating.

**Architecture:** The backend `finance_engine.py` is the single source of every figure — the Flutter app never recomputes. So all numeric changes land in one Python function (`compute_finance_summary`) and reach the app through the existing `FinanceSummaryResponse` JSON. UI tasks are then pure display changes. The DocuMind retrieval fix is independent of everything else and is diagnosis-first.

**Tech Stack:** Python 3 / FastAPI / Pydantic / `unittest` (backend, run with `pytest`); Flutter / Dart / Riverpod / `flutter_test` (app); Firestore.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-04-landlord-testing-fixes-design.md`. Read it before starting.
- **The app never recomputes a figure.** Any new number must come from the engine via JSON. Do not do arithmetic in a Dart widget.
- **No emojis in app-facing UI copy.** Use Material icon glyphs. (Existing project rule.)
- **Never `git add -A`.** The working tree carries unrelated multi-session WIP. Stage only the explicit paths listed in each task's commit step.
- **Backend baseline: 476 tests passing.** `cd backend && python -m pytest -q`
- **Flutter baseline: 211 passing + exactly 1 pre-existing failure.** `cd residex_app && flutter test`. The known failure is `test/widget_test.dart` "Counter increments" — template boilerplate referencing a `MyApp` counter this app does not have. It is unrelated; it must remain the **only** failure. Never "fix" it.
- **Currency is RM**, formatted through `formatRM` in `residex_app/lib/features/landlord/presentation/providers/finance_logic.dart`.
- **Rounding:** the engine's `_round2` is applied **after** scaling, never before.
- **Branch:** `feat/finance-tab-restructure`.

---

## File Structure

**Backend (modify only — no new files):**

| File | Responsibility | Tasks |
|---|---|---|
| `backend/rag/finance/finance_engine.py` | All finance math. Gains `_scaled_lines` helper; `compute_finance_summary` gains a per-property share choke point. | 1, 2, 3, 16 |
| `backend/models/documind_models.py` | Wire schema. `ExpenseLine` gains `full_amount`; `PropertyFinance` gains `landlord_expenses`. | 1, 2 |
| `backend/rag/ask/ask_orchestrator.py` | Splits one catch-all retrieval handler into three distinguishable failure classes. | 14 |
| `backend/tests/test_finance_engine.py` | Engine tests. | 1, 2, 3, 16 |

**Flutter (modify only — no new files):**

| File | Responsibility | Tasks |
|---|---|---|
| `.../domain/entities/finance_summary.dart` | Entities. `ExpenseLine` gains `fullAmount`; `PropertyFinance` gains `landlordExpenses`. | 4 |
| `.../data/models/finance_summary_model.dart` | JSON parsing for the above. | 4 |
| `.../widgets/common/finance_summary_panel.dart` | Finance-tab headline labels. | 5 |
| `.../screens/3-Finance/finance_screen.dart` | Property panel: labels, expenses value, coverage-strip removal, property-level expenses, share caption, loan nudge. | 6, 8, 9, 10, 13 |
| `.../screens/3-Finance/unit_finance_detail_screen.dart` | Unit dropdown titles + roll-up captions + line provenance. | 7, 9 |
| `.../widgets/common/document_nudge_banner.dart` | Optional third action for the `loan` category. | 13 |
| `.../widgets/common/add_property_dialog.dart` | Loses the loan method/cadence selectors. | 11 |
| `.../widgets/common/manual_loan_entry_sheet.dart` | Scope by structure type; cadence asked here and persisted. | 12 |
| `.../screens/5-Documents/documents_screen.dart` | "Enter figures manually" peer action in the Loans & Financing folder. | 13 |

All Flutter paths above are under `residex_app/lib/features/landlord/presentation/` unless stated.

**Task order rationale:** engine first (1–3), so the app has final numbers and fields to bind to; then the Dart model (4); then UI in parallel-safe chunks (5–10); then the loan UX, the largest UI change (11–13); then the independent retrieval work (14–15); then the optional statutory-basis alignment (16).

---

### Task 1: Ownership share applied at a per-property choke point

Implements spec §1. `share` currently multiplies only `net_pl` and `statutory`. It must apply to every figure, exactly once, **per property, before accumulation** — a cross-property total cannot be scaled by any single factor.

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` (new helper near `_dedup_expense_lines`; `compute_finance_summary` body)
- Modify: `backend/models/documind_models.py:176-189` (`ExpenseLine`)
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `_scaled_lines(lines: List[Dict[str, Any]], share: float) -> List[Dict[str, Any]]` — returns **copies**; adds `full_amount` when `share != 1.0`.
  - JSON field `full_amount: Optional[float]` on every expense line (Task 4 parses it; Task 9 renders it).
  - `totals.*` and `properties[].*` money fields are now share-scaled.

- [ ] **Step 1: Write the failing tests**

Add to `backend/tests/test_finance_engine.py`, inside the same class as `test_ownership_share_scales_both_net_and_statutory` (find it around line 281):

```python
    def test_ownership_share_scales_every_total_not_just_net_and_statutory(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "tax", {"subtype": "quit_rent", "amount": 120.0, "period_year": 2025}),
        ]
        exceptions = [_doc_exception("p1", 2025, c)
                      for c in ("loan", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "Shared", share=0.5)], year=2025,
                          today=date(2026, 1, 1), document_exceptions=exceptions)
        totals = result["totals"]
        # Every money total is now the landlord's half, not the property's whole.
        self.assertEqual(totals["received_rent"], 500.0)
        self.assertEqual(totals["direct_expenses"], 60.0)
        self.assertEqual(totals["landlord_expenses"], 60.0)
        # Unchanged by this task — proves share was not applied twice.
        self.assertEqual(totals["net_pl"], 440.0)
        self.assertEqual(totals["statutory_rental_income"], 495.0)

    def test_ownership_share_scales_property_block_and_expense_lines(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "tax", {"subtype": "quit_rent", "amount": 120.0, "period_year": 2025}),
        ]
        exceptions = [_doc_exception("p1", 2025, c)
                      for c in ("loan", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "Shared", share=0.5)], year=2025,
                          today=date(2026, 1, 1), document_exceptions=exceptions)
        block = result["properties"][0]
        self.assertEqual(block["received_rent"], 500.0)
        self.assertEqual(block["direct_expenses"], 60.0)
        self.assertEqual(block["rental_income_or_loss"], 440.0)
        # Each line is scaled, and carries the document's face value so the app
        # can show "your 50% of RM 120.00".
        line = block["expense_lines"][0]
        self.assertEqual(line["amount"], 60.0)
        self.assertEqual(line["full_amount"], 120.0)
        # The category breakdown is scaled too.
        self.assertEqual(result["expense_breakdown"]["tax"], 60.0)

    def test_full_ownership_leaves_every_figure_and_line_untouched(self):
        """Regression guard on the choke point: at share 1.0 nothing changes,
        and no full_amount provenance is emitted."""
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "tax", {"subtype": "quit_rent", "amount": 120.0, "period_year": 2025}),
        ]
        exceptions = [_doc_exception("p1", 2025, c)
                      for c in ("loan", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "Whole", share=1.0)], year=2025,
                          today=date(2026, 1, 1), document_exceptions=exceptions)
        self.assertEqual(result["totals"]["received_rent"], 1000.0)
        self.assertEqual(result["totals"]["direct_expenses"], 120.0)
        self.assertEqual(result["totals"]["net_pl"], 880.0)
        block = result["properties"][0]
        self.assertEqual(block["received_rent"], 1000.0)
        self.assertIsNone(block["expense_lines"][0].get("full_amount"))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k "ownership_share_scales_every or scales_property_block or full_ownership_leaves" -q`

Expected: FAIL. `test_ownership_share_scales_every_total_not_just_net_and_statutory` fails on `received_rent == 1000.0 != 500.0`; the others fail on missing `full_amount` / unscaled block figures.

- [ ] **Step 3: Add the `_scaled_lines` helper**

In `backend/rag/finance/finance_engine.py`, insert immediately **after** the `_dedup_expense_lines` function (it ends around line 430 — place the new function between it and whatever follows):

```python
def _scaled_lines(lines: List[Dict[str, Any]], share: float) -> List[Dict[str, Any]]:
    """Copy expense lines with amounts at the landlord's ownership share.

    Never mutates the input. The unscaled lines stay the basis for every
    property-level sum, so scaling is applied exactly once and no sum can be
    scaled twice. At share 1.0 the lines are returned unchanged (no
    `full_amount`), so the overwhelmingly common case is byte-identical to
    before. Below 1.0 each line also carries `full_amount`, the source
    document's face value, so the app can show "your 50% of RM 1,200.00"
    beside the scaled figure."""
    if share == 1.0:
        return list(lines)
    return [
        {**line,
         "amount": _round2(share * line["amount"]),
         "full_amount": _round2(line["amount"])}
        for line in lines
    ]
```

- [ ] **Step 4: Scale the unit blocks**

In `compute_finance_summary`, the scope loop currently builds unit blocks from unscaled figures (around lines 1048-1077). Replace the two `unit_*_total` computations and the `unit_blocks.append(...)` call so both totals and lines are scaled.

Find:

```python
            unit_deductible_total = sum(
                l["amount"] for l in unit_lines if l["deductible"]
            )
            unit_landlord_total = sum(
                l["amount"] for l in unit_lines if l["paid_by_landlord"]
            )
            prorated_expenses += unit_deductible_total * fraction
```

Leave that block exactly as-is — `prorated_expenses` must keep using **unscaled** amounts, because the property's `share` is applied to `statutory_sum` once, later.

Then find the `unit_blocks.append({...})` call and change only these three entries:

```python
                "contribution": _round2(
                    share * (actual_sum + derived_sum - unit_landlord_total)
                ),
                "statutory_contribution": _round2(
                    share * (actual_sum + derived_sum - unit_deductible_total)
                ),
                ...
                "expense_lines": _scaled_lines(unit_lines, share),
```

(`...` stands for the untouched `"months"`, `"missing_invoice_months"`, `"unit_id"`, `"label"`, `"rented_months"` and `"loan_status"` entries — leave them alone.)

- [ ] **Step 5: Add the per-property choke point**

Still in `compute_finance_summary`, find this block (around lines 1146-1153):

```python
        statutory_sum += share * (received - prorated_expenses)
        # Net P/L and statutory both reflect the landlord's ownership share, so a
        # co-owned property never shows a statutory figure below its Net P/L
        # (statutory deducts a smaller set of expenses than Net P/L, so once both
        # are on the same share basis statutory >= Net P/L always). Received and
        # Direct Expenses stay at the property's full amount — the share note and
        # the per-block caption explain the basis.
        net_pl_sum += share * (received - landlord_paid)
```

Replace it with:

```python
        # Ownership share is applied once, here, to every figure this property
        # contributes; the already-scaled values then feed the cross-property
        # totals. Each property carries its own share, so a total can never be
        # correctly scaled after the fact — the choke point must be per property
        # and must sit before accumulation. (Superseded the earlier design where
        # Received and Direct Expenses stayed at the property's full amount.)
        s_received = share * received
        s_derived = share * prop_derived
        s_outstanding = share * prop_outstanding
        s_direct = share * direct
        s_landlord_paid = share * landlord_paid
        s_prorated = share * prorated_expenses

        statutory_sum += s_received - s_prorated
        net_pl_sum += s_received - s_landlord_paid
```

- [ ] **Step 6: Accumulate the scaled values into the totals**

Find (around lines 1201-1205):

```python
        total_received += received
        total_derived += prop_derived
        total_outstanding += prop_outstanding
        total_expenses += direct
        total_landlord_expenses += landlord_paid
```

Replace with:

```python
        total_received += s_received
        total_derived += s_derived
        total_outstanding += s_outstanding
        total_expenses += s_direct
        total_landlord_expenses += s_landlord_paid
```

- [ ] **Step 7: Scale the expense breakdown**

Find (around lines 1175-1180):

```python
        for line in expense_lines:
            if not line["deductible"]:
                continue
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0) + line["amount"]
            )
```

Replace the last expression so the accumulated value is scaled:

```python
        for line in expense_lines:
            if not line["deductible"]:
                continue
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0) + share * line["amount"]
            )
```

- [ ] **Step 8: Emit the scaled property block**

Find the `property_blocks.append({...})` call (around lines 1207-1226) and replace these entries — leave `property_id`, `name`, `ownership_share`, `units`, `recovered_rent`, `complete`, `coverage`, `expected_categories` and `manual_loan_incomplete` untouched:

```python
            "received_rent": _round2(s_received),
            "derived_rent": _round2(s_derived),
            "outstanding_rent": _round2(s_outstanding),
            "direct_expenses": _round2(s_direct),
            "rental_income_or_loss": _round2(s_received - s_direct),
            "net_pl": _round2(s_received - s_landlord_paid),
            "statutory_contribution": _round2(s_received - s_direct),
            "expense_lines": _scaled_lines(expense_lines, share),
            "property_expense_lines": _scaled_lines(property_level_lines, share),
```

- [ ] **Step 9: Add `full_amount` to the wire model**

In `backend/models/documind_models.py`, in `class ExpenseLine` (line 176), add one field after `amount`:

```python
    amount: float
    full_amount: Optional[float] = None  # document face value when a share < 1.0 scaled `amount`
```

- [ ] **Step 10: Run the new tests**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k "ownership_share_scales_every or scales_property_block or full_ownership_leaves" -q`

Expected: PASS (3 tests).

- [ ] **Step 11: Run the whole backend suite**

Run: `cd backend && python -m pytest -q`

Expected: 479 passed (476 baseline + 3 new), 0 failed. If `test_ownership_share_scales_both_net_and_statutory` fails, `net_pl`/`statutory` are being scaled twice — check that Step 5 removed the `share *` from both accumulator lines. If a share-1.0 test fails, the bug is in `_scaled_lines` or a `_round2` applied before scaling.

- [ ] **Step 12: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/models/documind_models.py backend/tests/test_finance_engine.py
git commit -m "fix(finance): apply ownership share to every figure at one per-property choke point"
```

---

### Task 2: Expose `landlord_expenses` per property

Implements spec §2.3. The engine already computes `landlord_paid` per property but only accumulates it into the totals. The property panel needs it so "Expenses" means landlord cash out at every level.

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` (the `property_blocks.append` call)
- Modify: `backend/models/documind_models.py:236-256` (`PropertyFinance`)
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `s_landlord_paid` from Task 1 Step 5.
- Produces: JSON field `properties[].landlord_expenses: float` (Task 4 parses it, Task 6 renders it).

- [ ] **Step 1: Write the failing test**

Add to `backend/tests/test_finance_engine.py` in the same class as Task 1's tests:

```python
    def test_property_block_exposes_landlord_expenses_so_net_pl_reconciles(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            # Loan principal is landlord cash out but never LHDN-deductible,
            # so it separates the two expense bases.
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 100.0, "principal_paid": 300.0}),
        ]
        exceptions = [_doc_exception("p1", 2025, c)
                      for c in ("tax", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "Whole")], year=2025,
                          today=date(2026, 1, 1), document_exceptions=exceptions)
        block = result["properties"][0]
        # Deductible-only: interest alone.
        self.assertEqual(block["direct_expenses"], 100.0)
        # Cash out: interest + principal.
        self.assertEqual(block["landlord_expenses"], 400.0)
        # The point of the field — the property panel's arithmetic now closes.
        self.assertEqual(
            block["received_rent"] - block["landlord_expenses"], block["net_pl"]
        )
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k landlord_expenses_so_net_pl -q`

Expected: FAIL with `KeyError: 'landlord_expenses'`.

- [ ] **Step 3: Add the field to the property block**

In `compute_finance_summary`'s `property_blocks.append({...})`, add one entry directly after `"direct_expenses"`:

```python
            "landlord_expenses": _round2(s_landlord_paid),
```

- [ ] **Step 4: Add the field to the wire model**

In `backend/models/documind_models.py`, in `class PropertyFinance`, add after `direct_expenses`:

```python
    direct_expenses: float
    landlord_expenses: float = 0.0  # landlord cash out; pairs with net_pl
```

- [ ] **Step 5: Run the test**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k landlord_expenses_so_net_pl -q`

Expected: PASS.

- [ ] **Step 6: Run the whole backend suite**

Run: `cd backend && python -m pytest -q`

Expected: 480 passed, 0 failed.

- [ ] **Step 7: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/models/documind_models.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): expose landlord_expenses per property block"
```

---

### Task 3: The whole-property scope shows its own expense lines

Implements spec §3.1(a) — the root cause of "the unit did not capture loan figure as expenses". The synthetic whole-property scope receives an empty line list, so a property-scope loan appears in no drill-down at all.

**The trap:** property-level lines are *already* prorated into `prorated_expenses` further down via `avg_fraction`. If you also feed them through the in-scope `prorated_expenses +=` accumulation, the statutory total double-counts them. Display and proration must use different lists.

**Files:**
- Modify: `backend/rag/finance/finance_engine.py:1044-1077`
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `_scaled_lines` and `share` from Task 1.
- Produces: unit blocks whose `unit_id is None` carry `expense_lines`, and whose `contribution`/`statutory_contribution` account for them.

- [ ] **Step 1: Write the failing tests**

Add to `backend/tests/test_finance_engine.py` in the same class:

```python
    def test_whole_property_scope_carries_property_level_expense_lines(self):
        """A single-let house with no units: the whole-property block IS the
        property, so a property-scope loan must appear in its breakdown."""
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 200.0}),
        ]
        exceptions = [_doc_exception("p1", 2025, c)
                      for c in ("tax", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "House")], year=2025,
                          today=date(2026, 1, 1), document_exceptions=exceptions)
        unit = result["properties"][0]["units"][0]
        self.assertIsNone(unit["unit_id"])
        self.assertEqual(len(unit["expense_lines"]), 1)
        self.assertEqual(unit["expense_lines"][0]["category"], "loan")
        # And the block's own figures account for the line it now shows.
        self.assertEqual(unit["contribution"], 800.0)
        self.assertEqual(unit["statutory_contribution"], 800.0)

    def test_whole_property_scope_lines_do_not_double_count_in_statutory(self):
        """Regression guard on the trap: property-level lines are prorated once,
        via avg_fraction, not again through the scope loop."""
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 200.0}),
        ]
        exceptions = [_doc_exception("p1", 2025, c)
                      for c in ("tax", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "House")], year=2025,
                          today=date(2026, 1, 1), document_exceptions=exceptions)
        # 1 of 12 months rented -> 1000 - 200*(1/12) = 983.33. If the lines were
        # counted twice this would read 966.67.
        self.assertEqual(result["totals"]["statutory_rental_income"], 983.33)
        self.assertEqual(result["totals"]["net_pl"], 800.0)
        self.assertEqual(result["totals"]["direct_expenses"], 200.0)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k whole_property_scope -q`

Expected: the first FAILS on `len(unit["expense_lines"]) == 0 != 1`. The second should already PASS — it is the guard that must **stay** passing after Step 3.

- [ ] **Step 3: Separate display lines from proration lines**

In `compute_finance_summary`, find (around lines 1044-1054):

```python
            unit_lines = (
                lines_by_unit.get(scope["unit_id"], [])
                if scope["unit_id"] is not None else []
            )
            unit_deductible_total = sum(
                l["amount"] for l in unit_lines if l["deductible"]
            )
            unit_landlord_total = sum(
                l["amount"] for l in unit_lines if l["paid_by_landlord"]
            )
            prorated_expenses += unit_deductible_total * fraction
```

Replace with:

```python
            unit_lines = (
                lines_by_unit.get(scope["unit_id"], [])
                if scope["unit_id"] is not None else []
            )
            unit_deductible_total = sum(
                l["amount"] for l in unit_lines if l["deductible"]
            )
            # Proration keeps using the real-unit lines only. The property-level
            # lines are prorated once, below, by avg_fraction — feeding them in
            # here as well would double-count them in the statutory total.
            prorated_expenses += unit_deductible_total * fraction
            # Display lines: the synthetic whole-property scope shows the
            # property-level lines (a building-wide loan, quit rent) that belong
            # to no unit. For a single-let house that scope IS the property, so
            # showing an empty breakdown there hid the landlord's loan entirely.
            # Unit blocks are display-only — every total sums from `expense_lines`
            # — so widening what they show cannot move a total.
            display_lines = (
                unit_lines if scope["unit_id"] is not None
                else lines_by_unit.get(None, [])
            )
            display_deductible_total = sum(
                l["amount"] for l in display_lines if l["deductible"]
            )
            display_landlord_total = sum(
                l["amount"] for l in display_lines if l["paid_by_landlord"]
            )
```

- [ ] **Step 4: Point the unit block at the display lines**

In the same `unit_blocks.append({...})` call edited in Task 1 Step 4, swap the three entries to the display totals:

```python
                "contribution": _round2(
                    share * (actual_sum + derived_sum - display_landlord_total)
                ),
                "statutory_contribution": _round2(
                    share * (actual_sum + derived_sum - display_deductible_total)
                ),
                ...
                "expense_lines": _scaled_lines(display_lines, share),
```

For a real unit `display_lines is unit_lines`, so nothing about real units changes.

- [ ] **Step 5: Run the tests**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k whole_property_scope -q`

Expected: PASS (2 tests). If the second now fails at 966.67, Step 3 was applied wrongly and `display_deductible_total` is feeding `prorated_expenses`.

- [ ] **Step 6: Run the whole backend suite**

Run: `cd backend && python -m pytest -q`

Expected: 482 passed, 0 failed.

- [ ] **Step 7: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "fix(finance): show property-level expense lines on the whole-property scope"
```

---

### Task 4: Parse the two new fields in the Flutter model

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/finance_summary.dart`
- Modify: `residex_app/lib/features/landlord/data/models/finance_summary_model.dart`
- Test: `residex_app/test/features/landlord/finance_summary_model_test.dart`

**Interfaces:**
- Consumes: JSON `properties[].landlord_expenses` (Task 2), `*.expense_lines[].full_amount` (Task 1).
- Produces: `PropertyFinance.landlordExpenses` (double, default `0.0`) and `ExpenseLine.fullAmount` (`double?`, default `null`).

- [ ] **Step 1: Write the failing test**

Append to `residex_app/test/features/landlord/finance_summary_model_test.dart` inside the existing top-level `main()`:

```dart
  test('parses landlord_expenses and expense-line full_amount', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2026,
      'totals': {
        'received_rent': 500.0,
        'derived_rent': 0.0,
        'direct_expenses': 60.0,
        'net_pl': 440.0,
        'statutory_rental_income': 495.0,
        'statutory_note': '',
      },
      'properties': [
        {
          'property_id': 'p1',
          'name': 'Shared',
          'ownership_share': 0.5,
          'received_rent': 500.0,
          'derived_rent': 0.0,
          'direct_expenses': 60.0,
          'landlord_expenses': 60.0,
          'rental_income_or_loss': 440.0,
          'net_pl': 440.0,
          'expense_lines': [
            {'doc_id': 'd1', 'category': 'tax', 'amount': 60.0, 'full_amount': 120.0},
          ],
        },
      ],
    });
    final property = summary.properties.single;
    expect(property.landlordExpenses, 60.0);
    expect(property.expenseLines.single.fullAmount, 120.0);
  });

  test('full_amount is null when the landlord owns the whole property', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2026,
      'totals': {
        'received_rent': 1000.0,
        'derived_rent': 0.0,
        'direct_expenses': 120.0,
        'net_pl': 880.0,
        'statutory_rental_income': 990.0,
        'statutory_note': '',
      },
      'properties': [
        {
          'property_id': 'p1',
          'name': 'Whole',
          'received_rent': 1000.0,
          'derived_rent': 0.0,
          'direct_expenses': 120.0,
          'rental_income_or_loss': 880.0,
          'net_pl': 880.0,
          'expense_lines': [
            {'doc_id': 'd1', 'category': 'tax', 'amount': 120.0},
          ],
        },
      ],
    });
    expect(summary.properties.single.expenseLines.single.fullAmount, isNull);
    // Absent landlord_expenses must default, never crash the Finance tab.
    expect(summary.properties.single.landlordExpenses, 0.0);
  });
```

If the file's existing tests import differently, match the file's existing import block rather than adding new imports.

- [ ] **Step 2: Run it to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_summary_model_test.dart`

Expected: FAIL — compile error, `landlordExpenses`/`fullAmount` are not defined.

- [ ] **Step 3: Add the entity fields**

In `finance_summary.dart`, `class PropertyFinance`, add the field after `directExpenses` (line 52) and the matching constructor parameter after `required this.directExpenses,` (line 72):

```dart
  final double directExpenses;
  final double landlordExpenses;
```

```dart
    required this.directExpenses,
    this.landlordExpenses = 0.0,
```

In the same file, `class ExpenseLine`, add after `amount` (line 180) and after `required this.amount,` (line 191):

```dart
  final double amount;
  /// The source document's face value, present only when an ownership share
  /// below 1.0 scaled [amount]. Null means [amount] is the full figure.
  final double? fullAmount;
```

```dart
    required this.amount,
    this.fullAmount,
```

- [ ] **Step 4: Parse them**

In `finance_summary_model.dart`, in `_property` (after line 48):

```dart
      directExpenses: _d(json['direct_expenses']),
      landlordExpenses: _d(json['landlord_expenses']),
```

In `_lines` (after line 136):

```dart
              amount: _d(l['amount']),
              fullAmount: l['full_amount'] == null ? null : _d(l['full_amount']),
```

- [ ] **Step 5: Run the test**

Run: `cd residex_app && flutter test test/features/landlord/finance_summary_model_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/finance_summary.dart residex_app/lib/features/landlord/data/models/finance_summary_model.dart residex_app/test/features/landlord/finance_summary_model_test.dart
git commit -m "feat(finance): parse landlord_expenses and expense-line full_amount"
```

---

### Task 5: Finance-tab headline terminology

Implements spec §2.1/§2.2 for the aggregate level. The aggregate level prefixes **Overall**.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/finance_summary_panel.dart:43,48,123,245-247`
- Test: `residex_app/test/features/landlord/finance_screen_smoke_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: the exact strings `OVERALL NET PROFIT/LOSS · {year}`, `OVERALL RENTAL INCOME`, `OVERALL EXPENSES`, `Overall Statutory Income`, `Current Overall Statutory Income`.

- [ ] **Step 1: Write the failing test**

Append inside the existing `main()` of `residex_app/test/features/landlord/finance_screen_smoke_test.dart`. That file has no pump helper — its tests call `tester.pumpWidget` inline and build fixtures with `_fakeSummary(int year)` (line 9). Match that pattern exactly:

```dart
  testWidgets('finance tab headline uses the Overall glossary', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith((ref, year) async => _fakeSummary(year)),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OVERALL NET PROFIT/LOSS · 2026'), findsOneWidget);
    expect(find.text('OVERALL RENTAL INCOME'), findsOneWidget);
    expect(find.text('OVERALL EXPENSES'), findsOneWidget);
    expect(find.textContaining('Overall Statutory Income'), findsOneWidget);
    expect(find.text('TOTAL NET P/L · 2026'), findsNothing);
    expect(find.text('TOTAL RECEIVED'), findsNothing);
    expect(find.text('TOTAL EXPENSES'), findsNothing);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_smoke_test.dart`

Expected: FAIL — `find.text('OVERALL NET PROFIT/LOSS · 2026')` finds nothing.

- [ ] **Step 3: Change the four strings**

In `finance_summary_panel.dart`:

Line 123:
```dart
                      Text('OVERALL NET PROFIT/LOSS · ${summary.year}', style: headerStyle),
```

Line 43-46:
```dart
            final receivedCard = _SecondaryCard(
              label: 'OVERALL RENTAL INCOME',
              value: totals.receivedRent,
              headerStyle: _cardHeaderStyle,
            );
```

Line 47-51:
```dart
            final expensesCard = _SecondaryCard(
              label: 'OVERALL EXPENSES',
              value: totals.landlordExpenses,
              headerStyle: _cardHeaderStyle,
            );
```

Lines 245-247:
```dart
    final statutoryLabel = provisional
        ? 'Current Overall Statutory Income'
        : 'Overall Statutory Income';
```

- [ ] **Step 4: Run the test**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_smoke_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/finance_summary_panel.dart residex_app/test/features/landlord/finance_screen_smoke_test.dart
git commit -m "feat(finance): Overall glossary on the finance tab headline"
```

---

### Task 6: Property-panel terminology, and Expenses means cash out

Implements spec §2.1/§2.2/§2.3 for the property level. The property level uses the bare term, and `EXPENSES` switches from deductible-only to landlord cash out so `Rental Income − Expenses = Net Profit/Loss` holds.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:359,360,369,391`
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`

**Interfaces:**
- Consumes: `PropertyFinance.landlordExpenses` (Task 4).
- Produces: the exact strings `RENTAL INCOME`, `EXPENSES`, `Net Profit/Loss · {year}`, `Statutory Income`.

- [ ] **Step 1: Write the failing test**

Add inside `main()` in `residex_app/test/features/landlord/finance_screen_test.dart`:

```dart
  testWidgets('property panel uses the bare glossary and shows cash out', (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 3200.0, derivedRent: 0.0, directExpenses: 200.0,
        netPl: 2800.0, landlordExpenses: 400.0,
        statutoryRentalIncome: 3000.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 3200.0, derivedRent: 0.0,
          directExpenses: 200.0, landlordExpenses: 400.0,
          rentalIncomeOrLoss: 3000.0, netPl: 2800.0,
          statutoryContribution: 3000.0,
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('RENTAL INCOME'), findsOneWidget);
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.text('Net Profit/Loss · 2026'), findsOneWidget);
    expect(find.text('Statutory Income'), findsOneWidget);
    expect(find.text('RECEIVED'), findsNothing);
    expect(find.text('Net P/L · 2026'), findsNothing);
    // EXPENSES renders landlordExpenses (400), not directExpenses (200).
    expect(find.text('RM 400.00'), findsOneWidget);
  });
```

If `formatRM` renders differently from `RM 400.00`, run it once and match the real output rather than guessing.

- [ ] **Step 2: Run it to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`

Expected: FAIL — `find.text('RENTAL INCOME')` finds nothing.

- [ ] **Step 3: Change the four call sites**

In `finance_screen.dart`, lines 357-362:

```dart
          Row(
            children: [
              Expanded(child: _miniStat('RENTAL INCOME', block.receivedRent)),
              Expanded(child: _miniStat('EXPENSES', block.landlordExpenses)),
            ],
          ),
```

Line 369:
```dart
                child: Text('Net Profit/Loss · ${summary.year}',
```

Line 391:
```dart
                  'Statutory Income',
```

- [ ] **Step 4: Run the test**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`

Expected: PASS, including the file's pre-existing tests.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat(finance): property-panel glossary; Expenses means landlord cash out"
```

---

### Task 7: Unit-screen dropdown titles and roll-up captions

Implements spec §2.1/§2.2 for the unit level.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart:168-204`
- Test: `residex_app/test/features/landlord/unit_finance_detail_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: the exact strings `Rental income`, `Statutory income` as the two accordion titles.

- [ ] **Step 1: Write the failing test**

Add inside `main()` in `residex_app/test/features/landlord/unit_finance_detail_test.dart`. That file's helper is `_pumpScreen(WidgetTester tester, int year, UnitFinance unit)` (line 34) — it wraps the unit in `_summaryWithUnit` for you, so pass a `UnitFinance` directly:

```dart
  testWidgets('unit dropdowns use the bare glossary and name their roll-up',
      (tester) async {
    await _pumpScreen(tester, 2026, UnitFinance(
      unitId: 'u1', label: 'Unit 1', rentedMonths: 12,
      contribution: 3200.0, statutoryContribution: 3200.0,
    ));
    expect(find.text('Rental income'), findsOneWidget);
    expect(find.text('Statutory income'), findsOneWidget);
    expect(find.text('Net contribution'), findsNothing);
    expect(find.text('Contributing statutory income'), findsNothing);
    expect(find.textContaining("Contributes to this property's Rental Income"),
        findsOneWidget);
    expect(find.textContaining("Contributes to this property's Statutory Income"),
        findsOneWidget);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`

Expected: FAIL — `find.text('Rental income')` finds nothing.

- [ ] **Step 3: Rename and caption both accordions**

In `unit_finance_detail_screen.dart`, replace the doc comment and both builder methods at lines 168-204:

```dart
  /// Rental income and Statutory income are two separate dropdowns (user
  /// request). They differ in which lines count:
  ///  - Rental income subtracts everything the landlord actually paid
  ///    (penalties, principal and first-letting costs included), so those are
  ///    shown normally here and only tenant-paid lines are struck out.
  ///  - Statutory income subtracts only LHDN-deductible lines, so
  ///    penalties/capital/first-letting costs are struck out here.
  Widget _buildNetContributionAccordion(
      BuildContext context, UnitFinance unit, int year) {
    return _breakdownAccordion(
      context,
      title: 'Rental income',
      total: unit.contribution,
      gross: _grossIncome(unit),
      expensesLabel: 'Direct expenses',
      expensesTotal: landlordPaidExpenseTotal(unit.expenseLines),
      lines: unit.expenseLines,
      exclusionNote: _netExclusionNote,
      emptyNote: 'No direct expenses recorded for $year',
      caption: "Contributes to this property's Rental Income.",
    );
  }

  Widget _buildStatutoryAccordion(
      BuildContext context, UnitFinance unit, int year) {
    return _breakdownAccordion(
      context,
      title: 'Statutory income',
      total: unit.statutoryContribution,
      gross: _grossIncome(unit),
      expensesLabel: 'Deductible expenses',
      expensesTotal: deductibleExpenseTotal(unit.expenseLines),
      lines: unit.expenseLines,
      exclusionNote: expenseExclusionNote,
      emptyNote: 'No deductible expenses recorded — equals your gross income.',
      caption: "Contributes to this property's Statutory Income. "
          'Only LHDN-deductible expenses reduce this figure.',
    );
  }
```

`_breakdownAccordion` already accepts an optional `String? caption` (line 226) and renders it, so no signature change is needed.

- [ ] **Step 4: Run the test**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart residex_app/test/features/landlord/unit_finance_detail_test.dart
git commit -m "feat(finance): unit-level glossary with roll-up captions"
```

---

### Task 8: Remove the coverage-strip bubble

Implements spec Part 4 (defect 5). The `2025 · 2 missing` chips duplicate `DocumentNudgeBanner`.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:269-313,353-356`
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. `block.coverage` **stays** on the entity — `yearCoverageFor` still drives the "acknowledged unavailable" rows at line 504.

- [ ] **Step 1: Write the failing test**

Add inside `main()` in `finance_screen_test.dart`:

```dart
  testWidgets('coverage bubble is gone but the document nudge remains',
      (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 3200.0, derivedRent: 0.0, directExpenses: 200.0,
        netPl: 2800.0, landlordExpenses: 400.0,
        statutoryRentalIncome: 3000.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 3200.0, derivedRent: 0.0,
          directExpenses: 200.0, landlordExpenses: 400.0,
          rentalIncomeOrLoss: 3000.0, netPl: 2800.0,
          statutoryContribution: 3000.0,
          coverage: [
            YearCoverage(year: 2025, missing: ['tax', 'insurance']),
            YearCoverage(year: 2026, missing: const []),
          ],
        ),
      ],
      missingCategories: {'p1': ['tax', 'insurance']},
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('2025 · 2 missing'), findsNothing);
    expect(find.text('2025'), findsNothing);
    // The bottom panel still asks for the same documents.
    expect(find.textContaining('documents needed for 2026'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`

Expected: FAIL — `find.text('2025 · 2 missing')` finds one widget.

- [ ] **Step 3: Delete the call site**

In `finance_screen.dart`, delete these four lines (353-356) from `_buildPropertyBlock`:

```dart
          if (block.coverage.isNotEmpty) ...[
            _buildCoverageStrip(context, ref, block),
            const SizedBox(height: 10),
          ],
```

- [ ] **Step 4: Delete the widget**

Delete the whole `_buildCoverageStrip` method, lines 269-313 (from `Widget _buildCoverageStrip(` through its closing `}`).

- [ ] **Step 5: Remove the now-unused import if the analyzer flags it**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart`

Expected: no errors. If it reports an unused import, remove only that import. `yearCoverageFor` and `coverageLabels` are still used at line 504, so `finance_logic.dart` and `document_categories.dart` imports must stay.

- [ ] **Step 6: Run the test**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "refactor(finance): drop the coverage bubble, the nudge already covers it"
```

---

### Task 9: Ownership-share presentation

Implements spec §1 "Presentation" and the expense-line provenance decision. At `share == 1.0` nothing renders — this is purely additive for co-owned properties.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:405-412`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart` (the expense-line row inside `_breakdownAccordion`)
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`, `residex_app/test/features/landlord/unit_finance_detail_test.dart`

**Interfaces:**
- Consumes: `ExpenseLine.fullAmount` (Task 4).
- Produces: nothing consumed downstream.

- [ ] **Step 1: Write the failing tests**

In `finance_screen_test.dart`:

```dart
  testWidgets('co-owned property states the share basis plainly', (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 1600.0, derivedRent: 0.0, directExpenses: 100.0,
        netPl: 1400.0, landlordExpenses: 200.0,
        statutoryRentalIncome: 1500.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8', ownershipShare: 0.5,
          receivedRent: 1600.0, derivedRent: 0.0,
          directExpenses: 100.0, landlordExpenses: 200.0,
          rentalIncomeOrLoss: 1500.0, netPl: 1400.0,
          statutoryContribution: 1500.0,
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('Shown at your 50% share'), findsOneWidget);
    expect(find.textContaining("property's full figures"), findsNothing);
  });
```

In `unit_finance_detail_test.dart`, using the same `_pumpScreen(tester, year, unit)` helper (line 34) with expense lines on the `UnitFinance`:

```dart
  testWidgets('a scaled expense line shows the document face value',
      (tester) async {
    await _pumpScreen(tester, 2026, UnitFinance(
      unitId: 'u1', label: 'Unit 1', rentedMonths: 12,
      contribution: 600.0, statutoryContribution: 600.0,
      expenseLines: [
        ExpenseLine(
          docId: 'd1', category: 'tax', description: 'Quit rent',
          amount: 600.0, fullAmount: 1200.0,
        ),
      ],
    ));
    expect(find.textContaining('your 50% of'), findsOneWidget);
  });

  testWidgets('an unscaled expense line shows no provenance', (tester) async {
    await _pumpScreen(tester, 2026, UnitFinance(
      unitId: 'u1', label: 'Unit 1', rentedMonths: 12,
      contribution: 1200.0, statutoryContribution: 1200.0,
      expenseLines: [
        ExpenseLine(
          docId: 'd1', category: 'tax', description: 'Quit rent', amount: 1200.0,
        ),
      ],
    ));
    expect(find.textContaining('your'), findsNothing);
  });
```

The accordion may need expanding before its lines are in the tree. If either test fails on `findsNothing` where a line is expected, tap the accordion title first (`await tester.tap(find.text('Rental income')); await tester.pumpAndSettle();`).

- [ ] **Step 2: Run them to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart test/features/landlord/unit_finance_detail_test.dart`

Expected: FAIL on both new expectations.

- [ ] **Step 3: Replace the mixed-basis caption**

In `finance_screen.dart`, replace lines 405-412:

```dart
          if (block.ownershipShare < 1.0) ...[
            const SizedBox(height: 4),
            Text(
              'Shown at your ${(block.ownershipShare * 100).toStringAsFixed(0)}% share',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
```

- [ ] **Step 4: Add line provenance**

In `unit_finance_detail_screen.dart`, find the widget that renders one expense line's amount inside `_breakdownAccordion` (read the method — it is below line 229). Directly beneath the amount `Text`, add:

```dart
                    if (line.fullAmount != null)
                      Text(
                        'your ${((line.amount / line.fullAmount!) * 100).toStringAsFixed(0)}% '
                        'of ${formatRM(line.fullAmount!)}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted),
                      ),
```

Guard against a zero `fullAmount` by wrapping the condition as
`if (line.fullAmount != null && line.fullAmount! > 0)` — a zero-value line would otherwise divide by zero.

- [ ] **Step 5: Run the tests**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart test/features/landlord/unit_finance_detail_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart residex_app/test/features/landlord/finance_screen_test.dart residex_app/test/features/landlord/unit_finance_detail_test.dart
git commit -m "feat(finance): state the ownership-share basis and each line's face value"
```

---

### Task 10: Render property-level expenses

Implements spec §3.6 (defect 7). `propertyExpenseLines` is parsed and rendered nowhere, so a building-wide loan or quit rent appears in no drill-down.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart` (new section in `_buildPropertyBlock`)
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`

**Interfaces:**
- Consumes: `PropertyFinance.propertyExpenseLines` (already on the entity, line 58).
- Produces: nothing consumed downstream.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('property-level expenses are listed on the property panel',
      (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 3200.0, derivedRent: 0.0, directExpenses: 200.0,
        netPl: 2800.0, landlordExpenses: 400.0,
        statutoryRentalIncome: 3000.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 3200.0, derivedRent: 0.0,
          directExpenses: 200.0, landlordExpenses: 400.0,
          rentalIncomeOrLoss: 3000.0, netPl: 2800.0,
          statutoryContribution: 3000.0,
          propertyExpenseLines: [
            ExpenseLine(
              docId: 'd1', category: 'tax', description: 'Quit rent',
              amount: 120.0, date: '2026',
            ),
          ],
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('Property-level expenses'), findsOneWidget);
    expect(find.text('Quit rent'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`

Expected: FAIL — `find.text('Property-level expenses')` finds nothing.

- [ ] **Step 3: Add the section builder**

In `finance_screen.dart`, add this method to `FinanceScreen` (place it directly before `_buildRentIssuesSection`, around line 533):

```dart
  /// Property-scope costs — a building-wide loan, quit rent, assessment tax —
  /// belong to no unit, so they appear here rather than being split across
  /// units. Pro-rating them would invent a per-unit number the landlord could
  /// not tie back to any document.
  Widget _buildPropertyLevelExpenses(PropertyFinance block) {
    if (block.propertyExpenseLines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20, color: AppColors.hairline),
        Text('Property-level expenses', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        ...block.propertyExpenseLines.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line.description ?? line.category,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  Text(formatRM(line.amount), style: AppTextStyles.bodySmall),
                ],
              ),
            )),
      ],
    );
  }
```

- [ ] **Step 4: Call it**

In `_buildPropertyBlock`, add the call directly before `_buildRentIssuesSection(context, ref, block, summary.year),` (line 482):

```dart
          _buildPropertyLevelExpenses(block),
          _buildRentIssuesSection(context, ref, block, summary.year),
```

- [ ] **Step 5: Run the test**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat(finance): render property-level expenses on the property panel"
```

---

### Task 11: Property setup keeps only the mortgage question

Implements spec §3.3. Asking "upload or manual?" during registration is premature and sticky.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart:143-144,162-163,420-424,636-680`
- Test: `residex_app/test/features/landlord/add_property_dialog_loan_prefs_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: new properties are saved with `loanInputMethod: null` and `loanInputCadence: null`. Task 12 persists cadence later; Task 13 stops gating on method. **Nothing may read `loanInputMethod` to decide what to show after this task.**

> **Known interim gap, closed by Task 13.** From the end of this task until Task 13 Step 5, a newly created property has `loanInputMethod == null` while `finance_screen.dart:319-320` still requires `'manual'`, so its "Add loan figures" button stays hidden. This is expected between the two tasks — do not "fix" it here by re-adding the setup question. Existing properties are unaffected.

- [ ] **Step 1: Rewrite the test file's expectations**

Replace the two existing tests in `add_property_dialog_loan_prefs_test.dart` with:

```dart
  testWidgets('mortgage question stays', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: true))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Do you have a mortgage on this property?'), findsOneWidget);
  });

  testWidgets('loan method and cadence questions are gone', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: true))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('How do you record loan figures?'), findsNothing);
    expect(find.text('Upload statements'), findsNothing);
    expect(find.text('Enter manually'), findsNothing);
    expect(find.text('Annually'), findsNothing);
    expect(find.text('Monthly'), findsNothing);
  });
```

Keep the file's existing `_property` helper and imports.

- [ ] **Step 2: Run to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/add_property_dialog_loan_prefs_test.dart`

Expected: FAIL — "How do you record loan figures?" is found.

- [ ] **Step 3: Delete the selector call site**

In `add_property_dialog.dart`, replace lines 420-424:

```dart
                      _buildMortgageSelector(),
```

(That is: delete the `if (_hasMortgage == true) ...[ const SizedBox(height: 16), _buildLoanInputSelectors(), ],` block that follows it.)

- [ ] **Step 4: Delete the selector widget**

Delete the whole `_buildLoanInputSelectors` method (lines 636-680, from `Widget _buildLoanInputSelectors() {` through its closing `}`).

- [ ] **Step 5: Stop writing the two fields on save**

Replace line 143-144:

```dart
          loanInputCadence: property.loanInputCadence,
          loanInputMethod: property.loanInputMethod,
```

(preserving whatever the property already had, so editing a property never wipes a cadence Task 12 stored)

and lines 162-163, in the **create** branch, where there is no prior property:

```dart
          loanInputCadence: null,
          loanInputMethod: null,
```

- [ ] **Step 6: Remove the now-dead state fields**

Delete lines 46-47 (`String? _loanInputCadence;` / `String? _loanInputMethod;`) and lines 83-84 (their assignments in the edit branch).

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`

Expected: no errors, no unused-field warnings.

- [ ] **Step 7: Run the tests**

Run: `cd residex_app && flutter test test/features/landlord/add_property_dialog_loan_prefs_test.dart`

Expected: PASS (2 tests).

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart residex_app/test/features/landlord/add_property_dialog_loan_prefs_test.dart
git commit -m "refactor(property): ask only about the mortgage at registration"
```

---

### Task 12: Loan scope by structure type, and cadence asked in the sheet

Implements spec §3.2 and §3.4. A `Unit` is an individually titled apartment, so a strata property's loan is per-unit and "Whole property" is meaningless there. A landed house is one title with one loan even when the landlord created units for its rooms.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart`
- Test: `residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart` (create if absent)

**Interfaces:**
- Consumes: `Property.structureType` (`PropertyStructureType?`, values `landed` / `strata`), `Property.loanInputCadence`.
- Produces: `ManualLoanEntrySheet` gains a required `PropertyStructureType? structureType` parameter and its `cadence` parameter becomes `String?` (null = not yet chosen). Task 13's three call sites must pass both.

- [ ] **Step 1: Write the failing tests**

Create `residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart`. Model the `ProviderScope` overrides on `finance_screen_test.dart`'s `_pumpScreenWithProperty`, overriding `financeSummaryProvider` and `manualLoanEntriesProvider`.

```dart
  testWidgets('landed property offers no scope dropdown', (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.landed,
        units: [UnitFinance(unitId: 'u1', label: 'Room A', rentedMonths: 12, contribution: 0)],
        cadence: 'annual');
    expect(find.text('SCOPE'), findsNothing);
  });

  testWidgets('strata property with units offers units but not Whole property',
      (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.strata,
        units: [UnitFinance(unitId: 'u1', label: 'Unit 1', rentedMonths: 12, contribution: 0)],
        cadence: 'annual');
    expect(find.text('SCOPE'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String?>).first);
    await tester.pumpAndSettle();
    expect(find.text('Whole property'), findsNothing);
    expect(find.text('Unit 1'), findsWidgets);
  });

  testWidgets('strata property with no units offers no scope dropdown',
      (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.strata, units: const [], cadence: 'annual');
    expect(find.text('SCOPE'), findsNothing);
  });

  testWidgets('unknown structure type keeps both options', (tester) async {
    await _pumpSheet(tester,
        structureType: null,
        units: [UnitFinance(unitId: 'u1', label: 'Unit 1', rentedMonths: 12, contribution: 0)],
        cadence: 'annual');
    await tester.tap(find.byType(DropdownButton<String?>).first);
    await tester.pumpAndSettle();
    expect(find.text('Whole property'), findsWidgets);
  });

  testWidgets('cadence is asked when the property has none yet', (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.landed, units: const [], cadence: null);
    expect(find.text('One annual figure, or monthly instalments?'), findsOneWidget);
  });

  testWidgets('cadence is not re-asked once the property has one', (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.landed, units: const [], cadence: 'annual');
    expect(find.text('One annual figure, or monthly instalments?'), findsNothing);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_sheet_test.dart`

Expected: FAIL — compile error, `structureType` is not a parameter of `ManualLoanEntrySheet`.

- [ ] **Step 3: Widen the widget's parameters**

In `manual_loan_entry_sheet.dart`, replace the class fields and constructor (lines 17-29):

```dart
class ManualLoanEntrySheet extends ConsumerStatefulWidget {
  final String propertyId;
  final int year;

  /// Null until the landlord has chosen one — the sheet then asks and persists
  /// it to the property, so the question is posed when it is meaningful rather
  /// than during registration.
  final String? cadence;

  /// Decides the loan's real-world scope: a landed title carries one loan
  /// however many rooms are let, while each strata unit is separately titled
  /// and separately mortgaged. Null (some commercial) leaves both open.
  final PropertyStructureType? structureType;

  final List<UnitFinance> units;

  const ManualLoanEntrySheet({
    super.key,
    required this.propertyId,
    required this.year,
    required this.cadence,
    required this.structureType,
    required this.units,
  });
```

Add the import for `PropertyStructureType`:

```dart
import '../../../domain/entities/property.dart';
```

- [ ] **Step 4: Track the chosen cadence in state**

Add to `_ManualLoanEntrySheetState` (after line 41):

```dart
  String? _cadence;

  @override
  void initState() {
    super.initState();
    _cadence = widget.cadence;
  }
```

Replace both `widget.cadence` reads in `_save()` (lines 58 and 61) with `_cadence`:

```dart
        cadence: _cadence ?? 'annual',
        ...
        month: _cadence == 'monthly' ? _month : null,
```

and line 133 with:

```dart
    final isMonthly = _cadence == 'monthly';
```

- [ ] **Step 5: Gate the scope dropdown on structure type**

In `build`, replace the `if (units.isNotEmpty) ...[` guard around the SCOPE dropdown (line 176) with a computed flag. Add above the `return Material(`:

```dart
    // Landed = one title, one loan, whatever the room count. Strata = one loan
    // per separately-titled unit. Only an unknown structure keeps both open.
    final perUnitLoans =
        widget.structureType == PropertyStructureType.strata && units.isNotEmpty;
    final unknownStructure = widget.structureType == null && units.isNotEmpty;
    final showScope = perUnitLoans || unknownStructure;
```

Change the guard to `if (showScope) ...[` and make the "Whole property" item conditional inside the dropdown's `items` list (lines 187-197):

```dart
                    items: [
                      if (!perUnitLoans)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Whole property'),
                        ),
                      for (final u in units)
                        DropdownMenuItem<String?>(
                          value: u.unitId,
                          child: Text(u.label),
                        ),
                    ],
```

When `perUnitLoans` is true, `_selectedUnitId` starts as `null` with no matching item, which throws in `DropdownButton`. Default it in `initState`:

```dart
    if (widget.structureType == PropertyStructureType.strata &&
        widget.units.isNotEmpty) {
      _selectedUnitId = widget.units.first.unitId;
    }
```

- [ ] **Step 6: Ask for cadence when the property has none**

In `build`, directly after the `Text('Add loan figures — ${widget.year}', ...)` header (line 173-175), insert:

```dart
                if (_cadence == null) ...[
                  const SizedBox(height: 16),
                  Text('One annual figure, or monthly instalments?',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      AppChoiceChip(
                        label: 'One annual figure',
                        selected: false,
                        onSelected: (_) => _chooseCadence('annual'),
                      ),
                      AppChoiceChip(
                        label: 'Monthly instalments',
                        selected: false,
                        onSelected: (_) => _chooseCadence('monthly'),
                      ),
                    ],
                  ),
                ],
```

Add the `AppChoiceChip` import if the file lacks it — copy the exact import line from `add_property_dialog.dart`.

Add the handler, which persists the choice so the question is asked once:

```dart
  Future<void> _chooseCadence(String cadence) async {
    setState(() => _cadence = cadence);
    final property = await ref.read(propertyByIdProvider(widget.propertyId).future);
    if (property == null) return;
    await ref
        .read(propertyControllerProvider)
        .updateProperty(property.copyWith(loanInputCadence: cadence));
  }
```

`propertyControllerProvider` is a plain `Provider<PropertyController>` (`property_providers.dart:333`), **not** a NotifierProvider — read it directly, with no `.notifier`. Import `property_providers.dart`.

- [ ] **Step 7: Hide the entry form until cadence is chosen**

Wrap the interest/principal fields and the Save button in `if (_cadence != null) ...[ ... ]` so the sheet asks one question at a time.

- [ ] **Step 8: Keep the existing call site compiling**

Changing the constructor breaks the one existing caller. Task 13 restructures it properly; for now make it compile so this task ends on a working app. In `finance_screen.dart`, in the `ManualLoanEntrySheet(...)` call around line 432, replace the `cadence:` argument and add `structureType:`:

```dart
                  builder: (_) => ManualLoanEntrySheet(
                    propertyId: block.propertyId,
                    year: summary.year,
                    cadence: property?.loanInputCadence,
                    structureType: property?.structureType,
                    units: block.units
                        .where((u) => u.unitId != null)
                        .toList(),
                  ),
```

Add `import '../../../domain/entities/property.dart';` to `finance_screen.dart` if it is not already there.

- [ ] **Step 9: Run the tests**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_sheet_test.dart test/features/landlord/finance_screen_test.dart`

Expected: PASS (6 new tests, plus the finance-screen file's existing tests still green).

- [ ] **Step 10: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart
git commit -m "feat(loans): scope loan entry by structure type, ask cadence in the sheet"
```

---

### Task 13: Two entry points for manual loan entry

Implements spec §3.5. The nudge is in-context and year-scoped; the Loans & Financing folder is the persistent path for revisiting figures once the nudge has cleared.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/document_nudge_banner.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:319-320,420-445,485-502`
- Modify: `residex_app/lib/features/landlord/presentation/screens/5-Documents/documents_screen.dart` (loan category section)
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`, `residex_app/test/features/landlord/documents_screen_test.dart`

**Interfaces:**
- Consumes: `ManualLoanEntrySheet(propertyId:, year:, cadence:, structureType:, units:)` from Task 12.
- Produces: `DocumentNudgeBanner` gains `final VoidCallback? onEnterManually;` — when non-null it renders a third action.

- [ ] **Step 1: Write the failing tests**

In `finance_screen_test.dart`:

```dart
  testWidgets('nudge offers manual entry when a loan document is missing',
      (tester) async {
    final summary = _summaryWithProperty(2026, complete: false);
    await _pumpScreenWithProperty(
      tester, 2026,
      FinanceSummary(
        year: summary.year, totals: summary.totals,
        properties: summary.properties,
        missingCategories: const {'p1': ['loan']},
      ),
      _fakeProperty(hasMortgage: true, loanInputMethod: null),
    );
    expect(find.text('Enter figures manually'), findsOneWidget);
  });

  testWidgets('nudge omits manual entry when no loan document is missing',
      (tester) async {
    final summary = _summaryWithProperty(2026, complete: false);
    await _pumpScreenWithProperty(
      tester, 2026,
      FinanceSummary(
        year: summary.year, totals: summary.totals,
        properties: summary.properties,
        missingCategories: const {'p1': ['insurance']},
      ),
      _fakeProperty(hasMortgage: true, loanInputMethod: null),
    );
    expect(find.text('Enter figures manually'), findsNothing);
  });

  testWidgets('loan button no longer depends on loanInputMethod', (tester) async {
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryWithProperty(2026, complete: true, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true, loanInputMethod: null),
    );
    expect(find.text('Add loan figures'), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`

Expected: FAIL on all three.

- [ ] **Step 3: Add the optional third action to the banner**

In `document_nudge_banner.dart`, add the field and constructor parameter:

```dart
  final VoidCallback onMarkUnavailable;

  /// Non-null only when a loan document is among the missing ones — loan
  /// figures can be keyed in by hand, unlike every other category.
  final VoidCallback? onEnterManually;
```

```dart
    required this.onMarkUnavailable,
    this.onEnterManually,
```

Inside `build`, after `markUnavailableButton` (line 62), add:

```dart
          final enterManuallyButton = onEnterManually == null
              ? null
              : TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.registry,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onEnterManually,
                  child: const Text('Enter figures manually'),
                );
```

Then include it in both layout branches — replace the two `children: [uploadButton, markUnavailableButton],` lists with:

```dart
                  children: [
                    uploadButton,
                    if (enterManuallyButton != null) enterManuallyButton,
                    markUnavailableButton,
                  ],
```

With three buttons the wide branch can overflow. Change the wide-branch threshold at line 64 from `constraints.maxWidth >= 340` to:

```dart
          if (constraints.maxWidth >= (enterManuallyButton == null ? 340 : 480)) {
```

- [ ] **Step 4: Extract a sheet opener in the finance screen**

In `finance_screen.dart`, add this method to `FinanceScreen` (before `_buildPropertyBlock`, around line 315):

```dart
  void _openManualLoanSheet(
    BuildContext context,
    PropertyFinance block,
    Property? property,
    int year,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManualLoanEntrySheet(
        propertyId: block.propertyId,
        year: year,
        cadence: property?.loanInputCadence,
        structureType: property?.structureType,
        units: block.units.where((u) => u.unitId != null).toList(),
      ),
    );
  }
```

Add `import '../../../domain/entities/property.dart';` if the file lacks it.

- [ ] **Step 5: Ungate the Finance-tab button and reuse the opener**

Replace line 319-320:

```dart
    final showManualLoan = block.manualLoanIncomplete && property?.hasMortgage == true;
```

Replace the button's `onPressed` (lines 425-440) with:

```dart
                onPressed: () =>
                    _openManualLoanSheet(context, block, property, summary.year),
```

- [ ] **Step 6: Wire the nudge's third action**

Replace the `DocumentNudgeBanner(...)` call (lines 485-502) so it passes the new callback only for a missing loan:

```dart
            DocumentNudgeBanner(
              count: missing.length,
              year: summary.year,
              onUpload: () => showMissingDocumentsSheet(
                context, ref,
                propertyId: block.propertyId,
                year: summary.year,
                missing: missing,
                mode: MissingDocsMode.upload,
              ),
              onMarkUnavailable: () => showMissingDocumentsSheet(
                context, ref,
                propertyId: block.propertyId,
                year: summary.year,
                missing: missing,
                mode: MissingDocsMode.markUnavailable,
              ),
              onEnterManually: missing.contains('loan')
                  ? () => _openManualLoanSheet(
                      context, block, property, summary.year)
                  : null,
            ),
```

- [ ] **Step 7: Add the persistent path in the Loans & Financing folder**

In `documents_screen.dart`, find the `ElevatedButton.icon` that renders `'Upload ${getCategoryLabel(category)}'` (around line 745). Directly after it, inside the same `Column`'s `children`, add:

```dart
                      if (category == 'loan') ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _openManualLoanEntry(),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Enter figures manually'),
                        ),
                      ],
```

Add the handler to `_DocumentsScreenState`, opening the same sheet for the selected property and the current year:

```dart
  /// The persistent path to manual loan figures. The finance-tab nudge clears
  /// once figures exist, so without this there is no way back in to correct a
  /// typo.
  Future<void> _openManualLoanEntry() async {
    final propertyId = _selectedPropertyId;
    if (propertyId == null) return;
    final property = await ref.read(propertyByIdProvider(propertyId).future);
    final year = ref.read(financeYearProvider);
    final summary = await ref.read(financeSummaryProvider(year).future);
    final block = summary.properties
        .where((p) => p.propertyId == propertyId)
        .firstOrNull;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManualLoanEntrySheet(
        propertyId: propertyId,
        year: year,
        cadence: property?.loanInputCadence,
        structureType: property?.structureType,
        units: (block?.units ?? const [])
            .where((u) => u.unitId != null)
            .toList(),
      ),
    );
  }
```

Add imports for `ManualLoanEntrySheet`, `finance_providers.dart` and `property_providers.dart` if absent. `firstOrNull` needs `import 'package:collection/collection.dart';` — if that package is not already a dependency, use `.isEmpty ? null : ....first` instead rather than adding a dependency.

- [ ] **Step 8: Run the tests**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart test/features/landlord/documents_screen_test.dart`

Expected: PASS. If a pre-existing `finance_screen_test.dart` case asserted the button is hidden when `loanInputMethod` is not `manual` (there is one around line 132), it now contradicts the spec — update it to assert on `hasMortgage` instead, and note the change in the commit message.

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/document_nudge_banner.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/lib/features/landlord/presentation/screens/5-Documents/documents_screen.dart residex_app/test/features/landlord/finance_screen_test.dart residex_app/test/features/landlord/documents_screen_test.dart
git commit -m "feat(loans): manual entry from the document nudge and the Loans folder"
```

---

### Task 14: Distinguish the three retrieval failure classes

Implements spec §5.4. This is unconditional — it is what makes Task 15 diagnosable, and it stands on its own even if the root cause turns out to be environmental.

**Files:**
- Modify: `backend/rag/ask/ask_orchestrator.py:452-476`
- Test: `backend/tests/test_documind_service_flows.py`

**Interfaces:**
- Consumes: nothing.
- Produces: three distinct `AskResponse.answer` strings and three distinct `action_reason` values.

- [ ] **Step 1: Write the failing tests**

Add to `backend/tests/test_documind_service_flows.py`, following the file's existing orchestrator-test pattern (read a neighbouring test for how the orchestrator and its `_hybrid_retriever` are constructed/stubbed):

```python
    def test_index_error_tells_the_landlord_the_index_is_building(self):
        from google.api_core.exceptions import FailedPrecondition
        response = self._ask_with_retriever_error(
            FailedPrecondition("The query requires a vector index.")
        )
        self.assertIn("still building", response.answer)
        self.assertEqual(response.action_reason, "Vector index unavailable")

    def test_provider_error_reads_as_temporary(self):
        response = self._ask_with_retriever_error(
            ConnectionError("connection refused: localhost:11434")
        )
        self.assertIn("temporarily unavailable", response.answer)
        self.assertEqual(response.action_reason, "Retrieval backend unavailable")

    def test_unexpected_error_does_not_blame_the_index(self):
        response = self._ask_with_retriever_error(KeyError("doc_id"))
        self.assertIn("Something went wrong", response.answer)
        self.assertNotIn("index", response.answer.lower())
        self.assertEqual(response.action_reason, "Retrieval failure")
```

Add the helper `_ask_with_retriever_error(self, exc)` to the same class: it builds the orchestrator with a `_hybrid_retriever` whose `retrieve` raises `exc`, runs one `ask`, and returns the `AskResponse`.

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -k "index_error or provider_error or unexpected_error" -q`

Expected: FAIL — all three get the single old message and `action_reason == "Vector search failure"`.

- [ ] **Step 3: Split the handler**

In `ask_orchestrator.py`, add near the imports:

```python
import traceback
from google.api_core.exceptions import FailedPrecondition, ServiceUnavailable
```

Replace the `except Exception as e:` block (lines 462-476) with:

```python
        except Exception as e:
            # One catch-all used to report every failure as a vector-index
            # problem, which sent landlords to check an index that was usually
            # fine and hid the real cause in stdout. Each class now says
            # something true and actionable, and the traceback is always logged.
            print(f"❌ Hybrid retrieval failed: {type(e).__name__}: {e}")
            traceback.print_exc()
            if isinstance(e, FailedPrecondition):
                answer = ("Your document search index is still building. "
                          "Try again in a minute.")
                reason = "Vector index unavailable"
            elif isinstance(e, (ServiceUnavailable, ConnectionError, TimeoutError)):
                answer = ("Document search is temporarily unavailable. "
                          "Please try again shortly.")
                reason = "Retrieval backend unavailable"
            else:
                answer = "Something went wrong searching your documents."
                reason = "Retrieval failure"
            return AskResponse(
                answer=answer,
                confidence=0.0,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=predicted_categories,
                action_reason=reason,
            )
```

- [ ] **Step 4: Run the tests**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -k "index_error or provider_error or unexpected_error" -q`

Expected: PASS (3 tests).

- [ ] **Step 5: Run the whole backend suite**

Run: `cd backend && python -m pytest -q`

Expected: 485 passed, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/ask/ask_orchestrator.py backend/tests/test_documind_service_flows.py
git commit -m "fix(documind): distinguish index, provider and data retrieval failures"
```

---

### Task 15: Diagnose and fix the tenancy-agreement query

Implements spec §5.1-§5.3 (defect 4). **This task has no predetermined fix** — the spec's candidates are hypotheses, not conclusions. Do not implement a speculative fix.

**REQUIRED SUB-SKILL:** Use `superpowers:systematic-debugging` for this task.

**Files:**
- Read: `backend/rag/ask/retriever.py`, `backend/rag/ask/ask_orchestrator.py`
- Modify: whichever file the captured exception implicates.

**Interfaces:**
- Consumes: Task 14's traceback logging.
- Produces: nothing consumed downstream.

- [ ] **Step 1: Reproduce and capture**

Start the backend, then ask "When is the tenancy agreement ended" against a property that has an uploaded tenancy agreement. Capture the full traceback that Task 14 now prints.

Record verbatim in the task notes: exception type, message, and the frame it was raised in. **Do not proceed without it.**

- [ ] **Step 2: Confirm which hypothesis it matches**

Compare against the spec's four candidates:

1. `FailedPrecondition` naming a missing index → the category filter at `retriever.py:74-85` needs an index the unfiltered query does not. Follow the index-creation URL in the message, or drop the category filter for this query shape.
2. Connection error from `embed_query` at `retriever.py:47` → the local Ollama server is not running or `EMBEDDINGS_PROVIDER` is misconfigured.
3. `KeyError` at `retriever.py:95-101` → a stored chunk is missing `doc_id`, `filename` or `text`; those three are unguarded subscripts unlike the `.get()` calls beside them.
4. CrossEncoder load failure at `retriever.py:24` → the model is not cached and the machine is offline.

If it matches none, state that plainly and diagnose from the traceback.

- [ ] **Step 3: Write a regression test for the actual cause**

Write a test that fails against the current code for the specific cause found. For hypothesis 3, for example:

```python
    def test_chunk_missing_optional_fields_does_not_crash_retrieval(self):
        """A chunk stored before a field existed must not take down the whole
        query — it should be skipped, not raise."""
        retriever = self._retriever_with_chunks([
            {"embedding": [0.1] * 768, "category": "lease"},  # no doc_id/filename/text
        ])
        results = retriever._dense_search([0.1] * 768, "L1", "p1", ["lease"], 15)
        self.assertEqual(results, [])
```

Adapt the shape to whatever the real cause turns out to be.

- [ ] **Step 4: Run it to verify it fails**

Run: `cd backend && python -m pytest tests/ -k <your_test_name> -q`

Expected: FAIL, reproducing the captured exception.

- [ ] **Step 5: Fix the cause**

Implement the minimal fix the diagnosis points to. If the cause is purely environmental (a missing Firestore index, Ollama not running), the code fix is Task 14's message plus documenting the operational step — say so explicitly rather than inventing a code change.

- [ ] **Step 6: Verify against the real query**

Re-run the failing question through the running backend. Confirm it returns a cited answer drawn from the uploaded tenancy agreement — not just that the error message changed.

- [ ] **Step 7: Run the whole backend suite**

Run: `cd backend && python -m pytest -q`

Expected: 486 passed, 0 failed.

- [ ] **Step 8: Commit**

```bash
git add backend/rag/ask/<the file you changed> backend/tests/<the test file>
git commit -m "fix(documind): <the actual root cause, named precisely>"
```

---

### Task 16 (OPTIONAL — reviewer's call): Align the statutory basis

Implements spec §2.4 (defect 8). **The user has not approved this.** Confirm before starting; if declined, skip the task entirely — nothing else depends on it, which is why it is last.

The Finance-tab statutory total deducts occupancy-prorated expenses while the property block deducts all deductible expenses, so blocks do not sum to the headline. Aligning the block to the prorated basis **raises** displayed property-level statutory figures for any property with a vacancy.

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` (the `property_blocks.append` call)
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `s_prorated` from Task 1 Step 5.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

```python
    def test_property_blocks_sum_to_the_statutory_headline(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "tax", {"subtype": "quit_rent", "amount": 120.0, "period_year": 2025}),
        ]
        exceptions = [_doc_exception("p1", 2025, c)
                      for c in ("loan", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "House")], year=2025,
                          today=date(2026, 1, 1), document_exceptions=exceptions)
        block_sum = sum(p["statutory_contribution"] for p in result["properties"])
        self.assertEqual(block_sum, result["totals"]["statutory_rental_income"])
        # 1 of 12 months rented: 1000 - 120*(1/12) = 990.0, not 880.0.
        self.assertEqual(result["properties"][0]["statutory_contribution"], 990.0)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k blocks_sum_to_the_statutory -q`

Expected: FAIL — the block reads 880.0 against a headline of 990.0.

- [ ] **Step 3: Switch the block to the prorated basis**

In the `property_blocks.append({...})` call, change one entry:

```python
            "statutory_contribution": _round2(s_received - s_prorated),
```

- [ ] **Step 4: Run the test**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -k blocks_sum_to_the_statutory -q`

Expected: PASS.

- [ ] **Step 5: Run the whole backend suite**

Run: `cd backend && python -m pytest -q`

Expected: 487 passed, 0 failed. Several existing tests assert the old property-block statutory value; each failure must be inspected and updated **only** where the new prorated figure is genuinely correct.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "fix(finance): put property-block statutory on the same prorated basis as the total"
```

---

## Final verification

- [ ] **Backend:** `cd backend && python -m pytest -q` → all passing, 0 failures.
- [ ] **Flutter:** `cd residex_app && flutter test` → exactly 1 failure, and it is `widget_test.dart` "Counter increments".
- [ ] **Analyzer:** `cd residex_app && flutter analyze` → no new errors.
- [ ] **Manual, on device** (spec "Manual, on device"):
  - Enter a loan figure on a **landed** property (no scope dropdown) and confirm it appears in the whole-property breakdown and in Net Profit/Loss.
  - Enter a loan figure on a **strata** unit (units-only dropdown) and confirm it lands in that unit's breakdown.
  - Open a **co-owned** property and confirm every level reads at share, the levels reconcile, and lines show "your X% of RM …".
  - Confirm the property panel shows no coverage bubble and still shows the document nudge.
  - Ask the DocuMind tenancy-agreement question and confirm a cited answer.
- [ ] **Working tree:** `git status --porcelain | wc -l` should still show the unrelated WIP files and nothing you meant to commit.
