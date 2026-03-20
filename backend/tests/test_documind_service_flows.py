import unittest
from unittest.mock import PropertyMock, patch

from models.documind_models import AskRequest
from rag.documind_service import DocuMindService


class _LLMResponse:
    def __init__(self, content: str):
        self.content = content


class _FakeLLM:
    def __init__(self, content: str):
        self._content = content

    def invoke(self, _prompt: str):
        return _LLMResponse(self._content)


class _FakeEmbeddings:
    def embed_query(self, _question: str):
        return [0.1, 0.2, 0.3]


class _FakeSnapshot:
    def __init__(self, data):
        self._data = data

    def to_dict(self):
        return self._data


class _FakeVectorDoc:
    def __init__(self, data):
        self._data = data

    def to_dict(self):
        return self._data


class _FakeVectorQuery:
    def __init__(self, rows):
        self._rows = rows

    def stream(self):
        return [_FakeVectorDoc(row) for row in self._rows]


class _FakePropertyDoc:
    def __init__(self, exists=True, data=None):
        self.exists = exists
        self._data = data or {}

    def to_dict(self):
        return self._data


class _FakePropertyRef:
    def __init__(self, property_name: str):
        self._property_name = property_name

    def get(self):
        return _FakePropertyDoc(exists=True, data={"name": self._property_name})


class _FakeCollectionQuery:
    def __init__(self, db, name: str, filters=None):
        self._db = db
        self._name = name
        self._filters = filters or []

    def where(self, field, operator, value):
        if self._name == "documind_chunks" and field == "category":
            self._db.last_chunk_category_filter = (operator, value)
        return _FakeCollectionQuery(self._db, self._name, self._filters + [(field, operator, value)])

    def stream(self):
        if self._name == "documind_docs":
            rows = self._db.docs
        elif self._name == "documind_chunks":
            rows = self._db.chunks
        else:
            rows = []

        filtered = []
        for row in rows:
            include = True
            for field, operator, value in self._filters:
                row_value = row.get(field)
                if operator == "==" and row_value != value:
                    include = False
                    break
                if operator == "in" and row_value not in value:
                    include = False
                    break
            if include:
                filtered.append(row)

        return [_FakeSnapshot(row) for row in filtered]

    def find_nearest(self, vector_field, query_vector, distance_measure, limit):
        del vector_field, query_vector, distance_measure
        rows = [snapshot.to_dict() for snapshot in self.stream()][:limit]
        return _FakeVectorQuery(rows)


class _FakeCollection:
    def __init__(self, db, name: str):
        self._db = db
        self._name = name

    def where(self, field, operator, value):
        return _FakeCollectionQuery(self._db, self._name).where(field, operator, value)

    def document(self, _doc_id):
        if self._name == "properties":
            return _FakePropertyRef(self._db.property_name)
        raise NotImplementedError("document() only used for properties in these tests")


class _FakeDB:
    def __init__(self, docs=None, chunks=None, property_name="Test Property"):
        self.docs = docs or []
        self.chunks = chunks or []
        self.property_name = property_name
        self.last_chunk_category_filter = None

    def collection(self, name: str):
        return _FakeCollection(self, name)


class _FakeConversationStore:
    def __init__(self):
        self.sessions = {}
        self.pending = {}
        self.turns = {}

    def get_or_create_session(self, landlord_id, property_id, session_id):
        sid = session_id or "session-1"
        self.sessions[sid] = {
            "session_id": sid,
            "landlord_id": landlord_id,
            "property_id": property_id,
            "conversation_turns": self.turns.get(sid, []),
        }
        return self.sessions[sid]

    def get_turn_count(self, session_id):
        return len(self.turns.get(session_id, []))

    def append_turn(self, session_id, turn_data):
        self.turns.setdefault(session_id, []).append(turn_data)

    def set_pending_confirmation(self, session_id, pending):
        self.pending[session_id] = pending

    def get_pending_confirmation(self, session_id):
        return self.pending.get(session_id)

    def clear_pending_confirmation(self, session_id):
        self.pending[session_id] = None


class _FakeGraphOrchestrator:
    def __init__(self, state):
        self._state = state

    async def run(self, _state):
        return self._state


def _build_service(fake_db, fake_store, fake_graph, fake_llm):
    service = DocuMindService.__new__(DocuMindService)
    service._db = fake_db
    service._embeddings = _FakeEmbeddings()
    service._llm = fake_llm
    service._conversation_store = fake_store
    service._graph_orchestrator = fake_graph
    return service


class DocuMindServiceFlowTests(unittest.IsolatedAsyncioTestCase):
    async def test_ask_confirmation_returns_checkpoint_response(self):
        fake_db = _FakeDB(docs=[{"landlord_id": "l1", "property_id": "p1", "category": "warranty"}])
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator(
            {
                "action": "ask_confirmation",
                "predicted_categories": ["warranty"],
                "prediction_confidence": 0.84,
                "prediction_reason": "mentions coverage",
                "assistant_message": "Please confirm warranty category.",
                "intent": "document_question",
            }
        )
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("unused"))

        payload = AskRequest(landlord_id="l1", property_id="p1", question="what is covered")
        response = await service.ask_documind(payload)

        self.assertTrue(response.user_action_required)
        self.assertTrue(response.needs_category_clarification)
        self.assertEqual(response.predicted_categories, ["warranty"])
        self.assertEqual(fake_store.pending[response.session_id]["predicted_categories"], ["warranty"])

    async def test_cancel_clears_pending_and_returns_cancel_mode(self):
        fake_db = _FakeDB(docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        fake_store = _FakeConversationStore()
        fake_store.pending["session-9"] = {"question": "q", "predicted_categories": ["lease"]}
        fake_graph = _FakeGraphOrchestrator(
            {
                "action": "cancel",
                "assistant_message": "Cancelled.",
                "intent": "document_question",
            }
        )
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("unused"))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="cancel that",
            session_id="session-9",
            user_action="cancel",
        )
        response = await service.ask_documind(payload)

        self.assertEqual(response.category_filter_mode, "cancel")
        self.assertFalse(response.user_action_required)
        self.assertIsNone(fake_store.pending["session-9"])

    async def test_confirm_uses_pending_predicted_categories_for_retrieval(self):
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}],
            chunks=[
                {
                    "doc_id": "d1",
                    "filename": "lease.pdf",
                    "category": "lease",
                    "page": 2,
                    "text": "Pets are allowed with approval.",
                    "landlord_id": "l1",
                    "property_id": "p1",
                }
            ],
            property_name="Maple Residency",
        )
        fake_store = _FakeConversationStore()
        fake_store.pending["session-1"] = {
            "question": "Are pets allowed?",
            "predicted_categories": ["lease"],
            "available_categories": ["lease"],
        }
        fake_graph = _FakeGraphOrchestrator(
            {
                "action": "retrieve",
                "predicted_categories": ["lease"],
                "prediction_reason": "lease clause",
                "intent": "document_question",
            }
        )
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("Pets are allowed with owner approval."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="yes",
            session_id="session-1",
            user_action="confirm",
        )

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            response = await service.ask_documind(payload)

        self.assertEqual(response.category_filter_mode, "clarification_selected")
        self.assertEqual(response.searched_categories, ["lease"])
        self.assertEqual(response.property_name, "Maple Residency")
        self.assertEqual(len(response.citations), 1)
        self.assertFalse(response.user_action_required)

    async def test_override_category_uses_override_in_retrieval(self):
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "warranty"}],
            chunks=[
                {
                    "doc_id": "d2",
                    "filename": "warranty.pdf",
                    "category": "warranty",
                    "page": 1,
                    "text": "Warranty coverage starts from installation date.",
                    "landlord_id": "l1",
                    "property_id": "p1",
                }
            ],
        )
        fake_store = _FakeConversationStore()
        fake_store.pending["session-2"] = {
            "question": "What is covered?",
            "predicted_categories": ["lease"],
            "available_categories": ["lease", "warranty"],
        }
        fake_graph = _FakeGraphOrchestrator(
            {
                "action": "retrieve",
                "predicted_categories": ["lease"],
                "prediction_reason": "initial lease guess",
                "intent": "document_question",
            }
        )
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("Coverage includes parts and labor."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="choose warranty",
            session_id="session-2",
            user_action="override:warranty",
        )

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            response = await service.ask_documind(payload)

        self.assertEqual(response.category_filter_mode, "clarification_selected")
        self.assertEqual(response.searched_categories, ["warranty"])
        self.assertEqual(fake_db.last_chunk_category_filter, ("==", "warranty"))


if __name__ == "__main__":
    unittest.main()