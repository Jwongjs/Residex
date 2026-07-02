# DocuMind LangGraph Orchestration — Comprehensive Overview

## Table of Contents
1. [Architecture Summary](#architecture-summary)
2. [State Schema — `DocuMindState`](#state-schema)
3. [Graph Topology](#graph-topology)
4. [Nodes — Detailed Breakdown](#nodes)
   - [route_conversation](#1-route_conversation)
   - [respond_conversation](#2-respond_conversation)
   - [predict_categories](#3-predict_categories)
   - [decide_action](#4-decide_action)
   - [prepare_confirmation](#5-prepare_confirmation)
   - [prepare_cancel](#6-prepare_cancel)
   - [prepare_retrieve](#7-prepare_retrieve)
5. [Edges and Routing Logic](#edges-and-routing-logic)
6. [Supporting Components](#supporting-components)
   - [ConversationRouter](#conversationrouter)
   - [CategoryPredictor](#categorypredictor)
   - [ConversationStore](#conversationstore)
7. [End-to-End Request Flows](#end-to-end-request-flows)
8. [Post-Graph Execution (DocuMindService)](#post-graph-execution)
9. [Firestore Collections](#firestore-collections)
10. [Component Dependency Map](#component-dependency-map)

---

## Architecture Summary

DocuMind is a Retrieval-Augmented Generation (RAG) system for property document Q&A. It uses **LangGraph** to orchestrate a stateful, multi-step decision pipeline before any vector search is performed. The graph decides:

- Is this a casual chat or a real document question?
- Which document categories are relevant?
- Should the system ask the user for confirmation first, or retrieve immediately?

The graph runs entirely before RAG retrieval. Its output (`action` field) tells `DocuMindService` what to do next.

**Technology stack:**
- LangGraph `StateGraph` for orchestration
- Google Gemini 2.5 Flash as the LLM (`ChatGoogleGenerativeAI`)
- Google Gemini Embedding 001 for vector embeddings (768-dim)
- Firestore for vector storage, session memory, and document metadata

---

## State Schema

**File:** [graph_orchestrator.py](graph_orchestrator.py) — lines 8–27

`DocuMindState` is a `TypedDict` (all fields optional via `total=False`) that flows through every node. Each node reads from it and returns a merged copy with its additions.

| Field | Type | Set By | Purpose |
|-------|------|---------|---------|
| `user_input` | `str` | Caller | The user's raw question |
| `explicit_categories` | `List[str]` | Caller | Categories explicitly requested by the user |
| `available_categories` | `List[str]` | Caller | Categories that have uploaded docs for this property |
| `user_action` | `str` | Caller | Checkpoint response: `"confirm"`, `"cancel"`, `"override:<cat>"` |
| `recent_turns` | `List[Dict]` | Caller | Last N conversation turns for context |
| `property_name` | `str` | Caller | Human-readable property name |
| `intent` | `str` | `route_conversation` | `"conversation"` or `"document_question"` |
| `rag_needed` | `bool` | `route_conversation` | Whether RAG retrieval is required |
| `intent_confidence` | `float` | `route_conversation` | LLM confidence score (0.0–1.0) |
| `intent_reason` | `str` | `route_conversation` | Human-readable reason for intent classification |
| `predicted_categories` | `List[str]` | `predict_categories` | Up to 2 predicted document categories |
| `prediction_confidence` | `float` | `predict_categories` | Confidence of category prediction |
| `prediction_reason` | `str` | `predict_categories` | Reason for category prediction |
| `action` | `str` | `decide_action` / `respond_conversation` | Final action: `"conversation"`, `"ask_confirmation"`, `"cancel"`, `"retrieve"` |
| `assistant_message` | `str` | Multiple nodes | Pre-composed user-facing text (used for non-retrieval responses) |

---

## Graph Topology

```
                    ┌─────────────────────┐
                    │   route_conversation │  (ENTRY POINT)
                    └──────────┬──────────┘
                               │
              ┌────────────────┴────────────────┐
              │ _route_after_conversation()       │
              │                                   │
       rag_needed=false                    rag_needed=true
       intent="conversation"               OR intent="document_question"
              │                                   │
              ▼                                   ▼
  ┌─────────────────────┐          ┌──────────────────────┐
  │  respond_conversation│          │   predict_categories  │
  └──────────┬──────────┘          └──────────┬───────────┘
             │                                │
             │                                │ (always)
             │                                ▼
             │                    ┌──────────────────────┐
             │                    │     decide_action     │
             │                    └──────────┬───────────┘
             │                               │
             │           ┌──────────────────┬┴──────────────────┐
             │           │ _route_after_     │                   │
             │           │  decision()       │                   │
             │           │                  │                    │
             │      action=                action=          action=
             │    ask_confirmation         cancel           retrieve
             │           │                  │                   │
             │           ▼                  ▼                   ▼
             │  ┌──────────────────┐ ┌──────────────┐ ┌────────────────┐
             │  │prepare_confirmation│ │prepare_cancel│ │prepare_retrieve│
             │  └────────┬─────────┘ └──────┬───────┘ └───────┬────────┘
             │           │                  │                  │
             └───────────┴──────────────────┴──────────────────┘
                                            │
                                           END
```

---

## Nodes

### 1. `route_conversation`

**File:** [graph_orchestrator.py:78–102](graph_orchestrator.py#L78-L102)  
**Entry point of the graph.**

**Responsibility:** Classify the user's intent — is this a document question requiring RAG, or casual conversation?

**LLM PROMPT:** """
You are DocuMind's conversation router.
Your main role: support property-document assistance while allowing natural conversation.

Input: {text}
{property_context}
{history_summary}

Determine whether retrieval should be triggered now.

Rules:
- If user asks about property documents, tenancy, rent terms, warranties, insurance, utilities, receipts, rules/clauses, obligations -> rag_needed=true and intent=document_question.
- If user is chatting, greeting, random social text, or not asking for document facts -> rag_needed=false and intent=conversation.
- If uncertain between conversation/document_question, prefer rag_needed=true.

Respond in this exact format:
intent=<conversation|document_question>;rag_needed=<true|false>;confidence=<0.0-1.0>;reason=<short reason>;assistant_reply=<short user-facing reply when rag_needed=false, else empty>
"""

**Logic:**

1. **Checkpoint bypass:** If `user_action` is `"confirm"`, `"cancel"`, or starts with `"override:"`, the node **skips the LLM entirely** and forces `intent="document_question"`, `rag_needed=True`. This handles the case where the user is responding to a prior confirmation prompt.

2. **LLM classification (normal path):** Delegates to `ConversationRouter.route()` with:
   - `user_input` — the current question
   - `recent_turns` — up to last 3 turns for context
   - `property_name` — for property-aware replies

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `intent` | `"conversation"` or `"document_question"` |
| `rag_needed` | `true` / `false` |
| `intent_confidence` | 0.0–1.0 |
| `intent_reason` | Short reason string |
| `assistant_message` | Pre-composed reply if `rag_needed=false`, else `""` |

---

### 2. `respond_conversation`

**File:** [graph_orchestrator.py:104–108](graph_orchestrator.py#L104-L108)  
**Terminal node for casual chat.**

**Responsibility:** Mark the action as `"conversation"` so downstream code skips RAG entirely.

**Logic:** Minimal — just writes `action = "conversation"` to state. The actual reply text was already placed in `assistant_message` by `route_conversation`.

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `action` | `"conversation"` |

**Exits to:** `END`

---

### 3. `predict_categories`

**File:** [graph_orchestrator.py:110–130](graph_orchestrator.py#L110-L130)

**Responsibility:** Determine which document category/categories are most relevant to the user's question.

**Logic:**

1. **Explicit categories shortcut:** If `explicit_categories` is already populated (user or caller specified them), the node skips LLM prediction entirely and returns those with `confidence=1.0`.

2. **LLM prediction (normal path):** Delegates to `CategoryPredictor.predict()` with:
   - `user_input` — the question
   - `available_categories` — only categories that have actual documents for this property

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `predicted_categories` | Up to 2 category strings |
| `prediction_confidence` | 0.0–1.0 |
| `prediction_reason` | Reason string |

**Always exits to:** `decide_action`

---

### 4. `decide_action`

**File:** [graph_orchestrator.py:132–153](graph_orchestrator.py#L132-L153)

**Responsibility:** The decision hub. Determines the final action for this turn based on what information is available and what the user requested.

**Decision priority (waterfall):**

| Priority | Condition | Action |
|----------|-----------|--------|
| 1 | `explicit_categories` is set | `"retrieve"` — user told us exactly what to search |
| 2 | `user_action == "cancel"` | `"cancel"` — user cancelled the pending confirmation |
| 3 | `user_action` starts with `"override:"` | `"retrieve"` — user picked a specific category |
| 4 | `user_action == "confirm"` | `"retrieve"` — user confirmed predicted categories |
| 5 | `predicted_categories` is set AND `available_categories` is set | `"ask_confirmation"` — ambiguous, ask user to confirm |
| 6 | Fallback | `"retrieve"` — proceed with whatever was predicted |

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `action` | `"retrieve"`, `"ask_confirmation"`, or `"cancel"` |

---

### 5. `prepare_confirmation`

**File:** [graph_orchestrator.py:155–167](graph_orchestrator.py#L155-L167)

**Responsibility:** Compose a user-facing message that asks the user to confirm the predicted document category before retrieval.

**Logic:** Reads `predicted_categories` and builds a natural language prompt like:
> "I am going to search your lease, warranty documents to answer this accurately. Can you confirm, cancel, or choose another category?"

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `assistant_message` | Confirmation prompt string |

**Exits to:** `END`

---

### 6. `prepare_cancel`

**File:** [graph_orchestrator.py:169–173](graph_orchestrator.py#L169-L173)

**Responsibility:** Compose a user-facing cancellation acknowledgement message.

**Logic:** Writes a fixed cancellation message to `assistant_message`.

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `assistant_message` | `"Understood. I cancelled that action. Ask me anytime about your property documents."` |

**Exits to:** `END`

---

### 7. `prepare_retrieve`

**File:** [graph_orchestrator.py:175–176](graph_orchestrator.py#L175-L176)

**Responsibility:** Pass-through node. Signals that retrieval should proceed.

**Logic:** Returns the state unchanged. Actual RAG retrieval happens **outside** the graph in `DocuMindService.ask_documind()`.

**Exits to:** `END`

---

## Edges and Routing Logic

### Conditional: `route_conversation` → next node

**Router function:** `_route_after_conversation()` — [graph_orchestrator.py:178–184](graph_orchestrator.py#L178-L184)

```
if rag_needed == True  → "predict_categories"
if intent == "conversation" → "respond_conversation"
else (fallback)  → "predict_categories"
```

The fallback to `predict` means uncertain intents get treated as document questions (fail-safe toward retrieval).

### Conditional: `decide_action` → next node

**Router function:** `_route_after_decision()` — [graph_orchestrator.py:186–192](graph_orchestrator.py#L186-L192)

```
action == "ask_confirmation"  → "prepare_confirmation"
action == "cancel"            → "prepare_cancel"
else                          → "prepare_retrieve"
```

### Fixed edges

| From | To |
|------|----|
| `predict_categories` | `decide_action` |
| `respond_conversation` | `END` |
| `prepare_confirmation` | `END` |
| `prepare_cancel` | `END` |
| `prepare_retrieve` | `END` |

---

## Supporting Components

### ConversationRouter

**File:** [conversation_router.py](conversation_router.py)  
**Used by:** `route_conversation` node

Classifies whether a user message requires RAG retrieval.

**LLM prompt structure:**
- Provides the user's input, last 3 conversation turns (compact format), and property context
- Asks the LLM to output a structured semicolon-separated string: `intent=...;rag_needed=...;confidence=...;reason=...;assistant_reply=...`

**Fallback (LLM error):** Keyword matching against a hardcoded list:
```python
["lease", "rent", "tenant", "warranty", "insurance", "utility", "receipt", "invoice", "property", "pets", "allowed", "clause", "agreement"]
```

**Rules enforced:**
- If `intent == "document_question"`, `rag_needed` is forced `True`
- If `rag_needed == True`, `assistant_reply` is cleared (the LLM answer is not used)
- Empty input always returns `intent="conversation"` with a default reply

**Return shape:**
```python
{
    "intent": "conversation" | "document_question",
    "rag_needed": bool,
    "confidence": float,
    "reason": str,
    "assistant_reply": str  # only populated when rag_needed=False
}
```

---

### CategoryPredictor

**File:** [category_predictor.py](category_predictor.py)  
**Used by:** `predict_categories` node

Predicts up to 2 document categories from `available_categories` that best match the user's question.

**LLM prompt structure:**
- Provides the question and the list of available categories
- Asks the LLM to output: `categories=...;confidence=...;reason=...`
- Only accepts categories that appear in `available_categories` (prevents hallucination)

**Fallback (LLM error):** Keyword scoring per category:
```python
{
    "lease":     ["lease", "tenant", "pets", "rent", "deposit"],
    "warranty":  ["warranty", "covered", "claim", "expiry"],
    "insurance": ["insurance", "policy", "premium", "liability"],
    "utility":   ["utility", "electric", "water", "gas", "bill"],
    "receipt":   ["receipt", "invoice", "payment", "repair", "maintenance"],
}
```
If no keywords match, defaults to the first available category.

**Hard constraints:**
- Maximum 2 predicted categories (sliced to `[:2]`)
- Only validates against categories in `ALLOWED_CATEGORIES = {"lease", "warranty", "insurance", "utility", "receipt"}`
- If no categories are available for the property at all, returns empty list immediately

---

### ConversationStore

**File:** [conversation_store.py](conversation_store.py)

Firestore-backed session memory. Persists conversation history and pending confirmation state across requests.

**Firestore collection:** `documind_sessions`

**Session document structure:**
```json
{
    "session_id": "uuid",
    "landlord_id": "...",
    "property_id": "...",
    "created_at": "ServerTimestamp",
    "last_activity": "ServerTimestamp",
    "ttl_seconds": 3600,
    "conversation_turns": [...],
    "pending_confirmation": null | { ... }
}
```

**Key methods:**

| Method | Description |
|--------|-------------|
| `get_or_create_session()` | Returns existing session or creates new one. Checks in-memory cache first, then Firestore. |
| `set_pending_confirmation()` | Saves the pending question + predicted categories for a confirmation checkpoint. |
| `get_pending_confirmation()` | Reads pending state (cache-first). |
| `clear_pending_confirmation()` | Nullifies pending state after confirm/cancel/override. |
| `append_turn()` | Appends a turn dict (with UTC timestamp) to `conversation_turns` via `ArrayUnion`. |
| `get_turn_count()` | Returns the number of turns in a session. |

**Caching:** An in-process `_cache: Dict[str, Dict]` avoids redundant Firestore reads within the same process lifetime.

---

## End-to-End Request Flows

### Flow A: Casual Conversation

```
User: "Hey, what can you do?"

route_conversation
  └─ ConversationRouter → intent="conversation", rag_needed=False
  └─ state: assistant_message = "Hey! If you have anything..."
     ↓ _route_after_conversation → "conversation"
respond_conversation
  └─ state: action = "conversation"
     ↓
END

DocuMindService: graph_action == "conversation"
  → Returns assistant_message directly, no retrieval
  → Appends turn to ConversationStore
```

---

### Flow B: Direct Document Question (Predicted Category, Confirmed)

```
User: "What does my lease say about pets?"

route_conversation
  └─ ConversationRouter → intent="document_question", rag_needed=True
     ↓ _route_after_conversation → "predict_categories"
predict_categories
  └─ CategoryPredictor → predicted_categories=["lease"], confidence=0.9
     ↓
decide_action
  └─ predicted set, available set, no user_action → action="ask_confirmation"
     ↓ _route_after_decision → "prepare_confirmation"
prepare_confirmation
  └─ assistant_message = "I am going to search your lease documents..."
     ↓
END

DocuMindService: graph_action == "ask_confirmation"
  → Returns clarification prompt to user
  → Saves pending_confirmation to ConversationStore
  → Sets user_action_required=True, clarification_options=["lease", ...]

--- Next request (user clicks "Confirm") ---

User: user_action="confirm"

route_conversation
  └─ user_action is "confirm" → bypass LLM, rag_needed=True
     ↓
predict_categories → decide_action
  └─ user_action="confirm" → action="retrieve"
     ↓
prepare_retrieve → pass-through
     ↓
END

DocuMindService: graph_action == "retrieve"
  → Reads pending_confirmation from ConversationStore
  → Uses pending question + predicted_categories
  → Embeds question → vector search → LLM synthesis → response
```

---

### Flow C: Explicit Category (No Confirmation Needed)

```
User question with payload.categories = ["lease"]

route_conversation → rag_needed=True
  ↓
predict_categories
  └─ explicit_categories=["lease"] set → skips LLM, confidence=1.0
     ↓
decide_action
  └─ explicit set → action="retrieve" immediately
     ↓
prepare_retrieve → END

DocuMindService: graph_action == "retrieve"
  → category_filter_mode = "explicit"
  → Searches only the "lease" collection
```

---

### Flow D: Cancel

```
User: user_action="cancel" (responding to a confirmation prompt)

route_conversation
  └─ user_action="cancel" → bypass LLM, rag_needed=True
     ↓
predict_categories → decide_action
  └─ user_action="cancel" → action="cancel"
     ↓
prepare_cancel
  └─ assistant_message = "Understood. I cancelled..."
     ↓
END

DocuMindService: graph_action == "cancel"
  → Clears pending_confirmation in ConversationStore
  → Returns cancel message, no retrieval
```

---

### Flow E: Override Category

```
User: user_action="override:insurance" (user picks different category)

route_conversation
  └─ user_action starts with "override:" → bypass LLM, rag_needed=True
     ↓
predict_categories → decide_action
  └─ user_action.startswith("override:") → action="retrieve"
     ↓
prepare_retrieve → END

DocuMindService: graph_action == "retrieve"
  → Parses "insurance" from override string
  → Clears pending_confirmation
  → Searches insurance docs with original pending question
```

---

## Post-Graph Execution

**File:** [documind_service.py:309–694](documind_service.py#L309-L694)

After the graph returns, `DocuMindService.ask_documind()` interprets `graph_action` and runs the actual retrieval pipeline:

### Retrieval Pipeline (when `graph_action == "retrieve"`)

1. **Determine working question and categories**
   - Explicit categories → use them directly
   - `user_action="confirm"` → read `pending_confirmation` from `ConversationStore`, use the original question and predicted categories
   - `user_action="override:<cat>"` → extract category from the override string
   - Fallback → use `predicted_categories` from graph state

2. **Embed the question**
   ```python
   query_vector = self.embeddings.embed_query(working_question)
   # Gemini Embedding 001, 768 dimensions
   ```

3. **Firestore vector search**
   ```python
   query.find_nearest(
       vector_field='embedding',
       query_vector=Vector(query_vector),
       distance_measure=DistanceMeasure.COSINE,
       limit=payload.top_k,
   )
   ```
   Filtered by `landlord_id`, `property_id`, and optionally `category`.

4. **Build context and citations**
   - Each retrieved chunk becomes a `Citation` object with: `doc_id`, `filename`, `category`, `page`, `snippet` (first 200 chars), `score` (0.95 decreasing by 0.1 per rank)

5. **LLM answer synthesis**
   - Sends the question + retrieved chunks to Gemini 2.5 Flash
   - System prompt instructs: answer from context only, format with Sources section, redirect off-topic questions

6. **Persist turn** to `ConversationStore`

7. **Return `AskResponse`** with answer, citations, session metadata, and action metadata

---

## Firestore Collections

| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `documind_chunks` | Vector-embedded text chunks | `doc_id`, `landlord_id`, `property_id`, `category`, `text`, `embedding` (Vector), `page`, `chunk_index` |
| `documind_docs` | Document metadata | `doc_id`, `landlord_id`, `property_id`, `category`, `filename`, `chunks_indexed`, `file_size`, `status` |
| `documind_sessions` | Conversation sessions | `session_id`, `landlord_id`, `property_id`, `conversation_turns`, `pending_confirmation`, `ttl_seconds` |
| `properties` | Property info (read-only) | `name` (used for property_name lookups) |

---

## Component Dependency Map

```
DocuMindService
├── DocuMindGraphOrchestrator       (graph_orchestrator.py)
│   ├── ConversationRouter          (conversation_router.py)
│   │   └── ChatGoogleGenerativeAI  (Gemini 2.5 Flash LLM)
│   └── CategoryPredictor           (category_predictor.py)
│       └── ChatGoogleGenerativeAI  (Gemini 2.5 Flash LLM)
├── ConversationStore               (conversation_store.py)
│   └── Firestore Client
├── GoogleGenerativeAIEmbeddings    (Gemini Embedding 001)
└── Firestore Client
    ├── documind_chunks             (vector search target)
    ├── documind_docs               (document metadata)
    ├── documind_sessions           (session memory)
    └── properties                  (property name lookup)
```

---

## Key Design Decisions

**Why LangGraph over a simple if/else?**  
The graph makes the decision pipeline explicit, testable, and easily extensible. Each node has a single responsibility and a clear contract (reads from state, writes to state). Adding a new branch (e.g., a "summarize" action) only requires a new node and edge, not touching existing logic.

**Why confirm before retrieving?**  
Vector search cost (embedding + Firestore query) is non-trivial, and searching the wrong category produces low-quality answers. The confirmation checkpoint ensures the user agrees on the search scope before retrieval runs.

**Why does `prepare_retrieve` do nothing?**  
It's a semantic placeholder. Its presence makes the graph readable — "retrieval will happen" is an explicit declared state, not just the absence of other actions. The actual retrieval is intentionally kept outside the graph so the graph stays pure (no I/O side effects in nodes).

**Why bypass the LLM for checkpoint actions?**  
`"confirm"`, `"cancel"`, and `"override:"` are structured signals from the UI, not natural language. Routing them through the LLM would waste tokens and risk misclassification on short, ambiguous strings.
