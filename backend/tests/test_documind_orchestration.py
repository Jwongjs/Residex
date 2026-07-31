import unittest

from rag.ask.category_predictor import CategoryPredictor


class _LLMResponse:
    def __init__(self, content: str):
        self.content = content


class _FakeLLM:
    def __init__(self, content: str = "", raise_error: bool = False):
        self._content = content
        self._raise = raise_error
        self.last_prompt = None

    def invoke(self, prompt: str):
        if self._raise:
            raise RuntimeError("LLM unavailable")
        self.last_prompt = prompt
        return _LLMResponse(self._content)


ALL_CATEGORIES = ["lease", "warranty", "insurance", "utility", "receipt"]


class CategoryPredictorHonestUnknownTests(unittest.TestCase):
    def test_unparseable_llm_output_returns_empty_prediction(self):
        predictor = CategoryPredictor(_FakeLLM("nonsense with no expected format"), ALL_CATEGORIES)

        result = predictor.predict("zzz qqq", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], [])
        self.assertEqual(result["confidence"], 0.0)
        self.assertEqual(result["reason"], "no clear category signal")

    def test_no_signal_keyword_fallback_returns_empty_prediction(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        result = predictor.predict("zzz qqq", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], [])
        self.assertEqual(result["confidence"], 0.0)
        self.assertEqual(result["reason"], "no clear category signal")

    def test_empty_prediction_is_independent_of_category_ordering(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        forward = predictor.predict("zzz qqq", ["lease", "warranty", "utility"])
        reversed_order = predictor.predict("zzz qqq", ["utility", "warranty", "lease"])

        self.assertEqual(forward["predicted_categories"], reversed_order["predicted_categories"])
        self.assertEqual(forward["predicted_categories"], [])

    def test_keyword_fallback_still_matches_real_signal(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        result = predictor.predict("when does the lease expire", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], ["lease"])


from rag.ask.graph_orchestrator import DocuMindGraphOrchestrator


class _FakeRouter:
    def route(self, text, recent_turns, property_name=None):
        return {
            "intent": "document_question",
            "rag_needed": True,
            "confidence": 0.9,
            "reason": "document question",
            "assistant_reply": "",
        }


class _FakePredictor:
    def __init__(self, result):
        self._result = result

    def predict(self, question, available_categories, available_units=None, recent_turns=None):
        return self._result


class CategoryPredictorUnitRoutingTests(unittest.TestCase):
    _UNITS = [
        {"unit_id": "unit-A", "label": "Unit A-12-03"},
        {"unit_id": "unit-B", "label": "Unit B-08-11"},
    ]

    def test_parses_routed_unit_id(self):
        predictor = CategoryPredictor(
            _FakeLLM("categories=lease;confidence=0.9;reason=rent;unit=unit-A;unknown_unit=none"),
            ALL_CATEGORIES,
        )

        result = predictor.predict("rent for unit a?", ["lease", "utility"], self._UNITS)

        self.assertEqual(result["predicted_categories"], ["lease"])
        self.assertEqual(result["unit_id"], "unit-A")
        self.assertIsNone(result["unknown_unit"])
        self.assertTrue(result["unit_decided"])

    def test_accepts_label_echo_for_unit(self):
        predictor = CategoryPredictor(
            _FakeLLM("categories=lease;confidence=0.9;reason=rent;unit=Unit B-08-11;unknown_unit=none"),
            ALL_CATEGORIES,
        )

        result = predictor.predict("rent for unit b?", ["lease"], self._UNITS)

        self.assertEqual(result["unit_id"], "unit-B")
        self.assertTrue(result["unit_decided"])

    def test_unknown_unit_reported(self):
        predictor = CategoryPredictor(
            _FakeLLM("categories=lease;confidence=0.8;reason=rent;unit=all;unknown_unit=Unit D"),
            ALL_CATEGORIES,
        )

        result = predictor.predict("rent for unit d?", ["lease"], self._UNITS)

        self.assertIsNone(result["unit_id"])
        self.assertEqual(result["unknown_unit"], "Unit D")
        self.assertTrue(result["unit_decided"])

    def test_hallucinated_unit_id_leaves_routing_undecided(self):
        predictor = CategoryPredictor(
            _FakeLLM("categories=lease;confidence=0.8;reason=rent;unit=unit-Z;unknown_unit=none"),
            ALL_CATEGORIES,
        )

        result = predictor.predict("rent?", ["lease"], self._UNITS)

        self.assertIsNone(result["unit_id"])
        self.assertFalse(result["unit_decided"])

    def test_llm_failure_leaves_routing_undecided(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        result = predictor.predict("when does the lease expire", ["lease"], self._UNITS)

        self.assertFalse(result["unit_decided"])
        self.assertIsNone(result["unit_id"])

    def test_recent_turns_reach_the_router_prompt(self):
        # Conversational continuity: a follow-up that names no unit is routed
        # using the conversation, so the prompt must carry the recent turns.
        llm = _FakeLLM(
            "categories=lease;confidence=0.9;reason=follow-up;unit=unit-A;unknown_unit=none"
        )
        predictor = CategoryPredictor(llm, ALL_CATEGORIES)

        result = predictor.predict(
            "and when does the tenancy end?",
            ["lease"],
            self._UNITS,
            recent_turns=[
                {"question": "What is Unit A's monthly rent?", "answer": "RM 2,400"},
            ],
        )

        self.assertIn("Recent conversation", llm.last_prompt)
        self.assertIn("Unit A's monthly rent", llm.last_prompt)
        self.assertEqual(result["unit_id"], "unit-A")
        self.assertTrue(result["unit_decided"])


class GraphOrchestratorUnitRoutingTests(unittest.IsolatedAsyncioTestCase):
    async def test_unit_routing_fields_propagate_through_graph(self):
        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor({
                "predicted_categories": ["lease"],
                "confidence": 0.9,
                "reason": "rent question",
                "unit_id": "unit-A",
                "unknown_unit": None,
                "unit_decided": True,
            }),
        )

        state = await orchestrator.run({
            "user_input": "rent for unit a?",
            "explicit_categories": [],
            "available_categories": ["lease"],
            "available_units": [{"unit_id": "unit-A", "label": "Unit A"}],
            "user_action": "",
            "recent_turns": [],
            "property_name": "Maple Residency",
        })

        self.assertEqual(state["action"], "retrieve")
        self.assertEqual(state["routed_unit_id"], "unit-A")
        self.assertIsNone(state["unknown_unit_mention"])
        self.assertTrue(state["unit_routing_decided"])


class GraphOrchestratorEmptyPredictionTests(unittest.IsolatedAsyncioTestCase):
    async def test_empty_prediction_routes_to_retrieve_unscoped(self):
        # Fresh questions never stop at a category checkpoint anymore: an
        # empty/unsure prediction just searches the whole corpus.
        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor({
                "predicted_categories": [],
                "confidence": 0.0,
                "reason": "no clear category signal",
            }),
        )

        state = await orchestrator.run({
            "user_input": "zzz qqq",
            "explicit_categories": [],
            "available_categories": ["lease", "warranty"],
            "user_action": "",
            "recent_turns": [],
            "property_name": "Maple Residency",
        })

        self.assertEqual(state["action"], "retrieve")
        self.assertEqual(state["predicted_categories"], [])

    async def test_no_available_categories_still_retrieves(self):
        # No uploaded docs at all: nothing to clarify against, fall through
        # to retrieve (which answers "no relevant documents").
        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor({
                "predicted_categories": [],
                "confidence": 0.0,
                "reason": "No uploaded categories for this property",
            }),
        )

        state = await orchestrator.run({
            "user_input": "when does the lease end",
            "explicit_categories": [],
            "available_categories": [],
            "user_action": "",
            "recent_turns": [],
            "property_name": "Maple Residency",
        })

        self.assertEqual(state["action"], "retrieve")

    async def test_unit_action_routes_to_retrieve_without_new_checkpoint(self):
        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor({
                "predicted_categories": ["lease"],
                "confidence": 0.8,
                "reason": "lease question",
            }),
        )

        state = await orchestrator.run({
            "user_input": "when does the lease expire?",
            "explicit_categories": [],
            "available_categories": ["lease"],
            "user_action": "unit:unit-A",
            "recent_turns": [],
            "property_name": "Maple Residency",
        })

        self.assertEqual(state["action"], "retrieve")


if __name__ == "__main__":
    unittest.main()
