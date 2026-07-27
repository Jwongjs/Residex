# Two-Tier Expense Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the single `deductible` flag into two independent dimensions — `paid_by_landlord` (Overall Net P/L) and `statutory_deductible` (LHDN statutory income) — track loan principal, fix the fire-insurance double-count, surface both figures per property/unit, and let a reviewer delete an extracted expense line.

**Architecture:** The deterministic engine (`finance_engine.compute_finance_summary`) stays the single source of truth — the app never recomputes a figure the backend decided. Each expense line gains a second boolean; the engine sums each dimension independently. New fields flow through the FastAPI response models to the Flutter entities and into the dashboard + per-unit accordion. The review sheet edits/removes lines through the existing facts PATCH (no new endpoint).

**Tech Stack:** Python 3.11 / FastAPI / Pydantic v2 (backend, `pytest` + `unittest`), Flutter / Riverpod 3.x (frontend, `flutter_test`).

## Global Constraints

- TDD, no exceptions: write the failing test, watch it fail, minimal code, watch it pass, commit.
- Design spec: `docs/superpowers/specs/2026-07-27-two-tier-expense-model-design.md`. Classification table there is the single source of truth.
- LHDN basis: Public Ruling 12/2018, s.33(1) ITA. Statutory-deductible set is unchanged from today's `_line_deductible`.
- "The app never recomputes any figure" — headline figures (`contribution`, `net_pl`, `statutory_contribution`, totals) are backend-authoritative. Frontend line-item subtotals are display aids only and must reconcile to the backend figure.
- No emojis anywhere (icons/glyphs only) — user standing rule.
- Riverpod legacy imports: `package:flutter_riverpod/legacy.dart` where `StateProvider` is used (not needed for this plan unless a new StateProvider is added).
- Commit after every task. Do NOT push. Branch: `feat/finance-tab-restructure`.
- Backend test run dir: `backend/`. Frontend test run dir: `residex_app/`.

---

## File Structure

**Backend**
- `backend/rag/fact_extractor.py` — add `principal_paid` to the loan schema + hint (Task 1).
- `backend/rag/finance_engine.py` — `_line_paid_by_landlord`, both flags on every line, loan-principal line, annual-collapse dedup, two-tier totals (Tasks 2–5).
- `backend/models/documind_models.py` — expose new fields (Task 6).
- `backend/tests/test_fact_extractor.py`, `backend/tests/test_finance_engine.py` — tests.

**Frontend**
- `residex_app/lib/features/landlord/domain/entities/finance_summary.dart` — entity fields (Task 7).
- `residex_app/lib/features/landlord/data/models/finance_summary_model.dart` — `fromJson` (Task 7).
- `residex_app/lib/features/landlord/presentation/providers/finance_logic.dart` — `landlordPaidExpenseTotal` (Task 8).
- `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart` — accordion (Task 9).
- `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart` — dashboard label + per-property statutory (Task 10).
- `residex_app/lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart` — per-row delete (Task 11).
- Corresponding `residex_app/test/features/landlord/*_test.dart` — tests.

---

## Task 1: Extract loan `principal_paid`

**Files:**
- Modify: `backend/rag/fact_extractor.py:37-44` (loan `_FIELD_TYPES`) and `:91-98` (loan `_FIELD_HINTS`)
- Test: `backend/tests/test_fact_extractor.py`

**Interfaces:**
- Consumes: nothing new.
- Produces: a loan `interest_statement`'s extracted facts may now include `principal_paid: float` (the principal portion paid in the statement period), coerced as an amount, dropped when absent/invalid.

- [ ] **Step 1: Write the failing test**

Add to `backend/tests/test_fact_extractor.py` inside `FactExtractorTests`:

```python
    def test_loan_statement_extracts_principal_paid(self):
        llm = _FakeLLM(
            "subtype=interest statement;interest_paid=12408.31;"
            "principal_paid=8000.00;period_year=2026;confidence=0.85"
        )
        facts = FactExtractor(llm).extract("loan", "loan statement text")
        self.assertEqual(facts["interest_paid"], 12408.31)
        self.assertEqual(facts["principal_paid"], 8000.00)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_fact_extractor.py::FactExtractorTests::test_loan_statement_extracts_principal_paid -q`
Expected: FAIL — `KeyError: 'principal_paid'` (field not in schema, so dropped).

- [ ] **Step 3: Add the field to the loan schema and hint**

In `_FIELD_TYPES["loan"]` (currently lines 37-44) add the `principal_paid` entry:

```python
    "loan": {
        "subtype": "subtype",
        "interest_paid": "amount",
        "principal_paid": "amount",
        "period_year": "year",
        "principal": "amount",
        "interest_rate": "amount",
        "lender": "text",
    },
```

In `_FIELD_HINTS["loan"]` (currently lines 91-98) add the `principal_paid` line:

```python
    "loan": (
        "- subtype: agreement | interest_statement\n"
        "- interest_paid: total loan interest paid in the statement period\n"
        "- principal_paid: total loan PRINCIPAL repaid in the statement period "
        "(the capital portion of instalments, not the outstanding balance)\n"
        "- period_year: the year the statement covers\n"
        "- principal: original loan principal amount\n"
        "- interest_rate: annual interest rate (number only)\n"
        "- lender: bank or lender name"
    ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_fact_extractor.py -q`
Expected: PASS (all fact_extractor tests green).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/fact_extractor.py backend/tests/test_fact_extractor.py
git commit -m "feat: extract loan principal_paid from loan statements"
```

---

## Task 2: `_line_paid_by_landlord` + both flags on every expense line

**Files:**
- Modify: `backend/rag/finance_engine.py` (add helper after `_line_deductible` at :235; set both flags in `_expense_lines` bundled append :271-282 and typed append :321-334)
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `LANDLORD_BORNE_SUBTYPES` (already imported at :18).
- Produces: `_line_paid_by_landlord(subtype: Optional[str], utilities_paid_by: Optional[str]) -> bool`. Every dict in `_expense_lines(...)` output now carries both `"deductible": bool` (statutory) and `"paid_by_landlord": bool`.

- [ ] **Step 1: Write the failing test**

Add a new class to `backend/tests/test_finance_engine.py` (reuse the module's existing `_summary`, `_prop`, `_doc` helpers — see the top of that file):

```python
class PaidByLandlordFlagTests(unittest.TestCase):
    def _lines(self, docs, utilities_paid_by=None):
        from rag.finance_engine import _expense_lines
        return _expense_lines(docs, 2025, utilities_paid_by)

    def test_penalty_is_landlord_paid_but_not_deductible(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "late_penalty", "amount": 50.0, "period_year": 2025},
        ]})]
        line = self._lines(docs)[0]
        self.assertTrue(line["paid_by_landlord"])
        self.assertFalse(line["deductible"])

    def test_tenant_utility_is_neither(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "utilities", "amount": 80.0, "period_year": 2025},
        ]})]
        line = self._lines(docs, utilities_paid_by="tenant")[0]
        self.assertFalse(line["paid_by_landlord"])
        self.assertFalse(line["deductible"])

    def test_landlord_utility_is_both(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "utilities", "amount": 80.0, "period_year": 2025},
        ]})]
        line = self._lines(docs, utilities_paid_by="landlord")[0]
        self.assertTrue(line["paid_by_landlord"])
        self.assertTrue(line["deductible"])

    def test_maintenance_is_both(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "maintenance", "amount": 300.0, "date": "2025-03-01"},
        ]})]
        line = self._lines(docs)[0]
        self.assertTrue(line["paid_by_landlord"])
        self.assertTrue(line["deductible"])
```

(If `_doc`/`_prop` signatures differ, match the existing usages already in the file — e.g. `_doc("p1", "expenses", {...})`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_finance_engine.py::PaidByLandlordFlagTests -q`
Expected: FAIL — `KeyError: 'paid_by_landlord'`.

- [ ] **Step 3: Add the helper**

In `backend/rag/finance_engine.py`, immediately after `_line_deductible` (ends at :235) add:

```python
def _line_paid_by_landlord(
    subtype: Optional[str],
    utilities_paid_by: Optional[str],
) -> bool:
    """Whether the landlord actually bears this cost — feeds Overall Net P/L.

    Only utilities the tenant pays are excluded (not the landlord's outflow at
    all). Penalties, loan principal, capital works and first-letting costs are
    all real money the landlord paid, so they count toward Net P/L even though
    LHDN disallows them as statutory deductions."""
    if subtype in LANDLORD_BORNE_SUBTYPES:
        return utilities_paid_by == "landlord"
    return True
```

- [ ] **Step 4: Set both flags on every line**

In `_expense_lines`, the bundled-expenses append (currently :271-282) — add the `paid_by_landlord` key beside `deductible`:

```python
                lines.append({
                    "doc_id": doc["doc_id"],
                    "category": mapped,
                    "subtype": subtype,
                    "description": item.get("description") or _EXPENSE_LINE_LABELS[subtype],
                    "amount": _round2(amount),
                    "date": item.get("date") or str(item.get("period_year") or year),
                    "unit_id": doc.get("unit_id"),
                    "deductible": _line_deductible(
                        subtype, utilities_paid_by, letting_deductible
                    ),
                    "paid_by_landlord": _line_paid_by_landlord(subtype, utilities_paid_by),
                })
```

And the typed append (currently :321-334):

```python
        if entry is not None:
            amount, description, when = entry
            lines.append({
                "doc_id": doc["doc_id"],
                "category": category,
                "subtype": facts.get("subtype"),
                "description": description,
                "amount": _round2(amount),
                "date": when,
                "unit_id": doc.get("unit_id"),
                "deductible": _line_deductible(
                    facts.get("subtype"), utilities_paid_by, letting_deductible
                ),
                "paid_by_landlord": _line_paid_by_landlord(
                    facts.get("subtype"), utilities_paid_by
                ),
            })
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_finance_engine.py::PaidByLandlordFlagTests -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat: tag each expense line with paid_by_landlord (Net P/L dimension)"
```

---

## Task 3: Emit a loan-principal expense line

**Files:**
- Modify: `backend/rag/finance_engine.py` — the loan branch of `_expense_lines` (currently :285-289)
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `_line_paid_by_landlord`, `_line_deductible` (Task 2); loan facts `interest_paid`, `principal_paid`, `period_year` (Task 1).
- Produces: for a loan `interest_statement` matching the year, `_expense_lines` emits the interest line as today **plus** a second line `{"subtype": "loan_principal", "category": "loan", ...}` when `principal_paid` is present — `deductible=False`, `paid_by_landlord=True`.

- [ ] **Step 1: Write the failing test**

Add to `PaidByLandlordFlagTests` in `backend/tests/test_finance_engine.py`:

```python
    def test_loan_statement_emits_principal_line(self):
        docs = [_doc("p1", "loan", {
            "subtype": "interest_statement",
            "interest_paid": 5000.0,
            "principal_paid": 8000.0,
            "period_year": 2025,
        })]
        lines = self._lines(docs)
        by_subtype = {l["subtype"]: l for l in lines}
        self.assertIn("loan_principal", by_subtype)
        principal = by_subtype["loan_principal"]
        self.assertEqual(principal["amount"], 8000.0)
        self.assertTrue(principal["paid_by_landlord"])
        self.assertFalse(principal["deductible"])
        # interest line still present and fully deductible
        interest = by_subtype["interest_statement"]
        self.assertTrue(interest["deductible"])

    def test_loan_statement_without_principal_paid_emits_no_principal_line(self):
        docs = [_doc("p1", "loan", {
            "subtype": "interest_statement", "interest_paid": 5000.0, "period_year": 2025,
        })]
        subtypes = {l["subtype"] for l in self._lines(docs)}
        self.assertNotIn("loan_principal", subtypes)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_finance_engine.py::PaidByLandlordFlagTests::test_loan_statement_emits_principal_line -q`
Expected: FAIL — `loan_principal` not in the emitted lines.

- [ ] **Step 3: Emit the principal line**

Replace the loan branch (currently :285-289):

```python
        if category == "loan":
            amount = _amount(facts, "interest_paid")
            if facts.get("subtype") == "interest_statement" and amount is not None \
                    and facts.get("period_year") == year:
                entry = (amount, "Loan interest", str(year))
```

with:

```python
        if category == "loan":
            if facts.get("subtype") == "interest_statement" \
                    and facts.get("period_year") == year:
                interest = _amount(facts, "interest_paid")
                if interest is not None:
                    entry = (interest, "Loan interest", str(year))
                principal = _amount(facts, "principal_paid")
                if principal is not None:
                    # Principal is the landlord's cash out but never a statutory
                    # deduction (LHDN: only interest deducts). It rides Net P/L.
                    lines.append({
                        "doc_id": doc["doc_id"],
                        "category": "loan",
                        "subtype": "loan_principal",
                        "description": "Loan principal",
                        "amount": _round2(principal),
                        "date": str(year),
                        "unit_id": doc.get("unit_id"),
                        "deductible": _line_deductible(
                            "loan_principal", utilities_paid_by, letting_deductible
                        ),
                        "paid_by_landlord": _line_paid_by_landlord(
                            "loan_principal", utilities_paid_by
                        ),
                    })
```

(The interest line is still appended by the existing typed-append block at the end of the loop via `entry`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_finance_engine.py::PaidByLandlordFlagTests -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat: emit loan principal as a Net-P/L-only expense line"
```

---

## Task 4: Annual-collapse dedup (fire-insurance double count)

**Files:**
- Modify: `backend/rag/finance_engine.py` — `_dedup_expense_lines` (currently at :338)
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `_ym` (already at :68).
- Produces: `_dedup_expense_lines` now collapses annual-cadence subtypes (`insurance_premium`, `quit_rent`, `parcel_rent`) to one per `(unit_id, subtype, amount, year)` regardless of the specific date/month; all other subtypes keep the existing exact-line key.

- [ ] **Step 1: Write the failing test**

Add to `backend/tests/test_finance_engine.py` (the existing `ExpenseLineDedupTests` class, or a new one):

```python
class AnnualCollapseDedupTests(unittest.TestCase):
    def test_fire_insurance_on_two_monthly_statements_counts_once(self):
        from rag.finance_engine import _dedup_expense_lines
        lines = [
            {"unit_id": "u1", "category": "insurance", "subtype": "insurance_premium",
             "description": "Fire insurance", "date": "2025-01-31", "amount": 420.0,
             "deductible": True, "paid_by_landlord": True},
            {"unit_id": "u1", "category": "insurance", "subtype": "insurance_premium",
             "description": "Fire insurance", "date": "2025-02-28", "amount": 420.0,
             "deductible": True, "paid_by_landlord": True},
        ]
        self.assertEqual(len(_dedup_expense_lines(lines)), 1)

    def test_two_different_premiums_same_year_are_kept(self):
        from rag.finance_engine import _dedup_expense_lines
        lines = [
            {"unit_id": "u1", "category": "insurance", "subtype": "insurance_premium",
             "description": "Fire", "date": "2025-01-31", "amount": 420.0,
             "deductible": True, "paid_by_landlord": True},
            {"unit_id": "u1", "category": "insurance", "subtype": "insurance_premium",
             "description": "Contents", "date": "2025-01-31", "amount": 190.0,
             "deductible": True, "paid_by_landlord": True},
        ]
        self.assertEqual(len(_dedup_expense_lines(lines)), 2)

    def test_assessment_installments_still_kept_separate(self):
        from rag.finance_engine import _dedup_expense_lines
        lines = [
            {"unit_id": None, "category": "tax", "subtype": "assessment_tax",
             "description": "Assessment tax (1/2)", "date": "2025", "amount": 400.0,
             "deductible": True, "paid_by_landlord": True},
            {"unit_id": None, "category": "tax", "subtype": "assessment_tax",
             "description": "Assessment tax (2/2)", "date": "2025", "amount": 400.0,
             "deductible": True, "paid_by_landlord": True},
        ]
        self.assertEqual(len(_dedup_expense_lines(lines)), 2)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_finance_engine.py::AnnualCollapseDedupTests -q`
Expected: FAIL — `test_fire_insurance_on_two_monthly_statements_counts_once` gives 2, not 1 (different dates → not collapsed).

- [ ] **Step 3: Add the annual-collapse rule**

Add the constant near the top-level constants (e.g. after `_TAX_LABELS`), and rewrite `_dedup_expense_lines`:

```python
# Annual charges are billed once a year but often reprinted on every monthly
# strata statement. Collapse them per (unit, subtype, amount, year) so the one
# premium is not counted once per statement. Assessment tax is deliberately
# excluded — its instalments are legitimately several lines a year.
_ANNUAL_COLLAPSE_SUBTYPES = {"insurance_premium", "quit_rent", "parcel_rent"}
```

Replace the body of `_dedup_expense_lines` (keep its existing docstring, extend it):

```python
    seen = set()
    deduped: List[Dict[str, Any]] = []
    for line in lines:
        subtype = line.get("subtype")
        if subtype in _ANNUAL_COLLAPSE_SUBTYPES:
            ym = _ym(line.get("date"))
            year = ym[0] if ym is not None else line.get("date")
            key = ("__annual__", line.get("unit_id"), subtype, line.get("amount"), year)
        else:
            key = (line.get("unit_id"), line.get("category"), subtype,
                   line.get("description"), line.get("date"), line.get("amount"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(line)
    return deduped
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_finance_engine.py::AnnualCollapseDedupTests tests/test_finance_engine.py::ExpenseLineDedupTests -q`
Expected: PASS (new + existing dedup tests).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "fix: collapse annual charges once per year across monthly statements"
```

---

## Task 5: Two-tier totals in the engine

**Files:**
- Modify: `backend/rag/finance_engine.py` — per-unit loop (:859-891), property-level prorate (:915-919), per-property aggregation (:948-1019), portfolio totals (:1037-1047)
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: line dicts with both flags (Tasks 2-3).
- Produces, in the dict returned by `compute_finance_summary`:
  - `totals.net_pl` = Σ received − Σ (`paid_by_landlord` amounts).
  - Each `properties[i]` gains `net_pl: float` (received − landlord-paid) and `statutory_contribution: Optional[float]` (received − statutory-deductible, or `None` when the property's year is incomplete).
  - Each `properties[i].units[j]` gains `statutory_contribution: float`, and its `contribution` is now the Net P/L basis (received − landlord-paid).

- [ ] **Step 1: Write the failing test**

Add to `backend/tests/test_finance_engine.py`:

```python
class TwoTierTotalsTests(unittest.TestCase):
    def test_net_pl_includes_principal_and_penalty_statutory_excludes(self):
        # One fully-rented unit, RM 1000/mo actual = 12000 received.
        # Deductible: maintenance 3000. Non-deductible-but-paid: penalty 200,
        # loan principal 8000. Deductible interest 5000.
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": f"2025-{m:02d}"})
            for m in range(1, 13)
        ] + [
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 3000.0, "period_year": 2025},
                {"subtype": "late_penalty", "amount": 200.0, "period_year": 2025},
            ]}),
            _doc("p1", "loan", {"subtype": "interest_statement",
                                 "interest_paid": 5000.0, "principal_paid": 8000.0,
                                 "period_year": 2025}),
        ]
        result = _summary(docs, 2025)
        totals = result["totals"]
        # Statutory-deductible = maintenance 3000 + interest 5000 = 8000.
        # Landlord-paid = 3000 + 200 + 5000 + 8000 = 16200.
        self.assertEqual(totals["direct_expenses"], 8000.0)     # statutory set
        self.assertEqual(totals["net_pl"], 12000.0 - 16200.0)   # -4200 (all cash out)
        prop = result["properties"][0]
        self.assertEqual(prop["net_pl"], 12000.0 - 16200.0)
        self.assertEqual(prop["statutory_contribution"], 12000.0 - 8000.0)
```

(Adjust `_doc`/`_summary` calls to the file's existing helper signatures. If a property needs units for per-unit assertions, follow an existing multi-unit test in the file as the template.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_finance_engine.py::TwoTierTotalsTests -q`
Expected: FAIL — `net_pl` still equals received − deductible (penalty/principal missing), and `prop["net_pl"]` KeyError.

- [ ] **Step 3: Per-unit — compute both totals; contribution = Net P/L basis**

In the per-scope loop, replace the current `unit_expense_total` (:869-871) and the unit block append (:883-891):

```python
            unit_deductible_total = sum(
                l["amount"] for l in unit_lines if l["deductible"]
            )
            unit_landlord_total = sum(
                l["amount"] for l in unit_lines if l["paid_by_landlord"]
            )
            prorated_expenses += unit_deductible_total * fraction
```

(rename the later use of `unit_expense_total` in the whole-property suppression comment/logic accordingly — the suppression check at :881 uses `rented == 0`, not the total, so no change there).

Unit block append:

```python
            unit_blocks.append({
                "unit_id": scope["unit_id"],
                "label": scope["label"],
                "rented_months": rented,
                "contribution": _round2(actual_sum + derived_sum - unit_landlord_total),
                "statutory_contribution": _round2(
                    actual_sum + derived_sum - unit_deductible_total
                ),
                "months": month_rows,
                "missing_invoice_months": vacant,
                "expense_lines": unit_lines,
            })
```

- [ ] **Step 4: Property-level prorate — add a landlord-paid accumulator**

The property-level lines prorate block (:915-919) currently prorates deductible only. Add a full (non-prorated) landlord-paid sum used for Net P/L. Just after that block add:

```python
        # Net P/L uses the landlord's full cash out (not prorated by occupancy,
        # matching how direct/statutory `direct` is summed below).
        landlord_paid = sum(l["amount"] for l in expense_lines if l["paid_by_landlord"])
```

- [ ] **Step 5: Per-property aggregation — new fields and Net P/L accumulator**

Where `direct` is computed (:949) leave it (statutory). Add a portfolio Net P/L accumulator. Initialise `total_landlord_expenses = 0.0` beside `total_expenses` (find its init near the top of `compute_finance_summary`, alongside `total_received`), then near :1001 (`total_expenses += direct`) add:

```python
        total_landlord_expenses += landlord_paid
```

Extend the property block append (:1003-1019) with the two new fields:

```python
            "net_pl": _round2(received - landlord_paid),
            "statutory_contribution": (_round2(received - direct) if complete else None),
```

(insert these two keys into the existing dict literal, e.g. right after `"rental_income_or_loss": _round2(received - direct),`).

- [ ] **Step 6: Portfolio totals — net_pl uses landlord-paid**

Change the totals return (:1044):

```python
            "net_pl": _round2(total_received - total_landlord_expenses),
```

- [ ] **Step 7: Run the test + full engine suite; fix any drifted expectations**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -q`
Expected: `TwoTierTotalsTests` PASS. Some existing tests that asserted `net_pl` or per-unit `contribution` where a non-deductible line was present will now differ — for each, recompute the expected value on the Net P/L basis (received − landlord-paid) and update the assertion. Tests whose fixtures contain only deductible lines are unchanged (landlord-paid == deductible there). Do NOT change engine logic to satisfy an old expectation; update the expectation to the correct two-tier value.

- [ ] **Step 8: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat: two-tier totals — Net P/L (landlord-paid) vs statutory (LHDN)"
```

---

## Task 6: Expose new fields in the API models

**Files:**
- Modify: `backend/models/documind_models.py` — `ExpenseLine` (:178-190), `UnitFinance` (:193-201), `PropertyFinance` (:236-252)
- Test: `backend/tests/test_rex_routes_finance_api.py` (existing finance API test file)

**Interfaces:**
- Consumes: engine dict fields from Task 5.
- Produces: response JSON now includes `expense_lines[].paid_by_landlord`, `units[].statutory_contribution`, `properties[].net_pl`, `properties[].statutory_contribution`.

- [ ] **Step 1: Write the failing test**

Add to `backend/tests/test_rex_routes_finance_api.py` (patch `documind_service.compute_finance_summary` or the engine as the file already does; mirror an existing test's mocking). Minimal shape check:

```python
    def test_finance_summary_exposes_two_tier_fields(self):
        # ... arrange a mocked summary dict containing the new keys, following
        # the file's existing patching pattern for compute_finance_summary ...
        response = self.client.get("/api/rex/documind/finance/summary",
                                   params={"landlord_id": "l1", "year": 2025})
        self.assertEqual(response.status_code, 200)
        prop = response.json()["properties"][0]
        self.assertIn("net_pl", prop)
        self.assertIn("statutory_contribution", prop)
        self.assertIn("paid_by_landlord", prop["expense_lines"][0])
        self.assertIn("statutory_contribution", prop["units"][0])
```

(Match the existing test file's arrangement helpers — if it patches the engine to return a real computed dict, add the new keys to that fixture.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_rex_routes_finance_api.py::*::test_finance_summary_exposes_two_tier_fields -q`
Expected: FAIL — `response_model` filters the unknown keys out, so `net_pl` etc. are absent.

- [ ] **Step 3: Add the fields to the models**

`ExpenseLine` — add after `deductible` (:190):

```python
    deductible: bool = True
    paid_by_landlord: bool = True
```

`UnitFinance` — add after `contribution` (:198):

```python
    contribution: float  # income minus unit-scoped LANDLORD-PAID expenses (Net P/L)
    statutory_contribution: float  # income minus unit-scoped STATUTORY-deductible
```

`PropertyFinance` — add after `rental_income_or_loss` (:246):

```python
    rental_income_or_loss: float
    net_pl: float
    statutory_contribution: Optional[float] = None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_rex_routes_finance_api.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/models/documind_models.py backend/tests/test_rex_routes_finance_api.py
git commit -m "feat: expose paid_by_landlord + net_pl + statutory_contribution in API"
```

---

## Task 7: Flutter entities + `fromJson`

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/finance_summary.dart` — `ExpenseLine` (:163-183), `UnitFinance` (:124-143), `PropertyFinance` (:42-76)
- Modify: `residex_app/lib/features/landlord/data/models/finance_summary_model.dart` — `_lines` (:121-135), `_unit` (:97-119), `_property` (:38-95)
- Test: `residex_app/test/features/landlord/finance_summary_model_test.dart` (create if absent)

**Interfaces:**
- Consumes: JSON keys from Task 6.
- Produces: `ExpenseLine.paidByLandlord` (bool, default true), `UnitFinance.statutoryContribution` (double), `PropertyFinance.netPl` (double) + `PropertyFinance.statutoryContribution` (double?).

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/finance_summary_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/finance_summary_model.dart';

void main() {
  test('parses two-tier fields', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2025,
      'totals': {'received_rent': 12000, 'derived_rent': 0, 'direct_expenses': 8000,
        'net_pl': -4200, 'statutory_rental_income': 4000, 'statutory_note': 'x'},
      'properties': [
        {'property_id': 'p1', 'name': 'Ayer 8', 'received_rent': 12000, 'derived_rent': 0,
         'direct_expenses': 8000, 'rental_income_or_loss': 4000,
         'net_pl': -4200, 'statutory_contribution': 4000,
         'units': [
           {'unit_id': 'u1', 'label': 'A', 'rented_months': 12, 'contribution': -4200,
            'statutory_contribution': 4000, 'months': [], 'expense_lines': [
              {'doc_id': 'd', 'category': 'loan', 'subtype': 'loan_principal',
               'amount': 8000, 'deductible': false, 'paid_by_landlord': true},
            ]},
         ],
         'expense_lines': [], 'property_expense_lines': []},
      ],
    });
    final prop = summary.properties.single;
    expect(prop.netPl, -4200);
    expect(prop.statutoryContribution, 4000);
    final unit = prop.units.single;
    expect(unit.statutoryContribution, 4000);
    expect(unit.expenseLines.single.paidByLandlord, true);
    expect(unit.expenseLines.single.deductible, false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_summary_model_test.dart`
Expected: FAIL — `paidByLandlord`/`netPl`/`statutoryContribution` are not defined.

- [ ] **Step 3: Add entity fields**

`finance_summary.dart` — `ExpenseLine` add `paidByLandlord`:

```dart
  final bool deductible;
  final bool paidByLandlord;

  ExpenseLine({
    required this.docId,
    required this.category,
    this.subtype,
    this.description,
    required this.amount,
    this.date,
    this.unitId,
    this.deductible = true,
    this.paidByLandlord = true,
  });
```

`UnitFinance` add `statutoryContribution`:

```dart
  final double contribution;
  final double statutoryContribution;
  final List<MonthIncome> months;
  final List<int> missingInvoiceMonths;
  final List<ExpenseLine> expenseLines;

  UnitFinance({
    this.unitId,
    required this.label,
    required this.rentedMonths,
    required this.contribution,
    this.statutoryContribution = 0.0,
    this.months = const [],
    this.missingInvoiceMonths = const [],
    this.expenseLines = const [],
  });
```

`PropertyFinance` add `netPl` + `statutoryContribution`:

```dart
  final double rentalIncomeOrLoss;
  final double netPl;
  final double? statutoryContribution;
  // ... existing fields ...

  PropertyFinance({
    // ... existing required/optional ...
    required this.rentalIncomeOrLoss,
    this.netPl = 0.0,
    this.statutoryContribution,
    // ... rest unchanged ...
  });
```

- [ ] **Step 4: Add `fromJson` parsing**

`finance_summary_model.dart` — `_lines` (:124-133) add `paidByLandlord`:

```dart
              deductible: l['deductible'] as bool? ?? true,
              paidByLandlord: l['paid_by_landlord'] as bool? ?? true,
```

`_unit` (:97-118) add `statutoryContribution`:

```dart
      contribution: _d(json['contribution']),
      statutoryContribution: _d(json['statutory_contribution']),
```

`_property` (:38-94) add the two fields:

```dart
      rentalIncomeOrLoss: _d(json['rental_income_or_loss']),
      netPl: _d(json['net_pl']),
      statutoryContribution:
          json['statutory_contribution'] == null ? null : _d(json['statutory_contribution']),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/finance_summary_model_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/finance_summary.dart residex_app/lib/features/landlord/data/models/finance_summary_model.dart residex_app/test/features/landlord/finance_summary_model_test.dart
git commit -m "feat: parse two-tier finance fields into Flutter entities"
```

---

## Task 8: `landlordPaidExpenseTotal` in finance_logic

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/providers/finance_logic.dart` (add beside `deductibleExpenseTotal`)
- Test: `residex_app/test/features/landlord/finance_logic_test.dart`

**Interfaces:**
- Consumes: `ExpenseLine.paidByLandlord`.
- Produces: `double landlordPaidExpenseTotal(List<ExpenseLine> lines)` — sum of lines where `paidByLandlord`.

- [ ] **Step 1: Write the failing test**

Add to `finance_logic_test.dart` (the existing `makeLine` helper takes `deductible`; extend calls with a `paidByLandlord` param — add that param to `makeLine` mirroring `deductible`):

```dart
  group('landlordPaidExpenseTotal', () {
    test('sums lines the landlord pays, incl. non-deductible ones', () {
      final total = landlordPaidExpenseTotal([
        makeLine('maintenance', amount: 300.0),                       // both
        makeLine('late_penalty', amount: 200.0, deductible: false),   // paid, not deductible
        makeLine('utilities', amount: 80.0, deductible: false, paidByLandlord: false), // neither
      ]);
      expect(total, 500.0);
    });
  });
```

First extend `makeLine`:

```dart
  ExpenseLine makeLine(String subtype, {String category = 'expenses', String? date, double amount = 100.0, String? description, bool deductible = true, bool paidByLandlord = true}) {
    return ExpenseLine(
      docId: 'd', category: category, subtype: subtype,
      description: description, amount: amount, date: date,
      deductible: deductible, paidByLandlord: paidByLandlord,
    );
  }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_logic_test.dart`
Expected: FAIL — `landlordPaidExpenseTotal` not defined.

- [ ] **Step 3: Add the function**

In `finance_logic.dart`, beside `deductibleExpenseTotal`:

```dart
/// The Overall Net P/L direct-expenses figure: the sum of lines the landlord
/// actually pays (deductible or not). Mirrors the backend Net P/L fold; the
/// per-unit `contribution` equals gross minus this.
double landlordPaidExpenseTotal(List<ExpenseLine> lines) {
  return lines
      .where((l) => l.paidByLandlord)
      .fold<double>(0, (sum, l) => sum + l.amount);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/finance_logic_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/providers/finance_logic.dart residex_app/test/features/landlord/finance_logic_test.dart
git commit -m "feat: landlordPaidExpenseTotal for the Net P/L accordion figure"
```

---

## Task 9: Accordion — Net P/L basis + statutory contribution block

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart` — `build`/accordion body (:168-260 region) and helpers
- Test: `residex_app/test/features/landlord/unit_finance_detail_test.dart`

**Interfaces:**
- Consumes: `unit.contribution` (Net P/L, backend), `unit.statutoryContribution` (backend), `landlordPaidExpenseTotal`, `deductibleExpenseTotal`, `groupDirectExpenses`, `expenseExclusionNote`.
- Produces: accordion whose headline "Direct expenses" total = `landlordPaidExpenseTotal(unit.expenseLines)`, and a new "Contributing statutory income" block showing `unit.statutoryContribution` with the deductible-line subset.

- [ ] **Step 1: Update the existing widget test + add the statutory-block test**

In `unit_finance_detail_test.dart`, the existing test `'a tenant-paid utility line is marked excluded and kept out of the direct-expenses total'` still holds (tenant utility is not landlord-paid → total stays 300). Add a new test:

```dart
  testWidgets('accordion shows Net P/L direct expenses and a statutory contribution block',
      (tester) async {
    final year = DateTime.now().year;
    final unit = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 12,
      contribution: 12000.0 - 3200.0,          // Net P/L: maintenance 3000 + penalty 200
      statutoryContribution: 12000.0 - 3000.0, // statutory: maintenance only
      months: [MonthIncome(month: 1, source: 'actual', amount: 12000.0)],
      expenseLines: [
        ExpenseLine(docId: 'd1', category: 'maintenance', subtype: 'maintenance',
            description: 'Service charge', amount: 3000.0, date: '2025-01-01'),
        ExpenseLine(docId: 'd2', category: 'loan', subtype: 'late_penalty',
            description: 'Late charge', amount: 200.0, date: '2025-01-01',
            deductible: false, paidByLandlord: true),
      ],
    );
    await _pumpScreen(tester, year, unit);
    await tester.tap(find.text('Net contribution'));
    await tester.pumpAndSettle();

    // Net P/L direct expenses = 3200 (both landlord-paid lines).
    expect(find.text('−RM 3,200.00'), findsOneWidget);
    // Statutory contribution block present with its figure.
    expect(find.textContaining('Contributing statutory income'), findsOneWidget);
    expect(find.text('RM 9,000.00'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`
Expected: FAIL — total shows 3000 (old `deductibleExpenseTotal`), no statutory block.

- [ ] **Step 3: Switch the total and add the statutory block**

In `unit_finance_detail_screen.dart` `build`, change the total (currently `final expenseTotal = deductibleExpenseTotal(unit.expenseLines);`) to:

```dart
    final gross = _grossIncome(unit);
    // Net P/L basis (user decision): all landlord-paid outflows reduce the
    // headline. gross − expenseTotal == unit.contribution.
    final expenseTotal = landlordPaidExpenseTotal(unit.expenseLines);
    final statutoryTotal = deductibleExpenseTotal(unit.expenseLines);
    final hasExpenses = unit.expenseLines.isNotEmpty;
```

The Net P/L "Direct expenses" row and grouped lines stay as-is but now render the landlord-paid set. After the grouped lines (after `..._buildGroupedExpenseLines(context, unit.expenseLines),` at :241), insert a statutory block:

```dart
                      ..._buildGroupedExpenseLines(context, unit.expenseLines),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.hairline),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Contributing statutory income',
                                style: AppTextStyles.labelLarge),
                          ),
                          Text(
                            formatRM(unit.statutoryContribution),
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LHDN-deductible expenses only (−${formatRM(statutoryTotal)})',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                      ),
                      ..._buildGroupedExpenseLines(
                        context,
                        unit.expenseLines.where((l) => l.deductible).toList(),
                      ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/unit_finance_detail_test.dart`
Expected: PASS (both the updated existing test and the new one).

- [ ] **Step 5: Analyze + commit**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart`
Expected: No issues.

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart residex_app/test/features/landlord/unit_finance_detail_test.dart
git commit -m "feat: accordion on Net P/L basis with a statutory-contribution block"
```

---

## Task 10: Dashboard — "Current" statutory label + per-property statutory

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart` — the totals header (Net P/L + Statutory) and the per-property block (`_miniStat` row at :352-357)
- Test: `residex_app/test/features/landlord/finance_screen_test.dart` (create if absent, following the harness in `unit_finance_detail_test.dart` for provider overrides)

**Interfaces:**
- Consumes: `summary.totals.netPl`, `summary.totals.statutoryRentalIncome`, `summary.properties[].complete`, `summary.properties[].statutoryContribution`.
- Produces: the statutory headline reads "Current Statutory Rental Income" when any property is incomplete, else "Statutory Rental Income"; each property block shows a "STATUTORY" mini-stat when `statutoryContribution != null`.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/finance_screen_test.dart`. Pump `FinanceScreen` with a `financeSummaryProvider` override whose summary has one incomplete property, and assert the "Current" label appears; then a complete property and assert the settled label. (Mirror `_pumpScreen`/overrides from `unit_finance_detail_test.dart`; if `FinanceScreen` needs more providers, override them with the same fakes that test uses.)

```dart
    // incomplete property → provisional label
    expect(find.textContaining('Current Statutory Rental Income'), findsOneWidget);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`
Expected: FAIL — the label is static / not present.

- [ ] **Step 3: Derive the label and render per-property statutory**

At the top of the totals-header builder (where `summary.totals` is in scope), add:

```dart
    final provisional = summary.properties.any((p) => !p.complete);
    final statutoryLabel =
        provisional ? 'Current Statutory Rental Income' : 'Statutory Rental Income';
```

Use `statutoryLabel` for the statutory headline's label text, and `summary.totals.statutoryRentalIncome` for its value. In the per-property block, extend the `_miniStat` row (:352-357):

```dart
          Row(
            children: [
              Expanded(child: _miniStat('RECEIVED', block.receivedRent)),
              Expanded(child: _miniStat('EXPENSES', block.directExpenses)),
              if (block.statutoryContribution != null)
                Expanded(child: _miniStat('STATUTORY', block.statutoryContribution!)),
            ],
          ),
```

(If the dashboard does not yet render a Net P/L / Statutory headline pair at all, add one using the existing stat-widget style — a `_miniStat`/`_bigStat` — showing `summary.totals.netPl` labelled "OVERALL NET P/L" and `summary.totals.statutoryRentalIncome` labelled with `statutoryLabel`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart`
Expected: No issues.

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat: current-vs-settled statutory label + per-property statutory stat"
```

---

## Task 11: Review panel — delete an extracted line

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart` — add a per-row delete affordance in `_ExpenseLinesReviewSheetState`
- Test: `residex_app/test/features/landlord/expense_lines_review_sheet_test.dart`

**Interfaces:**
- Consumes: existing `_lines` list + `updateExpenseLinesActionProvider` (unchanged — save replaces the full list).
- Produces: a delete icon per row that removes the line (with a confirm) and marks the sheet dirty; saving persists the shorter list.

- [ ] **Step 1: Write the failing test**

Add to `expense_lines_review_sheet_test.dart`:

```dart
  testWidgets('deleting a line removes it from the list and enables save', (tester) async {
    await _pumpSheet(tester, [
      {'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025},
      {'subtype': 'late_penalty', 'amount': 50.0, 'period_year': 2025},
    ]);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    // Confirm dialog
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNWidgets(1)); // one line left
    expect(find.text('Save changes'), findsOneWidget);           // dirty
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/expense_lines_review_sheet_test.dart`
Expected: FAIL — no `Icons.delete_outline` in the sheet.

- [ ] **Step 3: Add the delete affordance**

Add a `_deleteLine` method to `_ExpenseLinesReviewSheetState`:

```dart
  Future<void> _deleteLine(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this expense?'),
        content: const Text(
            'It will no longer count toward your figures. This is for '
            'duplicates or charges that were waived.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _lines.removeAt(index);
        _dirty = true;
      });
    }
  }
```

In the `ListTile.trailing` `Row` (currently the amount + `Icon(Icons.edit_outlined)`), add a delete `IconButton` after the edit icon:

```dart
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(amount is num ? formatRM(amount.toDouble()) : '—',
                          style: AppTextStyles.bodyLarge),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Remove expense',
                        onPressed: _saving ? null : () => _deleteLine(index),
                      ),
                    ],
                  ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/expense_lines_review_sheet_test.dart`
Expected: PASS (delete + the earlier late_penalty/dropdown tests).

- [ ] **Step 5: Analyze + commit**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart`
Expected: No issues.

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart residex_app/test/features/landlord/expense_lines_review_sheet_test.dart
git commit -m "feat: remove an extracted expense line from the review sheet"
```

---

## Final verification (after all tasks)

- [ ] Backend: `cd backend && python -m pytest -q` → all pass.
- [ ] Frontend: `cd residex_app && flutter test test/features/landlord/` → all pass.
- [ ] `cd residex_app && flutter analyze` → no new errors (pre-existing `withOpacity`/`avoid_print` infos are acceptable).
- [ ] Manual smoke: upload a monthly strata statement carrying fire insurance in two months → insurance counted once; a loan statement with principal → Net P/L drops by principal, statutory unchanged; a penalty → in Net P/L, out of statutory; review sheet → delete a line, save, figure updates.

## Notes on spec coverage
- Fire-insurance double count → Task 4.
- Late penalty in Net P/L not statutory → Tasks 2 + 5.
- Confirmation-panel remove → Task 11 (dropdown widening already shipped).
- Net P/L = all landlord-paid → Tasks 2, 3, 5.
- Statutory = LHDN set, "Current" vs settled, per-property contribution → Tasks 5, 6, 7, 10.
- Loan interest (deductible) + principal (Net P/L only), frequent uploads → Tasks 1, 3, 5.
- Per-unit accordion → Net P/L + statutory block → Task 9.
