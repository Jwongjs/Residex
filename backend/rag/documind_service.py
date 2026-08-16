import os
from typing import Dict, List
from models.documind_models import *
from datetime import date

from dotenv import load_dotenv
load_dotenv()

# Gemini embeddings & LLM
from langchain_google_genai import GoogleGenerativeAIEmbeddings, ChatGoogleGenerativeAI

# Firestore imports
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

# Firebase Storage imports
import firebase_admin
from firebase_admin import storage as firebase_storage
from rag.ask.conversation_router import ConversationRouter
from rag.ask.category_predictor import CategoryPredictor
from rag.documents.fact_extractor import FactExtractor
from rag.providers.ollama_chat import OllamaChat
from rag.providers.groq_chat import GroqChat
from rag.documents.pdf_ocr import PdfOcr
from rag.providers.ollama_embeddings import OllamaEmbeddings
from rag.ask.conversation_store import ConversationStore
from rag.ask.graph_orchestrator import DocuMindGraphOrchestrator
from rag.ask.retriever import HybridRetriever
from rag.finance.finance_engine import compute_finance_summary
# Re-exported: tests import these directly from rag.documind_service.
from rag.categories import (
    ALLOWED_CATEGORIES,
    CATEGORY_ORDER,
    EXPENSE_GROUP,
    LEGACY_CATEGORY_ALIASES,
    UPLOAD_CONTENT_TYPES,
    expand_categories_for_query,
    facts_status_for,
    normalize_category,
    resolve_upload_kind,
)
from rag.unit_resolution import resolve_unit_mention
from rag import property_directory
from rag.finance.finance_overrides_repository import FinanceOverridesRepository
from rag.documents.document_lifecycle_service import DocumentLifecycleService
from rag.documents.ingestion_service import IngestionService
from rag.ask.ask_orchestrator import AskOrchestrator

EMBED_DIM = 768 # Default to 768 if not set


db = firestore.Client()

from firebase_app import ensure_initialized as _ensure_firebase_initialized
_ensure_firebase_initialized()

llm = ChatGoogleGenerativeAI(
                model="models/gemini-2.5-flash",
                google_api_key=os.getenv('GOOGLE_API_KEY'),
                temperature=0.3,
            )

class DocuMindService:
    """
    Firestore Vector Search-based RAG service for property document Q&A.
    
    Features:
    - Property-scoped document storage
    - Category-based organization
    - Vector similarity search with citations
    - Automatic metadata tracking
    """

    def __init__(self):
        self._db = db
        self._finance_overrides = FinanceOverridesRepository(self._db)
        self._document_lifecycle = DocumentLifecycleService(self._db, lambda: self.storage_bucket)
        self._storage_bucket = None
        # None on purpose: the embeddings property builds the correctly
        # configured client (task_type + output_dimensionality) exactly once.
        self._embeddings = None
        self._llm = llm
        self._hybrid_retriever = HybridRetriever(db=self._db, embeddings=self.embeddings)
        self._conversation_store = ConversationStore(self._db)
        # One chat client shared by every collaborator that sees chat text.
        # PdfOcr keeps self._llm below: it is a vision path, and GroqChat
        # cannot accept the multimodal message list PdfOcr sends.
        self._chat = self._chat_llm()
        self._conversation_router = ConversationRouter(self._chat)
        self._category_predictor = CategoryPredictor(
            self._chat,
            allowed_categories=sorted(ALLOWED_CATEGORIES),
        )
        self._fact_extractor = FactExtractor(self._fact_llm())
        self._groq_fact_extractor, self._groq_categories = self._configure_groq_extractor()
        self._pdf_ocr = PdfOcr(self._llm)
        self._ingestion_service = IngestionService(
            db=self._db,
            storage_bucket_getter=lambda: self.storage_bucket,
            embeddings_getter=lambda: self.embeddings,
            pdf_ocr=self._pdf_ocr,
            extractor_for=self._extractor_for,
        )
        self._graph_orchestrator = DocuMindGraphOrchestrator(
            conversation_router=self._conversation_router,
            category_predictor=self._category_predictor,
        )
        self._ask_orchestrator = AskOrchestrator(
            conversation_store=self._conversation_store,
            graph_orchestrator=self._graph_orchestrator,
            hybrid_retriever=self._hybrid_retriever,
            llm_getter=lambda: self.llm,
            list_available_categories=self._list_available_categories,
            get_property_name=self._get_property_name,
            list_property_units=self._list_property_units,
            get_finance_summary=self.get_finance_summary,
            get_document_facts=self._get_document_facts,
        )
        print("DocuMindService initializing...")
        
    @property
    def db(self):
        return self._db

    @property
    def embeddings(self):
        """Lazy-load the embeddings client once. EMBEDDINGS_PROVIDER=ollama routes
        to the local nomic-embed-text adapter (privacy: raw chunk text never leaves
        the host); default 'gemini' keeps the hosted 768-dim client. Ingest and the
        retriever share this one client, so the flag flips both legs together."""
        if self._embeddings is None:
            provider = os.getenv("EMBEDDINGS_PROVIDER", "gemini").lower()
            if provider == "ollama":
                model = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
                print(f"🔄 Initializing Ollama embeddings ({model})...")
                self._embeddings = OllamaEmbeddings(
                    model=model,
                    base_url=os.getenv("OLLAMA_BASE_URL"),
                )
                print(f"✅ Ollama embeddings ready (model={model}, expected dim={EMBED_DIM})")
            else:
                print("🔄 Initializing Gemini embeddings...")
                self._embeddings = GoogleGenerativeAIEmbeddings(
                    model="gemini-embedding-001",  # Latest model (replaces embedding-001)
                    google_api_key=os.getenv("GOOGLE_API_KEY"),
                    task_type="RETRIEVAL_DOCUMENT",
                    output_dimensionality= EMBED_DIM
                )
                print(f"✅ Gemini embeddings ready (dim={EMBED_DIM})")
        return self._embeddings

    @property
    def storage_bucket(self):
        """Lazy-load the Firebase Storage bucket (only when first accessed)."""
        if self._storage_bucket is None:
            self._storage_bucket = firebase_storage.bucket()
        return self._storage_bucket

    @property
    def llm(self):
        """The chat client. AskOrchestrator reaches this through its injected
        llm_getter, so CHAT_PROVIDER governs answer synthesis AND finance
        narration, not just routing. Falls back to the hosted client on
        instances built via __new__ in tests, which never set _chat.

        `is not None`, not `or`: a falsy _chat is unreachable today, but if
        _chat_llm ever degrades to None on misconfiguration, `or` would route
        chat text to Gemini while the operator believes CHAT_PROVIDER=groq is
        in force — failing open in the privacy-relevant direction, silently."""
        chat = getattr(self, "_chat", None)
        return chat if chat is not None else self._llm

    def _fact_llm(self):
        """The LLM injected into FactExtractor. FACT_PROVIDER=ollama (or local)
        routes extraction to the local model because it is fed the full leading
        document text (names, addresses, NRIC) — that raw text must never reach
        the hosted API, and unlike chat context it can't be scrubbed first
        without erasing the name fields extraction exists to capture. Default
        'gemini' keeps the hosted client."""
        provider = os.getenv("FACT_PROVIDER", "gemini").lower()
        if provider in ("ollama", "local"):
            model = os.getenv("OLLAMA_FACT_MODEL", "qwen2.5:7b")
            print(f"🔄 Fact extraction routed to local Ollama ({model})")
            return OllamaChat(model=model, base_url=os.getenv("OLLAMA_BASE_URL"))
        if provider == "groq":
            model = os.getenv("GROQ_FACT_MODEL", "llama-3.3-70b-versatile")
            print(f"🔄 Fact extraction routed to Groq ({model}) — ZDR must be enabled")
            return GroqChat(model=model)
        return self._llm

    def _chat_llm(self):
        """The LLM behind chat: answer synthesis, conversation routing and
        category prediction. CHAT_PROVIDER=groq routes them to Groq, which
        already receives lease text for fact extraction under ZDR; default
        'gemini' keeps the hosted client so merging this changes nothing until
        the flag is set.

        PdfOcr deliberately does NOT use this — it invokes with a list of
        multimodal HumanMessages and GroqChat.invoke takes a plain string.
        """
        provider = os.getenv("CHAT_PROVIDER", "gemini").lower()
        if provider == "groq":
            model = os.getenv("GROQ_CHAT_MODEL", "llama-3.3-70b-versatile")
            if not os.getenv("GROQ_API_KEY"):
                # Without this, every chat turn 401s and each consumer catches
                # broadly — the landlord sees generic "something went wrong"
                # across answers, routing and prediction with no clue why.
                print("⚠️  CHAT_PROVIDER=groq but GROQ_API_KEY is unset — "
                      "every chat call will fail authentication")
            print(f"🔄 Chat routed to Groq ({model}) — ZDR must be enabled")
            return GroqChat(model=model)
        return self._llm

    def _configure_groq_extractor(self):
        """Build the dedicated Groq extractor for the categories that need it.

        Returns (extractor_or_None, categories). Enabled only when GROQ_API_KEY
        is set; GROQ_FACT_CATEGORIES (default 'lease') names the categories that
        route to Groq — everything else stays on the local/default extractor so
        the least PII possible leaves the machine. Leases are the case local
        qwen fails (free-form prose), and the account owner is responsible for
        enabling Zero Data Retention before any unscrubbed text is sent."""
        if not os.getenv("GROQ_API_KEY"):
            return None, frozenset()
        categories = frozenset(
            c.strip().lower()
            for c in os.getenv("GROQ_FACT_CATEGORIES", "lease").split(",")
            if c.strip()
        )
        if not categories:
            return None, frozenset()
        model = os.getenv("GROQ_FACT_MODEL", "llama-3.3-70b-versatile")
        print(f"🔄 Groq fact extraction enabled for {sorted(categories)} ({model})")
        return FactExtractor(GroqChat(model=model)), categories

    def _extractor_for(self, category: str):
        """Route a document category to the Groq extractor when configured, else
        the default (local/hosted) extractor. Inert on test instances built via
        __new__: the _groq_* attrs are absent, so this always returns the
        default extractor and can never divert a test to a live Groq call."""
        groq_extractor = getattr(self, "_groq_fact_extractor", None)
        groq_categories = getattr(self, "_groq_categories", frozenset())
        if groq_extractor is not None and category in groq_categories:
            return groq_extractor
        return self._fact_extractor

    def _get_document_facts(self, doc_ids):
        """(doc_id, filename, unit_label, facts) for each doc_id that has facts.

        Scoped to the documents retrieval actually hit, so no data leaves for a
        document the query never touched. Best-effort by contract: any Firestore
        failure skips that document and is logged, because a missing facts block
        must degrade the answer to chunks-only rather than fail the request.
        """
        rows = []
        for doc_id in dict.fromkeys(doc_ids):  # de-dupe, preserve order
            try:
                snap = self.db.collection('documind_docs').document(doc_id).get()
            except Exception as e:
                print(f"WARNING: could not load facts for doc {doc_id}: {e}")
                continue
            if not snap.exists:
                continue
            data = snap.to_dict() or {}
            facts = data.get('extracted_facts') or {}
            if not facts:
                continue
            rows.append((doc_id, data.get('filename') or doc_id, data.get('unit_label'), facts))
        return rows

    def _list_available_categories(self, landlord_id: str, property_id: str) -> List[str]:
        """List categories that have uploaded docs for this landlord/property."""
        try:
            docs_query = self.db.collection('documind_docs') \
                .where(filter=FieldFilter('landlord_id', '==', landlord_id)) \
                .where(filter=FieldFilter('property_id', '==', property_id))

            found_categories = set()
            for doc in docs_query.stream():
                data = doc.to_dict() or {}
                category = normalize_category(data.get('category'))
                if category in ALLOWED_CATEGORIES:
                    found_categories.add(category)

            ordered = [
                category for category in CATEGORY_ORDER
                if category in found_categories
            ]
            return ordered
        except Exception as e:
            print(f"⚠️ Could not list available categories: {e}")
            return []

    def _get_property_name(self, property_id: str) -> str:
        return property_directory.get_property_name(self.db, property_id)

    def _list_property_units(self, property_id: str) -> List[Dict]:
        return property_directory.list_property_units(self.db, property_id)

    def _list_landlord_properties(self, landlord_id: str) -> List[Dict]:
        return property_directory.list_landlord_properties(self.db, landlord_id)

    async def ingest_document(self, landlord_id, property_id, category, file, unit_id=None, unit_label=None, progress=None):
        return await self._ingestion_service.ingest_document(
            landlord_id=landlord_id, property_id=property_id, category=category,
            file=file, unit_id=unit_id, unit_label=unit_label, progress=progress,
        )

    async def update_expense_lines(self, doc_id, landlord_id, lines):
        return await self._document_lifecycle.update_expense_lines(doc_id, landlord_id, lines)

    async def rename_document(self, doc_id, landlord_id, filename):
        return await self._document_lifecycle.rename_document(doc_id, landlord_id, filename)

    async def set_document_share_basis(self, doc_id, landlord_id, share_basis):
        return await self._document_lifecycle.set_document_share_basis(
            doc_id, landlord_id, share_basis
        )

    async def set_payment_exception(self, *, landlord_id, property_id, month, unit_id=None, reason=None, state="outstanding"):
        return await self._finance_overrides.set_payment_exception(
            landlord_id=landlord_id, property_id=property_id, month=month,
            unit_id=unit_id, reason=reason, state=state,
        )

    async def clear_payment_exception(self, *, landlord_id, property_id, month, unit_id=None):
        return await self._finance_overrides.clear_payment_exception(
            landlord_id=landlord_id, property_id=property_id, month=month, unit_id=unit_id,
        )

    async def set_document_unavailable(self, *, landlord_id, property_id, year, category):
        return await self._finance_overrides.set_document_unavailable(
            landlord_id=landlord_id, property_id=property_id, year=year, category=category,
        )

    async def clear_document_unavailable(self, *, landlord_id, property_id, year, category):
        return await self._finance_overrides.clear_document_unavailable(
            landlord_id=landlord_id, property_id=property_id, year=year, category=category,
        )

    async def record_rent_recovery(self, *, landlord_id, property_id, original_month, amount, received_year, unit_id=None):
        return await self._finance_overrides.record_rent_recovery(
            landlord_id=landlord_id, property_id=property_id, original_month=original_month,
            amount=amount, received_year=received_year, unit_id=unit_id,
        )

    async def clear_rent_recovery(self, *, landlord_id, property_id, original_month, unit_id=None):
        return await self._finance_overrides.clear_rent_recovery(
            landlord_id=landlord_id, property_id=property_id, original_month=original_month, unit_id=unit_id,
        )

    async def record_manual_loan_entry(self, *, landlord_id, property_id, year, cadence, interest_paid, principal_paid, unit_id=None, month=None):
        return await self._finance_overrides.record_manual_loan_entry(
            landlord_id=landlord_id, property_id=property_id, year=year, cadence=cadence,
            interest_paid=interest_paid, principal_paid=principal_paid, unit_id=unit_id, month=month,
        )

    async def delete_manual_loan_entry(self, *, landlord_id, property_id, year, unit_id=None, month=None):
        return await self._finance_overrides.delete_manual_loan_entry(
            landlord_id=landlord_id, property_id=property_id, year=year, unit_id=unit_id, month=month,
        )

    async def set_unit_loan_exemption(self, *, landlord_id, property_id, unit_id):
        return await self._finance_overrides.set_unit_loan_exemption(
            landlord_id=landlord_id, property_id=property_id, unit_id=unit_id,
        )

    async def clear_unit_loan_exemption(self, *, landlord_id, property_id, unit_id):
        return await self._finance_overrides.clear_unit_loan_exemption(
            landlord_id=landlord_id, property_id=property_id, unit_id=unit_id,
        )

    def list_manual_loan_entries(self, landlord_id, property_id, year=None):
        return self._finance_overrides.list_manual_loan_entries(landlord_id, property_id, year)

    async def ask_documind(self, payload: AskRequest, landlord_id: str) -> AskResponse:
        return await self._ask_orchestrator.ask(payload, landlord_id)

    async def list_documents(self, landlord_id, property_id=None, unit_id=None):
        return await self._document_lifecycle.list_documents(landlord_id, property_id, unit_id)

    async def get_finance_summary(self, landlord_id: str, year: int) -> FinanceSummaryResponse:
        """One Firestore fold, zero LLM: fetch the landlord's documents,
        properties, units, and payment exceptions, then run the pure engine.
        Categories are alias-normalized before the fold."""
        documents = []
        query = self.db.collection('documind_docs').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        for snap in query.stream():
            data = snap.to_dict() or {}
            documents.append({
                "doc_id": data.get("doc_id") or snap.id,
                "property_id": data.get("property_id"),
                "unit_id": data.get("unit_id"),
                "unit_label": data.get("unit_label"),
                "category": normalize_category(data.get("category")),
                "share_basis": data.get("share_basis"),
                "extracted_facts": data.get("extracted_facts"),
                "uploaded_at": data.get("uploaded_at"),
            })

        properties = self._list_landlord_properties(landlord_id)
        units_by_property = {
            prop["property_id"]: self._list_property_units(prop["property_id"])
            for prop in properties
        }

        overrides = self._finance_overrides.fetch_all(landlord_id)

        summary = compute_finance_summary(
            year=year,
            today=date.today(),
            documents=documents,
            properties=properties,
            units_by_property=units_by_property,
            payment_exceptions=overrides["payment_exceptions"],
            document_exceptions=overrides["document_exceptions"],
            rent_recoveries=overrides["rent_recoveries"],
            manual_loan_entries=overrides["manual_loan_entries"],
            unit_loan_exemptions=overrides["unit_loan_exemptions"],
        )
        return FinanceSummaryResponse(**summary)

    async def delete_document(self, landlord_id, property_id, doc_id):
        return await self._document_lifecycle.delete_document(landlord_id, property_id, doc_id)

    async def delete_documents_for_property(self, landlord_id, property_id):
        return await self._document_lifecycle.delete_documents_for_property(landlord_id, property_id)

    async def unassign_unit_documents(self, landlord_id, property_id, unit_id):
        return await self._document_lifecycle.unassign_unit_documents(landlord_id, property_id, unit_id)

    async def get_document_view_url(self, landlord_id, property_id, doc_id):
        return await self._document_lifecycle.get_document_view_url(landlord_id, property_id, doc_id)

# Singleton instance
documind_service = DocuMindService()