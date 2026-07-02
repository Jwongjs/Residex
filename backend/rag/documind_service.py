import os
import uuid
import tempfile
from typing import Dict, List, Optional
from fastapi import UploadFile
from models.documind_models import *
from datetime import datetime

from dotenv import load_dotenv
load_dotenv()  

# LangChain core
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter

# Gemini embeddings & LLM
from langchain_google_genai import GoogleGenerativeAIEmbeddings, ChatGoogleGenerativeAI

# Firestore imports
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1.vector import Vector
from google.cloud.firestore_v1.base_vector_query import DistanceMeasure
from rag.conversation_router import ConversationRouter
from rag.category_predictor import CategoryPredictor
from rag.conversation_store import ConversationStore
from rag.graph_orchestrator import DocuMindGraphOrchestrator
from rag.retriever import HybridRetriever

EMBED_DIM = 768 # Default to 768 if not set
ALLOWED_CATEGORIES = {"lease", "warranty", "insurance", "utility", "receipt"}
CATEGORY_KEYWORDS = {
    "lease": [
        "lease", "tenancy", "tenant", "rent", "rental", "deposit", "landlord", "agreement", "renewal", "termination"
    ],
    "warranty": [
        "warranty", "covered", "coverage", "claim", "expiry", "expire", "guarantee", "appliance", "manufacturer"
    ],
    "insurance": [
        "insurance", "policy", "premium", "insurer", "deductible", "claim", "coverage", "liability", "endorsement"
    ],
    "utility": [
        "utility", "utilities", "electric", "electricity", "water", "gas", "bill", "meter", "kwh", "usage"
    ],
    "receipt": [
        "receipt", "invoice", "invoices", "payment", "repair", "maintenance", "vendor", "purchase", "cost"
    ],
}

db = firestore.Client()
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
        self._embeddings = embeddings
        self._llm = llm
        self._hybrid_retriever = HybridRetriever(db=self._db, embeddings=self._embeddings)
        self._conversation_store = ConversationStore(self._db)
        self._conversation_router = ConversationRouter(self._llm)
        self._category_predictor = CategoryPredictor(
            self._llm,
            allowed_categories=sorted(ALLOWED_CATEGORIES),
        )
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
        """Lazy-load Gemini embeddings with FIXED 768 dimensions."""
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

    def _detect_categories_from_question(self, question: str) -> List[str]:
        """Infer likely document categories from question keywords."""
        lowered_question = (question or "").lower()
        detected = []

        for category, keywords in CATEGORY_KEYWORDS.items():
            if any(keyword in lowered_question for keyword in keywords):
                detected.append(category)

        return detected[:10]

    def _list_available_categories(self, landlord_id: str, property_id: str) -> List[str]:
        """List categories that have uploaded docs for this landlord/property."""
        try:
            docs_query = self.db.collection('documind_docs') \
                .where(filter=FieldFilter('landlord_id', '==', landlord_id)) \
                .where(filter=FieldFilter('property_id', '==', property_id))

            found_categories = set()
            for doc in docs_query.stream():
                data = doc.to_dict() or {}
                category = data.get('category')
                if category in ALLOWED_CATEGORIES:
                    found_categories.add(category)

            ordered = [
                category for category in ["lease", "warranty", "insurance", "utility", "receipt"]
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
            "warranty": ["warranty", "guarantee", "appliance warranty"],
            "insurance": ["insurance", "policy"],
            "utility": ["utility", "utilities", "bill", "bills"],
            "receipt": ["receipt", "invoice", "invoices"],
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

    async def ingest_document(
        self, 
        landlord_id: str, 
        property_id: str,
        category: str,
        file: UploadFile
    ) -> DocUploadResponse:
        """
        Ingest document into Firestore with vector embeddings.
        """
        doc_id = str(uuid.uuid4())
        
        # Step 1: Save file temporarily
        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, f"{doc_id}_{file.filename}")
        try:
            with open(temp_path, "wb") as f:
                content = await file.read()
                f.write(content)
            
            print(f"📄 Saved temp file: {temp_path}")
            
            # Step 2: Load PDF and extract text
            loader = PyPDFLoader(temp_path)
            pages = loader.load()
            
            # Step 3: Chunk text
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=1000,
                chunk_overlap=200,
            )
            chunks = text_splitter.split_documents(pages)
            
            print(f"📝 Split into {len(chunks)} chunks")
            
            # Step 4: Generate embeddings and prepare chunk documents
            chunk_documents = []
            for i, chunk in enumerate(chunks):
                try:
                    embedding = self.embeddings.embed_query(chunk.page_content)
                    
                    chunk_doc = {
                        'doc_id': doc_id,
                        'landlord_id': landlord_id,
                        'property_id': property_id,
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
                except Exception as e:
                    print(f"⚠️ Skipping chunk {i} due to error: {e}")
                    continue
            
            print(f"✅ Generated {len(chunk_documents)} embeddings")
            
            if len(chunk_documents) == 0:
                raise ValueError("No chunks could be processed from the document")
            
            # Step 5: Batch write chunks to Firestore
            batch = self.db.batch()
            for chunk_doc in chunk_documents:
                chunk_ref = self.db.collection('documind_chunks').document()
                batch.set(chunk_ref, chunk_doc)
            
            # Commit all chunks at once
            batch.commit()
            print(f"✅ Batch wrote {len(chunk_documents)} chunks to Firestore")
            
            # Step 6: Store document metadata
            file_size = os.path.getsize(temp_path)
            doc_ref = self.db.collection('documind_docs').document(doc_id)
            doc_ref.set({
                'landlord_id': landlord_id,
                'property_id': property_id,
                'category': category,
                'filename': file.filename,
                'chunks_indexed': len(chunk_documents),
                'file_size': file_size,
                'status': 'indexed',
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
            )
        
        except Exception as e:
            print(f"❌ Document ingestion failed: {e}")
            raise
        
        finally:
            # Step 7: Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                print(f"🗑️ Cleaned up temp file: {temp_path}")

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

        graph_state = await self._graph_orchestrator.run({
            "user_input": payload.question,
            "explicit_categories": explicit_valid,
            "available_categories": available_categories,
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

        if explicit_valid:
            selected_categories = explicit_valid[:10]
            category_filter_mode = "explicit"
        else:
            pending = self._conversation_store.get_pending_confirmation(session_id)
            user_action = (payload.user_action or "").strip().lower()

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
            elif user_action in ALLOWED_CATEGORIES:
                selected_categories = [user_action]
                working_question = pending.get("question", payload.question) if pending else payload.question
                category_filter_mode = "clarification_selected"
                self._conversation_store.clear_pending_confirmation(session_id)
            else:
                # Fallback to predicted categories when there is no checkpoint action
                selected_categories = [
                    category for category in predicted_categories if category in ALLOWED_CATEGORIES
                ]
                if selected_categories:
                    category_filter_mode = "auto"

        try:
            retrieved_chunks = await self._hybrid_retriever.retrieve(
                question=working_question,
                landlord_id=payload.landlord_id,
                property_id=payload.property_id,
                top_k=payload.top_k,
                categories=selected_categories or None,
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

        citations = []
        context_text = ""
        for i, chunk in enumerate(retrieved_chunks):
            citations.append(Citation(
                doc_id=chunk['doc_id'],
                filename=chunk['filename'],
                category=chunk['category'],
                page=chunk.get('page'),
                snippet=chunk['text'][:200],
                score=chunk.get('rerank_score', chunk.get('dense_score', 0.0)),
            ))
            context_text += f"\n\n[Document {i+1}: {chunk['filename']}, Page {chunk.get('page', 'N/A')}]\n{chunk['text']}"

        searched_categories_text = ", ".join(selected_categories) if selected_categories else "all categories"
        prompt = f"""You are DocuMind, an AI assistant specialized in property document management.

    **Your Purpose:**
    You help landlords understand their property documents across 6 categories:
    - Tenancy Agreements (lease terms, tenant details, rent schedules)
    - Warranties (appliance coverage, expiry dates, claim procedures)
    - Insurance Policies (coverage types, premiums, policy numbers)
    - Utility Bills (electricity, water, gas usage and costs)
    - Receipts & Invoices (maintenance costs, repairs, purchases)
    - Other Documents (general property records)

    **User Question:**
    {working_question}

    **Current Property:**
    {property_name}

    **Categories Searched:**
    {searched_categories_text}

    **Relevant Document Excerpts:**
    {context_text}

    **Instructions:**
    1. **IF** the question is about property documents (lease, warranty, insurance, utilities, receipts, other):
    - Answer based ONLY on the context above
    - Do NOT use inline or in-text citations inside sentences
    - Do not provide in-text citations, only provide citations at the end under a "Sources" section
    - In "Sources", list each source as: "- filename (page X)"
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
        property_id: Optional[str] = None
    ) -> DocListResponse:
        """
        List documents from Firestore metadata collection.
        
        Args:
            landlord_id: Filter by landlord
            property_id: Optional filter by specific property
            
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
            
            # Convert Firestore Timestamp to datetime
            uploaded_at = data.get('uploaded_at')
            if isinstance(uploaded_at, firestore.SERVER_TIMESTAMP.__class__):
                uploaded_at = datetime.now()
            elif hasattr(uploaded_at, 'to_pydantic'):
                uploaded_at = uploaded_at.to_pydantic()
            
            documents.append(DocumentInfo(
                doc_id=doc.id,
                landlord_id=data.get('landlord_id'),
                property_id=data.get('property_id'),
                category=data.get('category'),
                filename=data.get('filename'),
                uploaded_at=uploaded_at,
                chunks_indexed=data.get('chunks_indexed'),
                file_size=data.get('file_size'),
            ))
        
        print(f"✅ Listed {len(documents)} documents")
        
        return DocListResponse(
            documents=documents,
            total_count=len(documents),
            filtered_by_property=property_id
        )
        
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
        
        # Step 4: Delete document metadata
        doc_ref.delete()
        print(f"✅ Deleted document {doc_id}")
        
        return {
            "message": "Document deleted successfully",
            "doc_id": doc_id,
            "filename": doc_data.get('filename', 'Unknown'),
            "chunks_deleted": deleted_chunks_count,
        }

# Singleton instance
documind_service = DocuMindService()