import unittest
from datetime import datetime
from unittest.mock import MagicMock, PropertyMock, patch

from models.documind_models import AskRequest
from rag.documind_service import DocuMindService, resolve_unit_mention


class _LLMResponse:
    def __init__(self, content: str):
        self.content = content


class _FakeLLM:
    def __init__(self, content: str):
        self._content = content
        self.last_prompt = None

    def invoke(self, prompt: str):
        self.last_prompt = prompt
        return _LLMResponse(self._content)


class _FakeEmbeddings:
    def embed_query(self, _question: str):
        return [0.1, 0.2, 0.3]


class _FakeSnapshot:
    def __init__(self, data, reference=None):
        self._data = data
        self.reference = reference

    @property
    def id(self):
        return self._data.get("doc_id")

    def to_dict(self):
        return self._data


class _FakeRowRef:
    """Reference to a fixture row, so batch.delete(snapshot.reference) works."""

    def __init__(self, db, collection_name, row):
        self._db = db
        self._collection_name = collection_name
        self._row = row

    def delete(self):
        rows = self._db.chunks if self._collection_name == "documind_chunks" else self._db.docs
        for i, row in enumerate(rows):
            if row is self._row:
                del rows[i]
                break

    def update(self, fields):
        self._row.update(fields)


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


class _FakeUnitSnapshot:
    def __init__(self, unit_id, label):
        self.id = unit_id
        self._label = label

    def to_dict(self):
        return {"label": self._label}


class _FakeUnitsCollection:
    def __init__(self, units):
        self._units = units

    def stream(self):
        return [_FakeUnitSnapshot(u["unit_id"], u["label"]) for u in self._units]


class _FakePropertyRef:
    def __init__(self, property_name: str, units=None):
        self._property_name = property_name
        self._units = units or []

    def get(self):
        return _FakePropertyDoc(exists=True, data={"name": self._property_name})

    def collection(self, name: str):
        if name == "units":
            return _FakeUnitsCollection(self._units)
        raise NotImplementedError("only the units subcollection is faked")


class _FakeCollectionQuery:
    def __init__(self, db, name: str, filters=None):
        self._db = db
        self._name = name
        self._filters = filters or []

    def where(self, field=None, operator=None, value=None, filter=None):
        if filter is not None:
            field, operator, value = filter.field_path, filter.op_string, filter.value
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

        return [
            _FakeSnapshot(row, reference=_FakeRowRef(self._db, self._name, row))
            for row in filtered
        ]

    def find_nearest(self, vector_field, query_vector, distance_measure, limit):
        del vector_field, query_vector, distance_measure
        rows = [snapshot.to_dict() for snapshot in self.stream()][:limit]
        return _FakeVectorQuery(rows)


class _FakeDocDocRef:
    def __init__(self, db, doc_id):
        self._db = db
        self._doc_id = doc_id

    def set(self, data):
        self._db.docs.append({**data, "doc_id": self._doc_id})

    def _find_index(self):
        """Return the index of the row matching self._doc_id, or None.

        Rows that carry an explicit "doc_id" field are matched exactly.
        Rows with no "doc_id" field at all (a shorthand some tests use when
        there is only a single row in play) are treated as implicitly being
        whatever doc_id is being looked up for -- but only when there is
        exactly one such keyless row, so ambiguity can never be silently
        resolved by picking the first match.
        """
        keyless_indices = [i for i, row in enumerate(self._db.docs) if "doc_id" not in row]
        if len(keyless_indices) > 1:
            raise AssertionError(
                "_FakeDocDocRef cannot disambiguate multiple rows without an "
                "explicit 'doc_id' field; add 'doc_id' to each row in this test's "
                "_FakeDB(docs=[...]) fixture."
            )

        for i, row in enumerate(self._db.docs):
            if row.get("doc_id") == self._doc_id:
                return i

        if keyless_indices:
            return keyless_indices[0]

        return None

    def get(self):
        index = self._find_index()
        if index is not None:
            return _FakePropertyDoc(exists=True, data=self._db.docs[index])
        return _FakePropertyDoc(exists=False, data={})

    def delete(self):
        index = self._find_index()
        if index is not None:
            del self._db.docs[index]


class _FakeChunkDocRef:
    def __init__(self, db):
        self._db = db

    def set(self, data):
        self._db.chunks.append(data)


class _FakeBatch:
    def __init__(self):
        self._ops = []

    def set(self, ref, data):
        self._ops.append(("set", ref, data))

    def update(self, ref, fields):
        self._ops.append(("update", ref, fields))

    def delete(self, ref):
        self._ops.append(("delete", ref, None))

    def commit(self):
        for op, ref, data in self._ops:
            if op == "set":
                ref.set(data)
            elif op == "update":
                ref.update(data)
            else:
                ref.delete()


class _FakeCollection:
    def __init__(self, db, name: str):
        self._db = db
        self._name = name

    def where(self, field=None, operator=None, value=None, filter=None):
        return _FakeCollectionQuery(self._db, self._name).where(field, operator, value, filter=filter)

    def document(self, _doc_id=None):
        if self._name == "properties":
            return _FakePropertyRef(
                self._db.property_name, getattr(self._db, "units", [])
            )
        if self._name == "documind_docs":
            return _FakeDocDocRef(self._db, _doc_id)
        if self._name == "documind_chunks":
            return _FakeChunkDocRef(self._db)
        raise NotImplementedError("document() only used for properties, documind_docs, documind_chunks in these tests")


class _FakeDB:
    def __init__(self, docs=None, chunks=None, property_name="Test Property", units=None):
        self.docs = docs or []
        self.units = units or []
        self.chunks = chunks or []
        self.property_name = property_name
        self.last_chunk_category_filter = None

    def collection(self, name: str):
        return _FakeCollection(self, name)

    def batch(self):
        return _FakeBatch()


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


class _FakeHybridRetriever:
    """Stands in for HybridRetriever: filters the _FakeDB chunk fixtures the
    same way the real retriever's dense search + unit post-filter would, and
    records every call so tests can assert on question/categories/unit_id."""

    def __init__(self, db):
        self._db = db
        self.calls = []

    async def retrieve(self, question, landlord_id, property_id, top_k=4,
                       categories=None, unit_id=None):
        self.calls.append({
            "question": question,
            "categories": categories,
            "unit_id": unit_id,
        })

        rows = [
            dict(row) for row in self._db.chunks
            if row.get("landlord_id") == landlord_id
            and row.get("property_id") == property_id
        ]
        if categories:
            if len(categories) == 1:
                self._db.last_chunk_category_filter = ("==", categories[0])
            else:
                self._db.last_chunk_category_filter = ("in", categories[:10])
            rows = [row for row in rows if row.get("category") in categories]
        if unit_id:
            rows = [row for row in rows if row.get("unit_id") in (None, unit_id)]

        for rank, row in enumerate(rows):
            row.setdefault("rerank_score", 0.9 - rank * 0.05)
        return rows[:top_k]


def _build_service(fake_db, fake_store, fake_graph, fake_llm):
    service = DocuMindService.__new__(DocuMindService)
    service._db = fake_db
    service._embeddings = _FakeEmbeddings()
    service._llm = fake_llm
    service._conversation_store = fake_store
    service._graph_orchestrator = fake_graph
    service._hybrid_retriever = _FakeHybridRetriever(fake_db)
    return service


class DocuMindServiceFlowTests(unittest.IsolatedAsyncioTestCase):
    async def test_empty_prediction_checkpoint_offers_all_available_categories(self):
        fake_db = _FakeDB(docs=[
            {"doc_id": "doc-1", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
            {"doc_id": "doc-2", "landlord_id": "l1", "property_id": "p1", "category": "insurance"},
        ])
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator({
            "action": "ask_confirmation",
            "predicted_categories": [],
            "prediction_confidence": 0.0,
            "prediction_reason": "no clear category signal",
            "assistant_message": "Which category should I search?",
            "intent": "document_question",
        })
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("unused"))

        payload = AskRequest(landlord_id="l1", property_id="p1", question="zzz qqq")
        response = await service.ask_documind(payload)

        self.assertTrue(response.needs_category_clarification)
        self.assertEqual(response.clarification_options, ["lease", "insurance"])
        self.assertEqual(response.predicted_categories, [])

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
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "upkeep"}],
            chunks=[
                {
                    "doc_id": "d2",
                    "filename": "upkeep.pdf",
                    "category": "upkeep",
                    "page": 1,
                    "text": "Aircon servicing coverage starts from installation date.",
                    "landlord_id": "l1",
                    "property_id": "p1",
                }
            ],
        )
        fake_store = _FakeConversationStore()
        fake_store.pending["session-2"] = {
            "question": "What is covered?",
            "predicted_categories": ["lease"],
            "available_categories": ["lease", "upkeep"],
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
            question="choose upkeep",
            session_id="session-2",
            user_action="override:upkeep",
        )

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            response = await service.ask_documind(payload)

        self.assertEqual(response.category_filter_mode, "clarification_selected")
        self.assertEqual(response.searched_categories, ["upkeep"])
        self.assertEqual(
            fake_db.last_chunk_category_filter, ("in", ["upkeep", "utility", "warranty"])
        )

    async def test_citations_and_context_carry_unit_fields(self):
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}],
            chunks=[
                {"doc_id": "d1", "filename": "leaseA.pdf", "category": "lease", "page": 2,
                 "unit_id": "unit-A", "unit_label": "Unit A",
                 "text": "Unit A tenancy ends 31 December 2026.",
                 "landlord_id": "l1", "property_id": "p1"},
                {"doc_id": "d2", "filename": "insurance.pdf", "category": "insurance", "page": 0,
                 "text": "Building insurance covers fire damage.",
                 "landlord_id": "l1", "property_id": "p1"},
            ],
        )
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": [],
            "intent": "document_question",
        })
        fake_llm = _FakeLLM("The tenancy ends 31 December 2026.")
        service = _build_service(fake_db, fake_store, fake_graph, fake_llm)

        payload = AskRequest(landlord_id="l1", property_id="p1", question="when does the lease end")
        response = await service.ask_documind(payload)

        citations_by_doc = {c.doc_id: c for c in response.citations}
        self.assertEqual(citations_by_doc["d1"].unit_id, "unit-A")
        self.assertEqual(citations_by_doc["d1"].unit_label, "Unit A")
        self.assertIsNone(citations_by_doc["d2"].unit_id)
        self.assertIsNone(citations_by_doc["d2"].unit_label)
        self.assertIn("— Unit A]", fake_llm.last_prompt)
        self.assertIn("— Property-wide]", fake_llm.last_prompt)


class DocuMindUnitClarificationTests(unittest.IsolatedAsyncioTestCase):
    def _multi_unit_db(self):
        return _FakeDB(
            docs=[
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
                {"doc_id": "doc-B", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
            ],
            units=[
                {"unit_id": "unit-A", "label": "Unit A"},
                {"unit_id": "unit-B", "label": "Unit B"},
            ],
            chunks=[
                {"doc_id": "doc-A", "filename": "leaseA.pdf", "category": "lease", "page": 1,
                 "unit_id": "unit-A", "unit_label": "Unit A",
                 "text": "Unit A tenancy ends 31 December 2026.",
                 "landlord_id": "l1", "property_id": "p1"},
                {"doc_id": "doc-B", "filename": "leaseB.pdf", "category": "lease", "page": 1,
                 "unit_id": "unit-B", "unit_label": "Unit B",
                 "text": "Unit B tenancy ends 30 June 2027.",
                 "landlord_id": "l1", "property_id": "p1"},
            ],
        )

    def _retrieve_graph(self):
        return _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["lease"],
            "prediction_reason": "lease question",
            "intent": "document_question",
        })

    def _unit_pending(self):
        return {
            "type": "unit",
            "question": "when does the lease expire?",
            "unit_options": [
                {"unit_id": "unit-A", "unit_label": "Unit A"},
                {"unit_id": "unit-B", "unit_label": "Unit B"},
                {"unit_id": "all", "unit_label": "All units"},
            ],
        }

    async def test_multi_unit_retrieval_without_filter_answers_with_attribution(self):
        # Mixed-unit retrieval no longer blocks on a checkpoint: the answer
        # comes back directly and the prompt's unit-attribution rule keeps
        # each figure tied to its unit.
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        fake_llm = _FakeLLM("Unit A ends 2026; Unit B ends 2027.")
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), fake_llm)

        payload = AskRequest(landlord_id="l1", property_id="p1", question="when does the lease expire?")
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertFalse(response.user_action_required)
        self.assertEqual(len(response.citations), 2)
        self.assertIn("Unit attribution", fake_llm.last_prompt)

    async def test_explicit_unit_reference_scopes_retrieval(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        service = _build_service(
            fake_db, fake_store, self._retrieve_graph(), _FakeLLM("Ends 31 December 2026.")
        )

        payload = AskRequest(
            landlord_id="l1", property_id="p1", question="When does unit A's lease expire?"
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertEqual(retriever_call["unit_id"], "unit-A")
        self.assertEqual(len(response.citations), 1)
        self.assertEqual(response.citations[0].unit_label, "Unit A")

    async def test_unknown_unit_reference_answers_honestly_without_retrieval(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("unused"))

        payload = AskRequest(
            landlord_id="l1", property_id="p1", question="What is the rent for unit D?"
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertFalse(response.user_action_required)
        self.assertIn("Unit D", response.answer)
        self.assertIn("Unit A", response.answer)
        self.assertEqual(response.citations, [])
        self.assertEqual(service._hybrid_retriever.calls, [])

    async def test_aggregate_phrasing_searches_all_units_without_checkpoint(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        service = _build_service(
            fake_db,
            fake_store,
            self._retrieve_graph(),
            _FakeLLM("Unit A: RM 1; Unit B: RM 2; total RM 3."),
        )

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="What is the total monthly rent across all units?",
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertFalse(response.user_action_required)
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertIsNone(retriever_call["unit_id"])
        self.assertEqual(len(response.citations), 2)

    async def test_llm_routed_unit_scopes_retrieval(self):
        # The router LLM decided the unit (tool-style routing); no label
        # parsing is involved and retrieval is scoped straight to that unit.
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["lease"],
            "prediction_confidence": 0.9,
            "intent": "document_question",
            "routed_unit_id": "unit-B",
            "unit_routing_decided": True,
        })
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("Ends 30 June 2027."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="when does the tenancy for the second unit end?",
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertEqual(retriever_call["unit_id"], "unit-B")
        self.assertEqual(len(response.citations), 1)
        self.assertEqual(response.citations[0].unit_label, "Unit B")

    async def test_llm_routed_unknown_unit_answers_honestly(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": [],
            "intent": "document_question",
            "unknown_unit_mention": "Unit D",
            "unit_routing_decided": True,
        })
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("unused"))

        payload = AskRequest(landlord_id="l1", property_id="p1", question="rent for unit D?")
        response = await service.ask_documind(payload)

        self.assertFalse(response.user_action_required)
        self.assertIn("Unit D", response.answer)
        self.assertIn("Unit A", response.answer)
        self.assertEqual(service._hybrid_retriever.calls, [])

    async def test_prefix_collision_still_asks_which_unit(self):
        # The one surviving unit checkpoint: a reference that genuinely
        # matches several units (pre-retrieval, so no wasted search).
        fake_db = _FakeDB(
            docs=[{"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1", "category": "lease"}],
            chunks=[],
            units=[
                {"unit_id": "unit-A1", "label": "Unit A-1"},
                {"unit_id": "unit-A2", "label": "Unit A-2"},
            ],
        )
        fake_store = _FakeConversationStore()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("unused"))

        payload = AskRequest(
            landlord_id="l1", property_id="p1", question="what is the rent for unit A?"
        )
        response = await service.ask_documind(payload)

        self.assertTrue(response.needs_unit_clarification)
        self.assertTrue(response.user_action_required)
        self.assertEqual(
            [option.unit_id for option in response.unit_options],
            ["unit-A1", "unit-A2", "all"],
        )
        pending = fake_store.pending[response.session_id]
        self.assertEqual(pending["type"], "unit")
        self.assertEqual(service._hybrid_retriever.calls, [])

    async def test_unit_action_reruns_pending_question_with_unit_filter(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        fake_store.pending["session-7"] = self._unit_pending()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("It ends 31 December 2026."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="Unit A",
            session_id="session-7",
            user_action="unit:unit-A",
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertEqual(len(response.citations), 1)
        self.assertEqual(response.citations[0].unit_label, "Unit A")
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertEqual(retriever_call["unit_id"], "unit-A")
        self.assertEqual(retriever_call["question"], "when does the lease expire?")
        self.assertIsNone(fake_store.pending["session-7"])

    async def test_unit_all_action_answers_unfiltered_without_loop(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        fake_store.pending["session-8"] = self._unit_pending()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("Unit A ends 2026; Unit B ends 2027."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="All units",
            session_id="session-8",
            user_action="unit:all",
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertFalse(response.user_action_required)
        self.assertEqual(len(response.citations), 2)
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertIsNone(retriever_call["unit_id"])
        self.assertEqual(retriever_call["question"], "when does the lease expire?")

    async def test_single_unit_plus_property_wide_does_not_trigger(self):
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}],
            chunks=[
                {"doc_id": "doc-A", "filename": "leaseA.pdf", "category": "lease", "page": 1,
                 "unit_id": "unit-A", "unit_label": "Unit A",
                 "text": "Unit A tenancy ends 31 December 2026.",
                 "landlord_id": "l1", "property_id": "p1"},
                # Pre-units chunk: no unit keys at all — property-wide.
                {"doc_id": "doc-C", "filename": "insurance.pdf", "category": "insurance", "page": 1,
                 "text": "Building insurance covers fire damage.",
                 "landlord_id": "l1", "property_id": "p1"},
            ],
        )
        fake_store = _FakeConversationStore()
        # Empty predicted_categories so the fake retriever applies no category
        # filter — otherwise the property-wide insurance chunk would be dropped
        # before the citation count check. Matches Task 3's fields-test pattern.
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": [],
            "intent": "document_question",
        })
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("It ends 31 December 2026."))

        payload = AskRequest(landlord_id="l1", property_id="p1", question="when does the lease expire?")
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertEqual(len(response.citations), 2)

    async def test_unit_resume_preserves_original_category_scope(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        # Pending carries the ORIGINAL question's lease scope.
        fake_store.pending["session-scope"] = {
            "type": "unit",
            "question": "when does the lease expire?",
            "selected_categories": ["lease"],
            "unit_options": [
                {"unit_id": "unit-A", "unit_label": "Unit A"},
                {"unit_id": "unit-B", "unit_label": "Unit B"},
                {"unit_id": "all", "unit_label": "All units"},
            ],
        }
        # This turn's graph runs over "Unit A" and honestly returns no category.
        empty_pred_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": [],
            "intent": "document_question",
        })
        service = _build_service(fake_db, fake_store, empty_pred_graph, _FakeLLM("It ends 31 December 2026."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="Unit A",
            session_id="session-scope",
            user_action="unit:unit-A",
        )
        response = await service.ask_documind(payload)

        # The resumed retrieval must keep the ORIGINAL lease scope, not search all categories.
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertEqual(retriever_call["categories"], ["lease"])
        self.assertEqual(retriever_call["unit_id"], "unit-A")
        self.assertEqual(response.searched_categories, ["lease"])


class _FakeBlob:
    def __init__(self, bucket, path):
        self.bucket = bucket
        self.path = path
        self.uploaded_content = None
        self.uploaded_content_type = None

    def upload_from_string(self, content, content_type=None):
        self.uploaded_content = content
        self.uploaded_content_type = content_type
        self.bucket.blobs[self.path] = self


class _FakeStorageBucket:
    def __init__(self):
        self.blobs = {}

    def blob(self, path):
        return _FakeBlob(self, path)


class DocuMindServiceStorageTests(unittest.IsolatedAsyncioTestCase):
    async def test_ingest_document_uploads_pdf_to_storage(self):
        fake_db = _FakeDB()
        fake_bucket = _FakeStorageBucket()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket

        pdf_bytes = b"%PDF-1.4 fake content"

        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return pdf_bytes

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            fake_page = MagicMock()
            fake_page.page_content = "Some lease text"
            fake_page.metadata = {"page": 0}
            loader_mock.return_value.load.return_value = [fake_page]

            response = await service.ingest_document(
                landlord_id="l1",
                property_id="p1",
                category="lease",
                file=_FakeUploadFile(),
            )

        expected_path = f"documind/l1/p1/{response.doc_id}.pdf"
        self.assertIn(expected_path, fake_bucket.blobs)
        self.assertEqual(fake_bucket.blobs[expected_path].uploaded_content, pdf_bytes)
        self.assertEqual(fake_bucket.blobs[expected_path].uploaded_content_type, "application/pdf")

        stored_doc = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored_doc["storage_path"], expected_path)

    async def test_get_document_view_url_returns_signed_url(self):
        fake_db = _FakeDB(docs=[{
            "landlord_id": "l1",
            "property_id": "p1",
            "storage_path": "documind/l1/p1/doc-1.pdf",
        }])
        fake_bucket = _FakeStorageBucket()

        class _FakeBlobWithSignedUrl(_FakeBlob):
            def generate_signed_url(self, expiration, method="GET"):
                return f"https://fake-storage.example/{self.path}?exp={expiration}"

        fake_bucket.blob = lambda path: _FakeBlobWithSignedUrl(fake_bucket, path)

        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket

        # _FakeDB needs a document() lookup for "documind_docs" keyed by doc_id,
        # matching the extension made in Task 1 Step 1 for ingest's doc_ref.set().
        # Reuse that same fake document-reference support here for .get().
        url = await service.get_document_view_url(landlord_id="l1", property_id="p1", doc_id="doc-1")

        self.assertIn("documind/l1/p1/doc-1.pdf", url)

    async def test_get_document_view_url_raises_when_not_found(self):
        fake_db = _FakeDB(docs=[])
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.get_document_view_url(landlord_id="l1", property_id="p1", doc_id="missing-doc")

    async def test_delete_document_removes_storage_object(self):
        fake_db = _FakeDB(docs=[{
            "landlord_id": "l1",
            "property_id": "p1",
            "storage_path": "documind/l1/p1/doc-1.pdf",
            "filename": "lease.pdf",
        }])
        fake_bucket = _FakeStorageBucket()
        deleted_paths = []

        class _FakeDeletableBlob(_FakeBlob):
            def delete(self):
                deleted_paths.append(self.path)

        fake_bucket.blob = lambda path: _FakeDeletableBlob(fake_bucket, path)

        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket

        await service.delete_document(landlord_id="l1", property_id="p1", doc_id="doc-1")

        self.assertIn("documind/l1/p1/doc-1.pdf", deleted_paths)

    async def test_delete_documents_for_property_cascades_all_docs(self):
        fake_db = _FakeDB(
            docs=[
                {"doc_id": "doc-1", "landlord_id": "l1", "property_id": "p1",
                 "storage_path": "documind/l1/p1/doc-1.pdf", "filename": "lease.pdf"},
                {"doc_id": "doc-2", "landlord_id": "l1", "property_id": "p1",
                 "storage_path": "documind/l1/p1/doc-2.pdf", "filename": "bill.pdf"},
                {"doc_id": "doc-3", "landlord_id": "l1", "property_id": "p2",
                 "storage_path": "documind/l1/p2/doc-3.pdf", "filename": "other.pdf"},
            ],
            chunks=[
                {"doc_id": "doc-1", "text": "a"},
                {"doc_id": "doc-1", "text": "b"},
                {"doc_id": "doc-2", "text": "c"},
            ],
        )
        fake_bucket = _FakeStorageBucket()
        deleted_paths = []

        class _FakeDeletableBlob(_FakeBlob):
            def delete(self):
                deleted_paths.append(self.path)

        fake_bucket.blob = lambda path: _FakeDeletableBlob(fake_bucket, path)

        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket

        result = await service.delete_documents_for_property(landlord_id="l1", property_id="p1")

        self.assertEqual(result["documents_deleted"], 2)
        self.assertEqual(result["chunks_deleted"], 3)
        self.assertEqual([d["doc_id"] for d in fake_db.docs], ["doc-3"])
        self.assertEqual(fake_db.chunks, [])
        self.assertCountEqual(
            deleted_paths,
            ["documind/l1/p1/doc-1.pdf", "documind/l1/p1/doc-2.pdf"],
        )

    async def test_list_documents_unit_filter_includes_property_wide(self):
        fake_db = _FakeDB(docs=[
            {"doc_id": "doc-1", "landlord_id": "l1", "property_id": "p1",
             "unit_id": "unit-A", "unit_label": "Unit A", "category": "lease",
             "filename": "leaseA.pdf", "uploaded_at": datetime.now(), "chunks_indexed": 1},
            {"doc_id": "doc-2", "landlord_id": "l1", "property_id": "p1",
             "unit_id": "unit-B", "unit_label": "Unit B", "category": "lease",
             "filename": "leaseB.pdf", "uploaded_at": datetime.now(), "chunks_indexed": 1},
            {"doc_id": "doc-3", "landlord_id": "l1", "property_id": "p1",
             "unit_id": None, "unit_label": None, "category": "insurance",
             "filename": "insurance.pdf", "uploaded_at": datetime.now(), "chunks_indexed": 1},
            # Pre-units doc: no unit_id key at all — must be treated property-wide.
            {"doc_id": "doc-4", "landlord_id": "l1", "property_id": "p1",
             "category": "utility", "filename": "bill.pdf",
             "uploaded_at": datetime.now(), "chunks_indexed": 1},
        ])
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        response = await service.list_documents("l1", "p1", unit_id="unit-A")

        returned_ids = {doc.doc_id for doc in response.documents}
        self.assertEqual(returned_ids, {"doc-1", "doc-3", "doc-4"})
        self.assertEqual(response.total_count, 3)
        labels = {doc.doc_id: doc.unit_label for doc in response.documents}
        self.assertEqual(labels["doc-1"], "Unit A")
        self.assertIsNone(labels["doc-4"])

    async def test_delete_documents_for_property_empty_is_noop_success(self):
        fake_db = _FakeDB(docs=[], chunks=[])
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.delete_documents_for_property(landlord_id="l1", property_id="p1")

        self.assertEqual(result["documents_deleted"], 0)
        self.assertEqual(result["chunks_deleted"], 0)


class DocuMindUnassignUnitTests(unittest.IsolatedAsyncioTestCase):
    def _db_with_unit_docs(self):
        return _FakeDB(
            docs=[
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-A", "unit_label": "Unit A", "category": "lease"},
                {"doc_id": "doc-B", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-B", "unit_label": "Unit B", "category": "lease"},
                {"doc_id": "doc-C", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": None, "unit_label": None, "category": "insurance"},
            ],
            chunks=[
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-A", "unit_label": "Unit A", "text": "a"},
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-A", "unit_label": "Unit A", "text": "b"},
                {"doc_id": "doc-B", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-B", "unit_label": "Unit B", "text": "c"},
            ],
        )

    async def test_unassign_clears_target_unit_only(self):
        fake_db = self._db_with_unit_docs()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.unassign_unit_documents("l1", "p1", "unit-A")

        self.assertEqual(result["documents_updated"], 1)
        self.assertEqual(result["chunks_updated"], 2)
        doc_a = next(d for d in fake_db.docs if d["doc_id"] == "doc-A")
        self.assertIsNone(doc_a["unit_id"])
        self.assertIsNone(doc_a["unit_label"])
        doc_b = next(d for d in fake_db.docs if d["doc_id"] == "doc-B")
        self.assertEqual(doc_b["unit_id"], "unit-B")
        self.assertEqual(doc_b["unit_label"], "Unit B")
        for chunk in fake_db.chunks:
            if chunk["doc_id"] == "doc-A":
                self.assertIsNone(chunk["unit_id"])
                self.assertIsNone(chunk["unit_label"])
            if chunk["doc_id"] == "doc-B":
                self.assertEqual(chunk["unit_id"], "unit-B")

    async def test_unassign_is_idempotent(self):
        fake_db = self._db_with_unit_docs()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.unassign_unit_documents("l1", "p1", "unit-A")
        second = await service.unassign_unit_documents("l1", "p1", "unit-A")

        self.assertEqual(second["documents_updated"], 0)
        self.assertEqual(second["chunks_updated"], 0)


class UnitMentionResolutionTests(unittest.TestCase):
    _UNITS = [
        {"unit_id": "unit-A", "label": "Unit A-12-03"},
        {"unit_id": "unit-B", "label": "Unit B-08-11"},
    ]

    def test_no_unit_signal_is_none(self):
        result = resolve_unit_mention("what is the insurance deductible?", self._UNITS)
        self.assertEqual(result["kind"], "none")

    def test_short_reference_scopes_to_unique_unit(self):
        result = resolve_unit_mention("What is Unit A's monthly rent?", self._UNITS)
        self.assertEqual(result["kind"], "scoped")
        self.assertEqual(result["unit"]["unit_id"], "unit-A")

    def test_full_label_scopes(self):
        result = resolve_unit_mention("does unit b-08-11 allow pets?", self._UNITS)
        self.assertEqual(result["kind"], "scoped")
        self.assertEqual(result["unit"]["unit_id"], "unit-B")

    def test_unknown_unit_reference(self):
        result = resolve_unit_mention("monthly rent for unit D please", self._UNITS)
        self.assertEqual(result["kind"], "unknown")
        self.assertEqual(result["mention"], "Unit D")

    def test_aggregate_phrasing(self):
        result = resolve_unit_mention(
            "what is the total monthly rent across all units?", self._UNITS
        )
        self.assertEqual(result["kind"], "aggregate")

    def test_two_full_labels_is_deliberate_multi(self):
        result = resolve_unit_mention(
            "compare unit a-12-03 and unit b-08-11 rent", self._UNITS
        )
        self.assertEqual(result["kind"], "multi")

    def test_prefix_collision_is_ambiguous(self):
        units = [
            {"unit_id": "unit-A1", "label": "Unit A-1"},
            {"unit_id": "unit-A2", "label": "Unit A-2"},
        ]
        result = resolve_unit_mention("rent for unit a?", units)
        self.assertEqual(result["kind"], "ambiguous")
        self.assertEqual(len(result["candidates"]), 2)

    def test_reference_never_matches_across_segment_boundary(self):
        units = [{"unit_id": "unit-AB", "label": "Unit AB-2"}]
        result = resolve_unit_mention("rent for unit a?", units)
        self.assertEqual(result["kind"], "unknown")


class CategoryTaxonomyIngestTests(unittest.IsolatedAsyncioTestCase):
    def _upload_file(self):
        class _FakeUploadFile:
            filename = "doc.pdf"

            async def read(self):
                return b"%PDF-1.4 fake content"

        return _FakeUploadFile()

    async def test_ingest_rejects_unknown_category(self):
        service = _build_service(
            _FakeDB(), _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        with self.assertRaises(ValueError):
            await service.ingest_document(
                landlord_id="l1",
                property_id="p1",
                category="bank-statement",
                file=self._upload_file(),
            )

    async def test_ingest_normalizes_legacy_category_before_storing(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            fake_page = MagicMock()
            fake_page.page_content = "TNB electricity bill for the unit's aircon repair"
            fake_page.metadata = {"page": 0}
            loader_mock.return_value.load.return_value = [fake_page]

            response = await service.ingest_document(
                landlord_id="l1",
                property_id="p1",
                category="utility",
                file=self._upload_file(),
            )

        self.assertEqual(response.category, "upkeep")
        stored_doc = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored_doc["category"], "upkeep")
        self.assertTrue(all(c["category"] == "upkeep" for c in fake_db.chunks))


class CategoryAliasReadPathTests(unittest.IsolatedAsyncioTestCase):
    async def test_available_categories_normalize_legacy_names(self):
        fake_db = _FakeDB(docs=[
            {"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "utility"},
            {"doc_id": "d2", "landlord_id": "l1", "property_id": "p1", "category": "receipt"},
            {"doc_id": "d3", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
        ])
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        self.assertEqual(
            service._list_available_categories("l1", "p1"),
            ["lease", "upkeep", "rental_invoice"],
        )

    async def test_legacy_chunks_match_new_filter_and_citations_normalize(self):
        fake_db = _FakeDB(
            docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "utility"}],
            chunks=[{
                "doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
                "category": "utility", "filename": "aircon.pdf", "chunk_index": 0,
                "text": "Aircon servicing invoice RM 180 dated 12 March 2026", "page": 0,
            }],
        )
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["upkeep"],
            "prediction_confidence": 0.9,
            "prediction_reason": "repair question",
            "intent": "document_question",
        })
        service = _build_service(
            fake_db, _FakeConversationStore(), fake_graph, _FakeLLM("Serviced on 12 March 2026.")
        )
        response = await service.ask_documind(
            AskRequest(landlord_id="l1", property_id="p1", question="when was the aircon serviced?")
        )
        self.assertEqual(
            service._hybrid_retriever.calls[0]["categories"],
            ["upkeep", "utility", "warranty"],
        )
        self.assertEqual(response.searched_categories, ["upkeep"])
        self.assertEqual(response.citations[0].category, "upkeep")

    async def test_list_documents_returns_normalized_categories(self):
        fake_db = _FakeDB(docs=[{
            "doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
            "category": "receipt", "filename": "inv.pdf", "chunks_indexed": 2,
            "file_size": 100, "uploaded_at": datetime(2026, 1, 1),
        }])
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        response = await service.list_documents("l1", "p1")
        self.assertEqual(response.documents[0].category, "rental_invoice")


if __name__ == "__main__":
    unittest.main()