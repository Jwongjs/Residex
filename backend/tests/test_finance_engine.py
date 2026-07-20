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


def _exception(pid, month, unit_id=None, reason=None):
    return {"property_id": pid, "unit_id": unit_id, "month": month, "reason": reason}


def _summary(documents, properties, units=None, year=2025, today=date(2026, 7, 16), payment_exceptions=None):
    return compute_finance_summary(
        year=year,
        today=today,
        documents=documents,
        properties=properties,
        units_by_property=units or {},
        payment_exceptions=payment_exceptions,
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


class PaymentExceptionTests(unittest.TestCase):
    def test_exception_excludes_income_but_keeps_expense_proration(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "maintenance", {"amount": 1200.0, "period_start": "2025-01-01", "period_end": "2025-12-31"}),
        ]
        result = _summary(docs, [_prop("p1", "House")], payment_exceptions=[_exception("p1", "2025-03")])
        unit = result["properties"][0]["units"][0]
        march = next(m for m in unit["months"] if m["month"] == 3)
        self.assertEqual(march["source"], "unpaid")
        self.assertEqual(march["amount"], 0.0)
        # 11 months derived x 1000 (March excluded)
        self.assertEqual(result["properties"][0]["received_rent"], 11000.0)
        # March still counts as tenanted -> full year rented -> full expense deducted
        self.assertEqual(unit["rented_months"], 12)
        self.assertEqual(result["properties"][0]["direct_expenses"], 1200.0)
        self.assertEqual(result["properties"][0]["rental_income_or_loss"], 9800.0)

    def test_exception_beats_invoice(self):
        docs = [_doc("p1", "rental_invoice", {"amount": 1200.0, "period_month": "2025-03"})]
        result = _summary(docs, [_prop("p1", "House")],
                           payment_exceptions=[_exception("p1", "2025-03", reason="bounced cheque")])
        march = next(m for m in result["properties"][0]["units"][0]["months"] if m["month"] == 3)
        self.assertEqual(march["source"], "unpaid")
        self.assertEqual(result["properties"][0]["received_rent"], 0.0)

    def test_exception_beats_lease_derived(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House")], payment_exceptions=[_exception("p1", "2025-03")])
        march = next(m for m in result["properties"][0]["units"][0]["months"] if m["month"] == 3)
        self.assertEqual(march["source"], "unpaid")
        self.assertEqual(result["properties"][0]["received_rent"], 11000.0)

    def test_exception_reduces_statutory_income(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        without = _summary(docs, [_prop("p1", "House")])
        with_exception = _summary(docs, [_prop("p1", "House")], payment_exceptions=[_exception("p1", "2025-03")])
        self.assertEqual(without["totals"]["statutory_rental_income"], 12000.0)
        self.assertEqual(with_exception["totals"]["statutory_rental_income"], 11000.0)

    def test_exception_reason_appears_in_caveats(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House")],
                           payment_exceptions=[_exception("p1", "2025-03", reason="tenant requested deferral")])
        joined = " ".join(result["caveats"])
        self.assertIn("No payment received for Mar", joined)
        self.assertIn("tenant requested deferral", joined)

    def test_malformed_and_mismatched_exceptions_are_tolerated(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        exceptions = [
            _exception("p1", "not-a-month"),
            _exception("p2", "2025-03"),  # wrong property, must be ignored
            {"property_id": "p1", "unit_id": None, "month": "2025-04"},  # missing "reason" key is fine
        ]
        result = _summary(docs, [_prop("p1", "House")], payment_exceptions=exceptions)
        months = {m["month"]: m["source"] for m in result["properties"][0]["units"][0]["months"]}
        self.assertEqual(months[3], "derived")  # malformed month string ignored
        self.assertEqual(months[4], "unpaid")   # well-formed record still applies


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


class TestCombinedExpensesDocument(unittest.TestCase):
    def _summary(self, docs):
        return compute_finance_summary(
            year=2025,
            today=date(2026, 7, 18),
            documents=docs,
            properties=[{"property_id": "p1", "name": "Test Property"}],
            units_by_property={},
        )

    def test_lines_map_to_breakdown_categories_and_filter_by_year(self):
        docs = [{
            "doc_id": "d-exp",
            "property_id": "p1",
            "unit_id": None,
            "category": "expenses",
            "extracted_facts": {
                "expense_lines": [
                    {"subtype": "maintenance", "amount": 4200.0, "period_year": 2025},
                    {"subtype": "sinking_fund", "amount": 840.0, "period_year": 2025},
                    {"subtype": "insurance_premium", "amount": 1800.0, "date": "2025-03-01"},
                    {"subtype": "quit_rent", "amount": 316.87, "period_year": 2025},
                    {"subtype": "quit_rent", "amount": 316.87, "period_year": 2024},
                ],
                "policy_end": "2026-03-01",
            },
        }]
        summary = self._summary(docs)
        self.assertEqual(summary["expense_breakdown"]["maintenance"], 5040.0)
        self.assertEqual(summary["expense_breakdown"]["insurance"], 1800.0)
        self.assertEqual(summary["expense_breakdown"]["tax"], 316.87)
        self.assertEqual(summary["totals"]["direct_expenses"], 7156.87)

    def test_malformed_lines_are_skipped_silently(self):
        docs = [{
            "doc_id": "d-bad",
            "property_id": "p1",
            "unit_id": None,
            "category": "expenses",
            "extracted_facts": {
                "expense_lines": [
                    {"subtype": "unknown_thing", "amount": 10.0, "period_year": 2025},
                    {"subtype": "maintenance", "period_year": 2025},
                    "not-a-dict",
                    {"subtype": "maintenance", "amount": 100.0, "period_year": 2025},
                ],
            },
        }]
        summary = self._summary(docs)
        self.assertEqual(summary["totals"]["direct_expenses"], 100.0)
