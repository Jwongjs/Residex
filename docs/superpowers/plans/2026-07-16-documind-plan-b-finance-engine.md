# Plan B — Finance Engine, Summary API & Chat Finance Branch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [`docs/superpowers/specs/2026-07-15-documind-financial-intelligence-design.md`](../specs/2026-07-15-documind-financial-intelligence-design.md) (Plan B of three). **Requires Plan A** (`2026-07-16-documind-plan-a-taxonomy-ocr-extraction.md`) to be complete: the 7-category taxonomy, `normalize_category`, and `extracted_facts` on `documind_docs` must exist.

**Goal:** A deterministic pure-Python finance engine that folds extracted facts into per-unit/per-property/portfolio P/L and Malaysian statutory rental income, exposed via `GET /api/rex/documind/finance/summary`, and narratable through DocuMind chat via a new `finance_question` router intent — the LLM never does arithmetic.

**Architecture:** `backend/rag/finance_engine.py` is pure (no LLM, no I/O): top-level functions over already-fetched inputs. `DocuMindService.get_finance_summary` supplies the I/O (one `documind_docs` query, one `properties` query, unit lookups) and normalizes legacy categories before the fold. The chat path adds a third intent to `ConversationRouter` (which also echoes a 4-digit year), a `prepare_finance` branch to the LangGraph graph, and a narration prompt in the service — 2 LLM calls total on that branch, zero retrieval.

**Tech Stack:** Pure Python (`datetime`, stdlib only) engine; FastAPI + pydantic models; existing LangGraph orchestration; Firestore reads via existing patterns.

## Global Constraints

- Backend tests run with `py -3.11 -m pytest tests/ -q` from `backend/`. Baseline after Plan A: record it before starting; every task ends green.
- Money values are rounded to 2 decimals at engine output (`_round2`); the golden test asserts **exactly** `60106.58`.
- The statutory figure is never shown bare: `statutory_note` always contains `Estimate — for your tax agent`; a floored loss appends `Rental loss cannot be set off against other income and cannot be carried forward`.
- v1 equates billed with received — the first caveat always says so.
- Engine skips documents with `None`/malformed facts silently (they surface via `missing_categories`/caveats, never as errors).
- Categories reaching the engine are already alias-normalized (`utility → upkeep`, `receipt → rental_invoice`, `warranty → upkeep`) — the service normalizes at fetch.
- The backend has no hot reload — restart it manually for any manual verification.
- Commit after every task with the exact message given in the task's final step.

---

### Task 1: The finance engine (pure module + golden test)

**Files:**
- Create: `backend/rag/finance_engine.py`
- Create: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Produces: `compute_finance_summary(*, year: int, today: date, documents: list[dict], properties: list[dict], units_by_property: dict[str, list[dict]]) -> dict` returning the exact `FinanceSummaryResponse` shape (Task 2 wraps it in pydantic). Input contracts: `documents` items carry `doc_id, property_id, unit_id, unit_label, category (normalized), extracted_facts (dict|None), uploaded_at (datetime|None)`; `properties` items carry `property_id, name, ownership_share (float)`; `units_by_property` maps `property_id -> [{unit_id, label}]`. Also exports `FINANCE_CATEGORIES`, `STATUTORY_NOTE`, `LOSS_FLOOR_NOTE`, `MONTH_NAMES`.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_finance_engine.py`:

```python
import unittest
from datetime import date, datetime

from rag.finance_engine import (
    LOSS_FLOOR_NOTE,
    STATUTORY_NOTE,
    compute_finance_summary,
)

_UPLOAD_SEQ = [0]


def _doc(pid, category, facts, unit_id=None, uploaded=None, doc_id=None):
    _UPLOAD_SEQ[0] += 1
    return {
        "doc_id": doc_id or f"doc-{_UPLOAD_SEQ[0]}",
        "property_id": pid,
        "unit_id": unit_id,
        "unit_label": None,
        "category": category,
        "extracted_facts": facts,
        "uploaded_at": uploaded or datetime(2026, 1, 1, 0, 0, _UPLOAD_SEQ[0] % 60, _UPLOAD_SEQ[0]),
    }


def _prop(pid, name, share=1.0):
    return {"property_id": pid, "name": name, "ownership_share": share}


def _summary(documents, properties, units=None, year=2025, today=date(2026, 7, 16)):
    return compute_finance_summary(
        year=year,
        today=today,
        documents=documents,
        properties=properties,
        units_by_property=units or {},
    )


class IncomeFoldTests(unittest.TestCase):
    def test_invoice_beats_lease_backfill_for_its_month(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "rental_invoice", {"amount": 1200.0, "period_month": "2025-03"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        months = result["properties"][0]["units"][0]["months"]
        march = next(m for m in months if m["month"] == 3)
        self.assertEqual(march, {"month": 3, "source": "actual", "amount": 1200.0})
        january = next(m for m in months if m["month"] == 1)
        self.assertEqual(january["source"], "derived")
        self.assertEqual(january["amount"], 1000.0)
        # 11 derived x 1000 + 1 actual x 1200
        self.assertEqual(result["properties"][0]["received_rent"], 12200.0)
        self.assertEqual(result["properties"][0]["derived_rent"], 11000.0)

    def test_duplicate_invoice_most_recent_upload_wins(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 900.0, "period_month": "2025-05"},
                 uploaded=datetime(2025, 6, 1)),
            _doc("p1", "rental_invoice", {"amount": 950.0, "period_month": "2025-05"},
                 uploaded=datetime(2025, 6, 20)),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        may = next(m for m in result["properties"][0]["units"][0]["months"] if m["month"] == 5)
        self.assertEqual(may["amount"], 950.0)

    def test_year_boundaries_excluded(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 800.0, "period_month": "2024-12"}),
            _doc("p1", "lease", {"monthly_rent": 700.0, "lease_start": "2023-01-01", "lease_end": "2024-12-31"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertEqual(result["properties"][0]["received_rent"], 0.0)
        self.assertTrue(all(m["source"] == "vacant" for m in result["properties"][0]["units"][0]["months"]))

    def test_future_months_excluded(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
        ]
        result = _summary(docs, [_prop("p1", "House")], year=2025, today=date(2025, 6, 15))
        months = result["properties"][0]["units"][0]["months"]
        self.assertEqual(len(months), 6)
        self.assertEqual(result["properties"][0]["received_rent"], 6000.0)

    def test_unit_scoped_and_property_wide_income_coexist(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 500.0, "period_month": "2025-01"}, unit_id="u1"),
            _doc("p1", "rental_invoice", {"amount": 300.0, "period_month": "2025-01"}),
        ]
        result = _summary(docs, [_prop("p1", "Block A")], units={"p1": [{"unit_id": "u1", "label": "Unit A"}]})
        labels = [u["label"] for u in result["properties"][0]["units"]]
        self.assertEqual(labels, ["Unit A", "Whole property"])
        self.assertEqual(result["properties"][0]["received_rent"], 800.0)

    def test_malformed_facts_skipped_silently(self):
        docs = [
            _doc("p1", "rental_invoice", None),
            _doc("p1", "rental_invoice", {"amount": "lots", "period_month": "2025-01"}),
            _doc("p1", "rental_invoice", {"amount": 100.0, "period_month": "not-a-month"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertEqual(result["properties"][0]["received_rent"], 0.0)


class ExpenseFoldTests(unittest.TestCase):
    def test_expense_year_allocation_rules(self):
        docs = [
            _doc("p1", "loan", {"subtype": "interest_statement", "interest_paid": 5000.0, "period_year": 2025}),
            _doc("p1", "loan", {"subtype": "interest_statement", "interest_paid": 9999.0, "period_year": 2024}),
            _doc("p1", "loan", {"subtype": "agreement", "principal": 400000.0, "interest_rate": 4.2}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 750.0, "period_year": 2025, "installment": "1/2"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 750.0, "period_year": 2025, "installment": "2/2"}),
            _doc("p1", "upkeep", {"amount": 180.0, "service_date": "2025-03-12"}),
            _doc("p1", "upkeep", {"amount": 999.0, "service_date": "2024-03-12"}),
            _doc("p1", "maintenance", {"amount": 3600.0, "period_start": "2025-01-01", "period_end": "2025-12-31"}),
            _doc("p1", "maintenance", {"amount": 1200.0, "period_end": "2025-06-30"}),
            _doc("p1", "insurance", {"premium": 640.0, "policy_start": "2025-02-01", "policy_end": "2026-02-01"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        block = result["properties"][0]
        # 5000 + 750 + 750 + 180 + 3600 + 1200 + 640
        self.assertEqual(block["direct_expenses"], 12120.0)
        self.assertEqual(result["expense_breakdown"]["loan"], 5000.0)
        self.assertEqual(result["expense_breakdown"]["tax"], 1500.0)
        categories = [line["category"] for line in block["expense_lines"]]
        self.assertNotIn("agreement", categories)

    def test_renewal_fee_deductible_only_on_renewal_subtype(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31", "subtype": "renewal", "renewal_fee": 250.0}),
            _doc("p2", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31", "subtype": "new", "renewal_fee": 250.0}),
        ]
        result = _summary(docs, [_prop("p1", "Renewed"), _prop("p2", "Fresh")])
        renewed, fresh = result["properties"]
        self.assertEqual(renewed["direct_expenses"], 250.0)
        self.assertEqual(fresh["direct_expenses"], 0.0)


class StatutoryTests(unittest.TestCase):
    def test_vacant_unit_expense_hits_net_but_not_statutory(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}, unit_id="u1"),
            _doc("p1", "upkeep", {"amount": 600.0, "service_date": "2025-02-01"}, unit_id="u2"),
        ]
        units = {"p1": [{"unit_id": "u1", "label": "Unit A"}, {"unit_id": "u2", "label": "Unit B"}]}
        result = _summary(docs, [_prop("p1", "Block")], units=units, year=2025, today=date(2026, 1, 1))
        # Net includes the vacant unit's expense (cash reality)
        self.assertEqual(result["totals"]["net_pl"], 400.0)
        # Statutory prorates Unit B's expense by its rented fraction (0/12)
        # and Unit A's income stands: 1000 - 600*0 = 1000
        self.assertEqual(result["totals"]["statutory_rental_income"], 1000.0)

    def test_ownership_share_scales_statutory_not_net(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "tax", {"subtype": "quit_rent", "amount": 120.0, "period_year": 2025}),
        ]
        result = _summary(docs, [_prop("p1", "Shared", share=0.5)], year=2025, today=date(2026, 1, 1))
        self.assertEqual(result["totals"]["net_pl"], 880.0)
        # statutory: 0.5 * (1000 - 120 * (1/12 rented fraction))
        self.assertEqual(result["totals"]["statutory_rental_income"], 495.0)
        self.assertTrue(any("Ownership share applied" in c for c in result["caveats"]))

    def test_loss_offsets_across_properties_then_floors_at_zero(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p2", "rental_invoice", {"amount": 200.0, "period_month": "2025-01"}),
            _doc("p2", "loan", {"subtype": "interest_statement", "interest_paid": 5000.0, "period_year": 2025}),
        ]
        result = _summary(docs, [_prop("p1", "Winner"), _prop("p2", "Loser")], year=2025, today=date(2026, 1, 1))
        # p1 statutory 1000; p2: 200 - 5000*(1/12) = -216.67 -> offsets
        self.assertEqual(result["totals"]["statutory_rental_income"], 783.33)
        self.assertNotIn(LOSS_FLOOR_NOTE, result["totals"]["statutory_note"])

        heavy_loss = docs + [
            _doc("p2", "loan", {"subtype": "interest_statement", "interest_paid": 200000.0, "period_year": 2025},
                 doc_id="big-loss"),
        ]
        floored = _summary(heavy_loss, [_prop("p1", "Winner"), _prop("p2", "Loser")], year=2025, today=date(2026, 1, 1))
        self.assertEqual(floored["totals"]["statutory_rental_income"], 0.0)
        self.assertIn(LOSS_FLOOR_NOTE, floored["totals"]["statutory_note"])
        self.assertIn(STATUTORY_NOTE, floored["totals"]["statutory_note"])


class CompletenessTests(unittest.TestCase):
    def test_missing_categories_and_vacant_month_caveats(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
        ]
        result = _summary(docs, [_prop("p1", "House")], year=2025, today=date(2026, 1, 1))
        self.assertEqual(
            result["missing_categories"]["p1"],
            ["loan", "tax", "upkeep", "maintenance", "insurance"],
        )
        self.assertTrue(any("billed equals rent received" in c for c in result["caveats"]))
        self.assertTrue(any("No invoice recorded for Feb" in c for c in result["caveats"]))

    def test_empty_year_yields_empty_not_zero_truth(self):
        result = _summary([], [_prop("p1", "House")], year=2025, today=date(2026, 1, 1))
        self.assertEqual(result["totals"]["received_rent"], 0.0)
        self.assertEqual(result["missing_categories"]["p1"],
                         ["rental_invoice", "loan", "tax", "upkeep", "maintenance", "insurance"])


class GoldenReferenceSheetTest(unittest.TestCase):
    """The landlord's real 2025 spreadsheet ('rental income for apps.xlsx').

    Three properties, fully rented, ownership share 1.0 -> the statutory
    figure must reproduce the sheet's total exactly."""

    def _documents(self):
        docs = []
        # Ayer 8: 12 x 7,000 = 84,000; expenses 59,516.87
        for m in range(1, 13):
            docs.append(_doc("p1", "rental_invoice", {"amount": 7000.0, "period_month": f"2025-{m:02d}"}))
        docs += [
            _doc("p1", "loan", {"subtype": "interest_statement", "interest_paid": 32000.0, "period_year": 2025}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 1500.0, "period_year": 2025}),
            _doc("p1", "tax", {"subtype": "quit_rent", "amount": 316.87, "period_year": 2025}),
            _doc("p1", "maintenance", {"amount": 25700.0, "period_start": "2025-01-01", "period_end": "2025-12-31"}),
        ]
        # Shaftbury: 10 x 6,000 + 2 x 10,000 = 80,000; expenses 70,950.52
        for m in range(1, 11):
            docs.append(_doc("p2", "rental_invoice", {"amount": 6000.0, "period_month": f"2025-{m:02d}"}))
        for m in (11, 12):
            docs.append(_doc("p2", "rental_invoice", {"amount": 10000.0, "period_month": f"2025-{m:02d}"}))
        docs += [
            _doc("p2", "loan", {"subtype": "interest_statement", "interest_paid": 45000.0, "period_year": 2025}),
            _doc("p2", "maintenance", {"amount": 19090.0, "period_start": "2025-01-01", "period_end": "2025-12-31"}),
            _doc("p2", "tax", {"subtype": "assessment", "amount": 2860.52, "period_year": 2025}),
            _doc("p2", "upkeep", {"amount": 4000.0, "service_date": "2025-06-15"}),
        ]
        # USJ: 10 x 4,000 + 2 x 7,500 = 55,000; expenses 28,426.03
        for m in range(1, 11):
            docs.append(_doc("p3", "rental_invoice", {"amount": 4000.0, "period_month": f"2025-{m:02d}"}))
        for m in (11, 12):
            docs.append(_doc("p3", "rental_invoice", {"amount": 7500.0, "period_month": f"2025-{m:02d}"}))
        docs += [
            _doc("p3", "loan", {"subtype": "interest_statement", "interest_paid": 20000.0, "period_year": 2025}),
            _doc("p3", "insurance", {"premium": 1426.03, "policy_start": "2025-01-01", "policy_end": "2026-01-01"}),
            _doc("p3", "maintenance", {"amount": 7000.0, "period_start": "2025-01-01", "period_end": "2025-12-31"}),
        ]
        return docs

    def test_reference_sheet_reproduces_exactly(self):
        result = _summary(
            self._documents(),
            [_prop("p1", "Ayer 8"), _prop("p2", "Shaftbury"), _prop("p3", "USJ")],
        )
        by_name = {p["name"]: p for p in result["properties"]}
        self.assertEqual(by_name["Ayer 8"]["received_rent"], 84000.0)
        self.assertEqual(by_name["Ayer 8"]["direct_expenses"], 59516.87)
        self.assertEqual(by_name["Ayer 8"]["rental_income_or_loss"], 24483.13)
        self.assertEqual(by_name["Shaftbury"]["received_rent"], 80000.0)
        self.assertEqual(by_name["Shaftbury"]["direct_expenses"], 70950.52)
        self.assertEqual(by_name["Shaftbury"]["rental_income_or_loss"], 9049.48)
        self.assertEqual(by_name["USJ"]["received_rent"], 55000.0)
        self.assertEqual(by_name["USJ"]["direct_expenses"], 28426.03)
        self.assertEqual(by_name["USJ"]["rental_income_or_loss"], 26573.97)
        # Fully rented + share 1.0 -> statutory == net == the sheet's total
        self.assertEqual(result["totals"]["statutory_rental_income"], 60106.58)
        self.assertEqual(result["totals"]["net_pl"], 60106.58)
        self.assertIn(STATUTORY_NOTE, result["totals"]["statutory_note"])
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `backend/`: `py -3.11 -m pytest tests/test_finance_engine.py -q`
Expected: ImportError — `rag.finance_engine` does not exist.

- [ ] **Step 3: Implement the engine**

Create `backend/rag/finance_engine.py`:

```python
"""Deterministic finance engine: pure functions, no LLM, no I/O.

Folds extracted facts into per-unit monthly income, per-property
Received Rent / Direct Expenses / Rental Income/Loss, portfolio Net P/L,
and Malaysian statutory rental income (s.4(d), YA = calendar year).
Malformed or missing facts are skipped silently — they surface through
missing_categories/caveats, never as errors.
"""
from __future__ import annotations

from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

# Categories that feed the fold; also the per-property completeness report.
FINANCE_CATEGORIES = ["rental_invoice", "loan", "tax", "upkeep", "maintenance", "insurance"]

STATUTORY_NOTE = "Estimate — for your tax agent"
LOSS_FLOOR_NOTE = (
    "Rental loss cannot be set off against other income and cannot be carried forward"
)
MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

_TAX_LABELS = {
    "assessment": "Assessment tax",
    "quit_rent": "Quit rent",
    "parcel_rent": "Parcel rent",
}


def _round2(value: float) -> float:
    return round(float(value), 2)


def _ym(value: Any) -> Optional[Tuple[int, int]]:
    """'YYYY-MM' or 'YYYY-MM-DD' -> (year, month); None when unparseable."""
    if not isinstance(value, str) or len(value) < 7:
        return None
    try:
        return (int(value[0:4]), int(value[5:7]))
    except ValueError:
        return None


def _amount(facts: Dict[str, Any], key: str) -> Optional[float]:
    value = facts.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _uploaded_key(doc: Dict[str, Any]):
    # Tuple so None (pre-feature docs) sorts oldest without comparing
    # naive/aware datetimes against each other.
    value = doc.get("uploaded_at")
    return (value is not None, value or datetime.min)


def _months_in_scope(year: int, today: date) -> List[int]:
    """Jan..Dec of the target year, future months excluded."""
    if year > today.year:
        return []
    if year == today.year:
        return list(range(1, today.month + 1))
    return list(range(1, 13))


def _scope_income(
    prop_docs: List[Dict[str, Any]],
    unit_id: Optional[str],
    year: int,
    months: List[int],
):
    """Income rows for one scope (unit_id None = property-wide documents).

    Precedence per month: invoice (actual) > lease coverage (derived) > vacant.
    Returns (month_rows, rented_count, actual_sum, derived_sum,
    vacant_months, derived_months)."""
    invoice_by_month: Dict[int, float] = {}
    for doc in sorted(
        (d for d in prop_docs
         if d.get("category") == "rental_invoice" and d.get("unit_id") == unit_id),
        key=_uploaded_key,
    ):
        facts = doc["extracted_facts"]
        amount = _amount(facts, "amount")
        ym = _ym(facts.get("period_month"))
        if amount is None or ym is None or ym[0] != year:
            continue
        invoice_by_month[ym[1]] = amount  # ascending sort: later upload wins

    lease_facts: Optional[Dict[str, Any]] = None
    for doc in sorted(
        (d for d in prop_docs
         if d.get("category") == "lease" and d.get("unit_id") == unit_id),
        key=_uploaded_key,
    ):
        facts = doc["extracted_facts"]
        if (
            _amount(facts, "monthly_rent") is not None
            and _ym(facts.get("lease_start"))
            and _ym(facts.get("lease_end"))
        ):
            lease_facts = facts  # most recent valid lease wins

    month_rows: List[Dict[str, Any]] = []
    rented = 0
    actual_sum = 0.0
    derived_sum = 0.0
    vacant_months: List[int] = []
    derived_months: List[int] = []
    for month in months:
        if month in invoice_by_month:
            amount = invoice_by_month[month]
            month_rows.append({"month": month, "source": "actual", "amount": _round2(amount)})
            actual_sum += amount
            rented += 1
            continue
        if lease_facts is not None and (
            _ym(lease_facts["lease_start"]) <= (year, month) <= _ym(lease_facts["lease_end"])
        ):
            amount = _amount(lease_facts, "monthly_rent")
            month_rows.append({"month": month, "source": "derived", "amount": _round2(amount)})
            derived_sum += amount
            rented += 1
            derived_months.append(month)
            continue
        month_rows.append({"month": month, "source": "vacant", "amount": 0.0})
        vacant_months.append(month)
    return month_rows, rented, actual_sum, derived_sum, vacant_months, derived_months


def _expense_lines(prop_docs: List[Dict[str, Any]], year: int) -> List[Dict[str, Any]]:
    """Deductible expense lines allocated to the target year.

    Allocation rules (spec schema table): loan interest by the statement's
    period_year (agreements are informational only); tax by period_year
    (installments stay separate lines and sum naturally); upkeep by
    service_date's year; maintenance by period_start's year (fallback
    period_end); insurance premium by policy_start's year (fallback
    policy_end); lease renewal_fee only when subtype=renewal, by
    lease_start's year."""
    lines: List[Dict[str, Any]] = []
    for doc in prop_docs:
        facts = doc["extracted_facts"]
        category = doc.get("category")
        entry = None  # (amount, description, date_str)
        if category == "loan":
            amount = _amount(facts, "interest_paid")
            if facts.get("subtype") == "interest_statement" and amount is not None \
                    and facts.get("period_year") == year:
                entry = (amount, "Loan interest", str(year))
        elif category == "tax":
            amount = _amount(facts, "amount")
            if amount is not None and facts.get("period_year") == year:
                label = _TAX_LABELS.get(facts.get("subtype"), "Property tax")
                if facts.get("installment"):
                    label = f"{label} ({facts['installment']})"
                entry = (amount, label, str(year))
        elif category == "upkeep":
            amount = _amount(facts, "amount")
            ym = _ym(facts.get("service_date"))
            if amount is not None and ym and ym[0] == year:
                entry = (amount, facts.get("description") or "Upkeep", facts.get("service_date"))
        elif category == "maintenance":
            amount = _amount(facts, "amount")
            ym = _ym(facts.get("period_start")) or _ym(facts.get("period_end"))
            if amount is not None and ym and ym[0] == year:
                entry = (
                    amount,
                    facts.get("description") or "Maintenance fees & sinking fund",
                    facts.get("period_start") or facts.get("period_end"),
                )
        elif category == "insurance":
            premium = _amount(facts, "premium")
            ym = _ym(facts.get("policy_start")) or _ym(facts.get("policy_end"))
            if premium is not None and ym and ym[0] == year:
                entry = (premium, "Insurance premium", facts.get("policy_start") or facts.get("policy_end"))
        elif category == "lease":
            fee = _amount(facts, "renewal_fee")
            ym = _ym(facts.get("lease_start"))
            if facts.get("subtype") == "renewal" and fee is not None and ym and ym[0] == year:
                entry = (fee, "Tenancy renewal fee", facts.get("lease_start"))
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
            })
    return lines


def compute_finance_summary(
    *,
    year: int,
    today: date,
    documents: List[Dict[str, Any]],
    properties: List[Dict[str, Any]],
    units_by_property: Dict[str, List[Dict[str, Any]]],
) -> Dict[str, Any]:
    months = _months_in_scope(year, today)

    property_blocks: List[Dict[str, Any]] = []
    caveats: List[str] = [
        "Income assumes rent billed equals rent received — invoices are the "
        "ledger, payment is not confirmed.",
    ]
    missing_categories: Dict[str, List[str]] = {}
    expense_breakdown: Dict[str, float] = {}
    total_received = 0.0
    total_derived = 0.0
    total_expenses = 0.0
    statutory_sum = 0.0
    derived_notes: List[str] = []
    vacant_notes: List[str] = []
    share_notes: List[str] = []

    for prop in properties:
        pid = prop["property_id"]
        name = prop.get("name") or pid
        share = float(prop.get("ownership_share") or 1.0)
        prop_docs = [
            d for d in documents
            if d.get("property_id") == pid and isinstance(d.get("extracted_facts"), dict)
        ]

        # Income scopes: each real unit, plus a synthetic whole-property scope
        # when property-wide income documents exist (or the property has no
        # units at all) — single-let houses work without units.
        scopes = [
            {"unit_id": u["unit_id"], "label": u.get("label") or u["unit_id"]}
            for u in units_by_property.get(pid, [])
        ]
        has_property_wide_income = any(
            d.get("unit_id") is None and d.get("category") in ("rental_invoice", "lease")
            for d in prop_docs
        )
        if has_property_wide_income or not scopes:
            scopes.append({"unit_id": None, "label": "Whole property"})

        expense_lines = _expense_lines(prop_docs, year)
        lines_by_unit: Dict[Optional[str], List[Dict[str, Any]]] = {}
        for line in expense_lines:
            lines_by_unit.setdefault(line.get("unit_id"), []).append(line)

        unit_blocks: List[Dict[str, Any]] = []
        prop_actual = 0.0
        prop_derived = 0.0
        fractions: List[float] = []
        prorated_expenses = 0.0

        for scope in scopes:
            month_rows, rented, actual_sum, derived_sum, vacant, derived = _scope_income(
                prop_docs, scope["unit_id"], year, months
            )
            fraction = (rented / len(months)) if months else 0.0
            fractions.append(fraction)
            unit_lines = (
                lines_by_unit.get(scope["unit_id"], [])
                if scope["unit_id"] is not None else []
            )
            unit_expense_total = sum(l["amount"] for l in unit_lines)
            prorated_expenses += unit_expense_total * fraction
            unit_blocks.append({
                "unit_id": scope["unit_id"],
                "label": scope["label"],
                "rented_months": rented,
                "contribution": _round2(actual_sum + derived_sum - unit_expense_total),
                "months": month_rows,
                "missing_invoice_months": vacant,
                "expense_lines": unit_lines,
            })
            prop_actual += actual_sum
            prop_derived += derived_sum
            if derived:
                derived_notes.append(
                    f"{name} — {scope['label']}: "
                    + ", ".join(MONTH_NAMES[m - 1] for m in derived)
                )
            for m in vacant:
                vacant_notes.append(
                    f"No invoice recorded for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                )

        # Property-level expenses (no unit) prorate by the property's average
        # rented fraction; a fully-rented year = factor 1.0 so the reference
        # scenario reproduces exactly.
        property_level_lines = lines_by_unit.get(None, [])
        avg_fraction = (sum(fractions) / len(fractions)) if fractions else 0.0
        prorated_expenses += sum(l["amount"] for l in property_level_lines) * avg_fraction

        received = prop_actual + prop_derived
        direct = sum(l["amount"] for l in expense_lines)
        statutory_sum += share * (received - prorated_expenses)

        contributing = {l["category"] for l in expense_lines}
        if any(row["source"] == "actual" for u in unit_blocks for row in u["months"]):
            contributing.add("rental_invoice")
        missing = [c for c in FINANCE_CATEGORIES if c not in contributing]
        if missing:
            missing_categories[pid] = missing
            for category in missing:
                caveats.append(
                    f"No {category.replace('_', ' ')} document for {year} — {name}; "
                    "figures may be incomplete."
                )

        if share < 1.0:
            share_notes.append(f"Ownership share applied: {name} at {share:.0%}.")

        for line in expense_lines:
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0) + line["amount"]
            )

        total_received += received
        total_derived += prop_derived
        total_expenses += direct

        property_blocks.append({
            "property_id": pid,
            "name": name,
            "ownership_share": share,
            "received_rent": _round2(received),
            "derived_rent": _round2(prop_derived),
            "direct_expenses": _round2(direct),
            "rental_income_or_loss": _round2(received - direct),
            "units": unit_blocks,
            "expense_lines": expense_lines,
            "property_expense_lines": property_level_lines,
        })

    statutory = _round2(statutory_sum)
    statutory_note = STATUTORY_NOTE
    if statutory < 0:
        statutory = 0.0
        statutory_note = f"{STATUTORY_NOTE}. {LOSS_FLOOR_NOTE}."

    if derived_notes:
        caveats.append(
            "Months backfilled from lease terms (no invoice): " + "; ".join(derived_notes)
        )
    caveats.extend(vacant_notes)
    caveats.extend(share_notes)

    return {
        "year": year,
        "totals": {
            "received_rent": _round2(total_received),
            "derived_rent": _round2(total_derived),
            "direct_expenses": _round2(total_expenses),
            "net_pl": _round2(total_received - total_expenses),
            "statutory_rental_income": statutory,
            "statutory_note": statutory_note,
        },
        "expense_breakdown": expense_breakdown,
        "properties": property_blocks,
        "caveats": caveats,
        "missing_categories": missing_categories,
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `py -3.11 -m pytest tests/test_finance_engine.py -q`
Expected: 13 PASS, including the golden test's exact `60106.58`. If a rounding assertion fails by 0.01, the bug is a missing `_round2` at an aggregation point — fix the engine, not the test.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat: deterministic finance engine with statutory rental income and golden reference test"
```

---

### Task 2: Finance models, service I/O, summary endpoint

**Files:**
- Modify: `backend/models/documind_models.py` (append finance models)
- Modify: `backend/rag/documind_service.py` (imports, `_list_landlord_properties`, `get_finance_summary`)
- Modify: `backend/api/rex_routes.py` (new GET route + model import)
- Modify: `backend/tests/test_documind_service_flows.py` (`_FakeDB` properties support + test)
- Create: `backend/tests/test_rex_routes_finance_api.py`

**Interfaces:**
- Consumes: Task 1's `compute_finance_summary`; Plan A's `normalize_category`; Flutter-owned `properties` collection (field `landlordId`, `name`, optional `ownership_share` — Plan C adds the edit UI, backend defaults 1.0).
- Produces: pydantic models `MonthIncome`, `ExpenseLine`, `UnitFinance`, `PropertyFinance`, `FinanceTotals`, `FinanceSummaryResponse`; `DocuMindService.get_finance_summary(landlord_id: str, year: int) -> FinanceSummaryResponse`; route `GET /api/rex/documind/finance/summary?landlord_id=&year=`. Task 4 and Plan C consume all three.

- [ ] **Step 1: Write the failing tests**

In `backend/tests/test_documind_service_flows.py`:

**(a)** extend `_FakeDB.__init__` with a properties fixture list (after `self.chunks = chunks or []`):

```python
        self.properties_rows = []
```

**(b)** in `_FakeCollectionQuery.stream()`, add a branch before the `else`:

```python
        elif self._name == "properties":
            rows = self._db.properties_rows
```

**(c)** append the test class (needs `AsyncMock` added to the existing `unittest.mock` import line):

```python
class FinanceSummaryServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_get_finance_summary_folds_firestore_docs(self):
        fake_db = _FakeDB(docs=[
            {
                "doc_id": "inv-1", "landlord_id": "l1", "property_id": "p1",
                "category": "rental_invoice", "filename": "inv.pdf",
                "uploaded_at": datetime(2025, 3, 2),
                "extracted_facts": {"amount": 2000.0, "period_month": "2025-03"},
            },
            {
                # Legacy category: must fold as an upkeep expense (alias)
                "doc_id": "upk-1", "landlord_id": "l1", "property_id": "p1",
                "category": "utility", "filename": "aircon.pdf",
                "uploaded_at": datetime(2025, 4, 12),
                "extracted_facts": {"amount": 300.0, "service_date": "2025-04-10"},
            },
            {
                # Pre-feature doc without facts: silently skipped
                "doc_id": "old-1", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "old.pdf",
                "uploaded_at": datetime(2024, 1, 1),
            },
        ])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Kiara Court", "ownership_share": 0.5},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        self.assertEqual(summary.year, 2025)
        block = summary.properties[0]
        self.assertEqual(block.name, "Kiara Court")
        self.assertEqual(block.ownership_share, 0.5)
        self.assertEqual(block.received_rent, 2000.0)
        self.assertEqual(block.direct_expenses, 300.0)
        self.assertEqual(block.rental_income_or_loss, 1700.0)
        self.assertEqual(block.expense_lines[0].category, "upkeep")
        # statutory: 0.5 * (2000 - 300 * (1 rented month / 12)) = 987.50
        self.assertEqual(summary.totals.statutory_rental_income, 987.5)

    async def test_get_finance_summary_no_properties_is_empty(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        summary = await service.get_finance_summary("l1", 2025)
        self.assertEqual(summary.properties, [])
        self.assertEqual(summary.totals.net_pl, 0.0)
```

Create `backend/tests/test_rex_routes_finance_api.py`:

```python
import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from models.documind_models import FinanceSummaryResponse, FinanceTotals


def _fake_summary():
    return FinanceSummaryResponse(
        year=2025,
        totals=FinanceTotals(
            received_rent=219000.0,
            derived_rent=0.0,
            direct_expenses=158893.42,
            net_pl=60106.58,
            statutory_rental_income=60106.58,
            statutory_note="Estimate — for your tax agent",
        ),
        expense_breakdown={"loan": 97000.0},
        properties=[],
        caveats=["Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed."],
        missing_categories={},
    )


class FinanceSummaryApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_finance_summary_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.get_finance_summary",
            new=AsyncMock(return_value=_fake_summary()),
        ) as mocked:
            response = self.client.get(
                "/api/rex/documind/finance/summary",
                params={"landlord_id": "landlord-1", "year": 2025},
            )
            call_args = mocked.await_args.args

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["totals"]["statutory_rental_income"], 60106.58)
        self.assertEqual(body["totals"]["statutory_note"], "Estimate — for your tax agent")
        self.assertEqual(call_args, ("landlord-1", 2025))

    def test_finance_summary_requires_year(self):
        response = self.client.get(
            "/api/rex/documind/finance/summary",
            params={"landlord_id": "landlord-1"},
        )
        self.assertEqual(response.status_code, 422)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py tests/test_rex_routes_finance_api.py -q`
Expected: ImportError (`FinanceSummaryResponse` missing) / AttributeError (`get_finance_summary` missing).

- [ ] **Step 3: Implement models**

Append to `backend/models/documind_models.py` (extend the existing `from typing import Optional, List` import with `Dict`):

```python
# ========== FINANCE SUMMARY MODELS ==========

class MonthIncome(BaseModel):
    """One month of one unit's income."""
    month: int  # 1-12
    source: str  # actual | derived | vacant
    amount: float


class ExpenseLine(BaseModel):
    """One deductible expense, traceable to its source document."""
    doc_id: str
    category: str
    subtype: Optional[str] = None
    description: Optional[str] = None
    amount: float
    date: Optional[str] = None
    unit_id: Optional[str] = None  # None = property-level expense


class UnitFinance(BaseModel):
    """One unit's year: monthly income strip + its own expenses."""
    unit_id: Optional[str] = None  # None = synthetic whole-property line
    label: str
    rented_months: int
    contribution: float  # income minus unit-scoped expenses
    months: List[MonthIncome]
    missing_invoice_months: List[int] = Field(default_factory=list)
    expense_lines: List[ExpenseLine] = Field(default_factory=list)


class PropertyFinance(BaseModel):
    """Per-property annual block (mirrors the reference sheet)."""
    property_id: str
    name: str
    ownership_share: float = 1.0
    received_rent: float
    derived_rent: float
    direct_expenses: float
    rental_income_or_loss: float
    units: List[UnitFinance]
    expense_lines: List[ExpenseLine]  # all lines, itemized
    property_expense_lines: List[ExpenseLine]  # the property-level subset


class FinanceTotals(BaseModel):
    received_rent: float
    derived_rent: float
    direct_expenses: float
    net_pl: float
    statutory_rental_income: float
    statutory_note: str


class FinanceSummaryResponse(BaseModel):
    """GET /api/rex/documind/finance/summary"""
    year: int
    totals: FinanceTotals
    expense_breakdown: Dict[str, float]
    properties: List[PropertyFinance]
    caveats: List[str]
    missing_categories: Dict[str, List[str]]
```

- [ ] **Step 4: Implement the service I/O**

In `backend/rag/documind_service.py`:

**(a)** extend the datetime import to `from datetime import datetime, timedelta, date` and add `from rag.finance_engine import compute_finance_summary`.

**(b)** add beside `_list_property_units`:

```python
    def _list_landlord_properties(self, landlord_id: str) -> List[Dict]:
        """Property ids/names/ownership shares for a landlord. The properties
        collection is Flutter-owned (field 'landlordId'); ownership_share is
        optional and defaults to 1.0. Empty on lookup failure."""
        try:
            snapshots = (
                self.db.collection('properties')
                .where(filter=FieldFilter('landlordId', '==', landlord_id))
                .stream()
            )
            results = []
            for snap in snapshots:
                data = snap.to_dict() or {}
                try:
                    share = float(data.get('ownership_share') or 1.0)
                except (TypeError, ValueError):
                    share = 1.0
                results.append({
                    "property_id": snap.id,
                    "name": data.get('name') or snap.id,
                    "ownership_share": share,
                })
            return results
        except Exception as e:
            print(f"⚠️ Property lookup failed for landlord {landlord_id}: {e}")
            return []
```

**(c)** add the public method (place it after `list_documents`):

```python
    async def get_finance_summary(self, landlord_id: str, year: int) -> FinanceSummaryResponse:
        """One Firestore fold, zero LLM: fetch the landlord's documents,
        properties, and units, then run the pure engine. Categories are
        alias-normalized before the fold."""
        documents = []
        query = self.db.collection('documind_docs').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        for snap in query.stream():
            data = snap.to_dict() or {}
            documents.append({
                "doc_id": data.get("doc_id") or snap.id,
                "property_id": data.get("property_id"),
                "unit_id": data.get("unit_id"),
                "unit_label": data.get("unit_label"),
                "category": normalize_category(data.get("category")),
                "extracted_facts": data.get("extracted_facts"),
                "uploaded_at": data.get("uploaded_at"),
            })

        properties = self._list_landlord_properties(landlord_id)
        units_by_property = {
            prop["property_id"]: self._list_property_units(prop["property_id"])
            for prop in properties
        }

        summary = compute_finance_summary(
            year=year,
            today=date.today(),
            documents=documents,
            properties=properties,
            units_by_property=units_by_property,
        )
        return FinanceSummaryResponse(**summary)
```

(Note: `doc_id` prefers the stored field because the `_FakeDB` snapshot id comes from it; real Firestore docs carry the id as `snap.id` — both paths land on the same value.)

**(d)** In `backend/api/rex_routes.py`: add `FinanceSummaryResponse` to the models import, then append after the `list_documents` route:

```python
@router.get("/documind/finance/summary", response_model=FinanceSummaryResponse)
async def finance_summary(
    landlord_id: str = Query(..., description="Landlord ID"),
    year: int = Query(..., ge=2000, le=2100, description="Calendar year (YA)"),
):
    """
    Deterministic finance summary for one landlord and calendar year.

    Zero LLM: extracted facts are folded fresh on every request (compute-on-
    read). Statutory Rental Income is an estimate for the landlord's tax
    agent and always ships with its caveats.
    """
    return await documind_service.get_finance_summary(landlord_id, year)
```

- [ ] **Step 5: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: all PASS (Task 1 baseline + 4 new).

- [ ] **Step 6: Commit**

```bash
git add backend/models/documind_models.py backend/rag/documind_service.py backend/api/rex_routes.py backend/tests/
git commit -m "feat: finance summary endpoint backed by the deterministic engine"
```

---

### Task 3: `finance_question` router intent + graph finance branch

**Files:**
- Modify: `backend/rag/conversation_router.py`
- Modify: `backend/rag/graph_orchestrator.py`
- Create: `backend/tests/test_finance_chat.py`

**Interfaces:**
- Consumes: nothing new (LLM injected as before).
- Produces: `ConversationRouter.route(...)` result dict gains `"year": Optional[int]` and may return `intent="finance_question"` (with `rag_needed=False`); `DocuMindState` gains `finance_year`; graph emits `action="finance"` with `finance_year` set, never touching the category predictor on that branch. Task 4 consumes both.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_finance_chat.py`:

```python
import unittest

from rag.conversation_router import ConversationRouter
from rag.graph_orchestrator import DocuMindGraphOrchestrator


class _LLMResponse:
    def __init__(self, content):
        self.content = content


class _FakeLLM:
    def __init__(self, content):
        self._content = content

    def invoke(self, prompt):
        return _LLMResponse(self._content)


class _RaisingLLM:
    def invoke(self, prompt):
        raise RuntimeError("boom")


class ConversationRouterFinanceTests(unittest.TestCase):
    def test_finance_intent_and_year_parsed(self):
        llm = _FakeLLM(
            "intent=finance_question;rag_needed=false;confidence=0.9;"
            "reason=asks for computed profit;year=2025;assistant_reply="
        )
        result = ConversationRouter(llm).route("what was my rental profit in 2025?")
        self.assertEqual(result["intent"], "finance_question")
        self.assertEqual(result["year"], 2025)
        self.assertFalse(result["rag_needed"])
        self.assertEqual(result["assistant_reply"], "")

    def test_year_is_none_when_not_mentioned(self):
        llm = _FakeLLM(
            "intent=finance_question;rag_needed=false;confidence=0.9;"
            "reason=profit question;year=none;assistant_reply="
        )
        result = ConversationRouter(llm).route("how is my rental doing?")
        self.assertEqual(result["intent"], "finance_question")
        self.assertIsNone(result["year"])

    def test_document_questions_still_route_to_retrieval(self):
        llm = _FakeLLM(
            "intent=document_question;rag_needed=true;confidence=0.9;"
            "reason=clause question;year=none;assistant_reply="
        )
        result = ConversationRouter(llm).route("what is the notice period on Unit A's tenancy?")
        self.assertEqual(result["intent"], "document_question")
        self.assertTrue(result["rag_needed"])

    def test_keyword_fallback_detects_finance_and_year(self):
        result = ConversationRouter(_RaisingLLM()).route("how much profit did I make in 2024?")
        self.assertEqual(result["intent"], "finance_question")
        self.assertEqual(result["year"], 2024)
        self.assertFalse(result["rag_needed"])


class GraphFinanceBranchTests(unittest.IsolatedAsyncioTestCase):
    async def test_finance_intent_routes_to_finance_action(self):
        class _FakeRouter:
            def route(self, text, recent_turns=None, property_name=None):
                return {
                    "intent": "finance_question", "rag_needed": False,
                    "confidence": 0.9, "reason": "finance",
                    "assistant_reply": "", "year": 2025,
                }

        class _FakePredictor:
            def predict(self, **kwargs):
                raise AssertionError("category predictor must not run on the finance branch")

        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor(),
        )
        state = await orchestrator.run({"user_input": "profit in 2025?"})
        self.assertEqual(state["action"], "finance")
        self.assertEqual(state["finance_year"], 2025)

    async def test_document_intent_unaffected(self):
        class _FakeRouter:
            def route(self, text, recent_turns=None, property_name=None):
                return {
                    "intent": "document_question", "rag_needed": True,
                    "confidence": 0.9, "reason": "clause",
                    "assistant_reply": "", "year": None,
                }

        class _FakePredictor:
            def predict(self, question, available_categories, available_units=None, recent_turns=None):
                return {
                    "predicted_categories": ["lease"], "confidence": 0.8,
                    "reason": "lease", "unit_id": None,
                    "unknown_unit": None, "unit_decided": False,
                }

        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor(),
        )
        state = await orchestrator.run({
            "user_input": "what does my lease say?",
            "available_categories": ["lease"],
        })
        self.assertEqual(state["action"], "retrieve")
        self.assertEqual(state["predicted_categories"], ["lease"])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `py -3.11 -m pytest tests/test_finance_chat.py -q`
Expected: FAIL — router result has no `"year"` key, intent `finance_question` is coerced away, graph has no finance action.

- [ ] **Step 3: Implement the router changes**

In `backend/rag/conversation_router.py`:

**(a)** add `import re` at the top and a module helper below the imports:

```python
_YEAR_PATTERN = re.compile(r"\b(20\d{2})\b")


def _extract_year(text: str) -> Optional[int]:
    match = _YEAR_PATTERN.search(text or "")
    return int(match.group(1)) if match else None
```

**(b)** the empty-input early return gains `"year": None`.

**(c)** replace the prompt's rules and response-format block with:

```python
Rules:
- If user asks for COMPUTED money totals across their records — rental profit/loss, rental income for a year, total expenses, statutory or tax-declarable rental income, "how much did I make/spend" -> intent=finance_question and rag_needed=false.
- If user asks about property documents, tenancy, rent terms, insurance, loans, property taxes, upkeep/repairs, maintenance fees, rental invoices, rules/clauses, obligations -> rag_needed=true and intent=document_question.
- If user is chatting, greeting, random social text, or not asking for document facts -> rag_needed=false and intent=conversation.
- If uncertain between conversation/document_question, prefer rag_needed=true.
- year: echo the 4-digit year when the question names one (e.g. "profit in 2025"), else none.

Respond in this exact format:
intent=<conversation|document_question|finance_question>;rag_needed=<true|false>;confidence=<0.0-1.0>;reason=<short reason>;year=<4-digit year or none>;assistant_reply=<short user-facing reply when rag_needed=false and intent=conversation, else empty>
```

**(d)** in the parse loop: extend the intent whitelist to `{"conversation", "document_question", "finance_question"}` and add a branch:

```python
                elif part.startswith("year="):
                    raw = part.replace("year=", "").strip().lower()
                    if raw.isdigit() and len(raw) == 4:
                        year = int(raw)
```

with `year: Optional[int] = None` initialized beside the other defaults.

**(e)** after the parse loop, replace the two post-processing lines with:

```python
            if intent == "document_question":
                rag_needed = True
            if intent == "finance_question":
                rag_needed = False
                assistant_reply = ""
            if rag_needed:
                assistant_reply = ""
```

**(f)** add `"year": year,` to the success-path return dict.

**(g)** in the `except` fallback, check finance keywords first and add `"year"` to every fallback return:

```python
        except Exception:
            finance_keywords = [
                "profit", "statutory", "net income", "p/l",
                "total expenses", "how much did i make", "how much did i earn",
            ]
            if any(token in normalized for token in finance_keywords):
                return {
                    "intent": "finance_question",
                    "rag_needed": False,
                    "confidence": 0.55,
                    "reason": "Finance keyword fallback",
                    "assistant_reply": "",
                    "year": _extract_year(normalized),
                }
            document_keywords = [
                "lease", "rent", "tenant", "insurance", "loan", "interest", "tax",
                "cukai", "upkeep", "repair", "maintenance", "invoice", "receipt",
                "property", "pets", "allowed", "clause", "agreement",
            ]
            if any(token in normalized for token in document_keywords):
                return {
                    "intent": "document_question",
                    "rag_needed": True,
                    "confidence": 0.55,
                    "reason": "Keyword fallback",
                    "assistant_reply": "",
                    "year": None,
                }
            return {
                "intent": "conversation",
                "rag_needed": False,
                "confidence": 0.55,
                "reason": "Safe conversational fallback",
                "assistant_reply": self._default_conversation_reply(property_name),
                "year": None,
            }
```

(If Plan A's Task 2 already replaced the document keyword list, keep that version — only the finance block and `"year"` keys are new here.)

- [ ] **Step 4: Implement the graph changes**

In `backend/rag/graph_orchestrator.py`:

**(a)** `DocuMindState` gains (after `intent_reason: str`):

```python
    finance_year: int
```

**(b)** `_route_conversation_node`'s router-result return gains:

```python
            "finance_year": result.get("year"),
```

**(c)** `_build_graph`: add the node and rewire the first conditional:

```python
        graph.add_node("prepare_finance", self._prepare_finance_node)
```

```python
        graph.add_conditional_edges(
            "route_conversation",
            self._route_after_conversation,
            {
                "conversation": "respond_conversation",
                "finance": "prepare_finance",
                "predict": "predict_categories",
            },
        )
```

and add `graph.add_edge("prepare_finance", END)` beside the other END edges.

**(d)** the node and router function:

```python
    async def _prepare_finance_node(self, state: DocuMindState) -> DocuMindState:
        return {**state, "action": "finance"}
```

```python
    def _route_after_conversation(self, state: DocuMindState) -> str:
        if state.get("intent") == "finance_question":
            return "finance"
        if state.get("rag_needed", False):
            return "predict"
        intent = state.get("intent")
        if intent == "conversation":
            return "conversation"
        return "predict"
```

- [ ] **Step 5: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: all PASS (6 new). Existing router/orchestration tests must keep passing — the checkpoint-action shortcut (`confirm`/`cancel`/`override:`/`unit:`) sets `intent="document_question"` and so never hits the finance branch.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/conversation_router.py backend/rag/graph_orchestrator.py backend/tests/test_finance_chat.py
git commit -m "feat: finance_question router intent with year echo and graph finance branch"
```

---

### Task 4: Chat finance branch in the service (narrate, never recompute)

**Files:**
- Modify: `backend/rag/documind_service.py` — finance branch in `ask_documind` (after the `graph_action == "conversation"` block), new `_narrate_finance_summary` method
- Modify: `backend/tests/test_documind_service_flows.py` (append test class; extend imports)

**Interfaces:**
- Consumes: Task 2's `get_finance_summary`, Task 3's `action == "finance"` + `finance_year` graph state.
- Produces: chat answers for finance questions with `category_filter_mode="finance"`, empty citations, 2 LLM calls total (router + narration), and a deterministic no-LLM fallback line when narration fails.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_documind_service_flows.py` (add `FinanceSummaryResponse, FinanceTotals` to the `models.documind_models` import — the file currently imports only `AskRequest` from there — and ensure `AsyncMock` is imported from `unittest.mock`):

```python
def _fake_finance_summary():
    return FinanceSummaryResponse(
        year=2025,
        totals=FinanceTotals(
            received_rent=219000.0,
            derived_rent=0.0,
            direct_expenses=158893.42,
            net_pl=60106.58,
            statutory_rental_income=60106.58,
            statutory_note="Estimate — for your tax agent",
        ),
        expense_breakdown={"loan": 97000.0},
        properties=[],
        caveats=["Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed."],
        missing_categories={},
    )


class FinanceChatFlowTests(unittest.IsolatedAsyncioTestCase):
    def _finance_graph(self, year=2025):
        return _FakeGraphOrchestrator({
            "action": "finance",
            "finance_year": year,
            "intent": "finance_question",
            "intent_reason": "asks for computed profit",
        })

    async def test_finance_action_narrates_engine_output(self):
        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        narration = "Your 2025 statutory rental income is RM 60,106.58 (Estimate — for your tax agent)."
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(), _FakeLLM(narration)
        )
        service.get_finance_summary = AsyncMock(return_value=_fake_finance_summary())

        response = await service.ask_documind(
            AskRequest(landlord_id="l1", property_id="p1", question="how much profit did I make in 2025?")
        )

        service.get_finance_summary.assert_awaited_once_with("l1", 2025)
        self.assertEqual(response.answer, narration)
        self.assertEqual(response.category_filter_mode, "finance")
        self.assertEqual(response.citations, [])
        self.assertFalse(response.user_action_required)

    async def test_finance_year_defaults_to_current_year(self):
        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(year=None), _FakeLLM("Narrated.")
        )
        service.get_finance_summary = AsyncMock(return_value=_fake_finance_summary())

        await service.ask_documind(
            AskRequest(landlord_id="l1", property_id="p1", question="how is my rental doing?")
        )

        awaited_year = service.get_finance_summary.await_args.args[1]
        self.assertEqual(awaited_year, datetime.now().year)

    async def test_narration_failure_falls_back_to_deterministic_line(self):
        class _RaisingLLM:
            def invoke(self, prompt):
                raise RuntimeError("llm down")

        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(), _RaisingLLM()
        )
        service.get_finance_summary = AsyncMock(return_value=_fake_finance_summary())

        response = await service.ask_documind(
            AskRequest(landlord_id="l1", property_id="p1", question="profit in 2025?")
        )

        self.assertIn("60,106.58", response.answer)
        self.assertIn("Estimate — for your tax agent", response.answer)

    async def test_engine_failure_returns_apology_not_exception(self):
        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(), _FakeLLM("unused")
        )
        service.get_finance_summary = AsyncMock(side_effect=RuntimeError("firestore down"))

        response = await service.ask_documind(
            AskRequest(landlord_id="l1", property_id="p1", question="profit in 2025?")
        )

        self.assertIn("couldn't compute", response.answer)
        self.assertEqual(response.citations, [])
```

Note on `_RaisingLLM` in `test_narration_failure...`: `_build_service` also hands the LLM to the `FactExtractor`/`_FakePdfOcr` helpers, but neither runs on this path — only `_narrate_finance_summary` invokes it.

- [ ] **Step 2: Run tests to verify they fail**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py -q`
Expected: the 4 new tests FAIL — `graph_action == "finance"` falls through to the retrieval path today.

- [ ] **Step 3: Implement**

In `backend/rag/documind_service.py`, insert directly after the `graph_action == "conversation"` block's `return AskResponse(...)` (i.e. before the `# Type 2 ambiguity` comment):

```python
        # Finance branch: skip retrieval entirely — the deterministic engine
        # computes, the LLM only narrates (2 LLM calls total incl. the router).
        if graph_action == "finance":
            requested_year = graph_state.get("finance_year") or datetime.now().year
            try:
                summary = await self.get_finance_summary(payload.landlord_id, requested_year)
                answer = self._narrate_finance_summary(payload.question, property_name, summary)
            except Exception as e:
                print(f"❌ Finance summary failed: {e}")
                answer = (
                    "I couldn't compute your rental finances just now. "
                    "Please try again in a moment."
                )
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "finance_question",
                    "action": "finance",
                    "answer": answer,
                },
            )
            return AskResponse(
                answer=answer,
                confidence=0.9,
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="finance",
                needs_category_clarification=False,
                clarification_prompt=None,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=[],
                action_reason=graph_state.get("intent_reason"),
            )
```

Add the narration method (place it after `_get_property_name`):

```python
    def _narrate_finance_summary(self, question: str, property_name: str, summary) -> str:
        """Turn the engine's computed JSON into a chat answer. The LLM narrates
        only — on any failure a deterministic headline line stands in, so the
        numbers shown are always the engine's."""
        totals = summary.totals
        top_caveat = summary.caveats[0] if summary.caveats else ""
        prompt = f"""You are DocuMind, answering a landlord's finance question.

**Question:** {question}
**Currently selected property (context only — figures below cover the whole portfolio):** {property_name}

**Computed figures for {summary.year} (authoritative):**
{summary.model_dump_json(indent=2)}

Rules:
1. Answer using ONLY the figures above, quoted exactly as given. NEVER recompute, derive, add, or estimate any number yourself.
2. If a figure the user wants is not present above, say it is not computed rather than deriving it.
3. When mentioning statutory rental income, always attach: "{totals.statutory_note}".
4. Include this caveat once: {top_caveat}
5. Amounts are in RM. Be concise; short bullet points are fine.

**Your Answer:**"""
        try:
            response = self.llm.invoke(prompt)
            return response.content.strip()
        except Exception as e:
            print(f"❌ Finance narration failed: {e}")
            return (
                f"For {summary.year}: gross rent RM {totals.received_rent:,.2f}, "
                f"direct expenses RM {totals.direct_expenses:,.2f}, "
                f"net P/L RM {totals.net_pl:,.2f}. "
                f"Statutory rental income: RM {totals.statutory_rental_income:,.2f} "
                f"({totals.statutory_note})."
            )
```

- [ ] **Step 4: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: all PASS.

- [ ] **Step 5: Manual smoke test (optional but recommended)**

Restart the backend, then via the app or `POST /api/rex/documind/ask` with `{"landlord_id": ..., "property_id": ..., "question": "what's my rental profit this year?"}` — expect a narrated answer with no citations, log shows no retrieval, and `GET /api/rex/documind/finance/summary?landlord_id=...&year=2026` returns the same numbers.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/documind_service.py backend/tests/test_documind_service_flows.py
git commit -m "feat: chat finance branch narrates engine output, never recomputes"
```

---

## Deliverable check (spec Plan B)

After Task 4: the golden test reproduces the reference sheet's `60,106.58` exactly; `GET /api/rex/documind/finance/summary` serves the full summary shape with caveats and completeness; and DocuMind chat answers "what's my rental profit in 2025?" in 2 LLM calls by narrating the engine's figures — with a deterministic fallback if narration fails. Plan C renders all of it.
