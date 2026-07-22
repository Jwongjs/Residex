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


class CoverageTests(unittest.TestCase):
    def test_coverage_window_starts_at_earliest_lease_year(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2023-06-01", "lease_end": "2025-05-31"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        years = [c["year"] for c in result["properties"][0]["coverage"]]
        self.assertEqual(years, [2023, 2024, 2025, 2026])

    def test_coverage_flags_missing_categories_and_rental_invoice_windowing(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2024-01-01", "lease_end": "2024-12-31"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 100.0, "period_year": 2024}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        coverage = {c["year"]: c["missing"] for c in result["properties"][0]["coverage"]}
        self.assertEqual(sorted(coverage.keys()), [2024, 2025, 2026])
        # 2024: lease covers it -> no rental_invoice document -> flagged; tax present -> not flagged
        self.assertIn("rental_invoice", coverage[2024])
        self.assertNotIn("tax", coverage[2024])
        for category in ("loan", "upkeep", "maintenance", "insurance"):
            self.assertIn(category, coverage[2024])
        # 2025/2026: lease doesn't cover -> rental_invoice NOT flagged
        self.assertNotIn("rental_invoice", coverage[2025])
        self.assertNotIn("rental_invoice", coverage[2026])
        # but tax is still flagged in years no document covers
        self.assertIn("tax", coverage[2025])
        self.assertIn("tax", coverage[2026])

    def test_coverage_falls_back_to_earliest_document_year_without_lease(self):
        docs = [_doc("p1", "tax", {"subtype": "assessment", "amount": 100.0, "period_year": 2022})]
        result = _summary(docs, [_prop("p1", "House")])
        years = [c["year"] for c in result["properties"][0]["coverage"]]
        self.assertEqual(years[0], 2022)
        self.assertEqual(years[-1], 2026)

    def test_coverage_empty_when_no_documents(self):
        result = _summary([], [_prop("p1", "House")])
        self.assertEqual(result["properties"][0]["coverage"], [])


class NonDeductibleLineTests(unittest.TestCase):
    def _statement(self):
        return _doc("p1", "expenses", {"expense_lines": [
            {"subtype": "maintenance", "amount": 764.00, "date": "2025-02-01"},
            {"subtype": "sinking_fund", "amount": 76.40, "date": "2025-02-01"},
            {"subtype": "utilities", "amount": 132.21, "date": "2025-02-01"},
            {"subtype": "late_penalty", "amount": 5.71, "date": "2025-02-01"},
        ]})

    def test_utilities_and_penalties_excluded_by_default(self):
        result = _summary([self._statement()], [_prop("p1", "Ayer8")])
        self.assertEqual(result["totals"]["direct_expenses"], 840.40)
        self.assertEqual(result["expense_breakdown"]["maintenance"], 840.40)
        self.assertNotIn("utilities", result["expense_breakdown"])
        self.assertNotIn("late_penalty", result["expense_breakdown"])

    def test_non_deductible_lines_are_still_captured_and_visible(self):
        result = _summary([self._statement()], [_prop("p1", "Ayer8")])
        lines = result["properties"][0]["expense_lines"]
        utilities = next(l for l in lines if l["subtype"] == "utilities")
        self.assertFalse(utilities["deductible"])
        self.assertEqual(utilities["amount"], 132.21)
        self.assertEqual(utilities["category"], "utilities")

    def test_utilities_deduct_when_the_landlord_bears_them(self):
        prop = dict(_prop("p1", "Ayer8"), utilities_paid_by="landlord")
        result = _summary([self._statement()], [prop])
        self.assertEqual(result["totals"]["direct_expenses"], 972.61)
        self.assertEqual(result["expense_breakdown"]["utilities"], 132.21)

    def test_penalties_never_deduct_even_when_landlord_pays_utilities(self):
        prop = dict(_prop("p1", "Ayer8"), utilities_paid_by="landlord")
        result = _summary([self._statement()], [prop])
        penalty = next(
            l for l in result["properties"][0]["expense_lines"]
            if l["subtype"] == "late_penalty"
        )
        self.assertFalse(penalty["deductible"])

    def test_renovation_and_loan_principal_never_deduct(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "renovation", "amount": 9000.0, "date": "2025-05-01"},
            {"subtype": "loan_principal", "amount": 12000.0, "period_year": 2025},
            {"subtype": "upkeep", "amount": 300.0, "date": "2025-05-01"},
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertEqual(result["totals"]["direct_expenses"], 300.0)
        self.assertNotIn("renovation", result["expense_breakdown"])
        self.assertNotIn("loan_principal", result["expense_breakdown"])

    def test_loan_principal_does_not_satisfy_loan_coverage(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "loan_principal", "amount": 12000.0, "period_year": 2025},
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertIn("loan", result["missing_categories"]["p1"])

    def test_exclusion_is_announced_not_silent(self):
        result = _summary([self._statement()], [_prop("p1", "Ayer8")])
        self.assertTrue(any(
            "not deductible" in c and "Ayer8" in c for c in result["caveats"]
        ))

    def test_document_backed_lines_default_to_deductible(self):
        docs = [_doc("p1", "upkeep", {"amount": 300.0, "service_date": "2025-04-10"})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertTrue(result["properties"][0]["expense_lines"][0]["deductible"])

    def test_non_deductible_lines_do_not_reduce_statutory_income(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            self._statement(),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        # 12 x 1000 rent, fully rented so the proration factor is 1.0
        self.assertEqual(result["totals"]["statutory_rental_income"], 12000.0 - 840.40)


class ExpandedSubtypeTests(unittest.TestCase):
    def test_agent_and_management_charges_roll_into_their_own_buckets(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "management_fee", "amount": 200.0, "date": "2025-02-01"},
            {"subtype": "rent_collection", "amount": 50.0, "date": "2025-02-01"},
            {"subtype": "security_fee", "amount": 30.0, "date": "2025-02-01"},
            {"subtype": "sst", "amount": 24.0, "date": "2025-02-01"},
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertEqual(result["expense_breakdown"]["management"], 280.0)
        self.assertEqual(result["expense_breakdown"]["sst"], 24.0)
        self.assertEqual(result["totals"]["direct_expenses"], 304.0)

    def test_pest_control_rolls_into_upkeep(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "pest_control", "amount": 120.0, "date": "2025-05-01"},
            {"subtype": "upkeep", "amount": 300.0, "date": "2025-05-01"},
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertEqual(result["expense_breakdown"]["upkeep"], 420.0)

    def test_strata_management_charge_still_lands_in_maintenance(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "maintenance", "amount": 764.0, "date": "2025-02-01"},
            {"subtype": "sinking_fund", "amount": 76.4, "date": "2025-02-01"},
        ]})]
        result = _summary(docs, [_prop("p1", "Condo")])
        self.assertEqual(result["expense_breakdown"]["maintenance"], 840.40)
        self.assertNotIn("management", result["expense_breakdown"])

    def test_new_buckets_never_become_a_coverage_expectation(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "management_fee", "amount": 200.0, "date": "2025-02-01"},
            {"subtype": "sst", "amount": 24.0, "date": "2025-02-01"},
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        row = next(
            r for r in result["properties"][0]["coverage"] if r["year"] == 2025
        )
        self.assertNotIn("management", row["missing"])
        self.assertNotIn("sst", row["missing"])
        self.assertNotIn("letting", row["missing"])

    def test_sst_never_satisfies_the_property_tax_slot(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "sst", "amount": 24.0, "date": "2025-02-01"},
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertIn("tax", result["missing_categories"]["p1"])

    def test_every_new_subtype_has_a_line_label(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": subtype, "amount": 10.0, "date": "2025-02-01"}
            for subtype in (
                "agent_commission", "management_fee", "legal_fee", "stamp_duty",
                "advertising", "pest_control", "rent_collection", "security_fee",
                "sst",
            )
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        lines = result["properties"][0]["expense_lines"]
        self.assertEqual(len(lines), 9)
        self.assertTrue(all(line["description"] for line in lines))


class LettingCostDeductibilityTests(unittest.TestCase):
    def _letting_costs(self):
        return _doc("p1", "expenses", {"expense_lines": [
            {"subtype": "agent_commission", "amount": 1200.0, "date": "2025-01-15"},
            {"subtype": "stamp_duty", "amount": 180.0, "date": "2025-01-15"},
        ]})

    def _lease(self, subtype):
        return _doc("p1", "lease", {
            "monthly_rent": 1000.0, "subtype": subtype,
            "lease_start": "2025-01-01", "lease_end": "2025-12-31",
        })

    def test_first_letting_costs_do_not_deduct(self):
        result = _summary(
            [self._lease("new"), self._letting_costs()], [_prop("p1", "House")]
        )
        self.assertEqual(result["totals"]["direct_expenses"], 0.0)
        self.assertNotIn("letting", result["expense_breakdown"])

    def test_renewal_letting_costs_deduct(self):
        result = _summary(
            [self._lease("renewal"), self._letting_costs()], [_prop("p1", "House")]
        )
        self.assertEqual(result["expense_breakdown"]["letting"], 1380.0)
        self.assertEqual(result["totals"]["direct_expenses"], 1380.0)

    def test_no_lease_on_file_is_treated_as_a_first_letting(self):
        result = _summary([self._letting_costs()], [_prop("p1", "House")])
        self.assertEqual(result["totals"]["direct_expenses"], 0.0)

    def test_a_renewal_in_another_year_does_not_unlock_this_year(self):
        earlier = _doc("p1", "lease", {
            "monthly_rent": 1000.0, "subtype": "renewal",
            "lease_start": "2024-01-01", "lease_end": "2024-12-31",
        })
        result = _summary([earlier, self._letting_costs()], [_prop("p1", "House")])
        self.assertEqual(result["totals"]["direct_expenses"], 0.0)

    def test_excluded_letting_costs_say_what_would_change_them(self):
        result = _summary([self._letting_costs()], [_prop("p1", "House")])
        self.assertTrue(any(
            "renewal tenancy agreement" in c for c in result["caveats"]
        ))

    def test_letting_lines_stay_visible_when_excluded(self):
        result = _summary([self._letting_costs()], [_prop("p1", "House")])
        lines = result["properties"][0]["expense_lines"]
        commission = next(l for l in lines if l["subtype"] == "agent_commission")
        self.assertEqual(commission["amount"], 1200.0)
        self.assertFalse(commission["deductible"])

    def test_other_subtypes_are_unaffected_by_the_renewal_rule(self):
        docs = [self._lease("new"), _doc("p1", "expenses", {"expense_lines": [
            {"subtype": "upkeep", "amount": 300.0, "date": "2025-05-01"},
        ]})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertEqual(result["totals"]["direct_expenses"], 300.0)


class ProfileExpectationTests(unittest.TestCase):
    def _docs(self):
        return [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01",
                                     "lease_end": "2025-12-31"})]

    def _row(self, prop, year=2025):
        result = _summary(self._docs(), [prop])
        return next(
            r for r in result["properties"][0]["coverage"] if r["year"] == year
        )

    def test_landed_property_is_never_asked_for_maintenance(self):
        row = self._row(dict(_prop("p1", "House"), property_type="landed"))
        self.assertNotIn("maintenance", row["missing"])
        self.assertIn("insurance", row["missing"])

    def test_strata_property_is_never_asked_for_insurance(self):
        row = self._row(dict(_prop("p1", "Condo"), property_type="strata"))
        self.assertNotIn("insurance", row["missing"])
        self.assertIn("maintenance", row["missing"])

    def test_unmortgaged_property_is_never_asked_for_a_loan_statement(self):
        row = self._row(dict(_prop("p1", "House"),
                             property_type="landed", has_mortgage=False))
        self.assertNotIn("loan", row["missing"])

    def test_mortgaged_property_is_still_asked_for_a_loan_statement(self):
        row = self._row(dict(_prop("p1", "House"),
                             property_type="landed", has_mortgage=True))
        self.assertIn("loan", row["missing"])

    def test_unknown_profile_keeps_todays_behaviour(self):
        row = self._row(_prop("p1", "House"))
        self.assertIn("maintenance", row["missing"])
        self.assertIn("insurance", row["missing"])
        self.assertIn("loan", row["missing"])

    def test_the_gate_also_applies_to_missing_category_caveats(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata", has_mortgage=False)
        result = _summary(self._docs(), [prop])
        missing = result["missing_categories"]["p1"]
        self.assertNotIn("insurance", missing)
        self.assertNotIn("loan", missing)
        self.assertIn("maintenance", missing)


class TaxSubtypeCoverageTests(unittest.TestCase):
    def _docs(self, *tax_subtypes):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01",
                                     "lease_end": "2025-12-31"})]
        for subtype in tax_subtypes:
            docs.append(_doc("p1", "tax", {"subtype": subtype, "amount": 400.0,
                                           "period_year": 2025}))
        return docs

    def _row(self, prop, docs):
        result = _summary(docs, [prop])
        return next(
            r for r in result["properties"][0]["coverage"] if r["year"] == 2025
        )

    def test_landed_expects_quit_rent(self):
        prop = dict(_prop("p1", "House"), property_type="landed")
        row = self._row(prop, self._docs("assessment"))
        self.assertIn("quit_rent", row["missing"])
        self.assertNotIn("parcel_rent", row["missing"])
        self.assertNotIn("assessment", row["missing"])
        self.assertNotIn("tax", row["missing"])

    def test_strata_land_office_slot_satisfied_by_parcel_rent(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        row = self._row(prop, self._docs("assessment", "parcel_rent"))
        self.assertNotIn("land_office_tax", row["missing"])

    def test_strata_land_office_slot_also_satisfied_by_quit_rent(self):
        # Master-title strata: the management apportions quit rent to the
        # parcel, so no parcel-rent bill will ever exist. Real Ayer@8 case.
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        row = self._row(prop, self._docs("assessment", "quit_rent"))
        self.assertNotIn("land_office_tax", row["missing"])
        self.assertNotIn("parcel_rent", row["missing"])

    def test_strata_with_neither_is_flagged_exactly_once(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        row = self._row(prop, self._docs("assessment"))
        self.assertEqual(row["missing"].count("land_office_tax"), 1)

    def test_missing_assessment_is_flagged_separately(self):
        prop = dict(_prop("p1", "House"), property_type="landed")
        row = self._row(prop, self._docs("quit_rent"))
        self.assertIn("assessment", row["missing"])
        self.assertNotIn("quit_rent", row["missing"])

    def test_bundled_expenses_line_satisfies_the_land_office_slot(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        docs = self._docs("assessment")
        docs.append(_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "quit_rent", "amount": 434.56, "period_year": 2025},
        ]}))
        row = self._row(prop, docs)
        self.assertNotIn("land_office_tax", row["missing"])

    def test_bundled_assessment_line_satisfies_the_assessment_slot(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        docs = self._docs()
        docs.append(_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "assessment_tax", "amount": 400.0, "date": "2025-02-01"},
        ]}))
        row = self._row(prop, docs)
        self.assertNotIn("assessment", row["missing"])

    def test_unknown_type_keeps_the_generic_tax_bucket(self):
        row = self._row(_prop("p1", "House"), self._docs())
        self.assertIn("tax", row["missing"])
        self.assertNotIn("quit_rent", row["missing"])
        self.assertNotIn("land_office_tax", row["missing"])
