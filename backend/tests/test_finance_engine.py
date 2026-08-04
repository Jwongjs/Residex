import unittest
from datetime import date, datetime

from rag.finance.finance_engine import (
    LOSS_FLOOR_NOTE,
    STATUTORY_NOTE,
    _expected_record_categories,
    _installment_gaps,
    _maintenance_months_covered,
    _parse_installment,
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


def _exception(pid, month, unit_id=None, reason=None, state=None):
    row = {"property_id": pid, "unit_id": unit_id, "month": month, "reason": reason}
    if state is not None:
        row["state"] = state
    return row


def _doc_exception(pid, year, category):
    return {"property_id": pid, "year": year, "category": category}


def _recovery(pid, original_month, amount, received_year, unit_id=None):
    return {
        "property_id": pid, "unit_id": unit_id, "original_month": original_month,
        "amount": amount, "received_year": received_year,
    }


def _summary(documents, properties, units=None, year=2025, today=date(2026, 7, 16),
             payment_exceptions=None, document_exceptions=None, rent_recoveries=None,
             manual_loan_entries=None, unit_loan_exemptions=None):
    return compute_finance_summary(
        year=year,
        today=today,
        documents=documents,
        properties=properties,
        units_by_property=units or {},
        payment_exceptions=payment_exceptions,
        document_exceptions=document_exceptions,
        rent_recoveries=rent_recoveries,
        manual_loan_entries=manual_loan_entries,
        unit_loan_exemptions=unit_loan_exemptions,
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

    def test_empty_whole_property_scope_hidden_when_units_carry_income(self):
        # A property-wide lease with no extractable rent triggers the synthetic
        # "Whole property" scope but leaves it empty. Beside a unit that holds
        # the actual income it would render as a confusing "Whole property —
        # RM 0.00" row, so it must be suppressed. Totals are unaffected.
        docs = [
            _doc("p1", "rental_invoice", {"amount": 500.0, "period_month": "2025-01"}, unit_id="u1"),
            _doc("p1", "lease", {"tenant_name": "Unclear Rent Bhd"}),  # property-wide, no rent
        ]
        result = _summary(docs, [_prop("p1", "Block A")], units={"p1": [{"unit_id": "u1", "label": "Unit A"}]})
        labels = [u["label"] for u in result["properties"][0]["units"]]
        self.assertEqual(labels, ["Unit A"])
        self.assertEqual(result["properties"][0]["received_rent"], 500.0)
        self.assertFalse(
            any("Whole property" in c for c in result["caveats"]),
            "suppressed scope must not leave whole-property vacancy caveats",
        )

    def test_single_let_scope_kept_even_when_empty(self):
        # No real units: the sole synthetic scope must survive even at zero
        # income, or a single-let house would render no income row at all.
        docs = [_doc("p1", "lease", {"tenant_name": "Unclear Rent Bhd"})]
        result = _summary(docs, [_prop("p1", "House")])
        self.assertEqual(len(result["properties"][0]["units"]), 1)

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
        exceptions = [
            _doc_exception("p1", 2025, c)
            for c in ("rental_invoice", "loan", "tax", "upkeep", "maintenance", "insurance")
        ]
        without = _summary(docs, [_prop("p1", "House")], document_exceptions=exceptions)
        with_exception = _summary(docs, [_prop("p1", "House")], payment_exceptions=[_exception("p1", "2025-03")],
                                   document_exceptions=exceptions)
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
        # No profile is set, so every FINANCE_CATEGORIES slot is expected;
        # mark the ones this fixture never intended to exercise unavailable
        # so completeness doesn't withhold the statutory figure under test.
        exceptions = [_doc_exception("p1", 2025, c) for c in ("loan", "tax", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "Block")], units=units, year=2025, today=date(2026, 1, 1),
                           document_exceptions=exceptions)
        # Net includes the vacant unit's expense (cash reality)
        self.assertEqual(result["totals"]["net_pl"], 400.0)
        # Statutory prorates Unit B's expense by its rented fraction (0/12)
        # and Unit A's income stands: 1000 - 600*0 = 1000
        self.assertEqual(result["totals"]["statutory_rental_income"], 1000.0)

    def test_ownership_share_scales_both_net_and_statutory(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "tax", {"subtype": "quit_rent", "amount": 120.0, "period_year": 2025}),
        ]
        exceptions = [_doc_exception("p1", 2025, c) for c in ("loan", "upkeep", "maintenance", "insurance")]
        result = _summary(docs, [_prop("p1", "Shared", share=0.5)], year=2025, today=date(2026, 1, 1),
                           document_exceptions=exceptions)
        # Net P/L now also reflects the ownership share: 0.5 * (1000 - 120).
        self.assertEqual(result["totals"]["net_pl"], 440.0)
        # statutory: 0.5 * (1000 - 120 * (1/12 rented fraction)) = 495.
        self.assertEqual(result["totals"]["statutory_rental_income"], 495.0)
        # The invariant the landlord expects: statutory (deducts less) is never
        # below Net P/L once both are on the same ownership basis.
        self.assertGreaterEqual(
            result["totals"]["statutory_rental_income"], result["totals"]["net_pl"]
        )
        self.assertTrue(any("Ownership share applied" in c for c in result["caveats"]))

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

    def test_loss_offsets_across_properties_then_floors_at_zero(self):
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p2", "rental_invoice", {"amount": 200.0, "period_month": "2025-01"}),
            _doc("p2", "loan", {"subtype": "interest_statement", "interest_paid": 5000.0, "period_year": 2025}),
        ]
        exceptions = (
            [_doc_exception("p1", 2025, c) for c in ("loan", "tax", "upkeep", "maintenance", "insurance")]
            + [_doc_exception("p2", 2025, c) for c in ("tax", "upkeep", "maintenance", "insurance")]
        )
        result = _summary(docs, [_prop("p1", "Winner"), _prop("p2", "Loser")], year=2025, today=date(2026, 1, 1),
                           document_exceptions=exceptions)
        # p1 statutory 1000; p2: 200 - 5000*(1/12) = -216.67 -> offsets
        self.assertEqual(result["totals"]["statutory_rental_income"], 783.33)
        self.assertNotIn(LOSS_FLOOR_NOTE, result["totals"]["statutory_note"])

        heavy_loss = docs + [
            _doc("p2", "loan", {"subtype": "interest_statement", "interest_paid": 200000.0, "period_year": 2025},
                 doc_id="big-loss"),
        ]
        floored = _summary(heavy_loss, [_prop("p1", "Winner"), _prop("p2", "Loser")], year=2025, today=date(2026, 1, 1),
                            document_exceptions=exceptions)
        self.assertEqual(floored["totals"]["statutory_rental_income"], 0.0)
        self.assertIn(LOSS_FLOOR_NOTE, floored["totals"]["statutory_note"])
        self.assertIn(STATUTORY_NOTE, floored["totals"]["statutory_note"])

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
            # No profile is set (property_type unknown), so every FINANCE_CATEGORIES
            # slot is expected; these $0 placeholders satisfy insurance/upkeep for
            # completeness without moving any of the sheet's real figures.
            _doc("p1", "insurance", {"premium": 0.0,
                                     "policy_start": "2025-01-01", "policy_end": "2025-12-31"}),
            _doc("p1", "upkeep", {"amount": 0.0, "service_date": "2025-06-01"}),
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
            _doc("p2", "insurance", {"premium": 0.0,
                                     "policy_start": "2025-01-01", "policy_end": "2025-12-31"}),
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
            _doc("p3", "tax", {"subtype": "assessment", "amount": 0.0, "period_year": 2025}),
            _doc("p3", "upkeep", {"amount": 0.0, "service_date": "2025-06-01"}),
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
        exceptions = [
            _doc_exception("p1", 2025, c)
            # maintenance has only one of twelve months on file (a single
            # bundled line), so it is partial, not present — mark it too.
            for c in ("rental_invoice", "loan", "tax", "upkeep", "insurance", "maintenance")
        ]
        result = _summary(docs, [_prop("p1", "House")], document_exceptions=exceptions)
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


class InstallmentGapTests(unittest.TestCase):
    def test_parses_common_installment_labels(self):
        self.assertEqual(_parse_installment("1/2"), (1, 2))
        self.assertEqual(_parse_installment("2 of 2"), (2, 2))
        self.assertEqual(_parse_installment("ansuran 1/3"), (1, 3))
        self.assertEqual(_parse_installment("First half"), (None, None))
        self.assertEqual(_parse_installment(None), (None, None))
        self.assertEqual(_parse_installment("3/2"), (None, None))

    def test_flags_a_missing_second_installment_from_a_typed_tax_doc(self):
        docs = [_doc("p1", "tax", {
            "subtype": "assessment", "amount": 400.0,
            "period_year": 2025, "installment": "1/2",
        })]
        self.assertEqual(
            _installment_gaps(docs, 2025),
            [{"label": "Assessment tax", "have": 1, "expect": 2}],
        )

    def test_no_gap_when_both_installments_present(self):
        docs = [
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "1/2"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "2/2"}),
        ]
        self.assertEqual(_installment_gaps(docs, 2025), [])

    def test_duplicate_installment_still_counts_as_one(self):
        docs = [
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "1/2"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "1/2"}),
        ]
        self.assertEqual(
            _installment_gaps(docs, 2025),
            [{"label": "Assessment tax", "have": 1, "expect": 2}],
        )

    def test_annual_billing_council_never_triggers(self):
        docs = [_doc("p1", "tax", {"subtype": "assessment", "amount": 800.0,
                                   "period_year": 2025})]
        self.assertEqual(_installment_gaps(docs, 2025), [])

    def test_bundled_expenses_line_installment_counts_too(self):
        # A management statement lists the second assessment installment as
        # one line among several — the same statement that already
        # satisfies maintenance for the month (Stage A precedent).
        docs = [
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "1/2"}),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "assessment_tax", "amount": 400.0,
                 "period_year": 2025, "installment": "2/2"},
            ]}),
        ]
        self.assertEqual(_installment_gaps(docs, 2025), [])

    def test_bundled_line_installment_resolves_year_from_its_date(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "assessment_tax", "amount": 400.0,
             "date": "2025-06-01", "installment": "1/2"},
        ]})]
        self.assertEqual(
            _installment_gaps(docs, 2025),
            [{"label": "Assessment tax", "have": 1, "expect": 2}],
        )

    def test_quit_rent_and_parcel_rent_installments_normalise_like_assessment(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "quit_rent", "amount": 200.0, "period_year": 2025,
             "installment": "1/2"},
        ]})]
        self.assertEqual(
            _installment_gaps(docs, 2025),
            [{"label": "Quit rent", "have": 1, "expect": 2}],
        )


class PartialInstallmentCoverageTests(unittest.TestCase):
    def test_coverage_reports_a_partial_installment_year(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "1/2"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        row = next(r for r in result["properties"][0]["coverage"] if r["year"] == 2025)
        self.assertEqual(
            row["partial_installments"],
            [{"label": "Assessment tax", "have": 1, "expect": 2}],
        )

    def test_complete_year_reports_no_partials(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "1/2"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "2/2"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        row = next(r for r in result["properties"][0]["coverage"] if r["year"] == 2025)
        self.assertEqual(row["partial_installments"], [])

    def test_marking_the_gap_unavailable_clears_it_from_partial_installments(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 400.0,
                               "period_year": 2025, "installment": "1/2"}),
        ]
        prop = dict(_prop("p1", "House"), property_type="landed")
        exceptions = [_doc_exception("p1", 2025, "assessment")]
        result = _summary(docs, [prop], document_exceptions=exceptions)
        row = next(r for r in result["properties"][0]["coverage"] if r["year"] == 2025)
        self.assertEqual(row["partial_installments"], [])
        self.assertIn("assessment", row["unavailable"])


class MaintenanceMonthCoverageTests(unittest.TestCase):
    def test_typed_maintenance_doc_covers_its_period_span(self):
        docs = [_doc("p1", "maintenance", {
            "amount": 300.0, "period_start": "2025-01-01", "period_end": "2025-03-31",
        })]
        self.assertEqual(_maintenance_months_covered(docs, 2025), {1, 2, 3})

    def test_bundled_line_covers_only_its_own_dated_month(self):
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "maintenance", "amount": 250.0, "date": "2025-02-01"},
            {"subtype": "sinking_fund", "amount": 25.0, "date": "2025-02-01"},
        ]})]
        self.assertEqual(_maintenance_months_covered(docs, 2025), {2})

    def test_year_only_bundled_line_fills_no_specific_month(self):
        # No date to resolve to a month: falls back to the year, satisfies
        # no monthly slot (spec §4).
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "maintenance", "amount": 3000.0, "period_year": 2025},
        ]})]
        self.assertEqual(_maintenance_months_covered(docs, 2025), set())

    def test_other_years_are_excluded(self):
        docs = [_doc("p1", "maintenance", {
            "amount": 300.0, "period_start": "2024-11-01", "period_end": "2025-01-31",
        })]
        self.assertEqual(_maintenance_months_covered(docs, 2025), {1})


class PartialMaintenanceCoverageTests(unittest.TestCase):
    def _docs(self, *maintenance_months):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        for month in maintenance_months:
            docs.append(_doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 250.0, "date": f"2025-{month:02d}-01"},
            ]}))
        return docs

    def _row(self, prop, docs):
        result = _summary(docs, [prop])
        return next(r for r in result["properties"][0]["coverage"] if r["year"] == 2025)

    def test_four_of_twelve_months_reports_partial_not_missing(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        row = self._row(prop, self._docs(1, 2, 3, 4))
        self.assertNotIn("maintenance", row["missing"])
        self.assertEqual(
            row["partial_categories"],
            [{"category": "maintenance", "have": 4, "expect": 12}],
        )

    def test_zero_months_is_still_plain_missing(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        row = self._row(prop, self._docs())
        self.assertIn("maintenance", row["missing"])
        self.assertEqual(row["partial_categories"], [])

    def test_twelve_of_twelve_is_neither_missing_nor_partial(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        row = self._row(prop, self._docs(*range(1, 13)))
        self.assertNotIn("maintenance", row["missing"])
        self.assertEqual(row["partial_categories"], [])

    def test_landed_property_never_reports_a_maintenance_partial(self):
        prop = dict(_prop("p1", "House"), property_type="landed")
        row = self._row(prop, self._docs(1, 2))
        self.assertEqual(row["partial_categories"], [])


class DocumentExceptionCoverageTests(unittest.TestCase):
    def _docs(self):
        return [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]

    def _row(self, prop, exceptions):
        result = _summary(self._docs(), [prop], document_exceptions=exceptions)
        return next(r for r in result["properties"][0]["coverage"] if r["year"] == 2025)

    def test_marked_category_moves_from_missing_to_unavailable(self):
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=True)
        row = self._row(prop, [_doc_exception("p1", 2025, "loan")])
        self.assertNotIn("loan", row["missing"])
        self.assertIn("loan", row["unavailable"])

    def test_unmarked_categories_stay_missing(self):
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=True)
        row = self._row(prop, [_doc_exception("p1", 2025, "loan")])
        self.assertIn("insurance", row["missing"])

    def test_marks_a_granular_tax_label_too(self):
        prop = dict(_prop("p1", "House"), property_type="landed")
        row = self._row(prop, [_doc_exception("p1", 2025, "quit_rent")])
        self.assertNotIn("quit_rent", row["missing"])
        self.assertIn("quit_rent", row["unavailable"])
        self.assertIn("assessment", row["missing"])  # unrelated slot untouched

    def test_other_property_and_year_are_ignored(self):
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=True)
        row = self._row(prop, [
            _doc_exception("p2", 2025, "loan"),
            _doc_exception("p1", 2024, "loan"),
        ])
        self.assertIn("loan", row["missing"])

    def test_marking_maintenance_unavailable_suppresses_a_partial_too(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 250.0, "date": "2025-01-01"},
            ]}),
        ]
        prop = dict(_prop("p1", "Condo"), property_type="strata")
        result = _summary(docs, [prop], document_exceptions=[_doc_exception("p1", 2025, "maintenance")])
        row = next(r for r in result["properties"][0]["coverage"] if r["year"] == 2025)
        self.assertEqual(row["partial_categories"], [])
        self.assertIn("maintenance", row["unavailable"])


class IncompleteYearStatutoryTests(unittest.TestCase):
    def test_complete_year_is_flagged_and_counted(self):
        # A landed, unmortgaged property's full expected list is
        # rental_invoice, assessment, quit_rent, insurance, upkeep — every
        # one needs real evidence for this year to count as complete.
        # rental_invoice matches the lease amount so the total is unchanged;
        # the upkeep line is amount 0.0 so it satisfies the slot (spec
        # never requires an upkeep charge to exist) without moving the
        # expense total.
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": "2025-01"}),
            _doc("p1", "upkeep", {"amount": 0.0, "service_date": "2025-06-01"}),
        ]
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=False)
        docs.append(_doc("p1", "tax", {"subtype": "assessment", "amount": 400.0, "period_year": 2025}))
        docs.append(_doc("p1", "tax", {"subtype": "quit_rent", "amount": 200.0, "period_year": 2025}))
        docs.append(_doc("p1", "insurance", {"premium": 150.0,
                                             "policy_start": "2025-01-01", "policy_end": "2025-12-31"}))
        result = _summary(docs, [prop])
        block = result["properties"][0]
        self.assertTrue(block["complete"])
        self.assertEqual(result["totals"]["statutory_rental_income"], 12000.0 - 750.0)

    def test_incomplete_year_reports_a_provisional_statutory_figure(self):
        # An incomplete year no longer withholds statutory income entirely;
        # it contributes a provisional running figure (received - deductible
        # so far) and is flagged incomplete so the app labels it "Current".
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=False)
        result = _summary(docs, [prop])  # missing assessment, quit_rent, insurance
        block = result["properties"][0]
        self.assertFalse(block["complete"])
        self.assertEqual(result["totals"]["statutory_rental_income"], 12000.0)
        self.assertEqual(block["statutory_contribution"], 12000.0)

    def test_received_and_expenses_are_never_withheld_by_incompleteness(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=False)
        result = _summary(docs, [prop])
        self.assertEqual(result["properties"][0]["received_rent"], 12000.0)

    def test_incompleteness_is_named_in_a_caveat(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=False)
        result = _summary(docs, [prop])
        self.assertTrue(any("provisional" in c for c in result["caveats"]))

    def test_one_incomplete_property_does_not_zero_out_a_complete_one(self):
        complete_docs = [
            _doc("p2", "lease", {"monthly_rent": 500.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p2", "rental_invoice", {"amount": 500.0, "period_month": "2025-01"}),
            _doc("p2", "upkeep", {"amount": 0.0, "service_date": "2025-06-01"}),
            _doc("p2", "tax", {"subtype": "assessment", "amount": 100.0, "period_year": 2025}),
            _doc("p2", "tax", {"subtype": "quit_rent", "amount": 50.0, "period_year": 2025}),
            _doc("p2", "insurance", {"premium": 60.0,
                                     "policy_start": "2025-01-01", "policy_end": "2025-12-31"}),
        ]
        incomplete_docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                                "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        props = [
            dict(_prop("p1", "House 1"), property_type="landed", has_mortgage=False),
            dict(_prop("p2", "House 2"), property_type="landed", has_mortgage=False),
        ]
        result = _summary(incomplete_docs + complete_docs, props)
        # Both properties now contribute: the incomplete p1 provisionally
        # (12000, no deductibles yet) plus the complete p2 (6000 - 210).
        self.assertEqual(result["totals"]["statutory_rental_income"], 12000.0 + (6000.0 - 210.0))

    def test_a_year_marked_unavailable_for_every_remaining_gap_is_complete(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=False)
        exceptions = [
            _doc_exception("p1", 2025, c)
            for c in ("rental_invoice", "assessment", "quit_rent", "insurance", "upkeep")
        ]
        result = _summary(docs, [prop], document_exceptions=exceptions)
        self.assertTrue(result["properties"][0]["complete"])
        self.assertEqual(result["totals"]["statutory_rental_income"], 12000.0)


class RentPaymentStateTests(unittest.TestCase):
    def test_outstanding_is_the_default_state(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House")], payment_exceptions=[_exception("p1", "2025-03")])
        march = next(m for m in result["properties"][0]["units"][0]["months"] if m["month"] == 3)
        self.assertEqual(march["payment_state"], "outstanding")
        self.assertEqual(march["billed_amount"], 1000.0)
        self.assertEqual(march["source"], "unpaid")  # unchanged, Flutter still reads this today
        self.assertEqual(march["amount"], 0.0)  # unchanged

    def test_outstanding_amount_prefers_the_actual_invoice_over_the_lease(self):
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0,
                                 "lease_start": "2025-01-01", "lease_end": "2025-12-31"}),
            _doc("p1", "rental_invoice", {"amount": 1200.0, "period_month": "2025-03"}),
        ]
        result = _summary(docs, [_prop("p1", "House")], payment_exceptions=[_exception("p1", "2025-03")])
        march = next(m for m in result["properties"][0]["units"][0]["months"] if m["month"] == 3)
        self.assertEqual(march["billed_amount"], 1200.0)

    def test_outstanding_rent_is_reported_separately_from_received(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House")],
                           payment_exceptions=[_exception("p1", "2025-03"), _exception("p1", "2025-07")])
        self.assertEqual(result["properties"][0]["outstanding_rent"], 2000.0)
        self.assertEqual(result["totals"]["outstanding_rent"], 2000.0)
        self.assertEqual(result["properties"][0]["received_rent"], 10000.0)

    def test_written_off_is_distinguishable_and_not_counted_as_outstanding(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House")],
                           payment_exceptions=[_exception("p1", "2025-08", state="written_off")])
        august = next(m for m in result["properties"][0]["units"][0]["months"] if m["month"] == 8)
        self.assertEqual(august["payment_state"], "written_off")
        self.assertEqual(result["properties"][0]["outstanding_rent"], 0.0)
        self.assertEqual(result["properties"][0]["received_rent"], 11000.0)

    def test_written_off_note_reads_differently_from_outstanding(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House")],
                           payment_exceptions=[_exception("p1", "2025-08", state="written_off")])
        joined = " ".join(result["caveats"])
        self.assertIn("Written off", joined)
        self.assertNotIn("No payment received for Aug", joined)

    def test_existing_exceptions_with_no_state_key_keep_todays_wording(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        result = _summary(docs, [_prop("p1", "House")],
                           payment_exceptions=[{"property_id": "p1", "unit_id": None, "month": "2025-03"}])
        joined = " ".join(result["caveats"])
        self.assertIn("No payment received for Mar", joined)


class RentRecoveryTests(unittest.TestCase):
    def test_recovery_counts_toward_the_year_it_arrived(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2026-01-01", "lease_end": "2026-12-31"})]
        result = _summary(
            docs, [_prop("p1", "House")], year=2026, today=date(2026, 7, 16),
            rent_recoveries=[_recovery("p1", "2025-08", 3000.0, 2026)],
        )
        # 7 months derived (Jan-Jul, today is mid-Jul 2026 so Jul is in scope) + recovery
        self.assertEqual(result["properties"][0]["received_rent"], 7000.0 + 3000.0)
        self.assertEqual(result["totals"]["received_rent"], 7000.0 + 3000.0)

    def test_recovered_line_is_itemized_and_traceable(self):
        result = _summary(
            [], [_prop("p1", "House")], year=2026, today=date(2026, 7, 16),
            rent_recoveries=[_recovery("p1", "2025-08", 3000.0, 2026)],
        )
        lines = result["properties"][0]["recovered_rent"]
        self.assertEqual(len(lines), 1)
        self.assertEqual(lines[0]["original_month"], "2025-08")
        self.assertEqual(lines[0]["amount"], 3000.0)
        self.assertEqual(lines[0]["label"], "Recovered rent — Aug 2025")

    def test_recovery_does_not_appear_or_change_anything_in_the_original_year(self):
        docs = [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2025-01-01", "lease_end": "2025-12-31"})]
        without = _summary(docs, [_prop("p1", "House")], year=2025)
        with_recovery = _summary(
            docs, [_prop("p1", "House")], year=2025,
            rent_recoveries=[_recovery("p1", "2025-08", 3000.0, 2026)],
        )
        self.assertEqual(without["properties"][0]["received_rent"], with_recovery["properties"][0]["received_rent"])
        self.assertEqual(with_recovery["properties"][0]["recovered_rent"], [])

    def test_recovery_for_a_different_property_is_ignored(self):
        result = _summary(
            [], [_prop("p1", "House")], year=2026, today=date(2026, 7, 16),
            rent_recoveries=[_recovery("p2", "2025-08", 3000.0, 2026)],
        )
        self.assertEqual(result["properties"][0]["recovered_rent"], [])
        self.assertEqual(result["properties"][0]["received_rent"], 0.0)

    def test_recovery_feeds_the_statutory_estimate_like_any_other_receipt(self):
        # A coverage window needs at least one document to anchor a year at
        # all; with zero documents _property_coverage has nothing to walk
        # and the property can never be "complete". A single upkeep receipt
        # both anchors 2026 and satisfies its own slot.
        docs = [_doc("p1", "upkeep", {"amount": 0.0, "service_date": "2026-01-01"})]
        result = _summary(
            docs, [dict(_prop("p1", "House"), property_type="landed", has_mortgage=False)],
            year=2026, today=date(2026, 7, 16),
            rent_recoveries=[_recovery("p1", "2025-08", 3000.0, 2026)],
            document_exceptions=[
                _doc_exception("p1", 2026, c)
                for c in ("rental_invoice", "assessment", "quit_rent", "insurance")
            ],
        )
        self.assertEqual(result["totals"]["statutory_rental_income"], 3000.0)


class TrackFromYearTests(unittest.TestCase):
    def _docs(self):
        return [_doc("p1", "lease", {"monthly_rent": 1000.0,
                                     "lease_start": "2020-01-01",
                                     "lease_end": "2026-12-31"})]

    def test_years_before_track_from_year_are_never_flagged(self):
        prop = dict(_prop("p1", "House"), track_from_year=2023)
        result = _summary(self._docs(), [prop], today=date(2026, 7, 16))
        years = [r["year"] for r in result["properties"][0]["coverage"]]
        self.assertNotIn(2020, years)
        self.assertNotIn(2021, years)
        self.assertNotIn(2022, years)
        self.assertIn(2023, years)
        self.assertIn(2026, years)

    def test_absent_track_from_year_keeps_todays_behaviour(self):
        prop = _prop("p1", "House")
        result = _summary(self._docs(), [prop], today=date(2026, 7, 16))
        years = [r["year"] for r in result["properties"][0]["coverage"]]
        self.assertIn(2020, years)

    def test_track_from_year_never_produces_years_after_today(self):
        prop = dict(_prop("p1", "House"), track_from_year=2030)
        result = _summary(self._docs(), [prop], today=date(2026, 7, 16))
        self.assertEqual(result["properties"][0]["coverage"], [])


class ExpectedRecordCategoriesTests(unittest.TestCase):
    def test_strata_mortgaged_gets_the_land_office_slot_not_specific_subtypes(self):
        prop = dict(_prop("p1", "Condo"), property_type="strata", has_mortgage=True)
        categories = _expected_record_categories(prop)
        self.assertIn("assessment", categories)
        self.assertIn("land_office_tax", categories)
        self.assertIn("loan", categories)
        self.assertIn("maintenance", categories)
        self.assertNotIn("insurance", categories)
        self.assertNotIn("quit_rent", categories)
        self.assertNotIn("rental_invoice", categories)
        self.assertNotIn("upkeep", categories)

    def test_landed_mortgaged_expects_quit_rent_specifically(self):
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=True)
        categories = _expected_record_categories(prop)
        self.assertIn("assessment", categories)
        self.assertIn("quit_rent", categories)
        self.assertIn("insurance", categories)
        self.assertIn("loan", categories)
        self.assertNotIn("maintenance", categories)
        self.assertNotIn("land_office_tax", categories)

    def test_cash_buyer_is_never_expected_to_hold_a_loan_statement(self):
        prop = dict(_prop("p1", "House"), property_type="landed", has_mortgage=False)
        self.assertNotIn("loan", _expected_record_categories(prop))

    def test_unknown_profile_falls_back_to_the_generic_tax_bucket(self):
        prop = _prop("p1", "House")
        categories = _expected_record_categories(prop)
        self.assertIn("tax", categories)
        self.assertNotIn("assessment", categories)
        self.assertNotIn("quit_rent", categories)


from rag.finance.finance_engine import document_tags
from rag.documents.fact_extractor import EXPENSE_SUBTYPE_CATEGORY, EXPENSE_SUBTYPE_RHYTHM


class DocumentTagTests(unittest.TestCase):
    def test_every_expense_subtype_has_exactly_one_rhythm(self):
        self.assertEqual(set(EXPENSE_SUBTYPE_CATEGORY), set(EXPENSE_SUBTYPE_RHYTHM))
        self.assertEqual(set(EXPENSE_SUBTYPE_RHYTHM.values()), {"periodic", "one_off", "ad_hoc"})

    def test_expenses_category_returns_unique_subtypes_with_rhythm(self):
        facts = {"expense_lines": [
            {"subtype": "maintenance", "amount": 100.0},
            {"subtype": "sinking_fund", "amount": 20.0},
            {"subtype": "quit_rent", "amount": 50.0},
        ]}
        tags = document_tags("expenses", facts)
        self.assertEqual(
            {(t["tag"], t["rhythm"]) for t in tags},
            {("maintenance", "periodic"), ("sinking_fund", "periodic"), ("quit_rent", "one_off")},
        )

    def test_expenses_category_dedupes_repeated_subtype(self):
        facts = {"expense_lines": [
            {"subtype": "maintenance", "amount": 100.0, "period_year": 2025},
            {"subtype": "maintenance", "amount": 100.0, "period_year": 2025},
        ]}
        tags = document_tags("expenses", facts)
        self.assertEqual(len(tags), 1)

    def test_tax_category_maps_assessment_subtype_to_assessment_tax_tag(self):
        tags = document_tags("tax", {"subtype": "assessment", "amount": 460.0})
        self.assertEqual(tags, [{"tag": "assessment_tax", "rhythm": "one_off"}])

    def test_tax_category_quit_rent_and_parcel_rent_map_directly(self):
        self.assertEqual(
            document_tags("tax", {"subtype": "quit_rent"}),
            [{"tag": "quit_rent", "rhythm": "one_off"}],
        )
        self.assertEqual(
            document_tags("tax", {"subtype": "parcel_rent"}),
            [{"tag": "parcel_rent", "rhythm": "one_off"}],
        )

    def test_tax_category_unknown_subtype_returns_no_tags(self):
        self.assertEqual(document_tags("tax", {"amount": 100.0}), [])

    def test_loan_category_interest_statement_maps_to_loan_interest(self):
        tags = document_tags("loan", {"subtype": "interest_statement", "interest_paid": 1000.0})
        self.assertEqual(tags, [{"tag": "loan_interest", "rhythm": "one_off"}])

    def test_loan_category_agreement_subtype_returns_no_tags(self):
        self.assertEqual(document_tags("loan", {"subtype": "agreement"}), [])

    def test_fixed_single_subtype_categories(self):
        self.assertEqual(document_tags("maintenance", {"amount": 300.0}),
                          [{"tag": "maintenance", "rhythm": "periodic"}])
        self.assertEqual(document_tags("insurance", {"premium": 500.0}),
                          [{"tag": "insurance_premium", "rhythm": "one_off"}])
        self.assertEqual(document_tags("upkeep", {"amount": 80.0}),
                          [{"tag": "upkeep", "rhythm": "ad_hoc"}])

    def test_untagged_categories_return_no_tags(self):
        self.assertEqual(document_tags("other", {"amount": 1.0}), [])
        self.assertEqual(document_tags("lease", {"monthly_rent": 1500.0}), [])
        self.assertEqual(document_tags("rental_invoice", {"amount": 1500.0}), [])

    def test_no_facts_returns_no_tags(self):
        self.assertEqual(document_tags("expenses", None), [])
        self.assertEqual(document_tags("tax", None), [])


class ExpenseLineDedupTests(unittest.TestCase):
    """A duplicate charge must be counted once. The same bill uploaded twice
    (or a scanner backfill line that also came through the LLM) inflates both
    the visible list and — because the app never recomputes — the net
    contribution. Deduping in the fold keeps lines, direct_expenses and
    contribution consistent, while genuinely distinct installments/payments
    stay separate."""

    def test_exact_duplicate_line_from_two_uploads_counted_once(self):
        docs = [
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 764.0, "date": "2025-02-01"},
            ]}),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 764.0, "date": "2025-02-01"},
            ]}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        lines = result["properties"][0]["expense_lines"]
        maint = [l for l in lines if l["subtype"] == "maintenance"]
        self.assertEqual(len(maint), 1)
        self.assertEqual(result["totals"]["direct_expenses"], 764.0)

    def test_distinct_installments_same_year_same_amount_are_kept(self):
        # Two semi-annual assessment installments of equal amount differ only
        # by their installment marker in the description — both are real.
        docs = [
            _doc("p1", "tax", {"subtype": "assessment", "amount": 434.56,
                               "period_year": 2025, "installment": "1 of 2"}),
            _doc("p1", "tax", {"subtype": "assessment", "amount": 434.56,
                               "period_year": 2025, "installment": "2 of 2"}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        tax_lines = [l for l in result["properties"][0]["expense_lines"]
                     if l["category"] == "tax"]
        self.assertEqual(len(tax_lines), 2)
        self.assertEqual(result["totals"]["direct_expenses"], 869.12)

    def test_same_charge_on_different_dates_is_kept(self):
        docs = [
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "assessment_tax", "amount": 434.56, "date": "2025-02-15"},
                {"subtype": "assessment_tax", "amount": 434.56, "date": "2025-08-15"},
            ]}),
        ]
        result = _summary(docs, [_prop("p1", "House")])
        tax_lines = [l for l in result["properties"][0]["expense_lines"]
                     if l["subtype"] == "assessment_tax"]
        self.assertEqual(len(tax_lines), 2)


class AnnualCollapseDedupTests(unittest.TestCase):
    def test_fire_insurance_on_two_monthly_statements_counts_once(self):
        from rag.finance.finance_engine import _dedup_expense_lines
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
        from rag.finance.finance_engine import _dedup_expense_lines
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
        from rag.finance.finance_engine import _dedup_expense_lines
        lines = [
            {"unit_id": None, "category": "tax", "subtype": "assessment_tax",
             "description": "Assessment tax (1/2)", "date": "2025", "amount": 400.0,
             "deductible": True, "paid_by_landlord": True},
            {"unit_id": None, "category": "tax", "subtype": "assessment_tax",
             "description": "Assessment tax (2/2)", "date": "2025", "amount": 400.0,
             "deductible": True, "paid_by_landlord": True},
        ]
        self.assertEqual(len(_dedup_expense_lines(lines)), 2)


class LoanLineDedupTests(unittest.TestCase):
    """Loan statements have no 'reprinted on every monthly statement' problem
    the way annual strata/insurance charges do — each is a distinct uploaded
    document. Two different statements in the same year can legitimately
    carry equal principal (or interest); they must both survive dedup."""

    def test_two_distinct_loan_statements_same_year_equal_amount_both_kept(self):
        from rag.finance.finance_engine import _dedup_expense_lines
        lines = [
            {"doc_id": "doc-jan", "unit_id": "u1", "category": "loan",
             "subtype": "loan_principal", "description": "Loan principal",
             "date": "2025", "amount": 800.0,
             "deductible": False, "paid_by_landlord": True},
            {"doc_id": "doc-feb", "unit_id": "u1", "category": "loan",
             "subtype": "loan_principal", "description": "Loan principal",
             "date": "2025", "amount": 800.0,
             "deductible": False, "paid_by_landlord": True},
        ]
        self.assertEqual(len(_dedup_expense_lines(lines)), 2)

    def test_two_distinct_loan_interest_lines_same_year_equal_amount_both_kept(self):
        from rag.finance.finance_engine import _dedup_expense_lines
        lines = [
            {"doc_id": "doc-jan", "unit_id": "u1", "category": "loan",
             "subtype": "interest_statement", "description": "Loan interest",
             "date": "2025", "amount": 500.0,
             "deductible": True, "paid_by_landlord": True},
            {"doc_id": "doc-feb", "unit_id": "u1", "category": "loan",
             "subtype": "interest_statement", "description": "Loan interest",
             "date": "2025", "amount": 500.0,
             "deductible": True, "paid_by_landlord": True},
        ]
        self.assertEqual(len(_dedup_expense_lines(lines)), 2)

    def test_same_document_loan_line_reprocessed_still_collapses(self):
        # Same doc_id, same charge -> still an exact duplicate (e.g. a
        # scanner backfill line that also arrived through the LLM). The
        # loan-specific discriminator must not weaken this contract.
        from rag.finance.finance_engine import _dedup_expense_lines
        lines = [
            {"doc_id": "doc-jan", "unit_id": "u1", "category": "loan",
             "subtype": "loan_principal", "description": "Loan principal",
             "date": "2025", "amount": 800.0,
             "deductible": False, "paid_by_landlord": True},
            {"doc_id": "doc-jan", "unit_id": "u1", "category": "loan",
             "subtype": "loan_principal", "description": "Loan principal",
             "date": "2025", "amount": 800.0,
             "deductible": False, "paid_by_landlord": True},
        ]
        self.assertEqual(len(_dedup_expense_lines(lines)), 1)


class PaidByLandlordFlagTests(unittest.TestCase):
    def _lines(self, docs, utilities_paid_by=None):
        from rag.finance.finance_engine import _expense_lines
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


class TwoTierTotalsTests(unittest.TestCase):
    def test_net_pl_includes_principal_and_penalty_statutory_excludes(self):
        # One fully-rented whole-property scope, RM 1000/mo actual = 12000 received.
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
        # No profile is set, so every FINANCE_CATEGORIES slot is expected;
        # mark the ones this fixture never intended to exercise unavailable
        # so completeness doesn't withhold statutory_contribution (the
        # maintenance line here has no `date`, only period_year, so it would
        # otherwise read as a partial-months gap too).
        exceptions = [_doc_exception("p1", 2025, c) for c in ("tax", "upkeep", "insurance", "maintenance")]
        result = _summary(docs, [_prop("p1", "House")], year=2025, today=date(2026, 1, 1),
                           document_exceptions=exceptions)
        totals = result["totals"]
        # Statutory-deductible = maintenance 3000 + interest 5000 = 8000.
        # Landlord-paid = 3000 + 200 + 5000 + 8000 = 16200.
        self.assertEqual(totals["direct_expenses"], 8000.0)     # statutory set
        self.assertEqual(totals["landlord_expenses"], 16200.0)  # all cash out, differs from direct_expenses
        self.assertEqual(totals["net_pl"], 12000.0 - 16200.0)   # -4200 (all cash out)
        prop = result["properties"][0]
        self.assertTrue(prop["complete"])
        self.assertEqual(prop["net_pl"], 12000.0 - 16200.0)
        self.assertEqual(prop["statutory_contribution"], 12000.0 - 8000.0)

    def test_unit_contribution_and_statutory_contribution_diverge_on_mismatched_flags(self):
        # Unit u1 fully rented for the year: 12 x 1000 = 12000 gross.
        # Two expense lines on that unit diverge in their flags:
        #   maintenance 3000 -> paid_by_landlord=True AND deductible=True
        #   late_penalty 200 -> paid_by_landlord=True but deductible=False
        # so the unit's Net P/L basis (contribution) and statutory basis
        # (statutory_contribution) must land on different figures — a
        # flag-swap at the unit level would make them equal or transpose them.
        docs = [
            _doc("p1", "rental_invoice", {"amount": 1000.0, "period_month": f"2025-{m:02d}"}, unit_id="u1")
            for m in range(1, 13)
        ] + [
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 3000.0, "period_year": 2025},
                {"subtype": "late_penalty", "amount": 200.0, "period_year": 2025},
            ]}, unit_id="u1"),
        ]
        units = {"p1": [{"unit_id": "u1", "label": "Unit A"}]}
        result = _summary(docs, [_prop("p1", "House")], units=units, year=2025, today=date(2026, 1, 1))
        unit = result["properties"][0]["units"][0]
        self.assertEqual(unit["label"], "Unit A")
        # contribution (Net P/L basis): gross - landlord-paid = 12000 - (3000 + 200)
        self.assertEqual(unit["contribution"], 8800.0)
        # statutory_contribution: gross - deductible = 12000 - 3000
        self.assertEqual(unit["statutory_contribution"], 9000.0)
        self.assertNotEqual(unit["contribution"], unit["statutory_contribution"])


class ManualLoanEntryEngineTests(unittest.TestCase):
    def test_annual_entry_becomes_interest_and_principal_lines(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 3000.0, "cadence": "annual"},
            ],
        )
        lines = summary["properties"][0]["expense_lines"]
        by_subtype = {l["subtype"]: l for l in lines}
        self.assertEqual(by_subtype["interest_statement"]["amount"], 5000.0)
        self.assertTrue(by_subtype["interest_statement"]["deductible"])
        self.assertTrue(by_subtype["interest_statement"]["paid_by_landlord"])
        self.assertEqual(by_subtype["loan_principal"]["amount"], 3000.0)
        self.assertFalse(by_subtype["loan_principal"]["deductible"])
        self.assertTrue(by_subtype["loan_principal"]["paid_by_landlord"])

    def test_zero_principal_emits_no_principal_line(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        subtypes = {l["subtype"] for l in summary["properties"][0]["expense_lines"]}
        self.assertIn("interest_statement", subtypes)
        self.assertNotIn("loan_principal", subtypes)

    def test_manual_and_uploaded_interest_both_count(self):
        summary = _summary(
            documents=[_doc("p1", "loan", {"subtype": "interest_statement",
                                           "interest_paid": 4000.0, "period_year": 2025})],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        interest = [l for l in summary["properties"][0]["expense_lines"]
                    if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in interest), 9000.0)

    def test_monthly_entries_each_produce_a_line(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": 1, "interest_paid": 500.0,
                 "principal_paid": 0.0, "cadence": "monthly"},
                {"property_id": "p1", "year": 2025, "month": 2, "interest_paid": 500.0,
                 "principal_paid": 0.0, "cadence": "monthly"},
            ],
        )
        interest = [l for l in summary["properties"][0]["expense_lines"]
                    if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in interest), 1000.0)

    def test_entry_for_a_different_year_is_ignored(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            year=2025,
            manual_loan_entries=[
                {"property_id": "p1", "year": 2024, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        self.assertEqual(summary["properties"][0]["expense_lines"], [])

    def test_entry_lands_in_its_units_contribution(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "Block")],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        units = {u["unit_id"]: u for u in summary["properties"][0]["units"]}
        # u1's statutory contribution is reduced by the 5000 deductible interest; u2 untouched.
        u1_loan = [l for l in units["u1"]["expense_lines"] if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in u1_loan), 5000.0)
        self.assertTrue(all(l["unit_id"] == "u1" for l in u1_loan))
        u2_loan = [l for l in units["u2"]["expense_lines"] if l["subtype"] == "interest_statement"]
        self.assertEqual(u2_loan, [])

    def test_two_units_same_period_amount_stay_distinct(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "Block")],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
                {"property_id": "p1", "unit_id": "u2", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        interest = [l for l in summary["properties"][0]["expense_lines"]
                    if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in interest), 2000.0)


class LoanCompletenessTests(unittest.TestCase):
    def _prop_manual(self, cadence="annual"):
        return {"property_id": "p1", "name": "Block", "ownership_share": 1.0,
                "has_mortgage": True, "loan_input_method": "manual",
                "loan_input_cadence": cadence}

    def test_incomplete_when_a_unit_has_no_figures(self):
        summary = _summary(
            documents=[], properties=[self._prop_manual()],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        block = summary["properties"][0]
        self.assertTrue(block["manual_loan_incomplete"])
        status = {u["unit_id"]: u["loan_status"] for u in block["units"]}
        self.assertEqual(status["u1"], "complete")
        self.assertEqual(status["u2"], "incomplete")

    def test_complete_when_every_unit_resolved(self):
        summary = _summary(
            documents=[], properties=[self._prop_manual()],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
            unit_loan_exemptions=[{"property_id": "p1", "unit_id": "u2"}],
        )
        block = summary["properties"][0]
        self.assertFalse(block["manual_loan_incomplete"])
        status = {u["unit_id"]: u["loan_status"] for u in block["units"]}
        self.assertEqual(status["u2"], "no_loan")

    def test_monthly_cadence_needs_all_in_scope_months(self):
        # Past year 2024 (today defaults to 2026-07-16): all 12 months required.
        entries = [{"property_id": "p1", "unit_id": "u1", "year": 2024, "month": m,
                    "interest_paid": 100.0, "principal_paid": 0.0, "cadence": "monthly"}
                   for m in range(1, 12)]  # only 11 of 12
        summary = _summary(
            documents=[], properties=[self._prop_manual("monthly")], year=2024,
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
            manual_loan_entries=entries,
        )
        self.assertTrue(summary["properties"][0]["manual_loan_incomplete"])

    def test_whole_property_scope_complete_when_manual_entry_present(self):
        summary = _summary(
            documents=[], properties=[self._prop_manual()],
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": None, "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        block = summary["properties"][0]
        self.assertFalse(block["manual_loan_incomplete"])
        whole = next(u for u in block["units"] if u["unit_id"] is None)
        self.assertEqual(whole["loan_status"], "complete")

    def test_whole_property_scope_incomplete_when_no_figures(self):
        summary = _summary(
            documents=[], properties=[self._prop_manual()],
        )
        block = summary["properties"][0]
        self.assertTrue(block["manual_loan_incomplete"])
        whole = next(u for u in block["units"] if u["unit_id"] is None)
        self.assertEqual(whole["loan_status"], "incomplete")

    def test_not_evaluated_for_upload_method(self):
        prop = self._prop_manual()
        prop["loan_input_method"] = "upload"
        summary = _summary(
            documents=[], properties=[prop],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
        )
        block = summary["properties"][0]
        self.assertFalse(block["manual_loan_incomplete"])
        self.assertIsNone(block["units"][0]["loan_status"])
