import unittest

from rag.conversation_router import ConversationRouter
from rag.graph_orchestrator import DocuMindGraphOrchestrator


class _LLMResponse:
    def __init__(self, content):
        self.content = content


class _FakeLLM:
    def __init__(self, content):
        self._content = content

    def invoke(self, prompt):
        return _LLMResponse(self._content)


class _RaisingLLM:
    def invoke(self, prompt):
        raise RuntimeError("boom")


class ConversationRouterFinanceTests(unittest.TestCase):
    def test_finance_intent_and_year_parsed(self):
        llm = _FakeLLM(
            "intent=finance_question;rag_needed=false;confidence=0.9;"
            "reason=asks for computed profit;year=2025;assistant_reply="
        )
        result = ConversationRouter(llm).route("what was my rental profit in 2025?")
        self.assertEqual(result["intent"], "finance_question")
        self.assertEqual(result["year"], 2025)
        self.assertFalse(result["rag_needed"])
        self.assertEqual(result["assistant_reply"], "")

    def test_year_is_none_when_not_mentioned(self):
        llm = _FakeLLM(
            "intent=finance_question;rag_needed=false;confidence=0.9;"
            "reason=profit question;year=none;assistant_reply="
        )
        result = ConversationRouter(llm).route("how is my rental doing?")
        self.assertEqual(result["intent"], "finance_question")
        self.assertIsNone(result["year"])

    def test_document_questions_still_route_to_retrieval(self):
        llm = _FakeLLM(
            "intent=document_question;rag_needed=true;confidence=0.9;"
            "reason=clause question;year=none;assistant_reply="
        )
        result = ConversationRouter(llm).route("what is the notice period on Unit A's tenancy?")
        self.assertEqual(result["intent"], "document_question")
        self.assertTrue(result["rag_needed"])

    def test_keyword_fallback_detects_finance_and_year(self):
        result = ConversationRouter(_RaisingLLM()).route("how much profit did I make in 2024?")
        self.assertEqual(result["intent"], "finance_question")
        self.assertEqual(result["year"], 2024)
        self.assertFalse(result["rag_needed"])


class GraphFinanceBranchTests(unittest.IsolatedAsyncioTestCase):
    async def test_finance_intent_routes_to_finance_action(self):
        class _FakeRouter:
            def route(self, text, recent_turns=None, property_name=None):
                return {
                    "intent": "finance_question", "rag_needed": False,
                    "confidence": 0.9, "reason": "finance",
                    "assistant_reply": "", "year": 2025,
                }

        class _FakePredictor:
            def predict(self, **kwargs):
                raise AssertionError("category predictor must not run on the finance branch")

        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor(),
        )
        state = await orchestrator.run({"user_input": "profit in 2025?"})
        self.assertEqual(state["action"], "finance")
        self.assertEqual(state["finance_year"], 2025)

    async def test_document_intent_unaffected(self):
        class _FakeRouter:
            def route(self, text, recent_turns=None, property_name=None):
                return {
                    "intent": "document_question", "rag_needed": True,
                    "confidence": 0.9, "reason": "clause",
                    "assistant_reply": "", "year": None,
                }

        class _FakePredictor:
            def predict(self, question, available_categories, available_units=None, recent_turns=None):
                return {
                    "predicted_categories": ["lease"], "confidence": 0.8,
                    "reason": "lease", "unit_id": None,
                    "unknown_unit": None, "unit_decided": False,
                }

        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor(),
        )
        state = await orchestrator.run({
            "user_input": "what does my lease say?",
            "available_categories": ["lease"],
        })
        self.assertEqual(state["action"], "retrieve")
        self.assertEqual(state["predicted_categories"], ["lease"])
