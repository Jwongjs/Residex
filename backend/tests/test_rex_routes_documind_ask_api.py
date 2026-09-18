import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from api.auth import verify_firebase_token
from models.documind_models import AskResponse


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

    def test_documind_ask_returns_422_for_invalid_payload(self):
        response = self.client.post(
            "/api/rex/documind/ask",
            json={
                "property_id": "property-1",
                # Missing required 'question' field
            },
        )

        self.assertEqual(response.status_code, 422)


if __name__ == "__main__":
    unittest.main()