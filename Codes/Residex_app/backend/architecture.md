# REX AI Backend Architecture

## Overview

REX AI is the intelligent assistant for Residex, consisting of two main features:
- **Lease Generator**: Automated lease agreement generation with compliance validation
- **DocuMind**: Document Q&A using RAG (Retrieval-Augmented Generation)

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

## Data Flow

### Lease Generator Flow (LangGraph Multi-Step)

**Step 1: Information Collection (Flutter)**
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

### DocuMind RAG Flow

**Document Ingestion**:
```
Flutter App
    ↓ (POST /api/rex/documind/upload + PDF file)
rex_routes.py
    ↓ (save file, call documind_service)
documind_service.py
    ↓ (PyPDFLoader → extract text)
    ↓ (RecursiveCharacterTextSplitter → chunks)
    ↓ (VertexAIEmbeddings → vectors)
    ↓ (FAISS → save vectorstore)
Firestore (save metadata: doc_id, filename, chunks_indexed)
    ↓
Flutter App (confirmation: "Document indexed successfully")
```

**Q&A Flow**:
```
Flutter App
    ↓ (POST /api/rex/documind/ask + question)
rex_routes.py
    ↓ (validate request with AskRequest)
documind_service.py
    ↓ (load FAISS vectorstore)
    ↓ (retrieve top-k relevant chunks)
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

## API Endpoints

### Lease Generator Endpoints (LangGraph Workflow)

#### 1. Create Draft Lease
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

### DocuMind Endpoints

#### 5. Upload Document
```
POST /api/rex/documind/upload
```

**Request**: Multipart form data
- `file`: PDF file
- `landlord_id`: string
- `property_id`: string (optional)

**Response** (`DocUploadResponse`):
- `doc_id`: string
- `landlord_id`: string
- `property_id`: string | null
- `filename`: string
- `status`: "indexed"
- `chunks_indexed`: int

---

#### 6. Ask DocuMind Question
```
POST /api/rex/documind/ask
```

**Request Body** (`AskRequest`):
- `landlord_id`: string
- `question`: string
- `property_id`: string (optional, filters to specific property)
- `doc_ids`: string[] (optional, filters to specific documents)
- `top_k`: int (default: 4, max chunks to retrieve)

**Response** (`AskResponse`):
- `answer`: string
- `confidence`: float (0.0 - 1.0)
- `citations`: Citation[]
  - `doc_id`: string
  - `page`: int
  - `snippet`: string (first 200 chars)
  - `score`: float (relevance score)

---

#### 7. List Documents
```
GET /api/rex/documind/documents?landlordId={id}&propertyId={id}
```

**Response**:
```json
{
  "documents": [
    {
      "doc_id": "...",
      "filename": "Lease Agreement.pdf",
      "property_id": "...",
      "uploaded_at": "2026-02-27T10:00:00Z",
      "chunks_indexed": 42
    }
  ]
}
```

---

## Architecture Decisions

### ✅ LangGraph for Lease Generator (PRIMARY IMPLEMENTATION)
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

### ✅ LangChain for DocuMind RAG
**Why?**
- Built-in document loaders (PyPDFLoader, CSVLoader, etc.)
- Text splitting optimized for RAG (RecursiveCharacterTextSplitter)
- Vector store abstractions (FAISS, Pinecone, Firestore)
- Retrieval chains with citation support
- Active community and documentation

**Alternative Considered**: Build from scratch
- **Rejected**: Reinventing the wheel, LangChain handles 90% of boilerplate

---

### ✅ Hybrid Information Collection Strategy
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
    ├── propertyId (string | null)
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

## RAG Pipeline Details

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
  "filename": "Lease.pdf",
  "chunk_index": 0,
  "page": 3
}
```

**Benefits**:
- Filter by landlord (multi-tenancy)
- Filter by property (property-specific Q&A)
- Provide accurate citations (page numbers)

### Vector Database Choice
**MVP**: FAISS (local file storage)
- Fast setup, no external service
- Persists to disk (`vectorstores/{landlord_id}/{doc_id}/`)

**Production**: Firestore Vector Search (planned)
- Managed service, auto-scaling
- Integrated with existing Firestore

---

## Compliance Validation (Lease Generator)

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

## Implementation Checklist

### Backend - LangGraph Lease Workflow (Week 1-2)
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

### Backend - DocuMind RAG (Week 2)
- [ ] Implement `rag/documind_service.py` with LangChain
- [ ] Setup FAISS vector database
- [ ] Create `models/documind_models.py`
- [ ] Update `api/rex_routes.py` with DocuMind endpoints
- [ ] Test document upload + Q&A flow

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

### Frontend - DocuMind UI (Week 4)
- [ ] Build document upload UI
- [ ] Build chat interface for Q&A
- [ ] Add file picker for PDFs
- [ ] Display citations with page references

### Infrastructure & Deployment (Week 4-5)
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
