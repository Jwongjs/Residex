import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from models.documind_models import FinanceSummaryResponse, FinanceTotals, PropertyFinance, YearCoverage


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

    def test_set_payment_exception_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.set_payment_exception",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": None, "month": "2025-03", "reason": "late"}),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/payment-exception",
                json={"landlord_id": "l1", "property_id": "p1", "month": "2025-03", "reason": "late"},
            )
            call_kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["month"], "2025-03")
        self.assertEqual(call_kwargs["landlord_id"], "l1")
        self.assertEqual(call_kwargs["month"], "2025-03")

    def test_set_payment_exception_bad_month_returns_400(self):
        with patch(
            "api.rex_routes.documind_service.set_payment_exception",
            new=AsyncMock(side_effect=ValueError("month must be formatted YYYY-MM")),
        ):
            response = self.client.put(
                "/api/rex/documind/finance/payment-exception",
                json={"landlord_id": "l1", "property_id": "p1", "month": "March"},
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
                params={"landlord_id": "l1", "property_id": "p1", "month": "2025-03"},
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
                params={"landlord_id": "landlord-1", "year": 2026},
            )
        body = response.json()
        self.assertEqual(
            body["properties"][0]["coverage"],
            [{"year": 2024, "missing": ["tax", "insurance"]}],
        )
