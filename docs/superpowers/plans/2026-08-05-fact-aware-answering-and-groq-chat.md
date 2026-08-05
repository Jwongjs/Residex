# Fact-Aware Answering + Groq Chat Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DocuMind answer from the facts it already extracted at upload, so a value never reaches the model only when its chunk happens to win retrieval — and move chat synthesis onto Groq behind a flag.

**Architecture:** A new pure module renders a document's `extracted_facts` into a prompt block. `DocuMindService` gains a Firestore reader for those facts; `AskOrchestrator` takes it as one more injected callable, following the pattern its existing collaborators already use. Retrieval is untouched. Separately, `_chat_llm()` mirrors the existing `_fact_llm()` behind a `CHAT_PROVIDER` flag.

**Tech Stack:** Python 3.11, FastAPI, Firestore, pytest (unittest style), Groq via `rag/providers/groq_chat.py`, Gemini via `langchain_google_genai`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-05-fact-aware-answering-and-groq-chat-design.md`
- Run backend tests from `backend/` with `py -3.11 -m pytest tests/ -q`. **Baseline: 486 passed, 0 failed.** Never let this regress.
- The repo `.venv` has been removed; system Python 3.11 is the only environment and satisfies all of `requirements.txt`.
- On Windows, prefix any command whose output includes the emoji log lines with `PYTHONIOENCODING=utf-8` when piping, or stdout raises `UnicodeEncodeError`.
- `CHAT_PROVIDER` defaults to `gemini`. Merging this plan changes no runtime behaviour until `.env` sets it.
- `PdfOcr` must never receive a `GroqChat`. It invokes with a list of multimodal `HumanMessage`s; `GroqChat.invoke` takes a plain string.
- All extracted fact keys are injected, **including `tenant_name`** (explicit decision — names are permitted). `scrub_for_hosted` still redacts NRIC, phone and email.
- Never `git add -A`. Commit the explicit paths named in each task.
- Do not modify `backend/scripts/diagnose_ayer8_lease.py`, `backend/scripts/fix_ayer8_lease_facts.py`, or `backend/rexAI.txt`.

---

### Task 1: Facts block renderer

**Files:**
- Create: `backend/rag/ask/fact_context.py`
- Test: `backend/tests/test_fact_context.py`

**Interfaces:**
- Consumes: nothing (pure, first task)
- Produces: `build_facts_block(docs: Iterable[tuple[str, Optional[str], dict]]) -> str`, where each element is `(filename, unit_label, facts)`. Returns `""` when there is nothing to render.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_fact_context.py`:

```python
"""The facts block that goes in front of the answer prompt.

Pure rendering: no Firestore, no LLM. The block exists because retrieval can
miss the one chunk stating a value (a tenancy agreement's Schedule table), so
these tests pin the shape the model will read.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.ask.fact_context import build_facts_block


class TestEmptyCases:
    def test_no_documents_returns_empty_string(self):
        assert build_facts_block([]) == ""

    def test_document_without_facts_is_omitted(self):
        assert build_facts_block([("lease.pdf", "Unit A", {})]) == ""

    def test_facts_with_only_blank_values_are_omitted(self):
        assert build_facts_block([("lease.pdf", None, {"lease_end": None, "deposit": ""})]) == ""


class TestRendering:
    def test_renders_humanised_labels_and_values(self):
        block = build_facts_block([
            ("Ayer8 lease.pdf", "Unit B2-1-2",
             {"lease_end": "2026-10-31", "monthly_rent": 8000.0}),
        ])
        assert "Ayer8 lease.pdf" in block
        assert "Unit B2-1-2" in block
        assert "Lease end: 2026-10-31" in block
        assert "Monthly rent (RM): 8000.0" in block
        # Raw storage keys must not leak into the prompt.
        assert "lease_end" not in block

    def test_unknown_key_falls_back_to_readable_form(self):
        block = build_facts_block([("x.pdf", None, {"policy_number": "P-1"})])
        assert "Policy number: P-1" in block

    def test_missing_unit_label_reads_property_wide(self):
        block = build_facts_block([("quitrent.pdf", None, {"amount": 120.0})])
        assert "Property-wide" in block

    def test_blank_values_are_skipped_but_siblings_survive(self):
        block = build_facts_block([
            ("lease.pdf", None, {"lease_end": "2026-10-31", "deposit": None}),
        ])
        assert "Lease end: 2026-10-31" in block
        assert "Deposit" not in block

    def test_multiple_documents_render_as_separate_sections(self):
        block = build_facts_block([
            ("a.pdf", "Unit A", {"lease_end": "2026-10-31"}),
            ("b.pdf", "Unit B", {"lease_end": "2027-01-31"}),
        ])
        assert "a.pdf" in block and "b.pdf" in block
        assert "2026-10-31" in block and "2027-01-31" in block

    def test_tenant_name_is_included(self):
        # Explicit decision: names are permitted through to the trusted provider.
        block = build_facts_block([("lease.pdf", None, {"tenant_name": "JNT Sdn. Bhd."})])
        assert "Tenant: JNT Sdn. Bhd." in block
```

- [ ] **Step 2: Run test to verify it fails**

Run: `py -3.11 -m pytest tests/test_fact_context.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'rag.ask.fact_context'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/rag/ask/fact_context.py`:

```python
"""Render a document's extracted facts for the answer prompt.

Retrieval can miss the one chunk that states a value. A Malaysian tenancy
agreement puts its dates in a Schedule table that the body only
cross-references, and that table embeds poorly against a natural question —
measured on live data, the Schedule chunk was absent from the fetch_k=15
candidate set entirely and still ranked 21st of 42 when every chunk was
fetched and reranked. The facts were already parsed correctly at upload, so
this block puts them in front of the model rather than depending on the table
surviving retrieval.

Pure: no Firestore, no LLM, no network.
"""
from typing import Iterable, Optional, Tuple

# Storage keys are snake_case; the model reads these labels instead.
_LABELS = {
    "lease_start": "Lease start",
    "lease_end": "Lease end",
    "monthly_rent": "Monthly rent (RM)",
    "deposit": "Deposit (RM)",
    "tenant_name": "Tenant",
    "subtype": "Agreement type",
    "period_month": "Period",
    "amount": "Amount (RM)",
    "due_date": "Due date",
    "provider": "Provider",
}


def _label(key: str) -> str:
    """Known keys get a curated label; anything else becomes readable rather
    than being dropped, so a newly extracted fact still reaches the model."""
    if key in _LABELS:
        return _LABELS[key]
    return key.replace("_", " ").capitalize()


def build_facts_block(
    docs: Iterable[Tuple[str, Optional[str], dict]],
) -> str:
    """(filename, unit_label, facts) triples -> prompt block.

    Returns "" when there is nothing worth showing, so the caller can
    concatenate unconditionally without emitting an empty header.
    """
    sections = []
    for filename, unit_label, facts in docs:
        if not facts:
            continue
        lines = [
            f"    - {_label(key)}: {value}"
            for key, value in sorted(facts.items())
            if value is not None and value != ""
        ]
        if not lines:
            continue
        scope = unit_label or "Property-wide"
        sections.append(f"[{filename} — {scope}]\n" + "\n".join(lines))
    return "\n\n".join(sections)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `py -3.11 -m pytest tests/test_fact_context.py -q`
Expected: PASS (9 tests)

- [ ] **Step 5: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: 495 passed (486 baseline + 9 new), 0 failed

- [ ] **Step 6: Commit**

```bash
git add backend/rag/ask/fact_context.py backend/tests/test_fact_context.py
git commit -m "feat(documind): render extracted facts into a prompt block"
```

---

### Task 2: Firestore reader for document facts

**Files:**
- Modify: `backend/rag/documind_service.py` (add a method after `_extractor_for`, around line 208)
- Test: `backend/tests/test_document_facts_lookup.py`

**Interfaces:**
- Consumes: nothing from Task 1 (independent)
- Produces: `DocuMindService._get_document_facts(doc_ids: list[str]) -> list[tuple[str, Optional[str], dict]]` — exactly the shape `build_facts_block` consumes. De-duplicates `doc_ids` preserving order; omits documents that are missing or carry no `extracted_facts`; never raises.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_document_facts_lookup.py`:

```python
"""Loading extracted facts for the documents retrieval actually hit.

Scope is deliberately narrow: only doc_ids present in the retrieved chunks.
The lookup must never raise — a facts failure degrades the answer to
chunks-only, it never fails the request.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.documind_service import DocuMindService


class _Snap:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return self._data


class _DocRef:
    def __init__(self, data):
        self._data = data

    def get(self):
        return _Snap(self._data)


class _ExplodingDocRef:
    def get(self):
        raise RuntimeError("firestore unavailable")


class _Collection:
    def __init__(self, docs, explode_on=None):
        self._docs = docs
        self._explode_on = explode_on

    def document(self, doc_id):
        if doc_id == self._explode_on:
            return _ExplodingDocRef()
        return _DocRef(self._docs.get(doc_id))


class _DB:
    def __init__(self, docs, explode_on=None):
        self._docs = docs
        self._explode_on = explode_on
        self.requested_collections = []

    def collection(self, name):
        self.requested_collections.append(name)
        return _Collection(self._docs, self._explode_on)


def _service(docs, explode_on=None):
    service = DocuMindService.__new__(DocuMindService)
    service._db = _DB(docs, explode_on)
    return service


class TestDocumentFactsLookup:
    def test_returns_filename_unit_label_and_facts(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": "Unit A",
                   "extracted_facts": {"lease_end": "2026-10-31"}},
        })
        assert service._get_document_facts(["d1"]) == [
            ("lease.pdf", "Unit A", {"lease_end": "2026-10-31"}),
        ]

    def test_deduplicates_doc_ids_preserving_order(self):
        service = _service({
            "d1": {"filename": "a.pdf", "unit_label": None,
                   "extracted_facts": {"amount": 1}},
            "d2": {"filename": "b.pdf", "unit_label": None,
                   "extracted_facts": {"amount": 2}},
        })
        result = service._get_document_facts(["d1", "d2", "d1"])
        assert [row[0] for row in result] == ["a.pdf", "b.pdf"]

    def test_document_without_facts_is_omitted(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": None, "extracted_facts": {}},
        })
        assert service._get_document_facts(["d1"]) == []

    def test_missing_document_is_omitted(self):
        service = _service({})
        assert service._get_document_facts(["nope"]) == []

    def test_firestore_error_is_swallowed_and_skips_that_doc(self):
        service = _service(
            {"d2": {"filename": "ok.pdf", "unit_label": None,
                    "extracted_facts": {"amount": 5}}},
            explode_on="d1",
        )
        # d1 raises; d2 must still come back.
        assert service._get_document_facts(["d1", "d2"]) == [
            ("ok.pdf", None, {"amount": 5}),
        ]

    def test_empty_input_makes_no_firestore_call(self):
        service = _service({})
        assert service._get_document_facts([]) == []
        assert service._db.requested_collections == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `py -3.11 -m pytest tests/test_document_facts_lookup.py -q`
Expected: FAIL — `AttributeError: 'DocuMindService' object has no attribute '_get_document_facts'`

- [ ] **Step 3: Write minimal implementation**

In `backend/rag/documind_service.py`, add immediately after the `_extractor_for` method:

```python
    def _get_document_facts(self, doc_ids):
        """(filename, unit_label, facts) for each doc_id that has facts.

        Scoped to the documents retrieval actually hit, so no data leaves for a
        document the query never touched. Best-effort by contract: any Firestore
        failure skips that document and is logged, because a missing facts block
        must degrade the answer to chunks-only rather than fail the request.
        """
        rows = []
        for doc_id in dict.fromkeys(doc_ids):  # de-dupe, preserve order
            try:
                snap = self.db.collection('documind_docs').document(doc_id).get()
            except Exception as e:
                print(f"WARNING: could not load facts for doc {doc_id}: {e}")
                continue
            if not snap.exists:
                continue
            data = snap.to_dict() or {}
            facts = data.get('extracted_facts') or {}
            if not facts:
                continue
            rows.append((data.get('filename') or doc_id, data.get('unit_label'), facts))
        return rows
```

- [ ] **Step 4: Run test to verify it passes**

Run: `py -3.11 -m pytest tests/test_document_facts_lookup.py -q`
Expected: PASS (6 tests)

- [ ] **Step 5: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: 501 passed, 0 failed

- [ ] **Step 6: Commit**

```bash
git add backend/rag/documind_service.py backend/tests/test_document_facts_lookup.py
git commit -m "feat(documind): load extracted facts for retrieved documents"
```

---

### Task 3: Inject the facts block into the answer prompt

**Files:**
- Modify: `backend/rag/ask/ask_orchestrator.py` (imports line 8-10; `__init__` lines 17-28; context assembly around line 539; prompt around line 578)
- Modify: `backend/rag/pii_scrub.py` (module docstring, lines 1-13)
- Modify: `backend/tests/test_documind_service_flows.py` (`_build_service`, lines 549-578)
- Test: `backend/tests/test_documind_service_flows.py` (new test class at end of file)

**Interfaces:**
- Consumes: `build_facts_block` from Task 1; `DocuMindService._get_document_facts` from Task 2
- Produces: `AskOrchestrator.__init__` accepts a new keyword-only argument `get_document_facts=None`. **Defaulting to `None` is deliberate** — it keeps every existing construction site valid, and a `None` getter simply yields no facts block.

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_documind_service_flows.py`:

```python
class FactContextInjectionTests(unittest.IsolatedAsyncioTestCase):
    """The Ayer 8 regression.

    Retrieval returns real lease chunks that discuss termination in the
    abstract but never state the date — exactly what the live Schedule-table
    miss looks like. The document's extracted_facts carry the date. The
    assembled prompt must contain it.
    """

    def _fixtures(self):
        fake_db = _FakeDB(
            docs=[{
                "doc_id": "d-lease", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "ayer8-lease.pdf",
                "unit_label": "Unit B2-1-2",
                "extracted_facts": {"lease_end": "2026-10-31", "monthly_rent": 8000.0},
            }],
            chunks=[{
                "doc_id": "d-lease", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "ayer8-lease.pdf",
                "unit_label": "Unit B2-1-2", "page": 5,
                "text": ("the term of the tenancy has expired or has been sooner "
                         "determined, less any sums then due to the Landlord"),
            }],
        )
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["lease"],
            "prediction_confidence": 0.95,
            "prediction_reason": "asks about tenancy end date",
            "assistant_message": "",
            "intent": "document_question",
        })
        return fake_db, fake_graph

    async def test_extracted_facts_reach_the_prompt(self):
        fake_db, fake_graph = self._fixtures()
        fake_llm = _FakeLLM("The tenancy ends on 31 October 2026.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        await service.ask_documind(payload, "l1")

        # The chunk never states the date; only the facts block can supply it.
        self.assertNotIn("2026-10-31", fake_llm.last_prompt.split("Extracted Document Facts")[0])
        self.assertIn("2026-10-31", fake_llm.last_prompt)
        self.assertIn("Lease end", fake_llm.last_prompt)
        self.assertIn("Unit B2-1-2", fake_llm.last_prompt)

    async def test_answer_still_produced_when_facts_lookup_fails(self):
        fake_db, fake_graph = self._fixtures()
        fake_llm = _FakeLLM("Answered from excerpts alone.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        def _explode(_doc_ids):
            raise RuntimeError("firestore down")

        service._ask_orchestrator._get_document_facts = _explode

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        self.assertEqual(response.answer, "Answered from excerpts alone.")
        self.assertNotIn("Extracted Document Facts", fake_llm.last_prompt)

    async def test_no_facts_block_when_documents_have_no_facts(self):
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {}
        fake_llm = _FakeLLM("No facts available.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        await service.ask_documind(payload, "l1")

        self.assertNotIn("Extracted Document Facts", fake_llm.last_prompt)

    async def test_facts_block_is_pii_scrubbed(self):
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {
            "lease_end": "2026-10-31", "landlord_nric": "661214055049",
        }
        fake_llm = _FakeLLM("ok")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        await service.ask_documind(payload, "l1")

        self.assertIn("[NRIC]", fake_llm.last_prompt)
        self.assertNotIn("661214055049", fake_llm.last_prompt)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py -k FactContextInjection -q`
Expected: FAIL — `2026-10-31` is not in the prompt; no `Extracted Document Facts` heading exists.

- [ ] **Step 3: Wire the getter into `AskOrchestrator`**

In `backend/rag/ask/ask_orchestrator.py`, extend the import at line 8-10:

```python
from rag.ask.fact_context import build_facts_block
from rag.categories import ALLOWED_CATEGORIES, expand_categories_for_query, normalize_category
from rag.pii_scrub import scrub_for_hosted
from rag.unit_resolution import resolve_unit_mention
```

Replace `__init__` (lines 17-28) with:

```python
    def __init__(
        self, *, conversation_store, graph_orchestrator, hybrid_retriever, llm_getter,
        list_available_categories, get_property_name, list_property_units, get_finance_summary,
        get_document_facts=None,
    ):
        self._conversation_store = conversation_store
        self._graph_orchestrator = graph_orchestrator
        self._hybrid_retriever = hybrid_retriever
        self._llm_getter = llm_getter
        self._list_available_categories = list_available_categories
        self._get_property_name = get_property_name
        self._list_property_units = list_property_units
        self._get_finance_summary = get_finance_summary
        # Optional on purpose: a None getter yields no facts block, so every
        # existing construction site stays valid and the feature can never be
        # the reason an answer fails.
        self._get_document_facts = get_document_facts
```

- [ ] **Step 4: Build the block after context assembly**

In `backend/rag/ask/ask_orchestrator.py`, immediately after the `for i, chunk in enumerate(retrieved_chunks):` loop ends (after the `context_text += ...` line, before `citations = [`), insert:

```python
        # Retrieval ranks prose about a value above the table that states it —
        # a lease Schedule loses to the clauses that cross-reference it. These
        # facts were parsed at upload, so hand them to the model directly
        # rather than hoping the right chunk won. Scoped to the documents this
        # query actually hit.
        facts_block = ""
        if self._get_document_facts is not None:
            try:
                doc_ids = list(dict.fromkeys(c['doc_id'] for c in retrieved_chunks))
                facts_block = scrub_for_hosted(build_facts_block(self._get_document_facts(doc_ids)))
            except Exception as e:
                print(f"WARNING: facts block unavailable, answering from excerpts only: {e}")
                facts_block = ""
```

- [ ] **Step 5: Add the block to the prompt**

In the same file, inside the prompt f-string (around line 578), insert this section immediately **before** the `**Relevant Document Excerpts:**` line:

```python
    {("**Extracted Document Facts:**" + chr(10) + facts_block + chr(10)) if facts_block else ""}
```

Then add a rule to the numbered **Instructions** list, after rule 4:

```
    5. **Extracted facts take precedence for values.** The Extracted Document Facts block above holds values parsed from these same documents when they were uploaded. When it answers the question, use it — the excerpts often only cross-reference a Schedule whose table is not among them. Never contradict that block with a guess, and never claim a value is unavailable when the block states it.
```

Renumber the existing unit-attribution rule from 5 to 6, leaving its text unchanged.

- [ ] **Step 6: Wire the getter in production and in the test harness**

In `backend/rag/documind_service.py`, in the `AskOrchestrator(...)` construction inside `__init__`, add one line after `get_finance_summary=self.get_finance_summary,`:

```python
            get_document_facts=self._get_document_facts,
```

In `backend/tests/test_documind_service_flows.py`, in `_build_service`, add the same line after `get_finance_summary=service.get_finance_summary,`:

```python
        get_document_facts=service._get_document_facts,
```

- [ ] **Step 7: Correct the pii_scrub docstring**

In `backend/rag/pii_scrub.py`, replace lines 3-9 of the module docstring:

```python
"""Redact regex-reliable PII before any text is sent to a hosted LLM.

Scope, stated honestly: this catches the identifiers that are pattern-matchable
— Malaysian NRIC, phone, email — at every boundary where text leaves for a
hosted API (chat context assembly and the extracted-facts block in
ask_documind). Names and addresses are NOT regex-catchable and DO reach the
configured chat provider inside chunk text and extracted facts; keeping the
provider trusted (Groq under ZDR, via CHAT_PROVIDER) is what bounds that, not
this scrubber. Running OCR, embeddings and fact-extraction locally keeps raw
document bytes and full leading text off the hosted path — a separate control
from this one.

Known tradeoff: a bare 12-digit number is treated as an NRIC, so a 12-digit
invoice/account number is redacted too — acceptable for a privacy net.
Amounts, dates (YYYY-MM-DD) and clause numbers are left intact.
"""
```

- [ ] **Step 8: Run the new tests**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py -k FactContextInjection -q`
Expected: PASS (4 tests)

- [ ] **Step 9: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: 505 passed, 0 failed

- [ ] **Step 10: Commit**

```bash
git add backend/rag/ask/ask_orchestrator.py backend/rag/documind_service.py backend/rag/pii_scrub.py backend/tests/test_documind_service_flows.py
git commit -m "fix(documind): answer from extracted facts, not retrieval luck"
```

---

### Task 4: CHAT_PROVIDER routing to Groq

**Files:**
- Modify: `backend/rag/documind_service.py` (add `_chat_llm` after `_fact_llm`, around line 175; use it in `__init__` at lines 80-89)
- Test: `backend/tests/test_documind_groq_routing.py` (append a class)

**Interfaces:**
- Consumes: nothing from Tasks 1-3 (independent; may be implemented in any order relative to them)
- Produces: `DocuMindService._chat_llm()` returning a `GroqChat` when `CHAT_PROVIDER=groq`, else the Gemini client held in `self._llm`.

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_documind_groq_routing.py`:

```python
class TestChatLlmProvider:
    def test_defaults_to_hosted_gemini_client(self):
        service = _bare()
        service._llm = "HOSTED"
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("CHAT_PROVIDER", None)
            assert service._chat_llm() == "HOSTED"

    def test_explicit_gemini_stays_hosted(self):
        service = _bare()
        service._llm = "HOSTED"
        with patch.dict(os.environ, {"CHAT_PROVIDER": "gemini"}, clear=False):
            assert service._chat_llm() == "HOSTED"

    def test_groq_flag_selects_groq_client(self):
        service = _bare()
        service._llm = "HOSTED"
        with patch.dict(os.environ,
                        {"CHAT_PROVIDER": "groq", "GROQ_API_KEY": "k"}, clear=False):
            chosen = service._chat_llm()
        assert isinstance(chosen, GroqChat)

    def test_groq_chat_model_is_overridable(self):
        service = _bare()
        service._llm = "HOSTED"
        with patch.dict(os.environ,
                        {"CHAT_PROVIDER": "groq", "GROQ_API_KEY": "k",
                         "GROQ_CHAT_MODEL": "openai/gpt-oss-120b"}, clear=False):
            chosen = service._chat_llm()
        assert chosen.model == "openai/gpt-oss-120b"

    def test_case_insensitive(self):
        service = _bare()
        service._llm = "HOSTED"
        with patch.dict(os.environ,
                        {"CHAT_PROVIDER": "GROQ", "GROQ_API_KEY": "k"}, clear=False):
            assert isinstance(service._chat_llm(), GroqChat)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `py -3.11 -m pytest tests/test_documind_groq_routing.py -k ChatLlmProvider -q`
Expected: FAIL — `AttributeError: 'DocuMindService' object has no attribute '_chat_llm'`

- [ ] **Step 3: Write minimal implementation**

In `backend/rag/documind_service.py`, add immediately after `_fact_llm`:

```python
    def _chat_llm(self):
        """The LLM behind chat: answer synthesis, conversation routing and
        category prediction. CHAT_PROVIDER=groq routes them to Groq, which
        already receives lease text for fact extraction under ZDR; default
        'gemini' keeps the hosted client so merging this changes nothing until
        the flag is set.

        PdfOcr deliberately does NOT use this — it invokes with a list of
        multimodal HumanMessages and GroqChat.invoke takes a plain string.
        """
        provider = os.getenv("CHAT_PROVIDER", "gemini").lower()
        if provider == "groq":
            model = os.getenv("GROQ_CHAT_MODEL", "llama-3.3-70b-versatile")
            print(f"🔄 Chat routed to Groq ({model}) — ZDR must be enabled")
            return GroqChat(model=model)
        return self._llm
```

- [ ] **Step 4: Run test to verify it passes**

Run: `py -3.11 -m pytest tests/test_documind_groq_routing.py -k ChatLlmProvider -q`
Expected: PASS (5 tests)

- [ ] **Step 5: Write the failing wiring test**

Append to `backend/tests/test_documind_groq_routing.py`:

```python
class TestChatProviderWiring:
    """PdfOcr must never end up holding the chat client.

    Constructing a real DocuMindService needs live Firestore, so this asserts
    on __init__'s source. That is deliberate and narrow: it guards the one
    coupling that fails SILENTLY — swapping PdfOcr onto GroqChat breaks OCR
    only at upload time, with no test and no startup error to catch it. The
    behaviour of _chat_llm itself is covered properly by TestChatLlmProvider.
    """

    def test_pdf_ocr_keeps_the_gemini_client(self):
        # PdfOcr.invoke is called with a list of multimodal HumanMessages;
        # GroqChat.invoke takes a plain string and would break on it.
        import inspect

        from rag.documind_service import DocuMindService as Svc
        source = inspect.getsource(Svc.__init__)
        assert "PdfOcr(self._llm)" in source, "PdfOcr must hold the Gemini client"
        assert "PdfOcr(self._chat" not in source

    def test_llm_property_falls_back_for_bare_instances(self):
        # Every existing test builds the service via __new__ and sets _llm
        # directly; the property must keep honouring that.
        service = _bare()
        service._llm = "HOSTED"
        assert service.llm == "HOSTED"

    def test_llm_property_prefers_the_chat_client_when_present(self):
        service = _bare()
        service._llm = "HOSTED"
        service._chat = "CHAT"
        assert service.llm == "CHAT"
```

- [ ] **Step 6: Run it to verify it fails**

Run: `py -3.11 -m pytest tests/test_documind_groq_routing.py -k ChatProviderWiring -q`
Expected: FAIL — `self._chat = self._chat_llm()` is not in `__init__`

- [ ] **Step 7: Point the chat collaborators at the chat client**

In `backend/rag/documind_service.py` `__init__`, replace these three lines:

```python
        self._conversation_router = ConversationRouter(self._llm)
        self._category_predictor = CategoryPredictor(
            self._llm,
            allowed_categories=sorted(ALLOWED_CATEGORIES),
        )
```

with:

```python
        # One chat client shared by every collaborator that sees chat text.
        # PdfOcr keeps self._llm below: it is a vision path, and GroqChat
        # cannot accept the multimodal message list PdfOcr sends.
        self._chat = self._chat_llm()
        self._conversation_router = ConversationRouter(self._chat)
        self._category_predictor = CategoryPredictor(
            self._chat,
            allowed_categories=sorted(ALLOWED_CATEGORIES),
        )
```

Leave `self._pdf_ocr = PdfOcr(self._llm)` exactly as it is.

Then change the `llm` property so answer synthesis uses the chat client too:

```python
    @property
    def llm(self):
        """The chat client. AskOrchestrator reaches synthesis through this via
        its injected llm_getter, so CHAT_PROVIDER governs answers as well as
        routing. Falls back to the hosted client on instances built via
        __new__ in tests, which never set _chat."""
        return getattr(self, "_chat", None) or self._llm
```

- [ ] **Step 8: Run the wiring test**

Run: `py -3.11 -m pytest tests/test_documind_groq_routing.py -k ChatProviderWiring -q`
Expected: PASS (3 tests)

- [ ] **Step 9: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: 513 passed, 0 failed

If any pre-existing test fails here, it is almost certainly one that sets
`service._llm` on a `__new__` instance and expects `service.llm` to return it.
The `getattr(self, "_chat", None) or self._llm` fallback is what keeps those
working — do not remove it.

- [ ] **Step 10: Commit**

```bash
git add backend/rag/documind_service.py backend/tests/test_documind_groq_routing.py
git commit -m "feat(documind): route chat to Groq behind CHAT_PROVIDER"
```

---

## Manual verification (after all tasks)

Not a task — run once at the end, against live data, with the backend importable:

```bash
cd backend
PYTHONIOENCODING=utf-8 py -3.11 -c "
import asyncio
from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv(usecwd=True))
from models.documind_models import AskRequest
from rag.documind_service import DocuMindService
s = DocuMindService()
r = asyncio.run(s.ask_documind(
    AskRequest(property_id='zHesu7tDJsNFhl3En2is',
               question='When does the tenancy agreement end?'),
    'B294sd0lrTUL5JHXst4gAHAtpFQ2'))
print(r.answer)
"
```

**Expected:** the answer states **31 October 2026**. Before this plan it says the
end date "is not specified in the provided document excerpts".

Then set `CHAT_PROVIDER=groq` in `backend/.env` and re-run: the answer should be
equivalent, and startup should log `🔄 Chat routed to Groq`.
