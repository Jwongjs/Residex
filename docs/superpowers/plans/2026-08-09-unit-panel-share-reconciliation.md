# Unit Panel Share Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every figure on the unit finance detail panel reconcile at any ownership share, by having the engine emit the gross income it actually used instead of letting the panel compute its own.

**Architecture:** The finance engine already applies ownership share at three separate moments; the panel picks up two of them and recomputes the third from unscaled month rows. The fix is backend-emitted: the engine gains `gross_income` / `full_gross_income` on each unit block and scales the month rows it renders, following the exact convention `_scaled_lines` already uses for expense lines (scaled value always, face value only below 100%). The panel then deletes its local `_grossIncome()` and derives every percentage it displays from the figure pair itself, never from a share field — which is what keeps this work valid when ownership share later moves from the property to the unit.

**Tech Stack:** Python 3.11 + `unittest` (backend engine and tests), Flutter/Dart + `flutter_test` (app), Firestore (persistence).

## Global Constraints

- **Never `git add -A` on `feat/finance-tab-restructure`.** An unrelated fact-aware-answering / citation-precision workstream is live and uncommitted in this tree, including hunks inside `backend/rag/documind_service.py` and `backend/tests/test_documind_service_flows.py`. Stage only the files each task names.
- **Never touch** `backend/rexAI.txt` or `backend/scripts/{diagnose,fix}_ayer8_lease*.py`.
- **Never fix** `residex_app/test/widget_test.dart` "Counter increments smoke test". It is a pre-existing boilerplate failure and is part of the baseline.
- **Run the full suite every time, never a scoped one.** Baseline to hold: backend **613 passed / 0 failed**; Flutter **303 passed / 1 failed**; `flutter analyze` 292 issues / **0 errors**.
  - Backend: `cd backend && py -3.11 -m pytest tests/ -q`
  - Flutter: `cd residex_app && flutter test`
  - The backend *total* drifts between runs because `tests/test_fact_locator.py` belongs to another in-flight workstream. Judge by **zero failures**, plus the count in the file you touched.
- **Loan interest and principal are never scaled by ownership share.** That is settled (`_line_share`, `finance_engine.py:437-441`). No task may change it.
- At **share 1.0** every payload in this plan must be byte-identical to today. This is the single most important regression property; several tests below exist only to pin it.

---

## File Structure

**Backend**
- `backend/rag/finance/finance_engine.py` — the only production file changed. Gains `_scaled_month_rows` beside `_scaled_lines`; the unit-block assembly (`:1179-1193`) and the property income sum (`:1263-1274`) are edited in place.
- `backend/scripts/audit_rent_recovery_shares.py` — **new**, read-only pre-flight audit (Task 1). Reused by Task 5's correction if rows are found.
- `backend/tests/test_finance_engine.py` — all backend tests.

**Flutter**
- `residex_app/lib/features/landlord/domain/entities/finance_summary.dart` — `UnitFinance` and `MonthIncome` gain fields.
- `residex_app/lib/features/landlord/data/models/finance_summary_model.dart` — JSON mapping for those fields.
- `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart` — deletes `_grossIncome`, renders the sub-label and the strip heading.
- `residex_app/lib/features/landlord/presentation/widgets/common/rent_payment_sheets.dart` — the recovery sheet's adaptive label.
- `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart` — one call site threading a new argument.
- Tests: `finance_summary_model_test.dart`, `unit_finance_detail_test.dart`, `unit_finance_detail_screen_test.dart`. (`monthly_net_series_test.dart` is run as a regression check but not edited — see Task 7 Step 7.)

---

### Task 1: Pre-flight audit of stored rent recoveries

Task 4 changes the meaning of data already in Firestore: every `documind_rent_recoveries` document was entered at face value and is currently scaled on read. After Task 4 it is booked in full. **This only matters for recoveries whose property has `ownership_share < 1.0`** — at 1.0 the change is a no-op. This task finds out whether any exist. Do not assume the set is empty.

**Files:**
- Create: `backend/scripts/audit_rent_recovery_shares.py`

**Interfaces:**
- Consumes: nothing.
- Produces: a printed report. Its row count decides whether Task 5 runs.

- [ ] **Step 1: Write the audit script**

```python
"""Read-only: list every stored rent recovery on a partial-share property.

The finance engine currently multiplies recovered rent by ownership_share on
read (finance_engine.py:1274). The unit-panel share reconciliation plan stops
doing that, because the recovery sheet will ask the landlord for their own
share directly. Recoveries already stored at face value on a property with
share < 1.0 would therefore start being booked in full.

Writes nothing. Run before the engine change:
    cd backend && uv run python scripts/audit_rent_recovery_shares.py
"""
import os
import sys

# Put backend/ (this file's grandparent) on the path so `rag` imports whether
# launched as `python scripts/...` or `-m scripts...`.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from google.cloud import firestore  # noqa: E402  (import after load_dotenv)


def main() -> int:
    db = firestore.Client()
    shares = {}
    for snap in db.collection('documind_properties').stream():
        data = snap.to_dict() or {}
        share = data.get('ownership_share')
        shares[snap.id] = (
            data.get('name') or snap.id,
            1.0 if share is None else float(share),
        )

    affected = []
    total = 0
    for snap in db.collection('documind_rent_recoveries').stream():
        data = snap.to_dict() or {}
        total += 1
        pid = data.get('property_id')
        name, share = shares.get(pid, (pid, 1.0))
        if share < 1.0:
            affected.append((snap.id, name, share, data.get('original_month'),
                             data.get('received_year'), data.get('amount')))

    print(f"{total} rent recovery record(s) scanned.")
    if not affected:
        print("0 on a partial-share property — no correction needed.")
        return 0

    print(f"{len(affected)} on a partial-share property:\n")
    for doc_id, name, share, month, year, amount in affected:
        print(f"  {doc_id}")
        print(f"    property   {name} at {share:.0%}")
        print(f"    original   {month}   received {year}")
        print(f"    amount     RM {float(amount or 0):,.2f}"
              f"  ->  would become RM {float(amount or 0) * share:,.2f}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
```

The `load_dotenv()`-then-`firestore.Client()` bootstrap and the `sys.path` line are copied from `backend/scripts/backfill_fact_pages.py:25-40`, which is the working precedent in this repo. It needs the gitignored `backend/.env`.

- [ ] **Step 2: Run the audit**

Run: `cd backend && uv run python scripts/audit_rent_recovery_shares.py`
Expected: a scan count, then either "0 on a partial-share property" or an itemised list.

- [ ] **Step 3: Record the result in the plan**

Edit this file and replace the line below with the actual output summary:

> **AUDIT RESULT (2026-08-10):** 0 rent recovery record(s) scanned; 0 on a
> partial-share property. The `documind_rent_recoveries` collection is empty,
> so Task 4's change of meaning has no stored data to affect and **Task 5 is a
> no-op**.

If the count is 0, Task 5 is a no-op and says so. If it is above 0, Task 5 corrects exactly those documents.

- [ ] **Step 4: Commit**

```bash
git add backend/scripts/audit_rent_recovery_shares.py docs/superpowers/plans/2026-08-09-unit-panel-share-reconciliation.md
git commit -m "chore: read-only audit of rent recoveries on partial-share properties"
```

---

### Task 2: Engine emits `gross_income`, and rounds once before subtracting

**Files:**
- Modify: `backend/rag/finance/finance_engine.py:1179-1193`
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: nothing.
- Produces: each unit block in `result["properties"][i]["units"][j]` gains `gross_income: float` (always) and `full_gross_income: float` (present **only** when `share < 1.0`). Task 5 maps both to Dart; Task 6 renders them.

- [ ] **Step 1: Write the failing tests**

Append a new test class to `backend/tests/test_finance_engine.py`. It reuses the module-level `_doc`, `_prop` and `_summary` helpers already defined at the top of that file.

```python
class UnitGrossIncomeTests(unittest.TestCase):
    """The panel renders `gross - expenses = total` as three stacked figures.
    That subtraction has to be true of the numbers actually emitted, so gross
    is emitted rather than re-derived by the app from unscaled month rows."""

    def _docs(self):
        return [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u1"),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 600.0, "period_year": 2025},
            ]}, unit_id="u1"),
        ]

    def _unit_at(self, share):
        result = _summary(self._docs(), [_prop("p1", "Block", share=share)],
                          units={"p1": [{"unit_id": "u1", "label": "A-1"}]})
        return result["properties"][0]["units"][0]

    def test_gross_income_is_the_share_of_actual_plus_derived(self):
        unit = self._unit_at(0.5)
        # 12 derived months at 1000 = 12000 full; half is 6000.
        self.assertAlmostEqual(unit["gross_income"], 6000.0, places=2)
        self.assertAlmostEqual(unit["full_gross_income"], 12000.0, places=2)

    def test_full_gross_income_is_absent_at_full_share(self):
        # The absence of the field is how the app decides not to render a
        # "your N% of" sub-label. Emitting it at 1.0 would show "your 100% of".
        unit = self._unit_at(1.0)
        self.assertAlmostEqual(unit["gross_income"], 12000.0, places=2)
        self.assertNotIn("full_gross_income", unit)

    def test_contribution_equals_gross_minus_landlord_paid_lines(self):
        unit = self._unit_at(0.5)
        landlord_paid = sum(l["amount"] for l in unit["expense_lines"]
                            if l["paid_by_landlord"])
        self.assertAlmostEqual(
            unit["contribution"], unit["gross_income"] - landlord_paid, places=2
        )

    def test_statutory_equals_gross_minus_deductible_lines(self):
        unit = self._unit_at(0.5)
        deductible = sum(l["amount"] for l in unit["expense_lines"]
                         if l["deductible"])
        self.assertAlmostEqual(
            unit["statutory_contribution"], unit["gross_income"] - deductible,
            places=2
        )

    def test_the_rendered_subtraction_is_exact_on_a_half_cent(self):
        # THE ROUNDING GATE. 3 months at 1000.01 = 3000.03; half is 1500.015,
        # which rounds up to 1500.02 on its own but can land a cent lower when
        # the whole `share * income - expenses` expression is rounded as one.
        # A one-cent gap here means the panel renders 1500.02 - 200.00 =
        # 1300.01 above a total that says 1300.00 — the same defect this plan
        # removes, one cent wide. Reverting to the single-expression form
        # breaks this and nothing else.
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.01, "period_month": "2025-01"},
                 unit_id="u1"),
            _doc("p1", "rental_invoice", {"amount": 1000.01, "period_month": "2025-02"},
                 unit_id="u1"),
            _doc("p1", "rental_invoice", {"amount": 1000.01, "period_month": "2025-03"},
                 unit_id="u1"),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 400.0, "period_year": 2025},
            ]}, unit_id="u1"),
        ]
        result = _summary(docs, [_prop("p1", "Block", share=0.5)],
                          units={"p1": [{"unit_id": "u1", "label": "A-1"}]})
        unit = result["properties"][0]["units"][0]
        landlord_paid = sum(l["amount"] for l in unit["expense_lines"]
                            if l["paid_by_landlord"])
        self.assertEqual(
            round(unit["gross_income"] - landlord_paid, 2), unit["contribution"]
        )
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitGrossIncomeTests -v`
Expected: FAIL — `KeyError: 'gross_income'` on every test except `test_full_gross_income_is_absent_at_full_share`, which fails on the same key.

- [ ] **Step 3: Emit gross and build both totals from it**

In `backend/rag/finance/finance_engine.py`, replace the `unit_blocks.append({...})` call at `:1179-1193` with:

```python
            # Gross is rounded once, here, and both totals are built from the
            # rounded value. Rounding `share * income - expenses` as a single
            # expression instead lets the emitted gross and the emitted total
            # disagree by a cent, which the app renders as a subtraction that
            # does not work. `full_gross_income` follows _scaled_lines'
            # convention: present only below full ownership, where it is a
            # different number from `gross_income`.
            gross_income = _round2(share * (actual_sum + derived_sum))
            block: Dict[str, Any] = {
                "unit_id": scope["unit_id"],
                "label": scope["label"],
                "rented_months": rented,
                "gross_income": gross_income,
                "contribution": _round2(gross_income - display_landlord_scaled),
                "statutory_contribution": _round2(
                    gross_income - display_deductible_scaled
                ),
                "months": month_rows,
                "missing_invoice_months": vacant,
                "expense_lines": _scaled_lines(display_lines, share),
                "loan_status": loan_status_by_unit.get(scope["unit_id"]),
            }
            if share < 1.0:
                block["full_gross_income"] = _round2(actual_sum + derived_sum)
            unit_blocks.append(block)
```

- [ ] **Step 4: Run the new tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::UnitGrossIncomeTests -v`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** A unit figure may have moved by one cent; that is the intended effect of rounding once. If a test fails on a one-cent difference, update that test's expected value and say so in the commit body — do not revert the rounding order.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): emit unit gross_income and round it once before subtracting"
```

---

### Task 3: Engine scales the month rows it renders

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` — new helper after `_scaled_lines` (`:444-466`); one call site in the unit block from Task 2
- Modify: `backend/tests/test_finance_engine.py:2183`, `:2195` — two existing assertions whose contract changes
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `gross_income` from Task 2.
- Produces: `_scaled_month_rows(rows: List[Dict[str, Any]], share: float) -> List[Dict[str, Any]]`. Each rendered month row may now carry `full_amount` and `full_billed_amount`, both only below share 1.0. Task 5 maps them; Tasks 6-8 read them.

> **Two existing tests will fail, and that is expected.** `test_unit_contribution_reconciles_against_its_own_lines_at_half_share` and `test_unit_statutory_reconciles_and_keeps_loan_interest_whole` both compute `gross = sum(m["amount"] for m in unit["months"])` and then multiply by `0.5`. Once the rows arrive scaled, that multiplies a second time. They encode the *old* contract of `months[].amount`. Step 5 rewrites them to read `unit["gross_income"]`, which makes them stronger — they then assert the exact reconciliation identity the panel renders. **No other existing test may be edited in this task.** If a third one fails, stop and report it rather than adjusting it.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_finance_engine.py`:

```python
class ScaledMonthRowTests(unittest.TestCase):
    """The month strip is the source the panel's gross line sums from, so its
    rows have to carry the same share treatment as everything stacked around
    them. The property-level sums are scaled elsewhere and must not move."""

    def _docs(self):
        return [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u1"),
        ]

    def _result_at(self, share, payment_exceptions=None):
        return _summary(self._docs(), [_prop("p1", "Block", share=share)],
                        units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
                        payment_exceptions=payment_exceptions)

    def test_month_rows_are_scaled_and_carry_the_face_value(self):
        unit = self._result_at(0.5)["properties"][0]["units"][0]
        january = next(m for m in unit["months"] if m["month"] == 1)
        self.assertAlmostEqual(january["amount"], 500.0, places=2)
        self.assertAlmostEqual(january["full_amount"], 1000.0, places=2)

    def test_month_rows_are_untouched_at_full_share(self):
        unit = self._result_at(1.0)["properties"][0]["units"][0]
        january = next(m for m in unit["months"] if m["month"] == 1)
        self.assertAlmostEqual(january["amount"], 1000.0, places=2)
        self.assertNotIn("full_amount", january)
        self.assertNotIn("full_billed_amount", january)

    def test_the_strip_sums_to_gross_income(self):
        # The whole point: the figures stacked on the panel now agree.
        unit = self._result_at(0.5)["properties"][0]["units"][0]
        strip = sum(m["amount"] for m in unit["months"]
                    if m["source"] in ("actual", "derived"))
        self.assertAlmostEqual(strip, unit["gross_income"], places=2)

    def test_billed_amount_is_scaled_and_carries_the_face_value(self):
        result = self._result_at(0.5, payment_exceptions=[_exception("p1", "2025-03")])
        unit = result["properties"][0]["units"][0]
        march = next(m for m in unit["months"] if m["month"] == 3)
        self.assertAlmostEqual(march["billed_amount"], 500.0, places=2)
        self.assertAlmostEqual(march["full_billed_amount"], 1000.0, places=2)

    def test_outstanding_rent_is_not_double_scaled(self):
        # THE TRAP GATE. `_scope_income` returns `billed` in the rendered rows
        # AND in its `unpaid_months` tuples, and the tuple path already feeds
        # prop_outstanding, which is scaled once at the property level. Scaling
        # the tuple as well quarters this figure, and every other test in this
        # file stays green. 1000 billed at 50% = 500.
        result = self._result_at(0.5, payment_exceptions=[_exception("p1", "2025-03")])
        self.assertAlmostEqual(
            result["properties"][0]["outstanding_rent"], 500.0, places=2
        )
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::ScaledMonthRowTests -v`
Expected: FAIL on `test_month_rows_are_scaled_and_carry_the_face_value` (amount is 1000.0, `full_amount` missing), `test_the_strip_sums_to_gross_income`, and `test_billed_amount_is_scaled_and_carries_the_face_value`. The two "not double-scaled / untouched at full share" tests pass already — they are guards, not drivers.

- [ ] **Step 3: Add the helper**

In `backend/rag/finance/finance_engine.py`, immediately after `_scaled_lines` ends at `:466`:

```python
def _scaled_month_rows(rows: List[Dict[str, Any]], share: float) -> List[Dict[str, Any]]:
    """Copy month rows with amounts at the landlord's ownership share.

    Mirrors _scaled_lines: never mutates the input, returns the rows unchanged
    at share 1.0 so the common payload is byte-identical, and below 1.0 carries
    the source figure in `full_amount` / `full_billed_amount` so the app can
    show "your 50% of RM 1,000.00". Zero-amount rows (vacant, outstanding) are
    left alone — they render a state, not a figure.

    Only the *rendered* rows are scaled. `_scope_income`'s scalar returns
    (actual_sum, derived_sum) and its `unpaid_months` tuples stay at face
    value: those feed the property-level received and outstanding sums, which
    are scaled separately at the property level. Scaling them here as well
    would scale them twice, and no property-level assertion would notice.
    """
    if share == 1.0:
        return list(rows)
    out: List[Dict[str, Any]] = []
    for row in rows:
        scaled = dict(row)
        if row.get("amount"):
            scaled["amount"] = _round2(share * row["amount"])
            scaled["full_amount"] = _round2(row["amount"])
        if row.get("billed_amount"):
            scaled["billed_amount"] = _round2(share * row["billed_amount"])
            scaled["full_billed_amount"] = _round2(row["billed_amount"])
        out.append(scaled)
    return out
```

- [ ] **Step 4: Call it from the unit block**

In the block added by Task 2, change the one line:

```python
                "months": month_rows,
```

to:

```python
                "months": _scaled_month_rows(month_rows, share),
```

- [ ] **Step 5: Update the two existing tests whose contract changed**

In `backend/tests/test_finance_engine.py`, in `test_unit_contribution_reconciles_against_its_own_lines_at_half_share`, replace:

```python
        gross = sum(m["amount"] for m in unit["months"])
        landlord_paid = sum(l["amount"] for l in unit["expense_lines"]
                            if l["paid_by_landlord"])
        self.assertAlmostEqual(
            unit["contribution"], 0.5 * gross - landlord_paid, places=2
        )
```

with:

```python
        # `months` now arrives already scaled, so gross is read rather than
        # re-derived. This asserts the identity the panel renders.
        landlord_paid = sum(l["amount"] for l in unit["expense_lines"]
                            if l["paid_by_landlord"])
        self.assertAlmostEqual(
            unit["contribution"], unit["gross_income"] - landlord_paid, places=2
        )
```

And in `test_unit_statutory_reconciles_and_keeps_loan_interest_whole`, replace:

```python
        gross = sum(m["amount"] for m in unit["months"])
        deductible = sum(l["amount"] for l in unit["expense_lines"]
                         if l["deductible"])
        self.assertAlmostEqual(
            unit["statutory_contribution"], 0.5 * gross - deductible, places=2
        )
```

with:

```python
        deductible = sum(l["amount"] for l in unit["expense_lines"]
                         if l["deductible"])
        self.assertAlmostEqual(
            unit["statutory_contribution"], unit["gross_income"] - deductible,
            places=2
        )
```

Leave the rest of both tests, including the `by_subtype` face-value assertions, exactly as they are.

- [ ] **Step 6: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** If any test other than those two fails, stop and report which — do not edit it.

- [ ] **Step 7: Prove the trap gate has teeth**

Temporarily scale the tuple as well: in `_scope_income`, change `unpaid_months.append((month, reason, state, billed))` to `unpaid_months.append((month, reason, state, billed and billed * 0.5))`.

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py -q`
Expected: `test_outstanding_rent_is_not_double_scaled` FAILS. **Revert the temporary change** and re-run to confirm green.

- [ ] **Step 8: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): scale the month rows the unit panel renders"
```

---

### Task 4: Recovered rent is stored at the landlord's share

**Files:**
- Modify: `backend/rag/finance/finance_engine.py:1263`, `:1274`
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `s_received` no longer scales `prop_recovered`. Task 8 relies on this when it asks the landlord for their own share.

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_finance_engine.py`. It uses the module-level `_recovery` helper already defined near the top of the file.

```python
class RecoveryShareTests(unittest.TestCase):
    """A recovery is typed in by the landlord, not read off a document, and
    the sheet asks a partial-share owner for their own share. So it is stored
    as the landlord's money already and must not be scaled again on read."""

    def _docs(self):
        return [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}),
        ]

    def test_recovered_rent_is_not_scaled_by_ownership_share(self):
        result = _summary(
            self._docs(), [_prop("p1", "House", share=0.5)],
            rent_recoveries=[_recovery("p1", "2024-03", 900.0, 2025)],
        )
        block = result["properties"][0]
        # 12 derived months at 1000 = 12000, halved = 6000, plus the 900
        # recovery at face value.
        self.assertAlmostEqual(block["received_rent"], 6900.0, places=2)

    def test_rent_income_is_still_scaled_alongside_it(self):
        # Guards the other half: exempting recoveries must not exempt rent.
        result = _summary(self._docs(), [_prop("p1", "House", share=0.5)])
        self.assertAlmostEqual(
            result["properties"][0]["received_rent"], 6000.0, places=2
        )

    def test_full_share_is_unaffected(self):
        result = _summary(
            self._docs(), [_prop("p1", "House", share=1.0)],
            rent_recoveries=[_recovery("p1", "2024-03", 900.0, 2025)],
        )
        self.assertAlmostEqual(
            result["properties"][0]["received_rent"], 12900.0, places=2
        )
```

- [ ] **Step 2: Run the tests to verify the first one fails**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::RecoveryShareTests -v`
Expected: `test_recovered_rent_is_not_scaled_by_ownership_share` FAILS with 6450.0 != 6900.0 (the recovery arrives halved). The other two pass — they are guards.

- [ ] **Step 3: Stop scaling recoveries**

In `backend/rag/finance/finance_engine.py`, delete line `:1263`:

```python
        received = prop_actual + prop_derived + prop_recovered
```

and replace line `:1274`:

```python
        s_received = share * received
```

with:

```python
        # Recovered rent is exempt from the share multiply. Invoiced and
        # lease-derived rent come off documents that state the whole
        # property's figure; a recovery is typed in by the landlord, and the
        # sheet asks a partial-share owner for their own share directly. It is
        # already their money.
        s_received = share * (prop_actual + prop_derived) + prop_recovered
```

The local `received` had exactly one consumer, so nothing else changes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::RecoveryShareTests -v`
Expected: PASS, 3 tests.

- [ ] **Step 5: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.**

- [ ] **Step 6: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): stop scaling recovered rent by ownership share"
```

---

### Task 5: Correct stored recoveries — only if Task 1 found any

**Files:**
- Create: `backend/scripts/fix_rent_recovery_shares.py` *(only if Task 1 reported rows)*

**Interfaces:**
- Consumes: Task 1's audit result; Task 4's behaviour change.
- Produces: corrected Firestore documents.

> **If Task 1 reported zero rows on partial-share properties, this task is complete with no work.** Tick every step, write "no rows found in Task 1, nothing to correct" in the plan, and move to Task 6.

- [ ] **Step 1: Re-read Task 1's recorded result**

Run: `grep -n "AUDIT RESULT" docs/superpowers/plans/2026-08-09-unit-panel-share-reconciliation.md`
Expected: the line Task 1 filled in. If it still says "not yet run", go back and run Task 1.

- [ ] **Step 2: Write the correction script (skip if zero rows)**

```python
"""Bring stored rent recoveries in line with the unscaled-recovery engine.

Recoveries entered before this change were typed at face value and halved on
read. The engine no longer halves them, so the stored figure must become the
landlord's share once. Only recoveries on properties with ownership_share < 1.0
are affected; run audit_rent_recovery_shares.py first.

    cd backend && uv run python scripts/fix_rent_recovery_shares.py           # dry run
    cd backend && uv run python scripts/fix_rent_recovery_shares.py --apply   # write
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from google.cloud import firestore  # noqa: E402  (import after load_dotenv)


def main() -> int:
    apply = '--apply' in sys.argv
    db = firestore.Client()

    shares = {}
    for snap in db.collection('documind_properties').stream():
        data = snap.to_dict() or {}
        share = data.get('ownership_share')
        shares[snap.id] = 1.0 if share is None else float(share)

    changed = 0
    for snap in db.collection('documind_rent_recoveries').stream():
        data = snap.to_dict() or {}
        share = shares.get(data.get('property_id'), 1.0)
        if share >= 1.0:
            continue
        old = float(data.get('amount') or 0)
        new = round(old * share, 2)
        print(f"{snap.id}: RM {old:,.2f} -> RM {new:,.2f}  (share {share:.0%})")
        changed += 1
        if apply:
            snap.reference.update({'amount': new})

    print(f"\n{changed} record(s) {'updated' if apply else 'would be updated'}.")
    if not apply and changed:
        print("Dry run. Re-run with --apply to write.")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
```

- [ ] **Step 3: Dry run**

Run: `cd backend && uv run python scripts/fix_rent_recovery_shares.py`
Expected: the same records Task 1 listed, each with its old and new amount. Confirm the count matches Task 1 exactly. If it does not, stop — something else wrote to that collection in between.

- [ ] **Step 4: Apply**

Run: `cd backend && uv run python scripts/fix_rent_recovery_shares.py --apply`
Expected: "N record(s) updated."

- [ ] **Step 5: Re-run the audit to confirm the figures**

Run: `cd backend && uv run python scripts/audit_rent_recovery_shares.py`
Expected: the same records, now showing the corrected amounts.

- [ ] **Step 6: Commit**

```bash
git add backend/scripts/fix_rent_recovery_shares.py
git commit -m "chore: one-off correction of rent recoveries on partial-share properties"
```

---

### Task 6: Flutter entities and JSON mapping

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/finance_summary.dart:134-175`
- Modify: `residex_app/lib/features/landlord/data/models/finance_summary_model.dart:103-127`
- Test: `residex_app/test/features/landlord/finance_summary_model_test.dart`

**Interfaces:**
- Consumes: the JSON keys `gross_income`, `full_gross_income`, `full_amount`, `full_billed_amount` from Tasks 2-3.
- Produces: `UnitFinance.grossIncome` (`double`, defaults `0.0`), `UnitFinance.fullGrossIncome` (`double?`), `MonthIncome.fullAmount` (`double?`), `MonthIncome.fullBilledAmount` (`double?`). Tasks 7-8 read these.

- [ ] **Step 1: Write the failing test**

Append to `residex_app/test/features/landlord/finance_summary_model_test.dart`, inside the existing top-level `main()`:

```dart
  group('share-scaled unit figures', () {
    Map<String, dynamic> summaryJson(Map<String, dynamic> unit) => {
          'year': 2026,
          'properties': [
            {
              'property_id': 'p1',
              'name': 'Block',
              'units': [unit],
            }
          ],
        };

    test('maps gross_income and full_gross_income when both are present', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 12800.0,
        'full_gross_income': 25600.0,
      }));
      final unit = summary.properties.first.units.first;
      expect(unit.grossIncome, 12800.0);
      expect(unit.fullGrossIncome, 25600.0);
    });

    test('full_gross_income absent leaves fullGrossIncome null', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 25600.0,
      }));
      final unit = summary.properties.first.units.first;
      expect(unit.grossIncome, 25600.0);
      expect(unit.fullGrossIncome, isNull);
    });

    test('maps a month row full_amount and full_billed_amount', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 1600.0,
        'full_gross_income': 3200.0,
        'months': [
          {
            'month': 1,
            'source': 'actual',
            'amount': 1600.0,
            'full_amount': 3200.0,
          },
          {
            'month': 3,
            'source': 'unpaid',
            'amount': 0.0,
            'payment_state': 'written_off',
            'billed_amount': 1600.0,
            'full_billed_amount': 3200.0,
          },
        ],
      }));
      final months = summary.properties.first.units.first.months;
      expect(months.first.amount, 1600.0);
      expect(months.first.fullAmount, 3200.0);
      expect(months.last.billedAmount, 1600.0);
      expect(months.last.fullBilledAmount, 3200.0);
    });

    test('a month row without the full_ keys leaves them null', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 3200.0,
        'months': [
          {'month': 1, 'source': 'actual', 'amount': 3200.0},
        ],
      }));
      final month = summary.properties.first.units.first.months.first;
      expect(month.fullAmount, isNull);
      expect(month.fullBilledAmount, isNull);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_summary_model_test.dart`
Expected: FAIL to compile — `The getter 'grossIncome' isn't defined for the class 'UnitFinance'`.

- [ ] **Step 3: Add the entity fields**

In `residex_app/lib/features/landlord/domain/entities/finance_summary.dart`, in `UnitFinance` add after `statutoryContribution`:

```dart
  /// The landlord's share of this unit's rent for the year — invoiced months
  /// plus months priced from the tenancy agreement. Emitted by the engine so
  /// the panel never re-derives it from the month rows, which are scaled by a
  /// different code path.
  final double grossIncome;

  /// The whole property's gross before ownership share was applied, present
  /// only when a share below 1.0 scaled [grossIncome]. Null means
  /// [grossIncome] is the full figure.
  final double? fullGrossIncome;
```

and in its constructor, after `this.statutoryContribution = 0.0,`:

```dart
    this.grossIncome = 0.0,
    this.fullGrossIncome,
```

In `MonthIncome` add after `billedAmount`:

```dart
  /// The invoiced figure before ownership share was applied, present only
  /// when a share below 1.0 scaled [amount].
  final double? fullAmount;

  /// The billed figure before ownership share was applied, present only when
  /// a share below 1.0 scaled [billedAmount].
  final double? fullBilledAmount;
```

and in its constructor, after `this.billedAmount,`:

```dart
    this.fullAmount,
    this.fullBilledAmount,
```

- [ ] **Step 4: Add the JSON mapping**

In `residex_app/lib/features/landlord/data/models/finance_summary_model.dart`, in `_unit` add after `statutoryContribution: _d(json['statutory_contribution']),`:

```dart
      grossIncome: _d(json['gross_income']),
      fullGrossIncome:
          json['full_gross_income'] == null ? null : _d(json['full_gross_income']),
```

and in the `MonthIncome(...)` constructor inside the same method, after `billedAmount: ...`:

```dart
                fullAmount: m['full_amount'] == null ? null : _d(m['full_amount']),
                fullBilledAmount: m['full_billed_amount'] == null
                    ? null
                    : _d(m['full_billed_amount']),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/finance_summary_model_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the full Flutter suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **303 passed, 1 failed** (`widget_test.dart` only), plus the 4 new tests.

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/finance_summary.dart residex_app/lib/features/landlord/data/models/finance_summary_model.dart residex_app/test/features/landlord/finance_summary_model_test.dart
git commit -m "feat(finance): carry share-scaled gross and face values through the model"
```

---

### Task 7: The panel renders the engine's gross

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart:144`, `:158-166`, `:175-206`, `:218-229`, `:271-285`
- Test: `residex_app/test/features/landlord/unit_finance_detail_test.dart`

**Interfaces:**
- Consumes: `UnitFinance.grossIncome`, `UnitFinance.fullGrossIncome`, `MonthIncome.fullAmount` from Task 6.
- Produces: no new public API.

> **A test that leaves `ownershipShare` at its `1.0` default cannot fail against this bug** — scaled and unscaled are the same number there. Every fixture below sets the unit's figures as the engine would emit them at 0.5.

- [ ] **Step 1: Write the failing tests**

Append to `residex_app/test/features/landlord/unit_finance_detail_test.dart`, matching the file's existing pump/fixture helpers:

```dart
  group('reconciliation at partial ownership share', () {
    UnitFinance halfShareUnit({String? unitId = 'u1'}) => UnitFinance(
          unitId: unitId,
          label: unitId == null ? 'Whole property' : 'B-08-11',
          rentedMonths: 8,
          contribution: 9800.0,
          statutoryContribution: 11800.0,
          grossIncome: 12800.0,
          fullGrossIncome: 25600.0,
          months: [
            MonthIncome(
                month: 1, source: 'actual', amount: 1600.0, fullAmount: 3200.0),
          ],
          expenseLines: [
            ExpenseLine(
              docId: 'd1',
              category: 'maintenance',
              subtype: 'maintenance',
              description: 'Strata management fee',
              amount: 1000.0,
              fullAmount: 2000.0,
            ),
            ExpenseLine(
              docId: 'd2',
              category: 'loan',
              subtype: 'interest_statement',
              description: 'Loan interest',
              amount: 1000.0,
            ),
            ExpenseLine(
              docId: 'd3',
              category: 'loan_principal',
              subtype: 'loan_principal',
              description: 'Loan principal',
              amount: 1000.0,
              deductible: false,
            ),
          ],
        );

    testWidgets('gross renders the landlord share, not the invoiced total',
        (tester) async {
      await _pumpScreen(tester, 2026, halfShareUnit());
      await tester.tap(find.text('Rental Profit/Loss').first);
      await tester.pumpAndSettle();

      expect(find.text('RM 12,800.00'), findsWidgets);
      expect(find.text('RM 25,600.00'), findsNothing);
    });

    testWidgets('the sub-label names the share and the invoiced figure',
        (tester) async {
      await _pumpScreen(tester, 2026, halfShareUnit());
      await tester.tap(find.text('Rental Profit/Loss').first);
      await tester.pumpAndSettle();

      expect(find.text('your 50% of RM 25,600.00'), findsOneWidget);
    });

    testWidgets('the statutory accordion scales its gross too', (tester) async {
      await _pumpScreen(tester, 2026, halfShareUnit());
      await tester.tap(find.text('Statutory income').first);
      await tester.pumpAndSettle();

      expect(find.text('your 50% of RM 25,600.00'), findsOneWidget);
    });

    testWidgets('the whole-property scope has the same treatment',
        (tester) async {
      // unitId == null goes through the identical code path and had the
      // identical defect, so it gets its own gate.
      await _pumpScreen(tester, 2026, halfShareUnit(unitId: null));
      await tester.tap(find.text('Rental Profit/Loss').first);
      await tester.pumpAndSettle();

      expect(find.text('RM 12,800.00'), findsWidgets);
      expect(find.text('your 50% of RM 25,600.00'), findsOneWidget);
    });

    testWidgets('full ownership shows no sub-label', (tester) async {
      await _pumpScreen(
        tester,
        2026,
        UnitFinance(
          unitId: 'u1',
          label: 'B-08-11',
          rentedMonths: 8,
          contribution: 22600.0,
          grossIncome: 25600.0,
          months: [
            MonthIncome(month: 1, source: 'actual', amount: 3200.0),
          ],
        ),
      );
      await tester.tap(find.text('Rental Profit/Loss').first);
      await tester.pumpAndSettle();

      expect(find.text('RM 25,600.00'), findsWidgets);
      expect(find.textContaining('your '), findsNothing);
    });

    testWidgets('the strip heading names the share', (tester) async {
      await _pumpScreen(tester, 2026, halfShareUnit());
      expect(find.text('Monthly income · your 50% share'), findsOneWidget);
    });

    testWidgets('the strip heading is bare at full ownership', (tester) async {
      await _pumpScreen(
        tester,
        2026,
        UnitFinance(
          unitId: 'u1',
          label: 'B-08-11',
          rentedMonths: 8,
          contribution: 22600.0,
          grossIncome: 25600.0,
          months: [
            MonthIncome(month: 1, source: 'actual', amount: 3200.0),
          ],
        ),
      );
      expect(find.text('Monthly income'), findsOneWidget);
    });
  });
```

`_pumpScreen(WidgetTester, int year, UnitFinance)` already exists in this file at `:34-53`. It wraps the unit in `_summaryWithUnit` and overrides `financeSummaryProvider`, so passing the fixture is all that is needed — do not add a new mounting helper.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`
Expected: FAIL — gross renders `RM 25,600.00` (summed from the scaled month row it no longer should sum), and neither the sub-label nor the qualified heading exists.

- [ ] **Step 3: Delete the local gross computation**

In `unit_finance_detail_screen.dart`, delete the whole `_grossIncome` method at `:158-166`:

```dart
  double _grossIncome(UnitFinance unit) {
    var total = 0.0;
    for (final month in unit.months) {
      if (month.source == 'actual' || month.source == 'derived') {
        total += month.amount;
      }
    }
    return total;
  }
```

- [ ] **Step 4: Pass the engine's figures into both accordions**

In `_buildNetContributionAccordion`, replace `gross: _grossIncome(unit),` with:

```dart
      gross: unit.grossIncome,
      fullGross: unit.fullGrossIncome,
```

In `_buildStatutoryAccordion`, make the identical replacement.

In `_breakdownAccordion`'s parameter list, add after `required double gross,`:

```dart
    required double? fullGross,
```

- [ ] **Step 5: Render the sub-label**

In `_breakdownAccordion`, replace the gross `Row` at `:271-285`:

```dart
                    Row(
                      children: [
                        Expanded(
                          child: Text('Gross income', style: AppTextStyles.labelLarge),
                        ),
                        Text(
                          formatRM(gross),
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
```

with:

```dart
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text('Gross income', style: AppTextStyles.labelLarge),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatRM(gross),
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            // Percentage derived from the figure pair, exactly
                            // as the expense rows below do it — the panel never
                            // reads an ownership-share field, so this stays
                            // correct if share ever moves to the unit.
                            if (fullGross != null && fullGross > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'your ${((gross / fullGross) * 100).toStringAsFixed(0)}% '
                                'of ${formatRM(fullGross)}',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
```

- [ ] **Step 6: Qualify the month strip heading**

In `build`, replace `:144`:

```dart
          Text('Monthly income', style: AppTextStyles.titleMedium),
```

with:

```dart
          Text(_monthStripHeading(_displayedUnit),
              style: AppTextStyles.titleMedium),
```

and add this method next to `_buildMonthStrip`:

```dart
  /// "Monthly income", plus the share qualifier when the engine scaled these
  /// rows. Cells render the scaled amount, so the heading is what tells the
  /// landlord which figure they are looking at. The percentage comes from the
  /// row's own figure pair, never from an ownership-share field.
  String _monthStripHeading(UnitFinance unit) {
    for (final month in unit.months) {
      final full = month.fullAmount;
      if (full != null && full > 0) {
        final pct = ((month.amount / full) * 100).toStringAsFixed(0);
        return 'Monthly income · your $pct% share';
      }
    }
    return 'Monthly income';
  }
```

The cells themselves need no change — `month.amount` now arrives scaled.

- [ ] **Step 7: Note the sparkline side effect — no code change**

`monthlyNetSeries` (`finance_logic.dart:175-200`) adds month amounts and then subtracts already-scaled expense lines, so on a co-owned property the hero sparkline had the same mismatch as the panel. Scaling the rows corrects it with no edit here, because the function reads `month.amount` and that value now arrives scaled.

Do **not** add a test asserting `monthlyNetSeries` returns the scaled figure — the function does no scaling of its own, so such a test asserts `1600 == 1600` and can never fail. Its existing tests all use share-1.0 fixtures and stay green. Record the improvement in the commit body instead.

Confirm no regression: `cd residex_app && flutter test test/features/landlord/monthly_net_series_test.dart`
Expected: PASS, unchanged.

- [ ] **Step 8: Run the full Flutter suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (`widget_test.dart` only). All new tests pass.

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

- [ ] **Step 9: Prove the gate has teeth**

Temporarily restore the old behaviour: change `gross: unit.grossIncome,` in `_buildNetContributionAccordion` to `gross: unit.months.fold<double>(0.0, (t, m) => t + m.amount),`.

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`
Expected: the reconciliation tests FAIL. **Revert** and re-run to confirm green.

- [ ] **Step 10: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart residex_app/test/features/landlord/unit_finance_detail_test.dart
git commit -m "fix(finance): reconcile the unit panel at partial ownership share"
```

---

### Task 8: The recovery sheet asks for the right figure

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/rent_payment_sheets.dart:1-5`, `:97-107`, `:185-191`, `:194-235`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart:566-572`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:936-943`
- Test: `residex_app/test/features/landlord/unit_finance_detail_screen_test.dart`

**Interfaces:**
- Consumes: `MonthIncome.fullBilledAmount` from Task 6; the unscaled-recovery engine from Task 4.
- Produces: `showManageUnpaidSheet` gains an optional named `double? fullBilledAmount`. Both existing call sites pass it.

> This is the only place on this screen where a figure is typed back in and stored. Because Task 4 stopped scaling recoveries, whatever the landlord enters here is booked verbatim — so the label has to say which figure is wanted.

- [ ] **Step 1: Write the failing tests**

Append to `residex_app/test/features/landlord/unit_finance_detail_screen_test.dart`:

```dart
  group('recovery sheet asks for the figure the engine will book', () {
    // This file mounts the screen inline rather than through a helper
    // (see the year-switching test at the top), so this group brings its own.
    Future<void> pumpWithUnit(WidgetTester tester, UnitFinance unit) async {
      final summary = FinanceSummary(
        year: 2026,
        totals: FinanceTotals(
          receivedRent: 0.0, derivedRent: 0.0, directExpenses: 0.0,
          netPl: 0.0, statutoryRentalIncome: 0.0, statutoryNote: '',
        ),
        properties: [
          PropertyFinance(
            propertyId: 'p1', name: 'Ayer 8',
            receivedRent: 0.0, derivedRent: 0.0, directExpenses: 0.0,
            rentalIncomeOrLoss: 0.0,
            units: [unit],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeYearsProvider.overrideWith((ref) async => [2026]),
            financeSummaryProvider.overrideWith((ref, y) async => summary),
          ],
          child: MaterialApp(
            home: UnitFinanceDetailScreen(
              propertyId: 'p1',
              propertyName: 'Ayer 8',
              unit: unit,
              year: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('partial share asks for the landlord share', (tester) async {
      await pumpWithUnit(
        tester,
        UnitFinance(
          unitId: 'u1',
          label: 'B-08-11',
          rentedMonths: 1,
          contribution: 0,
          grossIncome: 0,
          fullGrossIncome: 0,
          months: [
            MonthIncome(
              month: 9,
              source: 'unpaid',
              amount: 0,
              paymentState: 'written_off',
              billedAmount: 1600.0,
              fullBilledAmount: 3200.0,
            ),
          ],
        ),
      );

      await tester.tap(find.text('WRITTEN OFF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a recovery'));
      await tester.pumpAndSettle();

      expect(find.text('Your share of the amount received (RM)'), findsOneWidget);
      expect(
        find.text('Enter your 50% share, not the full RM 3,200.00 the tenant paid.'),
        findsOneWidget,
      );
      expect(find.text('1600.00'), findsOneWidget);
    });

    testWidgets('full ownership asks for the whole invoiced amount',
        (tester) async {
      await pumpWithUnit(
        tester,
        UnitFinance(
          unitId: 'u1',
          label: 'B-08-11',
          rentedMonths: 1,
          contribution: 0,
          grossIncome: 0,
          months: [
            MonthIncome(
              month: 9,
              source: 'unpaid',
              amount: 0,
              paymentState: 'written_off',
              billedAmount: 3200.0,
            ),
          ],
        ),
      );

      await tester.tap(find.text('WRITTEN OFF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a recovery'));
      await tester.pumpAndSettle();

      expect(find.text('Amount received from tenant (RM)'), findsOneWidget);
      expect(find.textContaining('Enter your'), findsNothing);
      expect(find.text('3200.00'), findsOneWidget);
    });
  });
```

The imports this needs — `FinanceSummary`, `FinanceTotals`, `PropertyFinance`, `UnitFinance`, `MonthIncome`, `financeYearsProvider`, `financeSummaryProvider`, `UnitFinanceDetailScreen`, `ProviderScope` — are all already at the top of this file (`:1-7`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_screen_test.dart`
Expected: FAIL — the field is labelled `Amount received (RM)` in both cases and there is no helper text.

- [ ] **Step 3: Import the currency formatter**

At the top of `rent_payment_sheets.dart`, add after line 4:

```dart
import '../../providers/finance_logic.dart';
```

- [ ] **Step 4: Thread the face value through the manage sheet**

In `showManageUnpaidSheet`'s parameter list, after `double? billedAmount,` add:

```dart
  double? fullBilledAmount,
```

and in its `action == 'recover'` branch, change the `_showRecoverSheet` call to pass it:

```dart
    await _showRecoverSheet(
      context, ref,
      propertyId: propertyId, unitId: unitId, originalMonth: month, monthLabel: monthLabel,
      defaultAmount: billedAmount,
      fullAmount: fullBilledAmount,
    );
```

- [ ] **Step 5: Make the recovery field adaptive**

In `_showRecoverSheet`'s parameter list, after `double? defaultAmount,` add:

```dart
  double? fullAmount,
```

and replace the amount `TextField` at `:231-235`:

```dart
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount received (RM)'),
            ),
```

with:

```dart
            // The engine books this figure verbatim — it does not apply
            // ownership share to recoveries. At a partial share the month tile
            // already shows the landlord's half, so the field asks for that
            // same half and names the invoiced figure it came from.
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: fullAmount != null && fullAmount > 0
                    ? 'Your share of the amount received (RM)'
                    : 'Amount received from tenant (RM)',
                helperText: fullAmount != null &&
                        fullAmount > 0 &&
                        defaultAmount != null
                    ? 'Enter your '
                        '${((defaultAmount / fullAmount) * 100).toStringAsFixed(0)}% share, '
                        'not the full ${formatRM(fullAmount)} the tenant paid.'
                    : null,
                helperMaxLines: 2,
              ),
            ),
```

- [ ] **Step 6: Update both call sites**

In `unit_finance_detail_screen.dart:566-572`, add to the `showManageUnpaidSheet` call:

```dart
        reason: month.reason, billedAmount: month.billedAmount,
        fullBilledAmount: month.fullBilledAmount,
```

In `finance_screen.dart:936-943`, make the identical addition:

```dart
              reason: month.reason, billedAmount: month.billedAmount,
              fullBilledAmount: month.fullBilledAmount,
```

- [ ] **Step 7: Run the full Flutter suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (`widget_test.dart` only).

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/rent_payment_sheets.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/unit_finance_detail_screen_test.dart
git commit -m "feat(finance): ask the recovery sheet for the figure the engine books"
```

---

## Final verification

- [ ] `cd backend && py -3.11 -m pytest tests/ -q` → **0 failed**
- [ ] `cd residex_app && flutter test` → **1 failed**, `widget_test.dart` only
- [ ] `cd residex_app && flutter analyze` → **0 errors**
- [ ] `git status --short` → no unintended files staged; the fact-aware-answering / citation-precision WIP is still uncommitted and untouched
- [ ] Manual check on a co-owned property (Damai, 50%): open a unit, expand **both** accordions, confirm `gross − expenses` equals the total shown, that the sub-label reads `your 50% of RM …`, and that the strip heading names the share. Then confirm a 100%-ownership property (Ayer 8) shows no sub-label and no heading qualifier.
