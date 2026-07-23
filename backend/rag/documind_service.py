import os
import re
import uuid
import tempfile
from typing import Any, Dict, List, Optional, Tuple
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
from rag.pdf_ocr import PdfOcr
from rag.ollama_embeddings import OllamaEmbeddings
from rag.pii_scrub import scrub_for_hosted
from rag.conversation_store import ConversationStore
from rag.graph_orchestrator import DocuMindGraphOrchestrator
from rag.retriever import HybridRetriever
from rag.finance_engine import compute_finance_summary, document_tags

EMBED_DIM = 768 # Default to 768 if not set
OCR_TEXT_THRESHOLD = 200  # chars; below this a PDF is treated as scanned
_PAYMENT_MONTH_RE = re.compile(r"^\d{4}-\d{2}$")

UPLOAD_CONTENT_TYPES = {
    ".pdf": "application/pdf",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
}


def resolve_upload_kind(filename: Optional[str]) -> Tuple[str, str]:
    """(extension, content_type) for an upload; ValueError for anything the
    ingestion pipeline can't read."""
    ext = os.path.splitext(filename or "")[1].lower()
    content_type = UPLOAD_CONTENT_TYPES.get(ext)
    if content_type is None:
        raise ValueError("Unsupported file type. Upload a PDF or a JPG/PNG image.")
    return ext, content_type
# 7-category taxonomy (2026-07 financial-intelligence spec) plus the
# 'expenses' ingestion bucket (2026-07-18): combined statements upload as
# 'expenses' and carry line items instead of one amount. Documents stored
# before either rename keep their category strings; LEGACY_CATEGORY_ALIASES
# maps them at every read and expand_categories_for_query() widens
# stored-name queries. No data migration.
ALLOWED_CATEGORIES = {
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
}
CATEGORY_ORDER = [
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
]
LEGACY_CATEGORY_ALIASES = {
    "utility": "upkeep",
    "receipt": "rental_invoice",
    "warranty": "upkeep",
}
# Granular stored names the Expenses bucket groups at display/query time.
EXPENSE_GROUP = ["insurance", "loan", "tax", "upkeep", "maintenance"]


def normalize_category(category: Optional[str]) -> Optional[str]:
    """Stored/legacy category -> current taxonomy name (read-time alias)."""
    if not category:
        return category
    lowered = category.strip().lower()
    return LEGACY_CATEGORY_ALIASES.get(lowered, lowered)


def expand_categories_for_query(categories: List[str]) -> List[str]:
    """Current-taxonomy filter -> every stored name it must match: legacy
    spellings (chunks written pre-rename still carry 'utility' etc.) and the
    expenses group in both directions — an 'expenses' filter matches granular
    docs, and a granular filter matches combined 'expenses' statements."""
    expanded: List[str] = []

    def _add(name: str) -> None:
        if name not in expanded:
            expanded.append(name)

    for category in categories:
        _add(category)
        for legacy, current in LEGACY_CATEGORY_ALIASES.items():
            if current == category:
                _add(legacy)
        if category == "expenses":
            for granular in EXPENSE_GROUP:
                _add(granular)
                for legacy, current in LEGACY_CATEGORY_ALIASES.items():
                    if current == granular:
                        _add(legacy)
        elif category in EXPENSE_GROUP:
            _add("expenses")
    return expanded

# Question-side unit reference resolution. Matching is deterministic and
# label-driven: "unit a" resolves to "Unit A-12-03" only when exactly one
# unit label starts with that reference at a segment boundary.
_UNIT_REF_PATTERN = re.compile(r"\bunit\s+([a-z0-9]+(?:-[a-z0-9]+)*)")
_AGGREGATE_UNIT_PHRASES = (
    "all units", "all the units", "all my units", "across units",
    "every unit", "each unit", "per unit", "between units",
)


def _label_matches_token(label: str, token: str) -> bool:
    label_norm = " ".join(label.lower().split())
    prefix = f"unit {token}"
    if label_norm == token or label_norm == prefix:
        return True
    if label_norm.startswith(prefix):
        # Boundary check so "unit a" never matches "Unit AB-2".
        return label_norm[len(prefix):][:1] in ("-", " ", ".")
    return False


def resolve_unit_mention(question: str, units: List[Dict]) -> Dict:
    """Decide which unit(s) a question refers to, before retrieval runs.

    units: [{"unit_id": ..., "label": ...}]. Returns a dict whose "kind" is:
      none      - no unit signal; search everything, attribute per unit
      scoped    - exactly one unit referenced -> {"unit": {...}}
      multi     - several units named deliberately; search everything
      aggregate - "all units"-style phrasing; search everything
      ambiguous - one reference matches several units -> {"candidates": [...]}
      unknown   - a unit was named that does not exist -> {"mention": str}
    """
    q = " ".join((question or "").lower().split())
    if not q or not units:
        return {"kind": "none"}

    named = [
        u for u in units
        if u.get("label") and " ".join(u["label"].lower().split()) in q
    ]
    if len(named) == 1:
        return {"kind": "scoped", "unit": named[0]}
    if len(named) >= 2:
        return {"kind": "multi"}

    if any(phrase in q for phrase in _AGGREGATE_UNIT_PHRASES):
        return {"kind": "aggregate"}

    resolved: Dict[str, Dict] = {}
    for token in _UNIT_REF_PATTERN.findall(q):
        candidates = [
            u for u in units
            if u.get("label") and _label_matches_token(u["label"], token)
        ]
        if not candidates:
            return {"kind": "unknown", "mention": f"Unit {token.upper()}"}
        if len(candidates) > 1:
            return {"kind": "ambiguous", "candidates": candidates}
        resolved[candidates[0]["unit_id"]] = candidates[0]

    if len(resolved) == 1:
        return {"kind": "scoped", "unit": next(iter(resolved.values()))}
    if len(resolved) >= 2:
        return {"kind": "multi"}
    return {"kind": "none"}


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
            model = os.getenv("OLLAMA_FACT_MODEL", "qwen2.5:3b")
            print(f"🔄 Fact extraction routed to local Ollama ({model})")
            return OllamaChat(model=model, base_url=os.getenv("OLLAMA_BASE_URL"))
        return self._llm

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
        """Fetch property name from Firestore for user-facing responses."""
        property_name = "Unknown Property"
        try:
            property_doc = self.db.collection('properties').document(property_id).get()
            if property_doc.exists:
                property_data = property_doc.to_dict()
                property_name = property_data.get('name') if property_data else 'Unknown Property'
        except Exception as e:
            print(f"⚠️ Could not fetch property name: {e}")
        return property_name

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
        """Unit ids + labels for a property. Empty on lookup failure so a
        units outage degrades to unscoped search instead of blocking."""
        try:
            snapshots = (
                self.db.collection('properties')
                .document(property_id)
                .collection('units')
                .stream()
            )
            return [
                {
                    "unit_id": snap.id,
                    "label": (snap.to_dict() or {}).get('label') or snap.id,
                }
                for snap in snapshots
            ]
        except Exception as e:
            print(f"⚠️ Unit lookup failed for property {property_id}: {e}")
            return []

    def _list_landlord_properties(self, landlord_id: str) -> List[Dict]:
        """Property ids/names/ownership shares for a landlord. The properties
        collection is Flutter-owned (field 'landlordId'); ownership_share is
        optional and defaults to 1.0. Empty on lookup failure."""
        try:
            snapshots = (
                self.db.collection('properties')
                .where(filter=FieldFilter('landlordId', '==', landlord_id))
                .stream()
            )
            results = []
            for snap in snapshots:
                data = snap.to_dict() or {}
                try:
                    share = float(data.get('ownership_share') or 1.0)
                except (TypeError, ValueError):
                    share = 1.0
                results.append({
                    "property_id": snap.id,
                    "name": data.get('name') or snap.id,
                    "ownership_share": share,
                    "property_type": data.get('property_type'),
                    "has_mortgage": data.get('has_mortgage'),
                    "utilities_paid_by": data.get('utilities_paid_by'),
                    "track_from_year": data.get('track_from_year'),
                })
            return results
        except Exception as e:
            print(f"⚠️ Property lookup failed for landlord {landlord_id}: {e}")
            return []

    async def ingest_document(
        self,
        landlord_id: str,
        property_id: str,
        category: str,
        file: UploadFile,
        unit_id: Optional[str] = None,
        unit_label: Optional[str] = None,
    ) -> DocUploadResponse:
        """
        Ingest document into Firestore with vector embeddings.
        """
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

            # Step 3: Chunk text
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=1000,
                chunk_overlap=200,
            )
            chunks = text_splitter.split_documents(pages)
            
            print(f"📝 Split into {len(chunks)} chunks")
            
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

            # Fact extraction (best-effort, one LLM call over the leading
            # text). Failure must never block indexing.
            extracted_facts = None
            facts_confidence = None
            try:
                full_text = "\n".join(page.page_content or "" for page in pages)
                facts = self._fact_extractor.extract(category, full_text)
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
            )
        
        except Exception as e:
            print(f"❌ Document ingestion failed: {e}")
            raise
        
        finally:
            # Step 7: Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                print(f"🗑️ Cleaned up temp file: {temp_path}")

    async def update_expense_lines(
        self, doc_id: str, landlord_id: str, lines: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Replace a document's expense_lines after user review. Validation
        reuses the extractor whitelist, so the API can never store a subtype
        the finance engine doesn't understand."""
        cleaned = validate_expense_lines(lines)
        if not cleaned:
            raise ValueError(
                "No valid expense lines. Each line needs a known subtype and an amount."
            )
        doc_ref = self.db.collection('documind_docs').document(doc_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise ValueError("Document not found.")
        data = snapshot.to_dict() or {}
        if data.get("landlord_id") != landlord_id:
            raise ValueError("Document not found.")
        facts = dict(data.get("extracted_facts") or {})
        facts["expense_lines"] = cleaned
        doc_ref.update({
            "extracted_facts": facts,
            "facts_extracted_at": firestore.SERVER_TIMESTAMP,
        })
        return {"doc_id": doc_id, "extracted_facts": facts}

    def _payment_exception_doc_id(self, property_id: str, unit_id: Optional[str], month: str) -> str:
        return f"{property_id}__{unit_id or 'property'}__{month}"

    async def set_payment_exception(
        self,
        *,
        landlord_id: str,
        property_id: str,
        month: str,
        unit_id: Optional[str] = None,
        reason: Optional[str] = None,
        state: str = "outstanding",
    ) -> Dict[str, Any]:
        """Upsert a 'no payment received' mark for one month. Deterministic
        doc id keeps set/clear idempotent — no duplicate marks possible."""
        if not _PAYMENT_MONTH_RE.match(month or ""):
            raise ValueError("month must be formatted YYYY-MM")
        property_ref = self.db.collection('properties').document(property_id)
        property_snapshot = property_ref.get()
        if not property_snapshot.exists or (property_snapshot.to_dict() or {}).get('landlordId') != landlord_id:
            raise ValueError(f"Property {property_id} not found for landlord {landlord_id}")
        doc_id = self._payment_exception_doc_id(property_id, unit_id, month)
        ref = self.db.collection('documind_payment_exceptions').document(doc_id)
        ref.set({
            'landlord_id': landlord_id,
            'property_id': property_id,
            'unit_id': unit_id,
            'month': month,
            'reason': reason,
            'state': state,
            'created_at': firestore.SERVER_TIMESTAMP,
        })
        return {"property_id": property_id, "unit_id": unit_id, "month": month, "reason": reason, "state": state}

    async def clear_payment_exception(
        self,
        *,
        landlord_id: str,
        property_id: str,
        month: str,
        unit_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Remove a 'no payment received' mark, if any. Idempotent — clearing
        an unmarked month is a no-op, not an error."""
        doc_id = self._payment_exception_doc_id(property_id, unit_id, month)
        ref = self.db.collection('documind_payment_exceptions').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "unit_id": unit_id, "month": month}

    def _document_exception_doc_id(self, property_id: str, year: int, category: str) -> str:
        return f"{property_id}__{year}__{category}"

    async def set_document_unavailable(
        self, *, landlord_id: str, property_id: str, year: int, category: str,
    ) -> Dict[str, Any]:
        """Acknowledge that a coverage gap cannot be filled, so the year
        settles as complete-with-gaps instead of nagging permanently.
        Idempotent — re-marking the same scope is a no-op."""
        property_ref = self.db.collection('properties').document(property_id)
        property_snapshot = property_ref.get()
        if not property_snapshot.exists or (property_snapshot.to_dict() or {}).get('landlordId') != landlord_id:
            raise ValueError(f"Property {property_id} not found for landlord {landlord_id}")
        doc_id = self._document_exception_doc_id(property_id, year, category)
        ref = self.db.collection('documind_document_exceptions').document(doc_id)
        ref.set({
            'landlord_id': landlord_id,
            'property_id': property_id,
            'year': year,
            'category': category,
            'marked_at': firestore.SERVER_TIMESTAMP,
        })
        return {"property_id": property_id, "year": year, "category": category}

    async def clear_document_unavailable(
        self, *, landlord_id: str, property_id: str, year: int, category: str,
    ) -> Dict[str, Any]:
        """Clear an 'unavailable' mark. Idempotent — clearing an unmarked
        scope is a no-op, not an error."""
        doc_id = self._document_exception_doc_id(property_id, year, category)
        ref = self.db.collection('documind_document_exceptions').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "year": year, "category": category}

    def _rent_recovery_doc_id(self, property_id: str, unit_id: Optional[str], original_month: str) -> str:
        return f"{property_id}__{unit_id or 'property'}__{original_month}"

    async def record_rent_recovery(
        self, *, landlord_id: str, property_id: str, original_month: str,
        amount: float, received_year: int, unit_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Book a written-off month's rent as income in the year it
        actually arrived, without reopening the original (frozen) year.
        Requires the month to already be on file as written_off — a
        recovery corrects a specific write-off, it is never a free-
        floating credit. Idempotent — recording the same scope again
        overwrites the amount/year."""
        if not _PAYMENT_MONTH_RE.match(original_month or ""):
            raise ValueError("original_month must be formatted YYYY-MM")
        property_ref = self.db.collection('properties').document(property_id)
        property_snapshot = property_ref.get()
        if not property_snapshot.exists or (property_snapshot.to_dict() or {}).get('landlordId') != landlord_id:
            raise ValueError(f"Property {property_id} not found for landlord {landlord_id}")
        exception_id = self._payment_exception_doc_id(property_id, unit_id, original_month)
        exception_snapshot = self.db.collection('documind_payment_exceptions').document(exception_id).get()
        exception_data = exception_snapshot.to_dict() if exception_snapshot.exists else None
        if not exception_data or exception_data.get("state") != "written_off":
            raise ValueError(
                f"{original_month} is not on file as written_off for this scope; "
                "a recovery can only be recorded against a written-off month."
            )
        doc_id = self._rent_recovery_doc_id(property_id, unit_id, original_month)
        ref = self.db.collection('documind_rent_recoveries').document(doc_id)
        ref.set({
            'landlord_id': landlord_id,
            'property_id': property_id,
            'unit_id': unit_id,
            'original_month': original_month,
            'amount': float(amount),
            'received_year': received_year,
            'recorded_at': firestore.SERVER_TIMESTAMP,
        })
        return {
            "property_id": property_id, "unit_id": unit_id, "original_month": original_month,
            "amount": float(amount), "received_year": received_year,
        }

    async def clear_rent_recovery(
        self, *, landlord_id: str, property_id: str, original_month: str, unit_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Remove a recorded recovery. Idempotent — clearing an unrecorded
        scope is a no-op, not an error. Does not affect the underlying
        written_off exception."""
        doc_id = self._rent_recovery_doc_id(property_id, unit_id, original_month)
        ref = self.db.collection('documind_rent_recoveries').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "unit_id": unit_id, "original_month": original_month}

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

    async def list_documents(
        self,
        landlord_id: str,
        property_id: Optional[str] = None,
        unit_id: Optional[str] = None,
    ) -> DocListResponse:
        """
        List documents from Firestore metadata collection.

        Args:
            landlord_id: Filter by landlord
            property_id: Optional filter by specific property
            unit_id: Optional unit filter — matches documents assigned to
                this unit plus property-wide documents. Applied as a Python
                post-filter because docs uploaded before units existed have
                no unit_id field, which a Firestore where-clause can never
                match.

        Returns:
            DocListResponse with documents array, total_count
        """
        query = self.db.collection('documind_docs').where(filter=FieldFilter('landlord_id', '==', landlord_id))

        if property_id:
            query = query.where(filter=FieldFilter('property_id', '==', property_id))

        docs = query.stream()

        documents = []
        for doc in docs:
            data = doc.to_dict()

            if unit_id and data.get('unit_id') not in (None, unit_id):
                continue

            # Convert Firestore Timestamp to datetime
            uploaded_at = data.get('uploaded_at')
            if isinstance(uploaded_at, firestore.SERVER_TIMESTAMP.__class__):
                uploaded_at = datetime.now()
            elif hasattr(uploaded_at, 'to_pydantic'):
                uploaded_at = uploaded_at.to_pydantic()

            category = normalize_category(data.get('category'))
            documents.append(DocumentInfo(
                doc_id=doc.id,
                landlord_id=data.get('landlord_id'),
                property_id=data.get('property_id'),
                category=category,
                filename=data.get('filename'),
                uploaded_at=uploaded_at,
                chunks_indexed=data.get('chunks_indexed'),
                file_size=data.get('file_size'),
                unit_id=data.get('unit_id'),
                unit_label=data.get('unit_label'),
                extracted_facts=data.get('extracted_facts'),
                facts_confidence=data.get('facts_confidence'),
                tags=[DocumentTag(**t) for t in document_tags(category, data.get('extracted_facts'))],
            ))
        
        print(f"✅ Listed {len(documents)} documents")
        
        return DocListResponse(
            documents=documents,
            total_count=len(documents),
            filtered_by_property=property_id
        )

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

        payment_exceptions = []
        exceptions_query = self.db.collection('documind_payment_exceptions').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        for snap in exceptions_query.stream():
            data = snap.to_dict() or {}
            payment_exceptions.append({
                "property_id": data.get("property_id"),
                "unit_id": data.get("unit_id"),
                "month": data.get("month"),
                "reason": data.get("reason"),
                "state": data.get("state") or "outstanding",
            })

        document_exceptions = []
        doc_exceptions_query = self.db.collection('documind_document_exceptions').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        for snap in doc_exceptions_query.stream():
            data = snap.to_dict() or {}
            document_exceptions.append({
                "property_id": data.get("property_id"),
                "year": data.get("year"),
                "category": data.get("category"),
            })

        rent_recoveries = []
        recoveries_query = self.db.collection('documind_rent_recoveries').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        for snap in recoveries_query.stream():
            data = snap.to_dict() or {}
            rent_recoveries.append({
                "property_id": data.get("property_id"),
                "unit_id": data.get("unit_id"),
                "original_month": data.get("original_month"),
                "amount": data.get("amount"),
                "received_year": data.get("received_year"),
            })

        summary = compute_finance_summary(
            year=year,
            today=date.today(),
            documents=documents,
            properties=properties,
            units_by_property=units_by_property,
            payment_exceptions=payment_exceptions,
            document_exceptions=document_exceptions,
            rent_recoveries=rent_recoveries,
        )
        return FinanceSummaryResponse(**summary)

    async def delete_document(
        self, 
        landlord_id: str, 
        property_id: str,
        doc_id: str
    ) -> dict:
        """
        Delete a document and all its chunks from Firestore.
        
        Security:
        - Verifies landlord owns the document
        - Verifies document belongs to property
        - Cascades deletion to all chunks
        
        Args:
            landlord_id: Landlord ID for ownership verification
            property_id: Property ID for scoping
            doc_id: Document ID to delete
            
        Returns:
            dict with deletion summary
            
        Raises:
            ValueError: If document not found or ownership mismatch
        """
        print(f"🔵 DocuMind: Delete document {doc_id}")
        print(f"   - Landlord: {landlord_id}")
        print(f"   - Property: {property_id}")
        
        # Step 1: Verify document exists and ownership
        doc_ref = self.db.collection('documind_docs').document(doc_id)
        doc_snapshot = doc_ref.get()
        
        if not doc_snapshot.exists:
            raise ValueError(f"Document {doc_id} not found")
        
        doc_data = doc_snapshot.to_dict()
        
        # Step 2: Validate ownership
        if doc_data.get('landlord_id') != landlord_id:
            raise ValueError(f"Document {doc_id} does not belong to landlord {landlord_id}")
        
        if doc_data.get('property_id') != property_id:
            raise ValueError(f"Document {doc_id} does not belong to property {property_id}")
        
        # Step 3: Delete all chunks associated with this document
        chunks_ref = self.db.collection('documind_chunks')
        chunks_query = chunks_ref.where(filter=FieldFilter('doc_id', '==', doc_id))
        chunks_to_delete = chunks_query.stream()
        
        deleted_chunks_count = 0
        batch = self.db.batch()
        
        for chunk_doc in chunks_to_delete:
            batch.delete(chunk_doc.reference)
            deleted_chunks_count += 1
        
        # Commit chunk deletions
        if deleted_chunks_count > 0:
            batch.commit()
            print(f"✅ Deleted {deleted_chunks_count} chunks")

        # Step 3.5: Delete the original file from Storage, if one exists
        storage_path = doc_data.get('storage_path')
        if storage_path:
            try:
                self.storage_bucket.blob(storage_path).delete()
                print(f"Deleted storage object {storage_path}")
            except Exception as e:
                print(f"Warning: could not delete storage object {storage_path}: {e}")

        # Step 4: Delete document metadata
        doc_ref.delete()
        print(f"✅ Deleted document {doc_id}")
        
        return {
            "message": "Document deleted successfully",
            "doc_id": doc_id,
            "filename": doc_data.get('filename', 'Unknown'),
            "chunks_deleted": deleted_chunks_count,
        }

    async def delete_documents_for_property(
        self,
        landlord_id: str,
        property_id: str,
    ) -> dict:
        """
        Delete ALL documents (metadata + chunks + stored PDFs) for a property.

        Used by the property-deletion cascade in the app. Idempotent: a
        property with no documents returns a zero-count success.
        """
        print(f"🔵 DocuMind: Delete all documents for property {property_id}")

        docs_query = (
            self.db.collection('documind_docs')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
        )

        documents_deleted = 0
        chunks_deleted = 0
        for doc_snapshot in docs_query.stream():
            result = await self.delete_document(
                landlord_id=landlord_id,
                property_id=property_id,
                doc_id=doc_snapshot.id,
            )
            documents_deleted += 1
            chunks_deleted += result.get('chunks_deleted', 0)

        print(f"✅ Deleted {documents_deleted} documents / {chunks_deleted} chunks for property {property_id}")

        return {
            "message": "Property documents deleted",
            "property_id": property_id,
            "documents_deleted": documents_deleted,
            "chunks_deleted": chunks_deleted,
        }

    async def unassign_unit_documents(
        self,
        landlord_id: str,
        property_id: str,
        unit_id: str,
    ) -> dict:
        """
        Clear the unit assignment on every doc + chunk scoped to a unit,
        converting them to property-wide documents.

        Called by the app before deleting a unit so its documents are
        unassigned rather than orphaned with a stale unit_id. Idempotent: a
        unit with no assigned documents returns zero counts. A single batch
        is fine at this scale (Firestore's 500-op batch limit).
        """
        print(f"🔵 DocuMind: Unassign unit {unit_id} documents for property {property_id}")

        batch = self.db.batch()
        documents_updated = 0
        chunks_updated = 0

        docs_query = (
            self.db.collection('documind_docs')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in docs_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            documents_updated += 1

        chunks_query = (
            self.db.collection('documind_chunks')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in chunks_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            chunks_updated += 1

        if documents_updated or chunks_updated:
            batch.commit()

        print(f"✅ Unassigned {documents_updated} docs / {chunks_updated} chunks from unit {unit_id}")

        return {
            "message": "Unit documents unassigned",
            "unit_id": unit_id,
            "documents_updated": documents_updated,
            "chunks_updated": chunks_updated,
        }

    async def get_document_view_url(
        self,
        landlord_id: str,
        property_id: str,
        doc_id: str,
    ) -> str:
        """
        Generate a short-lived signed URL to view a document's original PDF.

        Raises:
            ValueError: If document not found or ownership/scope mismatch.
        """
        doc_ref = self.db.collection('documind_docs').document(doc_id)
        doc_snapshot = doc_ref.get()

        if not doc_snapshot.exists:
            raise ValueError(f"Document {doc_id} not found")

        doc_data = doc_snapshot.to_dict()

        if doc_data.get('landlord_id') != landlord_id:
            raise ValueError(f"Document {doc_id} does not belong to landlord {landlord_id}")

        if doc_data.get('property_id') != property_id:
            raise ValueError(f"Document {doc_id} does not belong to property {property_id}")

        storage_path = doc_data.get('storage_path')
        if not storage_path:
            raise ValueError(f"Document {doc_id} has no stored file")

        blob = self.storage_bucket.blob(storage_path)
        return blob.generate_signed_url(expiration=timedelta(minutes=10), method="GET")

# Singleton instance
documind_service = DocuMindService()