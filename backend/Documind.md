# DocuMind — Complete Technical Documentation (Residex)

## 0) Residex Context: The Broader Picture

### What is Residex?

**Residex** is a comprehensive digital operating system for shared living in Malaysia. It's a mobile app (Flutter-based for iOS, Android, and web) that solves three core problems in the shared-living market:

1. **Opaque bill splitting** — Tenants spend hours calculating who owes whom after shared expenses.
2. **No portable tenant reputation** — There's no record of a tenant's payment history or conduct when moving between properties.
3. **Landlords juggling multiple tools** — Landlords manage documents, maintenance requests, finances, tenant relationships, and portfolios across disconnected systems.

### The Two User Roles

Residex serves **two distinct personas** with separate but integrated UIs:

- **Tenants**: Manage bills (split/pay), track roommate relationships, gamified "honor scores," maintenance requests, and personal financial dashboards.
- **Landlords**: Manage property portfolios, tenant relationships, document archives, AI-powered document Q&A (DocuMind), AI-powered lease generation, maintenance oversight, financial reporting, and community engagement.

### The Residex Ecosystem at a Glance

```
┌─────────────────────────────────────────────────────────────┐
│                    RESIDEX APP (Flutter)                    │
├─────────────────────────────────┬───────────────────────────┤
│   TENANT INTERFACE              │   LANDLORD INTERFACE      │
├─────────────────────────────────┼───────────────────────────┤
│ • Bill Dashboard & Splitter     │ • Property Portfolio      │
│ • Bill Payments                 │ • Finance Reporting       │
│ • Fiscal & Honor Scores         │ • Maintenance Tickets     │
│ • Maintenance Requests          │ • REX AI Hub              │
│ • Community & Gamification      │ • Community Management    │
│ • Chores & Schedules            │ • Tenant Insights         │
└─────────────────────────────────┴───────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │   BACKEND (Python FastAPI)            │
        │   ┌─────────────────────────────────┐ │
        │   │  DocuMind RAG Service           │ │ ← **YOU ARE HERE**
        │   │  - PDF ingestion & vectorization
        │   │  - Multi-turn Q&A orchestration │ │
        │   │  - Category-aware retrieval     │ │
        │   │  - Session memory              │ │
        │   └─────────────────────────────────┘ │
        │   ┌─────────────────────────────────┐ │
        │   │  Other Services                 │ │
        │   │  - Auth & User Management       │ │
        │   │  - Bill Calculations            │ │
        │   │  - Lease Generation             │ │
        │   │  - Maintenance AI               │ │
        │   └─────────────────────────────────┘ │
        └───────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │   DATA LAYER                          │
        │   - Firestore (sessions, metadata)    │
        │   - Firestore Vector Search (chunks)  │
        │   - Gemini Embeddings & LLM           │
        └───────────────────────────────────────┘
```

### Where Does DocuMind Fit?

**DocuMind is the landlord's AI-powered document intelligence layer.** Landlords in Malaysia deal with dense, multi-document workflows:

- **Tenancy agreements** with varying expiry dates and clauses across multiple properties.
- **Warranty documents** covering appliances, each with different claim procedures.
- **Insurance policies** with buried coverage clauses and deductible terms.
- **Utility contracts and bills** scattered across months and properties.
- **Maintenance receipts and invoices** that need to be aggregated for tax/financial reporting.

**Without DocuMind:** A landlord looking up "Does my lease allow pets?" or "Is the washing machine still under warranty?" has to manually hunt through PDFs using Ctrl+F, often at time-critical moments (tenancy disputes, maintenance emergencies).

**With DocuMind:** A landlord uploads their documents once (categorized), then queries them conversationally:
- *"What does the lease say about pet policies?"* → DocuMind retrieves the exact clause with citation.
- *"Is the washing machine covered?"* → DocuMind checks the warranty document and summarizes coverage.
- *"How much have I spent on repairs this year?"* → DocuMind aggregates receipts and provides a summary.

### DocuMind's Role in the REX Hub

DocuMind is housed in the **REX AI Hub** — the landlord's dedicated AI assistant module in Residex. REX extends beyond documents to include:

- **DocuMind**: Document Q&A with RAG retrieval (this system).
- **Lease Generator**: AI-assisted lease agreement creation.
- **Maintenance AI**: Intelligent maintenance ticket routing and prediction.
- **Revenue Analytics**: AI-driven financial insights and trend detection.

### Technical Position

DocuMind is the **backend RAG service** that processes:
1. **Landlord uploads** → PDF ingestion, chunking, embedding, and Firestore storage.
2. **Landlord questions** → Intent routing, category prediction, vector retrieval, and LLM synthesis.
3. **Multi-turn sessions** → Stateful conversation memory with checkpoint confirmations.

It integrates with the Flutter landlord UI through a **structured REST API** that handles document management (upload/list/delete) and conversational Q&A.

### Key Differentiator: Orchestration + Safety

Unlike generic document chatbots, DocuMind adds **orchestration layer** safeguards:
- When a question is ambiguous (e.g., spans multiple document categories), DocuMind asks the landlord to clarify before retrieving, avoiding wrong answers.
- Landlords can explicitly confirm category selections or override predictions.
- Session memory tracks conversation history so multi-turn workflows feel natural.

This is production-grade RAG, not a quick LLM wrapper.

---

## 1) Executive Summary

DocuMind is an AI-powered, landlord-facing document intelligence system for property operations. It supports:

- PDF ingestion and indexing by landlord/property/category
- Retrieval-augmented question answering (RAG)
- Multi-turn orchestration with explicit user checkpoints (`confirm`, `cancel`, `override:<category>`)
- Firestore-backed conversation memory for session continuity
- Structured API contract consumed by a Flutter landlord chat UI

DocuMind is implemented as an applied AI system (not just a single LLM call): it combines routing, prediction, retrieval, state management, and frontend UX behavior into a full product workflow.

---

## 1.5) Architectural Update — Q1 2026 (LangGraph + Firestore Sessions)

### Major Structural Changes

As of March 2026, DocuMind transitioned to a **LangGraph-orchestrated, multi-turn flow** with **Firestore-backed conversation memory**, replacing the previous in-memory state management.

#### Four-Stage Architecture

1. **Intent Gate**
   - Uses `conversation_router` (LangChain-based) instead of hardcoded keyword matching.
   - Handles open-ended conversational chat until document intent is detected.
   - Triggers RAG flow only when `rag_needed=true`.
   - Provides safe fallback for non-document queries without exposing document corpus.

2. **Category Prediction + Confirmation Checkpoint**
   - For valid document questions without explicit categories, `category_predictor` infers 1–2 likely categories.
   - Returns `user_action_required=true` with predicted options.
   - Requires explicit user confirmation, override, or cancellation before retrieval.
   - Prevents wrong-category mismatches from producing incorrect answers.

3. **Session Memory Layer**
   - `documind_sessions` collection in Firestore stores:
     - Conversation turn history (append-only log)
     - Pending confirmation state (checkpoint checkouts)
     - Session TTL + last activity tracking
   - Supports continuation using `session_id` and `user_action` in follow-up requests.
   - Isolated per landlord + property scope for data safety.

4. **LangGraph State Machine Orchestration**
   - `graph_orchestrator.py` defines unified routing and decision nodes.
   - Transitions: `route_conversation` → `respond_conversation` / `predict_categories` → `decide_action` → `prepare_confirmation/cancel/retrieve`.
   - Supports explicit checkpoints (`confirm`, `cancel`, `override:<category>`) as first-class state transitions.

#### Backward Compatibility

- Existing API endpoints remain unchanged (`POST /api/rex/documind/ask`, etc.).
- `AskRequest`/`AskResponse` models include optional orchestration fields:
  - `session_id` (optional request/response)
  - `user_action` (optional request: `confirm`, `cancel`, `override:<category>`)
  - `user_action_required` (optional response: signals checkpoint)
  - `predicted_categories`, `clarification_prompt`, `clarification_options` (response fields)
- Clients that don't use session management or multi-turn flows continue to work unchanged.

#### New Backend Components

| File | Purpose |
|------|---------|
| `rag/graph_orchestrator.py` | LangGraph state machine for intent classification, prediction, confirmation routing, and retrieval branching. |
| `rag/conversation_router.py` | LangChain-based conversational router that detects document intent vs. open chat; provides `rag_needed` signal. |
| `rag/category_predictor.py` | LangChain-based category inference from question + available categories; outputs structured prediction with confidence. |
| `rag/conversation_store.py` | Firestore session persistence layer: `get_or_create_session`, `append_turn`, `set_pending_confirmation`, etc. |
| `rag/documind_service.py` (updated) | Replaced in-memory confirmation flow with orchestrated graph flow; now calls `graph_orchestrator` for routing. |
| `models/documind_models.py` (updated) | Added optional fields for `AskRequest`/`AskResponse` to support session IDs, user actions, and predicted categories. |

#### Updated Dependencies

- `requirements.txt` now includes `langgraph` for state machine orchestration.

---

## 2) Product Purpose and Scope (DocuMind Specifics)

### Primary users
- Landlords managing documents for one or more properties.

### Core jobs-to-be-done
- Upload and organize property documents.
- Ask questions like lease terms, warranty coverage, insurance clauses, utility obligations, etc.
- Receive concise answers grounded in uploaded documents.
- Handle ambiguity safely via user confirmation before expensive retrieval when needed.

### Supported document categories
- `lease`
- `warranty`
- `insurance`
- `utility`
- `receipt`
- `other`

### Current architectural boundary
- Document store/retrieval is scoped by `landlord_id` + `property_id`, with optional category narrowing.
- Session memory is stored in Firestore collection `documind_sessions`.

---

## 3) Tech Stack (DocuMind)

## Backend
- **FastAPI**: HTTP API framework
- **Pydantic**: Request/response schema validation
- **LangChain**:
	- `PyPDFLoader` for PDF extraction
	- `RecursiveCharacterTextSplitter` for chunking
	- Gemini wrappers for embeddings and generation
- **LangGraph**: state machine orchestration for multi-turn doc QA behavior
- **Google Cloud Firestore**:
	- metadata storage
	- vector-capable chunk collection with `find_nearest`
	- session memory persistence
- **Gemini models**:
	- Embeddings model (`models/gemini-embedding-001`)
	- Chat model (`models/gemini-2.5-flash` in service init)

## Frontend
- **Flutter** + **Riverpod** for state management
- **DashChat** for chat UI
- Landlord module integration through repository/use case/provider layers

---

## 4) Source Structure (DocuMind-relevant)

### Backend
- `api/rex_routes.py`
	- HTTP routes for upload/ask/list/delete
- `models/documind_models.py`
	- API request/response models for DocuMind
- `rag/documind_service.py`
	- End-to-end ingestion and ask pipeline
- `rag/graph_orchestrator.py`
	- LangGraph decision orchestration
- `rag/conversation_router.py`
	- Intent gating (conversation vs document question)
- `rag/category_predictor.py`
	- Category inference for ambiguous doc questions
- `rag/conversation_store.py`
	- Session persistence + pending confirmations

### Frontend (landlord)
- `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`
	- API calls for upload/ask/list/delete
- `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`
	- Action providers and dependency wiring
- `residex_app/lib/features/landlord/presentation/screens/3-REX/sub/documind_screen.dart`
	- Chat UX + session/action flow
- `residex_app/lib/features/landlord/presentation/screens/3-REX/sub/documind_chat_logic.dart`
	- Action mapping and assistant text building

---

## 5) API Contract

## Upload
`POST /api/rex/documind/upload`

Form fields:
- `landlord_id` (required)
- `property_id` (required)
- `category` (required)
- `file` (required, PDF)

Response model: `DocUploadResponse`
- `doc_id`, `landlord_id`, `property_id`, `category`, `filename`, `status`, `chunks_indexed`

## Ask
`POST /api/rex/documind/ask`

Request model: `AskRequest`
- Required: `landlord_id`, `property_id`, `question`
- Optional:
	- `top_k` (1–10, default 4)
	- `categories` (explicit filtering)
	- `session_id` (session continuation)
	- `conversation_turn` (frontend turn index)
	- `user_action` (`confirm`, `cancel`, `override:<category>`, or category token)

Response model: `AskResponse`
- Core answer fields: `answer`, `confidence`, `citations`, `property_name`
- Retrieval metadata: `searched_categories`, `category_filter_mode`
- Orchestration/checkpoint metadata:
	- `needs_category_clarification`
	- `clarification_prompt`
	- `clarification_options`
	- `session_id`
	- `conversation_turn`
	- `user_action_required`
	- `predicted_categories`
	- `action_reason`

## List
`GET /api/rex/documind/documents?landlord_id=...&property_id=...`

Response model: `DocListResponse`
- `documents[]`, `total_count`, `filtered_by_property`

## Delete
`DELETE /api/rex/documind/documents/{doc_id}?landlord_id=...&property_id=...`

Returns deletion summary after ownership/scope validation and chunk cascade delete.

---

## 6) Data Model and Persistence

### `documind_docs` collection (metadata)
Typical fields:
- `landlord_id`
- `property_id`
- `category`
- `filename`
- `chunks_indexed`
- `file_size`
- `status`
- `uploaded_at`

### `documind_chunks` collection (retrieval corpus)
Typical fields:
- `doc_id`
- `landlord_id`
- `property_id`
- `category`
- `filename`
- `chunk_index`
- `text`
- `embedding` (Firestore Vector)
- `page`
- `created_at`

### `documind_sessions` collection (conversation state)
Typical fields:
- `session_id`
- `landlord_id`
- `property_id`
- `created_at`
- `last_activity`
- `ttl_seconds`
- `conversation_turns` (append-only list)
- `pending_confirmation` (nullable checkpoint object)

---

## 7) Ingestion Pipeline (Upload Path)

`DocuMindService.ingest_document(...)` executes:

1. Create `doc_id` and save upload to temp path.
2. Parse PDF pages using `PyPDFLoader`.
3. Split text using `RecursiveCharacterTextSplitter` (`chunk_size=1000`, `chunk_overlap=200`).
4. Generate embedding per chunk.
5. Write chunk docs in Firestore batch to `documind_chunks`.
6. Write metadata doc in `documind_docs`.
7. Return indexed summary.
8. Always cleanup temp file in `finally`.

Implementation details:
- Stores page number safely as integer fallback (`0` when absent).
- Skips failed chunks individually and continues processing.
- Fails request if zero chunks were processable.

---

## 8) Ask Pipeline (RAG + Orchestration)

`DocuMindService.ask_documind(payload)` orchestration-aware flow:

1. Resolve available categories for this landlord/property.
2. Resolve property name for user-facing context.
3. Create or load session via `ConversationStore`.
4. Compute `turn_number` from persisted session turns.
5. Run graph orchestrator with state:
	 - user input
	 - explicit categories
	 - available categories
	 - user action
	 - recent turns
	 - property name
6. Branch by graph action:
	 - `conversation` → no retrieval; respond and log turn
	 - `ask_confirmation` → set pending checkpoint, return action-required payload
	 - `cancel` → clear checkpoint and return cancellation message
	 - `retrieve` → continue to vector retrieval
7. Retrieval path:
	 - build `selected_categories` based on explicit filters, pending confirmation, or predictions
	 - embed query
	 - metadata filter query by landlord/property (+ category when selected)
	 - perform `find_nearest` vector search
	 - build citations and context
	 - synthesize answer with LLM prompt instructions
8. Append turn into session memory and return structured response.

---

## 9) Orchestration Graph (LangGraph)

`DocuMindGraphOrchestrator` defines state and nodes.

### State includes
- Inputs: `user_input`, `explicit_categories`, `available_categories`, `user_action`, `recent_turns`, `property_name`
- Routing outputs: `intent`, `rag_needed`, `intent_confidence`, `intent_reason`
- Prediction outputs: `predicted_categories`, `prediction_confidence`, `prediction_reason`
- Final action: `action`, `assistant_message`

### Nodes
- `route_conversation`
- `respond_conversation`
- `predict_categories`
- `decide_action`
- `prepare_confirmation`
- `prepare_cancel`
- `prepare_retrieve`

### Key behavior
- Checkpoint responses (`confirm`, `cancel`, `override:`) are force-routed into doc flow before generic conversation fallback.
- Ambiguous doc intent + available categories can trigger confirmation checkpoint.

---

## 10) Intent Router

`ConversationRouter.route(...)` responsibilities:

- Distinguish between `conversation` and `document_question`.
- Determine `rag_needed`.
- Provide safe conversational assistant reply when retrieval is not needed.
- Include property-aware context in both prompt and fallback replies.
- Parse a strict key-value output contract from LLM.
- On LLM failure, use keyword fallback for robust classification.

Design property:
- If classified as `document_question`, retrieval is forcibly enabled (`rag_needed=True`) to avoid accidental no-RAG outcomes.

---

## 11) Category Predictor

`CategoryPredictor.predict(...)`:

- Predicts up to 2 categories from available categories only.
- Parses structured LLM output format:
	- `categories=...;confidence=...;reason=...`
- Falls back to first available category if parse fails.
- Uses keyword-scored fallback when LLM invocation fails.

This module supports checkpoint UX where the user can confirm/override predicted categories.

---

## 12) Conversation Memory Layer

`ConversationStore` operations:

- `get_or_create_session(...)`
- `set_pending_confirmation(session_id, pending)`
- `get_pending_confirmation(session_id)`
- `clear_pending_confirmation(session_id)`
- `append_turn(session_id, turn_data)`
- `get_turn_count(session_id)`

Important implementation detail:
- Turn append uses a Python datetime timestamp field inside appended turn object to avoid Firestore sentinel serialization issues in nested array union payloads.

---

## 13) Retrieval and Prompting Behavior

### Retrieval
- Embeds query and retrieves nearest chunks under metadata constraints.
- Supports category filtering modes:
	- `explicit`
	- `auto`
	- `clarification_selected`
	- fallback `all`/`conversation`/`cancel` depending on branch

### Prompt shaping
- Prompt includes:
	- user question
	- current property context
	- searched category context
	- relevant document excerpts
- Prompt instructions currently enforce:
	- answer grounded in provided context
	- no in-text citations
	- citations grouped under bottom `Sources` section
	- concise but structured answers

---

## 14) Frontend Workflow (Landlord App)

### Upload/document management
- User picks property and category.
- Upload endpoint called with multipart form.
- Category views list documents by selected category and property.
- Delete action cascades through backend API.

### Chat/session behavior
- Maintains `session_id` and local `conversation_turn`.
- For each user message:
	- derives `user_action` only when awaiting checkpoint response
	- sends ask request with session/action fields
- Receives action-required responses and renders actionable guidance.

### Action mapping logic
`documind_chat_logic.dart` maps user text:
- contains `confirm` → `confirm`
- contains `cancel` → `cancel`
- contains category token → `override:<category>`

### Response formatting behavior
- appends category mode summary
- appends `Sources` list at bottom from citations

---

## 15) Testing Coverage

### Backend tests
- `tests/test_documind_service_flows.py`
	- tests ask-confirmation flow
	- tests cancel flow
	- tests confirm retrieval selection
	- tests override category behavior
- `tests/test_rex_routes_documind_ask_api.py`
	- ask endpoint success and validation behavior
- `tests/test_rex_routes_documind_docs_api.py`
	- upload/list/delete API route behavior

### Frontend tests
- `residex_app/test/features/landlord/documind_chat_logic_test.dart`
	- unit tests for action mapping + response text building
- `residex_app/test/features/landlord/documind_screen_checkpoint_action_test.dart`
	- widget tests ensuring confirm/override/cancel user_action forwarding

### Current caveat
- `backend/tests/test_documind_orchestration.py` is currently empty and should be repopulated for full graph-level confidence.

---

## 16) Security and Data Isolation Considerations

## Already present
- All retrieval queries are scoped by `landlord_id` and `property_id` metadata.
- Delete operation validates landlord ownership and property scope before cascading delete.

## Recommended hardening
- Enforce auth middleware and verify request IDs against token claims.
- Add per-tenant rate limits and input size limits.
- Add sensitive data masking in logs.
- Add explicit backend-side category validation for upload endpoint.

---

## 17) Performance Characteristics and Tradeoffs

### Strengths
- Metadata prefilter + vector search reduces irrelevant retrieval.
- Chunking strategy balances granularity and context window usage.
- Session memory supports coherent multi-turn workflows.

### Tradeoffs
- Chunk size/overlap is static and may not suit all document layouts.
- Confidence values are heuristic and not calibrated.
- No explicit retrieval quality metrics currently persisted (e.g., hit@k dashboards).

### Recommended metrics to add
- Retrieval hit rate by category
- User action checkpoint acceptance rate
- End-to-end latency (P50/P95)
- No-result rate
- Hallucination/factuality manual evaluation set

---

## 18) Known Gaps / Improvement Backlog

1. **Tenant-level metadata filtering**
	 - Add `tenant_id` / `tenant_name` metadata at upload and chunk levels.
	 - Enable targeted retrieval by tenant in addition to category/property.

2. **Observability**
	 - Structured telemetry for each ask flow stage.
	 - Correlation IDs for debug traces.

3. **Evaluation harness**
	 - Gold Q/A benchmark set per category.
	 - Automated regression checks for groundedness and citation quality.

4. **Prompt governance**
	 - Centralized prompt templates with versioning.
	 - A/B testing of answer formatting styles.

5. **Test completeness**
	 - Rebuild graph orchestration unit tests.
	 - Add integration test for full upload→ask path with mocked Firestore vector behavior.

---

## 19) Resume Readiness Assessment

## Is this good enough for AI engineering roles?
Yes — this is solidly resume-worthy for **Applied AI Engineer / LLM Engineer / AI Product Engineer** roles.

### Why it is strong
- Demonstrates full-stack AI product delivery, not just notebook experimentation.
- Uses an orchestrated decision graph with user checkpoints.
- Implements retrieval with metadata constraints and session memory.
- Integrates backend orchestration contract into a real frontend experience.
- Includes automated tests at API, flow, and UI-behavior levels.

### How to present honestly
- Frame as a production-style applied RAG system with orchestration and UX safeguards.
- Be explicit about current limits (calibration/evals/observability) and planned roadmap.

---

## 20) Suggested Resume Bullets

- Built a multi-turn, landlord-facing RAG assistant for property documents using FastAPI, LangChain, LangGraph, Gemini, and Firestore vector search.
- Designed intent-gated orchestration with checkpointed user actions (`confirm/cancel/override`) to control retrieval flow and reduce category ambiguity errors.
- Implemented Firestore-backed session memory and pending confirmation state to support stateful follow-up interactions across chat turns.
- Delivered end-to-end Flutter integration (Riverpod + DashChat) with structured API contracts, action mapping, and citation rendering.
- Added automated backend and frontend tests for critical DocuMind workflows (ask, upload/list/delete, and checkpoint behavior).

---

## 21) Interview Deep-Dive Talking Points

When discussing DocuMind in interviews:

1. **System design**
	 - Explain why orchestration graph is better than one-shot prompting for ambiguous user intents.

2. **Retrieval quality**
	 - Discuss metadata filtering before vector search and category checkpointing.

3. **User safety/UX**
	 - Show how confirm/cancel/override prevents wrong retrieval assumptions.

4. **Data architecture**
	 - Describe separation of metadata docs, vector chunks, and session state.

5. **Operational lessons**
	 - Mention Firestore timestamp/array union edge case and how resilient storage patterns were applied.

---

## 22) Sequence Walkthrough (Text)

### Upload sequence
1. Frontend selects property + category + file.
2. Backend parses PDF and chunks text.
3. Embeddings generated and written to `documind_chunks`.
4. Metadata written to `documind_docs`.
5. Frontend refreshes document list.

### Ask sequence (ambiguous query)
1. User asks question without explicit category.
2. Router identifies document intent.
3. Predictor suggests categories.
4. Backend returns `user_action_required=true` with options.
5. User replies `confirm` or `override:<category>`.
6. Backend performs filtered vector search and synthesizes grounded answer.
7. Frontend renders answer + bottom sources section.

---

## 23) Practical Next Steps (High ROI)

1. Add tenant metadata fields to upload + chunk schema.
2. Extend ask payload with optional tenant filter.
3. Apply tenant filter before vector retrieval.
4. Restore graph-level unit tests.
5. Add basic retrieval evaluation script with fixed benchmark prompts.

---

## 24) Justification 

This is one of the most important parts to explain clearly, because a RAG system is only as strong as the problem it solves. The use case is strong; it just needs to be framed precisely.

### Framing to Avoid

Do not present this as "a chatbot that answers questions about documents." That sounds like a glorified search bar.

The real value is removing a high-friction workflow that landlords repeatedly face under time pressure.

### Core Justification

A landlord managing even 2-3 properties accumulates many documents across categories:

- Tenancy agreements with different expiry dates and clauses
- Appliance warranties with different claim procedures
- Insurance policies with different limits and exclusions
- Utility bills across months
- Maintenance receipts and invoices

When something urgent happens at 11pm on a Sunday, the landlord does not want to open 6 PDFs and run Ctrl+F repeatedly. They want one grounded answer immediately.

### Concrete Interview Scenarios

- Tenancy disputes:
"My tenant says the agreement allows pets. Does it?"
The landlord needs the exact clause fast, not a 20-minute document hunt. DocuMind retrieves and cites the relevant section.

- Warranty claims:
"The washing machine broke. Is it still under warranty, and what is the claim procedure?"
Without DocuMind, the landlord manually checks expiry details and claim terms. With DocuMind, the answer is retrieved in one query.

- Insurance queries:
"Does my policy cover water damage from a burst pipe?"
Insurance documents are dense. The landlord should not need to read 40 pages for a yes/no with conditions.

- Financial tracking:
"How much have I spent on repairs for this property this year?"
Costs are spread across receipts and invoices. DocuMind helps summarize across the receipts category.

- Tenant onboarding:
"What is the notice period if I need to terminate early?"
New landlords often do not memorize all lease clauses across properties.

### Strong One-Liner

"The problem is not that landlords do not have their documents. The problem is that documents are not useful when you cannot query them under time pressure. A tenancy dispute or maintenance emergency does not wait for manual PDF search."

### If Interviewers Ask "Why not Ctrl+F or ChatGPT with one PDF?"

- Ctrl+F assumes you already know which document to open and what exact keyword to search.
- It breaks down across multiple documents and categories.
- Generic chat with a single uploaded PDF has no persistent portfolio context, no category-aware routing, and often no structured citation trace.

DocuMind maintains property-scoped context, routes queries to likely categories, and returns grounded answers with citations.

### Honest Limitation and Forward Path

One real friction point is that landlords currently need to upload and categorize documents first.

A strong roadmap statement is:
"The next evolution is automatic document classification on upload, so landlords can drop a file and let the system categorize it."


## 25) Final Assessment

DocuMind is a credible applied AI engineering project with meaningful architectural depth:

- It combines LLM routing, graph orchestration, RAG retrieval, persistent memory, and product UI integration.
- It demonstrates practical software engineering around AI behavior control.
- With minor improvements in eval and observability, it can be positioned as a strong flagship portfolio project for AI engineering applications.

