import os
import uuid
import tempfile
import asyncio
from typing import Any, Callable, Dict, List, Optional, Tuple
from fastapi import UploadFile
from models.documind_models import *
from datetime import datetime, timedelta, date

from dotenv import load_dotenv
load_dotenv()  

# LangChain core
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document

# Gemini embeddings & LLM
from langchain_google_genai import GoogleGenerativeAIEmbeddings, ChatGoogleGenerativeAI

# Firestore imports
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1.vector import Vector
from google.cloud.firestore_v1.base_vector_query import DistanceMeasure

# Firebase Storage imports
import firebase_admin
from firebase_admin import storage as firebase_storage
from rag.conversation_router import ConversationRouter
from rag.category_predictor import CategoryPredictor
from rag.fact_extractor import FactExtractor, validate_expense_lines
from rag.ollama_chat import OllamaChat
from rag.groq_chat import GroqChat
from rag.pdf_ocr import PdfOcr
from rag.ollama_embeddings import OllamaEmbeddings
from rag.pii_scrub import scrub_for_hosted
from rag.conversation_store import ConversationStore
from rag.graph_orchestrator import DocuMindGraphOrchestrator
from rag.retriever import HybridRetriever
from rag.finance_engine import compute_finance_summary, document_tags
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
from rag.finance_overrides_repository import FinanceOverridesRepository
from rag.document_lifecycle_service import DocumentLifecycleService

EMBED_DIM = 768 # Default to 768 if not set
OCR_TEXT_THRESHOLD = 200  # chars; below this a PDF is treated as scanned


db = firestore.Client()

if not firebase_admin._apps:
    firebase_admin.initialize_app(options={
        'storageBucket': os.getenv(
            'FIREBASE_STORAGE_BUCKET',
            f"{os.getenv('GOOGLE_CLOUD_PROJECT')}.firebasestorage.app",
        ),
    })

embeddings = GoogleGenerativeAIEmbeddings(
            model="models/gemini-embedding-001",  
            google_api_key=os.getenv("GOOGLE_API_KEY"), # explicit key: os.getenv("GEMINI_API_KEY")
        )
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
        self._conversation_router = ConversationRouter(self._llm)
        self._category_predictor = CategoryPredictor(
            self._llm,
            allowed_categories=sorted(ALLOWED_CATEGORIES),
        )
        self._fact_extractor = FactExtractor(self._fact_llm())
        self._groq_fact_extractor, self._groq_categories = self._configure_groq_extractor()
        self._pdf_ocr = PdfOcr(self._llm)
        self._graph_orchestrator = DocuMindGraphOrchestrator(
            conversation_router=self._conversation_router,
            category_predictor=self._category_predictor,
        )
        print("DocuMindService initializing...")
        
    @property
    def db(self):
        """Lazy-load Firestore client (only when first accessed)"""
        if self._db is None:
            print("🔄 Initializing Firestore client...")
            self._db = firestore.Client()
            print("✅ Firestore client ready")
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
        """Lazy-load Gemini LLM (only when first accessed)"""
        if self._llm is None:
            print("🔄 Initializing Gemini LLM...")
            self._llm = ChatGoogleGenerativeAI(
                model="gemini-1.5-flash",
                google_api_key=os.getenv('GEMINI_API_KEY'),
                temperature=0.3,
            )
            print("✅ Gemini LLM ready")
        return self._llm

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

    def _normalize_category_selection(self, text: str, available_categories: List[str]) -> Optional[str]:
        """Map user follow-up text like 'lease' or 'tenancy agreement' to a valid category."""
        if not text:
            return None

        lowered = text.strip().lower()
        if not lowered:
            return None

        if lowered in available_categories:
            return lowered

        aliases = {
            "lease": ["lease", "tenancy", "tenancy agreement", "rental agreement", "agreement"],
            "insurance": ["insurance", "policy"],
            "loan": ["loan", "mortgage", "financing", "interest statement"],
            "tax": ["tax", "assessment", "cukai", "quit rent", "parcel rent", "taksiran"],
            "upkeep": ["upkeep", "repair", "servicing", "service", "utility", "warranty"],
            "maintenance": ["maintenance", "management fee", "sinking fund"],
            "rental_invoice": ["rental invoice", "rent invoice", "invoice", "invoices", "receipt"],
        }

        for category, values in aliases.items():
            if category in available_categories and any(value in lowered for value in values):
                return category

        if lowered.isdigit():
            index = int(lowered) - 1
            if 0 <= index < len(available_categories):
                return available_categories[index]

        return None

    def _get_property_name(self, property_id: str) -> str:
        return property_directory.get_property_name(self.db, property_id)

    def _narrate_finance_summary(self, question: str, property_name: str, summary) -> str:
        """Turn the engine's computed JSON into a chat answer. The LLM narrates
        only — on any failure a deterministic headline line stands in, so the
        numbers shown are always the engine's."""
        totals = summary.totals
        top_caveat = summary.caveats[0] if summary.caveats else ""
        prompt = f"""You are DocuMind, answering a landlord's finance question.

**Question:** {question}
**Currently selected property (context only — figures below cover the whole portfolio):** {property_name}

**Computed figures for {summary.year} (authoritative):**
{summary.model_dump_json(indent=2)}

Rules:
1. Answer using ONLY the figures above, quoted exactly as given. NEVER recompute, derive, add, or estimate any number yourself.
2. If a figure the user wants is not present above, say it is not computed rather than deriving it.
3. When mentioning statutory rental income, always attach: "{totals.statutory_note}".
4. Include this caveat once: {top_caveat}
5. Amounts are in RM. Be concise; short bullet points are fine.

**Your Answer:**"""
        try:
            response = self.llm.invoke(prompt)
            return response.content.strip()
        except Exception as e:
            print(f"❌ Finance narration failed: {e}")
            return (
                f"For {summary.year}: gross rent RM {totals.received_rent:,.2f}, "
                f"direct expenses RM {totals.direct_expenses:,.2f}, "
                f"net P/L RM {totals.net_pl:,.2f}. "
                f"Statutory rental income: RM {totals.statutory_rental_income:,.2f} "
                f"({totals.statutory_note})."
            )

    def _list_property_units(self, property_id: str) -> List[Dict]:
        return property_directory.list_property_units(self.db, property_id)

    def _list_landlord_properties(self, landlord_id: str) -> List[Dict]:
        return property_directory.list_landlord_properties(self.db, landlord_id)

    async def ingest_document(
        self,
        landlord_id: str,
        property_id: str,
        category: str,
        file: UploadFile,
        unit_id: Optional[str] = None,
        unit_label: Optional[str] = None,
        progress: Optional[Callable[[str], None]] = None,
    ) -> DocUploadResponse:
        """
        Ingest document into Firestore with vector embeddings.

        progress, when provided, is called with a stage key ("received",
        "reading", "organising", "indexing", "details") before each stage's
        work, so a streaming caller can report live progress. The tiny
        asyncio.sleep(0) after each emit yields control to the event loop so a
        StreamingResponse can flush the event before the (blocking) stage runs.
        """
        async def _emit(stage: str) -> None:
            if progress is not None:
                progress(stage)
                await asyncio.sleep(0)

        category = normalize_category(category)
        if category not in ALLOWED_CATEGORIES:
            raise ValueError(
                f"Unsupported category '{category}'. Allowed: {', '.join(CATEGORY_ORDER)}"
            )

        ext, content_type = resolve_upload_kind(file.filename)

        doc_id = str(uuid.uuid4())
        
        # Step 1: Save file temporarily
        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, f"{doc_id}_{file.filename}")
        try:
            with open(temp_path, "wb") as f:
                content = await file.read()
                f.write(content)
            
            print(f"📄 Saved temp file: {temp_path}")
            await _emit("received")

            await _emit("reading")
            if content_type == "application/pdf":
                # Step 2a: text-layer extraction, OCR fallback for scans.
                loader = PyPDFLoader(temp_path)
                pages = loader.load()
                total_text = sum(len((page.page_content or "").strip()) for page in pages)
                if total_text < OCR_TEXT_THRESHOLD:
                    transcripts = self._pdf_ocr.transcribe(content)
                    if transcripts:
                        pages = [
                            Document(page_content=text, metadata={"page": index})
                            for index, text in enumerate(transcripts)
                        ]
                        print(f"OCR fallback transcribed {len(pages)} page(s)")
            else:
                # Step 2b: images have no text layer — transcribe directly.
                pages = []
                transcripts = self._pdf_ocr.transcribe(content, mime_type=content_type)
                if transcripts:
                    pages = [
                        Document(page_content=text, metadata={"page": index})
                        for index, text in enumerate(transcripts)
                    ]
                    print(f"Transcribed image upload ({len(pages)} block(s))")

            await _emit("organising")
            # Step 3: Chunk text
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=1000,
                chunk_overlap=200,
            )
            chunks = text_splitter.split_documents(pages)
            
            print(f"📝 Split into {len(chunks)} chunks")
            
            await _emit("indexing")
            # Step 4: Embed every chunk in ONE batched call. A quota error
            # here fails fast and visibly (0 chunks, metadata-only) instead
            # of grinding chunk-by-chunk through retry backoff.
            vectors = []
            if chunks:
                try:
                    vectors = self.embeddings.embed_documents(
                        [chunk.page_content for chunk in chunks]
                    )
                except Exception as e:
                    print(f"⚠️ Batch embedding failed; indexing metadata only: {e}")
                    vectors = []

            chunk_documents = []
            for i, (chunk, embedding) in enumerate(zip(chunks, vectors)):
                chunk_doc = {
                    'doc_id': doc_id,
                    'landlord_id': landlord_id,
                    'property_id': property_id,
                    'unit_id': unit_id,
                    'unit_label': unit_label,
                    'category': category,
                    'filename': file.filename,
                    'chunk_index': i,
                    'text': chunk.page_content,
                    'embedding': Vector(embedding),
                    # ✅ FIXED: Ensure page is always an integer (never None)
                    'page': chunk.metadata.get('page', 0) if chunk.metadata.get('page') is not None else 0,
                    'created_at': firestore.SERVER_TIMESTAMP,
                }
                chunk_documents.append(chunk_doc)
            
            print(f"✅ Generated {len(chunk_documents)} embeddings")
            
            if len(chunk_documents) == 0:
                # Scanned document whose OCR fallback also produced nothing:
                # keep the document (Storage + metadata, 0 chunks) so it still
                # lists and can be re-uploaded; there is just nothing to search.
                print("⚠️ No text extracted; indexing metadata with 0 chunks")

            # Step 5: Batch write chunks to Firestore
            batch = self.db.batch()
            for chunk_doc in chunk_documents:
                chunk_ref = self.db.collection('documind_chunks').document()
                batch.set(chunk_ref, chunk_doc)
            
            # Commit all chunks at once
            batch.commit()
            print(f"✅ Batch wrote {len(chunk_documents)} chunks to Firestore")

            await _emit("details")
            # Fact extraction (best-effort, one LLM call over the leading
            # text). Failure must never block indexing.
            extracted_facts = None
            facts_confidence = None
            try:
                full_text = "\n".join(page.page_content or "" for page in pages)
                facts = self._extractor_for(category).extract(category, full_text)
                if facts:
                    facts_confidence = facts.pop("confidence", None)
                    extracted_facts = facts or None
            except Exception as e:
                print(f"⚠️ Fact extraction failed (non-blocking): {e}")

            # Step 5.5: Upload original file to Firebase Storage
            storage_path = f"documind/{landlord_id}/{property_id}/{doc_id}{ext}"
            blob = self.storage_bucket.blob(storage_path)
            blob.upload_from_string(content, content_type=content_type)

            # Step 6: Store document metadata
            file_size = os.path.getsize(temp_path)
            doc_ref = self.db.collection('documind_docs').document(doc_id)
            doc_ref.set({
                'landlord_id': landlord_id,
                'property_id': property_id,
                'unit_id': unit_id,
                'unit_label': unit_label,
                'category': category,
                'filename': file.filename,
                'chunks_indexed': len(chunk_documents),
                'file_size': file_size,
                'storage_path': storage_path,
                'status': 'indexed',
                'extracted_facts': extracted_facts,
                'facts_confidence': facts_confidence,
                'facts_status': facts_status_for(extracted_facts),
                'facts_extracted_at': firestore.SERVER_TIMESTAMP if extracted_facts else None,
                'uploaded_at': firestore.SERVER_TIMESTAMP,
            })
            
            print(f"✅ Indexed {file.filename}: {len(chunk_documents)} chunks")
            
            return DocUploadResponse(
                doc_id=doc_id,
                landlord_id=landlord_id,
                property_id=property_id,
                category=category,
                filename=file.filename,
                status="indexed",
                chunks_indexed=len(chunk_documents),
                extracted_facts=extracted_facts,
                facts_confidence=facts_confidence,
                facts_status=facts_status_for(extracted_facts),
            )
        
        except Exception as e:
            print(f"❌ Document ingestion failed: {e}")
            raise
        
        finally:
            # Step 7: Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                print(f"🗑️ Cleaned up temp file: {temp_path}")

    async def update_expense_lines(self, doc_id, landlord_id, lines):
        return await self._document_lifecycle.update_expense_lines(doc_id, landlord_id, lines)

    async def rename_document(self, doc_id, landlord_id, filename):
        return await self._document_lifecycle.rename_document(doc_id, landlord_id, filename)

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

    def list_manual_loan_entries(self, landlord_id, property_id, year):
        return self._finance_overrides.list_manual_loan_entries(landlord_id, property_id, year)

    async def ask_documind(self, payload: AskRequest) -> AskResponse:
        """
        Answer question using Firestore Vector Search.
        
        Flow:
        1. Generate embedding for question
        2. Vector search in Firestore (find_nearest)
        3. Build context from retrieved chunks
        4. Send to Gemini for answer synthesis
        5. Return answer with citations
        
        Args:
            payload: AskRequest with landlord_id, property_id, question, top_k
            
        Returns:
            AskResponse with answer, citations, confidence
        """
        
        category_filter_mode = "all"
        available_categories = self._list_available_categories(payload.landlord_id, payload.property_id)
        property_name = self._get_property_name(payload.property_id)

        # Normalize explicit category filters from payload
        requested_categories = payload.categories or []
        normalized_explicit = [category.strip().lower() for category in requested_categories if category and category.strip()]
        explicit_valid = [category for category in normalized_explicit if category in ALLOWED_CATEGORIES]

        session = self._conversation_store.get_or_create_session(
            landlord_id=payload.landlord_id,
            property_id=payload.property_id,
            session_id=payload.session_id,
        )
        session_id = session.get("session_id")
        turn_number = max(1, self._conversation_store.get_turn_count(session_id) + 1)
        recent_turns = session.get("conversation_turns", []) if isinstance(session, dict) else []

        # Units go into the graph so the routing node can decide the unit
        # scope in the same LLM call that picks categories.
        property_units = self._list_property_units(payload.property_id)

        graph_state = await self._graph_orchestrator.run({
            "user_input": payload.question,
            "explicit_categories": explicit_valid,
            "available_categories": available_categories,
            "available_units": property_units,
            "user_action": payload.user_action or "",
            "recent_turns": recent_turns,
            "property_name": property_name,
        })

        graph_action = graph_state.get("action", "retrieve")
        predicted_categories = graph_state.get("predicted_categories", [])
        action_reason = graph_state.get("prediction_reason") or graph_state.get("intent_reason")

        # Conversational mode: no retrieval required yet
        if graph_action == "conversation":
            answer = graph_state.get(
                "assistant_message",
                "Hey! If you have anything that needs help with on property documents, please let me know.",
            )
            if property_name != "Unknown Property" and property_name.lower() not in answer.lower():
                answer = f"For {property_name}, {answer}"
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": graph_state.get("intent", "conversation"),
                    "action": "conversation",
                    "answer": answer,
                },
            )
            return AskResponse(
                answer=answer,
                confidence=graph_state.get("intent_confidence", 0.9),
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="conversation",
                needs_category_clarification=False,
                clarification_prompt=None,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=[],
                action_reason=graph_state.get("intent_reason"),
            )

        # Finance branch: skip retrieval entirely — the deterministic engine
        # computes, the LLM only narrates (2 LLM calls total incl. the router).
        if graph_action == "finance":
            requested_year = graph_state.get("finance_year") or datetime.now().year
            try:
                summary = await self.get_finance_summary(payload.landlord_id, requested_year)
                answer = self._narrate_finance_summary(payload.question, property_name, summary)
            except Exception as e:
                print(f"❌ Finance summary failed: {e}")
                answer = (
                    "I couldn't compute your rental finances just now. "
                    "Please try again in a moment."
                )
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "finance_question",
                    "action": "finance",
                    "answer": answer,
                },
            )
            return AskResponse(
                answer=answer,
                confidence=0.9,
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="finance",
                needs_category_clarification=False,
                clarification_prompt=None,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=[],
                action_reason=graph_state.get("intent_reason"),
            )

        # Type 2 ambiguity: document question but category not explicit -> predict + confirm checkpoint
        if graph_action == "ask_confirmation":
            confirmation_message = graph_state.get("assistant_message", "Please confirm the document category to proceed.")
            if property_name != "Unknown Property" and property_name.lower() not in confirmation_message.lower():
                confirmation_message = f"For {property_name}, {confirmation_message}"
            confirmation_options = predicted_categories + [
                category for category in available_categories if category not in predicted_categories
            ]
            self._conversation_store.set_pending_confirmation(
                session_id,
                {
                    "question": payload.question,
                    "predicted_categories": predicted_categories,
                    "available_categories": available_categories,
                    "action_reason": action_reason,
                },
            )
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "document_question",
                    "action": "ask_confirmation",
                    "predicted_categories": predicted_categories,
                    "reason": action_reason,
                },
            )
            return AskResponse(
                answer=confirmation_message,
                confidence=graph_state.get("prediction_confidence", 0.6),
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="clarification",
                needs_category_clarification=True,
                clarification_prompt=confirmation_message,
                clarification_options=confirmation_options,
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=True,
                predicted_categories=predicted_categories,
                action_reason=action_reason,
            )

        if graph_action == "cancel":
            self._conversation_store.clear_pending_confirmation(session_id)
            cancel_message = graph_state.get(
                "assistant_message",
                "Understood. I cancelled that action. Ask me anytime about your property documents.",
            )
            if property_name != "Unknown Property" and property_name.lower() not in cancel_message.lower():
                cancel_message = f"For {property_name}, {cancel_message}"
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "document_question",
                    "action": "cancel",
                    "answer": cancel_message,
                },
            )
            return AskResponse(
                answer=cancel_message,
                confidence=0.9,
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="cancel",
                needs_category_clarification=False,
                clarification_prompt=None,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=[],
                action_reason="User cancelled requested action",
            )

        working_question = payload.question
        selected_categories: List[str] = []
        effective_unit_id = payload.unit_id

        if explicit_valid:
            selected_categories = explicit_valid[:10]
            category_filter_mode = "explicit"
        else:
            pending = self._conversation_store.get_pending_confirmation(session_id)
            user_action_raw = (payload.user_action or "").strip()
            user_action = user_action_raw.lower()

            if user_action == "confirm":
                if pending and pending.get("predicted_categories"):
                    selected_categories = [
                        category for category in pending.get("predicted_categories", [])
                        if category in ALLOWED_CATEGORIES
                    ]
                    working_question = pending.get("question", payload.question)
                    category_filter_mode = "clarification_selected"
                self._conversation_store.clear_pending_confirmation(session_id)
            elif user_action.startswith("override:"):
                override_category = user_action.split(":", 1)[1].strip().lower()
                if override_category in ALLOWED_CATEGORIES:
                    selected_categories = [override_category]
                    working_question = pending.get("question", payload.question) if pending else payload.question
                    category_filter_mode = "clarification_selected"
                self._conversation_store.clear_pending_confirmation(session_id)
            elif user_action.startswith("unit:"):
                # Resume of a unit-ambiguity checkpoint. The unit id keeps its
                # original casing (Firestore ids are case-sensitive); the "all"
                # sentinel proceeds unfiltered. A missing pending confirmation
                # falls back to treating this as a fresh question.
                unit_target = user_action_raw.split(":", 1)[1].strip()
                if pending:
                    working_question = pending.get("question", payload.question)
                if unit_target and unit_target.lower() != "all":
                    effective_unit_id = unit_target
                # Reuse the ORIGINAL question's category scope (stashed when the
                # checkpoint fired) — the follow-up turn's text is just the unit
                # label, so re-predicting over it would drop the real scope.
                pending_categories = pending.get("selected_categories") if pending else None
                if pending_categories:
                    selected_categories = [
                        category for category in pending_categories if category in ALLOWED_CATEGORIES
                    ]
                    category_filter_mode = "clarification_selected"
                else:
                    selected_categories = [
                        category for category in predicted_categories if category in ALLOWED_CATEGORIES
                    ]
                    if selected_categories:
                        category_filter_mode = "auto"
                self._conversation_store.clear_pending_confirmation(session_id)
            elif user_action in ALLOWED_CATEGORIES:
                selected_categories = [user_action]
                working_question = pending.get("question", payload.question) if pending else payload.question
                category_filter_mode = "clarification_selected"
                self._conversation_store.clear_pending_confirmation(session_id)
            else:
                # Auto scope: apply the predicted categories only when the
                # predictor is reasonably confident; a weak prediction searches
                # the whole corpus rather than risking a wrong silent filter.
                if graph_state.get("prediction_confidence", 0.0) >= 0.45:
                    selected_categories = [
                        category for category in predicted_categories if category in ALLOWED_CATEGORIES
                    ]
                if selected_categories:
                    category_filter_mode = "auto"

        # Unit routing (skipped when the header dropdown already scopes the
        # chat or this turn resumes a unit checkpoint). The search-router LLM
        # decides the unit scope from the question when it can (tool-style
        # routing); when it couldn't, deterministic label matching takes over.
        # Either way: explicit references route silently, a reference matching
        # several units is the only case that still asks, and a reference to a
        # unit that does not exist gets an honest answer listing the real ones.
        user_action_lower = (payload.user_action or "").strip().lower()
        if effective_unit_id is None and not user_action_lower.startswith("unit:"):
            unit_ids = {unit["unit_id"] for unit in property_units}
            routed_unit_id = graph_state.get("routed_unit_id")
            unknown_mention = graph_state.get("unknown_unit_mention")
            ambiguous_candidates = None

            if unknown_mention:
                pass  # honest not-found answer below
            elif routed_unit_id and routed_unit_id in unit_ids:
                effective_unit_id = routed_unit_id
            elif not graph_state.get("unit_routing_decided"):
                unit_resolution = resolve_unit_mention(working_question, property_units)
                if unit_resolution["kind"] == "scoped":
                    effective_unit_id = unit_resolution["unit"]["unit_id"]
                elif unit_resolution["kind"] == "unknown":
                    unknown_mention = unit_resolution["mention"]
                elif unit_resolution["kind"] == "ambiguous":
                    ambiguous_candidates = unit_resolution["candidates"]

            if unknown_mention:
                unit_labels = ", ".join(sorted(u["label"] for u in property_units))
                not_found_message = (
                    f"I couldn't find {unknown_mention} in {property_name}. "
                    f"This property's units are: {unit_labels}. "
                    "Ask about one of those, or ask without naming a unit to search everything."
                )
                self._conversation_store.append_turn(
                    session_id,
                    {
                        "turn": turn_number,
                        "question": working_question,
                        "intent": "document_question",
                        "action": "unknown_unit",
                        "answer": not_found_message,
                    },
                )
                return AskResponse(
                    answer=not_found_message,
                    confidence=0.9,
                    citations=[],
                    property_name=property_name,
                    searched_categories=selected_categories,
                    category_filter_mode=category_filter_mode,
                    session_id=session_id,
                    conversation_turn=turn_number,
                    user_action_required=False,
                    predicted_categories=predicted_categories,
                    action_reason="Question referenced a unit that does not exist",
                )

            if ambiguous_candidates:
                unit_options = [
                    UnitOption(unit_id=u["unit_id"], unit_label=u["label"])
                    for u in sorted(ambiguous_candidates, key=lambda u: u["label"])
                ]
                unit_options.append(UnitOption(unit_id="all", unit_label="All units"))
                matched_labels = " and ".join(
                    option.unit_label for option in unit_options[:-1]
                )
                unit_prompt = (
                    f"That could mean {matched_labels}. Which unit do you mean?"
                )
                self._conversation_store.set_pending_confirmation(
                    session_id,
                    {
                        "type": "unit",
                        "question": working_question,
                        "selected_categories": selected_categories,
                        "unit_options": [option.model_dump() for option in unit_options],
                    },
                )
                self._conversation_store.append_turn(
                    session_id,
                    {
                        "turn": turn_number,
                        "question": working_question,
                        "intent": "document_question",
                        "action": "ask_unit_clarification",
                        "unit_options": [option.unit_id for option in unit_options],
                    },
                )
                return AskResponse(
                    answer=unit_prompt,
                    confidence=0.6,
                    citations=[],
                    property_name=property_name,
                    searched_categories=selected_categories,
                    category_filter_mode=category_filter_mode,
                    needs_category_clarification=False,
                    clarification_prompt=unit_prompt,
                    clarification_options=[],
                    session_id=session_id,
                    conversation_turn=turn_number,
                    user_action_required=True,
                    needs_unit_clarification=True,
                    unit_options=unit_options,
                    predicted_categories=predicted_categories,
                    action_reason="Unit reference matches multiple units",
                )
            # "multi", "aggregate", and "none" all search unscoped; the answer
            # prompt attributes every fact to its unit.

        try:
            retrieved_chunks = await self._hybrid_retriever.retrieve(
                question=working_question,
                landlord_id=payload.landlord_id,
                property_id=payload.property_id,
                top_k=payload.top_k,
                categories=expand_categories_for_query(selected_categories) if selected_categories else None,
                unit_id=effective_unit_id,
            )
            print(f"✅ Retrieved {len(retrieved_chunks)} chunks (hybrid dense+rerank)")
        except Exception as e:
            print(f"❌ Hybrid retrieval failed: {e}")
            return AskResponse(
                answer="I couldn't search your documents. Please check your Firestore vector index.",
                confidence=0.0,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=predicted_categories,
                action_reason="Vector search failure",
            )

        if not retrieved_chunks:
            if selected_categories:
                category_hint = ", ".join(selected_categories)
                not_found_message = f"I couldn't find relevant information in your {category_hint} documents for {property_name}."
            else:
                not_found_message = f"I couldn't find relevant information in your documents for {property_name}."
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": working_question,
                    "intent": "document_question",
                    "action": "retrieve_no_result",
                    "searched_categories": selected_categories,
                    "answer": not_found_message,
                },
            )
            return AskResponse(
                answer=not_found_message,
                confidence=0.0,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=predicted_categories,
                action_reason="No chunks retrieved",
            )

        # No post-retrieval unit checkpoint: unit routing happened above from
        # the question text, and answers over mixed-unit chunks attribute every
        # fact to its unit (prompt rule 5) instead of blocking to ask.

        # Dedupe citations by (filename, page): multiple chunks can come from
        # the same page (overlapping splits), each with its own rerank score.
        # The LLM still sees every chunk's text via context_text below; this
        # only collapses what's shown as a citation, keeping the best score
        # per page so the same source never appears twice with two different
        # relevance bars.
        best_citation_by_page: dict[tuple[str, Optional[int]], dict] = {}
        context_text = ""
        for i, chunk in enumerate(retrieved_chunks):
            display_page = chunk['page'] + 1 if chunk.get('page') is not None else None
            page_key = (chunk['filename'], display_page)
            chunk_score = chunk.get('rerank_score', chunk.get('dense_score', 0.0))
            existing = best_citation_by_page.get(page_key)
            if existing is None or chunk_score > existing['score']:
                best_citation_by_page[page_key] = {
                    'doc_id': chunk['doc_id'],
                    'filename': chunk['filename'],
                    'category': normalize_category(chunk['category']),
                    'page': display_page,
                    'snippet': chunk['text'][:200],
                    'score': chunk_score,
                    'unit_id': chunk.get('unit_id'),
                    'unit_label': chunk.get('unit_label'),
                }
            unit_context = chunk.get('unit_label') or 'Property-wide'
            # PII gate: chunk text is the one place raw document content reaches
            # the hosted LLM. Scrub NRIC/phone/email here (citations to the app
            # keep the unscrubbed snippet — the user owns their own documents).
            safe_chunk_text = scrub_for_hosted(chunk['text'])
            context_text += f"\n\n[Document {i+1}: {chunk['filename']}, Page {display_page if display_page is not None else 'N/A'} — {unit_context}]\n{safe_chunk_text}"

        citations = [
            Citation(
                doc_id=c['doc_id'],
                filename=c['filename'],
                category=c['category'],
                page=c['page'],
                snippet=c['snippet'],
                score=c['score'],
                unit_id=c['unit_id'],
                unit_label=c['unit_label'],
            )
            for c in sorted(best_citation_by_page.values(), key=lambda c: c['score'], reverse=True)
        ]

        searched_categories_text = ", ".join(selected_categories) if selected_categories else "all categories"
        prompt = f"""You are DocuMind, an AI assistant specialized in property document management.

    **Your Purpose:**
    You help landlords understand their property documents across 7 categories:
    - Tenancy Agreements (lease terms, tenant details, rent, deposits, renewals)
    - Insurance Policies (coverage, premiums, policy periods)
    - Loans (loan agreements, bank interest statements)
    - Property Taxes (assessment tax, quit rent, parcel rent)
    - Upkeep (landlord-paid repairs and servicing)
    - Maintenance (management fees and sinking fund)
    - Rental Invoices (monthly rent billed to tenants)

    **User Question:**
    {working_question}

    **Current Property:**
    {property_name}

    **Categories Searched:**
    {searched_categories_text}

    **Relevant Document Excerpts:**
    {context_text}

    **Instructions:**
    1. **IF** the question is about property documents (lease, insurance, loan, tax, upkeep, maintenance, rental invoices):
    - Answer based ONLY on the context above
    - Do NOT cite sources or mention filenames/pages — the app displays sources separately
    - Format dates clearly (e.g., "15 March 2026")
    - Keep your answer detailed and informative but organized and concise (bullet points or numbered lists)

    2. **IF** the question is off-topic (weather, sports, general knowledge, personal advice):
    - Accomodate and Politely redirect to your purpose
        
    3. **IF** you cannot find the answer in the context:
    If there is uploaded documents to reference: 
    - Mention that the inquired information is not found in the uploaded documents and list out the documents you have searched, only in its relevant category.
    Else if there are no uploaded documents to reference: 
    - Say "You do not have any relevant uploaded documents for that matter. Please upload a [category name] document to get answers about [specific topic]."
    
    4. **DO NOT** make up information - only use what's provided in the context.

    5. **Unit attribution:** Each excerpt header names the unit it belongs to (or "Property-wide"). Never blend values from different units — attribute every figure to its unit. If the excerpts span multiple units, break the answer down per unit (e.g. "Unit A-12-03: ...", "Unit B-08-11: ..."). For totals across units, show each unit's value and then the combined total. Property-wide documents apply to the whole property.

    **Your Answer:**"""

        try:
            response = self.llm.invoke(prompt)
            answer = response.content.strip()
            print(f"✅ Generated answer: {answer[:100]}...")
        except Exception as e:
            print(f"❌ Gemini answer generation failed: {e}")
            answer = "I encountered an error generating an answer. Please try again."
        
        response = AskResponse(
            answer=answer,
            confidence=0.95,  # Mock confidence
            citations=citations,
            property_name=property_name,
            searched_categories=selected_categories,
            category_filter_mode=category_filter_mode,
            needs_category_clarification=False,
            clarification_prompt=None,
            clarification_options=[],
            session_id=session_id,
            conversation_turn=turn_number,
            user_action_required=False,
            predicted_categories=predicted_categories,
            action_reason=action_reason,
        )

        self._conversation_store.append_turn(
            session_id,
            {
                "turn": turn_number,
                "question": working_question,
                "intent": "document_question",
                "action": "retrieve",
                "searched_categories": selected_categories,
                "answer": answer,
            },
        )

        return response

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