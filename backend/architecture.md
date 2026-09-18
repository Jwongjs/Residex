# Residex / DocuMind — Architecture

Last updated: 2026-07-14

Residex is a Flutter app (self-management back-office for small landlords) with
one AI feature — **DocuMind**, document Q&A over a landlord's property PDFs —
served by this Python FastAPI backend. Firestore is the single database (app
data **and** vector index), Firebase Storage holds the raw PDFs, and Gemini
powers embeddings, routing, and answer synthesis.

```
Flutter (residex_app)
  ├─ Properties / Units ──────────► Firestore (direct SDK)
  └─ DocuMind (chat + docs) ──────► FastAPI backend (this repo)
                                      ├─ LangGraph orchestration (Gemini 2.5 Flash)
                                      ├─ HybridRetriever ► Firestore vector search + reranker
                                      ├─ Answer synthesis (Gemini)
                                      └─ Firebase Storage (PDFs) / Firestore (docs, chunks)
```

## Components

| Layer | Technology | Entry points |
|---|---|---|
| Mobile app | Flutter + Riverpod, clean architecture | `residex_app/lib/features/landlord/` |
| API | FastAPI | `main.py`, `api/rex_routes.py` |
| Orchestration | LangGraph state machine | `rag/graph_orchestrator.py` |
| Routing LLM | Gemini `models/gemini-2.5-flash` | `rag/conversation_router.py`, `rag/category_predictor.py` |
| Retrieval | Firestore `find_nearest` + cross-encoder rerank | `rag/retriever.py` |
| Service core | Ingest, ask, list, delete, unassign | `rag/documind_service.py` |
| Session state | In-memory conversation store | `rag/conversation_store.py` |

## Data model — two-axis documents

Every document is classified on two independent axes: **category** and **unit
scope**.

- `properties/{id}` — property record (`name`, type, address).
- `properties/{id}/units/{unitId}` — `label` (e.g. "Unit A-12-03"),
  `monthlyRent`, `isOccupied`. Rent and occupancy live **only** on units; a
  single-dwelling home is represented as one unit for the whole property, and
  a property with zero units is excluded from portfolio occupancy stats.
- `documind_docs` — one record per uploaded PDF: `doc_id`, `landlord_id`,
  `property_id`, `category` (`lease | warranty | insurance | utility |
  receipt`), `filename`, `chunk_count`, `storage_path`, and optional
  `unit_id` / `unit_label` (**null = property-wide**).
- `documind_chunks` — the RAG index. ~1000-char chunks (200 overlap) with a
  768-dim `Vector` field (`models/gemini-embedding-001`) plus denormalized doc
  metadata (`doc_id`, `category`, `unit_id`, `unit_label`, `filename`, `page`)
  so retrieval needs no joins.
- Raw PDFs: bucket `residex-2ebd8.firebasestorage.app` (override with
  `FIREBASE_STORAGE_BUCKET`; the default is derived as
  `{GOOGLE_CLOUD_PROJECT}.firebasestorage.app`), path
  `documind/{landlord_id}/{property_id}/{doc_id}.pdf`.

**Scoping rule everywhere:** a unit filter returns *that unit's documents plus
property-wide documents*. Unit filtering is a Python post-filter (docs uploaded
before units existed have no `unit_id` field, which a Firestore where-clause
can never match as null).

## Ingest pipeline (`ingest_document`)

PDF-only (enforced in the app picker and by PyPDFLoader here):

1. `PyPDFLoader` extracts pages → `RecursiveCharacterTextSplitter`
   (chunk 1000 / overlap 200).
2. Chunks embedded with `gemini-embedding-001` and batch-written to
   `documind_chunks` (each with `unit_id`/`unit_label` when assigned).
3. Raw PDF uploaded to Firebase Storage.
4. `documind_docs` metadata written last — so a mid-ingest failure leaves
   orphan chunks rather than a phantom document
   (`scripts/cleanup_orphan_chunks.py` purges those).

## Ask pipeline (`ask_documind`)

The design principle: **route silently, never stop to ask**. The LLM decides
the search parameters (tool-call style); every LLM decision has a
deterministic fallback, so an LLM failure degrades to a broader search: never
a dead end and never a question back to the user.

Per question:

1. **Unit fetch** — `properties/{id}/units` is read once and passed into the
   graph as `available_units`.
2. **`route_conversation` node** — LLM classifies chit-chat vs finance
   question vs document question.
3. **`predict_categories` node — the unified search router.** One Gemini call
   receives the question, available categories, the unit list, **and the last
   few conversation turns** (so a follow-up like "and when does it end?"
   keeps the previous turn's unit), and returns: up to 2 categories (empty =
   search all), the target `unit` (a unit id, or `all`), and `unknown_unit`
   when the question names a unit that does not exist. The service validates
   the output — only a real unit id may scope a search; `unit_decided=False`
   (failure, hallucinated id, unparseable output) hands unit routing to the
   deterministic matcher.
4. **Graph exit** — `predict_categories` ends the graph with
   `action=retrieve`. There is no confirmation step.
5. **Service-side unit routing** (in priority order):
   - An explicit `unit_id` in the API payload wins outright. The app's unit
     picker sends it when the landlord scopes the session to one unit, and
     omits it for "Whole property".
   - Else the **LLM's validated decision** applies: scoped, all, or the honest
     "I couldn't find Unit D — this property's units are: …" answer.
   - Else the **deterministic matcher** `resolve_unit_mention` label-matches
     the question ("unit a" → "Unit A-12-03" only at a segment boundary):
     scoped / aggregate ("all units", "per unit", …) / unknown / ambiguous.
   - **No checkpoint:** a reference that matches *several* units (e.g.
     "unit A" with "Unit A-1" and "Unit A-2") searches the whole property,
     like "all units"; the answer attributes every fact to its unit. The
     landlord already chose the scope in the unit picker.
6. **Category scope** — the router's categories apply when its confidence is
   ≥ 0.45; otherwise the whole corpus is searched. Explicit categories in
   the payload always win.
7. **Retrieval** — `HybridRetriever`: Firestore `find_nearest` dense search
   filtered by landlord/property/category, unit post-filter, then
   cross-encoder rerank (sentence-transformers).
8. **Answer synthesis** — Gemini, with excerpts headed
   `[filename, page — unit label | Property-wide]`. Prompt rule 5 forbids
   blending values across units: multi-unit answers break down per unit, and
   totals show per-unit values plus the combined total. Citations dedupe per
   (filename, page), keep the best rerank score, and carry `unit_id` /
   `unit_label` for the app's unit badges.

Conversation state lives in `ConversationStore` (Firestore-backed sessions
and turns, cached in process); recent turns feed both routers so short
follow-ups keep their context.

**LLM call budget:** three calls per document question — conversation router,
search router, answer synthesis. Unit routing added zero extra calls.

## Flutter DocuMind screen (for backend developers)

`residex_app/lib/features/landlord/presentation/screens/2-Documind/`:

- **Chat tab** — dash_chat_2; typing-dots indicator while waiting; on a
  multi-unit property a unit picker (each unit plus "Whole property") appears
  before the first question, and a header control changes it later; the
  chosen unit goes out as `unit_id` on every question, while "Whole property"
  leaves unit scope to the backend router; citation lines pin the page number
  and unit badge (the transparency layer for unit scoping).
- **Docs tab** — category grid → per-category list, always property-wide;
  each tile shows its unit badge; PDF-only upload with an assign-to-unit
  dialog (leases list units first).
- Lifecycle safety — deleting a unit first converts its documents to
  property-wide (`unassign_unit_documents`); deleting a property cascades
  child-first: documents (chunks + PDFs) → units → property record.

## Tests

| File | Covers |
|---|---|
| `tests/test_documind_orchestration.py` | Graph routing, search-router parsing (unit id / label echo / unknown / hallucination / failure fallback) |
| `tests/test_documind_service_flows.py` | Ask flows end-to-end with fakes: LLM-routed scoping, deterministic fallback, unknown-unit answers, ambiguous references searching the whole property, unassign/delete |
| `tests/test_rex_routes_documind_*.py` | API contract |
| `tests/test_retriever.py` | Hybrid retrieval |
| `residex_app/test/features/landlord/` | Chat text and citation helpers, unit-scope picker flows, upload rules, unit label resolution |

Run backend tests with a Python 3.11 that has `sentence_transformers`
installed (the repo `.venv` does not): `py -3.11 -m pytest tests/ -q` from
`backend/`.
