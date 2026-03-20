# REX AI Backend Architecture

## Overview

REX AI is the intelligent assistant for Residex, consisting of two main features:
- **Lease Generator**: Automated lease agreement generation with compliance validation
- **DocuMind**: Document Q&A using RAG (Retrieval-Augmented Generation)

### DocuMind Update (March 2026)

DocuMind now uses a **LangGraph-orchestrated, multi-turn flow** with Firestore-backed conversation memory:

1. **Intent Gate**
  - Uses a conversational router node (`conversation_router`) instead of hardcoded greeting keywords.
  - Handles open-ended chat in a role-safe loop until document intent is detected.
  - Triggers RAG flow only when `rag_needed=true`.

2. **Category Predict + Confirm**
   - For valid document questions without explicit categories, predicts likely categories.
   - Returns a checkpoint response requiring user confirmation/override/cancel.

3. **Session Memory**
   - Stores turn history and pending confirmation state in `documind_sessions`.
   - Supports continuation using `session_id` and `user_action` in follow-up requests.

4. **Backward-Compatible API Evolution**
   - Existing DocuMind endpoints remain unchanged.
   - `AskRequest`/`AskResponse` now include optional fields for orchestration (`session_id`, `user_action_required`, `predicted_categories`, etc.).

### New/Updated Backend Components

- **New** `rag/graph_orchestrator.py`
  - LangGraph state machine for intent classification, prediction, confirmation checkpoints, and retrieval routing.

- **New** `rag/conversation_router.py`
  - LangChain-based conversational routing with `rag_needed` trigger and safe fallback.

- **New** `rag/category_predictor.py`
  - LangChain-based category prediction with reasoning and fallback.

- **New** `rag/conversation_store.py`
  - Firestore session persistence (`documind_sessions`) + pending confirmation state + turn logging.

- **Updated** `rag/documind_service.py`
  - Replaced in-memory pending clarification flow with orchestrated graph flow and Firestore memory.
  - Added checkpoint handling for `confirm`, `cancel`, and `override:<category>` user actions.

- **Updated** `models/documind_models.py`
  - Added optional session/action fields for multi-turn orchestration while preserving compatibility.

- **Updated** `requirements.txt`
  - Added `langgraph` dependency.

Criteria	Lease Generator
Immediate Value	✅ High - Creates leases from scratch	
Frequency of Use	✅ High - Every new tenant (multiple times/year)	
Time Saved	✅ 2-4 hours per lease	
Revenue Potential	✅ $5-15 per lease generated	
Market Demand	✅ Every landlord needs this	
Technical Complexity	⚠️ Medium (LangGraph workflow)	
Competitive Edge	✅ Few competitors do this well	
User Pain Point	✅ Critical - Legal fees expensive

## Tech Stack

### Core Framework
- **FastAPI**: Python web framework for building REST APIs
- **Pydantic**: Request/response validation and auto-generated API docs

### AI/ML Services
- **Vertex AI Gemini 1.5 Flash**: Lease generation, Q&A responses
- **Vertex AI Embeddings**: `textembedding-gecko@003` for document embeddings
- **LangChain**: RAG pipeline orchestration (document loading, chunking, retrieval)
- **LangGraph**: Stateful multi-step workflows with human-in-the-loop
- **FAISS**: Vector database for semantic document search

### Backend Services
- **Firebase Admin SDK**: Authentication and Firestore access
- **Firestore**: Lease state persistence, user data
- **Python Libraries**:
  - `PyPDFLoader`: PDF document parsing
  - `RecursiveCharacterTextSplitter`: Text chunking for RAG
  - `reportlab/weasyprint`: PDF generation

---

## Folder Structure

```
backend/
├── agents/         # AI decision makers (business logic)
│   └── lease_workflow.py    # LangGraph workflow definition
├── api/           # HTTP endpoints (REST API layer)
│   └── rex_routes.py        # Lease + DocuMind endpoints
├── models/        # Pydantic schemas (validation + docs)
│   ├── lease_models.py      # Lease request/response
│   └── documind_models.py   # DocuMind Q&A models
├── rag/           # RAG pipeline (DocuMind Q&A)
│   └── documind_service.py  # LangChain RAG pipeline
├── utils/         # Reusable helpers (auth, PDF, OCR)
│   ├── auth.py              # Firebase authentication
│   ├── pdf_helpers.py       # PDF generation
│   └── firestore_helpers.py # Firestore operations
├── vectorstores/  # FAISS indexes (property-scoped)
│   ├── landlord_{id}_property_{id}.faiss
│   └── ...
├── metadata/      # Document metadata (JSON files)
│   ├── landlord_{id}_property_{id}.json
│   └── ...
└── main.py        # FastAPI app entry point
```

### 📁 `agents/` - AI Decision Makers

**Purpose**: Contains AI business logic separated from HTTP layer

**Files**:
- `lease_workflow.py`: LangGraph workflow for multi-step lease generation with human-in-the-loop

**Why separate?**
- Business logic independent of API framework
- Easier to test AI logic in isolation
- Can be reused by CLI tools, background jobs, etc.
- Graph definition separate from API routing

**Responsibilities**:
- Define LangGraph state machine (nodes, edges, conditions)
- Construct prompts for Gemini at each workflow step
- Validate compliance rules (Malaysia RTA 2024)
- Handle state transitions (DRAFT → REVIEW → REVISION → FINALIZED)
- Manage interrupts for human review checkpoints

---

### 📁 `api/` - HTTP Endpoints

**Purpose**: REST API routes that connect frontend to backend services

**Files**:
- `rex_routes.py`: REX AI endpoints (8 routes: 4 for leases, 4 for DocuMind)

**Why separate?**
- Clean separation between HTTP and business logic
- API layer focuses on request/response handling
- Agents focus on AI logic

**Responsibilities**:
- Route requests to appropriate agents/services
- Handle HTTP-specific concerns (headers, status codes)
- Authentication middleware
- Error handling and response formatting

---

### 📁 `models/` - Pydantic Schemas

**Purpose**: Data validation and API documentation

**Files**:
- `lease_models.py`: Lease generation request/response schemas
- `documind_models.py`: DocuMind RAG request/response schemas

**Why separate?**
- Shared between api/ and agents/ layers
- Auto-generates OpenAPI documentation
- Type safety across the codebase
- Clear contracts between frontend and backend

**Benefits**:
- FastAPI validates incoming requests automatically
- Auto-complete in IDEs (type hints)
- API docs generated from these models

---

### 📁 `rag/` - RAG Pipeline

**Purpose**: Document retrieval and Q&A using LangChain

**Files**:
- `documind_service.py`: Complete RAG pipeline implementation

**Why separate?**
- Complex RAG logic deserves its own module
- Vector database management
- Document ingestion pipeline
- Retrieval logic with citations

**Responsibilities**:
- Ingest documents (PDF → chunks → embeddings → vector store)
- Query answering (retrieve relevant chunks → send to Gemini → return answer + citations)
- Manage FAISS vector database
- Track document metadata (landlord_id, property_id, doc_id)

---

### 📁 `utils/` - Helper Functions

**Purpose**: Reusable utilities across the backend

**Files**:
- `auth.py`: Firebase ID token verification
- `pdf_helpers.py`: PDF generation utilities (planned)
- `ocr_helpers.py`: OCR processing (planned)

**Why separate?**
- Avoid code duplication
- Single source of truth for common operations
- Easy to unit test

---

### 📁 `vectorstores/` - FAISS Vector Databases

**Purpose**: Store document embeddings for semantic search (property-scoped)

**Structure**:
- `{landlord_id}_{property_id}.faiss` - FAISS index file (binary)
- One vectorstore per property (privacy isolation, faster retrieval)

**Why property-scoped?**
- **Privacy**: Documents isolated by property (multi-tenancy)
- **Performance**: Smaller indexes = faster search
- **Accuracy**: Questions scoped to specific property context
- **UX**: Matches landlord's mental model

**Example**:
```
vectorstores/
├── landlord_123_property_1.faiss  # Verdi Eco-Dominium documents
├── landlord_123_property_2.faiss  # The Grand Subang documents
└── landlord_456_property_3.faiss  # Different landlord's property
```

---

### 📁 `metadata/` - Document Metadata (JSON)

**Purpose**: Track document information without querying vector database

**Structure**:
- `{landlord_id}_{property_id}.json` - Document list with metadata

**JSON Schema**:
```json
{
  "property_id": "property_1",
  "property_name": "Verdi Eco-Dominium",
  "documents": [
    {
      "doc_id": "uuid-1",
      "landlord_id": "landlord_123",
      "property_id": "property_1",
      "category": "warranty",
      "filename": "AC_Warranty_Daikin.pdf",
      "uploaded_at": "2026-02-27T10:00:00Z",
      "chunks_indexed": 42
    }
  ]
}
```

**Why separate from vectorstore?**
- **Fast listing**: No need to load FAISS index
- **Filtering**: Query by category, date, filename
- **Display**: Show documents in UI without embeddings
- **Lightweight**: JSON parsing faster than FAISS operations

---

# LEASE GENERATOR

Complete documentation for automated lease agreement generation with LangGraph multi-step workflow.

---

## Lease Generator - Data Flow

### Step 1: Information Collection (Flutter)
```
Landlord clicks "Generate Lease"
    ↓
Select Property (dropdown)
    ↓ Auto-retrieve from Firestore
Property data: address, rent, deposit, type
    ↓
Choose Tenant Input Method:
  Option A: Select Existing Tenant → Auto-fill data
  Option B: Manual Input → Landlord enters tenant details
    ↓
Validate required fields → Continue
```

**Step 2: Draft Generation**
```
Flutter App (POST /api/rex/lease/draft)
    ↓ {property_id, tenant_id OR tenant_data, lease_terms}
rex_routes.py
    ↓ Create lease_id, initialize LangGraph
lease_workflow.py [generate_draft node]
    ↓ Call Gemini with structured prompt
Gemini 1.5 Flash
    ↓ Return JSON {title, markdown, sections}
lease_workflow.py [check_compliance node]
    ↓ Validate required/banned clauses
    ↓ [PASS?]
lease_workflow.py [human_review node]
    ↓ ️INTERRUPT - Save state to Firestore
rex_routes.py
    ↓ Return {lease_id, status: "REVIEW", markdown, compliance_issues}
Flutter App (display draft with [Approve] [Revise] buttons)
```

**Step 3: Human Review (Landlord)**
```
Landlord reviews draft
    ↓
[Option A] Approve:
    Flutter App (POST /api/rex/lease/{id}/approve)
        ↓
    lease_workflow.py [finalize node]
        ↓ Generate PDF, save to Firebase Storage
        ↓ Update Firestore: status = "FINALIZED"
        ↓ Send email notifications
    Return {pdf_url, status: "FINALIZED"}

[Option B] Request Changes:
    Flutter App (POST /api/rex/lease/{id}/revise)
        ↓ {feedback: "Change termination to 60 days"}
    lease_workflow.py [revise_draft node]
        ↓ Call Gemini with original + feedback
        ↓ Loop back to check_compliance → human_review
    Return {lease_id, status: "DRAFT", markdown (revised)}
```

---

## Lease Generator - API Endpoints

### 1. Create Draft Lease
```
POST /api/rex/lease/draft
```

**Request Body** (`LeaseDraftRequest`):
- `landlord_id`: string (Firebase UID)
- `property_id`: string (auto-retrieved from Firestore)
- `tenant_id`: string | null (if existing tenant selected)
- `tenant_data`: TenantData | null (if manual input)
  - `full_name`: string
  - `ic_number`: string
  - `email`: string (optional)
  - `phone`: string (optional)
- `jurisdiction`: string (default: "Malaysia - Selangor")
- `lease_type`: "FIXED" | "PERIODIC"
- `start_date`: ISO timestamp
- `end_date`: ISO timestamp
- `optional_clauses`: string[] (optional)

**Response** (`LeaseDraftResponse`):
- `lease_id`: string
- `status`: "DRAFT" | "REVIEW"
- `markdown`: string (generated lease text)
- `compliance_issues`: string[] (if any)
- `missing_clauses`: string[]
- `risk_flags`: string[]
- `current_step`: "generate_draft" | "check_compliance" | "human_review"
- `created_at`: ISO timestamp

---

#### 2. Get Lease State
```
GET /api/rex/lease/{lease_id}
```

**Response** (`LeaseStateResponse`):
- `lease_id`: string
- `status`: "DRAFT" | "REVIEW" | "REVISION" | "FINALIZED"
- `markdown`: string (current lease text)
- `property_data`: PropertySnapshot
- `tenant_data`: TenantSnapshot
- `compliance_issues`: string[]
- `revision_count`: int
- `current_step`: string
- `created_at`: ISO timestamp
- `updated_at`: ISO timestamp
- `pdf_url`: string | null (only if FINALIZED)

---

#### 3. Approve Lease
```
POST /api/rex/lease/{lease_id}/approve
```

**Request Body**: None (or optional signature data)

**Response** (`LeaseApprovalResponse`):
- `lease_id`: string
- `status`: "FINALIZED"
- `pdf_url`: string
- `finalized_at`: ISO timestamp
- `message`: "Lease finalized successfully"

---

#### 4. Revise Lease
```
POST /api/rex/lease/{lease_id}/revise
```

**Request Body** (`LeaseRevisionRequest`):
- `feedback`: string (landlord's change request)
- `specific_changes`: dict (optional, structured changes)
  - Example: `{"termination_notice_days": 60, "pet_policy": "allowed"}`

**Response** (`LeaseRevisionResponse`):
- `lease_id`: string
- `status`: "DRAFT"
- `markdown`: string (revised lease text)
- `revision_count`: int
- `changes_applied`: string[]
- `current_step`: "human_review"

---

---

---

# DOCUMIND

Complete documentation for Document Q&A using property-scoped RAG (Retrieval-Augmented Generation).

---

## DocuMind - API Endpoints

### 1. Upload Document
```
POST /api/rex/documind/upload
```

**Request**: Multipart form data
- `file`: PDF file
- `landlord_id`: string
- `property_id`: string
- `category`: string (e.g., "lease", "warranty", "insurance", "utility", "receipt", "other")

**Response** (`DocUploadResponse`):
- `doc_id`: string
- `landlord_id`: string
- `property_id`: string
- `category`: string
- `filename`: string
- `status`: "indexed"
- `chunks_indexed`: int

---

### 2. Ask DocuMind Question
```
POST /api/rex/documind/ask
```

**Request Body** (`AskRequest`):
- `landlord_id`: string
- `property_id`: string (scopes search to specific property)
- `question`: string
- `top_k`: int (default: 4, max chunks to retrieve)

**Response** (`AskResponse`):
- `answer`: string (Gemini-synthesized answer)
- `confidence`: float (0.0 - 1.0)
- `property_name`: string (for display)
- `citations`: Citation[]
  - `doc_id`: string
  - `filename`: string (e.g., "AC_Warranty_Daikin.pdf")
  - `category`: string (e.g., "warranty")
  - `page`: int
  - `snippet`: string (first 200 chars of relevant chunk)
  - `score`: float (relevance score 0.0 - 1.0)

---

### 3. List Documents
```
GET /api/rex/documind/documents?landlordId={id}&propertyId={id}
```

**Query Parameters**:
- `landlordId`: string (required) - Filter documents by landlord
- `propertyId`: string (optional) - Filter documents by specific property

**Response** (`DocListResponse`):
```json
{
  "documents": [
    {
      "doc_id": "...",
      "landlord_id": "...",
      "property_id": "...",
      "category": "warranty",
      "filename": "AC_Warranty_Daikin.pdf",
      "uploaded_at": "2026-02-27T10:00:00Z",
      "chunks_indexed": 42
    }
  ],
  "total_count": 15,
  "filtered_by_property": "property_1"
}
```

---

## Lease Generator - Architecture Decisions

### ✅ LangGraph-First Approach
**Decision**: Use LangGraph from Day 1 for multi-step lease workflow with human-in-the-loop

**Why LangGraph?**

**Our Requirements (All Matched by LangGraph)**:
1. ✅ **Multi-step process** - Draft → Compliance → Review → Revise/Finalize
2. ✅ **Human-in-the-loop** - Landlord must review and approve before PDF generation
3. ✅ **Conditional logic** - Compliance failures auto-trigger revision, landlord rejection loops back
4. ✅ **Persistent state** - Landlord can review draft later (saved in Firestore)
5. ✅ **Iterative refinement** - Landlord provides feedback, Gemini revises, loops back to review
6. ✅ **Audit trail** - Track all revisions, approvals, compliance checks

**Our LangGraph Workflow**:
```
┌─────────────┐
│ Collect Info│
└──────┬──────┘
       ↓
┌──────────────────┐
│ Generate Draft   │ ← Gemini
└──────┬───────────┘
       ↓
┌──────────────────┐
│ Compliance Check │ ← Python validation
└──────┬───────────┘
       ↓
    [PASS?]
       ↓ YES
┌──────────────────┐
│ Human Review     │ ← WAIT for landlord input
└──────┬───────────┘
       ↓
   [APPROVE?]
       ↓ YES              ↓ NO (request changes)
┌──────────────┐    ┌──────────────┐
│ Finalize PDF │    │ Revise Draft │ ← Gemini + feedback
└──────────────┘    └──────┬───────┘
                           ↓
                    (loop back to Review)
```

**LangGraph Benefits**:
- **Stateful**: Tracks current step (DRAFT, REVIEW, REVISION, FINALIZED)
- **Checkpoints**: Landlord can review tomorrow, workflow resumes
- **Conditional edges**: Route based on compliance/approval results
- **Built-in persistence**: Saves intermediate states to DB
- **Interrupt/Resume**: Pause for human input, continue when ready

**Implementation Example**:
```python
from langgraph.graph import StateGraph

# Define workflow states
class LeaseState(TypedDict):
    lease_id: str
    status: str  # "DRAFT", "REVIEW", "REVISION", "FINALIZED"
    lease_data: dict
    compliance_issues: list
    landlord_feedback: str | None

# Build graph
workflow = StateGraph(LeaseState)
workflow.add_node("generate_draft", generate_draft_node)
workflow.add_node("check_compliance", compliance_check_node)
workflow.add_node("human_review", human_review_node)  # interrupts here
workflow.add_node("revise_draft", revise_draft_node)
workflow.add_node("finalize", finalize_node)

# Add conditional edges
workflow.add_conditional_edges(
    "check_compliance",
    lambda state: "pass" if not state["compliance_issues"] else "fail",
    {"pass": "human_review", "fail": "revise_draft"}
)

workflow.add_conditional_edges(
    "human_review",
    lambda state: "approve" if state["landlord_feedback"] == "APPROVE" else "revise",
    {"approve": "finalize", "revise": "revise_draft"}
)
```

---

## Lease Generator - Information Collection Strategy

### ✅ Hybrid Approach
**Decision**: Auto-retrieve property data + flexible tenant input (existing or manual)

**Property Selection**:
- ✅ Dropdown of landlord's properties (from Firestore)
- ✅ Auto-fill: address, type, rent, deposit, units
- ✅ Read-only in lease form (single source of truth)

**Tenant Selection (Two Paths)**:

**Path A: Existing Registered Tenant**
- Dropdown shows tenants with `status = 'registered'`
- Auto-fill: name, IC, email, phone from Firestore
- System sends email notification (non-blocking)
- Lease stores `tenant_id` (reference to users collection)

**Path B: Manual Tenant Input**
- Landlord enters: name (required), IC (required), email, phone
- Lease stores `tenant_data` (embedded in lease document)
- Optional: Invite tenant to register after lease finalization

**Benefits**:
- Handles both new and existing tenants
- No blocking permission flow (faster UX)
- Encourages tenant registration without requiring it
- Data accuracy for existing tenants

---

## Database Schema (Firestore)

### Collections Structure
```
├── users/
│   ├── landlords/{landlordId}
│   │   ├── email, name, phone, ic
│   │   └── (properties stored in separate collection)
│   └── tenants/{tenantId}
│       ├── email, name, phone, ic, address
│       ├── status: "registered" | "invited" | "pending"
│       └── created_at, updated_at
│
├── properties/{propertyId}
│   ├── landlordId
│   ├── name, address, type
│   ├── totalUnits, occupiedUnits
│   ├── monthlyRent, securityDeposit
│   ├── purchasePrice, currentValue
│   ├── currentTenants: [tenantId1, tenantId2]
│   └── created_at, updated_at
│
├── leases/{leaseId}  ← NEW COLLECTION
│   ├── landlordId
│   ├── propertyId
│   ├── tenantId (string | null)          # If existing tenant
│   ├── tenantData (map | null)           # If manual input
│   │   ├── full_name
│   │   ├── ic_number
│   │   ├── email
│   │   └── phone
│   ├── status: "DRAFT" | "REVIEW" | "REVISION" | "FINALIZED" | "SIGNED"
│   ├── markdown (string)                 # Current lease text
│   ├── jurisdiction (string)
│   ├── leaseType (string)
│   ├── startDate, endDate (timestamps)
│   ├── monthlyRent, securityDeposit (number)
│   ├── complianceIssues (array)
│   ├── missingClauses (array)
│   ├── riskFlags (array)
│   ├── revisionCount (number)
│   ├── currentStep (string)              # LangGraph checkpoint
│   ├── landlordFeedback (string | null)  # Latest revision request
│   ├── pdfUrl (string | null)            # Only after FINALIZED
│   ├── created_at (timestamp)
│   ├── updated_at (timestamp)
│   ├── finalized_at (timestamp | null)
│   └── metadata
│       ├── generatedBy: "AI"
│       ├── version: "1.0"
│       └── workflowId: string            # LangGraph thread ID
│
├── tenant_invitations/{invitationId}  ← OPTIONAL (Future)
│   ├── landlordId
│   ├── propertyId
│   ├── leaseId
│   ├── email, name
│   ├── status: "SENT" | "ACCEPTED" | "EXPIRED"
│   ├── sentAt, expiresAt (timestamps)
│   └── acceptedAt (timestamp | null)
│
└── documind_docs/{docId}
    ├── landlordId
    ├── propertyId (string)
    ├── category (string)                # "lease", "warranty", "insurance", etc.
    ├── filename
    ├── uploadedAt
    ├── chunksIndexed
    └── vectorStorePath
```

### Lease State Transitions
```
DRAFT → (compliance check) → REVIEW → (landlord action) → FINALIZED
                    ↓                        ↓
                REVISION                  REVISION
                    ↓                        ↓
                (loop back to REVIEW)   (loop back to REVIEW)
```

---

---

# DOCUMIND (CONTINUED)

Documentation for DocuMind AI system architecture, data flow, and RAG implementation.

---

## DocuMind - Data Flow

### Document Ingestion Flow

```
Flutter App
    ↓ (POST /api/rex/documind/upload + PDF file)
    ↓ {landlord_id, property_id, category, file}
rex_routes.py
    ↓ (save file, call documind_service)
documind_service.py
    ↓ (PyPDFLoader → extract text)
    ↓ (RecursiveCharacterTextSplitter → chunks)
    ↓ (VertexAIEmbeddings → vectors)
    ↓ (FAISS → save to vectorstores/{landlord_id}_{property_id}.faiss)
    ↓ (save metadata to metadata/{landlord_id}_{property_id}.json)
Firestore (save doc metadata: doc_id, landlord_id, property_id, category, filename)
    ↓
Flutter App (confirmation: "Document indexed successfully")
```

### Q&A Flow

```
Flutter App
    ↓ (POST /api/rex/documind/ask + question)
    ↓ {landlord_id, property_id, question}
rex_routes.py
    ↓ (validate request with AskRequest)
documind_service.py
    ↓ (load FAISS vectorstore for property: landlord_id_property_id.faiss)
    ↓ (retrieve top-k relevant chunks with category metadata)
    ↓ (send chunks + question to Gemini)
Gemini 1.5 Flash
    ↓ (synthesize answer from chunks)
documind_service.py
    ↓ (extract citations: doc_id, page, snippet, score)
rex_routes.py
    ↓ (return AskResponse with answer + citations)
Flutter App (display answer with reference links)
```

---

## DocuMind - Architecture Decisions

### ✅ LangChain for RAG Pipeline

**Why LangChain?**
- Built-in document loaders (PyPDFLoader, CSVLoader, etc.)
- Text splitting optimized for RAG (RecursiveCharacterTextSplitter)
- Vector store abstractions (FAISS, Pinecone, Firestore)
- Retrieval chains with citation support
- Active community and documentation

**Alternative Considered**: Build from scratch
- **Rejected**: Reinventing the wheel, LangChain handles 90% of boilerplate

### ✅ Property-Scoped RAG

**Why property-scoped instead of global search?**
- **Privacy**: Documents isolated by property (multi-tenancy)
- **Performance**: Smaller indexes = faster retrieval
- **Accuracy**: Questions scoped to specific property context
- **UX**: Matches landlord's mental model (organize by property)
- **Demo Clarity**: "Upload warranty → Ask about warranty" shows immediate value

---

## DocuMind - RAG Pipeline Details

### Chunking Strategy
- **Chunk size**: 1000 characters
- **Overlap**: 200 characters
- **Why?** Balances context preservation with retrieval precision

### Metadata Tracking
Each chunk stores:
```python
{
  "doc_id": "uuid",
  "landlord_id": "firebase_uid",
  "property_id": "property_uuid",
  "category": "warranty",  # Document category
  "filename": "AC_Warranty_Daikin.pdf",
  "chunk_index": 0,
  "page": 3
}
```

**Benefits**:
- Filter by landlord (multi-tenancy)
- Filter by property (property-specific Q&A)
- Filter by category (e.g., only search warranties)
- Provide accurate citations (page numbers, filename)

### Vector Database Choice
**MVP**: FAISS (local file storage)
- Fast setup, no external service
- Persists to disk (`vectorstores/{landlord_id}/{doc_id}/`)

**Production**: Firestore Vector Search (planned)
- Managed service, auto-scaling
- Integrated with existing Firestore

---

### Document Organization Model (Property-Scoped RAG)

**Architecture Choice**: Property-scoped RAG with category organization

**Conceptual Structure** (User's Mental Model):
```
landlord_123/
├── Verdi Eco-Dominium (property_1)/
│   ├── Leases/
│   │   └── Lease_Unit4-2_AliRahman.pdf
│   ├── Warranties/
│   │   └── AC_Warranty_Daikin.pdf
│   ├── Insurance/
│   │   └── Fire_Insurance_2026.pdf
│   └── Utilities/
│       └── TNB_Bill_Jan2026.pdf
├── The Grand Subang (property_2)/
│   ├── Leases/
│   ├── Warranties/
│   └── Insurance/
```

**Backend Storage Structure**:
```
backend/
├── vectorstores/                    # FAISS indexes
│   ├── landlord_123_property_1.faiss
│   ├── landlord_123_property_2.faiss
│   └── ...
└── metadata/                        # Document metadata (JSON)
    ├── landlord_123_property_1.json
    ├── landlord_123_property_2.json
    └── ...
```

**Metadata JSON Structure**:
```json
{
  "property_id": "property_1",
  "property_name": "Verdi Eco-Dominium",
  "documents": [
    {
      "doc_id": "uuid-1",
      "landlord_id": "landlord_123",
      "property_id": "property_1",
      "category": "warranty",
      "filename": "AC_Warranty_Daikin.pdf",
      "uploaded_at": "2026-02-27T10:00:00Z",
      "chunks_indexed": 42
    },
    {
      "doc_id": "uuid-2",
      "landlord_id": "landlord_123",
      "property_id": "property_1",
      "category": "insurance",
      "filename": "Fire_Insurance_2026.pdf",
      "uploaded_at": "2026-02-26T14:30:00Z",
      "chunks_indexed": 28
    }
  ]
}
```

**Route-to-Organization Mapping**:

| **User Action** | **Route** | **Storage** |
|----------------|-----------|-------------|
| Upload AC warranty for Verdi | `POST /documind/upload`<br>`landlord_id=123`<br>`property_id=property_1`<br>`category=warranty` | `vectorstores/landlord_123_property_1.faiss`<br>`metadata/landlord_123_property_1.json` |
| List all docs for Verdi | `GET /documind/documents?landlordId=123&propertyId=property_1` | Read `metadata/landlord_123_property_1.json` |
| Ask "When does AC warranty expire?" | `POST /documind/ask`<br>`landlord_id=123`<br>`property_id=property_1` | Load `vectorstores/landlord_123_property_1.faiss` → Retrieve → Gemini |

**Benefits of Property-Scoped RAG**:
- **Privacy**: Documents isolated by property (multi-tenancy)
- **Performance**: Smaller vector stores = faster retrieval
- **Accuracy**: Questions scoped to specific property context
- **UX**: Matches landlord's mental model (organize by property)
- **Demo Clarity**: "Upload warranty → Ask about warranty" shows immediate value

**Supported Document Categories**:
- `lease` - Tenancy agreements
- `warranty` - Appliance/equipment warranties
- `insurance` - Property insurance policies
- `utility` - Electricity, water, internet bills
- `receipt` - Purchase receipts, invoices
- `other` - Miscellaneous documents

---

## Complete Usage Flow Example

### Scenario: Landlord Manages Verdi Eco-Dominium Documents

This example demonstrates the complete workflow of uploading documents, listing them, and asking questions using the property-scoped RAG system.

#### Step 1: Upload Documents

**Action 1a: Upload AC Warranty**
```http
POST /api/rex/documind/upload
Content-Type: multipart/form-data

landlord_id: "landlord_123"
property_id: "property_1"
category: "warranty"
file: AC_Warranty_Daikin.pdf
```

**Response**:
```json
{
  "doc_id": "uuid-abc-123",
  "landlord_id": "landlord_123",
  "property_id": "property_1",
  "category": "warranty",
  "filename": "AC_Warranty_Daikin.pdf",
  "status": "indexed",
  "chunks_indexed": 42
}
```

**Backend Processing**:
1. Save PDF to `/tmp/uuid-abc-123_AC_Warranty_Daikin.pdf`
2. Extract text using PyPDFLoader
3. Split into 42 chunks (1000 chars each, 200 overlap)
4. Generate embeddings using Vertex AI
5. Save to `vectorstores/landlord_123_property_1.faiss`
6. Update `metadata/landlord_123_property_1.json`:
```json
{
  "property_id": "property_1",
  "property_name": "Verdi Eco-Dominium",
  "documents": [
    {
      "doc_id": "uuid-abc-123",
      "landlord_id": "landlord_123",
      "property_id": "property_1",
      "category": "warranty",
      "filename": "AC_Warranty_Daikin.pdf",
      "uploaded_at": "2026-02-27T10:00:00Z",
      "chunks_indexed": 42,
      "file_size": 245678
    }
  ]
}
```

---

**Action 1b: Upload Fire Insurance**
```http
POST /api/rex/documind/upload
Content-Type: multipart/form-data

landlord_id: "landlord_123"
property_id: "property_1"
category: "insurance"
file: Fire_Insurance_2026.pdf
```

**Response**:
```json
{
  "doc_id": "uuid-def-456",
  "landlord_id": "landlord_123",
  "property_id": "property_1",
  "category": "insurance",
  "filename": "Fire_Insurance_2026.pdf",
  "status": "indexed",
  "chunks_indexed": 28
}
```

**Backend Processing**:
1. Load existing FAISS vectorstore: `landlord_123_property_1.faiss`
2. Add 28 new chunks to existing index (now has 42 + 28 = 70 chunks)
3. Save updated vectorstore
4. Append to metadata JSON (now has 2 documents)

---

#### Step 2: List All Documents for Property

**Action 2: List Documents**
```http
GET /api/rex/documind/documents?landlordId=landlord_123&propertyId=property_1
```

**Response**:
```json
{
  "documents": [
    {
      "doc_id": "uuid-abc-123",
      "landlord_id": "landlord_123",
      "property_id": "property_1",
      "category": "warranty",
      "filename": "AC_Warranty_Daikin.pdf",
      "uploaded_at": "2026-02-27T10:00:00Z",
      "chunks_indexed": 42,
      "file_size": 245678
    },
    {
      "doc_id": "uuid-def-456",
      "landlord_id": "landlord_123",
      "property_id": "property_1",
      "category": "insurance",
      "filename": "Fire_Insurance_2026.pdf",
      "uploaded_at": "2026-02-27T11:30:00Z",
      "chunks_indexed": 28,
      "file_size": 189234
    }
  ],
  "total_count": 2,
  "filtered_by_property": "property_1"
}
```

**Backend Processing**:
1. Read `metadata/landlord_123_property_1.json`
2. Return all documents for property_1
3. No vectorstore loading required (fast listing!)

---

#### Step 3: Ask Questions

**Action 3a: Ask About AC Warranty**
```http
POST /api/rex/documind/ask
Content-Type: application/json

{
  "landlord_id": "landlord_123",
  "property_id": "property_1",
  "question": "When does the AC warranty expire?",
  "top_k": 4
}
```

**Backend Processing**:
1. Load FAISS vectorstore: `vectorstores/landlord_123_property_1.faiss`
2. Generate embedding for question
3. Retrieve top 4 most similar chunks:
   - Chunk 1: "...warranty period is valid until December 31, 2028..." (score: 0.95)
   - Chunk 2: "...Daikin air conditioning unit serial number AC-2024-5678..." (score: 0.85)
   - Chunk 3: "...coverage includes compressor and refrigerant leaks..." (score: 0.75)
   - Chunk 4: "...contact customer service at 1-800-DAIKIN..." (score: 0.65)
4. Send chunks + question to Gemini 1.5 Flash
5. Gemini synthesizes answer from context

**Response**:
```json
{
  "answer": "The AC warranty for the Daikin unit expires on December 31, 2028, as stated in the warranty document.",
  "confidence": 0.95,
  "property_name": "Verdi Eco-Dominium",
  "citations": [
    {
      "doc_id": "uuid-abc-123",
      "filename": "AC_Warranty_Daikin.pdf",
      "category": "warranty",
      "page": 2,
      "snippet": "...warranty period is valid until December 31, 2028. This coverage includes parts and labor for the Daikin air conditioning unit serial number AC-2024-5678...",
      "score": 0.95
    },
    {
      "doc_id": "uuid-abc-123",
      "filename": "AC_Warranty_Daikin.pdf",
      "category": "warranty",
      "page": 3,
      "snippet": "...coverage includes compressor and refrigerant leaks, electrical components, and thermostat calibration...",
      "score": 0.75
    }
  ]
}
```

---

**Action 3b: Ask About Insurance Coverage**
```http
POST /api/rex/documind/ask
Content-Type: application/json

{
  "landlord_id": "landlord_123",
  "property_id": "property_1",
  "question": "What is the fire insurance coverage amount?",
  "top_k": 4
}
```

**Response**:
```json
{
  "answer": "The fire insurance coverage for Verdi Eco-Dominium is RM 2,500,000, covering structural damage, contents, and liability claims.",
  "confidence": 0.95,
  "property_name": "Verdi Eco-Dominium",
  "citations": [
    {
      "doc_id": "uuid-def-456",
      "filename": "Fire_Insurance_2026.pdf",
      "category": "insurance",
      "page": 1,
      "snippet": "...total coverage amount of RM 2,500,000 effective from January 1, 2026 to December 31, 2026. This policy covers structural damage, contents replacement, and third-party liability claims...",
      "score": 0.95
    }
  ]
}
```

---

#### File System State After Complete Flow

**Vectorstores**:
```
vectorstores/
└── landlord_123_property_1.faiss  # 70 chunks (42 warranty + 28 insurance)
```

**Metadata**:
```
metadata/
└── landlord_123_property_1.json   # 2 documents (AC warranty + fire insurance)
```

**Firestore** (optional, for persistence):
```
documind_docs/
├── uuid-abc-123/
│   ├── doc_id: "uuid-abc-123"
│   ├── landlord_id: "landlord_123"
│   ├── property_id: "property_1"
│   ├── category: "warranty"
│   ├── filename: "AC_Warranty_Daikin.pdf"
│   └── chunks_indexed: 42
└── uuid-def-456/
    ├── doc_id: "uuid-def-456"
    ├── landlord_id: "landlord_123"
    ├── property_id: "property_1"
    ├── category: "insurance"
    ├── filename: "Fire_Insurance_2026.pdf"
    └── chunks_indexed: 28
```

---

### Key Observations

1. **Property Scoping**: All documents isolated to `property_1` vectorstore
2. **Category Organization**: Documents tagged with semantic categories (warranty, insurance)
3. **Fast Listing**: Metadata JSON enables quick document browsing without loading FAISS
4. **Accurate Retrieval**: Questions retrieve relevant chunks from correct documents
5. **Citation Support**: Gemini answers include source references (filename, page, snippet)
6. **Scalability**: Each property has its own vectorstore (privacy + performance)

---

## Lease Generator - Compliance Validation

### Required Clauses (Malaysia RTA 2024)
- Landlord/tenant identification
- Property description
- Rental amount and payment terms
- Security deposit terms
- Lease duration
- Termination conditions
- Maintenance responsibilities

### Banned Clauses
- Unreasonable penalty charges
- Waiver of tenant rights
- Discrimination clauses

### Post-Processing
1. Parse Gemini JSON output
2. Extract all clause headings
3. Match against `REQUIRED_CLAUSES` list
4. Check for `BANNED_CLAUSES` patterns
5. Generate `risk_flags` and `missing_clauses`

---

---

# IMPLEMENTATION ROADMAP

Backend and frontend implementation checklists organized by feature.

---

## Lease Generator - Implementation Checklist

### Backend (Week 1-2)
- [ ] Setup Vertex AI project and credentials
- [ ] Install dependencies: `langgraph`, `langchain-google-vertexai`
- [ ] Create `agents/lease_workflow.py`
  - [ ] Define `LeaseState` TypedDict
  - [ ] Implement `generate_draft` node (Gemini prompt)
  - [ ] Implement `check_compliance` node (validation logic)
  - [ ] Implement `human_review` node (interrupt point)
  - [ ] Implement `revise_draft` node (Gemini + feedback)
  - [ ] Implement `finalize` node (PDF generation + Firestore)
  - [ ] Define conditional edges (compliance pass/fail, approve/revise)
  - [ ] Setup checkpointer (Firestore-backed state persistence)
- [ ] Create `models/lease_models.py`
  - [ ] `LeaseDraftRequest`, `LeaseDraftResponse`
  - [ ] `LeaseStateResponse`, `LeaseRevisionRequest`
  - [ ] `TenantData`, `PropertySnapshot`
- [ ] Create `utils/pdf_helpers.py`
  - [ ] Markdown to PDF conversion (reportlab/weasyprint)
  - [ ] Upload to Firebase Storage
- [ ] Create `utils/firestore_helpers.py`
  - [ ] Save/load lease state
  - [ ] Query properties by landlordId
  - [ ] Query registered tenants
- [ ] Update `api/rex_routes.py`
  - [ ] `POST /api/rex/lease/draft`
  - [ ] `GET /api/rex/lease/{id}`
  - [ ] `POST /api/rex/lease/{id}/approve`
  - [ ] `POST /api/rex/lease/{id}/revise`
- [ ] Test LangGraph workflow locally

---

### Frontend (Week 3)
- [ ] Create domain entities
  - [ ] `lib/features/landlord/domain/entities/lease.dart`
  - [ ] Update `lib/features/landlord/domain/entities/tenant.dart`
- [ ] Create Freezed models
  - [ ] `lib/features/landlord/data/models/lease_models.dart`
  - [ ] Run `flutter pub run build_runner build`
- [ ] Create HTTP client
  - [ ] `lib/features/landlord/data/datasources/lease_remote_datasource.dart`
- [ ] Create Riverpod providers
  - [ ] `lib/features/landlord/presentation/providers/lease_providers.dart`
- [ ] Build UI screens
  - [ ] Step 1: Property selection (dropdown with auto-fill)
  - [ ] Step 2: Tenant selection (existing OR manual input)
  - [ ] Step 3: Lease terms (dates, optional clauses)
  - [ ] Step 4: Review screen (markdown preview, approve/revise)
  - [ ] Step 5: Finalized screen (PDF viewer, download)
- [ ] Add loading states, error handling
- [ ] Add form validation

---

---

## DocuMind - Implementation Checklist

### Backend (Week 2)
- [ ] Create `models/documind_models.py`
  - [ ] `DocUploadRequest` (landlord_id, property_id, category)
  - [ ] `DocUploadResponse` (doc_id, category, chunks_indexed, status)
  - [ ] `AskRequest` (landlord_id, property_id, question, top_k)
  - [ ] `Citation` (doc_id, filename, category, page, snippet, score)
  - [ ] `AskResponse` (answer, confidence, citations, property_name)
  - [ ] `DocumentInfo` (doc metadata for listing)
  - [ ] `DocListResponse` (documents list, total_count)
- [ ] Implement `rag/documind_service.py` with LangChain
  - [ ] `ingest_document()` - PDF → chunks → embeddings → FAISS
  - [ ] `ask_documind()` - load FAISS → retrieve → Gemini → answer + citations
  - [ ] `list_documents()` - read metadata files → filter by property
  - [ ] Setup metadata storage in JSON files (metadata/{landlord_id}_{property_id}.json)
  - [ ] Setup FAISS vectorstore paths (vectorstores/{landlord_id}_{property_id}.faiss)
- [ ] Update `api/rex_routes.py` with DocuMind endpoints
  - [ ] `POST /api/rex/documind/upload` (with category parameter)
  - [ ] `POST /api/rex/documind/ask`
  - [ ] `GET /api/rex/documind/documents`
- [ ] Test document upload + Q&A flow
  - [ ] Upload test PDF with category
  - [ ] Verify FAISS vectorstore created
  - [ ] Verify metadata JSON created
  - [ ] Test list_documents endpoint
  - [ ] Test Q&A with property scoping

### Frontend - Lease Generator UI (Week 3)
- [ ] Create domain entities
  - [ ] `lib/features/landlord/domain/entities/lease.dart`
  - [ ] Update `lib/features/landlord/domain/entities/tenant.dart`
- [ ] Create Freezed models
  - [ ] `lib/features/landlord/data/models/lease_models.dart`
  - [ ] Run `flutter pub run build_runner build`
- [ ] Create HTTP client
  - [ ] `lib/features/landlord/data/datasources/lease_remote_datasource.dart`
- [ ] Create Riverpod providers
  - [ ] `lib/features/landlord/presentation/providers/lease_providers.dart`
- [ ] Build UI screens
  - [ ] Step 1: Property selection (dropdown with auto-fill)
  - [ ] Step 2: Tenant selection (existing OR manual input)
  - [ ] Step 3: Lease terms (dates, optional clauses)
  - [ ] Step 4: Review screen (markdown preview, approve/revise)
  - [ ] Step 5: Finalized screen (PDF viewer, download)
- [ ] Add loading states, error handling
- [ ] Add form validation

---

---

## DocuMind - Implementation Checklist

### Frontend (Week 4)
- [ ] Create `lib/features/landlord/presentation/screens/3-REX/sub/documind_screen.dart`
- [ ] Build property selector dropdown (fetch from property_providers)
- [ ] Build category selector (lease, warranty, insurance, utility, receipt, other)
- [ ] Build document upload UI with file picker for PDFs
- [ ] Build chat interface for Q&A
  - [ ] Message list (user questions + Rex answers)
  - [ ] Question input field with send button
  - [ ] Loading states (thinking indicator)
- [ ] Display citations with references
  - [ ] Show document filename
  - [ ] Show category badge
  - [ ] Show page number
  - [ ] Show relevance score
- [ ] Add error handling (upload failed, Q&A timeout)
- [ ] Test E2E flow (select property → upload → ask → view answer)

---

---

# SHARED INFRASTRUCTURE

Infrastructure, deployment, testing, and future enhancements applicable to both systems.

---

## Infrastructure & Deployment (Week 4-5)
- [ ] Configure Vertex AI API access in GCP
- [ ] Setup Firebase Admin SDK service account
- [ ] Create Firestore collections (`leases`, `documind_docs`)
- [ ] Create Firestore indexes (landlordId + status, etc.)
- [ ] Deploy backend to Cloud Run
- [ ] Configure CORS for Flutter web
- [ ] Add rate limiting (Vertex AI quotas)
- [ ] Setup monitoring (Cloud Logging, error tracking)
- [ ] E2E testing with production data
- [ ] Performance testing (Gemini latency, workflow state persistence)

---

## Priority Order

1. **LangGraph Lease Workflow** (Week 1-2) - Core value proposition
2. **DocuMind RAG** (Week 2) - Complementary AI feature
3. **Flutter Lease UI** (Week 3) - User-facing workflow screens
4. **Flutter DocuMind UI** (Week 4) - Document Q&A interface
5. **Deployment & Testing** (Week 4-5) - Production readiness

---

## Next Steps

### Immediate (Today)
1. Setup Vertex AI credentials: `gcloud auth application-default login`
2. Install dependencies:
   ```bash
   pip install google-cloud-aiplatform \
               langgraph \
               langchain \
               langchain-google-vertexai \
               langchain-community \
               pydantic \
               fastapi \
               uvicorn \
               firebase-admin \
               reportlab
   ```
3. Create `backend/main.py` FastAPI app
4. Define Firestore schema (create `leases` collection)

### Week 1: LangGraph Workflow Foundation
1. Implement `agents/lease_workflow.py` state graph
2. Create `generate_draft` and `check_compliance` nodes
3. Setup Firestore checkpointer for state persistence
4. Test workflow execution with mock data

### Week 2: Complete Workflow + API
1. Implement `revise_draft` and `finalize` nodes
2. Add PDF generation in `finalize` node
3. Create all 4 API endpoints (draft, get, approve, revise)
4. Test full workflow: draft → review → revise → approve → PDF
5. Start DocuMind RAG implementation

### Week 3: Flutter UI
1. Build property selection + tenant input screens
2. Build lease review screen (markdown preview)
3. Implement approve/revise actions
4. Test E2E flow with backend

---

## Testing Strategy

### Unit Tests
- Test compliance validation logic (required/banned clauses)
- Test LangGraph state transitions (DRAFT → REVIEW → FINALIZED)
- Test conditional edges (compliance pass/fail routing)
- Test safe parsing helpers (Pydantic validation)
- Test chunking strategy (chunk size, overlap)

### Integration Tests
- Test Gemini API calls with mock responses
- Test Firestore checkpointer (save/load state)
- Test FAISS vector store operations
- Test authentication middleware (Firebase ID token)
- Test PDF generation and Firebase Storage upload

### E2E Tests
- Full lease workflow (draft → review → revise → approve → PDF)
- Test property auto-retrieval from Firestore
- Test existing tenant selection vs manual input
- Test LangGraph interrupt/resume (landlord reviews later)
- Full DocuMind flow (upload → ingest → query → response)
- Test with real property + tenant data

---

## Future Enhancements

### Phase 2 (Post-Initial Launch)
- [ ] Tenant permission flow (explicit consent for data usage)
- [ ] Email notifications (lease ready, tenant invitation)
- [ ] Digital signatures (landlord + tenant e-sign)
- [ ] OCR for scanned documents (Google Document AI)
- [ ] Multi-language support (Malay, Chinese)
- [ ] Lease template customization (industry-specific clauses)
- [ ] DocuMind conversation history
- [ ] Lease analytics dashboard (common clauses, avg rent, etc.)

### Phase 3 (Advanced)
- [ ] Multi-tenant approval (co-landlords, guarantors)
- [ ] Auto-renew lease suggestions (based on tenant history)
- [ ] Property market insights (RAG on market data)
- [ ] Tenant screening automation (credit check integration)
- [ ] Lease comparison tool (compare drafts side-by-side)
- [ ] Version control for lease revisions (git-like diff)
- [ ] Webhooks for lease state changes (integrate with property management systems)

---

## Notes

- All AI operations are **asynchronous** (FastAPI async endpoints)
- Authentication uses **Firebase ID tokens** (verify on every request)
- Vector stores are **scoped by landlord_id** (multi-tenancy isolation)
- Errors return **structured JSON** with error codes (not HTML)
- All costs tracked via **Vertex AI quotas** (monitor usage in GCP console)
