# DocuMind LangGraph Orchestration — Comprehensive Overview

## Table of Contents
1. [Architecture Summary](#architecture-summary)
2. [State Schema — `DocuMindState`](#state-schema)
3. [Graph Topology](#graph-topology)
4. [Nodes — Detailed Breakdown](#nodes)
   - [route_conversation](#1-route_conversation)
   - [respond_conversation](#2-respond_conversation)
   - [predict_categories](#3-predict_categories)
   - [prepare_finance](#4-prepare_finance)
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

- Is this casual chat, a finance question, or a document question?
- For a document question: which document categories, and which unit, should the search target?

The graph never asks the user anything back and never retrieves. It runs entirely before RAG retrieval, and its output (`action` field) tells `AskOrchestrator.ask()` what to do next. On a multi-unit property the app's unit picker usually settles the unit before the question is asked (`payload.unit_id`).

**Technology stack:**
- LangGraph `StateGraph` for orchestration
- Google Gemini 2.5 Flash as the LLM (`ChatGoogleGenerativeAI`)
- Google Gemini Embedding 001 for vector embeddings (768-dim)
- Firestore for vector storage, session memory, and document metadata

---

## State Schema

**File:** [ask/graph_orchestrator.py](ask/graph_orchestrator.py#L8-L35)

`DocuMindState` is a `TypedDict` (all fields optional via `total=False`) that flows through every node. Each node reads from it and returns a merged copy with its additions.

| Field | Type | Set By | Purpose |
|-------|------|---------|---------|
| `user_input` | `str` | Caller | The user's raw question |
| `explicit_categories` | `List[str]` | Caller | Categories explicitly requested by the user |
| `available_categories` | `List[str]` | Caller | Categories that have uploaded docs for this property |
| `available_units` | `List[Dict]` | Caller | The property's units for unit routing; empty when the app's unit picker already pinned `unit_id` |
| `recent_turns` | `List[Dict]` | Caller | Last N conversation turns for context |
| `property_name` | `str` | Caller | Human-readable property name |
| `intent` | `str` | `route_conversation` | `"conversation"`, `"document_question"`, or `"finance_question"` |
| `rag_needed` | `bool` | `route_conversation` | Whether RAG retrieval is required |
| `intent_confidence` | `float` | `route_conversation` | LLM confidence score (0.0–1.0) |
| `intent_reason` | `str` | `route_conversation` | Human-readable reason for intent classification |
| `finance_year` | `int` | `route_conversation` | Year named in a finance question (None = current year) |
| `predicted_categories` | `List[str]` | `predict_categories` | Up to 2 predicted document categories |
| `prediction_confidence` | `float` | `predict_categories` | Confidence of category prediction |
| `prediction_reason` | `str` | `predict_categories` | Reason for category prediction |
| `routed_unit_id` | `str` | `predict_categories` | Unit the router picked (validated by the service before use) |
| `unknown_unit_mention` | `str` | `predict_categories` | A unit the question names that doesn't exist |
| `unit_routing_decided` | `bool` | `predict_categories` | False = router made no unit decision; the service falls back to label matching |
| `action` | `str` | the terminal node | `"conversation"`, `"finance"`, or `"retrieve"` |
| `assistant_message` | `str` | `route_conversation` | Chat reply, used only when `action="conversation"` |

---

## Graph Topology

```
                       ┌──────────────────────┐
                       │  route_conversation  │  (ENTRY POINT)
                       └──────────┬───────────┘
                                  │  _route_after_conversation()
           ┌──────────────────────┼──────────────────────┐
           │                      │                      │
  intent="conversation"   intent="finance_question"   rag_needed=true
                           (checked first)            (and the fallback)
           │                      │                      │
           ▼                      ▼                      ▼
┌──────────────────────┐ ┌─────────────────┐ ┌──────────────────────┐
│ respond_conversation │ │ prepare_finance │ │  predict_categories  │
│ action=conversation  │ │ action=finance  │ │   action=retrieve    │
└──────────┬───────────┘ └────────┬────────┘ └──────────┬───────────┘
           └──────────────────────┼──────────────────────┘
                                  ▼
                                 END
```

Every path is two nodes long: classify, then one terminal node that names the action.

---

## Nodes

### 1. `route_conversation`

**File:** [ask/graph_orchestrator.py:72–86](ask/graph_orchestrator.py#L72-L86)  
**Entry point of the graph.**

**Responsibility:** Classify the user's message as casual conversation, a finance question, or a document question.

**Logic:** Delegates to `ConversationRouter.route()` (one LLM call; the prompt lives in [ask/conversation_router.py](ask/conversation_router.py)) with:
- `user_input`: the current question
- `recent_turns`: recent turns, so short follow-ups keep their context
- `property_name`: for property-aware replies

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `intent` | `"conversation"`, `"document_question"`, or `"finance_question"` |
| `rag_needed` | `true` / `false` |
| `intent_confidence` | 0.0–1.0 |
| `intent_reason` | Short reason string |
| `assistant_message` | Pre-composed reply for conversation, else `""` |
| `finance_year` | Year named in a finance question, else `None` |

---

### 2. `respond_conversation`

**File:** [ask/graph_orchestrator.py:88–92](ask/graph_orchestrator.py#L88-L92)  
**Terminal node for casual chat.**

**Logic:** Writes `action = "conversation"`. The reply text is already in `assistant_message` from `route_conversation`.

**Exits to:** `END`

---

### 3. `predict_categories`

**File:** [ask/graph_orchestrator.py:94–124](ask/graph_orchestrator.py#L94-L124)  
**Terminal node for document questions.**

**Responsibility:** The search router. Decide which categories, and which unit, the retrieval should target.

**Logic:**

1. **Explicit categories shortcut:** if the caller passed `explicit_categories`, return them with `confidence=1.0` and make no LLM call.
2. **LLM routing (normal path):** `CategoryPredictor.predict()` makes one LLM call with the question, `available_categories`, `available_units`, and `recent_turns`, and returns up to 2 categories plus a unit decision.

**State mutations:**

| Field Written | Value |
|---------------|-------|
| `action` | `"retrieve"` |
| `predicted_categories` | Up to 2 category strings |
| `prediction_confidence` | 0.0–1.0 |
| `prediction_reason` | Reason string |
| `routed_unit_id` / `unknown_unit_mention` / `unit_routing_decided` | The router's unit decision |

**Exits to:** `END`

---

### 4. `prepare_finance`

**File:** [ask/graph_orchestrator.py:126–127](ask/graph_orchestrator.py#L126-L127)  
**Terminal node for finance questions.**

**Logic:** Writes `action = "finance"`. The service then skips retrieval: the finance engine computes the figures for `finance_year` and the LLM only narrates them.

**Exits to:** `END`

---

## Edges and Routing Logic

### Conditional: `route_conversation` → next node

**Router function:** `_route_after_conversation()`, [ask/graph_orchestrator.py:129–136](ask/graph_orchestrator.py#L129-L136)

```
intent == "finance_question" → "prepare_finance"
rag_needed == True           → "predict_categories"
intent == "conversation"     → "respond_conversation"
else (fallback)              → "predict_categories"
```

The fallback means an uncertain intent is treated as a document question (fail-safe toward retrieval).

### Fixed edges

| From | To |
|------|----|
| `respond_conversation` | `END` |
| `predict_categories` | `END` |
| `prepare_finance` | `END` |

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

Firestore-backed session memory. Persists conversation history across requests.

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
    "conversation_turns": [...]
}
```

**Key methods:**

| Method | Description |
|--------|-------------|
| `get_or_create_session()` | Returns existing session or creates new one. Checks in-memory cache first, then Firestore. |
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

AskOrchestrator: graph_action == "conversation"
  → Returns assistant_message directly, no retrieval
  → Appends turn to ConversationStore
```

---

### Flow B: Document Question

```
User: "What does my lease say about pets?"   (session scoped to "Whole property")

route_conversation
  └─ ConversationRouter → intent="document_question", rag_needed=True
     ↓ _route_after_conversation → "predict"
predict_categories
  └─ CategoryPredictor → predicted_categories=["lease"], confidence=0.9, no unit named
  └─ state: action = "retrieve"
     ↓
END

AskOrchestrator: graph_action == "retrieve"
  → confidence ≥ 0.45, so the search is scoped to lease documents
  → no unit pinned or named → searches the whole property
  → retrieve → answer synthesis → response with citations
```

If the landlord picked a unit in the app's unit picker, the request carries `unit_id`, the graph gets an empty unit list (no unit routing in the prompt), and retrieval is scoped to that unit plus property-wide documents.

---

### Flow C: Explicit Category

```
User question with payload.categories = ["lease"]

route_conversation → rag_needed=True
  ↓
predict_categories
  └─ explicit_categories=["lease"] → skips the LLM, confidence=1.0, action="retrieve"
     ↓
END

AskOrchestrator: graph_action == "retrieve"
  → category_filter_mode = "explicit"
  → Searches only lease documents
```

---

### Flow D: Finance Question

```
User: "How much rental profit did I make in 2025?"

route_conversation
  └─ ConversationRouter → intent="finance_question", year=2025
     ↓ _route_after_conversation → "finance"
prepare_finance
  └─ state: action = "finance"
     ↓
END

AskOrchestrator: graph_action == "finance"
  → Finance engine computes the 2025 summary (no retrieval)
  → LLM narrates the computed figures only
```

---

## Post-Graph Execution

**File:** [ask/ask_orchestrator.py](ask/ask_orchestrator.py#L71) (`AskOrchestrator.ask()`, called by `DocuMindService.ask_documind()`)

After the graph returns, `AskOrchestrator.ask()` interprets `graph_action` and runs the actual retrieval pipeline:

### Retrieval Pipeline (when `graph_action == "retrieve"`)

1. **Determine categories and unit**
   - Explicit categories → use them directly
   - Otherwise the predicted categories, but only when `prediction_confidence >= 0.45`; a weaker prediction searches every category
   - Unit: `payload.unit_id` (the app's unit picker) wins; otherwise the router's validated unit, then deterministic label matching. A unit that doesn't exist gets an honest "couldn't find" answer. An ambiguous or multi-unit reference searches the whole property, and the answer attributes each fact to its unit

2. **Embed the question**
   ```python
   query_vector = self.embeddings.embed_query(payload.question)
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
| `documind_sessions` | Conversation sessions | `session_id`, `landlord_id`, `property_id`, `conversation_turns`, `ttl_seconds` |
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

**Why doesn't the graph ask clarifying questions?**
It used to: a category-confirmation checkpoint, then a "which unit?" checkpoint. Both are gone. The app's unit picker settles the unit before the first question, and a weak category prediction widens the search to every category instead of stopping to ask. Every routing decision has a deterministic fallback, so the worst case is a broader search, never a question back to the user.

**Why does retrieval happen outside the graph?**
So the graph stays pure: nodes only classify and route, with no retrieval I/O. Each terminal node names the action, and `AskOrchestrator.ask()` carries it out.
