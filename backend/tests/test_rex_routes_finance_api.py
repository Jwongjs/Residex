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
