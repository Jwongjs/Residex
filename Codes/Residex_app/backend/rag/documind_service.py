import os
import uuid
import tempfile
from typing import List, Optional
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
from google.cloud.firestore_v1.vector import Vector
from google.cloud.firestore_v1.base_vector_query import DistanceMeasure

EMBED_DIM = 768 # Default to 768 if not set

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
        
        # Step 1: Generate embedding for question
        try:
            query_vector = self.embeddings.embed_query(payload.question)
        except Exception as e:
            print(f"❌ Query embedding failed: {e}")
            return AskResponse(
                answer="I encountered an error processing your question. Please try again.",
                confidence=0.0,
                citations=[],
                property_name="Unknown",
            )
        
        # Step 2: Vector search in Firestore
        chunks_ref = self.db.collection('documind_chunks')
        
        # Build base query with filters (property scoping)
        query = chunks_ref.where('landlord_id', '==', payload.landlord_id) \
                          .where('property_id', '==', payload.property_id)
        
        # Perform vector search (finds nearest neighbors)
        try:
            vector_query = query.find_nearest(
                vector_field='embedding',
                query_vector=Vector(query_vector),
                distance_measure=DistanceMeasure.COSINE,
                limit=payload.top_k,
            )
            
            # Execute query
            docs = vector_query.stream()
            retrieved_chunks = [doc.to_dict() for doc in docs]
            
            print(f"✅ Retrieved {len(retrieved_chunks)} chunks from Firestore")
        
        except Exception as e:
            print(f"❌ Vector search failed: {e}")
            return AskResponse(
                answer="I couldn't search your documents. Please check your Firestore vector index.",
                confidence=0.0,
                citations=[],
                property_name="Unknown",
            )
        
        if not retrieved_chunks:
            return AskResponse(
                answer="I couldn't find relevant information in your documents for this property.",
                confidence=0.0,
                citations=[],
                property_name="Unknown",
            )
        
        # Step 3: Build citations
        citations = []
        context_text = ""
        for i, chunk in enumerate(retrieved_chunks):
            citations.append(Citation(
                doc_id=chunk['doc_id'],
                filename=chunk['filename'],
                category=chunk['category'],
                page=chunk.get('page'),
                snippet=chunk['text'][:200],  # First 200 chars
                score=0.95 - (i * 0.1),  # Mock score (Firestore doesn't return distance)
            ))
            context_text += f"\n\n[Document {i+1}: {chunk['filename']}, Page {chunk.get('page', 'N/A')}]\n{chunk['text']}"
        
        # Step 4: Generate answer with Gemini
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
    {payload.question}

    **Relevant Document Excerpts:**
    {context_text}

    **Instructions:**
    1. **IF** the question is about property documents (lease, warranty, insurance, utilities, receipts, other):
    - Answer based ONLY on the context above
    - Cite the document name and page number (e.g., "According to Lease_Agreement.pdf, page 3...")
    - Format dates clearly (e.g., "15 March 2026")
    - Keep your answer concise (2-3 sentences max)

    2. **IF** the question is off-topic (weather, sports, general knowledge, personal advice):
    - Accomodate and Politely redirect to your purpose
        
    3. **IF** you cannot find the answer in the context:
    - Say: "I couldn't find that information in your uploaded documents. Upload a [category name] document to get answers about [specific topic]."
    - Suggest uploading relevant documents

    4. **DO NOT** make up information - only use what's provided in the context.

    **Your Answer:**"""

        try:
            response = self.llm.invoke(prompt)
            answer = response.content.strip()
            print(f"✅ Generated answer: {answer[:100]}...")
        except Exception as e:
            print(f"❌ Gemini answer generation failed: {e}")
            answer = "I encountered an error generating an answer. Please try again."
        
        # Step 5: Fetch property name from Firestore (optional)
        property_name = "Unknown Property"
        try:
            property_doc = self.db.collection('properties').document(payload.property_id).get()
            if property_doc.exists:
                property_data = property_doc.to_dict()
                property_name = property_data.get('name') if property_data else 'Unknown Property'
        except Exception as e:
            print(f"⚠️ Could not fetch property name: {e}")
        
        return AskResponse(
            answer=answer,
            confidence=0.95,  # Mock confidence
            citations=citations,
            property_name=property_name,
        )

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
        query = self.db.collection('documind_docs').where('landlord_id', '==', landlord_id)
        
        if property_id:
            query = query.where('property_id', '==', property_id)
        
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
        chunks_query = chunks_ref.where('doc_id', '==', doc_id)
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