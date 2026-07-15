# Plan A — Category Taxonomy, OCR & Fact Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [`docs/superpowers/specs/2026-07-15-documind-financial-intelligence-design.md`](../specs/2026-07-15-documind-financial-intelligence-design.md) (Plan A of three). Supersedes the unexecuted plan `2026-07-08-documind-fact-extraction.md`.

**Goal:** Replace the 5-category taxonomy with the 7 finance-matched categories (read-time aliases, no migration), add a Gemini-native OCR fallback for scanned PDFs, and extract structured facts from every document at ingest — surfaced through the API and the upload snackbar.

**Architecture:** All backend work lives in `backend/rag/` following the house pattern for injected-LLM helpers (`CategoryPredictor`): constructor-injected `llm`, semicolon `key=value` response format, defensive parse, `None` over guessing. Category renames are applied at read time via an alias map — stored documents are never rewritten. Two new modules (`fact_extractor.py`, `pdf_ocr.py`) hook into `ingest_document`; both are strictly best-effort and can never fail an ingestion. Flutter gets the 7 categories in its picker/labels plus `extracted_facts` on the document model and a fact-confirming snackbar.

**Tech Stack:** FastAPI + Firestore + `langchain_google_genai` (`gemini-2.5-flash`) backend; `pypdf` (already a PyPDFLoader dependency) for page slicing; Flutter/Riverpod frontend.

## Global Constraints

- Backend tests run with `py -3.11 -m pytest tests/ -q` from `backend/` (the repo `.venv` lacks pytest and sentence_transformers). Baseline before this plan: **74 passing**.
- Flutter tests run with `flutter test` from `residex_app/`; baseline **29 passing**. `flutter analyze` must stay at its **0-error** baseline.
- No emoji in user-facing UI text — icon glyphs + `AppColors` tokens only (log lines in backend Python may keep the existing emoji-prefix style).
- Ingestion is PDF-only; the picker already enforces it (commit `13d8cd3`).
- The category aliases are exactly: `utility → upkeep`, `receipt → rental_invoice`, `warranty → upkeep`. No data migration, ever.
- Fact extraction and OCR are best-effort: **no failure of either may block, delay, or degrade document ingestion** (test-enforced).
- The backend has no hot reload — restart it manually for any manual verification.
- Commit after every task with the exact message given in the task's final step.

---

### Task 1: New taxonomy constants, alias helpers, upload validation (backend)

**Files:**
- Modify: `backend/rag/documind_service.py:36-53` (constants), `:213-222` (delete dead method), `:311-324` (ingest validation)
- Modify: `backend/api/rex_routes.py:9-34` (400 on bad category, docstring)
- Create: `backend/tests/test_category_taxonomy.py`
- Modify: `backend/tests/test_documind_service_flows.py` (append test class)

**Interfaces:**
- Produces: module-level `ALLOWED_CATEGORIES: set[str]` (7 new names), `CATEGORY_ORDER: list[str]`, `LEGACY_CATEGORY_ALIASES: dict[str, str]`, `normalize_category(category: Optional[str]) -> Optional[str]`, `expand_categories_for_query(categories: List[str]) -> List[str]` — all importable from `rag.documind_service`. Tasks 2 and 4 and Plan B's engine I/O consume these.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_category_taxonomy.py`:

```python
import unittest

from rag.documind_service import (
    ALLOWED_CATEGORIES,
    CATEGORY_ORDER,
    expand_categories_for_query,
    normalize_category,
)


class CategoryAliasTests(unittest.TestCase):
    def test_allowed_categories_are_the_seven_new_names(self):
        self.assertEqual(
            ALLOWED_CATEGORIES,
            {"lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice"},
        )
        self.assertEqual(sorted(ALLOWED_CATEGORIES), sorted(CATEGORY_ORDER))

    def test_normalize_maps_legacy_names(self):
        self.assertEqual(normalize_category("utility"), "upkeep")
        self.assertEqual(normalize_category("receipt"), "rental_invoice")
        self.assertEqual(normalize_category("warranty"), "upkeep")

    def test_normalize_passes_through_current_names_and_none(self):
        self.assertEqual(normalize_category("lease"), "lease")
        self.assertEqual(normalize_category(" Loan "), "loan")
        self.assertIsNone(normalize_category(None))

    def test_expand_adds_legacy_spellings(self):
        self.assertEqual(
            expand_categories_for_query(["upkeep"]), ["upkeep", "utility", "warranty"]
        )
        self.assertEqual(
            expand_categories_for_query(["rental_invoice"]), ["rental_invoice", "receipt"]
        )
        self.assertEqual(expand_categories_for_query(["lease"]), ["lease"])
```

Append to `backend/tests/test_documind_service_flows.py` (uses the file's existing `_build_service`, `_FakeDB`, `_FakeConversationStore`, `_FakeGraphOrchestrator`, `_FakeLLM`, `_FakeStorageBucket`, `_FakeEmbeddings` and its imports of `MagicMock`, `PropertyMock`, `patch`, `DocuMindService`):

```python
class CategoryTaxonomyIngestTests(unittest.IsolatedAsyncioTestCase):
    def _upload_file(self):
        class _FakeUploadFile:
            filename = "doc.pdf"

            async def read(self):
                return b"%PDF-1.4 fake content"

        return _FakeUploadFile()

    async def test_ingest_rejects_unknown_category(self):
        service = _build_service(
            _FakeDB(), _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        with self.assertRaises(ValueError):
            await service.ingest_document(
                landlord_id="l1",
                property_id="p1",
                category="bank-statement",
                file=self._upload_file(),
            )

    async def test_ingest_normalizes_legacy_category_before_storing(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            fake_page = MagicMock()
            fake_page.page_content = "TNB electricity bill for the unit's aircon repair"
            fake_page.metadata = {"page": 0}
            loader_mock.return_value.load.return_value = [fake_page]

            response = await service.ingest_document(
                landlord_id="l1",
                property_id="p1",
                category="utility",
                file=self._upload_file(),
            )

        self.assertEqual(response.category, "upkeep")
        stored_doc = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored_doc["category"], "upkeep")
        self.assertTrue(all(c["category"] == "upkeep" for c in fake_db.chunks))
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `backend/`: `py -3.11 -m pytest tests/test_category_taxonomy.py tests/test_documind_service_flows.py -q`
Expected: ImportError (`normalize_category` not defined) for the new file; the two new ingest tests FAIL (no validation, category stored verbatim). The 74 pre-existing tests must still pass — note some existing tests seed `_FakeDB` with `"warranty"` docs; they don't touch the constants yet and stay green.

- [ ] **Step 3: Implement constants + helpers**

In `backend/rag/documind_service.py`, replace lines 36-53 (`ALLOWED_CATEGORIES = ...` through the end of the `CATEGORY_KEYWORDS` dict) with:

```python
# 7-category taxonomy (2026-07 financial-intelligence spec). Documents stored
# before the rename keep their legacy category strings; LEGACY_CATEGORY_ALIASES
# maps them at every read and expand_categories_for_query() widens stored-name
# queries. No data migration.
ALLOWED_CATEGORIES = {
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
}
CATEGORY_ORDER = [
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
]
LEGACY_CATEGORY_ALIASES = {
    "utility": "upkeep",
    "receipt": "rental_invoice",
    "warranty": "upkeep",
}


def normalize_category(category: Optional[str]) -> Optional[str]:
    """Stored/legacy category -> current taxonomy name (read-time alias)."""
    if not category:
        return category
    lowered = category.strip().lower()
    return LEGACY_CATEGORY_ALIASES.get(lowered, lowered)


def expand_categories_for_query(categories: List[str]) -> List[str]:
    """Current-taxonomy filter -> every stored name it must match, including
    legacy spellings (chunks written pre-rename still carry 'utility' etc.)."""
    expanded: List[str] = []
    for category in categories:
        if category not in expanded:
            expanded.append(category)
        for legacy, current in LEGACY_CATEGORY_ALIASES.items():
            if current == category and legacy not in expanded:
                expanded.append(legacy)
    return expanded
```

Delete the now-dead `_detect_categories_from_question` method (`documind_service.py:213-222`) — it was `CATEGORY_KEYWORDS`' only consumer and has no callers (verified 2026-07-16 via grep).

At the top of `ingest_document` (currently `:311`), before `doc_id = str(uuid.uuid4())`:

```python
        category = normalize_category(category)
        if category not in ALLOWED_CATEGORIES:
            raise ValueError(
                f"Unsupported category '{category}'. Allowed: {', '.join(CATEGORY_ORDER)}"
            )
```

In `backend/api/rex_routes.py`, change `documind_upload`'s body (the `return await documind_service.ingest_document(...)` call at `:27-34`) to:

```python
    try:
        return await documind_service.ingest_document(
            landlord_id=landlord_id,
            property_id=property_id,
            category=category,
            file=file,
            unit_id=unit_id,
            unit_label=unit_label,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
```

and update its docstring category line to:

```python
    Category options: 'lease', 'insurance', 'loan', 'tax', 'upkeep',
    'maintenance', 'rental_invoice' (legacy names utility/receipt/warranty are
    accepted and stored under their new equivalents)
```

- [ ] **Step 4: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: the 4 new + 2 new ingest tests PASS. **Expect collateral failures** in existing tests that assert legacy category behavior through `ALLOWED_CATEGORIES` (e.g. flow tests seeding `"warranty"` docs and asserting `clarification_options == ["lease", "warranty"]`, or `user_action="warranty"` selection paths). Fix each failing assertion to the new taxonomy: at this task, `_list_available_categories` still checks `category in ALLOWED_CATEGORIES` against raw stored names, so legacy-seeded docs simply drop out of available categories — update those fixtures to seed new-name categories instead, e.g. `"category": "upkeep"`. Do not weaken any assertion; retarget them.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/documind_service.py backend/api/rex_routes.py backend/tests/test_category_taxonomy.py backend/tests/test_documind_service_flows.py
git commit -m "feat: 7-category taxonomy with read-time legacy aliases and upload validation"
```

---

### Task 2: Read-path aliasing everywhere stored categories surface (backend)

**Files:**
- Modify: `backend/rag/documind_service.py` — `_list_available_categories` (`:224-245` pre-Task-1 numbering), `_normalize_category_selection` aliases (`:259-265`), retrieval call (`:788`), citation build (`:860`), answer prompt (`:885-928`), `list_documents` (`:1015`)
- Modify: `backend/rag/category_predictor.py:162-168` (fallback keywords)
- Modify: `backend/rag/conversation_router.py:14-17, :66, :117` (vocabulary)
- Modify: `backend/models/documind_models.py:25, :123` (field descriptions)
- Modify: `backend/api/rex_routes.py:53` (ask docstring)
- Test: `backend/tests/test_documind_service_flows.py` (append class)

**Interfaces:**
- Consumes: Task 1's `normalize_category`, `expand_categories_for_query`, `CATEGORY_ORDER`.
- Produces: every API response (`available` categories, citations, `DocumentInfo.category`, `searched_categories`) carries only new-taxonomy names; retrieval filters match legacy-stored chunks. Plan B and Plan C rely on this ("Flutter only ever sees new names").

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_documind_service_flows.py`:

```python
class CategoryAliasReadPathTests(unittest.IsolatedAsyncioTestCase):
    async def test_available_categories_normalize_legacy_names(self):
        fake_db = _FakeDB(docs=[
            {"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "utility"},
            {"doc_id": "d2", "landlord_id": "l1", "property_id": "p1", "category": "receipt"},
            {"doc_id": "d3", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
        ])
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        self.assertEqual(
            service._list_available_categories("l1", "p1"),
            ["lease", "upkeep", "rental_invoice"],
        )

    async def test_legacy_chunks_match_new_filter_and_citations_normalize(self):
        fake_db = _FakeDB(
            docs=[{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1", "category": "utility"}],
            chunks=[{
                "doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
                "category": "utility", "filename": "aircon.pdf", "chunk_index": 0,
                "text": "Aircon servicing invoice RM 180 dated 12 March 2026", "page": 0,
            }],
        )
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["upkeep"],
            "prediction_confidence": 0.9,
            "prediction_reason": "repair question",
            "intent": "document_question",
        })
        service = _build_service(
            fake_db, _FakeConversationStore(), fake_graph, _FakeLLM("Serviced on 12 March 2026.")
        )
        response = await service.ask_documind(
            AskRequest(landlord_id="l1", property_id="p1", question="when was the aircon serviced?")
        )
        self.assertEqual(
            service._hybrid_retriever.calls[0]["categories"],
            ["upkeep", "utility", "warranty"],
        )
        self.assertEqual(response.searched_categories, ["upkeep"])
        self.assertEqual(response.citations[0].category, "upkeep")

    async def test_list_documents_returns_normalized_categories(self):
        fake_db = _FakeDB(docs=[{
            "doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
            "category": "receipt", "filename": "inv.pdf", "chunks_indexed": 2,
            "file_size": 100, "uploaded_at": datetime(2026, 1, 1),
        }])
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        response = await service.list_documents("l1", "p1")
        self.assertEqual(response.documents[0].category, "rental_invoice")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py -q`
Expected: all three FAIL — legacy names leak through unaliased.

- [ ] **Step 3: Implement the read-path aliasing**

In `backend/rag/documind_service.py`:

**(a)** `_list_available_categories` — replace the loop and ordering:

```python
            found_categories = set()
            for doc in docs_query.stream():
                data = doc.to_dict() or {}
                category = normalize_category(data.get('category'))
                if category in ALLOWED_CATEGORIES:
                    found_categories.add(category)

            ordered = [
                category for category in CATEGORY_ORDER
                if category in found_categories
            ]
            return ordered
```

**(b)** `_normalize_category_selection` — replace the `aliases` dict:

```python
        aliases = {
            "lease": ["lease", "tenancy", "tenancy agreement", "rental agreement", "agreement"],
            "insurance": ["insurance", "policy"],
            "loan": ["loan", "mortgage", "financing", "interest statement"],
            "tax": ["tax", "assessment", "cukai", "quit rent", "parcel rent", "taksiran"],
            "upkeep": ["upkeep", "repair", "servicing", "service", "utility", "warranty"],
            "maintenance": ["maintenance", "management fee", "sinking fund"],
            "rental_invoice": ["rental invoice", "rent invoice", "invoice", "invoices", "receipt"],
        }
```

**(c)** the retrieval call in `ask_documind` (currently `:783-790`) — expand the filter:

```python
            retrieved_chunks = await self._hybrid_retriever.retrieve(
                question=working_question,
                landlord_id=payload.landlord_id,
                property_id=payload.property_id,
                top_k=payload.top_k,
                categories=expand_categories_for_query(selected_categories) if selected_categories else None,
                unit_id=effective_unit_id,
            )
```

**(d)** the citation build (currently `:857-866`) — normalize what the client sees:

```python
                best_citation_by_page[page_key] = {
                    'doc_id': chunk['doc_id'],
                    'filename': chunk['filename'],
                    'category': normalize_category(chunk['category']),
                    'page': display_page,
                    'snippet': chunk['text'][:200],
                    'score': chunk_score,
                    'unit_id': chunk.get('unit_id'),
                    'unit_label': chunk.get('unit_label'),
                }
```

**(e)** the answer prompt (currently `:885-928`) — replace the purpose block and instruction wording:

```python
        prompt = f"""You are DocuMind, an AI assistant specialized in property document management.

    **Your Purpose:**
    You help landlords understand their property documents across 7 categories:
    - Tenancy Agreements (lease terms, tenant details, rent, deposits, renewals)
    - Insurance Policies (coverage, premiums, policy periods)
    - Loans (loan agreements, bank interest statements)
    - Property Taxes (assessment tax, quit rent, parcel rent)
    - Upkeep (landlord-paid repairs and servicing)
    - Maintenance (management fees and sinking fund)
    - Rental Invoices (monthly rent billed to tenants)
```

and in instruction 1 change the parenthetical to `(lease, insurance, loan, tax, upkeep, maintenance, rental invoices)`. Instructions 2-5 are unchanged.

**(f)** `list_documents` `DocumentInfo` construction (currently `:1011-1022`):

```python
                category=normalize_category(data.get('category')),
```

In `backend/rag/category_predictor.py`, replace the `fallback_keywords` dict (`:162-168`):

```python
            fallback_keywords = {
                "lease": ["lease", "tenant", "tenancy", "rent", "deposit", "pets"],
                "insurance": ["insurance", "policy", "premium", "liability"],
                "loan": ["loan", "mortgage", "interest", "bank", "financing"],
                "tax": ["tax", "assessment", "cukai", "quit rent", "parcel rent", "taksiran"],
                "upkeep": ["repair", "upkeep", "servicing", "plumbing", "aircon", "fix"],
                "maintenance": ["maintenance", "management", "sinking fund", "service charge"],
                "rental_invoice": ["invoice", "receipt", "payment", "rental invoice"],
            }
```

In `backend/rag/conversation_router.py`:
- `_default_conversation_reply` (`:14-17`): change the parenthetical to `(leases, insurance, loans, taxes, upkeep, maintenance, rental invoices)`.
- Prompt rule (`:66`): change to `- If user asks about property documents, tenancy, rent terms, insurance, loans, property taxes, upkeep/repairs, maintenance fees, rental invoices, rules/clauses, obligations -> rag_needed=true and intent=document_question.`
- Keyword fallback list (`:117`): replace with `["lease", "rent", "tenant", "insurance", "loan", "interest", "tax", "cukai", "upkeep", "repair", "maintenance", "invoice", "receipt", "property", "pets", "allowed", "clause", "agreement"]`.

In `backend/models/documind_models.py`:
- `AskRequest.categories` description (`:25`): `"Optional category filters: lease, insurance, loan, tax, upkeep, maintenance, rental_invoice"`.
- `DocumentInfo.category` comment (`:123`): `# 'lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice' (legacy names normalized at read)`.

In `backend/api/rex_routes.py` `documind_ask` docstring (`:53`): `Allowed categories: 'lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice'`.

- [ ] **Step 4: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: new tests PASS. Existing flow tests that assert on old category vocabulary (clarification options ordering, `user_action="warranty"`, keyword-fallback assertions in `test_documind_orchestration.py` / router tests) may fail — retarget fixtures and expected strings to the new taxonomy, never weaken assertions. Record the new total (expect ≥ 80).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/documind_service.py backend/rag/category_predictor.py backend/rag/conversation_router.py backend/models/documind_models.py backend/api/rex_routes.py backend/tests/
git commit -m "feat: alias-normalize categories on every read path; new router vocabulary"
```

---

### Task 3: FactExtractor module (backend)

**Files:**
- Create: `backend/rag/fact_extractor.py`
- Create: `backend/tests/test_fact_extractor.py`

**Interfaces:**
- Produces: `FactExtractor(llm)` with `extract(category: str, text: str) -> dict | None`. The returned dict contains validated fields **plus a `"confidence"` key** when the model supplied one; Task 4 pops `"confidence"` out before storing. Module constant `MAX_INPUT_CHARS = 8000`. Categories must be already-normalized new-taxonomy names (Task 1 guarantees this at ingest).

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_fact_extractor.py`:

```python
import unittest

from rag.fact_extractor import FactExtractor


class _LLMResponse:
    def __init__(self, content):
        self.content = content


class _FakeLLM:
    def __init__(self, content):
        self._content = content
        self.invocations = 0
        self.last_prompt = None

    def invoke(self, prompt):
        self.invocations += 1
        self.last_prompt = prompt
        return _LLMResponse(self._content)


class _RaisingLLM:
    def invoke(self, prompt):
        raise RuntimeError("boom")


class FactExtractorTests(unittest.TestCase):
    def test_lease_well_formed_response_parses(self):
        llm = _FakeLLM(
            "monthly_rent=RM 1,500.00;deposit=3000;lease_start=2025-09-01;"
            "lease_end=2026-09-01;tenant_name=Aisha Binti Rahman;subtype=renewal;"
            "renewal_fee=250;confidence=0.9"
        )
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT dated ...")
        self.assertEqual(facts["monthly_rent"], 1500.0)
        self.assertEqual(facts["deposit"], 3000.0)
        self.assertEqual(facts["lease_start"], "2025-09-01")
        self.assertEqual(facts["lease_end"], "2026-09-01")
        self.assertEqual(facts["tenant_name"], "Aisha Binti Rahman")
        self.assertEqual(facts["subtype"], "renewal")
        self.assertEqual(facts["renewal_fee"], 250.0)
        self.assertEqual(facts["confidence"], 0.9)

    def test_invalid_subtype_dropped_other_fields_kept(self):
        llm = _FakeLLM("subtype=extension;amount=460.63;period_year=2026;confidence=0.8")
        facts = FactExtractor(llm).extract("tax", "CUKAI TAKSIRAN bill ...")
        self.assertNotIn("subtype", facts)
        self.assertEqual(facts["amount"], 460.63)
        self.assertEqual(facts["period_year"], 2026)

    def test_loan_subtype_space_normalized_to_underscore(self):
        llm = _FakeLLM("subtype=interest statement;interest_paid=12408.31;period_year=2026;confidence=0.85")
        facts = FactExtractor(llm).extract("loan", "YEAR END INTEREST STATEMENT ...")
        self.assertEqual(facts["subtype"], "interest_statement")
        self.assertEqual(facts["interest_paid"], 12408.31)

    def test_non_iso_date_dropped(self):
        llm = _FakeLLM("lease_end=01/09/2026;monthly_rent=1500;confidence=0.7")
        facts = FactExtractor(llm).extract("lease", "some lease text")
        self.assertNotIn("lease_end", facts)
        self.assertEqual(facts["monthly_rent"], 1500.0)

    def test_period_month_validated_as_yyyy_mm(self):
        good = FactExtractor(_FakeLLM("amount=1200;period_month=2026-07;confidence=0.9")) \
            .extract("rental_invoice", "invoice text")
        self.assertEqual(good["period_month"], "2026-07")
        bad = FactExtractor(_FakeLLM("amount=1200;period_month=2026-13;confidence=0.9")) \
            .extract("rental_invoice", "invoice text")
        self.assertNotIn("period_month", bad)

    def test_none_and_unknown_values_skipped(self):
        llm = _FakeLLM("premium=none;policy_end=2027-01-31;policy_number=unknown;confidence=0.8")
        facts = FactExtractor(llm).extract("insurance", "policy schedule")
        self.assertEqual(facts, {"policy_end": "2027-01-31", "confidence": 0.8})

    def test_garbage_and_confidence_only_return_none(self):
        self.assertIsNone(
            FactExtractor(_FakeLLM("I could not find any facts.")).extract("lease", "text")
        )
        self.assertIsNone(
            FactExtractor(_FakeLLM("confidence=0.4")).extract("lease", "text")
        )

    def test_llm_exception_returns_none(self):
        self.assertIsNone(FactExtractor(_RaisingLLM()).extract("lease", "text"))

    def test_unknown_category_and_empty_text_skip_llm(self):
        llm = _FakeLLM("amount=1")
        self.assertIsNone(FactExtractor(llm).extract("other", "text"))
        self.assertIsNone(FactExtractor(llm).extract("lease", "   "))
        self.assertEqual(llm.invocations, 0)

    def test_input_text_truncated_to_cap(self):
        llm = _FakeLLM("amount=100;service_date=2026-03-12;confidence=0.9")
        FactExtractor(llm).extract("upkeep", "x" * 20000)
        self.assertLess(len(llm.last_prompt), 12000)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `py -3.11 -m pytest tests/test_fact_extractor.py -q`
Expected: ImportError — `rag.fact_extractor` does not exist.

- [ ] **Step 3: Implement the module**

Create `backend/rag/fact_extractor.py`:

```python
from __future__ import annotations

import re
from datetime import date
from typing import Any, Dict, Optional

MAX_INPUT_CHARS = 8000

# Fields requested per category. The parser is the enforcement layer:
# anything failing its type check is dropped, never guessed.
_FIELD_TYPES: Dict[str, Dict[str, str]] = {
    "lease": {
        "monthly_rent": "amount",
        "deposit": "amount",
        "lease_start": "date",
        "lease_end": "date",
        "tenant_name": "text",
        "subtype": "subtype",
        "renewal_fee": "amount",
    },
    "rental_invoice": {
        "amount": "amount",
        "period_month": "month",
        "invoice_date": "date",
    },
    "loan": {
        "subtype": "subtype",
        "interest_paid": "amount",
        "period_year": "year",
        "principal": "amount",
        "interest_rate": "amount",
        "lender": "text",
    },
    "tax": {
        "subtype": "subtype",
        "amount": "amount",
        "period_year": "year",
        "installment": "text",
    },
    "upkeep": {
        "amount": "amount",
        "service_date": "date",
        "description": "text",
    },
    "maintenance": {
        "amount": "amount",
        "period_start": "date",
        "period_end": "date",
        "description": "text",
    },
    "insurance": {
        "premium": "amount",
        "policy_start": "date",
        "policy_end": "date",
        "policy_number": "text",
    },
}

_SUBTYPES: Dict[str, set] = {
    "lease": {"new", "renewal"},
    "loan": {"agreement", "interest_statement"},
    "tax": {"assessment", "quit_rent", "parcel_rent"},
}

_FIELD_HINTS: Dict[str, str] = {
    "lease": (
        "- monthly_rent: monthly rent amount\n"
        "- deposit: security deposit amount\n"
        "- lease_start: tenancy start date\n"
        "- lease_end: tenancy end date\n"
        "- tenant_name: tenant full name\n"
        "- subtype: new | renewal\n"
        "- renewal_fee: fee charged for renewing the tenancy (renewals only)"
    ),
    "rental_invoice": (
        "- amount: rent billed for the month\n"
        "- period_month: the month being billed, as YYYY-MM\n"
        "- invoice_date: date the invoice was issued"
    ),
    "loan": (
        "- subtype: agreement | interest_statement\n"
        "- interest_paid: total loan interest paid in the statement year\n"
        "- period_year: the year the interest statement covers\n"
        "- principal: loan principal amount\n"
        "- interest_rate: annual interest rate (number only)\n"
        "- lender: bank or lender name"
    ),
    "tax": (
        "- subtype: assessment | quit_rent | parcel_rent "
        "(cukai pintu/taksiran = assessment, cukai tanah = quit_rent)\n"
        "- amount: amount payable on this bill\n"
        "- period_year: the year the bill covers\n"
        "- installment: installment description when the bill is one of several (e.g. 1/2)"
    ),
    "upkeep": (
        "- amount: amount paid for the repair or servicing\n"
        "- service_date: date of the service or invoice\n"
        "- description: short description of the work"
    ),
    "maintenance": (
        "- amount: management/maintenance charge amount (include sinking fund)\n"
        "- period_start: start of the period the charge covers\n"
        "- period_end: end of the period the charge covers\n"
        "- description: short description of the charge"
    ),
    "insurance": (
        "- premium: policy premium amount\n"
        "- policy_start: policy period start date\n"
        "- policy_end: policy period end date\n"
        "- policy_number: policy number"
    ),
}

_AMOUNT_STRIP = re.compile(r"[^0-9.\-]")
_SKIP_VALUES = {"", "none", "null", "unknown", "n/a", "na", "-"}


class FactExtractor:
    """Best-effort structured fact extraction at ingest.

    Mirrors CategoryPredictor's house pattern: constructor-injected llm,
    semicolon key=value response format, defensive parse. No keyword
    fallback — these figures feed tax computations, so "unknown" beats
    fabrication.
    """

    def __init__(self, llm):
        self._llm = llm

    def extract(self, category: str, text: str) -> Optional[Dict[str, Any]]:
        """Validated facts (plus a 'confidence' key when provided) or None.
        Never raises on LLM or parse trouble."""
        fields = _FIELD_TYPES.get(category)
        if not fields:
            return None
        cleaned = (text or "").strip()
        if not cleaned:
            return None

        try:
            prompt = self._build_prompt(category, cleaned[:MAX_INPUT_CHARS])
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()
        except Exception as e:
            print(f"⚠️ Fact extraction LLM call failed: {e}")
            return None

        facts = self._parse(category, fields, content)
        if not [key for key in facts if key != "confidence"]:
            return None
        return facts

    def _build_prompt(self, category: str, text: str) -> str:
        subtype_rule = ""
        if category in _SUBTYPES:
            subtype_rule = (
                "- subtype must be exactly one of: "
                f"{', '.join(sorted(_SUBTYPES[category]))}. Omit it when unclear.\n"
            )
        return f"""
You are extracting structured facts from a landlord's {category} document.

Document text (may be truncated):
{text}

Extract ONLY these fields:
{_FIELD_HINTS[category]}

Rules:
- Omit any field that is not clearly stated in the text. NEVER guess.
- Dates must be ISO format YYYY-MM-DD. period_month must be YYYY-MM. period_year must be a 4-digit year.
- Amounts must be plain numbers with no currency symbols or thousands separators.
{subtype_rule}- Always include confidence=<0.0-1.0> for the extraction overall.

Respond with ONLY one line of semicolon-separated key=value pairs, e.g.:
amount=460.63;period_year=2026;confidence=0.9
""".strip()

    def _parse(self, category: str, fields: Dict[str, str], content: str) -> Dict[str, Any]:
        facts: Dict[str, Any] = {}
        for part in content.split(";"):
            part = part.strip()
            if "=" not in part:
                continue
            key, raw = part.split("=", 1)
            key = key.strip().lower()
            raw = raw.strip()
            if raw.lower() in _SKIP_VALUES:
                continue
            if key == "confidence":
                try:
                    facts["confidence"] = max(0.0, min(1.0, float(raw)))
                except ValueError:
                    pass
                continue
            field_type = fields.get(key)
            if field_type is None:
                continue
            value = self._coerce(category, field_type, raw)
            if value is not None:
                facts[key] = value
        return facts

    @staticmethod
    def _coerce(category: str, field_type: str, raw: str) -> Optional[Any]:
        if field_type == "date":
            try:
                date.fromisoformat(raw)
                return raw
            except ValueError:
                return None
        if field_type == "month":
            try:
                date.fromisoformat(f"{raw}-01")
                return raw
            except ValueError:
                return None
        if field_type == "year":
            if raw.isdigit() and len(raw) == 4:
                return int(raw)
            return None
        if field_type == "amount":
            stripped = _AMOUNT_STRIP.sub("", raw)
            try:
                return float(stripped)
            except ValueError:
                return None
        if field_type == "subtype":
            candidate = raw.lower().replace(" ", "_")
            if candidate in _SUBTYPES.get(category, set()):
                return candidate
            return None
        return raw  # text
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `py -3.11 -m pytest tests/test_fact_extractor.py -q`
Expected: 10 PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/fact_extractor.py backend/tests/test_fact_extractor.py
git commit -m "feat: FactExtractor with per-category schemas and strict validation"
```

---

### Task 4: Wire extraction into ingest; API passthrough (backend)

**Files:**
- Modify: `backend/rag/documind_service.py` — imports, `__init__` (`:161` area), `ingest_document` (between chunk `batch.commit()` and metadata write), `list_documents` `DocumentInfo` construction
- Modify: `backend/models/documind_models.py` — `DocUploadResponse` (`:6-14`), `DocumentInfo` (`:118-129`)
- Modify: `backend/tests/test_documind_service_flows.py` — `_build_service` (`:352-360`), append test class
- Modify: `backend/tests/test_rex_routes_documind_docs_api.py` — extraction-field round-trip

**Interfaces:**
- Consumes: Task 3's `FactExtractor.extract` (returns dict incl. `"confidence"`, or `None`).
- Produces: `documind_docs` metadata fields `extracted_facts: dict | None`, `facts_confidence: float | None`, `facts_extracted_at: timestamp | None`; `DocUploadResponse.extracted_facts/facts_confidence`; `DocumentInfo.extracted_facts/facts_confidence`. Plan B's finance engine reads `extracted_facts` from these exact field names; Plan C parses them from JSON.

- [ ] **Step 1: Write the failing tests**

In `backend/tests/test_documind_service_flows.py`, add `from rag.fact_extractor import FactExtractor` to the imports, extend `_build_service` (this also future-proofs every existing ingest test):

```python
def _build_service(fake_db, fake_store, fake_graph, fake_llm):
    service = DocuMindService.__new__(DocuMindService)
    service._db = fake_db
    service._embeddings = _FakeEmbeddings()
    service._llm = fake_llm
    service._conversation_store = fake_store
    service._graph_orchestrator = fake_graph
    service._hybrid_retriever = _FakeHybridRetriever(fake_db)
    service._fact_extractor = FactExtractor(fake_llm)
    return service
```

then append:

```python
class FactExtractionIngestTests(unittest.IsolatedAsyncioTestCase):
    def _upload_file(self):
        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return b"%PDF-1.4 fake content"

        return _FakeUploadFile()

    def _patched_loader_page(self, text="Tenancy agreement: rent RM 1,500 monthly."):
        fake_page = MagicMock()
        fake_page.page_content = text
        fake_page.metadata = {"page": 0}
        return fake_page

    async def test_extraction_failure_never_blocks_ingest(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        class _RaisingExtractor:
            def extract(self, category, text):
                raise RuntimeError("extractor exploded")

        service._fact_extractor = _RaisingExtractor()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [self._patched_loader_page()]

            response = await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        self.assertEqual(response.status, "indexed")
        self.assertIsNone(response.extracted_facts)
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertIsNone(stored["extracted_facts"])
        self.assertIsNone(stored["facts_confidence"])

    async def test_successful_extraction_lands_in_metadata_and_response(self):
        fake_db = _FakeDB()
        fake_llm = _FakeLLM("monthly_rent=1500;lease_start=2025-09-01;lease_end=2026-09-01;confidence=0.9")
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), fake_llm
        )
        service._storage_bucket = _FakeStorageBucket()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [self._patched_loader_page()]

            response = await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        expected_facts = {
            "monthly_rent": 1500.0,
            "lease_start": "2025-09-01",
            "lease_end": "2026-09-01",
        }
        self.assertEqual(response.extracted_facts, expected_facts)
        self.assertEqual(response.facts_confidence, 0.9)
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored["extracted_facts"], expected_facts)
        self.assertEqual(stored["facts_confidence"], 0.9)
        self.assertIsNotNone(stored["facts_extracted_at"])

    async def test_list_documents_passes_extraction_fields_through(self):
        fake_db = _FakeDB(docs=[
            {
                "doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
                "category": "tax", "filename": "quitrent.pdf", "chunks_indexed": 1,
                "file_size": 50, "uploaded_at": datetime(2026, 1, 1),
                "extracted_facts": {"amount": 460.63, "period_year": 2026, "subtype": "quit_rent"},
                "facts_confidence": 0.9,
            },
            {
                "doc_id": "d2", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "old.pdf", "chunks_indexed": 1,
                "file_size": 50, "uploaded_at": datetime(2025, 1, 1),
            },
        ])
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        response = await service.list_documents("l1", "p1")
        by_id = {d.doc_id: d for d in response.documents}
        self.assertEqual(by_id["d1"].extracted_facts["subtype"], "quit_rent")
        self.assertEqual(by_id["d1"].facts_confidence, 0.9)
        self.assertIsNone(by_id["d2"].extracted_facts)
        self.assertIsNone(by_id["d2"].facts_confidence)
```

In `backend/tests/test_rex_routes_documind_docs_api.py`, add to `test_documind_upload_returns_200_and_calls_service`'s `mocked_upload_response` construction the two new kwargs:

```python
            extracted_facts={"monthly_rent": 1500.0, "lease_end": "2026-09-01"},
            facts_confidence=0.9,
```

and after the existing assertions:

```python
        self.assertEqual(response.json()["extracted_facts"]["monthly_rent"], 1500.0)
        self.assertEqual(response.json()["facts_confidence"], 0.9)
```

(Also update that test's `category="warranty"` fixture values to `category="lease"` / `filename="lease.pdf"` if Task 1/2's retargeting has not already done so.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py tests/test_rex_routes_documind_docs_api.py -q`
Expected: new tests FAIL — `DocUploadResponse` has no field `extracted_facts` (pydantic error), metadata rows lack the keys.

- [ ] **Step 3: Implement**

In `backend/models/documind_models.py`:

```python
class DocUploadResponse(BaseModel):
    """Response after uploading a document"""
    doc_id: str
    landlord_id: str
    property_id: str
    category: str
    filename: str
    status: str  # "indexed"
    chunks_indexed: int
    extracted_facts: Optional[dict] = None
    facts_confidence: Optional[float] = None
```

`DocumentInfo` gains the same two fields after `unit_label`:

```python
    extracted_facts: Optional[dict] = None
    facts_confidence: Optional[float] = None
```

In `backend/rag/documind_service.py`:

**(a)** import: `from rag.fact_extractor import FactExtractor` (beside the `CategoryPredictor` import).

**(b)** `__init__`, directly after the `self._category_predictor = CategoryPredictor(...)` block:

```python
        self._fact_extractor = FactExtractor(self._llm)
```

**(c)** in `ingest_document`, between `batch.commit()` (and its print) and the Storage upload step:

```python
            # Fact extraction (best-effort, one LLM call over the leading
            # text). Failure must never block indexing.
            extracted_facts = None
            facts_confidence = None
            try:
                full_text = "\n".join(page.page_content or "" for page in pages)
                facts = self._fact_extractor.extract(category, full_text)
                if facts:
                    facts_confidence = facts.pop("confidence", None)
                    extracted_facts = facts or None
            except Exception as e:
                print(f"⚠️ Fact extraction failed (non-blocking): {e}")
```

**(d)** the metadata `doc_ref.set({...})` gains, after `'status': 'indexed',`:

```python
                'extracted_facts': extracted_facts,
                'facts_confidence': facts_confidence,
                'facts_extracted_at': firestore.SERVER_TIMESTAMP if extracted_facts else None,
```

**(e)** the returned `DocUploadResponse(...)` gains:

```python
                extracted_facts=extracted_facts,
                facts_confidence=facts_confidence,
```

**(f)** `list_documents`'s `DocumentInfo(...)` construction gains:

```python
                extracted_facts=data.get('extracted_facts'),
                facts_confidence=data.get('facts_confidence'),
```

- [ ] **Step 4: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: all PASS (older ingest tests keep passing because `_build_service` now injects a real `FactExtractor` over the test's fake LLM, whose non-parseable content yields `None` facts).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/documind_service.py backend/models/documind_models.py backend/tests/
git commit -m "feat: extract structured facts at ingest and pass through the docs API"
```

---

### Task 5: Gemini-native OCR fallback for scanned PDFs (backend)

**Files:**
- Create: `backend/rag/pdf_ocr.py`
- Modify: `backend/rag/documind_service.py` — imports, `__init__`, `ingest_document` (OCR gate after `pages = loader.load()`; zero-chunk tolerance)
- Create: `backend/tests/test_pdf_ocr.py`
- Modify: `backend/tests/test_documind_service_flows.py` — `_build_service` + append test class

**Interfaces:**
- Consumes: the raw `content` bytes already read in `ingest_document`, the shared injected `llm`.
- Produces: `PdfOcr(llm)` with `transcribe(pdf_bytes: bytes) -> list[str] | None` (per-page transcripts, `None` on any failure), constants `MAX_OCR_PAGES = 10` (in `pdf_ocr.py`), `OCR_TEXT_THRESHOLD = 200` (in `documind_service.py`). Behavior change: an ingest that ends with zero chunks **no longer raises** — it stores metadata with `chunks_indexed=0` (spec §Error handling: the document must still index so the completeness indicator can surface it).

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_pdf_ocr.py`:

```python
import io
import unittest

from pypdf import PdfWriter

from rag.pdf_ocr import MAX_OCR_PAGES, PdfOcr, _first_pages


class _LLMResponse:
    def __init__(self, content):
        self.content = content


class _FakeLLM:
    def __init__(self, content):
        self._content = content
        self.last_input = None

    def invoke(self, messages):
        self.last_input = messages
        return _LLMResponse(self._content)


class _RaisingLLM:
    def invoke(self, messages):
        raise RuntimeError("boom")


def _blank_pdf(num_pages: int) -> bytes:
    writer = PdfWriter()
    for _ in range(num_pages):
        writer.add_blank_page(width=595, height=842)
    buffer = io.BytesIO()
    writer.write(buffer)
    return buffer.getvalue()


class PdfOcrTests(unittest.TestCase):
    def test_transcribe_splits_pages_on_delimiter(self):
        llm = _FakeLLM("First page text\n===PAGE===\nSecond page text")
        pages = PdfOcr(llm).transcribe(_blank_pdf(2))
        self.assertEqual(pages, ["First page text", "Second page text"])

    def test_transcribe_single_block_returns_one_page(self):
        llm = _FakeLLM("All the text on one page")
        self.assertEqual(PdfOcr(llm).transcribe(_blank_pdf(1)), ["All the text on one page"])

    def test_empty_response_and_exception_return_none(self):
        self.assertIsNone(PdfOcr(_FakeLLM("")).transcribe(_blank_pdf(1)))
        self.assertIsNone(PdfOcr(_RaisingLLM()).transcribe(_blank_pdf(1)))

    def test_first_pages_caps_at_max(self):
        from pypdf import PdfReader

        sliced = _first_pages(_blank_pdf(15), MAX_OCR_PAGES)
        self.assertEqual(len(PdfReader(io.BytesIO(sliced)).pages), MAX_OCR_PAGES)
        untouched = _blank_pdf(3)
        self.assertEqual(_first_pages(untouched, MAX_OCR_PAGES), untouched)

    def test_first_pages_garbage_bytes_fall_back_to_original(self):
        garbage = b"not a pdf at all"
        self.assertEqual(_first_pages(garbage, MAX_OCR_PAGES), garbage)
```

Append to `backend/tests/test_documind_service_flows.py` a fake OCR helper class (place it beside `_FakeHybridRetriever`) and wire it in `_build_service`:

```python
class _FakePdfOcr:
    """Stands in for PdfOcr: returns canned transcripts (None = OCR failed
    or produced nothing) and counts invocations."""

    def __init__(self, transcripts=None):
        self.transcripts = transcripts
        self.calls = 0

    def transcribe(self, pdf_bytes):
        self.calls += 1
        return self.transcripts
```

In `_build_service`, after the `_fact_extractor` line:

```python
    service._pdf_ocr = _FakePdfOcr()
```

Then append the test class:

```python
class OcrIngestTests(unittest.IsolatedAsyncioTestCase):
    def _upload_file(self):
        class _FakeUploadFile:
            filename = "scanned.pdf"

            async def read(self):
                return b"%PDF-1.4 fake scanned content"

        return _FakeUploadFile()

    def _page(self, text):
        fake_page = MagicMock()
        fake_page.page_content = text
        fake_page.metadata = {"page": 0}
        return fake_page

    async def _ingest(self, service, pages):
        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = pages
            return await service.ingest_document(
                landlord_id="l1", property_id="p1", category="upkeep", file=self._upload_file(),
            )

    async def test_scanned_pdf_triggers_ocr_and_indexes_transcript(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()
        service._pdf_ocr = _FakePdfOcr(transcripts=[
            "INVOIS: Servis penyaman udara RM 180, 12 Mac 2026",
        ])

        response = await self._ingest(service, [self._page("")])

        self.assertEqual(service._pdf_ocr.calls, 1)
        self.assertGreater(response.chunks_indexed, 0)
        self.assertIn("penyaman udara", fake_db.chunks[0]["text"])

    async def test_digital_pdf_never_triggers_ocr(self):
        service = _build_service(
            _FakeDB(), _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        long_text = "This tenancy agreement is made between the landlord and tenant. " * 10
        await self._ingest(service, [self._page(long_text)])

        self.assertEqual(service._pdf_ocr.calls, 0)

    async def test_ocr_failure_still_indexes_with_zero_chunks(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()
        service._pdf_ocr = _FakePdfOcr(transcripts=None)

        response = await self._ingest(service, [self._page("")])

        self.assertEqual(response.status, "indexed")
        self.assertEqual(response.chunks_indexed, 0)
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored["chunks_indexed"], 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `py -3.11 -m pytest tests/test_pdf_ocr.py tests/test_documind_service_flows.py -q`
Expected: `test_pdf_ocr.py` fails on ImportError; `OcrIngestTests` fail (no OCR gate; zero-text ingest raises `ValueError("No chunks could be processed...")`).

- [ ] **Step 3: Implement**

Create `backend/rag/pdf_ocr.py`:

```python
from __future__ import annotations

import base64
import io
from typing import List, Optional

from langchain_core.messages import HumanMessage
from pypdf import PdfReader, PdfWriter

MAX_OCR_PAGES = 10
_PAGE_DELIMITER = "===PAGE==="


def _first_pages(pdf_bytes: bytes, max_pages: int) -> bytes:
    """First max_pages of the PDF, or the original bytes when it is already
    short enough — or when pypdf can't read it (the LLM may still cope)."""
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        if len(reader.pages) <= max_pages:
            return pdf_bytes
        writer = PdfWriter()
        for page in reader.pages[:max_pages]:
            writer.add_page(page)
        buffer = io.BytesIO()
        writer.write(buffer)
        return buffer.getvalue()
    except Exception:
        return pdf_bytes


class PdfOcr:
    """Gemini-native OCR fallback for scanned PDFs.

    The Gemini API reads PDF bytes directly (258 tokens/page) — no Tesseract
    or image-conversion dependency. Best-effort by contract: any failure
    returns None and the caller continues with whatever text it has.
    """

    def __init__(self, llm):
        self._llm = llm

    def transcribe(self, pdf_bytes: bytes) -> Optional[List[str]]:
        try:
            payload = _first_pages(pdf_bytes, MAX_OCR_PAGES)
            prompt = (
                "Transcribe ALL text in this scanned document, page by page, "
                "top to bottom. Preserve amounts, dates, names and reference "
                "numbers exactly. Separate pages with a line containing only "
                f"{_PAGE_DELIMITER}. Output nothing but the transcription."
            )
            message = HumanMessage(content=[
                {"type": "text", "text": prompt},
                {
                    "type": "media",
                    "mime_type": "application/pdf",
                    "data": base64.b64encode(payload).decode("ascii"),
                },
            ])
            response = self._llm.invoke([message])
            content = str(response.content).strip()
            if not content:
                return None
            pages = [part.strip() for part in content.split(_PAGE_DELIMITER)]
            pages = [part for part in pages if part]
            return pages or None
        except Exception as e:
            print(f"⚠️ OCR fallback failed (non-blocking): {e}")
            return None
```

In `backend/rag/documind_service.py`:

**(a)** imports:

```python
from langchain_core.documents import Document
from rag.pdf_ocr import PdfOcr
```

**(b)** module constant beside `EMBED_DIM`:

```python
OCR_TEXT_THRESHOLD = 200  # chars; below this a PDF is treated as scanned
```

**(c)** `__init__`, after the `_fact_extractor` line:

```python
        self._pdf_ocr = PdfOcr(self._llm)
```

**(d)** in `ingest_document`, directly after `pages = loader.load()`:

```python
            # OCR fallback: a scanned PDF yields (near-)empty text. Send the
            # PDF bytes to Gemini for transcription so the document becomes
            # searchable and extractable. Best-effort — on failure we continue
            # with whatever text exists (possibly none).
            total_text = sum(len((page.page_content or "").strip()) for page in pages)
            if total_text < OCR_TEXT_THRESHOLD:
                transcripts = self._pdf_ocr.transcribe(content)
                if transcripts:
                    pages = [
                        Document(page_content=text, metadata={"page": index})
                        for index, text in enumerate(transcripts)
                    ]
                    print(f"🔍 OCR fallback transcribed {len(pages)} page(s)")
```

**(e)** replace the zero-chunk guard (`if len(chunk_documents) == 0: raise ValueError(...)`) with:

```python
            if len(chunk_documents) == 0:
                # Scanned document whose OCR fallback also produced nothing:
                # keep the document (Storage + metadata, 0 chunks) so it still
                # lists and can be re-uploaded; there is just nothing to search.
                print("⚠️ No text extracted; indexing metadata with 0 chunks")
```

(The batch write over an empty list is a no-op; the metadata write and Storage upload proceed unchanged.)

- [ ] **Step 4: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: all PASS. Existing ingest tests keep passing because `_build_service` injects `_FakePdfOcr()` (transcripts `None` → original text kept) even though their short fixture text is below the 200-char threshold.

- [ ] **Step 5: Manual smoke test (optional but recommended)**

Restart the backend (no hot reload), upload a scanned PDF through `POST /api/rex/documind/upload`, and confirm the log shows `🔍 OCR fallback transcribed N page(s)` and the doc gains chunks + facts.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/pdf_ocr.py backend/rag/documind_service.py backend/tests/
git commit -m "feat: Gemini-native OCR fallback for scanned PDFs at ingest"
```

---

### Task 6: Flutter — 7-category taxonomy, extracted facts on the model, fact-confirming snackbar

**Files:**
- Modify: `residex_app/lib/core/theme/app_colors.dart:20-25`
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart:45-52` (picker list), `:1696-1731` (label/icon/color maps), `:1102-1121` (upload result + snackbar)
- Modify: `residex_app/lib/features/landlord/domain/usecases/upload_document.dart:25`
- Modify: `residex_app/lib/features/landlord/domain/entities/documind_document.dart` (entity fields)
- Modify: `residex_app/lib/features/landlord/data/models/documind_models.dart` (parse/serialize/toEntity)
- Create: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_upload_summary.dart`
- Create: `residex_app/test/features/landlord/documind_upload_summary_test.dart`
- Create: `residex_app/test/features/landlord/documind_document_model_facts_test.dart`

**Interfaces:**
- Consumes: backend fields `extracted_facts` (JSON object) and `facts_confidence` (number) on upload and list responses (Task 4).
- Produces: `DocuMindDocument.extractedFacts: Map<String, dynamic>?` and `.factsConfidence: double?`; pure function `String? uploadFactSummary(String category, Map<String, dynamic>? facts)`. Plan C's expiry tile and Finance-tab completeness read `extractedFacts` through this entity.

- [ ] **Step 1: Write the failing Dart tests**

Create `residex_app/test/features/landlord/documind_upload_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_upload_summary.dart';

void main() {
  test('tax facts produce subtype + amount + year line', () {
    expect(
      uploadFactSummary('tax', {'subtype': 'quit_rent', 'amount': 460.63, 'period_year': 2026}),
      'Quit rent recorded — RM 460.63, 2026',
    );
  });

  test('lease facts produce rent + end date line', () {
    expect(
      uploadFactSummary('lease', {'monthly_rent': 1500.0, 'lease_end': '2026-09-01'}),
      'Lease recorded — RM 1500.00/mo, ends 2026-09-01',
    );
  });

  test('rental invoice facts produce amount + month line', () {
    expect(
      uploadFactSummary('rental_invoice', {'amount': 1200.0, 'period_month': '2026-07'}),
      'Rent invoice recorded — RM 1200.00 for 2026-07',
    );
  });

  test('null or empty facts return null so caller falls back', () {
    expect(uploadFactSummary('lease', null), isNull);
    expect(uploadFactSummary('lease', const {}), isNull);
  });

  test('facts without a summarizable field return null', () {
    expect(uploadFactSummary('upkeep', const {'description': 'aircon'}), isNull);
  });
}
```

Create `residex_app/test/features/landlord/documind_document_model_facts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/documind_models.dart';

void main() {
  test('fromJson parses extracted facts and confidence', () {
    final model = DocuMindDocumentModel.fromJson(const {
      'doc_id': 'd1',
      'landlord_id': 'l1',
      'property_id': 'p1',
      'category': 'tax',
      'filename': 'quitrent.pdf',
      'chunks_indexed': 1,
      'uploaded_at': '2026-07-16T10:00:00Z',
      'extracted_facts': {'amount': 460.63, 'period_year': 2026},
      'facts_confidence': 0.9,
    });
    expect(model.extractedFacts!['amount'], 460.63);
    expect(model.factsConfidence, 0.9);
    expect(model.toEntity().extractedFacts!['period_year'], 2026);
  });

  test('fromJson without extraction fields yields nulls', () {
    final model = DocuMindDocumentModel.fromJson(const {
      'doc_id': 'd2',
      'landlord_id': 'l1',
      'property_id': 'p1',
      'category': 'lease',
      'filename': 'lease.pdf',
      'chunks_indexed': 3,
      'uploaded_at': '2026-07-16T10:00:00Z',
    });
    expect(model.extractedFacts, isNull);
    expect(model.factsConfidence, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `residex_app/`: `flutter test test/features/landlord/documind_upload_summary_test.dart test/features/landlord/documind_document_model_facts_test.dart`
Expected: compile errors — `documind_upload_summary.dart` missing, `extractedFacts` undefined.

- [ ] **Step 3: Implement entity + model fields**

`residex_app/lib/features/landlord/domain/entities/documind_document.dart` — add to `DocuMindDocument` after `unitLabel`:

```dart
  /// Structured facts captured by backend fact extraction at ingest;
  /// null when extraction produced nothing.
  final Map<String, dynamic>? extractedFacts;

  /// Extractor's self-reported confidence (0.0-1.0).
  final double? factsConfidence;
```

and to the constructor: `this.extractedFacts,` / `this.factsConfidence,`.

`residex_app/lib/features/landlord/data/models/documind_models.dart` — `DocuMindDocumentModel`:
- constructor: add `super.extractedFacts,` and `super.factsConfidence,`
- `fromFirestore`: add

```dart
      extractedFacts: (data['extracted_facts'] as Map<String, dynamic>?),
      factsConfidence: (data['facts_confidence'] as num?)?.toDouble(),
```

- `fromJson`: add

```dart
      extractedFacts: (json['extracted_facts'] as Map<String, dynamic>?),
      factsConfidence: (json['facts_confidence'] as num?)?.toDouble(),
```

- `toJson`: add `'extracted_facts': extractedFacts,` and `'facts_confidence': factsConfidence,`
- `toEntity`: add `extractedFacts: extractedFacts,` and `factsConfidence: factsConfidence,`

- [ ] **Step 4: Implement the summary helper**

Create `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_upload_summary.dart`:

```dart
/// Pure helper: builds the upload confirmation line from extracted facts.
/// Returns null when nothing is worth confirming — the caller falls back to
/// the generic success message. No emoji (app convention).
String? uploadFactSummary(String category, Map<String, dynamic>? facts) {
  if (facts == null || facts.isEmpty) return null;

  String? money(dynamic value) =>
      value is num ? 'RM ${value.toStringAsFixed(2)}' : null;

  switch (category) {
    case 'lease':
      final end = facts['lease_end'];
      final rent = money(facts['monthly_rent']);
      if (rent != null && end is String) return 'Lease recorded — $rent/mo, ends $end';
      if (end is String) return 'Lease recorded — ends $end';
      if (rent != null) return 'Lease recorded — $rent/mo';
      return null;
    case 'rental_invoice':
      final amount = money(facts['amount']);
      final month = facts['period_month'];
      if (amount != null && month is String) {
        return 'Rent invoice recorded — $amount for $month';
      }
      return amount != null ? 'Rent invoice recorded — $amount' : null;
    case 'loan':
      final interest = money(facts['interest_paid']);
      final year = facts['period_year'];
      if (interest != null && year is int) return 'Loan interest recorded — $interest, $year';
      return interest != null ? 'Loan interest recorded — $interest' : null;
    case 'tax':
      final amount = money(facts['amount']);
      final year = facts['period_year'];
      final subtype = switch (facts['subtype']) {
        'assessment' => 'Assessment tax',
        'quit_rent' => 'Quit rent',
        'parcel_rent' => 'Parcel rent',
        _ => 'Tax bill',
      };
      if (amount != null && year is int) return '$subtype recorded — $amount, $year';
      return amount != null ? '$subtype recorded — $amount' : null;
    case 'upkeep':
      final amount = money(facts['amount']);
      return amount != null ? 'Upkeep expense recorded — $amount' : null;
    case 'maintenance':
      final amount = money(facts['amount']);
      return amount != null ? 'Maintenance charge recorded — $amount' : null;
    case 'insurance':
      final end = facts['policy_end'];
      final premium = money(facts['premium']);
      if (premium != null && end is String) return 'Policy recorded — $premium, expires $end';
      if (end is String) return 'Policy recorded — expires $end';
      return premium != null ? 'Policy recorded — $premium' : null;
  }
  return null;
}
```

- [ ] **Step 5: Run the two Dart test files — expect PASS**

Run: `flutter test test/features/landlord/documind_upload_summary_test.dart test/features/landlord/documind_document_model_facts_test.dart`
Expected: 7 PASS.

- [ ] **Step 6: Switch the taxonomy in the UI**

`residex_app/lib/core/theme/app_colors.dart` — replace lines 20-25 with:

```dart
  static const Color catLease = registry; // deep green
  static const Color catInsurance = Color(0xFF8C3A32); // oxblood
  static const Color catLoan = Color(0xFF44519E); // indigo
  static const Color catTax = Color(0xFF365B6D); // steel blue
  static const Color catUpkeep = Color(0xFF96690F); // ochre
  static const Color catMaintenance = Color(0xFF4E6151); // sage
  static const Color catInvoice = Color(0xFF6E4A8C); // plum
  // Legacy tokens kept: non-category uses (property color cycling) reference them.
  static const Color catWarranty = Color(0xFF44519E); // indigo
  static const Color catUtility = Color(0xFF96690F); // ochre
  static const Color catReceipt = Color(0xFF6E4A8C); // plum
  static const Color catOther = slate;
```

`documind_screen.dart:45-52` — replace the picker list:

```dart
  // Document categories (backend-supported, financial-intelligence taxonomy)
  final List<String> _categories = [
    'lease',
    'insurance',
    'loan',
    'tax',
    'upkeep',
    'maintenance',
    'rental_invoice',
  ];
```

`documind_screen.dart:1696-1731` — replace the three maps:

```dart
  String _getCategoryLabel(String category) {
    final labels = {
      'lease': 'Tenancy Agreements',
      'insurance': 'Insurance Policies',
      'loan': 'Loans & Financing',
      'tax': 'Property Taxes',
      'upkeep': 'Upkeep & Repairs',
      'maintenance': 'Maintenance Fees',
      'rental_invoice': 'Rental Invoices',
      'other': 'Other Documents',
    };
    return labels[category] ?? category.toUpperCase();
  }

  Icon _getCategoryIcon(String category) {
    final iconMap = {
      'lease': Icons.description_outlined,
      'insurance': Icons.security_outlined,
      'loan': Icons.account_balance_outlined,
      'tax': Icons.account_balance_wallet_outlined,
      'upkeep': Icons.build_outlined,
      'maintenance': Icons.apartment_outlined,
      'rental_invoice': Icons.receipt_long_outlined,
      'other': Icons.folder_outlined,
    };

    return Icon(iconMap[category] ?? Icons.folder_outlined);
  }

  Color _getCategoryColor(String category) {
    final colorMap = {
      'lease': AppColors.catLease,
      'insurance': AppColors.catInsurance,
      'loan': AppColors.catLoan,
      'tax': AppColors.catTax,
      'upkeep': AppColors.catUpkeep,
      'maintenance': AppColors.catMaintenance,
      'rental_invoice': AppColors.catInvoice,
      'other': AppColors.catOther,
    };
    return colorMap[category] ?? AppColors.catOther;
  }
```

`upload_document.dart:25`:

```dart
    final validCategories = ['lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice'];
```

`documind_screen.dart:1102-1121` — capture the upload result and use the fact summary (add `import 'documind_upload_summary.dart';` at the top of the file):

```dart
        final uploaded = await uploadAction(
          propertyId: _selectedPropertyId!,
          category: category,
          file: File(selectedFile.path!),
          unitId: unitChoice.unit?.id,
          unitLabel: unitChoice.unit?.label,
        );

        // Complete progress
        setState(() => _uploadProgress = 1.0);

        // Wait a moment to show completion, then hide
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          _showSnackBar(
            uploadFactSummary(category, uploaded.extractedFacts) ??
                'Document uploaded successfully!',
          );
        }
```

- [ ] **Step 7: Run the full Flutter suite + analyzer**

Run from `residex_app/`: `flutter test` then `flutter analyze`
Expected: all tests PASS (29 baseline + 7 new = 36); analyze stays at 0 errors. If any existing test references the old category constants (e.g. `documind_upload_rules_test.dart` for `validCategories`), retarget it to the new list — do not weaken it.

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib residex_app/test
git commit -m "feat: 7-category taxonomy in app; extracted facts on document model with fact-confirming upload snackbar"
```

---

## Deliverable check (spec Plan A)

After Task 6: every upload is validated against the 7 new categories (legacy names normalized, never migrated), scanned PDFs OCR into searchable/extractable text, every document carries `extracted_facts` end-to-end (Firestore → API → Flutter entity), and the upload snackbar confirms captured facts ("Quit rent recorded — RM 460.63, 2026"). Backend restart required before manual verification.
