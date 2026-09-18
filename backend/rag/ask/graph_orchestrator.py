from __future__ import annotations

from typing import Dict, Any, List, TypedDict

from langgraph.graph import StateGraph, END


class DocuMindState(TypedDict, total=False):
    user_input: str
    explicit_categories: List[str]
    available_categories: List[str]
    available_units: List[Dict[str, Any]]
    recent_turns: List[Dict[str, Any]]
    property_name: str

    intent: str
    rag_needed: bool
    intent_confidence: float
    intent_reason: str
    finance_year: int

    predicted_categories: List[str]
    prediction_confidence: float
    prediction_reason: str

    # LLM search routing for units: a validated unit id (or None), the name of
    # a referenced-but-nonexistent unit, and whether the router actually made
    # a unit decision (False -> the service falls back to deterministic label
    # matching).
    routed_unit_id: str
    unknown_unit_mention: str
    unit_routing_decided: bool

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
        graph.add_node("prepare_finance", self._prepare_finance_node)

        graph.set_entry_point("route_conversation")

        graph.add_conditional_edges(
            "route_conversation",
            self._route_after_conversation,
            {
                "conversation": "respond_conversation",
                "finance": "prepare_finance",
                "predict": "predict_categories",
            },
        )

        graph.add_edge("respond_conversation", END)
        graph.add_edge("predict_categories", END)
        graph.add_edge("prepare_finance", END)

        return graph.compile()

    async def run(self, state: DocuMindState) -> DocuMindState:
        return await self._graph.ainvoke(state)

    async def _route_conversation_node(self, state: DocuMindState) -> DocuMindState:
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
            "finance_year": result.get("year"),
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
                "action": "retrieve",
                "predicted_categories": explicit_categories,
                "prediction_confidence": 1.0,
                "prediction_reason": "User provided explicit categories",
                "routed_unit_id": None,
                "unknown_unit_mention": None,
                "unit_routing_decided": False,
            }

        prediction = self._category_predictor.predict(
            question=state.get("user_input", ""),
            available_categories=state.get("available_categories", []),
            available_units=state.get("available_units", []),
            recent_turns=state.get("recent_turns", []),
        )

        return {
            **state,
            "action": "retrieve",
            "predicted_categories": prediction.get("predicted_categories", []),
            "prediction_confidence": prediction.get("confidence", 0.0),
            "prediction_reason": prediction.get("reason", ""),
            "routed_unit_id": prediction.get("unit_id"),
            "unknown_unit_mention": prediction.get("unknown_unit"),
            "unit_routing_decided": prediction.get("unit_decided", False),
        }

    async def _prepare_finance_node(self, state: DocuMindState) -> DocuMindState:
        return {**state, "action": "finance"}

    def _route_after_conversation(self, state: DocuMindState) -> str:
        if state.get("intent") == "finance_question":
            return "finance"
        if state.get("rag_needed", False):
            return "predict"
        intent = state.get("intent")
        if intent == "conversation":
            return "conversation"
        return "predict"
