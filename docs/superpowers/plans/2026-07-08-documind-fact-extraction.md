# DocuMind Fact Extraction & Expiry Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** At ingest, extract category-specific structured facts (dates + amounts) from lease/warranty/insurance PDFs and surface them per unit and as an "Upcoming expiries" dashboard tile — turning the unit↔document link from a list filter into queryable knowledge.

**Architecture:** A new `FactExtractor` (backend, mirroring `CategoryPredictor`) makes one best-effort LLM call during `ingest_document` and writes `extracted_facts` onto the `documind_docs` metadata. The existing landlord-wide `list_documents` (no new endpoint) carries facts to Flutter, where a pure-Dart fold produces upcoming-expiry entries for a dashboard tile and `UnitsScreen` shows each unit's lease facts. Extraction is strictly best-effort: a failure never blocks or degrades ingestion.

**Tech Stack:** Python 3.11, FastAPI, pydantic v2, Firestore, pytest/unittest; Flutter 3 with Riverpod 2, IndexedStack shell tabs, flutter_test.

**Source spec:** `docs/superpowers/specs/2026-07-06-documind-fact-extraction-design.md` (supersedes the Phase 5 sketch in the unit-intelligence spec).

**Relationship to the unit-intelligence plan:** Independent — no ordering dependency either way. Where both touch the same file (`documind_screen.dart`, `documind_provider.dart`, `documind_models.dart`), this plan adds new members and does not conflict. `selectedDocumindUnitProvider` (used by the tile's tap-through) already exists today.

## Global Constraints

- Extraction is **best-effort**: any extractor error (LLM failure, empty text, garbage response) yields `extracted_facts = None`; the document is still fully indexed. This invariant is test-enforced.
- Only `lease`, `warranty`, `insurance` are extractable. `utility`, `receipt`, `other`, and any unknown category return `None` **without invoking the LLM**.
- Dates normalize to ISO `YYYY-MM-DD`, validated with `date.fromisoformat` (Python) / `DateTime.tryParse` (Dart); a non-conforming date is **dropped**, never guessed. Amounts parse as floats, stripping currency symbols/commas.
- All new fields are additive and optional (`extracted_facts`, `facts_confidence`, `facts_extracted_at` on metadata; `DocumentInfo.extracted_facts/facts_confidence`; `DocUploadResponse.extracted_facts`). Pre-feature docs have no field → `None` everywhere. No migration, no backfill.
- No new routes; no writes to the Flutter-owned `properties/{pid}/units/{uid}` subcollection; no OCR/parser changes; ingestion stays PDF-only.
- No emoji in user-facing UI copy — use icon glyphs + `AppColors` tokens (existing app convention). Empty expiry state hides the tile entirely (no "nothing expiring" noise).
- "Days remaining" is computed against the device's **local calendar date** (dates are timezone-free calendar dates).
- `flutter analyze` must stay at its 0-error baseline. Backend pytest is import-heavy (~1.5-3 min per invocation) — use timeouts ≥ 300 s, run from `backend/`.

## Extraction schemas (the contract every task shares)

| Category | Extracted fields | Expiry date field |
|---|---|---|
| `lease` | `monthly_rent`, `deposit`, `lease_start`, `lease_end`, `tenant_name?` | `lease_end` |
| `warranty` | `item`, `warranty_end` | `warranty_end` |
| `insurance` | `policy_end`, `premium?`, `policy_number?` | `policy_end` |

`confidence` (0.0-1.0) is always requested; the ingest hook stores it separately as `facts_confidence` and removes it from `extracted_facts`.

---

### Task 1: FactExtractor (backend, new)

New injected-LLM helper mirroring `CategoryPredictor`: constructor takes `llm`; one public method `extract(category, text) -> dict | None`. Fully testable with a fake LLM. No keyword fallback — there is no sane heuristic for a date, so "unknown" (None) beats fabrication.

**Files:**
- Create: `backend/rag/fact_extractor.py`
- Create: `backend/tests/test_fact_extractor.py`

**Interfaces:**
- Produces: `class FactExtractor` with `__init__(self, llm)` and `extract(self, category: str, text: str) -> dict | None`. On success the returned dict contains the parsed fields **plus** a `confidence: float` key (e.g. `{'lease_end': '2026-09-01', 'monthly_rent': 1500.0, 'confidence': 0.9}`). Returns `None` for non-extractable categories (without calling the LLM), empty/whitespace text, LLM exceptions, and parses that yield no real field. Task 2 constructs it as `FactExtractor(self._llm)` and pops `confidence`.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_fact_extractor.py`:

```python
import unittest

from rag.fact_extractor import FactExtractor


class _LLMResponse:
    def __init__(self, content: str):
        self.content = content


class _FakeLLM:
    def __init__(self, content: str = "", raise_error: bool = False):
        self._content = content
        self._raise = raise_error
        self.called = False

    def invoke(self, _prompt: str):
        self.called = True
        if self._raise:
            raise RuntimeError("LLM unavailable")
        return _LLMResponse(self._content)


class FactExtractorTests(unittest.TestCase):
    def test_well_formed_lease_response_parses_dict(self):
        llm = _FakeLLM("monthly_rent=RM1,500;deposit=3000;lease_start=2025-09-01;lease_end=2026-09-01;confidence=0.9")
        facts = FactExtractor(llm).extract("lease", "lease text")

        self.assertEqual(facts["lease_end"], "2026-09-01")
        self.assertEqual(facts["lease_start"], "2025-09-01")
        self.assertEqual(facts["monthly_rent"], 1500.0)
        self.assertEqual(facts["deposit"], 3000.0)
        self.assertEqual(facts["confidence"], 0.9)

    def test_partial_response_drops_malformed_date(self):
        # lease_end is not ISO -> dropped; monthly_rent still captured.
        llm = _FakeLLM("monthly_rent=1200;lease_end=next September;confidence=0.5")
        facts = FactExtractor(llm).extract("lease", "lease text")

        self.assertEqual(facts["monthly_rent"], 1200.0)
        self.assertNotIn("lease_end", facts)

    def test_non_iso_date_dropped_by_fromisoformat(self):
        llm = _FakeLLM("warranty_end=15/03/2027;item=Fridge;confidence=0.8")
        facts = FactExtractor(llm).extract("warranty", "warranty text")

        self.assertEqual(facts["item"], "Fridge")
        self.assertNotIn("warranty_end", facts)

    def test_garbage_response_returns_none(self):
        llm = _FakeLLM("I could not find any dates in this document.")
        self.assertIsNone(FactExtractor(llm).extract("lease", "lease text"))

    def test_empty_response_returns_none(self):
        self.assertIsNone(FactExtractor(_FakeLLM("")).extract("lease", "lease text"))

    def test_llm_exception_returns_none(self):
        self.assertIsNone(FactExtractor(_FakeLLM(raise_error=True)).extract("lease", "lease text"))

    def test_non_extractable_category_returns_none_without_calling_llm(self):
        llm = _FakeLLM("utility_end=2026-01-01;confidence=0.9")
        self.assertIsNone(FactExtractor(llm).extract("utility", "utility text"))
        self.assertFalse(llm.called)

    def test_empty_text_returns_none_without_calling_llm(self):
        llm = _FakeLLM("lease_end=2026-09-01;confidence=0.9")
        self.assertIsNone(FactExtractor(llm).extract("lease", "   "))
        self.assertFalse(llm.called)

    def test_confidence_only_response_returns_none(self):
        # No real fields parsed -> None (don't store a lone confidence).
        self.assertIsNone(FactExtractor(_FakeLLM("confidence=0.9")).extract("lease", "text"))

    def test_insurance_amount_strips_currency(self):
        llm = _FakeLLM("policy_end=2026-12-31;premium=$1,200.50;policy_number=AB-99;confidence=0.7")
        facts = FactExtractor(llm).extract("insurance", "policy text")

        self.assertEqual(facts["policy_end"], "2026-12-31")
        self.assertEqual(facts["premium"], 1200.50)
        self.assertEqual(facts["policy_number"], "AB-99")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_fact_extractor.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'rag.fact_extractor'`.

- [ ] **Step 3: Implement**

Create `backend/rag/fact_extractor.py`:

```python
from __future__ import annotations

import re
from datetime import date
from typing import List, Optional

# Fields the prompt requests per category. Only these categories are
# extractable; everything else returns None without touching the LLM.
_SCHEMAS = {
    "lease": ["monthly_rent", "deposit", "lease_start", "lease_end", "tenant_name"],
    "warranty": ["item", "warranty_end"],
    "insurance": ["policy_end", "premium", "policy_number"],
}
_EXAMPLES = {
    "lease": "monthly_rent=1500;deposit=3000;lease_start=2025-09-01;lease_end=2026-09-01;confidence=0.9",
    "warranty": "item=Refrigerator;warranty_end=2027-03-15;confidence=0.9",
    "insurance": "policy_end=2026-12-31;premium=1200;policy_number=ABC123;confidence=0.9",
}
_DATE_FIELDS = {"lease_start", "lease_end", "warranty_end", "policy_end"}
_AMOUNT_FIELDS = {"monthly_rent", "deposit", "premium"}
_MAX_CHARS = 8000


class FactExtractor:
    """Extracts category-specific structured facts from document text.

    Mirrors CategoryPredictor: constructor-injected llm, semicolon key=value
    response format, defensive parsing, no fabrication. Best-effort — any
    failure returns None. There is no keyword fallback: unlike category
    prediction, no heuristic can honestly infer a date, so admitting
    "unknown" beats guessing.
    """

    def __init__(self, llm):
        self._llm = llm

    def extract(self, category: str, text: str) -> Optional[dict]:
        schema = _SCHEMAS.get(category)
        if not schema or not (text or "").strip():
            return None
        try:
            response = self._llm.invoke(self._build_prompt(category, schema, text))
            return self._parse(str(response.content).strip(), schema)
        except Exception:
            return None

    def _build_prompt(self, category: str, schema: List[str], text: str) -> str:
        fields = ", ".join(schema)
        return f"""
You are extracting structured facts from a property {category} document.

Requested fields: {fields}

Respond with ONLY the fields you can find, in this exact format (semicolons
between fields, no prose), for example:
{_EXAMPLES[category]}

Rules:
- Dates MUST be ISO format YYYY-MM-DD. Omit any date you cannot express that way.
- Amounts are plain numbers, no currency symbols or thousands separators.
- Omit any field you cannot find in the text. Never guess.
- End with confidence=<0.0-1.0> reflecting how sure you are.

Document text:
{text[:_MAX_CHARS]}
""".strip()

    def _parse(self, content: str, schema: List[str]) -> Optional[dict]:
        facts: dict = {}
        for part in content.split(";"):
            if "=" not in part:
                continue
            raw_key, raw_value = part.split("=", 1)
            key = raw_key.strip().lower()
            value = raw_value.strip()
            if not value:
                continue
            if key == "confidence":
                amount = self._parse_amount(value)
                if amount is not None:
                    facts["confidence"] = max(0.0, min(1.0, amount))
                continue
            if key not in schema:
                continue
            if key in _DATE_FIELDS:
                iso = self._parse_iso_date(value)
                if iso is not None:
                    facts[key] = iso
            elif key in _AMOUNT_FIELDS:
                amount = self._parse_amount(value)
                if amount is not None:
                    facts[key] = amount
            else:
                facts[key] = value

        # A parse with only a confidence (or nothing) is not a real extraction.
        real_fields = [k for k in facts if k != "confidence"]
        if not real_fields:
            return None
        return facts

    @staticmethod
    def _parse_iso_date(value: str) -> Optional[str]:
        try:
            return date.fromisoformat(value).isoformat()
        except ValueError:
            return None

    @staticmethod
    def _parse_amount(value: str) -> Optional[float]:
        cleaned = re.sub(r"[^0-9.\-]", "", value)
        if cleaned in ("", "-", ".", "-.", "."):
            return None
        try:
            return float(cleaned)
        except ValueError:
            return None
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_fact_extractor.py -q`
Expected: PASS (10 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/fact_extractor.py backend/tests/test_fact_extractor.py
git commit -m "feat: add FactExtractor for category-specific document facts" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Ingest hook + DocUploadResponse.extracted_facts (backend)

Wire `FactExtractor` into `ingest_document` between the chunk batch-commit and the metadata write, wrapped so no exception escapes. Store three new metadata fields and echo the facts back in `DocUploadResponse`.

**Files:**
- Modify: `backend/rag/documind_service.py` (`__init__`, `ingest_document`)
- Modify: `backend/models/documind_models.py` (`DocUploadResponse`)
- Modify: `backend/tests/test_documind_service_flows.py` (harness + tests)

**Interfaces:**
- Consumes: `FactExtractor.extract` (Task 1).
- Produces: `DocUploadResponse` gains `extracted_facts: dict | None = None`. `documind_docs` metadata gains `extracted_facts`, `facts_confidence`, `facts_extracted_at`. `DocuMindService.__init__` sets `self._fact_extractor = FactExtractor(self._llm)`. `_build_service` sets `service._fact_extractor = _FakeFactExtractor()` (default no-op); tests override it.

- [ ] **Step 1: Add DocUploadResponse field**

In `backend/models/documind_models.py`, extend `DocUploadResponse`:

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
    extracted_facts: dict | None = None  # category facts captured at ingest (None = none found)
```

- [ ] **Step 2: Extend the test harness with a fake extractor**

In `backend/tests/test_documind_service_flows.py`, add near the other fakes:

```python
class _FakeFactExtractor:
    """Records the call and returns a preset result (or raises)."""

    def __init__(self, result=None, raise_error=False):
        self._result = result
        self._raise = raise_error
        self.calls = []

    def extract(self, category, text):
        self.calls.append({"category": category, "text": text})
        if self._raise:
            raise RuntimeError("extraction boom")
        return self._result
```

And in `_build_service`, add a default so ingest never hits a missing attribute:

```python
    service._fact_extractor = _FakeFactExtractor()
    return service
```

- [ ] **Step 3: Write the failing ingest tests**

Add to `DocuMindServiceStorageTests` in `backend/tests/test_documind_service_flows.py`:

```python
    async def test_ingest_stores_extracted_facts_and_confidence(self):
        fake_db = _FakeDB()
        fake_bucket = _FakeStorageBucket()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket
        service._fact_extractor = _FakeFactExtractor(
            result={"lease_end": "2026-09-01", "monthly_rent": 1500.0, "confidence": 0.9}
        )

        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return b"%PDF-1.4 fake"

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            fake_page = MagicMock()
            fake_page.page_content = "Tenancy ends 2026-09-01, rent RM1500."
            fake_page.metadata = {"page": 0}
            loader_mock.return_value.load.return_value = [fake_page]

            response = await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=_FakeUploadFile(),
            )

        # DocUploadResponse echoes the facts (confidence removed).
        self.assertEqual(response.extracted_facts, {"lease_end": "2026-09-01", "monthly_rent": 1500.0})
        # Metadata stores facts + confidence separately.
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored["extracted_facts"], {"lease_end": "2026-09-01", "monthly_rent": 1500.0})
        self.assertEqual(stored["facts_confidence"], 0.9)
        # The extractor saw the parsed page text.
        self.assertIn("Tenancy ends 2026-09-01", service._fact_extractor.calls[0]["text"])

    async def test_ingest_survives_extraction_failure(self):
        fake_db = _FakeDB()
        fake_bucket = _FakeStorageBucket()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket
        service._fact_extractor = _FakeFactExtractor(raise_error=True)

        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return b"%PDF-1.4 fake"

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            fake_page = MagicMock()
            fake_page.page_content = "Some lease text"
            fake_page.metadata = {"page": 0}
            loader_mock.return_value.load.return_value = [fake_page]

            response = await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=_FakeUploadFile(),
            )

        # Document is still fully indexed; facts are simply None.
        self.assertEqual(response.status, "indexed")
        self.assertIsNone(response.extracted_facts)
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertIsNone(stored["extracted_facts"])
        self.assertIsNone(stored["facts_confidence"])
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py::DocuMindServiceStorageTests -q`
Expected: FAIL — `response.extracted_facts` is unknown/None and `stored["extracted_facts"]` raises `KeyError` (metadata write doesn't set it yet).

- [ ] **Step 5: Wire the extractor into `__init__`**

In `backend/rag/documind_service.py`, add the import near the other `rag.` imports:

```python
from rag.fact_extractor import FactExtractor
```

In `DocuMindService.__init__`, after `self._category_predictor = CategoryPredictor(...)`:

```python
        self._fact_extractor = FactExtractor(self._llm)
```

- [ ] **Step 6: Capture full text and run extraction in `ingest_document`**

In `ingest_document`, right after `pages = loader.load()`:

```python
            # Concatenated text for best-effort fact extraction (bounded in
            # FactExtractor). Kept separate from chunking.
            full_text = "\n".join(getattr(page, "page_content", "") or "" for page in pages)
```

Then, between `batch.commit()` (chunk write) and the Storage upload / metadata write, add:

```python
            # Best-effort structured fact extraction — must never block ingest.
            extracted_facts = None
            facts_confidence = None
            try:
                extracted_facts = self._fact_extractor.extract(category, full_text)
            except Exception as e:
                print(f"⚠️ Fact extraction failed (non-blocking): {e}")
            if extracted_facts is not None:
                facts_confidence = extracted_facts.pop("confidence", None)
```

Extend the metadata `doc_ref.set({...})` with three fields (add before `'uploaded_at'`):

```python
                'extracted_facts': extracted_facts,
                'facts_confidence': facts_confidence,
                'facts_extracted_at': firestore.SERVER_TIMESTAMP if extracted_facts else None,
```

And extend the returned `DocUploadResponse(...)` with:

```python
                extracted_facts=extracted_facts,
```

- [ ] **Step 7: Run the flow suite**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -q`
Expected: PASS (all tests, including the pre-existing storage/ingest tests — the default `_FakeFactExtractor()` returns `None`, so `test_ingest_document_uploads_pdf_to_storage` still writes `extracted_facts: None`).

- [ ] **Step 8: Commit**

```bash
git add backend/rag/documind_service.py backend/models/documind_models.py backend/tests/test_documind_service_flows.py
git commit -m "feat: extract and store document facts at ingest (best-effort)" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: DocumentInfo facts passthrough (backend)

`list_documents` already supports landlord-wide queries (`property_id` optional) — the Flutter fold needs no new endpoint. Just carry the two facts fields through `DocumentInfo`.

**Files:**
- Modify: `backend/models/documind_models.py` (`DocumentInfo`)
- Modify: `backend/rag/documind_service.py` (`list_documents` mapping)
- Modify: `backend/tests/test_documind_service_flows.py` (extend the list test)
- Modify: `backend/tests/test_rex_routes_documind_docs_api.py` (extend)

**Interfaces:**
- Produces: `DocumentInfo` gains `extracted_facts: dict | None = None` and `facts_confidence: float | None = None`. `list_documents` reads both from the metadata document. Task 4's Flutter model parses `extracted_facts` / `facts_confidence`.

- [ ] **Step 1: Write the failing service test**

Add this test to `DocuMindServiceStorageTests` in `backend/tests/test_documind_service_flows.py`:

```python
    async def test_list_documents_passes_through_extracted_facts(self):
        fake_db = _FakeDB(docs=[
            {"doc_id": "doc-1", "landlord_id": "l1", "property_id": "p1",
             "category": "lease", "filename": "lease.pdf",
             "uploaded_at": datetime.now(), "chunks_indexed": 3,
             "extracted_facts": {"lease_end": "2026-09-01", "monthly_rent": 1500.0},
             "facts_confidence": 0.9},
            # Pre-feature doc: no facts keys at all -> None.
            {"doc_id": "doc-2", "landlord_id": "l1", "property_id": "p1",
             "category": "utility", "filename": "bill.pdf",
             "uploaded_at": datetime.now(), "chunks_indexed": 1},
        ])
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        response = await service.list_documents("l1", "p1")

        by_id = {doc.doc_id: doc for doc in response.documents}
        self.assertEqual(by_id["doc-1"].extracted_facts, {"lease_end": "2026-09-01", "monthly_rent": 1500.0})
        self.assertEqual(by_id["doc-1"].facts_confidence, 0.9)
        self.assertIsNone(by_id["doc-2"].extracted_facts)
        self.assertIsNone(by_id["doc-2"].facts_confidence)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py::DocuMindServiceStorageTests::test_list_documents_passes_through_extracted_facts -q`
Expected: FAIL — `DocumentInfo` has no `extracted_facts` attribute (pydantic rejects the kwarg / attribute access fails).

- [ ] **Step 3: Implement the model**

In `backend/models/documind_models.py`, extend `DocumentInfo`:

```python
class DocumentInfo(BaseModel):
    """Metadata for a single document"""
    doc_id: str
    landlord_id: str
    property_id: str
    category: str  # 'lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'
    filename: str
    uploaded_at: datetime
    chunks_indexed: int
    file_size: int | None = None  # In bytes
    unit_id: str | None = None  # None = property-wide document
    unit_label: str | None = None  # Denormalized label for display
    extracted_facts: dict | None = None  # category facts captured at ingest
    facts_confidence: float | None = None  # extractor confidence (0.0-1.0)
```

- [ ] **Step 4: Implement the passthrough**

In `backend/rag/documind_service.py`, in `list_documents`, extend the `DocumentInfo(...)` construction with:

```python
                extracted_facts=data.get('extracted_facts'),
                facts_confidence=data.get('facts_confidence'),
```

- [ ] **Step 5: Add the route round-trip test**

In `backend/tests/test_rex_routes_documind_docs_api.py`, add to `DocuMindDocumentsApiTests` (`DocumentInfo` is already imported):

```python
    def test_list_documents_serializes_extracted_facts(self):
        mocked_list_response = DocListResponse(
            documents=[
                DocumentInfo(
                    doc_id="doc-1",
                    landlord_id="landlord-1",
                    property_id="property-1",
                    category="lease",
                    filename="lease.pdf",
                    uploaded_at=datetime(2026, 3, 18, 12, 0, 0),
                    chunks_indexed=5,
                    extracted_facts={"lease_end": "2026-09-01", "monthly_rent": 1500.0},
                    facts_confidence=0.9,
                )
            ],
            total_count=1,
            filtered_by_property="property-1",
        )

        with patch("api.rex_routes.documind_service.list_documents", new=AsyncMock(return_value=mocked_list_response)):
            response = self.client.get(
                "/api/rex/documind/documents",
                params={"landlord_id": "landlord-1", "property_id": "property-1"},
            )

        self.assertEqual(response.status_code, 200)
        doc = response.json()["documents"][0]
        self.assertEqual(doc["extracted_facts"], {"lease_end": "2026-09-01", "monthly_rent": 1500.0})
        self.assertEqual(doc["facts_confidence"], 0.9)
```

- [ ] **Step 6: Run both backend suites**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py tests/test_rex_routes_documind_docs_api.py -q`
Expected: PASS (all tests).

- [ ] **Step 7: Commit**

```bash
git add backend/models/documind_models.py backend/rag/documind_service.py backend/tests/test_documind_service_flows.py backend/tests/test_rex_routes_documind_docs_api.py
git commit -m "feat: pass extracted facts through the documents list API" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Flutter model layer parses facts (Flutter)

`DocuMindDocument` entity + `DocuMindDocumentModel` parse the two new optional fields from both Firestore and the backend JSON. The upload success snackbar surfaces the captured end date when present.

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/documind_document.dart`
- Modify: `residex_app/lib/features/landlord/data/models/documind_models.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (`_uploadDocument` success snackbar)
- Test: `residex_app/test/features/landlord/documind_document_facts_test.dart` (create)

**Interfaces:**
- Consumes: backend JSON `extracted_facts` (Map) / `facts_confidence` (num) on each document and on the upload response (Tasks 2-3).
- Produces: `DocuMindDocument` and `DocuMindDocumentModel` gain `final Map<String, dynamic>? extractedFacts;` and `final double? factsConfidence;` (optional constructor params). Task 5's fold and Task 7's units line consume `extractedFacts`.

- [ ] **Step 1: Write the failing model test**

Create `residex_app/test/features/landlord/documind_document_facts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/documind_models.dart';

void main() {
  test('fromJson parses extracted_facts and facts_confidence', () {
    final model = DocuMindDocumentModel.fromJson({
      'doc_id': 'doc-1',
      'landlord_id': 'l1',
      'property_id': 'p1',
      'category': 'lease',
      'filename': 'lease.pdf',
      'chunks_indexed': 3,
      'uploaded_at': '2026-03-18T12:00:00.000',
      'extracted_facts': {'lease_end': '2026-09-01', 'monthly_rent': 1500.0},
      'facts_confidence': 0.9,
    });

    expect(model.extractedFacts?['lease_end'], '2026-09-01');
    expect(model.extractedFacts?['monthly_rent'], 1500.0);
    expect(model.factsConfidence, 0.9);
  });

  test('fromJson defaults facts to null for pre-feature docs', () {
    final model = DocuMindDocumentModel.fromJson({
      'doc_id': 'doc-2',
      'landlord_id': 'l1',
      'property_id': 'p1',
      'category': 'utility',
      'filename': 'bill.pdf',
      'chunks_indexed': 1,
      'uploaded_at': '2026-03-18T12:00:00.000',
    });

    expect(model.extractedFacts, isNull);
    expect(model.factsConfidence, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/documind_document_facts_test.dart`
Expected: FAIL — compile error, `extractedFacts` undefined.

- [ ] **Step 3: Implement the entity**

In `residex_app/lib/features/landlord/domain/entities/documind_document.dart`, extend `DocuMindDocument` with two fields and constructor params:

```dart
  /// Structured facts extracted at ingest (lease_end, monthly_rent, …).
  /// Null when nothing was extracted or the doc predates the feature.
  final Map<String, dynamic>? extractedFacts;

  /// Extractor confidence (0.0-1.0), null when no facts.
  final double? factsConfidence;
```

```dart
    this.extractedFacts,
    this.factsConfidence,
```

- [ ] **Step 4: Implement the model**

In `residex_app/lib/features/landlord/data/models/documind_models.dart`, extend `DocuMindDocumentModel` with the same two fields + constructor params `this.extractedFacts, this.factsConfidence`. Add helpers and parse in both factories:

```dart
  static Map<String, dynamic>? _parseFacts(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static double? _parseConfidence(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }
```

In `fromFirestore`, add:

```dart
      extractedFacts: _parseFacts(data['extracted_facts']),
      factsConfidence: _parseConfidence(data['facts_confidence']),
```

In `fromJson`, add:

```dart
      extractedFacts: _parseFacts(json['extracted_facts']),
      factsConfidence: _parseConfidence(json['facts_confidence']),
```

Add to `toJson()`:

```dart
      'extracted_facts': extractedFacts,
      'facts_confidence': factsConfidence,
```

And to `toEntity()`:

```dart
      extractedFacts: extractedFacts,
      factsConfidence: factsConfidence,
```

- [ ] **Step 5: Run the model test**

Run: `cd residex_app && flutter test test/features/landlord/documind_document_facts_test.dart`
Expected: PASS.

- [ ] **Step 6: Surface the captured date in the upload snackbar**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, `_uploadDocument`, capture the returned entity from `uploadAction` and enrich the success message. Replace the `await uploadAction(...)` call with:

```dart
        final uploaded = await uploadAction(
          propertyId: _selectedPropertyId!,
          category: category,
          file: File(selectedFile.path!),
          unitId: unitChoice.unit?.id,
          unitLabel: unitChoice.unit?.label,
        );
```

And replace the success `_showSnackBar('Document uploaded successfully!');` with:

```dart
          final endDate = uploaded.extractedFacts?['lease_end'] ??
              uploaded.extractedFacts?['warranty_end'] ??
              uploaded.extractedFacts?['policy_end'];
          _showSnackBar(endDate != null
              ? 'Document uploaded — expires $endDate'
              : 'Document uploaded successfully!');
```

- [ ] **Step 7: Run tests and analyzer**

Run: `cd residex_app && flutter test test/features/landlord/ && flutter analyze`
Expected: all tests PASS; analyze reports 0 errors.

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/documind_document.dart residex_app/lib/features/landlord/data/models/documind_models.dart "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart" residex_app/test/features/landlord/documind_document_facts_test.dart
git commit -m "feat: parse extracted document facts in Flutter model layer" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Upcoming-expiries fold + providers (Flutter)

A pure-Dart fold (unit-testable, no Riverpod) over a landlord-wide document list, plus the providers that feed the dashboard tile.

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/upcoming_expiries.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (two providers)
- Test: `residex_app/test/features/landlord/upcoming_expiries_test.dart` (create)

**Interfaces:**
- Consumes: `DocuMindDocument.extractedFacts/category/uploadedAt/propertyId/unitId/unitLabel` (Task 4); `listDocumentsUseCaseProvider`, `currentLandlordIdProvider` (existing).
- Produces: `class ExpiryEntry` (`docId, propertyId, unitId?, unitLabel?, category, filename, date`) with `int daysRemaining(DateTime now)`; top-level `List<ExpiryEntry> foldUpcomingExpiries(List<DocuMindDocument> docs, {required DateTime now, int windowDays = 90})`; `landlordDocumentsProvider` (FutureProvider<List<DocuMindDocument>>) and `upcomingExpiriesProvider` (FutureProvider<List<ExpiryEntry>>). Task 6 consumes `upcomingExpiriesProvider`.

- [ ] **Step 1: Write the failing fold test**

Create `residex_app/test/features/landlord/upcoming_expiries_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/screens/1-Dashboard/upcoming_expiries.dart';

DocuMindDocument _doc({
  required String docId,
  required String category,
  required String propertyId,
  String? unitId,
  String? unitLabel,
  required DateTime uploadedAt,
  Map<String, dynamic>? facts,
}) {
  return DocuMindDocument(
    docId: docId,
    landlordId: 'l1',
    propertyId: propertyId,
    category: category,
    filename: '$docId.pdf',
    chunksIndexed: 1,
    uploadedAt: uploadedAt,
    unitId: unitId,
    unitLabel: unitLabel,
    extractedFacts: facts,
  );
}

void main() {
  final now = DateTime(2026, 7, 8);

  test('includes lease/warranty/insurance within the 90-day window, soonest first', () {
    final docs = [
      _doc(docId: 'lease', category: 'lease', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1),
          facts: {'lease_end': '2026-09-01'}), // in 55 days
      _doc(docId: 'warranty', category: 'warranty', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1),
          facts: {'warranty_end': '2026-07-20'}), // in 12 days
      _doc(docId: 'insurance', category: 'insurance', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1),
          facts: {'policy_end': '2026-08-15'}), // in 38 days
    ];

    final entries = foldUpcomingExpiries(docs, now: now);

    expect(entries.map((e) => e.docId), ['warranty', 'insurance', 'lease']);
    expect(entries.first.daysRemaining(now), 12);
  });

  test('90-day boundary is inclusive, day 91 excluded', () {
    final docs = [
      _doc(docId: 'in', category: 'lease', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1),
          facts: {'lease_end': '2026-10-06'}), // exactly 90 days
      _doc(docId: 'out', category: 'lease', propertyId: 'p2',
          uploadedAt: DateTime(2026, 1, 1),
          facts: {'lease_end': '2026-10-07'}), // 91 days
    ];

    final entries = foldUpcomingExpiries(docs, now: now);

    expect(entries.map((e) => e.docId), ['in']);
  });

  test('excludes past dates and non-extractable categories', () {
    final docs = [
      _doc(docId: 'past', category: 'lease', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1), facts: {'lease_end': '2026-07-01'}),
      _doc(docId: 'utility', category: 'utility', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1), facts: {'lease_end': '2026-08-01'}),
      _doc(docId: 'nofacts', category: 'lease', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1), facts: null),
    ];

    expect(foldUpcomingExpiries(docs, now: now), isEmpty);
  });

  test('most recently uploaded doc wins per unit+category', () {
    final docs = [
      _doc(docId: 'old', category: 'lease', propertyId: 'p1', unitId: 'u1',
          uploadedAt: DateTime(2026, 1, 1), facts: {'lease_end': '2026-08-01'}),
      _doc(docId: 'new', category: 'lease', propertyId: 'p1', unitId: 'u1',
          uploadedAt: DateTime(2026, 6, 1), facts: {'lease_end': '2026-09-15'}),
    ];

    final entries = foldUpcomingExpiries(docs, now: now);

    expect(entries.length, 1);
    expect(entries.single.docId, 'new');
  });

  test('skips malformed dates without crashing', () {
    final docs = [
      _doc(docId: 'bad', category: 'lease', propertyId: 'p1',
          uploadedAt: DateTime(2026, 1, 1), facts: {'lease_end': 'next September'}),
    ];

    expect(foldUpcomingExpiries(docs, now: now), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/upcoming_expiries_test.dart`
Expected: FAIL — the imported file doesn't exist.

- [ ] **Step 3: Implement the fold**

Create `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/upcoming_expiries.dart`:

```dart
import '../../../domain/entities/documind_document.dart';

/// The expiry date field name for each extractable category.
const Map<String, String> _expiryFieldByCategory = {
  'lease': 'lease_end',
  'warranty': 'warranty_end',
  'insurance': 'policy_end',
};

/// One upcoming expiry surfaced on the dashboard.
class ExpiryEntry {
  final String docId;
  final String propertyId;
  final String? unitId;
  final String? unitLabel;
  final String category; // lease | warranty | insurance
  final String filename;
  final DateTime date; // calendar date (no time component)

  const ExpiryEntry({
    required this.docId,
    required this.propertyId,
    this.unitId,
    this.unitLabel,
    required this.category,
    required this.filename,
    required this.date,
  });

  /// Whole calendar days from `now` to the expiry date (negative if past).
  int daysRemaining(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return date.difference(today).inDays;
  }
}

/// Fold a landlord-wide document list into sorted (soonest-first) expiry
/// entries within the next [windowDays] days. Pure — no Riverpod, no I/O.
///
/// Rules (see fact-extraction spec §Flutter surfacing):
/// - Only lease/warranty/insurance with a valid expiry date count.
/// - Per (property, unit, category) only the most recently uploaded doc wins
///   (a re-uploaded lease supersedes the old one's dates).
/// - Past dates and dates beyond the window are excluded; malformed dates are
///   skipped, never thrown.
List<ExpiryEntry> foldUpcomingExpiries(
  List<DocuMindDocument> docs, {
  required DateTime now,
  int windowDays = 90,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(Duration(days: windowDays));

  // Most recently uploaded doc per (property, unit, category).
  final Map<String, DocuMindDocument> latest = {};
  for (final doc in docs) {
    final field = _expiryFieldByCategory[doc.category];
    if (field == null) continue;
    if (doc.extractedFacts == null || doc.extractedFacts![field] == null) continue;
    final key = '${doc.propertyId}|${doc.unitId ?? ''}|${doc.category}';
    final existing = latest[key];
    if (existing == null || doc.uploadedAt.isAfter(existing.uploadedAt)) {
      latest[key] = doc;
    }
  }

  final entries = <ExpiryEntry>[];
  for (final doc in latest.values) {
    final field = _expiryFieldByCategory[doc.category]!;
    final parsed = DateTime.tryParse(doc.extractedFacts![field].toString());
    if (parsed == null) continue;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    if (day.isBefore(today) || day.isAfter(horizon)) continue;
    entries.add(ExpiryEntry(
      docId: doc.docId,
      propertyId: doc.propertyId,
      unitId: doc.unitId,
      unitLabel: doc.unitLabel,
      category: doc.category,
      filename: doc.filename,
      date: day,
    ));
  }

  entries.sort((a, b) => a.date.compareTo(b.date));
  return entries;
}
```

- [ ] **Step 4: Run the fold test**

Run: `cd residex_app && flutter test test/features/landlord/upcoming_expiries_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the providers**

In `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`, add the import at the top:

```dart
import '../screens/1-Dashboard/upcoming_expiries.dart';
```

Add after `documindDocumentsProvider`:

```dart
/// All of a landlord's documents across every property (no property/unit
/// filter) — the source for the portfolio-wide expiry fold.
final landlordDocumentsProvider =
    FutureProvider<List<DocuMindDocument>>((ref) async {
  final landlordId = ref.watch(currentLandlordIdProvider);
  final useCase = ref.watch(listDocumentsUseCaseProvider);
  return useCase(landlordId: landlordId);
});

/// Upcoming lease/warranty/insurance expiries within the next 90 days,
/// soonest first, folded from the landlord-wide document list.
final upcomingExpiriesProvider =
    FutureProvider<List<ExpiryEntry>>((ref) async {
  final docs = await ref.watch(landlordDocumentsProvider.future);
  return foldUpcomingExpiries(docs, now: DateTime.now());
});
```

- [ ] **Step 6: Run analyzer + full landlord suite**

Run: `cd residex_app && flutter analyze && flutter test test/features/landlord/`
Expected: 0 analyzer errors; all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add "residex_app/lib/features/landlord/presentation/screens/1-Dashboard/upcoming_expiries.dart" residex_app/lib/features/landlord/presentation/providers/documind_provider.dart residex_app/test/features/landlord/upcoming_expiries_test.dart
git commit -m "feat: fold landlord documents into upcoming-expiry entries" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Dashboard "Upcoming expiries" tile + tap-through (Flutter)

Insert an expiries card after the stat-tile row, styled like the existing glass cards. Tapping an entry switches to the DocuMind tab with that property selected and (when unit-scoped) the unit filter preset. Cross-tab navigation uses a small shared target provider that `DocuMindScreen` consumes.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (nav target provider)
- Modify: `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart` (tile + tap)
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (consume nav target)

**Interfaces:**
- Consumes: `upcomingExpiriesProvider` (Task 5); `selectedDocumindUnitProvider`, `unitsForPropertyStreamProvider` (existing); `onOpenDocumind` (existing dashboard callback that switches to the DocuMind tab).
- Produces: `class DocumindNavTarget { final String propertyId; final String? unitId; }` and `documindNavTargetProvider` (`NotifierProvider<…, DocumindNavTarget?>` with `request(...)` / `consume()`), added to `documind_provider.dart`. `DocuMindScreen` reads and consumes the target on build.

- [ ] **Step 1: Add the nav-target provider**

In `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`, add:

```dart
/// A requested DocuMind navigation target (set by the dashboard expiry tile,
/// consumed once by DocuMindScreen). Enables cross-tab navigation in the
/// IndexedStack shell without a router.
class DocumindNavTarget {
  final String propertyId;
  final String? unitId;

  const DocumindNavTarget({required this.propertyId, this.unitId});
}

class DocumindNavTargetNotifier extends Notifier<DocumindNavTarget?> {
  @override
  DocumindNavTarget? build() => null;

  void request(DocumindNavTarget target) => state = target;

  /// Read-and-clear: returns the pending target (if any) and resets to null.
  DocumindNavTarget? consume() {
    final current = state;
    state = null;
    return current;
  }
}

final documindNavTargetProvider =
    NotifierProvider<DocumindNavTargetNotifier, DocumindNavTarget?>(
  DocumindNavTargetNotifier.new,
);
```

- [ ] **Step 2: Build the tile and wire the tap in the dashboard**

In `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart`, add imports (the fold file is in this same `1-Dashboard/` folder, so use a bare relative import):

```dart
import '../../providers/documind_provider.dart';
import 'upcoming_expiries.dart';
```

Insert the tile in `_buildContent`, right after `_buildStatTileRow(stats)` and its trailing `SizedBox`:

```dart
            _buildUpcomingExpiriesTile(context, ref),
```

Add the builder methods to the class (all receive `ref`, which `_buildContent` already has):

```dart
  Widget _buildUpcomingExpiriesTile(BuildContext context, WidgetRef ref) {
    final expiriesAsync = ref.watch(upcomingExpiriesProvider);
    final entries = expiriesAsync.value ?? const <ExpiryEntry>[];
    // Hide entirely while loading, on error, or when nothing is expiring.
    if (entries.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final shown = entries.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 16, color: AppColors.registry),
                const SizedBox(width: 8),
                Text(
                  'UPCOMING EXPIRIES',
                  style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...shown.map((entry) => _buildExpiryRow(context, ref, entry, now)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryRow(
      BuildContext context, WidgetRef ref, ExpiryEntry entry, DateTime now) {
    final days = entry.daysRemaining(now);
    final urgencyColor = days <= 30
        ? AppColors.error
        : (days <= 60 ? AppColors.catUtility : AppColors.textMuted);
    final scopeLabel = entry.unitLabel ?? 'Property-wide';
    final kindLabel = _expiryKindLabel(entry.category);

    return InkWell(
      onTap: () {
        ref.read(documindNavTargetProvider.notifier).request(
              DocumindNavTarget(
                  propertyId: entry.propertyId, unitId: entry.unitId),
            );
        onOpenDocumind();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: urgencyColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$scopeLabel · $kindLabel ${_formatExpiryDate(entry.date)}',
                style: AppTextStyles.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              days == 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}',
              style: AppTextStyles.bodySmall.copyWith(color: urgencyColor),
            ),
          ],
        ),
      ),
    );
  }

  String _expiryKindLabel(String category) {
    switch (category) {
      case 'lease':
        return 'Lease ends';
      case 'warranty':
        return 'Warranty ends';
      case 'insurance':
        return 'Policy ends';
      default:
        return 'Expires';
    }
  }

  String _formatExpiryDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
```

- [ ] **Step 3: Consume the nav target in DocuMindScreen**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, at the very top of `build` (before `final propertiesAsync = ...`), add a listener that applies a pending target once:

```dart
    // A dashboard expiry tap may request a specific property/unit. Apply it
    // once when it arrives, then clear it.
    ref.listen(documindNavTargetProvider, (previous, next) {
      if (next == null) return;
      final target = ref.read(documindNavTargetProvider.notifier).consume();
      if (target == null) return;
      setState(() {
        _selectedPropertyId = target.propertyId;
        _selectedCategory = null;
        _showChatInterface = true;
      });
      if (target.unitId != null) {
        final units = ref
                .read(unitsForPropertyStreamProvider(target.propertyId))
                .value ??
            const <Unit>[];
        for (final unit in units) {
          if (unit.id == target.unitId) {
            ref.read(selectedDocumindUnitProvider.notifier).select(unit);
            break;
          }
        }
      } else {
        ref.read(selectedDocumindUnitProvider.notifier).select(null);
      }
    });
```

`documind_provider.dart` is already imported in this screen — confirm `documindNavTargetProvider` resolves; the `Unit` type and `unitsForPropertyStreamProvider` imports are already present from the unit filter row.

- [ ] **Step 4: Run analyzer and the landlord suite**

Run: `cd residex_app && flutter analyze && flutter test test/features/landlord/`
Expected: 0 analyzer errors; all tests PASS (existing DocuMind widget tests never set `documindNavTargetProvider`, so the listener no-ops).

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/providers/documind_provider.dart "residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart" "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart"
git commit -m "feat: add upcoming-expiries dashboard tile with tap-through to Documind" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: UnitsScreen lease-facts line (Flutter)

Each unit row that has a most-recent lease document with facts shows a secondary line (`Lease ends 2026-09-01 · RM 1,500/mo`). Units without facts render exactly as today.

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/unit_lease_facts.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart`
- Test: `residex_app/test/features/landlord/unit_lease_facts_test.dart` (create)

**Interfaces:**
- Consumes: `DocuMindDocument` (Task 4); `documindDocumentsProvider(propertyId)` (existing).
- Produces: top-level `Map<String, String> unitLeaseFactLines(List<DocuMindDocument> docs)` mapping `unitId -> display line` (only units whose most-recent `lease` doc has a `lease_end`), and `String? formatLeaseFactLine(DocuMindDocument doc)`.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/unit_lease_facts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/screens/4-Portfolio/unit_lease_facts.dart';

DocuMindDocument _lease({
  required String docId,
  required String unitId,
  required DateTime uploadedAt,
  Map<String, dynamic>? facts,
}) {
  return DocuMindDocument(
    docId: docId,
    landlordId: 'l1',
    propertyId: 'p1',
    category: 'lease',
    filename: '$docId.pdf',
    chunksIndexed: 1,
    uploadedAt: uploadedAt,
    unitId: unitId,
    extractedFacts: facts,
  );
}

void main() {
  test('builds a line per unit from its most-recent lease doc', () {
    final docs = [
      _lease(docId: 'old', unitId: 'u1', uploadedAt: DateTime(2026, 1, 1),
          facts: {'lease_end': '2026-08-01', 'monthly_rent': 1000.0}),
      _lease(docId: 'new', unitId: 'u1', uploadedAt: DateTime(2026, 6, 1),
          facts: {'lease_end': '2026-09-01', 'monthly_rent': 1500.0}),
    ];

    final lines = unitLeaseFactLines(docs);

    expect(lines['u1'], 'Lease ends 2026-09-01 · RM 1,500/mo');
  });

  test('omits units whose lease has no end date, and non-lease docs', () {
    final docs = [
      _lease(docId: 'noend', unitId: 'u1', uploadedAt: DateTime(2026, 1, 1),
          facts: {'monthly_rent': 1000.0}),
      DocuMindDocument(
        docId: 'ins', landlordId: 'l1', propertyId: 'p1', category: 'insurance',
        filename: 'ins.pdf', chunksIndexed: 1, uploadedAt: DateTime(2026, 1, 1),
        unitId: 'u2', extractedFacts: {'policy_end': '2026-09-01'},
      ),
    ];

    expect(unitLeaseFactLines(docs), isEmpty);
  });

  test('renders end date alone when rent is absent', () {
    final docs = [
      _lease(docId: 'd', unitId: 'u1', uploadedAt: DateTime(2026, 1, 1),
          facts: {'lease_end': '2026-09-01'}),
    ];

    expect(unitLeaseFactLines(docs)['u1'], 'Lease ends 2026-09-01');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/unit_lease_facts_test.dart`
Expected: FAIL — the imported file doesn't exist.

- [ ] **Step 3: Implement**

Create `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/unit_lease_facts.dart`:

```dart
import '../../../domain/entities/documind_document.dart';

/// Map each unit to a one-line lease-facts summary, taken from that unit's
/// most recently uploaded `lease` document that has a `lease_end`. Units with
/// no such document are omitted (their rows render unchanged).
Map<String, String> unitLeaseFactLines(List<DocuMindDocument> docs) {
  final Map<String, DocuMindDocument> latestLease = {};
  for (final doc in docs) {
    final unitId = doc.unitId;
    if (unitId == null || doc.category != 'lease') continue;
    if (doc.extractedFacts == null || doc.extractedFacts!['lease_end'] == null) continue;
    final existing = latestLease[unitId];
    if (existing == null || doc.uploadedAt.isAfter(existing.uploadedAt)) {
      latestLease[unitId] = doc;
    }
  }

  final lines = <String, String>{};
  latestLease.forEach((unitId, doc) {
    final line = formatLeaseFactLine(doc);
    if (line != null) lines[unitId] = line;
  });
  return lines;
}

/// Format a single lease document's facts, e.g.
/// `Lease ends 2026-09-01 · RM 1,500/mo`. Returns null without a `lease_end`.
String? formatLeaseFactLine(DocuMindDocument doc) {
  final leaseEnd = doc.extractedFacts?['lease_end'];
  if (leaseEnd == null) return null;

  final buffer = StringBuffer('Lease ends $leaseEnd');
  final rent = doc.extractedFacts?['monthly_rent'];
  if (rent is num) {
    buffer.write(' · RM ${_formatAmount(rent)}/mo');
  }
  return buffer.toString();
}

String _formatAmount(num value) {
  // Thousands separators; drop the fractional part for whole amounts.
  final digits = value.round().toString();
  return digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
}
```

- [ ] **Step 4: Run the fact-line test**

Run: `cd residex_app && flutter test test/features/landlord/unit_lease_facts_test.dart`
Expected: PASS.

- [ ] **Step 5: Render the line in UnitsScreen**

In `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart`, add imports:

```dart
import '../../providers/documind_provider.dart';
import 'unit_lease_facts.dart';
```

In `build`, alongside `unitsAsync`, watch the property's documents and compute the fact lines:

```dart
    final docsAsync = ref.watch(documindDocumentsProvider(propertyId));
    final factLines = unitLeaseFactLines(docsAsync.value ?? const []);
```

In the `ListView.builder` item, replace the `ListTile`'s `subtitle:` (currently a single `Text`) with a column that adds the facts line when present:

```dart
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'RM ${unit.monthlyRent.toStringAsFixed(0)}/mo',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textMuted),
                                  ),
                                  if (factLines[unit.id] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        factLines[unit.id]!,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.registry,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
```

(Note: `documindDocumentsProvider` applies the current `selectedDocumindUnitProvider` filter, which returns the selected unit's docs **plus** property-wide docs. Lease-fact lines are keyed by `unitId`, and property-wide docs have `unitId == null`, so they never collide — with no filter set, every unit's lease is present; with a filter, that unit's line is still correct.)

- [ ] **Step 6: Run analyzer and the landlord suite**

Run: `cd residex_app && flutter analyze && flutter test test/features/landlord/`
Expected: 0 analyzer errors; all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add "residex_app/lib/features/landlord/presentation/screens/4-Portfolio/unit_lease_facts.dart" "residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart" residex_app/test/features/landlord/unit_lease_facts_test.dart
git commit -m "feat: show lease facts on unit rows in UnitsScreen" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Full-suite verification + demo-beat acceptance

**Files:**
- No production changes expected; fix anything the full suites surface.

- [ ] **Step 1: Full backend suite**

Run: `cd backend && python -m pytest tests -q` (timeout ≥ 600 s — import-heavy)
Expected: PASS — including `test_fact_extractor.py`, `test_documind_service_flows.py`, `test_rex_routes_documind_docs_api.py`.

- [ ] **Step 2: Full Flutter suite + analyzer**

Run: `cd residex_app && flutter analyze && flutter test`
Expected: 0 analyzer errors; all tests PASS.

- [ ] **Step 3: Manual demo-beat acceptance (requires running backend + emulator)**

This is the spec's acceptance test. With backend and Android emulator running (see the project's run setup notes):

1. Create a property with Unit A → upload Unit A's lease PDF (category `lease`) → upload confirmation reads "Document uploaded — expires <date>" (Task 4).
2. Open the dashboard → an "UPCOMING EXPIRIES" tile shows `Unit A · Lease ends <date> (in N days)` with urgency color (Task 6). If nothing is within 90 days, the tile is absent (not an empty box).
3. Tap the entry → lands on the DocuMind tab with the property selected and (unit-scoped) the Unit A filter preset (Task 6). Ask a lease question → cited answer.
4. Open Portfolio → Units → Unit A's row shows the secondary lease-facts line (Task 7).
5. Upload a scanned image-only PDF (no text layer) or a `utility` bill → no facts captured, document still indexed and listed normally (best-effort invariant).

If any step fails, debug and fix before closing the plan (use superpowers:systematic-debugging).

- [ ] **Step 4: Commit any verification fixes**

Only if Steps 1-3 required changes:

```bash
git add -A
git commit -m "fix: address fact-extraction verification findings" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
