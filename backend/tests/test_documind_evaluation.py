import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from api.auth import verify_firebase_token
from models.documind_models import AskResponse, Citation, UnitOption


class DocuMindStructuralEvaluationTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        app.dependency_overrides[verify_firebase_token] = lambda: {"uid": "landlord_123"}

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_happy_path_with_citations(self):
        """Test successful response with populated citations and relevance scores."""
        citations = [
            Citation(
                doc_id="doc-1",
                filename="warranty-2023.pdf",
                category="warranty",
                page=3,
                snippet="The compressor replacement is covered under the extended warranty plan for 5 years.",
                score=0.89,
            ),
            Citation(
                doc_id="doc-2",
                filename="lease-clause-hvac.pdf",
                category="lease",
                page=12,
                snippet="Tenant is responsible for routine maintenance only; landlord covers major repairs.",
                score=0.76,
            ),
        ]

        mocked_response = AskResponse(
            answer="Yes, the compressor replacement is covered under the extended warranty plan for 5 years.",
            confidence=0.87,
            citations=citations,
            property_name="Oakwood Apartments",
            searched_categories=["warranty", "lease"],
            category_filter_mode="explicit",
            session_id="sess-eval-1",
            conversation_turn=1,
            user_action_required=False,
            predicted_categories=["warranty"],
            action_reason="User selected warranty category",
        )

        with patch(
            "api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)
        ) as mocked_ask:
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "property_id": "property-eval-1",
                    "question": "Is compressor replacement covered?",
                    "categories": ["warranty"],
                    "session_id": "sess-eval-1",
                    "conversation_turn": 1,
                },
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["answer"], mocked_response.answer)
        self.assertEqual(data["confidence"], 0.87)
        self.assertEqual(len(data["citations"]), 2)

        # Assert all citations have required fields and valid scores
        for citation in data["citations"]:
            self.assertIn("doc_id", citation)
            self.assertIn("filename", citation)
            self.assertIn("category", citation)
            self.assertIn("snippet", citation)
            self.assertIn("score", citation)
            self.assertIsInstance(citation["score"], float)
            self.assertGreaterEqual(citation["score"], 0.0)
            self.assertLessEqual(citation["score"], 1.0)

        mocked_ask.assert_awaited_once()

    def test_no_results_path(self):
        """Test response when no relevant documents are found."""
        mocked_response = AskResponse(
            answer="I couldn't find relevant information about that topic in the property documents.",
            confidence=0.0,
            citations=[],
            property_name="Oakwood Apartments",
            searched_categories=[],
            category_filter_mode="all",
            session_id="sess-eval-2",
            conversation_turn=1,
            user_action_required=False,
            predicted_categories=[],
            action_reason="No matching documents found",
        )

        with patch(
            "api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)
        ) as mocked_ask:
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "property_id": "property-eval-2",
                    "question": "Tell me about time travel regulations?",
                    "session_id": "sess-eval-2",
                    "conversation_turn": 1,
                },
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data["citations"]), 0)
        self.assertEqual(data["confidence"], 0.0)
        self.assertIn("couldn't find", data["answer"].lower())

        mocked_ask.assert_awaited_once()

    def test_category_filter_round_trip(self):
        """Test that category filters are passed through to the service layer."""
        mocked_response = AskResponse(
            answer="The lease specifies maintenance responsibilities.",
            confidence=0.85,
            citations=[],
            property_name="Oakwood Apartments",
            searched_categories=["lease", "warranty"],
            category_filter_mode="explicit",
            session_id="sess-eval-3",
            conversation_turn=1,
            user_action_required=False,
            predicted_categories=["lease", "warranty"],
            action_reason="User specified categories",
        )

        with patch(
            "api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)
        ) as mocked_ask:
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "property_id": "property-eval-3",
                    "question": "What are my maintenance responsibilities?",
                    "categories": ["lease", "warranty"],
                    "session_id": "sess-eval-3",
                    "conversation_turn": 1,
                },
            )

            # Verify the categories were passed to the service
            called_payload = mocked_ask.await_args.args[0]
            called_landlord_id = mocked_ask.await_args.args[1]

        self.assertEqual(response.status_code, 200)
        self.assertEqual(called_payload.categories, ["lease", "warranty"])
        self.assertEqual(called_payload.question, "What are my maintenance responsibilities?")
        self.assertEqual(called_landlord_id, "landlord_123")  # token uid; landlord_id is no longer part of the payload
        self.assertEqual(called_payload.property_id, "property-eval-3")

    def test_invalid_payload_missing_question(self):
        """Test that missing required field 'question' returns 422 validation error."""
        response = self.client.post(
            "/api/rex/documind/ask",
            json={
                "property_id": "property-eval-4",
                # Missing required 'question' field
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_multi_unit_ambiguity_checkpoint(self):
        """Multi-unit ambiguity: with no unit filter set, a question matching
        two units' documents must return a unit checkpoint (no blended
        answer, no citations) whose options end with the 'all' sentinel."""
        mocked_response = AskResponse(
            answer="That question matches documents from Unit A and Unit B. Which unit do you mean?",
            confidence=0.6,
            citations=[],
            property_name="Oakwood Apartments",
            searched_categories=["lease"],
            category_filter_mode="auto",
            session_id="sess-eval-5",
            conversation_turn=1,
            user_action_required=True,
            needs_unit_clarification=True,
            unit_options=[
                UnitOption(unit_id="unit-a", unit_label="Unit A"),
                UnitOption(unit_id="unit-b", unit_label="Unit B"),
                UnitOption(unit_id="all", unit_label="All units"),
            ],
            predicted_categories=["lease"],
            action_reason="Retrieved documents span multiple units",
        )

        with patch(
            "api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)
        ) as mocked_ask:
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "property_id": "property-eval-5",
                    "question": "when does the lease expire?",
                    "session_id": "sess-eval-5",
                    "conversation_turn": 1,
                },
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["needs_unit_clarification"])
        self.assertTrue(data["user_action_required"])
        self.assertEqual(len(data["citations"]), 0)
        self.assertEqual(data["unit_options"][-1]["unit_id"], "all")
        self.assertEqual(data["unit_options"][-1]["unit_label"], "All units")

        mocked_ask.assert_awaited_once()

    @classmethod
    def tearDownClass(cls):
        print("\n" + "=" * 60)
        print("DOCUMIND STRUCTURAL EVALUATION SUITE COMPLETE")
        print("=" * 60)


if __name__ == "__main__":
    unittest.main()
