import unittest
from datetime import datetime
from unittest.mock import MagicMock, PropertyMock, patch

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

    def delete(self, ref):
        self._ops.append(("delete", ref, None))

    def commit(self):
        for op, ref, data in self._ops:
            if op == "set":
                ref.set(data)
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
            return _FakePropertyRef(self._db.property_name)
        if self._name == "documind_docs":
            return _FakeDocDocRef(self._db, _doc_id)
        if self._name == "documind_chunks":
            return _FakeChunkDocRef(self._db)
        raise NotImplementedError("document() only used for properties, documind_docs, documind_chunks in these tests")


class _FakeDB:
    def __init__(self, docs=None, chunks=None, property_name="Test Property"):
        self.docs = docs or []
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


if __name__ == "__main__":
    unittest.main()