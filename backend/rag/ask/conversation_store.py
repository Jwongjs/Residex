from __future__ import annotations

import uuid
from datetime import datetime
from typing import Dict, Any, Optional

from google.cloud import firestore


class ConversationStore:
    """Firestore-backed conversation memory for DocuMind sessions."""

    def __init__(self, db: firestore.Client, ttl_seconds: int = 3600):
        self._db = db
        self._ttl_seconds = ttl_seconds
        self._cache: Dict[str, Dict[str, Any]] = {}

    def _session_ref(self, session_id: str):
        return self._db.collection("documind_sessions").document(session_id)

    def get_or_create_session(self, landlord_id: str, property_id: str, session_id: Optional[str]) -> Dict[str, Any]:
        if session_id:
            cached = self._cache.get(session_id)
            if cached:
                return cached

            snapshot = self._session_ref(session_id).get()
            if snapshot.exists:
                data = snapshot.to_dict() or {}
                data["session_id"] = session_id
                self._cache[session_id] = data
                return data

        session_id = str(uuid.uuid4())
        payload = {
            "session_id": session_id,
            "landlord_id": landlord_id,
            "property_id": property_id,
            "created_at": firestore.SERVER_TIMESTAMP,
            "last_activity": firestore.SERVER_TIMESTAMP,
            "ttl_seconds": self._ttl_seconds,
            "conversation_turns": [],
            "pending_confirmation": None,
        }
        self._session_ref(session_id).set(payload)
        self._cache[session_id] = payload
        return payload

    def set_pending_confirmation(self, session_id: str, pending: Dict[str, Any]) -> None:
        self._session_ref(session_id).update({
            "pending_confirmation": pending,
            "last_activity": firestore.SERVER_TIMESTAMP,
        })
        if session_id in self._cache:
            self._cache[session_id]["pending_confirmation"] = pending

    def get_pending_confirmation(self, session_id: str) -> Optional[Dict[str, Any]]:
        cached = self._cache.get(session_id)
        if cached and "pending_confirmation" in cached:
            return cached.get("pending_confirmation")

        snapshot = self._session_ref(session_id).get()
        if not snapshot.exists:
            return None
        data = snapshot.to_dict() or {}
        self._cache[session_id] = {**data, "session_id": session_id}
        return data.get("pending_confirmation")

    def clear_pending_confirmation(self, session_id: str) -> None:
        self._session_ref(session_id).update({
            "pending_confirmation": None,
            "last_activity": firestore.SERVER_TIMESTAMP,
        })
        if session_id in self._cache:
            self._cache[session_id]["pending_confirmation"] = None

    def append_turn(self, session_id: str, turn_data: Dict[str, Any]) -> None:
        safe_turn = {
            **turn_data,
            "timestamp": datetime.utcnow(),
        }
        self._session_ref(session_id).update({
            "conversation_turns": firestore.ArrayUnion([safe_turn]),
            "last_activity": firestore.SERVER_TIMESTAMP,
        })

    def get_turn_count(self, session_id: str) -> int:
        snapshot = self._session_ref(session_id).get()
        if not snapshot.exists:
            return 0
        data = snapshot.to_dict() or {}
        return len(data.get("conversation_turns", []))
