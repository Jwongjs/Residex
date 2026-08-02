import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

from main import app
from api.auth import verify_firebase_token
from models.documind_models import (
    ExpenseLine,
    FinanceSummaryResponse,
    FinanceTotals,
    PropertyFinance,
    UnitFinance,
    YearCoverage,
)


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
        app.dependency_overrides[verify_firebase_token] = lambda: {"uid": "landlord_123"}

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_finance_summary_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.get_finance_summary",
            new=AsyncMock(return_value=_fake_summary()),
        ) as mocked:
            response = self.client.get(
                "/api/rex/documind/finance/summary",
                params={"year": 2025},
            )
            call_args = mocked.await_args.args

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["totals"]["statutory_rental_income"], 60106.58)
        self.assertEqual(body["totals"]["statutory_note"], "Estimate — for your tax agent")
        self.assertEqual(call_args, ("landlord_123", 2025))  # token uid, not the wire value ("landlord-1") sent above

    def test_finance_summary_requires_year(self):
        response = self.client.get(
            "/api/rex/documind/finance/summary",
            params={},
        )
        self.assertEqual(response.status_code, 422)

    def test_set_payment_exception_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.set_payment_exception",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": None, "month": "2025-03", "reason": "late"}),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/payment-exception",
                json={"property_id": "p1", "month": "2025-03", "reason": "late"},
            )
            call_kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["month"], "2025-03")
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not the wire value ("l1") sent above
        self.assertEqual(call_kwargs["month"], "2025-03")

    def test_set_payment_exception_forwards_state(self):
        with patch(
            "api.rex_routes.documind_service.set_payment_exception",
            new=AsyncMock(return_value={
                "property_id": "p1", "unit_id": None, "month": "2025-08",
                "reason": None, "state": "written_off",
            }),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/payment-exception",
                json={
                    "property_id": "p1",
                    "month": "2025-08", "state": "written_off",
                },
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["state"], "written_off")
        self.assertEqual(kwargs["state"], "written_off")

    def test_set_payment_exception_bad_month_returns_400(self):
        with patch(
            "api.rex_routes.documind_service.set_payment_exception",
            new=AsyncMock(side_effect=ValueError("month must be formatted YYYY-MM")),
        ):
            response = self.client.put(
                "/api/rex/documind/finance/payment-exception",
                json={"property_id": "p1", "month": "March"},
            )
        self.assertEqual(response.status_code, 400)

    def test_clear_payment_exception_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.clear_payment_exception",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": None, "month": "2025-03"}),
        ) as mocked:
            response = self.client.request(
                "DELETE",
                "/api/rex/documind/finance/payment-exception",
                params={"property_id": "p1", "month": "2025-03"},
            )
            call_kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(call_kwargs["property_id"], "p1")

    def test_finance_summary_serializes_coverage(self):
        summary = FinanceSummaryResponse(
            year=2026,
            totals=FinanceTotals(
                received_rent=0.0, derived_rent=0.0, direct_expenses=0.0,
                net_pl=0.0, statutory_rental_income=0.0,
                statutory_note="Estimate — for your tax agent",
            ),
            expense_breakdown={},
            properties=[PropertyFinance(
                property_id="p1", name="House",
                received_rent=0.0, derived_rent=0.0, direct_expenses=0.0,
                rental_income_or_loss=0.0,
                net_pl=0.0,
                units=[],
                expense_lines=[],
                property_expense_lines=[],
                coverage=[YearCoverage(year=2024, missing=["tax", "insurance"])],
            )],
            caveats=[],
            missing_categories={},
        )
        with patch(
            "api.rex_routes.documind_service.get_finance_summary",
            new=AsyncMock(return_value=summary),
        ):
            response = self.client.get(
                "/api/rex/documind/finance/summary",
                params={"year": 2026},
            )
        body = response.json()
        self.assertEqual(
            body["properties"][0]["coverage"],
            [{"year": 2024, "missing": ["tax", "insurance"], "partial_installments": [],
              "partial_categories": [], "unavailable": []}],
        )

    def test_finance_summary_exposes_two_tier_fields(self):
        summary = FinanceSummaryResponse(
            year=2025,
            totals=FinanceTotals(
                received_rent=0.0, derived_rent=0.0, direct_expenses=0.0,
                net_pl=0.0, statutory_rental_income=0.0,
                statutory_note="Estimate — for your tax agent",
            ),
            expense_breakdown={},
            properties=[PropertyFinance(
                property_id="p1", name="House",
                received_rent=0.0, derived_rent=0.0, direct_expenses=0.0,
                rental_income_or_loss=100.0,
                net_pl=100.0,
                statutory_contribution=80.0,
                units=[UnitFinance(
                    unit_id="u1", label="Unit 1", rented_months=12,
                    contribution=100.0, statutory_contribution=80.0,
                    months=[],
                )],
                expense_lines=[ExpenseLine(
                    doc_id="d1", category="utilities", amount=20.0,
                    paid_by_landlord=False,
                )],
                property_expense_lines=[],
            )],
            caveats=[],
            missing_categories={},
        )
        with patch(
            "api.rex_routes.documind_service.get_finance_summary",
            new=AsyncMock(return_value=summary),
        ):
            response = self.client.get(
                "/api/rex/documind/finance/summary",
                params={"year": 2025},
            )

        self.assertEqual(response.status_code, 200)
        prop = response.json()["properties"][0]
        self.assertIn("net_pl", prop)
        self.assertIn("statutory_contribution", prop)
        self.assertIn("paid_by_landlord", prop["expense_lines"][0])
        self.assertIn("statutory_contribution", prop["units"][0])
        self.assertEqual(prop["net_pl"], 100.0)
        self.assertEqual(prop["statutory_contribution"], 80.0)
        self.assertEqual(prop["expense_lines"][0]["paid_by_landlord"], False)
        self.assertEqual(prop["units"][0]["statutory_contribution"], 80.0)

    def test_set_document_unavailable_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.set_document_unavailable",
            new=AsyncMock(return_value={"property_id": "p1", "year": 2025, "category": "loan"}),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/document-exception",
                json={"property_id": "p1", "year": 2025, "category": "loan"},
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["category"], "loan")
        self.assertEqual(kwargs["year"], 2025)

    def test_clear_document_unavailable_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.clear_document_unavailable",
            new=AsyncMock(return_value={"property_id": "p1", "year": 2025, "category": "loan"}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/document-exception",
                params={"property_id": "p1", "year": 2025, "category": "loan"},
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["property_id"], "p1")

    def test_record_rent_recovery_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.record_rent_recovery",
            new=AsyncMock(return_value={
                "property_id": "p1", "unit_id": None, "original_month": "2025-08",
                "amount": 3000.0, "received_year": 2026,
            }),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/rent-recovery",
                json={
                    "property_id": "p1",
                    "original_month": "2025-08", "amount": 3000.0, "received_year": 2026,
                },
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["amount"], 3000.0)
        self.assertEqual(kwargs["received_year"], 2026)

    def test_clear_rent_recovery_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.clear_rent_recovery",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": None, "original_month": "2025-08"}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/rent-recovery",
                params={"property_id": "p1", "original_month": "2025-08"},
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["property_id"], "p1")

    def test_record_manual_loan_entry_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.record_manual_loan_entry",
            new=AsyncMock(return_value={
                "property_id": "p1", "year": 2025, "month": None,
                "interest_paid": 5000.0, "principal_paid": 3000.0, "cadence": "annual",
            }),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/manual-loan-entry",
                json={
                    "property_id": "p1", "year": 2025,
                    "cadence": "annual", "interest_paid": 5000.0, "principal_paid": 3000.0,
                },
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["interest_paid"], 5000.0)
        self.assertEqual(kwargs["cadence"], "annual")

    def test_record_manual_loan_entry_monthly_without_month_is_422(self):
        response = self.client.put(
            "/api/rex/documind/finance/manual-loan-entry",
            json={
                "property_id": "p1", "year": 2025,
                "cadence": "monthly", "interest_paid": 500.0, "principal_paid": 0.0,
            },
        )
        self.assertEqual(response.status_code, 422)

    def test_record_manual_loan_entry_negative_amount_is_422(self):
        response = self.client.put(
            "/api/rex/documind/finance/manual-loan-entry",
            json={
                "property_id": "p1", "year": 2025,
                "cadence": "annual", "interest_paid": -1.0, "principal_paid": 0.0,
            },
        )
        self.assertEqual(response.status_code, 422)

    def test_delete_manual_loan_entry_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.delete_manual_loan_entry",
            new=AsyncMock(return_value={"property_id": "p1", "year": 2025, "month": None}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/manual-loan-entry",
                params={"property_id": "p1", "year": 2025},
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["property_id"], "p1")

    def test_record_manual_loan_entry_forwards_unit_id(self):
        with patch(
            "api.rex_routes.documind_service.record_manual_loan_entry",
            new=AsyncMock(return_value={
                "property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual",
            }),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/manual-loan-entry",
                json={"property_id": "p1", "unit_id": "u1", "year": 2025,
                      "cadence": "annual", "interest_paid": 5000.0, "principal_paid": 0.0},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["unit_id"], "u1")
        self.assertEqual(response.json()["unit_id"], "u1")

    def test_delete_manual_loan_entry_forwards_unit_id(self):
        with patch(
            "api.rex_routes.documind_service.delete_manual_loan_entry",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/manual-loan-entry",
                params={"property_id": "p1", "unit_id": "u1", "year": 2025},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["unit_id"], "u1")

    def test_list_manual_loan_entries_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.list_manual_loan_entries",
            new=MagicMock(return_value=[{
                "property_id": "p1", "year": 2025, "month": None,
                "interest_paid": 5000.0, "principal_paid": 3000.0, "cadence": "annual",
            }]),
        ):
            response = self.client.get(
                "/api/rex/documind/finance/manual-loan-entry",
                params={"property_id": "p1", "year": 2025},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()["entries"]), 1)
        self.assertEqual(response.json()["entries"][0]["interest_paid"], 5000.0)

    def test_set_unit_loan_exemption_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.set_unit_loan_exemption",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": "u1"}),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/unit-loan-exemption",
                json={"property_id": "p1", "unit_id": "u1"},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["unit_id"], "u1")

    def test_clear_unit_loan_exemption_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.clear_unit_loan_exemption",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": "u1"}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/unit-loan-exemption",
                params={"property_id": "p1", "unit_id": "u1"},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["property_id"], "p1")
