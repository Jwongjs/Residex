**PRODUCT REQUIREMENTS DOCUMENT**

**DocuMind RAG — Landlord Document Q&A System**

2026

| **Category**             | **Details**                                                            |
| ------------------------ | ---------------------------------------------------------------------- |
| **Document Type**        | Residex Landlord Scope — DocuMind RAG Module                           |
| **System Name**          | DocuMind - Landlord Property Document Q&A                              |
| **Architecture Pattern** | Agentic RAG: Intent → Retrieval → Synthesis (LangGraph)                |
| **Domain**               | Property Document Management (leases, warranties, insurance, utilities)|
| **Core Stack**           | Python · LangGraph · LangChain · FastAPI · Firestore Vector Search    |
| **Retrieval Strategy**   | Hybrid Dense+Sparse + Property/Category Scoping                        |
| **Evaluation**           | Golden Dataset · LLM-as-Judge                                          |

---

# **1. Executive Summary**

DocuMind is a landlord-focused RAG (Retrieval-Augmented Generation) system for property document management within Residex. It enables landlords to upload and query their property documents (leases, warranties, insurance policies, utility agreements, receipts) with AI-powered Q&A, category-aware retrieval, and citation-backed answers.

The system is built on LangGraph orchestration, Firestore Vector Search for property-scoped retrieval, and Gemini for synthesis. DocuMind is delivered as a FastAPI backend service integrated with the Residex Flutter app, supporting multi-turn conversations, category-aware filtering, and session-based confirmation workflows.

## **1.1 Core Capabilities**

| **Capability**                | **Implementation**                                                                                                                 |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Property-Scoped Retrieval**  | Vector search filtered by `landlord_id` and `property_id` — prevents cross-property document leakage                             |
| **Category-Aware Lookup**      | Six document categories (lease, warranty, insurance, utility, receipt, other) enable focused searches                           |
| **Intent Classification**      | LangGraph node classifies: conversation (greeting/meta) vs. RAG intent (document lookup) vs. confirmation (user action checkpoint) |
| **Multi-Turn Context**         | Session memory persists across turns; users can clarify categories or confirm document scope                                     |
| **Citations**                  | Every answer includes source document, page number, snippet, and retrieval score for auditability                               |
| **Confirmation Checkpoints**   | Ambiguous queries trigger user confirmation before synthesis (e.g. "Did you mean insurance documents?")                         |

---

# **2. System Architecture**

## **2.1 High-Level Workflow**

```
Landlord uploads property document (PDF)
         ↓
[1] Parse + Extract Text (PyPDFLoader)
         ↓
[2] Chunk Text (RecursiveCharacterTextSplitter, category-specific)
         ↓
[3] Generate Embeddings (Gemini embedding-001)
         ↓
[4] Persist to Firestore (documind_chunks collection)
         ↓
[5] User asks question via DocuMindScreen
         ↓
[6] Intent Router classifies: conversation? RAG? confirmation?
         ↓
[7] (If RAG) Category Predictor suggests relevant document categories
         ↓
[8] Firestore Vector Search: filter by landlord_id, property_id, optional categories
         ↓
[9] Synthesize answer with Gemini 2.5 Flash + inline citations
         ↓
[10] Return AskResponse with answer, confidence, citations, user_action_required
```

## **2.2 LangGraph State Schema**

The DocuMindState TypedDict carries context across the conversation:

| **Field**           | **Type**                      | **Purpose**                                                     |
| ------------------- | ----------------------------- | --------------------------------------------------------------- |
| **query**           | str                           | Current user question                                           |
| **session_id**      | str                           | Session identifier for multi-turn context                       |
| **landlord_id**     | str                           | Scopes retrieval to this landlord's documents                   |
| **property_id**     | str                           | Scopes retrieval to this property's documents                   |
| **intent**          | Literal[conversation, rag, confirm] | Classified by Intent Router                                     |
| **predicted_categories** | List[str]              | Predicted document categories by Category Predictor             |
| **user_action**     | Literal[confirm, cancel, override] | Optional user response (confirm retrieval, cancel, override category) |
| **retrieved_chunks** | List[Chunk]                   | Retrieved document chunks with embeddings and metadata          |
| **answer**          | str                           | Synthesized answer with inline citation markers                 |
| **citations**       | List[Citation]                | Rich citation objects linked to source chunks                   |
| **confidence**      | float                         | Confidence score (0–1) of the answer                            |
| **user_action_required** | bool                    | True if confirmation needed before synthesis                    |
| **pending_confirmation** | str                    | Prompt for user confirmation (stored in ConversationStore)     |

## **2.3 LangGraph Nodes**

### **Node 1 – Intent Router**

Classifies every incoming query into three categories:

- **conversation** — Pure greeting, farewell, meta-question ("Who are you?", "What can you do?"). Responds with template or single LLM call. Zero retrieval.
- **rag** — Factual question about property documents. Routes to Category Predictor.
- **confirmation** — User responds with `user_action=confirm/cancel/override`. Resumes pending confirmation checkpoint.

### **Node 2 – Category Predictor**

(Fires only on RAG intent)

Analyzes the query and suggests which document categories are most relevant:
- Lease: tenant rights, lease terms, renewal, eviction
- Warranty: appliance/structure warranty coverage
- Insurance: property/liability insurance terms
- Utility: utility agreements, meter reading, billing disputes
- Receipt: expense/maintenance receipt details
- Other: miscellaneous documents

Output: `predicted_categories: List[str]` with optional user confirmation.

### **Node 3 – Document Retriever**

Executes Firestore Vector Search:
1. Filter by `landlord_id`, `property_id`
2. Filter by `predicted_categories` (if user confirmed, or if unambiguous)
3. Query embedding via Gemini API
4. Cosine similarity search in Firestore
5. Return top-K chunks with scores

### **Node 4 – Answer Synthesizer**

Constructs prompt with:
1. System instruction for citation-grounded answering
2. Retrieved chunks as numbered context blocks
3. Instruction to reference inline: \[¹\], \[²\], etc.

Calls Gemini 2.5 Flash to generate answer with citations.

### **Node 5 – Confirmation Checkpoint**

If answer quality is low or categories were ambiguous:
- Set `user_action_required=true`
- Emit `action=ask_confirmation` with suggested categories or retry strategy
- Persist state in ConversationStore
- Return to caller; next request resumes with `user_action=confirm/cancel/override`

---

# **3. Document Ingestion Pipeline**

## **3.1 Upload Workflow**

```python
POST /api/rex/documind/upload
{
  "landlord_id": "landlord_123",
  "property_id": "prop_456",
  "category": "lease",  # or "warranty", "insurance", "utility", "receipt", "other"
  "file": <PDF binary>
}
```

Response:
```json
{
  "document_id": "doc_789",
  "filename": "Lease_Agreement_2026.pdf",
  "category": "lease",
  "chunks_created": 15,
  "indexed_at": "2026-01-15T10:30:00Z",
  "status": "indexed"
}
```

## **3.2 Processing Steps**

1. **Parse PDF** — PyPDFLoader extracts text + page numbers
2. **Chunk** — RecursiveCharacterTextSplitter, category-specific:
   - Lease/warranty/insurance: 800 tokens, 100 token overlap (preserve legal context)
   - Receipt: 200 tokens, 50 overlap (line items are atomic)
   - Utility: 400 tokens, 75 overlap (billing sections are modular)
3. **Embed** — Gemini `models/gemini-embedding-001` (768-dim vector)
4. **Persist** — Save to Firestore:
   - Collection: `documind_chunks`
   - Document: `{landlord_id}_{property_id}_{doc_id}_chunk_{i}`
   - Fields: `content`, `page`, `doc_id`, `landlord_id`, `property_id`, `category`, `embedding_vector`, `created_at`

---

# **4. Question-Answer Lifecycle**

## **4.1 API Contract**

```python
POST /api/rex/documind/ask
{
  "landlord_id": "landlord_123",
  "property_id": "prop_456",
  "question": "What is the lease renewal date?",
  "categories": [],  # optional: ["lease", "warranty"]
  "session_id": "session_789",
  "user_action": null  # optional: "confirm" | "cancel" | "override:warranty"
}
```

Response:
```json
{
  "answer": "The lease renewal date is March 31, 2027 [¹].",
  "confidence": 0.92,
  "citations": [
    {
      "citation_id": 1,
      "source_document": "Lease_Agreement_2026.pdf",
      "page": 3,
      "snippet": "Renewal date: March 31, 2027",
      "score": 0.96,
      "category": "lease"
    }
  ],
  "searched_categories": ["lease"],
  "user_action_required": false,
  "predicted_categories": ["lease"],
  "action": "respond"
}
```

On ambiguity, response can instead be:
```json
{
  "user_action_required": true,
  "action": "ask_confirmation",
  "pending_confirmation": "Your question could relate to multiple document categories. Which would you like me to search?\n• Lease (tenant agreements)\n• Insurance (property coverage)\n• Warranty (appliance coverage)",
  "predicted_categories": ["lease", "insurance", "warranty"]
}
```

## **4.2 Session Management**

Multi-turn conversations are persisted in ConversationStore (Firestore):

```python
class ConversationSession:
  session_id: str
  landlord_id: str
  property_id: str
  turns: List[Turn]  # {query, answer, citations, timestamp}
  pending_confirmation: Optional[str]
  pending_category_override: Optional[str]
  created_at: datetime
  updated_at: datetime
```

User can:
- Ask follow-up questions (session_id re-used for context)
- Cancel a pending confirmation (pending_confirmation cleared)
- Override category prediction (user_action="override:warranty" → search warranty docs instead)

---

# **5. Citation Model**

Each citation is traceable back to its source:

| **Field**         | **Type** | **Description**                                              |
| ----------------- | -------- | ------------------------------------------------------------ |
| **citation_id**   | int      | Inline marker index (\[¹\], \[²\])                          |
| **source_document** | str    | Filename (e.g. "Lease_Agreement_2026.pdf")                 |
| **category**      | str      | Document category (lease, warranty, insurance, etc.)        |
| **page**          | int      | Page number within the PDF                                  |
| **snippet**       | str      | 80–120 character excerpt supporting the claim              |
| **score**         | float    | Cosine similarity from Firestore Vector Search (0–1)       |

---

# **6. Property Management**

Landlords can manage documents per property:

```python
GET /api/rex/documind/documents?landlord_id=...&property_id=...
```

Response:
```json
{
  "property_id": "prop_456",
  "documents": [
    {
      "document_id": "doc_789",
      "filename": "Lease_Agreement_2026.pdf",
      "category": "lease",
      "chunks_count": 15,
      "uploaded_at": "2026-01-15T10:30:00Z",
      "file_size_bytes": 125000
    },
    { ... }
  ]
}
```

Delete a document:
```python
DELETE /api/rex/documind/documents/{document_id}
```

---

# **7. Technology Stack**

| **Layer**         | **Technology**              | **Justification**                                                  |
| ----------------- | --------------------------- | ------------------------------------------------------------------ |
| **Orchestration** | LangGraph                   | Stateful multi-turn with confirmation checkpoints                 |
| **Backend**       | FastAPI                     | REST API for upload and ask endpoints                              |
| **LLM**           | Gemini 2.5 Flash            | Fast synthesis, vision capability for receipt parsing              |
| **Embeddings**    | Gemini embedding-001        | Google-first stack consistency                                     |
| **Vector DB**     | Firestore (native vectors)  | No external dependency; property-scoped filtering built-in         |
| **Persistence**   | Firestore                   | Multi-turn session storage + document metadata                     |
| **Document Parse** | PyPDFLoader                | Extract text + page numbers from PDFs                              |
| **Chunking**      | RecursiveCharacterTextSplitter | Category-specific token targets                                   |

---

# **8. Frontend Integration (Flutter)**

DocuMindScreen in the Residex app provides:

1. **Document Management**
   - File picker to upload PDFs
   - List of indexed documents per property
   - Delete documents

2. **Chat Interface**
   - Text input + send button
   - Message thread (user Q / AI A)
   - Typing indicator while synthesizing
   - Citations panel below answer

3. **Category Filter**
   - Checkboxes: lease, warranty, insurance, utility, receipt, other
   - Optional user input to override AI category prediction

4. **Property Scoping**
   - Dropdown to select property
   - Queries automatically scoped to that property's documents

---

# **9. Success Metrics**

| **Metric**                   | **Target**     | **Measurement**                          |
| ---------------------------- | -------------- | ---------------------------------------- |
| **Citation Accuracy**        | >95%           | Manual audit of top-20 queries           |
| **Answer Relevance**         | >0.85 (RAGAS)  | LLM-as-judge on golden dataset           |
| **Latency (simple query)**   | <3s            | Streamlit/Flutter app wall-clock time    |
| **Category Prediction Accuracy** | >80%       | Automated check against ground truth     |
| **Session Persistence**      | 100%           | No conversation loss across turns        |
| **Document Retrieval Precision** | >0.90    | Top-K results contain answer info        |

---

# **10. Deployment & Operations**

## **10.1 Backend Deployment**

```bash
# Run locally (development)
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production: Deploy to Cloud Run with service account key for Firestore/Gemini access
gcloud run deploy documind-rag \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_APPLICATION_CREDENTIALS=/secrets/service-account-key.json
```

## **10.2 Environment Variables**

```
GOOGLE_APPLICATION_CREDENTIALS=<path to service account JSON>
GOOGLE_API_KEY=<Gemini API key>
FIRESTORE_PROJECT=<GCP project ID>
FIRESTORE_DATABASE=<Firestore database ID>
```

## **10.3 Monitoring**

- **LangGraph Observability**: Optional LangSmith integration for full node tracing
- **Error Logging**: FastAPI logger captures embedding failures, retrieval errors, synthesis issues
- **Performance**: Measure embedding latency, Firestore query latency, Gemini synthesis latency per request

---

# **11. Future Enhancements**

1. **Multi-Modal Documents** — Support images (e.g. warranty cards), receipt photos with OCR
2. **Document Summarization** — Auto-generate document summaries on upload
3. **Audit Trail** — Log all Q&A interactions per landlord for compliance
4. **Lease Clause Highlighter** — Flag potentially problematic lease terms (Malaysian Housing Act)
5. **Property Comparison** — Compare lease terms across multiple properties
6. **Batch Upload** — Landlords upload multiple documents at once with category tagging

---

*DocuMind — Part of Residex, the shared-living operating system for Malaysian landlords and tenants.*
*Landlord-only scope: Auth, Property Management, and DocuMind RAG.*
