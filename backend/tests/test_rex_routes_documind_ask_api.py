import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from api.auth import verify_firebase_token
from models.documind_models import AskResponse, UnitOption


class DocuMindAskApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        app.dependency_overrides[verify_firebase_token] = lambda: {"uid": "landlord_123"}

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_documind_ask_returns_200_with_mocked_service_response(self):
        mocked_response = AskResponse(
            answer="Sure — your warranty covers compressor replacement.",
            confidence=0.92,
            citations=[],
            property_name="Pine Residence",
            searched_categories=["warranty"],
            category_filter_mode="explicit",
            session_id="sess-1",
            conversation_turn=2,
            user_action_required=False,
            predicted_categories=["warranty"],
            action_reason="User selected explicit category",
        )

        with patch("api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)) as mocked_ask:
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "property_id": "property-1",
                    "question": "What does my warranty cover?",
                    "categories": ["warranty"],
                    "session_id": "sess-1",
                    "conversation_turn": 2,
                },
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["answer"], mocked_response.answer)
        self.assertEqual(data["session_id"], "sess-1")
        self.assertEqual(data["searched_categories"], ["warranty"])
        mocked_ask.assert_awaited_once()

    def test_documind_ask_passes_user_action_to_service(self):
        mocked_response = AskResponse(
            answer="Confirmed. I will proceed with lease documents.",
            confidence=0.88,
            citations=[],
            property_name="Maple Residency",
            searched_categories=["lease"],
            category_filter_mode="clarification_selected",
            session_id="sess-99",
            conversation_turn=3,
            user_action_required=False,
            predicted_categories=["lease"],
            action_reason="Confirmation accepted",
        )

        with patch("api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)) as mocked_ask:
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "property_id": "property-1",
                    "question": "yes proceed",
                    "session_id": "sess-99",
                    "conversation_turn": 3,
                    "user_action": "confirm",
                },
            )

            called_payload = mocked_ask.await_args.args[0]

        self.assertEqual(response.status_code, 200)
        self.assertEqual(called_payload.session_id, "sess-99")
        self.assertEqual(called_payload.user_action, "confirm")
        self.assertEqual(called_payload.question, "yes proceed")

    def test_documind_ask_returns_422_for_invalid_payload(self):
        response = self.client.post(
            "/api/rex/documind/ask",
            json={
                "property_id": "property-1",
                # Missing required 'question' field
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_documind_ask_serializes_unit_clarification_checkpoint(self):
        mocked_response = AskResponse(
            answer="That question matches documents from Unit A and Unit B. Which unit do you mean?",
            confidence=0.6,
            citations=[],
            property_name="Maple Residency",
            searched_categories=[],
            category_filter_mode="all",
            session_id="sess-42",
            conversation_turn=1,
            user_action_required=True,
            needs_unit_clarification=True,
            unit_options=[
                UnitOption(unit_id="unit-a", unit_label="Unit A"),
                UnitOption(unit_id="unit-b", unit_label="Unit B"),
                UnitOption(unit_id="all", unit_label="All units"),
            ],
        )

        with patch("api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)):
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "property_id": "property-1",
                    "question": "when does the lease expire?",
                },
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["needs_unit_clarification"])
        self.assertEqual(
            [option["unit_id"] for option in data["unit_options"]],
            ["unit-a", "unit-b", "all"],
        )
        self.assertTrue(data["user_action_required"])
        self.assertEqual(data["citations"], [])


if __name__ == "__main__":
    unittest.main()