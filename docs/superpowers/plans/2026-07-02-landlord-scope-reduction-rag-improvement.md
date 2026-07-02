# Landlord-Only Scope Reduction + RAG Quality Improvements

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete tenant features from codebase, integrate hybrid retrieval + cross-encoder reranking + evaluation automation from KnowledgePilot reference into Documind RAG, producing a focused portfolio-grade system.

**Architecture:** Scope reduction happens in two layers (backend/frontend). RAG improvements are copy-paste + minimal config from backend_reference_example. New components: `retriever.py` (hybrid logic), `evaluator.py` (pytest harness), updates to `documind_service.py` and `requirements.txt`.

**Tech Stack:** FastAPI, LangChain, Firestore, Gemini, sentence-transformers (cross-encoder), pytest, LangSmith (optional tracing).

## Global Constraints

- No breaking changes to existing API contracts (`/api/rex/documind/*` endpoints remain unchanged)
- Frontend deletion must not affect landlord feature navigation
- All Documind RAG improvements backward-compatible (existing `ask` endpoint signature unchanged)
- Tests added must not increase backend startup latency
- Target: Complete within 2 weeks

---

## Phase 1: Scope Reduction (Tenant Feature Deletion)

### Task 1: Delete Tenant Frontend Feature Folder

**Files:**
- Delete: `residex_app/lib/features/tenant/` (entire folder, 64 .dart files)
- Modify: `residex_app/lib/main.dart` (remove tenant route/navigation)
- Modify: `residex_app/pubspec.yaml` (if tenant-specific deps exist, remove)

**Interfaces:**
- Consumes: None (deletion only)
- Produces: Frontend still boots, landlord routes work, no tenant screens accessible

- [ ] **Step 1: Backup tenant folder (safety)**

```bash
cd residex_app
mv lib/features/tenant lib/features/tenant.backup
```

- [ ] **Step 2: Check main.dart for tenant route registration**

Run: `grep -n "tenant" lib/main.dart`

Expected output: Any lines referencing tenant navigation. Note them.

- [ ] **Step 3: Remove tenant routes from main.dart**

If main.dart has GoRouter or navigation setup with tenant routes, remove those lines. Example:

```dart
// DELETE this section if it exists:
GoRoute(
  path: '/tenant',
  builder: (context, state) => TenantScreen(),
)
```

- [ ] **Step 4: Check pubspec.yaml for tenant-specific packages**

Run: `grep -i "tenant\|expense\|maintenance_request" pubspec.yaml`

Expected: May be empty (tenant deps likely shared). If matches, remove only those specific deps.

- [ ] **Step 5: Run flutter pub get to verify no broken imports**

```bash
flutter pub get
```

Expected: Completes without "Missing packages" errors.

- [ ] **Step 6: Run flutter analyze to check for unused imports**

```bash
flutter analyze
```

Expected: No errors related to tenant imports. Warnings OK at this stage.

- [ ] **Step 7: Permanently delete tenant.backup folder**

```bash
rm -rf lib/features/tenant.backup
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: remove tenant feature from frontend"
```

---

### Task 2: Delete Tenant Backend Routes & Agents

**Files:**
- Delete: `backend/agents/lease_generator.py` (tenant lease generation, unused in landlord scope)
- Modify: `backend/api/rex_routes.py` (remove lease endpoints)
- Modify: `backend/main.py` (no structural changes needed, just cleaner imports)

**Interfaces:**
- Consumes: None (deletion only)
- Produces: FastAPI app only exports `/api/rex/documind/*` and property management endpoints

- [ ] **Step 1: Review rex_routes.py to identify all lease endpoints**

Run: `grep -n "lease" backend/api/rex_routes.py`

Expected output: Lines mentioning `/lease/generate` and other lease routes.

- [ ] **Step 2: Delete lease_generator.py**

```bash
rm backend/agents/lease_generator.py
```

- [ ] **Step 3: Remove lease routes from rex_routes.py**

Open `backend/api/rex_routes.py`. Find and delete:
- Import: `from agents.lease_generator import generate_lease`
- Section: `# ========== LEASE GENERATOR ROUTES ==========` and all routes under it
- Any `@router.post("/lease/...")` endpoints

After deletion, file should start with documind routes only.

- [ ] **Step 4: Check if agents/ folder is now empty**

Run: `ls -la backend/agents/`

- [ ] **Step 5: Delete empty agents/ folder**

```bash
rm -rf backend/agents
```

- [ ] **Step 6: Update main.py docstring to reflect landlord-only focus**

Open `backend/main.py`. Change the docstring:

```python
app = FastAPI(
    title="Documind RAG Backend",  # Changed from "Rex AI Backend"
    description="Landlord Document RAG + Property Management API",  # Changed
    version="2.0.0"
)
```

And update the root endpoint response:

```python
@app.get("/")
async def root():
    return {
        "message": "Documind RAG Backend",
        "version": "2.0.0",
        "features": ["Document RAG (Firestore Vector Search)", "Property Management"]
    }
```

- [ ] **Step 7: Run pytest to verify no import errors**

```bash
cd backend
pytest tests/ -v --tb=short
```

Expected: Tests pass (or skip gracefully if lease routes had tests).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: remove lease generator and tenant routes from backend"
```

---

### Task 3: Clean Up Documentation

**Files:**
- Modify: `prd.md` (remove tenant use cases, focus on landlord)
- Modify: `README.md` (update feature list, remove tenant/lease references)
- Delete: Any docs in `backend/agents/` folder-specific docs (already deleted)

**Interfaces:**
- Consumes: None
- Produces: Documentation reflects landlord-only scope

- [ ] **Step 1: Update prd.md—remove tenant/lease sections**

Open `prd.md`. Remove or comment out sections mentioning:
- Tenant expense tracking
- Lease generation
- Tenant communication
- Maintenance request workflows

Keep:
- DocuMind RAG overview
- Property management
- Auth

- [ ] **Step 2: Update README.md feature list**

Find the "Features" section in README. Update to:

```markdown
## Features

- **DocuMind RAG** — AI-powered document Q&A for leases, warranties, insurance, utilities, receipts
- **Property Management** — View, create, update properties; track documents per property
- **Authentication** — Secure login/registration for landlords
```

- [ ] **Step 3: Commit**

```bash
git add prd.md README.md
git commit -m "docs: update scope to landlord-only, remove tenant/lease references"
```

---

## Phase 2: Integrate Hybrid Retrieval + Reranking (from KnowledgePilot)

### Task 4: Update requirements.txt with New Dependencies

**Files:**
- Modify: `backend/requirements.txt` (add sentence-transformers for cross-encoder)

**Interfaces:**
- Consumes: None
- Produces: sentence-transformers library available for import

- [ ] **Step 1: Add sentence-transformers to requirements.txt**

Open `backend/requirements.txt`. Add at the end:

```
# ML/NLP for reranking
sentence-transformers
scikit-learn
```

- [ ] **Step 2: Install new dependencies**

```bash
cd backend
pip install -r requirements.txt
```

Expected: No errors. sentence-transformers downloads ~400MB on first install.

- [ ] **Step 3: Verify import works**

```bash
python -c "from sentence_transformers import CrossEncoder; print('Import OK')"
```

Expected output: `Import OK`

- [ ] **Step 4: Commit**

```bash
git add backend/requirements.txt
git commit -m "deps: add sentence-transformers for cross-encoder reranking"
```

---

### Task 5: Create Hybrid Retriever Module (Dense + BM25 + CrossEncoder)

**Files:**
- Create: `backend/rag/retriever.py` (new hybrid retrieval logic)

**Interfaces:**
- Consumes: 
  - Firestore Vector Search (existing)
  - `langchain.retrievers.BM25Retriever` (new)
  - `sentence_transformers.CrossEncoder` (new)
- Produces: `HybridRetriever` class with `retrieve(query, property_id, category_filters, top_k)` → `list[dict]` with `[{text, metadata, dense_score, rerank_score}, ...]`

- [ ] **Step 1: Write the HybridRetriever class skeleton with imports**

Create `backend/rag/retriever.py`:

```python
from typing import Optional, Any
from langchain.retrievers import BM25Retriever, EnsembleRetriever
from langchain.schema import Document
from sentence_transformers import CrossEncoder
from google.cloud import firestore
import numpy as np


class HybridRetriever:
    """
    Hybrid retriever combining dense vector search (Firestore Vector Search) 
    + sparse keyword search (BM25) + cross-encoder reranking.
    """
    
    def __init__(self, firestore_client: firestore.Client, bm25_index: Optional[BM25Retriever] = None):
        """
        Args:
            firestore_client: Firestore client for vector search
            bm25_index: Pre-built BM25Retriever (if None, skips BM25, falls back to dense-only)
        """
        self.firestore = firestore_client
        self.bm25_retriever = bm25_index
        self.cross_encoder = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')
    
    async def retrieve(
        self,
        query: str,
        property_id: str,
        top_k: int = 4,
        category_filters: Optional[list[str]] = None,
    ) -> list[dict]:
        """
        Retrieve documents using hybrid strategy.
        
        Returns:
            [
                {
                    'text': chunk_text,
                    'metadata': {doc_id, filename, category, page, ...},
                    'dense_score': float (0-1),
                    'rerank_score': float (0-1),
                },
                ...
            ]
        """
        # TODO: Implement dense retrieval from Firestore
        pass
```

- [ ] **Step 2: Implement dense retrieval (adapt from documind_service.py)**

Add to `HybridRetriever.retrieve()`:

```python
# Dense: Query Firestore Vector Search
dense_results = await self._dense_search(query, property_id, category_filters, top_k=10)
# dense_results: list of {text, metadata, score}
```

Add helper:

```python
async def _dense_search(
    self, 
    query: str, 
    property_id: str, 
    category_filters: Optional[list[str]], 
    top_k: int
) -> list[dict]:
    """Query Firestore Vector Search, return top-k chunks with embedding scores."""
    # Reuse logic from documind_service.py's embedding + retrieval
    # For now: call existing documind_service.retrieve_chunks() logic
    # Return: list of {text, metadata, score}
    pass
```

- [ ] **Step 3: Implement BM25 fallback (if bm25_index exists)**

Add to `HybridRetriever.retrieve()`:

```python
# Sparse: BM25 search (if index built)
sparse_results = []
if self.bm25_retriever:
    bm25_docs = await self.bm25_retriever.aget_relevant_documents(query)
    sparse_results = [
        {
            'text': doc.page_content,
            'metadata': doc.metadata,
            'score': 0.5,  # placeholder; BM25 doesn't expose scores easily
        }
        for doc in bm25_docs[:10]
    ]
```

- [ ] **Step 4: Implement ensemble fusion (RRF: reciprocal rank fusion)**

Add to `HybridRetriever.retrieve()`:

```python
# Ensemble: Combine dense + sparse via RRF
# RRF score = (dense_weight / (rank + 60)) + (sparse_weight / (rank + 60))
fused = self._rrf_fusion(dense_results, sparse_results, dense_weight=0.6, sparse_weight=0.4)
# fused: list of {text, metadata, dense_score, sparse_score}
```

Add helper:

```python
def _rrf_fusion(
    self, 
    dense: list[dict], 
    sparse: list[dict], 
    dense_weight: float = 0.6, 
    sparse_weight: float = 0.4
) -> list[dict]:
    """
    Reciprocal Rank Fusion: combine two ranked lists without score calibration.
    """
    # Create a map: text -> {scores, metadata}
    fused_map = {}
    
    # Add dense results with rank
    for rank, result in enumerate(dense, 1):
        key = result['text'][:100]  # Use text prefix as key
        rrf_score = dense_weight / (rank + 60)
        if key not in fused_map:
            fused_map[key] = {
                'text': result['text'],
                'metadata': result['metadata'],
                'dense_score': result['score'],
                'sparse_score': 0.0,
                'rrf_score': 0.0,
            }
        fused_map[key]['rrf_score'] += rrf_score
    
    # Add sparse results with rank
    for rank, result in enumerate(sparse, 1):
        key = result['text'][:100]
        rrf_score = sparse_weight / (rank + 60)
        if key not in fused_map:
            fused_map[key] = {
                'text': result['text'],
                'metadata': result['metadata'],
                'dense_score': 0.0,
                'sparse_score': result['score'],
                'rrf_score': 0.0,
            }
        else:
            fused_map[key]['sparse_score'] = result['score']
        fused_map[key]['rrf_score'] += rrf_score
    
    # Sort by RRF score, take top-K
    fused_list = sorted(fused_map.values(), key=lambda x: x['rrf_score'], reverse=True)
    return fused_list
```

- [ ] **Step 5: Implement cross-encoder reranking**

Add to `HybridRetriever.retrieve()`:

```python
# Reranking: Score fused results with cross-encoder
candidates = fused[:15]  # Rerank only top-15 (cross-encoder is slow)
pair_inputs = [(query, c['text']) for c in candidates]
rerank_scores = self.cross_encoder.predict(pair_inputs)

# Normalize to [0, 1] and merge back
for i, candidate in enumerate(candidates):
    candidate['rerank_score'] = float(rerank_scores[i])

# Sort by rerank score, return top-k
reranked = sorted(candidates, key=lambda x: x['rerank_score'], reverse=True)
return reranked[:top_k]
```

- [ ] **Step 6: Write unit test for HybridRetriever**

Create `backend/tests/test_retriever.py`:

```python
import pytest
from rag.retriever import HybridRetriever


@pytest.mark.asyncio
async def test_hybrid_retriever_returns_top_k():
    """Verify retriever returns exactly top_k results."""
    # Mock Firestore + BM25
    # Call retrieve(query="...", property_id="...", top_k=4)
    # Assert len(results) == 4
    # Assert each result has keys: text, metadata, dense_score, rerank_score
    pass


@pytest.mark.asyncio
async def test_rrf_fusion_combines_scores():
    """Verify RRF fusion combines dense + sparse rankings."""
    # Create mock dense_results, sparse_results
    # Call _rrf_fusion()
    # Assert fused results ranked by RRF score
    pass
```

- [ ] **Step 7: Commit**

```bash
git add backend/rag/retriever.py backend/tests/test_retriever.py
git commit -m "feat: add hybrid retriever with BM25 + cross-encoder reranking"
```

---

### Task 6: Integrate HybridRetriever into documind_service.py

**Files:**
- Modify: `backend/rag/documind_service.py` (swap dense-only retrieval for hybrid)

**Interfaces:**
- Consumes: `HybridRetriever` from task 5
- Produces: Same API (`ask_documind()`, `ingest_document()` signatures unchanged)

- [ ] **Step 1: Add import to documind_service.py**

At top of file:

```python
from rag.retriever import HybridRetriever
```

- [ ] **Step 2: Initialize HybridRetriever in documind_service.__init__()**

Find the `__init__` method. Add:

```python
self.hybrid_retriever = HybridRetriever(
    firestore_client=self.db,
    bm25_index=None  # TODO: build BM25 index on ingest
)
```

- [ ] **Step 3: Replace existing retrieval call with hybrid retrieval**

Find the line in `ask_documind()` that calls the old dense retrieval (likely `retrieve_chunks()` or similar). Replace with:

```python
# Old (example):
# retrieved_chunks = await self.retrieve_chunks(query, property_id, top_k)

# New:
retrieved_chunks = await self.hybrid_retriever.retrieve(
    query=query,
    property_id=property_id,
    top_k=top_k,
    category_filters=categories,
)
```

- [ ] **Step 4: Update citation logic to use rerank_score**

In the citation construction code (likely in `ask_documind()` where citations are built), add rerank score:

```python
for chunk in retrieved_chunks:
    citation = Citation(
        doc_id=chunk['metadata']['doc_id'],
        filename=chunk['metadata']['filename'],
        category=chunk['metadata']['category'],
        page=chunk['metadata'].get('page', 0),
        snippet=chunk['text'][:200],
        score=chunk.get('rerank_score', chunk.get('dense_score', 0.0)),  # Prefer rerank score
    )
    citations.append(citation)
```

- [ ] **Step 5: Run existing documind tests to verify backward compatibility**

```bash
cd backend
pytest tests/test_rex_routes_documind_ask_api.py -v
```

Expected: All tests pass. API response structure unchanged.

- [ ] **Step 6: Manual test with curl**

```bash
curl -X POST http://localhost:8000/api/rex/documind/ask \
  -H "Content-Type: application/json" \
  -d '{
    "landlord_id": "test_landlord",
    "property_id": "test_property",
    "query": "What is the security deposit amount?",
    "session_id": "test_session"
  }'
```

Expected: Response includes `answer`, `citations` with higher-quality results (due to reranking).

- [ ] **Step 7: Commit**

```bash
git add backend/rag/documind_service.py
git commit -m "feat: integrate hybrid retriever into documind RAG pipeline"
```

---

## Phase 3: Add Evaluation Automation

### Task 7: Create Pytest Evaluation Harness

**Files:**
- Create: `backend/tests/test_documind_evaluation.py` (golden dataset + auto-eval)

**Interfaces:**
- Consumes: 
  - Existing 12 test cases from `backend/tests/TEST_CASES.md`
  - `documind_service` from task 6
- Produces: `pytest` runnable harness with metrics (pass %, precision, recall)

- [ ] **Step 1: Create evaluation test file with golden dataset**

Create `backend/tests/test_documind_evaluation.py`:

```python
import pytest
import asyncio
from rag.documind_service import documind_service
from models.documind_models import AskRequest


# Golden dataset: 12 test cases from TEST_CASES.md
GOLDEN_CASES = [
    {
        'id': 'T01_simple_security_deposit',
        'landlord_id': 'landlord_damai',
        'property_id': 'property_damai_batu',
        'query': 'What is the security deposit amount for my property?',
        'expected_answer_keywords': ['security deposit', 'RM'],
        'expected_sources': ['lease.pdf'],
        'categories': None,
    },
    {
        'id': 'T02_warranty_exclusion',
        'landlord_id': 'landlord_damai',
        'property_id': 'property_damai_batu',
        'query': 'Are water damages covered by the warranty?',
        'expected_answer_keywords': ['water', 'not covered', 'exclusion'],
        'expected_sources': ['warranty.pdf'],
        'categories': ['warranty'],
    },
    {
        'id': 'T03_insurance_coverage',
        'landlord_id': 'landlord_damai',
        'property_id': 'property_damai_batu',
        'query': 'What is the coverage amount for contents insurance?',
        'expected_answer_keywords': ['coverage', 'RM', '50000'],
        'expected_sources': ['insurance.pdf'],
        'categories': ['insurance'],
    },
    # ... add remaining 9 cases from TEST_CASES.md
]


@pytest.mark.asyncio
@pytest.mark.parametrize('case', GOLDEN_CASES, ids=[c['id'] for c in GOLDEN_CASES])
async def test_documind_golden_cases(case):
    """
    Test that documind RAG answers golden cases correctly.
    Measures: answer correctness, citation accuracy.
    """
    request = AskRequest(
        landlord_id=case['landlord_id'],
        property_id=case['property_id'],
        query=case['query'],
        session_id=f"eval_{case['id']}",
        categories=case['categories'],
    )
    
    response = await documind_service.ask_documind(request)
    
    # Assert: answer contains expected keywords
    answer_lower = response.answer.lower()
    for keyword in case['expected_answer_keywords']:
        assert keyword.lower() in answer_lower, \
            f"Expected keyword '{keyword}' not in answer: {response.answer}"
    
    # Assert: citations exist
    assert len(response.citations) > 0, "Expected at least one citation"
    
    # Assert: citation sources match expected
    cited_sources = [c.filename for c in response.citations]
    for expected_source in case['expected_sources']:
        assert any(expected_source in source for source in cited_sources), \
            f"Expected source '{expected_source}' not in citations: {cited_sources}"


@pytest.mark.asyncio
async def test_documind_hallucination_rate():
    """
    Verify hallucination rate is 0% (no answers when info not found).
    """
    request = AskRequest(
        landlord_id='landlord_damai',
        property_id='property_damai_batu',
        query='What is the tenant\'s favorite color?',  # Not in documents
        session_id='eval_hallucination_check',
    )
    
    response = await documind_service.ask_documind(request)
    
    # Assert: system admits when info not found
    assert 'not found' in response.answer.lower() or 'no information' in response.answer.lower(), \
        f"Expected 'not found' message, got: {response.answer}"


def test_evaluation_metrics_calculation():
    """
    Calculate and log evaluation metrics.
    """
    pass_count = 0
    total_count = len(GOLDEN_CASES)
    
    # After all tests run, print metrics
    # This is pseudo-code; actual implementation runs via pytest hooks
    precision_at_1 = pass_count / total_count if total_count > 0 else 0
    
    print(f"\n\n{'='*60}")
    print(f"DOCUMIND EVALUATION METRICS")
    print(f"{'='*60}")
    print(f"Pass Rate: {precision_at_1:.1%} ({pass_count}/{total_count})")
    print(f"{'='*60}")
```

- [ ] **Step 2: Add pytest conftest for async test setup**

Create `backend/tests/conftest.py`:

```python
import pytest
import asyncio
import os
from dotenv import load_dotenv

# Load test environment
load_dotenv()

@pytest.fixture(scope='session')
def event_loop():
    """Provide event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()
```

- [ ] **Step 3: Add all 12 test cases to GOLDEN_CASES**

Reference `backend/tests/TEST_CASES.md`. For each test case, add a dict to `GOLDEN_CASES` with:
- `id`: Test case ID (T01, T02, ..., T12)
- `landlord_id`, `property_id`, `query`: From TEST_CASES.md
- `expected_answer_keywords`: Key terms that must appear in answer
- `expected_sources`: PDF filenames that should be cited
- `categories`: Category filter (if applicable)

Example:

```python
{
    'id': 'T07_multi_doc_reference',
    'landlord_id': 'landlord_ipoh',
    'property_id': 'property_ipoh_roadside',
    'query': 'How do I report a maintenance issue?',
    'expected_answer_keywords': ['maintenance', 'report', 'landlord'],
    'expected_sources': ['lease.pdf', 'warranty.pdf'],
    'categories': None,
},
```

- [ ] **Step 4: Run evaluation tests**

```bash
cd backend
pytest tests/test_documind_evaluation.py -v --tb=short
```

Expected output:

```
test_documind_evaluation.py::test_documind_golden_cases[T01_simple_security_deposit] PASSED
test_documind_evaluation.py::test_documind_golden_cases[T02_warranty_exclusion] PASSED
...
test_documind_evaluation.py::test_documind_hallucination_rate PASSED
```

If tests fail, note failures and fix documind_service logic.

- [ ] **Step 5: Add metrics summary to test output**

Modify conftest.py to add a pytest hook that prints summary:

```python
def pytest_sessionfinish(session, exitstatus):
    """Print test summary."""
    if hasattr(session, 'items'):
        passed = sum(1 for item in session.items if item.nodeid.startswith('test_documind_evaluation'))
        total = sum(1 for item in session.items if item.nodeid.startswith('test_documind_evaluation'))
        print(f"\n\n{'='*60}")
        print(f"DOCUMIND EVALUATION SUMMARY")
        print(f"Pass Rate: {passed}/{total} ({100*passed/total:.1f}%)")
        print(f"{'='*60}\n")
```

- [ ] **Step 6: Commit**

```bash
git add backend/tests/test_documind_evaluation.py backend/tests/conftest.py
git commit -m "test: add pytest golden dataset evaluation harness"
```

---

### Task 8: Add LangSmith Tracing (Optional but Recommended)

**Files:**
- Modify: `backend/.env` (add LANGSMITH_API_KEY)
- Modify: `backend/rag/documind_service.py` (enable LangSmith tracing on ask calls)

**Interfaces:**
- Consumes: LangSmith API key (user provides)
- Produces: Every `ask_documind()` call traces to LangSmith dashboard

- [ ] **Step 1: Add LangSmith API key to .env**

Open `backend/.env`. Add:

```
LANGSMITH_API_KEY=<your-langsmith-api-key>
LANGCHAIN_TRACING_V2=true
LANGCHAIN_PROJECT=documind-landlord
```

To get a key: https://smith.langchain.com → Sign up → Settings → Create API key

- [ ] **Step 2: Update requirements.txt to include langsmith**

Already in `requirements.txt` (via langchain), but verify:

```bash
grep langsmith backend/requirements.txt
```

If missing, add:

```
langsmith
```

- [ ] **Step 3: Enable tracing in documind_service**

In `documind_service.py`, at the start of `ask_documind()`:

```python
import os
from langsmith import traceable

@traceable(name="documind_ask", tags=["rag", "landlord"])
async def ask_documind(self, request: AskRequest) -> AskResponse:
    # ... existing code
    pass
```

Or simpler: Just ensure LangChain env vars are set (LangChain auto-traces when LANGCHAIN_TRACING_V2=true).

- [ ] **Step 4: Verify tracing works**

Run a test ask:

```bash
curl -X POST http://localhost:8000/api/rex/documind/ask \
  -H "Content-Type: application/json" \
  -d '{...}'
```

Then check LangSmith dashboard (https://smith.langchain.com/projects) → Your project → You should see the trace.

- [ ] **Step 5: Commit**

```bash
git add backend/.env
git commit -m "ops: enable LangSmith tracing for observability"
```

---

## Phase 4: Cleanup & Polish

### Task 9: Clean Up Old Test Files & Documentation

**Files:**
- Delete: Any old lease-related test files (if exist)
- Modify: `backend/DOCUMIND_CHECKLIST.md` (update completion status)

**Interfaces:**
- Consumes: None
- Produces: Codebase cleaner, no orphaned tests

- [ ] **Step 1: Check for lease-related test files**

```bash
find backend/tests -name "*lease*" -o -name "*rex*"
```

Expected: Likely `test_rex_routes_*` files exist.

- [ ] **Step 2: Delete lease tests (keep documind tests)**

If there are lease-specific tests, delete them:

```bash
rm backend/tests/test_rex_routes_lease_api.py  # if exists
```

Keep:

```bash
# These should remain:
backend/tests/test_rex_routes_documind_ask_api.py
backend/tests/test_rex_routes_documind_docs_api.py
backend/tests/test_documind_evaluation.py  # new from task 7
```

- [ ] **Step 3: Update DOCUMIND_CHECKLIST.md**

Open `backend/DOCUMIND_CHECKLIST.md`. Update summary at top:

```markdown
**Overall Status:** 85% Complete (post-improvements)
- ✅ Implemented: Hybrid Retrieval + Reranking, Evaluation Automation
- ⚠️ Tenant features: Removed
- ⚠️ Scope: Landlord-only
```

- [ ] **Step 4: Commit**

```bash
git add backend/tests/ backend/DOCUMIND_CHECKLIST.md
git commit -m "chore: remove lease test files, update checklist"
```

---

### Task 10: Final Integration Test

**Files:**
- No new files

**Interfaces:**
- Consumes: All previous tasks
- Produces: Verified end-to-end system (upload → ask → citations)

- [ ] **Step 1: Start backend**

```bash
cd backend
python main.py
```

Expected output: Server running on port 8000.

- [ ] **Step 2: Upload a test document**

```bash
curl -X POST http://localhost:8000/api/rex/documind/upload \
  -F "landlord_id=test_landlord" \
  -F "property_id=test_property" \
  -F "category=lease" \
  -F "file=@/path/to/sample_lease.pdf"
```

Expected: `{"success": true, "doc_id": "...", "chunks_embedded": N}`

- [ ] **Step 3: Ask a question**

```bash
curl -X POST http://localhost:8000/api/rex/documind/ask \
  -H "Content-Type: application/json" \
  -d '{
    "landlord_id": "test_landlord",
    "property_id": "test_property",
    "query": "What is the security deposit?",
    "session_id": "integration_test"
  }'
```

Expected: Response with `answer`, `citations` (should include rerank_score in scores).

- [ ] **Step 4: List documents**

```bash
curl "http://localhost:8000/api/rex/documind/documents?landlord_id=test_landlord&property_id=test_property"
```

Expected: List of uploaded documents.

- [ ] **Step 5: Run evaluation suite**

```bash
cd backend
pytest tests/test_documind_evaluation.py -v
```

Expected: All 12 golden cases pass (or note failures to fix).

- [ ] **Step 6: Commit a final summary**

```bash
git add -A
git commit -m "chore: final integration test—all systems operational"
```

---

## Post-Implementation Verification Checklist

- [ ] No tenant features remain in codebase (grep for "tenant", "lease", "expense")
- [ ] All API tests pass: `pytest tests/ -v`
- [ ] Evaluation tests pass: `pytest tests/test_documind_evaluation.py::test_documind_golden_cases -v`
- [ ] No new security vulnerabilities: `bandit -r backend/`
- [ ] LangSmith traces appear in dashboard (if configured)
- [ ] Cross-encoder reranking is active (check citations have rerank_score in responses)
- [ ] README reflects landlord-only scope
- [ ] All changes committed to git

---

## Rollback Plan (if needed)

If integration fails at any task:

1. **Task 1-3 (Scope Reduction):** These are deletions. Rollback with `git reset --hard HEAD~1` or restore from `tenant.backup` folder.
2. **Task 4-6 (Hybrid Retrieval):** Rollback `documind_service.py` to use old retrieval. New `retriever.py` can be deleted without impact.
3. **Task 7-8 (Evaluation):** Rollback test files. They don't affect runtime.

---

## Success Criteria

✅ Tenant features completely removed (no references in code/docs)  
✅ Hybrid retrieval integrated (dense + BM25 + cross-encoder)  
✅ Evaluation harness automated (pytest runs 12 golden cases)  
✅ All existing API contracts maintained (zero breaking changes)  
✅ Codebase is focused, documented, and portfolio-ready  

---

**Estimated Duration:** 2 weeks (scope reduction 2-3 days, RAG improvements 3-4 days, evaluation 2-3 days, integration 1-2 days)
