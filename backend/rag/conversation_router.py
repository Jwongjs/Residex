from __future__ import annotations

from typing import Dict, Any, List, Optional


class ConversationRouter:
    """Role-aware conversational router for DocuMind orchestration."""

    def __init__(self, llm):
        self._llm = llm

    @staticmethod
    def _default_conversation_reply(property_name: Optional[str]) -> str:
        base = (
            "Hey! If you have anything that needs help with on property documents "
            "(leases, warranties, insurance, utilities, receipts), please let me know."
        )
        if property_name and property_name != "Unknown Property":
            return f"For {property_name}, {base}"
        return base

    def route(
        self,
        text: str,
        recent_turns: Optional[List[Dict[str, Any]]] = None,
        property_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        normalized = (text or "").strip().lower()
        if not normalized:
            return {
                "intent": "conversation",
                "rag_needed": False,
                "confidence": 0.0,
                "reason": "Empty query",
                "assistant_reply": self._default_conversation_reply(property_name),
            }

        try:
            history_summary = ""
            if recent_turns:
                compact_turns = []
                for turn in recent_turns[-3:]:
                    user_q = str(turn.get("question", "")).strip()
                    action = str(turn.get("action", "")).strip()
                    if user_q:
                        compact_turns.append(f"Q: {user_q} | action: {action}")
                history_summary = "\nRecent conversation turns:\n" + "\n".join(compact_turns) if compact_turns else ""

            property_context = (
                f"Current property context: {property_name}"
                if property_name and property_name != "Unknown Property"
                else "Current property context: not provided"
            )

            prompt = f"""
You are DocuMind's conversation router.
Your main role: support property-document assistance while allowing natural conversation.

Input: {text}
{property_context}
{history_summary}

Determine whether retrieval should be triggered now.

Rules:
- If user asks about property documents, tenancy, rent terms, warranties, insurance, utilities, receipts, rules/clauses, obligations -> rag_needed=true and intent=document_question.
- If user is chatting, greeting, random social text, or not asking for document facts -> rag_needed=false and intent=conversation.
- If uncertain between conversation/document_question, prefer rag_needed=true.

Respond in this exact format:
intent=<conversation|document_question>;rag_needed=<true|false>;confidence=<0.0-1.0>;reason=<short reason>;assistant_reply=<short user-facing reply when rag_needed=false, else empty>
""".strip()
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()

            intent = "conversation"
            rag_needed = False
            confidence = 0.5
            reason = "Fallback parse"
            assistant_reply = self._default_conversation_reply(property_name)

            for part in content.split(";"):
                if part.startswith("intent="):
                    value = part.replace("intent=", "").strip().lower()
                    if value in {"conversation", "document_question"}:
                        intent = value
                elif part.startswith("rag_needed="):
                    raw = part.replace("rag_needed=", "").strip().lower()
                    rag_needed = raw == "true"
                elif part.startswith("confidence="):
                    raw = part.replace("confidence=", "").strip()
                    try:
                        confidence = max(0.0, min(1.0, float(raw)))
                    except ValueError:
                        pass
                elif part.startswith("reason="):
                    reason = part.replace("reason=", "").strip()
                elif part.startswith("assistant_reply="):
                    parsed = part.replace("assistant_reply=", "").strip()
                    if parsed:
                        assistant_reply = parsed

            if intent == "document_question":
                rag_needed = True
            if rag_needed:
                assistant_reply = ""

            return {
                "intent": intent,
                "rag_needed": rag_needed,
                "confidence": confidence,
                "reason": reason,
                "assistant_reply": assistant_reply,
            }
        except Exception:
            document_keywords = [
                "lease", "rent", "tenant", "warranty", "insurance", "utility", "receipt", "invoice", "property", "pets", "allowed", "clause", "agreement"
            ]
            if any(token in normalized for token in document_keywords):
                return {
                    "intent": "document_question",
                    "rag_needed": True,
                    "confidence": 0.55,
                    "reason": "Keyword fallback",
                    "assistant_reply": "",
                }
            return {
                "intent": "conversation",
                "rag_needed": False,
                "confidence": 0.55,
                "reason": "Safe conversational fallback",
                "assistant_reply": self._default_conversation_reply(property_name),
            }
