from __future__ import annotations

from typing import Dict, Any, List, TypedDict

from langgraph.graph import StateGraph, END


class DocuMindState(TypedDict, total=False):
    user_input: str
    explicit_categories: List[str]
    available_categories: List[str]
    user_action: str
    recent_turns: List[Dict[str, Any]]
    property_name: str

    intent: str
    rag_needed: bool
    intent_confidence: float
    intent_reason: str

    predicted_categories: List[str]
    prediction_confidence: float
    prediction_reason: str

    action: str
    assistant_message: str


class DocuMindGraphOrchestrator:
    def __init__(self, conversation_router, category_predictor):
        self._conversation_router = conversation_router
        self._category_predictor = category_predictor
        self._graph = self._build_graph()

    def _build_graph(self):
        graph = StateGraph(DocuMindState)
        graph.add_node("route_conversation", self._route_conversation_node)
        graph.add_node("respond_conversation", self._respond_conversation_node)
        graph.add_node("predict_categories", self._predict_categories_node)
        graph.add_node("decide_action", self._decide_action_node)
        graph.add_node("prepare_confirmation", self._prepare_confirmation_node)
        graph.add_node("prepare_cancel", self._prepare_cancel_node)
        graph.add_node("prepare_retrieve", self._prepare_retrieve_node)

        graph.set_entry_point("route_conversation")

        graph.add_conditional_edges(
            "route_conversation",
            self._route_after_conversation,
            {
                "conversation": "respond_conversation",
                "predict": "predict_categories",
            },
        )

        graph.add_edge("predict_categories", "decide_action")

        graph.add_conditional_edges(
            "decide_action",
            self._route_after_decision,
            {
                "ask_confirmation": "prepare_confirmation",
                "cancel": "prepare_cancel",
                "retrieve": "prepare_retrieve",
            },
        )

        graph.add_edge("respond_conversation", END)
        graph.add_edge("prepare_confirmation", END)
        graph.add_edge("prepare_cancel", END)
        graph.add_edge("prepare_retrieve", END)

        return graph.compile()

    async def run(self, state: DocuMindState) -> DocuMindState:
        return await self._graph.ainvoke(state)

    async def _route_conversation_node(self, state: DocuMindState) -> DocuMindState:
        user_action = (state.get("user_action") or "").strip().lower()
        if user_action in {"confirm", "cancel"} or user_action.startswith("override:"):
            return {
                **state,
                "intent": "document_question",
                "rag_needed": True,
                "intent_confidence": 1.0,
                "intent_reason": "User checkpoint action",
                "assistant_message": "",
            }

        result = self._conversation_router.route(
            text=state.get("user_input", ""),
            recent_turns=state.get("recent_turns", []),
            property_name=state.get("property_name"),
        )
        return {
            **state,
            "intent": result["intent"],
            "rag_needed": result.get("rag_needed", False),
            "intent_confidence": result["confidence"],
            "intent_reason": result["reason"],
            "assistant_message": result.get("assistant_reply", ""),
        }

    async def _respond_conversation_node(self, state: DocuMindState) -> DocuMindState:
        return {
            **state,
            "action": "conversation",
        }

    async def _predict_categories_node(self, state: DocuMindState) -> DocuMindState:
        explicit_categories = state.get("explicit_categories", [])
        if explicit_categories:
            return {
                **state,
                "predicted_categories": explicit_categories,
                "prediction_confidence": 1.0,
                "prediction_reason": "User provided explicit categories",
            }

        prediction = self._category_predictor.predict(
            question=state.get("user_input", ""),
            available_categories=state.get("available_categories", []),
        )

        return {
            **state,
            "predicted_categories": prediction.get("predicted_categories", []),
            "prediction_confidence": prediction.get("confidence", 0.0),
            "prediction_reason": prediction.get("reason", ""),
        }

    async def _decide_action_node(self, state: DocuMindState) -> DocuMindState:
        user_action = (state.get("user_action") or "").strip().lower()
        explicit = state.get("explicit_categories", [])
        predicted = state.get("predicted_categories", [])
        available = state.get("available_categories", [])

        if explicit:
            return {**state, "action": "retrieve"}

        if user_action == "cancel":
            return {**state, "action": "cancel"}

        if user_action.startswith("override:"):
            return {**state, "action": "retrieve"}

        if user_action == "confirm":
            return {**state, "action": "retrieve"}

        if predicted and available:
            return {**state, "action": "ask_confirmation"}

        return {**state, "action": "retrieve"}

    async def _prepare_confirmation_node(self, state: DocuMindState) -> DocuMindState:
        predicted = state.get("predicted_categories", [])
        prediction_label = ", ".join(predicted) if predicted else "the most relevant documents"

        message = (
            f"I am going to search your {prediction_label} documents to answer this accurately. "
            "Can you confirm, cancel, or choose another category?"
        )

        return {
            **state,
            "assistant_message": message,
        }

    async def _prepare_cancel_node(self, state: DocuMindState) -> DocuMindState:
        return {
            **state,
            "assistant_message": "Understood. I cancelled that action. Ask me anytime about your property documents.",
        }

    async def _prepare_retrieve_node(self, state: DocuMindState) -> DocuMindState:
        return state

    def _route_after_conversation(self, state: DocuMindState) -> str:
        if state.get("rag_needed", False):
            return "predict"
        intent = state.get("intent")
        if intent == "conversation":
            return "conversation"
        return "predict"

    def _route_after_decision(self, state: DocuMindState) -> str:
        action = state.get("action", "retrieve")
        if action == "ask_confirmation":
            return "ask_confirmation"
        if action == "cancel":
            return "cancel"
        return "retrieve"