# Cite Extracted Facts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When an answer's value comes from a document's extracted facts rather than a retrieved excerpt, say so in the citations — instead of listing pages that do not contain it.

**Architecture:** `Citation` gains a `source` discriminator (`"excerpt"` default, `"extracted_facts"`). The ask orchestrator emits one extra citation per fact-contributing document, carrying the rendered fact lines as its snippet and no page number. Flutter renders those distinctly.

**Tech Stack:** Python 3.11 / FastAPI / pytest on the backend; Flutter / Dart / flutter_test on the client.

## Why

Fact-aware answering (plan `2026-08-05-fact-aware-answering-and-groq-chat.md`) lets DocuMind answer "the tenancy ends 31 October 2026" from `extracted_facts`. Retrieval still returns pages 8, 2 and 6 — none of which state that date — and those are what the citation strip shows. A landlord tapping a citation to verify the date does not find it. The answer is correct; its provenance is not.

## Global Constraints

- Backend: run from `backend/` with `py -3.11 -m pytest tests/ -q`. **Baseline: 515 passed, 0 failed.**
- Flutter: run from `residex_app/` with `flutter test`. **Baseline: 235 passed, 1 failed** — `test/widget_test.dart` "Counter increments smoke test" is a pre-existing boilerplate failure. It must stay at exactly 1 failure; never "fix" it as part of this work.
- There is **no venv**; system Python 3.11 is the only environment.
- Prefix piped Python commands with `PYTHONIOENCODING=utf-8` (emoji startup logs vs Windows cp1252).
- `source` must default to `"excerpt"` on both sides so an older client and a newer server interoperate.
- Citation snippets are deliberately **not** PII-scrubbed — the existing convention (`ask_orchestrator.py:557-559`) is that citations go to the landlord, who owns the documents; only text bound for the hosted LLM is scrubbed. Keep that.
- Never `git add -A`. Commit the explicit paths each task names.
- Do not modify `backend/scripts/diagnose_ayer8_lease.py`, `backend/scripts/fix_ayer8_lease_facts.py`, `backend/rexAI.txt`, or `demo_documents/`.

---

### Task 1: Carry doc_id and expose a per-document snippet

**Files:**
- Modify: `backend/rag/ask/fact_context.py`
- Modify: `backend/rag/documind_service.py` (`_get_document_facts`)
- Modify: `backend/tests/test_document_facts_lookup.py`
- Test: `backend/tests/test_fact_context.py`

**Interfaces:**
- Produces: `facts_snippet(facts: dict) -> str` — the same rendered lines `build_facts_block` uses for one document, without the filename header. `""` when nothing renders.
- Produces (changed): `DocuMindService._get_document_facts(doc_ids)` now returns `list[tuple[str, str, Optional[str], dict]]` = `(doc_id, filename, unit_label, facts)`. **This is a breaking shape change** — the only consumer is `ask_orchestrator.py`, updated in Task 2, plus the tests updated here.
- `build_facts_block` keeps its existing `(filename, unit_label, facts)` signature unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_fact_context.py`:

```python
class TestFactsSnippet:
    def test_renders_the_same_lines_without_a_filename_header(self):
        from rag.ask.fact_context import facts_snippet
        snippet = facts_snippet({"lease_end": "2026-10-31", "monthly_rent": 8000.0})
        assert "Lease end: 2026-10-31" in snippet
        assert "Monthly rent (RM): 8000.0" in snippet
        assert "[" not in snippet  # no document header

    def test_empty_facts_give_empty_string(self):
        from rag.ask.fact_context import facts_snippet
        assert facts_snippet({}) == ""

    def test_skips_structured_and_blank_values_like_the_block_does(self):
        from rag.ask.fact_context import facts_snippet
        snippet = facts_snippet({
            "amount": 120.0, "expense_lines": [{"a": 1}], "note": None,
        })
        assert "Amount (RM): 120.0" in snippet
        assert "Expense lines" not in snippet
        assert "Note" not in snippet
```

In `backend/tests/test_document_facts_lookup.py`, update the three shape assertions to expect the doc_id first:

```python
    def test_returns_doc_id_filename_unit_label_and_facts(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": "Unit A",
                   "extracted_facts": {"lease_end": "2026-10-31"}},
        })
        assert service._get_document_facts(["d1"]) == [
            ("d1", "lease.pdf", "Unit A", {"lease_end": "2026-10-31"}),
        ]
```

```python
        result = service._get_document_facts(["d1", "d2", "d1"])
        assert [row[1] for row in result] == ["a.pdf", "b.pdf"]
```

```python
        assert service._get_document_facts(["d1", "d2"]) == [
            ("d2", "ok.pdf", None, {"amount": 5}),
        ]
```

(Rename the first test from `test_returns_filename_unit_label_and_facts`; leave the other three tests in that file untouched.)

- [ ] **Step 2: Run to verify they fail**

Run: `py -3.11 -m pytest tests/test_fact_context.py tests/test_document_facts_lookup.py -q`
Expected: FAIL — `ImportError: cannot import name 'facts_snippet'` and tuple-shape mismatches.

- [ ] **Step 3: Extract the shared renderer**

In `backend/rag/ask/fact_context.py`, replace the body of `build_facts_block`'s line-building with a call to a new shared helper, and add the public snippet function:

```python
def _render_lines(facts: dict) -> list[str]:
    """The value lines for one document, shared by the prompt block and the
    citation snippet so the two can never drift apart.

    Structured values (expense_lines is a list[dict]) are skipped: a raw
    Python repr would inject hundreds of tokens of literal into every
    prompt that retrieves the document. Those rows already reach the
    model through the excerpts and the finance engine; this is for
    the scalar facts retrieval keeps losing.
    """
    return [
        f"    - {_label(key)}: {value}"
        for key, value in sorted(facts.items())
        if value is not None and value != "" and not isinstance(value, (list, dict))
    ]


def facts_snippet(facts: dict) -> str:
    """The rendered values for a single document, with no filename header —
    what a citation shows so the landlord sees the value being cited."""
    return "\n".join(line.strip() for line in _render_lines(facts))


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
        lines = _render_lines(facts)
        if not lines:
            continue
        scope = unit_label or "Property-wide"
        sections.append(f"[{filename} — {scope}]\n" + "\n".join(lines))
    return "\n\n".join(sections)
```

- [ ] **Step 4: Return doc_id from the lookup**

In `backend/rag/documind_service.py`, change the final append in `_get_document_facts`:

```python
            rows.append((doc_id, data.get('filename') or doc_id, data.get('unit_label'), facts))
```

and update its docstring's first line to:

```python
        """(doc_id, filename, unit_label, facts) for each doc_id that has facts.
```

- [ ] **Step 5: Run to verify they pass**

Run: `py -3.11 -m pytest tests/test_fact_context.py tests/test_document_facts_lookup.py -q`
Expected: PASS (13 + 6 tests)

- [ ] **Step 6: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: **FAILURES in `test_documind_service_flows.py`** — `ask_orchestrator` still unpacks 3-tuples. That is correct and expected at this point; Task 2 fixes it. Record which tests fail so Task 2 can confirm it fixed exactly those.

- [ ] **Step 7: Do NOT commit yet**

This task leaves the tree red on purpose — the shape change and its only consumer must land together. Proceed straight to Task 2 and commit once, at the end of Task 2.

---

### Task 2: Emit a citation for the extracted facts

**Files:**
- Modify: `backend/models/documind_models.py` (`Citation`)
- Modify: `backend/rag/ask/ask_orchestrator.py`
- Test: `backend/tests/test_documind_service_flows.py`

**Interfaces:**
- Consumes: `facts_snippet` and the 4-tuple `_get_document_facts` from Task 1
- Produces: `Citation.source: str = "excerpt"`; fact citations carry `source="extracted_facts"`, `page=None`, `score=1.0`

- [ ] **Step 1: Write the failing test**

Append to the `FactContextInjectionTests` class in `backend/tests/test_documind_service_flows.py`:

```python
    async def test_facts_answer_is_cited_as_extracted(self):
        fake_db, fake_graph = self._fixtures()
        fake_llm = _FakeLLM("Ends 31 October 2026.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        extracted = [c for c in response.citations if c.source == "extracted_facts"]
        self.assertEqual(len(extracted), 1)
        self.assertEqual(extracted[0].doc_id, "d-lease")
        self.assertEqual(extracted[0].filename, "ayer8-lease.pdf")
        self.assertIsNone(extracted[0].page)
        self.assertEqual(extracted[0].unit_label, "Unit B2-1-2")
        # The snippet shows the value being cited, so the strip is verifiable.
        self.assertIn("Lease end: 2026-10-31", extracted[0].snippet)
        # Page citations survive alongside it and keep the default source.
        self.assertTrue(any(c.source == "excerpt" for c in response.citations))

    async def test_no_extracted_citation_when_no_facts(self):
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {}
        fake_llm = _FakeLLM("No facts.")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        self.assertEqual([c for c in response.citations if c.source == "extracted_facts"], [])

    async def test_extracted_citation_snippet_is_not_scrubbed(self):
        # Citations go to the landlord, who owns the documents; only text bound
        # for the hosted LLM is scrubbed.
        fake_db, fake_graph = self._fixtures()
        fake_db.docs[0]["extracted_facts"] = {"tenant_nric": "661214055049"}
        fake_llm = _FakeLLM("ok")
        service = _build_service(fake_db, _FakeConversationStore(), fake_graph, fake_llm)

        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        response = await service.ask_documind(payload, "l1")

        extracted = [c for c in response.citations if c.source == "extracted_facts"]
        self.assertIn("661214055049", extracted[0].snippet)
        self.assertIn("[NRIC]", fake_llm.last_prompt)
```

- [ ] **Step 2: Run to verify it fails**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py -k FactContextInjection -q`
Expected: FAIL — `Citation` has no attribute `source`.

- [ ] **Step 3: Add the discriminator**

In `backend/models/documind_models.py`, add to `Citation` after `unit_label`:

```python
    source: str = "excerpt"  # "excerpt" | "extracted_facts"
```

- [ ] **Step 4: Keep the fact rows for citation building**

In `backend/rag/ask/ask_orchestrator.py`, replace the facts block assembly with:

```python
        facts_block = ""
        fact_rows = []
        if self._get_document_facts is not None:
            try:
                doc_ids = list(dict.fromkeys(c['doc_id'] for c in retrieved_chunks))
                fact_rows = list(self._get_document_facts(doc_ids))
                facts_block = scrub_for_hosted(
                    build_facts_block([(f, u, fa) for _, f, u, fa in fact_rows])
                )
            except Exception as e:
                print(f"WARNING: facts block unavailable, answering from excerpts only: {e}")
                facts_block = ""
                fact_rows = []
```

Extend the import at the top of the file:

```python
from rag.ask.fact_context import build_facts_block, facts_snippet
```

- [ ] **Step 5: Emit the citations**

In the same file, immediately after the `citations = [...]` list comprehension, insert:

```python
        # A value answered from extracted facts is not on any page we retrieved
        # — citing only those pages would send a landlord to verify a date that
        # is not there. Cite the facts themselves, page-less, with the value in
        # the snippet. Category and unit come from the chunk that pulled the
        # document in, so the badge matches the page citations beside it.
        chunk_meta = {
            c['doc_id']: (normalize_category(c['category']), c.get('unit_id'), c.get('unit_label'))
            for c in retrieved_chunks
        }
        for doc_id, filename, unit_label, facts in fact_rows:
            snippet = facts_snippet(facts)
            if not snippet:
                continue
            category, unit_id, chunk_unit_label = chunk_meta.get(doc_id, ('other', None, None))
            citations.insert(0, Citation(
                doc_id=doc_id,
                filename=filename,
                category=category,
                page=None,
                snippet=snippet,
                score=1.0,
                unit_id=unit_id,
                unit_label=unit_label or chunk_unit_label,
                source="extracted_facts",
            ))
```

- [ ] **Step 6: Run the task's tests**

Run: `py -3.11 -m pytest tests/test_documind_service_flows.py -k FactContextInjection -q`
Expected: PASS (8 tests)

- [ ] **Step 7: Run the full backend suite**

Run: `py -3.11 -m pytest tests/ -q`
Expected: **521 passed, 0 failed** (515 + 3 snippet + 3 citation). The Task 1 failures must all be gone.

- [ ] **Step 8: Commit Tasks 1 and 2 together**

```bash
git add backend/rag/ask/fact_context.py backend/rag/documind_service.py backend/models/documind_models.py backend/rag/ask/ask_orchestrator.py backend/tests/test_fact_context.py backend/tests/test_document_facts_lookup.py backend/tests/test_documind_service_flows.py
git commit -m "fix(documind): cite extracted facts as their own source"
```

---

### Task 3: Render extracted-fact citations in the app

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/documind_document.dart` (`Citation`, line 68)
- Modify: `residex_app/lib/features/landlord/data/models/documind_models.dart` (`CitationModel`, line 133)
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (`_buildCitationLine`, line 309)
- Test: `residex_app/test/features/landlord/documind_citation_test.dart` (create)

**Interfaces:**
- Consumes: the JSON field `source` produced by Task 2
- Produces: nothing downstream

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/documind_citation_test.dart`:

```dart
// A citation whose value came from extracted facts must not claim a page.
// Showing "p.—" beside a filename reads as a missing page number; the point
// is to say the value came from the document's parsed details instead.
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/documind_models.dart';

void main() {
  group('CitationModel.source', () {
    test('defaults to excerpt when the server omits it', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1', 'filename': 'lease.pdf', 'category': 'lease',
        'page': 3, 'snippet': 'text', 'score': 0.9,
      });
      expect(c.source, 'excerpt');
      expect(c.isExtractedFacts, isFalse);
    });

    test('parses extracted_facts and exposes it as a flag', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1', 'filename': 'lease.pdf', 'category': 'lease',
        'page': null, 'snippet': 'Lease end: 2026-10-31', 'score': 1.0,
        'source': 'extracted_facts',
      });
      expect(c.source, 'extracted_facts');
      expect(c.isExtractedFacts, isTrue);
      expect(c.page, isNull);
    });

    test('round-trips source through toJson', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1', 'filename': 'lease.pdf', 'category': 'lease',
        'snippet': 's', 'score': 1.0, 'source': 'extracted_facts',
      });
      expect(c.toJson()['source'], 'extracted_facts');
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run from `residex_app/`: `flutter test test/features/landlord/documind_citation_test.dart`
Expected: FAIL — `CitationModel` has no `source` / `isExtractedFacts`.

- [ ] **Step 3: Add the field to the entity**

In `documind_document.dart`, add to `Citation` after `unitLabel` (line 80) and to its constructor:

```dart
  /// 'excerpt' (a retrieved page) | 'extracted_facts' (values parsed at
  /// upload). Facts answer questions no retrieved page states, so citing a
  /// page for them would send the landlord somewhere the value is not.
  final String source;
```

constructor parameter: `this.source = 'excerpt',`

Add a convenience getter inside the class:

```dart
  bool get isExtractedFacts => source == 'extracted_facts';
```

- [ ] **Step 4: Parse it in the model**

In `documind_models.dart`, add the field, constructor parameter `this.source = 'excerpt',`, the `fromJson` line, and the `toJson` entry:

```dart
  final String source;
```
```dart
      source: json['source'] as String? ?? 'excerpt',
```
```dart
      'source': source,
```

Add the same getter to `CitationModel`:

```dart
  bool get isExtractedFacts => source == 'extracted_facts';
```

- [ ] **Step 5: Render it distinctly**

In `documind_screen.dart` `_buildCitationLine`, replace the page `Text` widget (line 347-353) with:

```dart
            Text(
              citation.isExtractedFacts
                  ? ' · extracted'
                  : ' · p.${citation.page ?? '—'}',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
```

Then wrap the existing `Row` so an extracted citation also shows its values. Replace `child: Row(` with `child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(` … and after the closing `)` of the Row, before the Padding's closing, add:

```dart
            if (citation.isExtractedFacts && citation.snippet.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 8),
                child: Text(
                  citation.snippet,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
```

Keep the `InkWell.onTap` unchanged — tapping still opens the document, which is correct: the landlord can read the whole agreement.

- [ ] **Step 6: Run the task's test**

Run: `flutter test test/features/landlord/documind_citation_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Run the full Flutter suite**

Run: `flutter test`
Expected: 238 passed, **1 failed** — the pre-existing `widget_test.dart` boilerplate failure and nothing else.

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/documind_document.dart residex_app/lib/features/landlord/data/models/documind_models.dart residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart residex_app/test/features/landlord/documind_citation_test.dart
git commit -m "feat(documind): show extracted-fact citations as their own source"
```

---

## Manual verification (after all tasks)

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
for c in r.citations:
    print(f'  [{c.source}] {c.filename} p.{c.page} :: {c.snippet[:60]}')
"
```

**Expected:** one `extracted_facts` citation whose snippet contains `Lease end: 2026-10-31`, listed alongside the `excerpt` citations for pages 8, 2 and 6.
