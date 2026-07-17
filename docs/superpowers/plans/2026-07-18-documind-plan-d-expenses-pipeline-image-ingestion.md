# Plan D — Expenses Line-Item Pipeline + Image Ingestion (Backend)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Accept JPG/PNG uploads alongside PDFs, add an `expenses` ingestion category whose fact extraction emits whitelist-validated line items (service charge, sinking fund, quit rent, insurance, loan interest…), fold those lines into the deterministic finance engine, and expose a PATCH endpoint so the app can save user-reviewed lines.

**Architecture:** The document's stored category stays untouched for existing docs (no migration — same convention as the utility→upkeep aliases). A new `expenses` category triggers a JSON line-item extraction with a closed subtype vocabulary + synonym table; each subtype maps to an existing finance category (`maintenance`, `tax`, `insurance`, `loan`, `upkeep`), so the engine's breakdown rows, golden test, and the Flutter Finance tab schema are unchanged. Images skip PyPDFLoader and go straight to the existing Gemini transcription path.

**Tech Stack:** FastAPI, Firestore, LangChain + Gemini (injected `llm`), pypdf, pytest (unittest-style classes).

## Global Constraints

- No data migration ever: stored `category` strings are never rewritten; aliasing happens at read/query time (existing `LEGACY_CATEGORY_ALIASES` convention in `backend/rag/documind_service.py:51`).
- Extraction never guesses: anything failing type/whitelist validation is dropped, never coerced into a guess (existing `FactExtractor` contract).
- Finance engine stays pure: no LLM, no I/O, malformed facts skipped silently (docstring contract in `backend/rag/finance_engine.py:1-8`).
- No emoji in any user-facing string (API messages included) — icons/plain text only.
- Backend tests run from `backend/` with the system Python: `python -m pytest tests/<file> -q`.
- Amounts are plain floats; dates ISO `YYYY-MM-DD`; `period_year` 4-digit int; `period_month` `YYYY-MM`.

## Category model after this plan (reference for every task)

| Stored category | Who writes it | Extraction schema | Engine path |
|---|---|---|---|
| `lease`, `rental_invoice` | app (unchanged) | existing per-category fields | existing |
| `insurance`, `loan`, `tax`, `upkeep`, `maintenance` | old docs + granular-context uploads (checklist, Finance-tab "missing" buttons) | existing per-category fields | existing per-category readers |
| `expenses` (NEW) | the app's Expenses folder | `expense_lines` JSON list | new line-item fold |
| `utility`, `receipt`, `warranty` | legacy docs only | n/a | via aliases (unchanged) |

---

### Task 1: `PdfOcr.transcribe` accepts image MIME types

**Files:**
- Modify: `backend/rag/pdf_ocr.py:42-58`
- Test: `backend/tests/test_pdf_ocr.py` (append)

**Interfaces:**
- Consumes: nothing new.
- Produces: `PdfOcr.transcribe(data: bytes, mime_type: str = "application/pdf") -> Optional[List[str]]`. Task 4 calls it with `mime_type="image/jpeg"` / `"image/png"`.

- [ ] **Step 1: Write the failing tests** (append to `backend/tests/test_pdf_ocr.py`; the fake is self-contained so it works regardless of existing fixtures)

```python
class _MimeCapturingLlm:
    """Records the media part of the last invoke() message."""

    def __init__(self, content="line one"):
        self.media = None
        self._content = content

    def invoke(self, messages):
        for part in messages[0].content:
            if isinstance(part, dict) and part.get("type") == "media":
                self.media = part

        class _R:
            pass

        r = _R()
        r.content = self._content
        return r


class TestTranscribeMimeTypes(unittest.TestCase):
    def test_default_mime_is_pdf(self):
        llm = _MimeCapturingLlm()
        PdfOcr(llm).transcribe(b"%PDF-fake")
        self.assertEqual(llm.media["mime_type"], "application/pdf")

    def test_image_mime_passes_through_without_page_capping(self):
        llm = _MimeCapturingLlm()
        raw = b"\x89PNG-fake-bytes"
        result = PdfOcr(llm).transcribe(raw, mime_type="image/png")
        self.assertEqual(llm.media["mime_type"], "image/png")
        # Image bytes must reach the LLM unmodified (no pypdf page slicing).
        self.assertEqual(
            llm.media["data"], base64.b64encode(raw).decode("ascii")
        )
        self.assertEqual(result, ["line one"])
```

If the file lacks them, add `import base64` and `import unittest` at the top (keep existing imports).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_pdf_ocr.py -q`
Expected: FAIL — `TypeError: transcribe() got an unexpected keyword argument 'mime_type'`

- [ ] **Step 3: Implement** — replace `transcribe` in `backend/rag/pdf_ocr.py:42` (class docstring at line 32 gains one sentence; `_first_pages` unchanged):

```python
    def transcribe(
        self, data: bytes, mime_type: str = "application/pdf"
    ) -> Optional[List[str]]:
        try:
            payload = data
            if mime_type == "application/pdf":
                payload = _first_pages(data, MAX_OCR_PAGES)
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
                    "mime_type": mime_type,
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
            print(f"OCR fallback failed (non-blocking): {e}")
            return None
```

Class docstring (line 32-37) becomes:

```python
    """Gemini-native transcription for scanned PDFs and photo uploads.

    The Gemini API reads PDF or image bytes directly (258 tokens/page) — no
    Tesseract or image-conversion dependency. Best-effort by contract: any
    failure returns None and the caller continues with whatever text it has.
    Page capping applies to PDFs only; an image is a single page.
    """
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_pdf_ocr.py -q`
Expected: PASS (all, including pre-existing tests — the positional first argument is unchanged).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/pdf_ocr.py backend/tests/test_pdf_ocr.py
git commit -m "feat: PdfOcr transcribes image uploads via mime_type parameter"
```

---

### Task 2: Expense-line vocabulary, validation, and extraction

**Files:**
- Modify: `backend/rag/fact_extractor.py`
- Test: `backend/tests/test_fact_extractor.py` (append)

**Interfaces:**
- Consumes: nothing new.
- Produces (used by Tasks 5 and 6):
  - `EXPENSE_SUBTYPE_CATEGORY: Dict[str, str]` — subtype → finance category, exactly: `{"loan_interest": "loan", "assessment_tax": "tax", "quit_rent": "tax", "parcel_rent": "tax", "maintenance": "maintenance", "sinking_fund": "maintenance", "insurance_premium": "insurance", "upkeep": "upkeep"}`
  - `validate_expense_lines(lines: Any) -> List[Dict[str, Any]]` — module-level; cleaned copies with keys `subtype` (whitelisted), `amount` (float), optional `description` (str ≤200), `date` (ISO str), `period_year` (int).
  - `FactExtractor.extract("expenses", text)` returns `{"expense_lines": [...], "policy_start"?: str, "policy_end"?: str, "confidence"?: float}` or `None`.

- [ ] **Step 1: Write the failing tests** (append to `backend/tests/test_fact_extractor.py`)

```python
class _FakeExpensesLlm:
    def __init__(self, content):
        self._content = content

    def invoke(self, prompt):
        class _R:
            pass

        r = _R()
        r.content = self._content
        return r


class TestExpenseLineExtraction(unittest.TestCase):
    def test_combined_statement_yields_validated_lines(self):
        payload = (
            '```json\n'
            '{"lines": ['
            '{"subtype": "maintenance", "description": "Service charge Q1", "amount": "RM 1,050.00", "period_year": 2025},'
            '{"subtype": "sinking_fund", "amount": 210.0, "period_year": 2025},'
            '{"subtype": "insurance_premium", "amount": 1800.0, "date": "2025-03-01"},'
            '{"subtype": "quit_rent", "amount": 316.87, "period_year": 2025},'
            '{"subtype": "made_up_charge", "amount": 999.0}'
            '], "policy_end": "2026-03-01", "confidence": 0.9}\n```'
        )
        facts = FactExtractor(_FakeExpensesLlm(payload)).extract("expenses", "statement text")
        self.assertEqual(len(facts["expense_lines"]), 4)  # bogus subtype dropped
        self.assertEqual(facts["expense_lines"][0]["amount"], 1050.0)  # currency stripped
        self.assertEqual(facts["policy_end"], "2026-03-01")
        self.assertEqual(facts["confidence"], 0.9)

    def test_no_valid_lines_returns_none(self):
        facts = FactExtractor(
            _FakeExpensesLlm('{"lines": [{"subtype": "nonsense", "amount": 10}]}')
        ).extract("expenses", "text")
        self.assertIsNone(facts)

    def test_unparseable_json_returns_none(self):
        facts = FactExtractor(_FakeExpensesLlm("not json at all")).extract("expenses", "text")
        self.assertIsNone(facts)


class TestValidateExpenseLines(unittest.TestCase):
    def test_bad_dates_and_years_are_dropped_from_the_line_not_the_list(self):
        cleaned = validate_expense_lines([
            {"subtype": "upkeep", "amount": 150, "date": "31/12/2025", "period_year": "20255"},
        ])
        self.assertEqual(cleaned, [{"subtype": "upkeep", "amount": 150.0}])

    def test_every_subtype_maps_to_a_finance_category(self):
        for subtype, category in EXPENSE_SUBTYPE_CATEGORY.items():
            self.assertIn(category, {"loan", "tax", "maintenance", "insurance", "upkeep"})
```

Extend the file's import line to `from rag.fact_extractor import FactExtractor, EXPENSE_SUBTYPE_CATEGORY, validate_expense_lines` (keep whatever it already imports).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_fact_extractor.py -q`
Expected: FAIL — `ImportError: cannot import name 'EXPENSE_SUBTYPE_CATEGORY'`

- [ ] **Step 3: Implement in `backend/rag/fact_extractor.py`**

3a. Add `import json` beneath `import re` (line 3).

3b. After `_FIELD_HINTS` (below line 112), add:

```python
# Canonical expense-line subtypes -> the finance category each amount rolls
# into. Single source of truth: extraction and the PATCH API validate against
# the keys; the finance engine maps breakdown rows with the values.
EXPENSE_SUBTYPE_CATEGORY: Dict[str, str] = {
    "loan_interest": "loan",
    "assessment_tax": "tax",
    "quit_rent": "tax",
    "parcel_rent": "tax",
    "maintenance": "maintenance",
    "sinking_fund": "maintenance",
    "insurance_premium": "insurance",
    "upkeep": "upkeep",
}

# Classification is a lookup against this table, not model judgment — the
# Malay/English wording landlords actually see on Malaysian bills.
_EXPENSE_SYNONYMS = (
    "- loan_interest: housing loan interest, interest charged, faedah pinjaman\n"
    "- assessment_tax: assessment, cukai pintu, cukai taksiran\n"
    "- quit_rent: quit rent, cukai tanah\n"
    "- parcel_rent: parcel rent, cukai petak\n"
    "- maintenance: service charge, caj perkhidmatan, management fee, "
    "maintenance fee, caj penyelenggaraan\n"
    "- sinking_fund: sinking fund, kumpulan wang penjelas\n"
    "- insurance_premium: insurance premium, fire policy, houseowner policy, "
    "takaful contribution\n"
    "- upkeep: repairs, servicing, plumbing or electrical works, Indah Water, "
    "utility bills paid by the owner"
)


def validate_expense_lines(lines: Any) -> List[Dict[str, Any]]:
    """Whitelist-validated copy of expense line items; invalid entries are
    dropped, never guessed. Shared by extraction and the facts PATCH API."""
    if not isinstance(lines, list):
        return []
    cleaned: List[Dict[str, Any]] = []
    for line in lines:
        if not isinstance(line, dict):
            continue
        subtype = str(line.get("subtype") or "").strip().lower().replace(" ", "_")
        if subtype not in EXPENSE_SUBTYPE_CATEGORY:
            continue
        amount = FactExtractor._coerce("expenses", "amount", str(line.get("amount", "")))
        if amount is None:
            continue
        entry: Dict[str, Any] = {"subtype": subtype, "amount": amount}
        description = str(line.get("description") or "").strip()
        if description:
            entry["description"] = description[:200]
        date_value = FactExtractor._coerce("expenses", "date", str(line.get("date", "")))
        if date_value is not None:
            entry["date"] = date_value
        year_value = FactExtractor._coerce("expenses", "year", str(line.get("period_year", "")))
        if year_value is not None:
            entry["period_year"] = year_value
        cleaned.append(entry)
    return cleaned
```

Extend the typing import (line 5) to include `List`: `from typing import Any, Dict, List, Optional`.

3c. In `FactExtractor.extract` (line 130), branch before the `_FIELD_TYPES` lookup:

```python
    def extract(self, category: str, text: str) -> Optional[Dict[str, Any]]:
        """Validated facts (plus a 'confidence' key when provided) or None.
        Never raises on LLM or parse trouble."""
        cleaned = (text or "").strip()
        if not cleaned:
            return None
        if category == "expenses":
            return self._extract_expense_lines(cleaned[:MAX_INPUT_CHARS])
        fields = _FIELD_TYPES.get(category)
        if not fields:
            return None

        try:
            prompt = self._build_prompt(category, cleaned[:MAX_INPUT_CHARS])
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()
        except Exception as e:
            print(f"Fact extraction LLM call failed: {e}")
            return None

        facts = self._parse(category, fields, content)
        if not [key for key in facts if key != "confidence"]:
            return None
        return facts
```

3d. Add the new method after `_build_prompt`:

```python
    def _extract_expense_lines(self, text: str) -> Optional[Dict[str, Any]]:
        """JSON line-item extraction for combined expense documents."""
        prompt = f"""
You are extracting expense line items from a Malaysian landlord's property
expense document (bill, statement or receipt). One document may contain
several distinct charge types.

Document text (may be truncated):
{text}

Allowed subtypes and the wording that maps to each (classify strictly by
this table):
{_EXPENSE_SYNONYMS}

Rules:
- Extract ONLY charges billed TO the property owner. Ignore amounts the
  owner bills to a tenant, and ignore totals that duplicate itemised lines.
- One object per distinct charge. NEVER invent amounts.
- Dates must be ISO YYYY-MM-DD; period_year a 4-digit year. Include
  whichever the document states.
- If an insurance premium appears, also report policy_start and policy_end.

Respond with ONLY a JSON object, no markdown fences, shaped exactly like:
{{"lines": [{{"subtype": "maintenance", "description": "Service charge Jan-Mar",
 "amount": 1050.00, "date": "2025-01-01", "period_year": 2025}}],
 "policy_start": null, "policy_end": null, "confidence": 0.9}}
""".strip()
        try:
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()
        except Exception as e:
            print(f"Expense-line extraction LLM call failed: {e}")
            return None

        start = content.find("{")
        end = content.rfind("}")
        if start == -1 or end <= start:
            return None
        try:
            payload = json.loads(content[start:end + 1])
        except ValueError:
            return None
        if not isinstance(payload, dict):
            return None

        lines = validate_expense_lines(payload.get("lines"))
        if not lines:
            return None
        facts: Dict[str, Any] = {"expense_lines": lines}
        for key in ("policy_start", "policy_end"):
            value = self._coerce("expenses", "date", str(payload.get(key) or ""))
            if value is not None:
                facts[key] = value
        try:
            facts["confidence"] = max(0.0, min(1.0, float(payload.get("confidence"))))
        except (TypeError, ValueError):
            pass
        return facts
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_fact_extractor.py -q`
Expected: PASS (new and pre-existing — the non-expenses path is byte-identical logic).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/fact_extractor.py backend/tests/test_fact_extractor.py
git commit -m "feat: expenses line-item extraction with closed subtype vocabulary"
```

---

### Task 3: Taxonomy — allow `expenses` and expand queries in both directions

**Files:**
- Modify: `backend/rag/documind_service.py:41-76`
- Test: `backend/tests/test_category_taxonomy.py` (append)

**Interfaces:**
- Consumes: nothing new.
- Produces: `"expenses"` in `ALLOWED_CATEGORIES`/`CATEGORY_ORDER`; `EXPENSE_GROUP = ["insurance", "loan", "tax", "upkeep", "maintenance"]`; `expand_categories_for_query` maps `expenses` ↔ granular names (used by chat retrieval filters and the Flutter Expenses folder).

- [ ] **Step 1: Write the failing tests** (append inside the existing TestCase class in `backend/tests/test_category_taxonomy.py`, matching its `self.assertEqual` style; extend its import line with `CATEGORY_ORDER` and `EXPENSE_GROUP` if missing)

```python
    def test_expenses_category_is_allowed(self):
        self.assertIn("expenses", ALLOWED_CATEGORIES)
        self.assertIn("expenses", CATEGORY_ORDER)

    def test_expenses_filter_expands_to_granular_and_legacy_names(self):
        expanded = expand_categories_for_query(["expenses"])
        for name in ["expenses", "insurance", "loan", "tax", "upkeep",
                     "maintenance", "utility", "warranty"]:
            self.assertIn(name, expanded)
        self.assertNotIn("lease", expanded)
        self.assertNotIn("rental_invoice", expanded)

    def test_granular_expense_filter_includes_combined_statements(self):
        self.assertEqual(
            expand_categories_for_query(["insurance"]), ["insurance", "expenses"]
        )
        self.assertEqual(
            expand_categories_for_query(["upkeep"]),
            ["upkeep", "utility", "warranty", "expenses"],
        )

    def test_lease_filter_is_unchanged(self):
        self.assertEqual(expand_categories_for_query(["lease"]), ["lease"])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_category_taxonomy.py -q`
Expected: FAIL — `"expenses"` not in `ALLOWED_CATEGORIES`.

- [ ] **Step 3: Implement in `backend/rag/documind_service.py`** — replace lines 41-76 with:

```python
# 7-category taxonomy (2026-07 financial-intelligence spec) plus the
# 'expenses' ingestion bucket (2026-07-18): combined statements upload as
# 'expenses' and carry line items instead of one amount. Documents stored
# before either rename keep their category strings; LEGACY_CATEGORY_ALIASES
# maps them at every read and expand_categories_for_query() widens
# stored-name queries. No data migration.
ALLOWED_CATEGORIES = {
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
}
CATEGORY_ORDER = [
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
]
LEGACY_CATEGORY_ALIASES = {
    "utility": "upkeep",
    "receipt": "rental_invoice",
    "warranty": "upkeep",
}
# Granular stored names the Expenses bucket groups at display/query time.
EXPENSE_GROUP = ["insurance", "loan", "tax", "upkeep", "maintenance"]


def normalize_category(category: Optional[str]) -> Optional[str]:
    """Stored/legacy category -> current taxonomy name (read-time alias)."""
    if not category:
        return category
    lowered = category.strip().lower()
    return LEGACY_CATEGORY_ALIASES.get(lowered, lowered)


def expand_categories_for_query(categories: List[str]) -> List[str]:
    """Current-taxonomy filter -> every stored name it must match: legacy
    spellings (chunks written pre-rename still carry 'utility' etc.) and the
    expenses group in both directions — an 'expenses' filter matches granular
    docs, and a granular filter matches combined 'expenses' statements."""
    expanded: List[str] = []

    def _add(name: str) -> None:
        if name not in expanded:
            expanded.append(name)

    for category in categories:
        _add(category)
        for legacy, current in LEGACY_CATEGORY_ALIASES.items():
            if current == category:
                _add(legacy)
        if category == "expenses":
            for granular in EXPENSE_GROUP:
                _add(granular)
                for legacy, current in LEGACY_CATEGORY_ALIASES.items():
                    if current == granular:
                        _add(legacy)
        elif category in EXPENSE_GROUP:
            _add("expenses")
    return expanded
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_category_taxonomy.py -q`
Expected: PASS (pre-existing expansion tests still hold — legacy-alias ordering for non-expense categories is unchanged).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/documind_service.py backend/tests/test_category_taxonomy.py
git commit -m "feat: expenses category with bidirectional query expansion"
```

---

### Task 4: Image ingestion — upload kind resolution, transcription branch, storage content type

**Files:**
- Modify: `backend/rag/documind_service.py:389-550` (`ingest_document`), plus module level
- Modify: `backend/api/rex_routes.py:18-27` (docstring only)
- Test: `backend/tests/test_upload_kind.py` (create)

**Interfaces:**
- Consumes: `PdfOcr.transcribe(data, mime_type=...)` from Task 1.
- Produces: `resolve_upload_kind(filename: Optional[str]) -> Tuple[str, str]` (module-level in `documind_service.py`) returning `(extension, content_type)` or raising `ValueError`; upload endpoint accepts `.pdf/.jpg/.jpeg/.png` and stores the blob under its real extension/content type.

- [ ] **Step 1: Write the failing tests** — create `backend/tests/test_upload_kind.py`:

```python
import unittest

from rag.documind_service import resolve_upload_kind


class TestResolveUploadKind(unittest.TestCase):
    def test_pdf(self):
        self.assertEqual(resolve_upload_kind("lease.PDF"), (".pdf", "application/pdf"))

    def test_images(self):
        self.assertEqual(resolve_upload_kind("bill.jpg"), (".jpg", "image/jpeg"))
        self.assertEqual(resolve_upload_kind("bill.JPEG"), (".jpeg", "image/jpeg"))
        self.assertEqual(resolve_upload_kind("bill.png"), (".png", "image/png"))

    def test_everything_else_is_rejected(self):
        for name in ("doc.docx", "notes.txt", "archive.zip", "", None):
            with self.assertRaises(ValueError):
                resolve_upload_kind(name)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_upload_kind.py -q`
Expected: FAIL — `ImportError: cannot import name 'resolve_upload_kind'`

- [ ] **Step 3: Implement**

3a. In `backend/rag/documind_service.py`, below `OCR_TEXT_THRESHOLD` (line 40), add (ensure `Tuple` is in the module's `typing` import):

```python
UPLOAD_CONTENT_TYPES = {
    ".pdf": "application/pdf",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
}


def resolve_upload_kind(filename: Optional[str]) -> Tuple[str, str]:
    """(extension, content_type) for an upload; ValueError for anything the
    ingestion pipeline can't read."""
    ext = os.path.splitext(filename or "")[1].lower()
    content_type = UPLOAD_CONTENT_TYPES.get(ext)
    if content_type is None:
        raise ValueError("Unsupported file type. Upload a PDF or a JPG/PNG image.")
    return ext, content_type
```

3b. In `ingest_document`, after the category check (line 405), add:

```python
        ext, content_type = resolve_upload_kind(file.filename)
```

3c. Replace Step 2 of the method (lines 419-435, the PyPDFLoader + OCR-fallback block) with:

```python
            if content_type == "application/pdf":
                # Step 2a: text-layer extraction, OCR fallback for scans.
                loader = PyPDFLoader(temp_path)
                pages = loader.load()
                total_text = sum(len((page.page_content or "").strip()) for page in pages)
                if total_text < OCR_TEXT_THRESHOLD:
                    transcripts = self._pdf_ocr.transcribe(content)
                    if transcripts:
                        pages = [
                            Document(page_content=text, metadata={"page": index})
                            for index, text in enumerate(transcripts)
                        ]
                        print(f"OCR fallback transcribed {len(pages)} page(s)")
            else:
                # Step 2b: images have no text layer — transcribe directly.
                pages = []
                transcripts = self._pdf_ocr.transcribe(content, mime_type=content_type)
                if transcripts:
                    pages = [
                        Document(page_content=text, metadata={"page": index})
                        for index, text in enumerate(transcripts)
                    ]
                    print(f"Transcribed image upload ({len(pages)} block(s))")
```

3d. Replace the storage lines (504-506) with:

```python
            storage_path = f"documind/{landlord_id}/{property_id}/{doc_id}{ext}"
            blob = self.storage_bucket.blob(storage_path)
            blob.upload_from_string(content, content_type=content_type)
```

3e. In `backend/api/rex_routes.py:18-19`, change the docstring's first line to `Upload a document (PDF, or JPG/PNG photo) for a property.` — the 400 for other types now comes from `resolve_upload_kind` via the existing `ValueError` handler at line 38.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_upload_kind.py tests/test_documind_service_flows.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/documind_service.py backend/api/rex_routes.py backend/tests/test_upload_kind.py
git commit -m "feat: ingest JPG/PNG uploads via direct Gemini transcription"
```

---

### Task 5: Finance engine folds expense_lines

**Files:**
- Modify: `backend/rag/finance_engine.py:133-195` (`_expense_lines`) + module level
- Test: `backend/tests/test_finance_engine.py` (append)

**Interfaces:**
- Consumes: `EXPENSE_SUBTYPE_CATEGORY` from Task 2.
- Produces: engine lines for `expenses` docs, one per valid item, with `category` set to the mapped finance category — so `expense_breakdown`, completeness, proration, and the API schema all behave exactly as for granular docs.

- [ ] **Step 1: Write the failing test** (append a new class to `backend/tests/test_finance_engine.py`, matching its unittest style and existing imports of `compute_finance_summary` and `date`)

```python
class TestCombinedExpensesDocument(unittest.TestCase):
    def _summary(self, docs):
        return compute_finance_summary(
            year=2025,
            today=date(2026, 7, 18),
            documents=docs,
            properties=[{"property_id": "p1", "name": "Test Property"}],
            units_by_property={},
        )

    def test_lines_map_to_breakdown_categories_and_filter_by_year(self):
        docs = [{
            "doc_id": "d-exp",
            "property_id": "p1",
            "unit_id": None,
            "category": "expenses",
            "extracted_facts": {
                "expense_lines": [
                    {"subtype": "maintenance", "amount": 4200.0, "period_year": 2025},
                    {"subtype": "sinking_fund", "amount": 840.0, "period_year": 2025},
                    {"subtype": "insurance_premium", "amount": 1800.0, "date": "2025-03-01"},
                    {"subtype": "quit_rent", "amount": 316.87, "period_year": 2025},
                    {"subtype": "quit_rent", "amount": 316.87, "period_year": 2024},
                ],
                "policy_end": "2026-03-01",
            },
        }]
        summary = self._summary(docs)
        self.assertEqual(summary["expense_breakdown"]["maintenance"], 5040.0)
        self.assertEqual(summary["expense_breakdown"]["insurance"], 1800.0)
        self.assertEqual(summary["expense_breakdown"]["tax"], 316.87)
        self.assertEqual(summary["totals"]["direct_expenses"], 7156.87)

    def test_malformed_lines_are_skipped_silently(self):
        docs = [{
            "doc_id": "d-bad",
            "property_id": "p1",
            "unit_id": None,
            "category": "expenses",
            "extracted_facts": {
                "expense_lines": [
                    {"subtype": "unknown_thing", "amount": 10.0, "period_year": 2025},
                    {"subtype": "maintenance", "period_year": 2025},
                    "not-a-dict",
                    {"subtype": "maintenance", "amount": 100.0, "period_year": 2025},
                ],
            },
        }]
        summary = self._summary(docs)
        self.assertEqual(summary["totals"]["direct_expenses"], 100.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_finance_engine.py -q`
Expected: FAIL — breakdown empty / `direct_expenses` 0.0 (expenses docs currently fall through every branch).

- [ ] **Step 3: Implement in `backend/rag/finance_engine.py`**

3a. Below the imports (line 12), add:

```python
from rag.fact_extractor import EXPENSE_SUBTYPE_CATEGORY

_EXPENSE_LINE_LABELS = {
    "loan_interest": "Loan interest",
    "assessment_tax": "Assessment tax",
    "quit_rent": "Quit rent",
    "parcel_rent": "Parcel rent",
    "maintenance": "Maintenance fees",
    "sinking_fund": "Sinking fund",
    "insurance_premium": "Insurance premium",
    "upkeep": "Upkeep",
}
```

3b. In `_expense_lines` (line 144), right after `category = doc.get("category")` and before `entry = None`, insert the multi-line branch:

```python
        if category == "expenses":
            for item in (facts.get("expense_lines") or []):
                if not isinstance(item, dict):
                    continue
                subtype = item.get("subtype")
                mapped = EXPENSE_SUBTYPE_CATEGORY.get(subtype)
                amount = _amount(item, "amount")
                ym = _ym(item.get("date"))
                in_year = item.get("period_year") == year or (ym is not None and ym[0] == year)
                if mapped is None or amount is None or not in_year:
                    continue
                lines.append({
                    "doc_id": doc["doc_id"],
                    "category": mapped,
                    "subtype": subtype,
                    "description": item.get("description") or _EXPENSE_LINE_LABELS[subtype],
                    "amount": _round2(amount),
                    "date": item.get("date") or str(item.get("period_year") or year),
                    "unit_id": doc.get("unit_id"),
                })
            continue
```

3c. Extend the `_expense_lines` docstring (line 134-142) with one sentence: `Combined 'expenses' documents contribute one line per validated item, mapped to its finance category via EXPENSE_SUBTYPE_CATEGORY; a line belongs to the year when its period_year matches or its date falls in the year.`

- [ ] **Step 4: Run the full engine suite — the golden reference-sheet test must still pass**

Run: `cd backend && python -m pytest tests/test_finance_engine.py tests/test_finance_chat.py tests/test_rex_routes_finance_api.py -q`
Expected: PASS, including the golden `60106.58` assertion (granular docs never enter the new branch).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat: finance engine folds combined-statement expense lines"
```

---

### Task 6: PATCH endpoint for reviewed expense lines

**Files:**
- Modify: `backend/models/documind_models.py` (append models)
- Modify: `backend/rag/documind_service.py` (append method; extend the `rag.fact_extractor` import with `validate_expense_lines`)
- Modify: `backend/api/rex_routes.py` (new route; extend the models import)
- Test: `backend/tests/test_update_expense_lines.py` (create)

**Interfaces:**
- Consumes: `validate_expense_lines` from Task 2.
- Produces: `PATCH /api/rex/documind/documents/{doc_id}/facts` with body `{"landlord_id": str, "expense_lines": [{subtype, amount, description?, date?, period_year?}]}` → `{"doc_id": str, "extracted_facts": {...}}`. Plan E's datasource calls this.

- [ ] **Step 1: Write the failing test** — create `backend/tests/test_update_expense_lines.py` (validation fires before any Firestore access, so no mocking is needed):

```python
import asyncio
import unittest

from rag.documind_service import documind_service


class TestUpdateExpenseLinesValidation(unittest.TestCase):
    def test_rejects_lines_with_unknown_subtypes(self):
        with self.assertRaises(ValueError):
            asyncio.run(documind_service.update_expense_lines(
                doc_id="missing",
                landlord_id="landlord-1",
                lines=[{"subtype": "bogus", "amount": 10.0}],
            ))

    def test_rejects_empty_list(self):
        with self.assertRaises(ValueError):
            asyncio.run(documind_service.update_expense_lines(
                doc_id="missing", landlord_id="landlord-1", lines=[],
            ))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_update_expense_lines.py -q`
Expected: FAIL — `AttributeError: ... has no attribute 'update_expense_lines'`

- [ ] **Step 3: Implement**

3a. `backend/models/documind_models.py` — append (add any of `BaseModel`, `Optional`, `List`, `Dict`, `Any` missing from its imports):

```python
class ExpenseLineEdit(BaseModel):
    subtype: str
    amount: float
    description: Optional[str] = None
    date: Optional[str] = None
    period_year: Optional[int] = None


class FactsUpdateRequest(BaseModel):
    landlord_id: str
    expense_lines: List[ExpenseLineEdit]


class FactsUpdateResponse(BaseModel):
    doc_id: str
    extracted_facts: Dict[str, Any]
```

3b. `backend/rag/documind_service.py` — extend the fact-extractor import to include `validate_expense_lines` (keep existing names), and append this method to the service class, directly after `ingest_document`:

```python
    async def update_expense_lines(
        self, doc_id: str, landlord_id: str, lines: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Replace a document's expense_lines after user review. Validation
        reuses the extractor whitelist, so the API can never store a subtype
        the finance engine doesn't understand."""
        cleaned = validate_expense_lines(lines)
        if not cleaned:
            raise ValueError(
                "No valid expense lines. Each line needs a known subtype and an amount."
            )
        doc_ref = self.db.collection('documind_docs').document(doc_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise ValueError("Document not found.")
        data = snapshot.to_dict() or {}
        if data.get("landlord_id") != landlord_id:
            raise ValueError("Document not found.")
        facts = dict(data.get("extracted_facts") or {})
        facts["expense_lines"] = cleaned
        doc_ref.update({
            "extracted_facts": facts,
            "facts_extracted_at": firestore.SERVER_TIMESTAMP,
        })
        return {"doc_id": doc_id, "extracted_facts": facts}
```

3c. `backend/api/rex_routes.py` — extend the models import (line 2) with `FactsUpdateRequest, FactsUpdateResponse`, and add after the upload route:

```python
@router.patch("/documind/documents/{doc_id}/facts", response_model=FactsUpdateResponse)
async def update_document_facts(doc_id: str, payload: FactsUpdateRequest):
    """
    Replace a document's reviewed expense lines (Expenses uploads).

    Subtypes are whitelist-validated server-side; a body with no valid
    line returns 400 and the stored facts stay untouched.
    """
    try:
        result = await documind_service.update_expense_lines(
            doc_id=doc_id,
            landlord_id=payload.landlord_id,
            lines=[line.model_dump() for line in payload.expense_lines],
        )
        return FactsUpdateResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
```

- [ ] **Step 4: Run tests to verify they pass, then the whole backend suite**

Run: `cd backend && python -m pytest tests/test_update_expense_lines.py -q`
Expected: PASS.
Run: `cd backend && python -m pytest tests -q`
Expected: PASS across the board.

- [ ] **Step 5: Commit**

```bash
git add backend/models/documind_models.py backend/rag/documind_service.py backend/api/rex_routes.py backend/tests/test_update_expense_lines.py
git commit -m "feat: PATCH endpoint to save reviewed expense lines"
```
