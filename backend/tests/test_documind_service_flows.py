import unittest
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, PropertyMock, patch

from models.documind_models import AskRequest, FinanceSummaryResponse, FinanceTotals
from rag.documind_service import DocuMindService, resolve_unit_mention
from rag.documents.fact_extractor import FactExtractor
from rag.finance.finance_overrides_repository import FinanceOverridesRepository
from rag.documents.document_lifecycle_service import DocumentLifecycleService
from rag.documents.ingestion_service import IngestionService
from rag.ask.ask_orchestrator import AskOrchestrator


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
    def __init__(self):
        self.embed_documents_calls = []

    def embed_query(self, _question: str):
        return [0.1, 0.2, 0.3]

    def embed_documents(self, texts):
        self.embed_documents_calls.append(list(texts))
        return [[0.1, 0.2, 0.3] for _ in texts]


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
    def __init__(self, unit_id, label, ownership_share=None):
        self.id = unit_id
        self._label = label
        self._ownership_share = ownership_share

    def to_dict(self):
        data = {"label": self._label}
        # Absent, not null: a unit that has never had a share set stores no
        # field at all, and `None` is what tells the engine to inherit.
        if self._ownership_share is not None:
            data["ownership_share"] = self._ownership_share
        return data


class _FakeUnitsCollection:
    def __init__(self, units):
        self._units = units

    def stream(self):
        return [
            _FakeUnitSnapshot(u["unit_id"], u["label"], u.get("ownership_share"))
            for u in self._units
        ]


class _FakePropertyRef:
    def __init__(self, db, doc_id, property_name: str, units=None):
        self._db = db
        self._doc_id = doc_id
        self._property_name = property_name
        self._units = units or []

    def get(self):
        landlord_id = self._db.property_owners.get(self._doc_id)
        return _FakePropertyDoc(
            exists=True,
            data={"name": self._property_name, "landlordId": landlord_id},
        )

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
        elif self._name == "properties":
            rows = self._db.properties_rows
        elif self._name == "documind_payment_exceptions":
            rows = self._db.payment_exceptions
        elif self._name == "documind_document_exceptions":
            rows = self._db.document_exceptions
        elif self._name == "documind_rent_recoveries":
            rows = self._db.rent_recoveries
        elif self._name == "documind_manual_loan_entries":
            rows = self._db.manual_loan_entries
        elif self._name == "documind_unit_loan_exemptions":
            rows = self._db.unit_loan_exemptions
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


class _FakePaymentExceptionRef:
    def __init__(self, db, doc_id):
        self._db = db
        self._doc_id = doc_id

    def set(self, data):
        self._db.payment_exceptions = [
            row for row in self._db.payment_exceptions if row.get("doc_id") != self._doc_id
        ]
        self._db.payment_exceptions.append({**data, "doc_id": self._doc_id})

    def get(self):
        for row in self._db.payment_exceptions:
            if row.get("doc_id") == self._doc_id:
                return _FakePropertyDoc(exists=True, data=row)
        return _FakePropertyDoc(exists=False, data={})

    def delete(self):
        self._db.payment_exceptions = [
            row for row in self._db.payment_exceptions if row.get("doc_id") != self._doc_id
        ]


class _FakeDocumentExceptionRef:
    def __init__(self, db, doc_id):
        self._db = db
        self._doc_id = doc_id

    def set(self, data):
        self._db.document_exceptions = [
            row for row in self._db.document_exceptions if row.get("doc_id") != self._doc_id
        ]
        self._db.document_exceptions.append({**data, "doc_id": self._doc_id})

    def get(self):
        for row in self._db.document_exceptions:
            if row.get("doc_id") == self._doc_id:
                return _FakePropertyDoc(exists=True, data=row)
        return _FakePropertyDoc(exists=False, data={})

    def delete(self):
        self._db.document_exceptions = [
            row for row in self._db.document_exceptions if row.get("doc_id") != self._doc_id
        ]


class _FakeRentRecoveryRef:
    def __init__(self, db, doc_id):
        self._db = db
        self._doc_id = doc_id

    def set(self, data):
        self._db.rent_recoveries = [
            row for row in self._db.rent_recoveries if row.get("doc_id") != self._doc_id
        ]
        self._db.rent_recoveries.append({**data, "doc_id": self._doc_id})

    def get(self):
        for row in self._db.rent_recoveries:
            if row.get("doc_id") == self._doc_id:
                return _FakePropertyDoc(exists=True, data=row)
        return _FakePropertyDoc(exists=False, data={})

    def delete(self):
        self._db.rent_recoveries = [
            row for row in self._db.rent_recoveries if row.get("doc_id") != self._doc_id
        ]


class _FakeManualLoanEntryRef:
    def __init__(self, db, doc_id):
        self._db = db
        self._doc_id = doc_id

    def set(self, data):
        self._db.manual_loan_entries = [
            row for row in self._db.manual_loan_entries if row.get("doc_id") != self._doc_id
        ]
        self._db.manual_loan_entries.append({**data, "doc_id": self._doc_id})

    def get(self):
        for row in self._db.manual_loan_entries:
            if row.get("doc_id") == self._doc_id:
                return _FakePropertyDoc(exists=True, data=row)
        return _FakePropertyDoc(exists=False, data={})

    def delete(self):
        self._db.manual_loan_entries = [
            row for row in self._db.manual_loan_entries if row.get("doc_id") != self._doc_id
        ]


class _FakeUnitLoanExemptionRef:
    def __init__(self, db, doc_id):
        self._db = db
        self._doc_id = doc_id

    def set(self, data):
        self._db.unit_loan_exemptions = [
            row for row in self._db.unit_loan_exemptions if row.get("doc_id") != self._doc_id
        ]
        self._db.unit_loan_exemptions.append({**data, "doc_id": self._doc_id})

    def get(self):
        for row in self._db.unit_loan_exemptions:
            if row.get("doc_id") == self._doc_id:
                return _FakePropertyDoc(exists=True, data=row)
        return _FakePropertyDoc(exists=False, data={})

    def delete(self):
        self._db.unit_loan_exemptions = [
            row for row in self._db.unit_loan_exemptions if row.get("doc_id") != self._doc_id
        ]


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
                self._db, _doc_id, self._db.property_name, getattr(self._db, "units", [])
            )
        if self._name == "documind_docs":
            return _FakeDocDocRef(self._db, _doc_id)
        if self._name == "documind_chunks":
            return _FakeChunkDocRef(self._db)
        if self._name == "documind_payment_exceptions":
            return _FakePaymentExceptionRef(self._db, _doc_id)
        if self._name == "documind_document_exceptions":
            return _FakeDocumentExceptionRef(self._db, _doc_id)
        if self._name == "documind_rent_recoveries":
            return _FakeRentRecoveryRef(self._db, _doc_id)
        if self._name == "documind_manual_loan_entries":
            return _FakeManualLoanEntryRef(self._db, _doc_id)
        if self._name == "documind_unit_loan_exemptions":
            return _FakeUnitLoanExemptionRef(self._db, _doc_id)
        raise NotImplementedError("document() only used for properties, documind_docs, documind_chunks, documind_payment_exceptions, documind_document_exceptions, documind_rent_recoveries, documind_manual_loan_entries, documind_unit_loan_exemptions in these tests")


class _FakeDB:
    def __init__(self, docs=None, chunks=None, property_name="Test Property", units=None,
                 payment_exceptions=None, property_owners=None, document_exceptions=None,
                 rent_recoveries=None, manual_loan_entries=None, unit_loan_exemptions=None):
        self.docs = docs or []
        self.units = units or []
        self.chunks = chunks or []
        self.properties_rows = []
        self.document_exceptions = document_exceptions or []
        self.rent_recoveries = rent_recoveries or []
        self.manual_loan_entries = manual_loan_entries or []
        self.unit_loan_exemptions = unit_loan_exemptions or []
        self.payment_exceptions = payment_exceptions or []
        self.property_name = property_name
        self.property_owners = property_owners or {}
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


class _FakePdfOcr:
    """Stands in for PdfOcr: returns canned transcripts (None = OCR failed
    or produced nothing) and counts invocations."""

    def __init__(self, transcripts=None):
        self.transcripts = transcripts
        self.calls = 0

    def transcribe(self, pdf_bytes):
        self.calls += 1
        return self.transcripts


class _LivePdfOcrProxy:
    """Delegates to service._pdf_ocr at call time. IngestionService captures
    its pdf_ocr collaborator once at construction (mirroring production,
    where self._pdf_ocr never changes after __init__), but several tests
    below reassign service._pdf_ocr after _build_service() returns. This
    proxy keeps ingest_document seeing whatever object currently sits at
    service._pdf_ocr instead of the one that existed at wiring time."""

    def __init__(self, service):
        self._service = service

    def transcribe(self, *args, **kwargs):
        return self._service._pdf_ocr.transcribe(*args, **kwargs)


# NOTE: the collaborators below (_finance_overrides, _document_lifecycle,
# _ingestion_service, _ask_orchestrator) capture db/conversation_store/
# graph_orchestrator/hybrid_retriever/etc. eagerly at construction time.
# Reassigning service._X after this function returns does NOT reach them —
# also repoint the corresponding attribute on the relevant collaborator.
def _build_service(fake_db, fake_store, fake_graph, fake_llm):
    service = DocuMindService.__new__(DocuMindService)
    service._db = fake_db
    service._finance_overrides = FinanceOverridesRepository(fake_db)
    service._document_lifecycle = DocumentLifecycleService(fake_db, lambda: service.storage_bucket)
    service._embeddings = _FakeEmbeddings()
    service._llm = fake_llm
    service._conversation_store = fake_store
    service._graph_orchestrator = fake_graph
    service._hybrid_retriever = _FakeHybridRetriever(fake_db)
    service._fact_extractor = FactExtractor(fake_llm)
    service._pdf_ocr = _FakePdfOcr()
    service._ingestion_service = IngestionService(
        db=fake_db,
        storage_bucket_getter=lambda: service.storage_bucket,
        embeddings_getter=lambda: service.embeddings,
        pdf_ocr=_LivePdfOcrProxy(service),
        extractor_for=service._extractor_for,
    )
    service._ask_orchestrator = AskOrchestrator(
        conversation_store=service._conversation_store,
        graph_orchestrator=service._graph_orchestrator,
        hybrid_retriever=service._hybrid_retriever,
        llm_getter=lambda: service.llm,
        list_available_categories=service._list_available_categories,
        get_property_name=service._get_property_name,
        list_property_units=service._list_property_units,
        get_finance_summary=service.get_finance_summary,
        get_document_facts=service._get_document_facts,
    )
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

        payload = AskRequest(property_id="p1", question="zzz qqq")
        response = await service.ask_documind(payload, "l1")

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

        payload = AskRequest(property_id="p1", question="what is covered")
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="cancel that",
            session_id="session-9",
            user_action="cancel",
        )
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="yes",
            session_id="session-1",
            user_action="confirm",
        )

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="choose upkeep",
            session_id="session-2",
            user_action="override:upkeep",
        )

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            response = await service.ask_documind(payload, "l1")

        self.assertEqual(response.category_filter_mode, "clarification_selected")
        self.assertEqual(response.searched_categories, ["upkeep"])
        self.assertEqual(
            fake_db.last_chunk_category_filter,
            ("in", ["upkeep", "utility", "warranty", "expenses"]),
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

        payload = AskRequest(property_id="p1", question="when does the lease end")
        response = await service.ask_documind(payload, "l1")

        citations_by_doc = {c.doc_id: c for c in response.citations}
        self.assertEqual(citations_by_doc["d1"].unit_id, "unit-A")
        self.assertEqual(citations_by_doc["d1"].unit_label, "Unit A")
        self.assertIsNone(citations_by_doc["d2"].unit_id)
        self.assertIsNone(citations_by_doc["d2"].unit_label)
        self.assertIn("— Unit A]", fake_llm.last_prompt)
        self.assertIn("— Property-wide]", fake_llm.last_prompt)

    def _ask_with_retriever_error(self, exc):
        """Helper to test retrieval error handling.

        Builds the orchestrator with a _hybrid_retriever that raises exc
        on retrieve, runs one ask_documind, and returns the AskResponse.
        """
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}],
        )
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["lease"],
            "prediction_reason": "lease question",
            "intent": "document_question",
        })

        # Build service and immediately replace the retriever with one that raises
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("unused"))

        class _ErrorRaisingRetriever:
            async def retrieve(self, **kwargs):
                raise exc

        service._hybrid_retriever = _ErrorRaisingRetriever()
        service._ask_orchestrator._hybrid_retriever = _ErrorRaisingRetriever()

        # Run the question
        import asyncio
        payload = AskRequest(property_id="p1", question="test question")
        response = asyncio.run(service.ask_documind(payload, "l1"))
        return response

    def test_index_error_tells_the_landlord_the_index_is_building(self):
        from google.api_core.exceptions import FailedPrecondition
        response = self._ask_with_retriever_error(
            FailedPrecondition("The query requires a vector index.")
        )
        self.assertIn("still building", response.answer)
        self.assertEqual(response.action_reason, "Vector index unavailable")

    def test_provider_error_reads_as_temporary(self):
        response = self._ask_with_retriever_error(
            ConnectionError("connection refused: localhost:11434")
        )
        self.assertIn("temporarily unavailable", response.answer)
        self.assertEqual(response.action_reason, "Retrieval backend unavailable")

    def test_unexpected_error_does_not_blame_the_index(self):
        response = self._ask_with_retriever_error(KeyError("doc_id"))
        self.assertIn("Something went wrong", response.answer)
        self.assertNotIn("index", response.answer.lower())
        self.assertEqual(response.action_reason, "Retrieval failure")


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

        payload = AskRequest(property_id="p1", question="when does the lease expire?")
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1", question="When does unit A's lease expire?"
        )
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1", question="What is the rent for unit D?"
        )
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="What is the total monthly rent across all units?",
        )
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="when does the tenancy for the second unit end?",
        )
        response = await service.ask_documind(payload, "l1")

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

        payload = AskRequest(property_id="p1", question="rent for unit D?")
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1", question="what is the rent for unit A?"
        )
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="Unit A",
            session_id="session-7",
            user_action="unit:unit-A",
        )
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="All units",
            session_id="session-8",
            user_action="unit:all",
        )
        response = await service.ask_documind(payload, "l1")

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

        payload = AskRequest(property_id="p1", question="when does the lease expire?")
        response = await service.ask_documind(payload, "l1")

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
            property_id="p1",
            question="Unit A",
            session_id="session-scope",
            user_action="unit:unit-A",
        )
        response = await service.ask_documind(payload, "l1")

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
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
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

    async def test_ingest_document_reports_pipeline_stages_in_order(self):
        fake_db = _FakeDB()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = _FakeStorageBucket()

        stages = []

        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return b"%PDF-1.4 fake content"

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
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
                progress=lambda stage: stages.append(stage),
            )

        self.assertEqual(stages, ["received", "reading", "organising", "indexing", "details"])
        self.assertEqual(response.status, "indexed")

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
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
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
            AskRequest(property_id="p1", question="when was the aircon serviced?"), "l1"
        )
        self.assertEqual(
            service._hybrid_retriever.calls[0]["categories"],
            ["upkeep", "utility", "warranty", "expenses"],
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


class FactExtractionIngestTests(unittest.IsolatedAsyncioTestCase):
    def _upload_file(self):
        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return b"%PDF-1.4 fake content"

        return _FakeUploadFile()

    def _patched_loader_page(self, text="Tenancy agreement: rent RM 1,500 monthly."):
        fake_page = MagicMock()
        fake_page.page_content = text
        fake_page.metadata = {"page": 0}
        return fake_page

    async def test_extraction_failure_never_blocks_ingest(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        class _RaisingExtractor:
            def extract(self, category, text):
                raise RuntimeError("extractor exploded")

        service._fact_extractor = _RaisingExtractor()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [self._patched_loader_page()]

            response = await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        self.assertEqual(response.status, "indexed")
        self.assertIsNone(response.extracted_facts)
        self.assertEqual(response.facts_status, "needs_review")
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertIsNone(stored["extracted_facts"])
        self.assertIsNone(stored["facts_confidence"])
        self.assertEqual(stored["facts_status"], "needs_review")

    async def test_successful_extraction_lands_in_metadata_and_response(self):
        fake_db = _FakeDB()
        fake_llm = _FakeLLM('{"monthly_rent": 1500, "lease_start": "2025-09-01", '
                            '"lease_end": "2026-09-01", "confidence": 0.9}')
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), fake_llm
        )
        service._storage_bucket = _FakeStorageBucket()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [self._patched_loader_page()]

            response = await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        expected_facts = {
            "monthly_rent": 1500.0,
            "lease_start": "2025-09-01",
            "lease_end": "2026-09-01",
        }
        self.assertEqual(response.extracted_facts, expected_facts)
        self.assertEqual(response.facts_confidence, 0.9)
        self.assertEqual(response.facts_status, "ok")
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored["extracted_facts"], expected_facts)
        self.assertEqual(stored["facts_confidence"], 0.9)
        self.assertEqual(stored["facts_status"], "ok")
        self.assertIsNotNone(stored["facts_extracted_at"])

    async def test_list_documents_passes_extraction_fields_through(self):
        fake_db = _FakeDB(docs=[
            {
                "doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
                "category": "tax", "filename": "quitrent.pdf", "chunks_indexed": 1,
                "file_size": 50, "uploaded_at": datetime(2026, 1, 1),
                "extracted_facts": {"amount": 460.63, "period_year": 2026, "subtype": "quit_rent"},
                "facts_confidence": 0.9,
            },
            {
                "doc_id": "d2", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "old.pdf", "chunks_indexed": 1,
                "file_size": 50, "uploaded_at": datetime(2025, 1, 1),
            },
        ])
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        response = await service.list_documents("l1", "p1")
        by_id = {d.doc_id: d for d in response.documents}
        self.assertEqual(by_id["d1"].extracted_facts["subtype"], "quit_rent")
        self.assertEqual(by_id["d1"].facts_confidence, 0.9)
        self.assertEqual(by_id["d1"].facts_status, "ok")
        self.assertIsNone(by_id["d2"].extracted_facts)
        self.assertIsNone(by_id["d2"].facts_confidence)
        self.assertEqual(by_id["d2"].facts_status, "needs_review")

    async def test_list_documents_computes_sub_category_tags(self):
        fake_db = _FakeDB(docs=[{
            "doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
            "category": "tax", "filename": "quitrent.pdf", "chunks_indexed": 1,
            "file_size": 50, "uploaded_at": datetime(2026, 1, 1),
            "extracted_facts": {"amount": 460.63, "period_year": 2026, "subtype": "quit_rent"},
            "facts_confidence": 0.9,
        }])
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        response = await service.list_documents("l1", "p1")
        self.assertEqual(len(response.documents[0].tags), 1)
        self.assertEqual(response.documents[0].tags[0].tag, "quit_rent")
        self.assertEqual(response.documents[0].tags[0].rhythm, "one_off")


class OcrIngestTests(unittest.IsolatedAsyncioTestCase):
    def _upload_file(self):
        class _FakeUploadFile:
            filename = "scanned.pdf"

            async def read(self):
                return b"%PDF-1.4 fake scanned content"

        return _FakeUploadFile()

    def _page(self, text):
        fake_page = MagicMock()
        fake_page.page_content = text
        fake_page.metadata = {"page": 0}
        return fake_page

    async def _ingest(self, service, pages):
        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = pages
            return await service.ingest_document(
                landlord_id="l1", property_id="p1", category="upkeep", file=self._upload_file(),
            )

    async def test_scanned_pdf_triggers_ocr_and_indexes_transcript(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()
        service._pdf_ocr = _FakePdfOcr(transcripts=[
            "INVOIS: Servis penyaman udara RM 180, 12 Mac 2026",
        ])

        response = await self._ingest(service, [self._page("")])

        self.assertEqual(service._pdf_ocr.calls, 1)
        self.assertGreater(response.chunks_indexed, 0)
        self.assertIn("penyaman udara", fake_db.chunks[0]["text"])

    async def test_digital_pdf_never_triggers_ocr(self):
        service = _build_service(
            _FakeDB(), _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        long_text = "This tenancy agreement is made between the landlord and tenant. " * 10
        await self._ingest(service, [self._page(long_text)])

        self.assertEqual(service._pdf_ocr.calls, 0)

    async def test_ocr_failure_still_indexes_with_zero_chunks(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()
        service._pdf_ocr = _FakePdfOcr(transcripts=None)

        response = await self._ingest(service, [self._page("")])

        self.assertEqual(response.status, "indexed")
        self.assertEqual(response.chunks_indexed, 0)
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored["chunks_indexed"], 0)


class FinanceSummaryServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_get_finance_summary_folds_firestore_docs(self):
        fake_db = _FakeDB(docs=[
            {
                "doc_id": "inv-1", "landlord_id": "l1", "property_id": "p1",
                "category": "rental_invoice", "filename": "inv.pdf",
                "uploaded_at": datetime(2025, 3, 2),
                "extracted_facts": {"amount": 2000.0, "period_month": "2025-03"},
            },
            {
                # Legacy category: must fold as an upkeep expense (alias)
                "doc_id": "upk-1", "landlord_id": "l1", "property_id": "p1",
                "category": "utility", "filename": "aircon.pdf",
                "uploaded_at": datetime(2025, 4, 12),
                "extracted_facts": {"amount": 300.0, "service_date": "2025-04-10"},
            },
            {
                # Pre-feature doc without facts: silently skipped
                "doc_id": "old-1", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "old.pdf",
                "uploaded_at": datetime(2024, 1, 1),
            },
        ], document_exceptions=[
            # No profile is set, so every FINANCE_CATEGORIES slot is
            # expected; mark the ones this fixture never intended to
            # exercise unavailable so completeness doesn't withhold the
            # statutory figure under test.
            {"landlord_id": "l1", "property_id": "p1", "year": 2025, "category": c}
            for c in ("loan", "tax", "maintenance", "insurance")
        ])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Kiara Court", "ownership_share": 0.5},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        self.assertEqual(summary.year, 2025)
        block = summary.properties[0]
        self.assertEqual(block.name, "Kiara Court")
        self.assertEqual(block.ownership_share, 0.5)
        self.assertEqual(block.received_rent, 1000.0)
        self.assertEqual(block.direct_expenses, 150.0)
        self.assertEqual(block.rental_income_or_loss, 850.0)
        self.assertEqual(block.expense_lines[0].category, "upkeep")
        # statutory: 0.5 * (2000 - 300 * (1 rented month / 12)) = 987.50
        self.assertEqual(summary.totals.statutory_rental_income, 987.5)

    async def test_get_finance_summary_defaults_missing_state_to_outstanding(self):
        fake_db = _FakeDB(payment_exceptions=[
            {"landlord_id": "l1", "property_id": "p1", "unit_id": None, "month": "2025-03", "reason": None},
        ])
        fake_db.properties_rows = [{"doc_id": "p1", "landlordId": "l1", "name": "House"}]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        summary = await service.get_finance_summary("l1", 2025)
        march = next(
            m for m in summary.properties[0].units[0].months if m.month == 3
        )
        self.assertEqual(march.payment_state, "outstanding")

    async def test_get_finance_summary_folds_a_rent_recovery(self):
        fake_db = _FakeDB(rent_recoveries=[
            {"landlord_id": "l1", "property_id": "p1", "unit_id": None, "original_month": "2025-08",
             "amount": 3000.0, "received_year": 2026},
        ])
        fake_db.properties_rows = [{"doc_id": "p1", "landlordId": "l1", "name": "House"}]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        summary = await service.get_finance_summary("l1", 2026)

        self.assertEqual(summary.properties[0].recovered_rent[0].amount, 3000.0)

    async def test_get_finance_summary_reads_utilities_policy(self):
        statement = {
            "doc_id": "exp-1", "landlord_id": "l1", "property_id": "p1",
            "category": "expenses", "filename": "feb.pdf",
            "uploaded_at": datetime(2025, 2, 10),
            "extracted_facts": {"expense_lines": [
                {"subtype": "maintenance", "amount": 764.00, "date": "2025-02-01"},
                {"subtype": "utilities", "amount": 132.21, "date": "2025-02-01"},
            ]},
        }
        fake_db = _FakeDB(docs=[statement])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Ayer8",
             "utilities_paid_by": "landlord"},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        self.assertEqual(summary.totals.direct_expenses, 896.21)
        utilities = next(
            l for l in summary.properties[0].expense_lines if l.subtype == "utilities"
        )
        self.assertTrue(utilities.deductible)

    async def test_get_finance_summary_reads_property_profile(self):
        fake_db = _FakeDB()
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Kiara Court",
             "property_type": "strata", "has_mortgage": False},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        missing = summary.missing_categories.get("p1", [])
        self.assertNotIn("insurance", missing)
        self.assertNotIn("loan", missing)
        self.assertIn("maintenance", missing)

    async def test_get_finance_summary_reads_track_from_year(self):
        lease = {
            "doc_id": "lease-1", "landlord_id": "l1", "property_id": "p1",
            "category": "lease", "filename": "lease.pdf",
            "uploaded_at": datetime(2020, 1, 1),
            "extracted_facts": {
                "monthly_rent": 1000.0, "lease_start": "2020-01-01", "lease_end": "2026-12-31",
            },
        }
        fake_db = _FakeDB(docs=[lease])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Kiara Court", "track_from_year": 2023},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        years = [row.year for row in summary.properties[0].coverage]
        self.assertNotIn(2020, years)
        self.assertNotIn(2022, years)
        self.assertIn(2023, years)

    async def test_get_finance_summary_no_properties_is_empty(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        summary = await service.get_finance_summary("l1", 2025)
        self.assertEqual(summary.properties, [])
        self.assertEqual(summary.totals.net_pl, 0.0)

    async def test_get_finance_summary_preserves_unit_id_on_manual_loan_read(self):
        # Regression: the read loop in get_finance_summary dropped unit_id when
        # rebuilding manual_loan_entries dicts from Firestore, so a unit-scoped
        # entry (stored WITH unit_id) came back property-scoped and per-unit
        # loan completeness never resolved.
        fake_db = _FakeDB(
            property_owners={"p1": "l1"},
            units=[{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}],
        )
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Block",
             "property_type": "landed", "has_mortgage": True,
             "loan_input_cadence": "annual"},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", unit_id="u1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )

        summary = await service.get_finance_summary("l1", 2025)

        block = summary.properties[0]
        u1 = next(u for u in block.units if u.unit_id == "u1")
        u2 = next(u for u in block.units if u.unit_id == "u2")
        u1_loan = [l for l in u1.expense_lines if l.subtype == "interest_statement"]
        self.assertEqual(sum(l.amount for l in u1_loan), 5000.0)
        self.assertTrue(all(l.unit_id == "u1" for l in u1_loan))
        self.assertEqual(u1.loan_status, "complete")
        self.assertEqual(u2.loan_status, "incomplete")

    async def test_get_finance_summary_reads_the_property_basis_default(self):
        statement = {
            "doc_id": "exp-1", "landlord_id": "l1", "property_id": "p1",
            "category": "expenses", "filename": "feb.pdf",
            "uploaded_at": datetime(2025, 2, 10),
            "extracted_facts": {"expense_lines": [
                {"subtype": "maintenance", "amount": 800.00, "date": "2025-02-01"},
            ]},
        }
        fake_db = _FakeDB(docs=[statement])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Ayer8",
             "ownership_share": 0.5, "share_basis_default": "mine"},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        # Already split by the agent: booked whole, not halved a second time.
        self.assertEqual(summary.totals.direct_expenses, 800.00)

    async def test_get_finance_summary_reads_the_documents_own_basis(self):
        # THE PLUMBING GATE. The engine handles `share_basis` on a document,
        # but this method builds its document dicts by naming keys — a missing
        # name here leaves the review sheet's chip writing to a field nothing
        # ever reads, with every engine test still green.
        statement = {
            "doc_id": "exp-1", "landlord_id": "l1", "property_id": "p1",
            "category": "expenses", "filename": "feb.pdf",
            "uploaded_at": datetime(2025, 2, 10),
            "share_basis": "full",
            "extracted_facts": {"expense_lines": [
                {"subtype": "maintenance", "amount": 800.00, "date": "2025-02-01"},
            ]},
        }
        fake_db = _FakeDB(docs=[statement])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Ayer8",
             "ownership_share": 0.5, "share_basis_default": "mine"},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        # The document says otherwise, and the document wins.
        self.assertEqual(summary.totals.direct_expenses, 400.00)


def _fake_finance_summary():
    return FinanceSummaryResponse(
        year=2025,
        totals=FinanceTotals(
            received_rent=219000.0,
            derived_rent=0.0,
            direct_expenses=158893.42,
            net_pl=60106.58,
            statutory_rental_income=60106.58,
            statutory_note="Estimate — for your tax agent",
        ),
        expense_breakdown={"loan": 97000.0},
        properties=[],
        caveats=["Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed."],
        missing_categories={},
    )


class FinanceChatFlowTests(unittest.IsolatedAsyncioTestCase):
    def _finance_graph(self, year=2025):
        return _FakeGraphOrchestrator({
            "action": "finance",
            "finance_year": year,
            "intent": "finance_question",
            "intent_reason": "asks for computed profit",
        })

    async def test_finance_action_narrates_engine_output(self):
        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        narration = "Your 2025 statutory rental income is RM 60,106.58 (Estimate — for your tax agent)."
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(), _FakeLLM(narration)
        )
        service.get_finance_summary = AsyncMock(return_value=_fake_finance_summary())
        # Reassigned after construction: AskOrchestrator captured the earlier
        # bound method at _build_service() time, so it needs to be repointed
        # at the mock too (same hazard as the _pdf_ocr proxy in Task 6).
        service._ask_orchestrator._get_finance_summary = service.get_finance_summary

        response = await service.ask_documind(
            AskRequest(property_id="p1", question="how much profit did I make in 2025?"), "l1"
        )

        service.get_finance_summary.assert_awaited_once_with("l1", 2025)
        self.assertEqual(response.answer, narration)
        self.assertEqual(response.category_filter_mode, "finance")
        self.assertEqual(response.citations, [])
        self.assertFalse(response.user_action_required)

    async def test_finance_path_never_retrieves_document_chunks(self):
        # Privacy lock: finance answers must be built ONLY from the engine's
        # computed figures (from extracted_facts), never from raw chunks. Any
        # chunk retrieval on this path would send confidential document text to
        # the hosted LLM — so a retrieve() call here is a regression, and this
        # exploding retriever turns it into a test failure.
        class _ExplodingRetriever:
            def __init__(self):
                self.called = False

            async def retrieve(self, *args, **kwargs):
                self.called = True
                raise AssertionError("finance path must not retrieve document chunks")

        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        narration = "Your 2025 statutory rental income is RM 60,106.58."
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(), _FakeLLM(narration)
        )
        service.get_finance_summary = AsyncMock(return_value=_fake_finance_summary())
        service._ask_orchestrator._get_finance_summary = service.get_finance_summary
        exploding = _ExplodingRetriever()
        service._hybrid_retriever = exploding
        # AskOrchestrator also captured its own hybrid_retriever reference at
        # construction time; repoint it too so the exploding stub above is
        # actually reachable and this privacy-lock test still bites on a
        # regression instead of silently passing against the stale fake.
        service._ask_orchestrator._hybrid_retriever = exploding

        response = await service.ask_documind(
            AskRequest(property_id="p1", question="how much profit did I make in 2025?"), "l1"
        )

        self.assertFalse(exploding.called)       # no chunk retrieval at all
        self.assertEqual(response.citations, [])  # nothing chunk-derived returned
        self.assertEqual(response.answer, narration)

    async def test_finance_year_defaults_to_current_year(self):
        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(year=None), _FakeLLM("Narrated.")
        )
        service.get_finance_summary = AsyncMock(return_value=_fake_finance_summary())
        service._ask_orchestrator._get_finance_summary = service.get_finance_summary

        await service.ask_documind(
            AskRequest(property_id="p1", question="how is my rental doing?"), "l1"
        )

        awaited_year = service.get_finance_summary.await_args.args[1]
        self.assertEqual(awaited_year, datetime.now().year)

    async def test_narration_failure_falls_back_to_deterministic_line(self):
        class _RaisingLLM:
            def invoke(self, prompt):
                raise RuntimeError("llm down")

        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(), _RaisingLLM()
        )
        service.get_finance_summary = AsyncMock(return_value=_fake_finance_summary())
        service._ask_orchestrator._get_finance_summary = service.get_finance_summary

        response = await service.ask_documind(
            AskRequest(property_id="p1", question="profit in 2025?"), "l1"
        )

        self.assertIn("60,106.58", response.answer)
        self.assertIn("Estimate — for your tax agent", response.answer)

    async def test_engine_failure_returns_apology_not_exception(self):
        fake_db = _FakeDB(docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "lease"}])
        service = _build_service(
            fake_db, _FakeConversationStore(), self._finance_graph(), _FakeLLM("unused")
        )
        service.get_finance_summary = AsyncMock(side_effect=RuntimeError("firestore down"))
        service._ask_orchestrator._get_finance_summary = service.get_finance_summary

        response = await service.ask_documind(
            AskRequest(property_id="p1", question="profit in 2025?"), "l1"
        )

        self.assertIn("couldn't compute", response.answer)
        self.assertEqual(response.citations, [])


class EmbeddingClientAndBatchingTests(unittest.IsolatedAsyncioTestCase):
    def test_embeddings_property_creates_client_once_and_caches(self):
        service = DocuMindService.__new__(DocuMindService)
        service._embeddings = None
        # Pin the provider so the test stays hermetic even when the ambient
        # .env sets EMBEDDINGS_PROVIDER=ollama (the local-hybrid runtime).
        with patch.dict("os.environ", {"EMBEDDINGS_PROVIDER": "gemini"}, clear=False), \
                patch("rag.documind_service.GoogleGenerativeAIEmbeddings") as ctor:
            ctor.return_value = MagicMock(name="embeddings_client")
            first = service.embeddings
            second = service.embeddings
        self.assertIs(first, second)
        self.assertEqual(ctor.call_count, 1)

    def test_embeddings_property_selects_ollama_when_provider_flag_set(self):
        from rag.providers.ollama_embeddings import OllamaEmbeddings

        service = DocuMindService.__new__(DocuMindService)
        service._embeddings = None
        with patch.dict("os.environ", {"EMBEDDINGS_PROVIDER": "ollama"}, clear=False):
            client = service.embeddings
        self.assertIsInstance(client, OllamaEmbeddings)

    def test_fact_llm_selects_ollama_when_provider_flag_set(self):
        # Privacy: fact extraction sees the full leading document text
        # (names, addresses, NRIC), so FACT_PROVIDER=ollama must keep it off
        # the hosted client — the sentinel below must NOT be chosen.
        from rag.providers.ollama_chat import OllamaChat

        service = DocuMindService.__new__(DocuMindService)
        service._llm = object()  # hosted client sentinel
        with patch.dict("os.environ", {"FACT_PROVIDER": "ollama"}, clear=False):
            chosen = service._fact_llm()
        self.assertIsInstance(chosen, OllamaChat)

    def test_fact_llm_defaults_to_hosted_client(self):
        service = DocuMindService.__new__(DocuMindService)
        sentinel = object()
        service._llm = sentinel
        with patch.dict("os.environ", {"FACT_PROVIDER": "gemini"}, clear=False):
            chosen = service._fact_llm()
        self.assertIs(chosen, sentinel)

    async def test_ingest_embeds_all_chunks_in_one_batched_call(self):
        fake_db = _FakeDB()
        fake_embeddings = _FakeEmbeddings()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return b"%PDF-1.4 fake content"

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = fake_embeddings
            fake_page = MagicMock()
            # ~2.5k chars -> multiple 1000-char chunks, so batching is observable.
            fake_page.page_content = "lease clause text. " * 130
            fake_page.metadata = {"page": 0}
            loader_mock.return_value.load.return_value = [fake_page]

            response = await service.ingest_document(
                landlord_id="l1",
                property_id="p1",
                category="lease",
                file=_FakeUploadFile(),
            )

        self.assertEqual(len(fake_embeddings.embed_documents_calls), 1)
        self.assertGreater(len(fake_embeddings.embed_documents_calls[0]), 1)
        self.assertEqual(response.chunks_indexed, len(fake_embeddings.embed_documents_calls[0]))


class HostedContextScrubTests(unittest.IsolatedAsyncioTestCase):
    async def test_chunk_pii_is_scrubbed_before_hosted_prompt(self):
        # Synthetic NRIC — must never reach the hosted LLM prompt verbatim.
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}],
            chunks=[
                {
                    "doc_id": "d1",
                    "filename": "lease.pdf",
                    "category": "lease",
                    "page": 1,
                    "text": "Tenant NRIC 123456-78-9012 signed the lease.",
                    "landlord_id": "l1",
                    "property_id": "p1",
                }
            ],
            property_name="Maple Residency",
        )
        fake_store = _FakeConversationStore()
        fake_store.pending["session-pii"] = {
            "question": "Who signed?",
            "predicted_categories": ["lease"],
            "available_categories": ["lease"],
        }
        fake_graph = _FakeGraphOrchestrator(
            {
                "action": "retrieve",
                "predicted_categories": ["lease"],
                "prediction_reason": "lease",
                "intent": "document_question",
            }
        )
        fake_llm = _FakeLLM("The tenant signed the lease.")
        service = _build_service(fake_db, fake_store, fake_graph, fake_llm)

        payload = AskRequest(
            property_id="p1",
            question="yes",
            session_id="session-pii",
            user_action="confirm",
        )

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            await service.ask_documind(payload, "l1")

        self.assertIsNotNone(fake_llm.last_prompt)
        self.assertNotIn("123456-78-9012", fake_llm.last_prompt)
        self.assertIn("[NRIC]", fake_llm.last_prompt)


class PaymentExceptionServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_set_payment_exception_writes_deterministic_doc_id(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.set_payment_exception(
            landlord_id="l1", property_id="p1", unit_id="u1", month="2025-03", reason="bounced cheque",
        )

        self.assertEqual(result, {"property_id": "p1", "unit_id": "u1", "month": "2025-03",
                                   "reason": "bounced cheque", "state": "outstanding"})
        self.assertEqual(len(fake_db.payment_exceptions), 1)
        row = fake_db.payment_exceptions[0]
        self.assertEqual(row["doc_id"], "p1__u1__2025-03")
        self.assertEqual(row["landlord_id"], "l1")
        self.assertEqual(row["reason"], "bounced cheque")

    async def test_set_payment_exception_upserts_same_month(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.set_payment_exception(landlord_id="l1", property_id="p1", month="2025-03", reason="first")
        await service.set_payment_exception(landlord_id="l1", property_id="p1", month="2025-03", reason="corrected")

        self.assertEqual(len(fake_db.payment_exceptions), 1)
        self.assertEqual(fake_db.payment_exceptions[0]["reason"], "corrected")

    async def test_set_payment_exception_rejects_bad_month(self):
        fake_db = _FakeDB()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.set_payment_exception(landlord_id="l1", property_id="p1", month="March 2025")

    async def test_set_payment_exception_rejects_property_owned_by_another_landlord(self):
        fake_db = _FakeDB(property_owners={"p1": "someone-else"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.set_payment_exception(landlord_id="l1", property_id="p1", month="2025-03")

        self.assertEqual(fake_db.payment_exceptions, [])

    async def test_clear_payment_exception_removes_matching_record(self):
        fake_db = _FakeDB(payment_exceptions=[
            {"doc_id": "p1__property__2025-03", "landlord_id": "l1", "property_id": "p1",
             "unit_id": None, "month": "2025-03", "reason": None},
        ])
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.clear_payment_exception(landlord_id="l1", property_id="p1", month="2025-03")

        self.assertEqual(fake_db.payment_exceptions, [])

    async def test_clear_payment_exception_ignores_other_landlords_record(self):
        fake_db = _FakeDB(payment_exceptions=[
            {"doc_id": "p1__property__2025-03", "landlord_id": "someone-else", "property_id": "p1",
             "unit_id": None, "month": "2025-03", "reason": None},
        ])
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.clear_payment_exception(landlord_id="l1", property_id="p1", month="2025-03")

        self.assertEqual(len(fake_db.payment_exceptions), 1)

    async def test_get_finance_summary_loads_payment_exceptions_into_engine(self):
        fake_db = _FakeDB(
            docs=[{
                "doc_id": "doc-1", "landlord_id": "l1", "property_id": "p1", "unit_id": None,
                "unit_label": None, "category": "lease",
                "extracted_facts": {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"},
                "uploaded_at": datetime(2025, 1, 1),
            }],
            payment_exceptions=[{
                "doc_id": "p1__property__2025-03", "landlord_id": "l1", "property_id": "p1",
                "unit_id": None, "month": "2025-03", "reason": "tenant requested deferral",
            }],
            property_name="House",
        )
        fake_db.properties_rows = [{"landlordId": "l1", "name": "House", "doc_id": "p1"}]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        summary = await service.get_finance_summary("l1", 2025)

        march = next(m for m in summary.properties[0].units[0].months if m.month == 3)
        self.assertEqual(march.source, "unpaid")
        self.assertEqual(march.reason, "tenant requested deferral")
        self.assertEqual(summary.totals.received_rent, 11000.0)


class DocumentExceptionServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_set_document_unavailable_stores_the_mark(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.set_document_unavailable(
            landlord_id="l1", property_id="p1", year=2025, category="loan",
        )

        self.assertEqual(result, {"property_id": "p1", "year": 2025, "category": "loan"})
        self.assertEqual(len(fake_db.document_exceptions), 1)

    async def test_set_document_unavailable_rejects_wrong_owner(self):
        fake_db = _FakeDB(property_owners={"p1": "someone-else"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.set_document_unavailable(
                landlord_id="l1", property_id="p1", year=2025, category="loan",
            )
        self.assertEqual(fake_db.document_exceptions, [])

    async def test_clear_document_unavailable_is_idempotent(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        first = await service.clear_document_unavailable(
            landlord_id="l1", property_id="p1", year=2025, category="loan",
        )
        await service.set_document_unavailable(landlord_id="l1", property_id="p1", year=2025, category="loan")
        await service.clear_document_unavailable(landlord_id="l1", property_id="p1", year=2025, category="loan")

        self.assertEqual(first, {"property_id": "p1", "year": 2025, "category": "loan"})
        self.assertEqual(fake_db.document_exceptions, [])

    async def test_get_finance_summary_reads_document_exceptions(self):
        fake_db = _FakeDB(
            docs=[{
                "doc_id": "doc-1", "landlord_id": "l1", "property_id": "p1", "unit_id": None,
                "unit_label": None, "category": "lease",
                "extracted_facts": {"monthly_rent": 1000.0, "lease_start": "2025-01-01", "lease_end": "2025-12-31"},
                "uploaded_at": datetime(2025, 1, 1),
            }],
            document_exceptions=[
                {"landlord_id": "l1", "property_id": "p1", "year": 2025, "category": "loan"},
            ],
        )
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "House",
             "property_type": "landed", "has_mortgage": True},
        ]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        summary = await service.get_finance_summary("l1", 2025)

        row = next(r for r in summary.properties[0].coverage if r.year == 2025)
        self.assertIn("loan", row.unavailable)
        self.assertNotIn("loan", row.missing)


class RentRecoveryServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_record_requires_a_written_off_exception_on_file(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.record_rent_recovery(
                landlord_id="l1", property_id="p1", original_month="2025-08",
                amount=3000.0, received_year=2026,
            )

    async def test_record_succeeds_once_the_month_is_written_off(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.set_payment_exception(
            landlord_id="l1", property_id="p1", month="2025-08", state="written_off",
        )

        result = await service.record_rent_recovery(
            landlord_id="l1", property_id="p1", original_month="2025-08",
            amount=3000.0, received_year=2026,
        )

        self.assertEqual(result["amount"], 3000.0)
        self.assertEqual(len(fake_db.rent_recoveries), 1)

    async def test_clear_is_idempotent(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.clear_rent_recovery(
            landlord_id="l1", property_id="p1", original_month="2025-08",
        )

        self.assertEqual(result["original_month"], "2025-08")
        self.assertEqual(fake_db.rent_recoveries, [])


class ManualLoanEntryServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_record_stores_an_annual_entry(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=3000.0,
        )

        self.assertEqual(result["interest_paid"], 5000.0)
        self.assertEqual(result["principal_paid"], 3000.0)
        self.assertEqual(len(fake_db.manual_loan_entries), 1)
        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__2025")

    async def test_monthly_entry_requires_a_month(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.record_manual_loan_entry(
                landlord_id="l1", property_id="p1", year=2025, cadence="monthly",
                interest_paid=500.0, principal_paid=0.0, month=None,
            )

    async def test_monthly_entry_keys_by_month(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="monthly",
            interest_paid=500.0, principal_paid=0.0, month=3,
        )

        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__2025__03")

    async def test_record_rejects_wrong_owner(self):
        fake_db = _FakeDB(property_owners={"p1": "someone-else"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.record_manual_loan_entry(
                landlord_id="l1", property_id="p1", year=2025, cadence="annual",
                interest_paid=5000.0, principal_paid=0.0,
            )
        self.assertEqual(fake_db.manual_loan_entries, [])

    async def test_record_rejects_negative_amount(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.record_manual_loan_entry(
                landlord_id="l1", property_id="p1", year=2025, cadence="annual",
                interest_paid=-1.0, principal_paid=0.0,
            )

    async def test_record_is_idempotent_per_period(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=6000.0, principal_paid=0.0,
        )

        self.assertEqual(len(fake_db.manual_loan_entries), 1)
        self.assertEqual(fake_db.manual_loan_entries[0]["interest_paid"], 6000.0)

    async def test_list_returns_entries_for_the_year(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2024, cadence="annual",
            interest_paid=1000.0, principal_paid=0.0,
        )

        entries = service.list_manual_loan_entries("l1", "p1", 2025)

        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["interest_paid"], 5000.0)

    async def test_list_without_a_year_returns_every_year(self):
        """The "remove loan tracking" guard is retroactive across all years, so
        it asks without a year. Probing only the current year let a property
        with nothing booked this year but a full history last year skip the
        confirmation entirely."""
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2024, cadence="annual",
            interest_paid=1000.0, principal_paid=0.0,
        )

        entries = service.list_manual_loan_entries("l1", "p1")

        self.assertEqual(
            sorted(e["year"] for e in entries), [2024, 2025],
        )

    async def test_list_without_a_year_still_scopes_to_the_property(self):
        """Dropping the year filter must not also drop the property filter."""
        fake_db = _FakeDB(property_owners={"p1": "l1", "p2": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p2", year=2025, cadence="annual",
            interest_paid=9999.0, principal_paid=0.0,
        )

        entries = service.list_manual_loan_entries("l1", "p1")

        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["interest_paid"], 5000.0)

    async def test_delete_is_idempotent(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.delete_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025,
        )

        self.assertEqual(result["property_id"], "p1")
        self.assertEqual(fake_db.manual_loan_entries, [])

    async def test_get_finance_summary_folds_a_manual_entry(self):
        fake_db = _FakeDB(
            manual_loan_entries=[{
                "doc_id": "p1__2025", "landlord_id": "l1", "property_id": "p1",
                "year": 2025, "month": None, "interest_paid": 5000.0,
                "principal_paid": 3000.0, "cadence": "annual",
            }],
        )
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "House",
             "property_type": "landed", "has_mortgage": True},
        ]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        summary = await service.get_finance_summary("l1", 2025)

        subtypes = {l.subtype for l in summary.properties[0].expense_lines}
        self.assertIn("interest_statement", subtypes)
        self.assertIn("loan_principal", subtypes)

    async def test_unit_scoped_entry_keys_by_unit(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", unit_id="u1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )

        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__u1__2025")
        self.assertEqual(fake_db.manual_loan_entries[0]["unit_id"], "u1")

    async def test_whole_property_entry_keeps_legacy_key(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )

        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__2025")
        self.assertIsNone(fake_db.manual_loan_entries[0]["unit_id"])

    async def test_list_returns_unit_id(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", unit_id="u1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )

        entries = service.list_manual_loan_entries("l1", "p1", 2025)

        self.assertEqual(entries[0]["unit_id"], "u1")

    async def test_list_landlord_properties_exposes_loan_prefs(self):
        fake_db = _FakeDB()
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "H",
             "loan_input_cadence": "monthly", "mortgage_settled_on": "2027-03"},
        ]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_landlord_properties("l1")
        self.assertEqual(rows[0]["loan_input_cadence"], "monthly")
        self.assertEqual(rows[0]["mortgage_settled_on"], "2027-03")
        self.assertNotIn("loan_input_method", rows[0])


class UnitLoanExemptionServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_set_stores_the_mark(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        result = await service.set_unit_loan_exemption(landlord_id="l1", property_id="p1", unit_id="u1")
        self.assertEqual(result, {"property_id": "p1", "unit_id": "u1"})
        self.assertEqual(fake_db.unit_loan_exemptions[0]["doc_id"], "p1__u1")

    async def test_set_rejects_wrong_owner(self):
        fake_db = _FakeDB(property_owners={"p1": "someone-else"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        with self.assertRaises(ValueError):
            await service.set_unit_loan_exemption(landlord_id="l1", property_id="p1", unit_id="u1")
        self.assertEqual(fake_db.unit_loan_exemptions, [])

    async def test_clear_is_idempotent(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        result = await service.clear_unit_loan_exemption(landlord_id="l1", property_id="p1", unit_id="u1")
        self.assertEqual(result, {"property_id": "p1", "unit_id": "u1"})
        self.assertEqual(fake_db.unit_loan_exemptions, [])


class FactContextInjectionTests(unittest.IsolatedAsyncioTestCase):
    """The Ayer 8 regression.

    Retrieval returns real lease chunks that discuss termination in the
    abstract but never state the date — exactly what the live Schedule-table
    miss looks like. The document's extracted_facts carry the date. The
    assembled prompt must contain it.
    """

    def _fixtures(self):
        fake_db = _FakeDB(
            docs=[{
                "doc_id": "d-lease", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "ayer8-lease.pdf",
                "unit_label": "Unit B2-1-2",
                "extracted_facts": {"lease_end": "2026-10-31", "monthly_rent": 8000.0},
            }],
            chunks=[{
                "doc_id": "d-lease", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "ayer8-lease.pdf",
                "unit_label": "Unit B2-1-2", "page": 5,
                "text": ("the term of the tenancy has expired or has been sooner "
                         "determined, less any sums then due to the Landlord"),
            }],
        )
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["lease"],
            "prediction_confidence": 0.95,
            "prediction_reason": "asks about tenancy end date",
            "assistant_message": "",
            "intent": "document_question",
        })
        return fake_db, fake_graph

    async def test_extracted_facts_reach_the_prompt(self):
        fake_db, fake_graph = self._fixtures()
        fake_llm = _FakeLLM("The tenancy ends on 31 October 2026.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        await service.ask_documind(payload, "l1")

        # The chunk never states the date; only the facts block can supply it.
        self.assertNotIn("2026-10-31", fake_llm.last_prompt.split("Extracted Document Facts")[0])
        self.assertIn("2026-10-31", fake_llm.last_prompt)
        self.assertIn("Lease end", fake_llm.last_prompt)
        self.assertIn("Unit B2-1-2", fake_llm.last_prompt)

    async def test_answer_still_produced_when_facts_lookup_fails(self):
        fake_db, fake_graph = self._fixtures()
        fake_llm = _FakeLLM("Answered from excerpts alone.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        def _explode(_doc_ids):
            raise RuntimeError("firestore down")

        service._ask_orchestrator._get_document_facts = _explode

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        self.assertEqual(response.answer, "Answered from excerpts alone.")
        # The bolded heading, not the phrase — instruction 5 names the block in
        # prose and is always present, so a bare substring check can never pass.
        self.assertNotIn("**Extracted Document Facts:**", fake_llm.last_prompt)

    async def test_no_facts_block_when_documents_have_no_facts(self):
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {}
        fake_llm = _FakeLLM("No facts available.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        await service.ask_documind(payload, "l1")

        self.assertNotIn("**Extracted Document Facts:**", fake_llm.last_prompt)

    async def test_facts_are_not_sent_for_documents_retrieval_never_hit(self):
        # The spec's privacy boundary: only documents this query actually
        # retrieved contribute facts. Widening to "all docs for the property"
        # would answer more questions and leak data the query never touched,
        # and without this test that change stays green.
        fake_db, fake_graph = self._fixtures()
        fake_db.docs.append({
            "doc_id": "d-other", "landlord_id": "l1", "property_id": "p1",
            "category": "lease", "filename": "unrelated-lease.pdf",
            "unit_label": "Unit C-9-9",
            "extracted_facts": {"lease_end": "2099-12-31"},
        })
        fake_llm = _FakeLLM("ok")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        await service.ask_documind(payload, "l1")

        # d-other has facts but no chunks, so retrieval never returns it.
        self.assertIn("2026-10-31", fake_llm.last_prompt)
        self.assertNotIn("2099-12-31", fake_llm.last_prompt)
        self.assertNotIn("unrelated-lease.pdf", fake_llm.last_prompt)

    async def test_facts_block_is_pii_scrubbed(self):
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {
            "lease_end": "2026-10-31", "landlord_nric": "661214055049",
        }
        fake_llm = _FakeLLM("ok")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        await service.ask_documind(payload, "l1")

        self.assertIn("[NRIC]", fake_llm.last_prompt)
        self.assertNotIn("661214055049", fake_llm.last_prompt)

    async def test_facts_answer_is_cited_as_extracted(self):
        fake_db, fake_graph = self._fixtures()
        fake_llm = _FakeLLM("Ends 31 October 2026.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        extracted = [c for c in response.citations if c.source == "extracted_facts"]
        self.assertEqual(len(extracted), 1)
        self.assertEqual(extracted[0].doc_id, "d-lease")
        self.assertEqual(extracted[0].filename, "ayer8-lease.pdf")
        self.assertIsNone(extracted[0].page)
        self.assertEqual(extracted[0].unit_label, "Unit B2-1-2")
        # The snippet shows the value being cited, so the strip is verifiable.
        self.assertIn("Lease end: 2026-10-31", extracted[0].snippet)
        # Page citations survive alongside it and keep the default source.
        self.assertTrue(any(c.source == "excerpt" for c in response.citations))

    async def test_no_extracted_citation_when_no_facts(self):
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {}
        fake_llm = _FakeLLM("No facts.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        self.assertEqual([c for c in response.citations if c.source == "extracted_facts"], [])

    async def test_extracted_citation_snippet_is_not_scrubbed(self):
        # Citations go to the landlord, who owns the documents; only text bound
        # for the hosted LLM is scrubbed.
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {"tenant_nric": "661214055049"}
        fake_llm = _FakeLLM("ok")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        extracted = [c for c in response.citations if c.source == "extracted_facts"]
        self.assertIn("661214055049", extracted[0].snippet)
        self.assertIn("[NRIC]", fake_llm.last_prompt)


class UnitOwnershipShareLookupTests(unittest.IsolatedAsyncioTestCase):
    """The unit override has to survive the Firestore read. `None` means
    inherit the property's share — coercing it to 1.0 here would override a
    partial property share for every untouched unit."""

    async def test_stored_unit_share_is_returned(self):
        fake_db = _FakeDB(units=[
            {"unit_id": "u1", "label": "A-1", "ownership_share": 0.5},
        ])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertEqual(rows[0]["ownership_share"], 0.5)

    async def test_absent_unit_share_is_none_not_one(self):
        fake_db = _FakeDB(units=[{"unit_id": "u2", "label": "A-2"}])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertIsNone(rows[0]["ownership_share"])

    async def test_unparseable_unit_share_is_none(self):
        fake_db = _FakeDB(units=[
            {"unit_id": "u3", "label": "A-3", "ownership_share": "half"},
        ])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertIsNone(rows[0]["ownership_share"])

    async def test_label_and_id_still_returned(self):
        fake_db = _FakeDB(units=[{"unit_id": "u1", "label": "A-1"}])
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_property_units("p1")
        self.assertEqual(rows[0]["unit_id"], "u1")
        self.assertEqual(rows[0]["label"], "A-1")


class PropertyShareBasisLookupTests(unittest.IsolatedAsyncioTestCase):
    """The property's basis answers have to survive the Firestore read. A
    property that never answered reads as None / {} — which the engine
    resolves to 'full', today's behaviour."""

    def _rows(self, extra):
        fake_db = _FakeDB()
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Block", **extra},
        ]
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        return service._list_landlord_properties("l1")

    async def test_stored_default_and_exceptions_are_returned(self):
        rows = self._rows({
            "share_basis_default": "mine",
            "share_basis_exceptions": {"tax": "full"},
        })
        self.assertEqual(rows[0]["share_basis_default"], "mine")
        self.assertEqual(rows[0]["share_basis_exceptions"], {"tax": "full"})

    async def test_absent_fields_read_as_none_and_empty(self):
        rows = self._rows({})
        self.assertIsNone(rows[0]["share_basis_default"])
        self.assertEqual(rows[0]["share_basis_exceptions"], {})

    async def test_an_unknown_default_is_dropped(self):
        rows = self._rows({"share_basis_default": "sometimes"})
        self.assertIsNone(rows[0]["share_basis_default"])

    async def test_unknown_exception_values_are_dropped_individually(self):
        rows = self._rows({
            "share_basis_exceptions": {"tax": "full", "upkeep": "maybe"},
        })
        self.assertEqual(rows[0]["share_basis_exceptions"], {"tax": "full"})

    async def test_a_non_map_exceptions_field_reads_as_empty(self):
        rows = self._rows({"share_basis_exceptions": ["tax"]})
        self.assertEqual(rows[0]["share_basis_exceptions"], {})

    async def test_the_existing_fields_still_come_back(self):
        # A guard: the new keys are added to a dict several other features
        # read, and dropping one of those would be silent here.
        rows = self._rows({"ownership_share": 0.5, "utilities_paid_by": "landlord"})
        self.assertEqual(rows[0]["ownership_share"], 0.5)
        self.assertEqual(rows[0]["utilities_paid_by"], "landlord")
        self.assertEqual(rows[0]["name"], "Block")


if __name__ == "__main__":
    unittest.main()