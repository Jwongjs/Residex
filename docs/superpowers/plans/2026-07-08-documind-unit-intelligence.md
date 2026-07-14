# DocuMind Unit Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make units visible to everything that reasons over documents — unit-aware citations, an honest-unknown category predictor, a unit-ambiguity clarification checkpoint, a lease-upload unit nudge, and unit-lifecycle hygiene (unassign-on-delete, live labels, PDF-only picker).

**Architecture:** Backend is a FastAPI + Firestore RAG service (`backend/`): `HybridRetriever` (dense + rerank) feeds `DocuMindService.ask_documind`, orchestrated by a LangGraph `DocuMindGraphOrchestrator` with a Firestore-backed `ConversationStore` for checkpoint state. Frontend is a Flutter app (`residex_app/`) using Riverpod providers and a clean datasource->repository->usecase->provider layering. All changes are additive; the two-axis model (unit filter = unit docs **plus** property-wide docs) is extended, not redesigned.

**Tech Stack:** Python 3.11, FastAPI, pydantic v2 (use `model_dump()`), LangGraph, Firestore, pytest/unittest; Flutter 3 with Riverpod 2, dash_chat_2, flutter_test.

**Source spec:** `docs/superpowers/specs/2026-07-06-documind-unit-intelligence-design.md` (Phases 1, 2, 3, 4, 6).

**Out of scope:** Phase 5 (fact extraction + expiry surfacing) has its own spec (`docs/superpowers/specs/2026-07-06-documind-fact-extraction-design.md`) and gets its own plan. Also out: DOCX ingestion, new categories, push notifications, editing extracted facts, OCR, tenant-side work.

## Global Constraints

- Two-axis model unchanged: `unit_id` stays optional on any document; a unit filter always returns that unit's docs **plus** property-wide docs (`unit_id` absent or `None`).
- Pre-units records (no `unit_id`/`unit_label` key at all) must flow through every new code path as `None` -> property-wide. No special-casing, no migration.
- All new API fields are optional/additive with defaults (`Citation.unit_id/unit_label = None`, `AskResponse.needs_unit_clarification = False`, `AskResponse.unit_options = []`).
- Backend ingestion is PDF-only (`PyPDFLoader`, stored as `application/pdf`); the upload picker must match: error copy is exactly `"Only PDF files are supported."`
- Category predictor must never return `available_categories[0]` as a guess; the no-signal reason string is exactly `"no clear category signal"`.
- Unit checkpoint actions are `unit:<unit_id>` and `unit:all`; the sentinel option is exactly `{unit_id: "all", unit_label: "All units"}` appended last. Unit ids are case-sensitive Firestore ids — never lowercase them.
- Lease-nudge subtitle copy is exactly `"Leases usually belong to a specific unit"`; unit-delete dialog copy pattern is `"N document(s) assigned to this unit will be kept as property-wide documents."`
- No emoji in user-facing UI copy — use icon glyphs (existing app convention).
- `flutter analyze` must stay at its 0-error baseline.
- Backend tests import heavy modules (sentence_transformers, Firestore client at module import) — a pytest invocation takes ~1.5-3 minutes even for one test. Use generous timeouts (>= 300 s) and don't interpret slow startup as a hang. Run backend tests from `backend/` so `main`/`rag`/`models` imports resolve.

---

### Task 1: Repair the service-flow test harness (fake hybrid retriever)

`backend/tests/test_documind_service_flows.py` has a **pre-existing failure**: `_build_service` constructs `DocuMindService` via `__new__` but never sets `_hybrid_retriever`, so every retrieval-path test hits `AttributeError` (swallowed by the service's try/except, returning the "couldn't search" response). `test_confirm_uses_pending_predicted_categories_for_retrieval` and `test_override_category_uses_override_in_retrieval` fail today. Every later backend task builds on this harness, so fix it first.

**Files:**
- Modify: `backend/tests/test_documind_service_flows.py`

**Interfaces:**
- Produces: `_FakeHybridRetriever` with `async retrieve(question, landlord_id, property_id, top_k=4, categories=None, unit_id=None) -> list[dict]` and a `calls: list[dict]` recorder (keys `question`, `categories`, `unit_id`). `_build_service(...)` now sets `service._hybrid_retriever = _FakeHybridRetriever(fake_db)`. Later tasks assert on `service._hybrid_retriever.calls`.

- [ ] **Step 1: Confirm the current failures**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -q`
Expected: FAIL — `test_confirm_uses_pending_predicted_categories_for_retrieval` (asserts 1 citation, gets 0) and `test_override_category_uses_override_in_retrieval` (asserts `last_chunk_category_filter`, gets `None`), with stdout showing `Hybrid retrieval failed: 'DocuMindService' object has no attribute '_hybrid_retriever'`.

- [ ] **Step 2: Add the fake retriever and inject it**

In `backend/tests/test_documind_service_flows.py`, add after the `_FakeGraphOrchestrator` class:

```python
class _FakeHybridRetriever:
    """Stands in for HybridRetriever: filters the _FakeDB chunk fixtures the
    same way the real retriever's dense search + unit post-filter would, and
    records every call so tests can assert on question/categories/unit_id."""

    def __init__(self, db):
        self._db = db
        self.calls = []

    async def retrieve(self, question, landlord_id, property_id, top_k=4,
                       categories=None, unit_id=None):
        self.calls.append({
            "question": question,
            "categories": categories,
            "unit_id": unit_id,
        })

        rows = [
            dict(row) for row in self._db.chunks
            if row.get("landlord_id") == landlord_id
            and row.get("property_id") == property_id
        ]
        if categories:
            if len(categories) == 1:
                self._db.last_chunk_category_filter = ("==", categories[0])
            else:
                self._db.last_chunk_category_filter = ("in", categories[:10])
            rows = [row for row in rows if row.get("category") in categories]
        if unit_id:
            rows = [row for row in rows if row.get("unit_id") in (None, unit_id)]

        for rank, row in enumerate(rows):
            row.setdefault("rerank_score", 0.9 - rank * 0.05)
        return rows[:top_k]
```

Then update `_build_service` to inject it:

```python
def _build_service(fake_db, fake_store, fake_graph, fake_llm):
    service = DocuMindService.__new__(DocuMindService)
    service._db = fake_db
    service._embeddings = _FakeEmbeddings()
    service._llm = fake_llm
    service._conversation_store = fake_store
    service._graph_orchestrator = fake_graph
    service._hybrid_retriever = _FakeHybridRetriever(fake_db)
    return service
```

- [ ] **Step 3: Run the suite to verify it is green**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -q`
Expected: PASS (all tests, including the two that failed in Step 1).

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_documind_service_flows.py
git commit -m "test: inject fake hybrid retriever into service-flow test harness" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Retriever propagates unit_label (Phase 1, backend)

`HybridRetriever._dense_search` maps Firestore chunks to result dicts and already carries `unit_id` ([retriever.py:99](backend/rag/retriever.py#L99)) but drops `unit_label`. Citations and LLM context headers need it.

**Files:**
- Modify: `backend/rag/retriever.py` (the `results.append({...})` mapping in `_dense_search`)
- Test: `backend/tests/test_retriever.py`

**Interfaces:**
- Produces: every dict returned by `HybridRetriever.retrieve` gains key `'unit_label': str | None` (missing key on old chunks -> `None`). Task 3's citation builder consumes `chunk.get('unit_label')`.

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_retriever.py` (not async — `_dense_search` is sync):

```python
def test_dense_search_propagates_unit_id_and_label():
    """_dense_search's result mapping must carry unit_id AND unit_label from
    the Firestore chunk; chunks ingested before units existed (no keys at
    all) yield None for both."""
    mock_db = MagicMock()
    mock_embeddings = MagicMock()
    retriever = HybridRetriever(db=mock_db, embeddings=mock_embeddings)

    rows = [
        {'doc_id': 'd0', 'filename': 'leaseA.pdf', 'category': 'lease', 'page': 1,
         'unit_id': 'unit-A', 'unit_label': 'Unit A', 'text': 'unit A lease', 'embedding': None},
        {'doc_id': 'd1', 'filename': 'old.pdf', 'category': 'utility', 'page': 2,
         'text': 'pre-units chunk', 'embedding': None},
    ]
    fake_docs = []
    for row in rows:
        doc = MagicMock()
        doc.to_dict.return_value = row
        fake_docs.append(doc)
    query = mock_db.collection.return_value.where.return_value.where.return_value
    query.find_nearest.return_value.stream.return_value = fake_docs

    results = retriever._dense_search([0.1, 0.2, 0.3], 'landlord_1', 'property_1', categories=None, fetch_k=15)

    assert results[0]['unit_id'] == 'unit-A'
    assert results[0]['unit_label'] == 'Unit A'
    assert results[1]['unit_id'] is None
    assert results[1]['unit_label'] is None
```

(`embedding: None` deliberately routes `_cosine_score` through its rank-fallback path — a printed warning is expected, not a failure.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_retriever.py::test_dense_search_propagates_unit_id_and_label -q`
Expected: FAIL with `KeyError: 'unit_label'`.

- [ ] **Step 3: Implement**

In `backend/rag/retriever.py`, in `_dense_search`, change the `results.append({...})` mapping to include `unit_label` right after `unit_id`:

```python
            results.append({
                'doc_id': chunk['doc_id'],
                'filename': chunk['filename'],
                'category': chunk['category'],
                'page': chunk.get('page'),
                'unit_id': chunk.get('unit_id'),
                'unit_label': chunk.get('unit_label'),
                'text': chunk['text'],
                'dense_score': dense_score,
            })
```

- [ ] **Step 4: Run the retriever suite**

Run: `cd backend && python -m pytest tests/test_retriever.py -q`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/retriever.py backend/tests/test_retriever.py
git commit -m "feat: propagate unit_label through hybrid retriever results" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Unit-aware Citation model + LLM context headers (Phase 1, backend)

Carry unit fields into the `Citation` response model and identify each excerpt's unit in the answer-synthesis context so the LLM can attribute per unit.

**Files:**
- Modify: `backend/models/documind_models.py` (the `Citation` class)
- Modify: `backend/rag/documind_service.py` (citation builder + context header, currently lines 607-635)
- Test: `backend/tests/test_documind_service_flows.py`

**Interfaces:**
- Consumes: `chunk.get('unit_id')` / `chunk.get('unit_label')` from Task 2's retriever results.
- Produces: `Citation` gains `unit_id: str | None = None` and `unit_label: str | None = None`. Context excerpt headers become `[Document N: <filename>, Page <P> — <unit_label>]` or `... — Property-wide]`. `_FakeLLM` gains `last_prompt` recording (used again in later tasks).

- [ ] **Step 1: Extend the fake LLM to record prompts**

In `backend/tests/test_documind_service_flows.py`, replace the `_FakeLLM` class with:

```python
class _FakeLLM:
    def __init__(self, content: str):
        self._content = content
        self.last_prompt = None

    def invoke(self, prompt: str):
        self.last_prompt = prompt
        return _LLMResponse(self._content)
```

- [ ] **Step 2: Write the failing test**

Add to the `DocuMindServiceFlowTests` class:

```python
    async def test_citations_and_context_carry_unit_fields(self):
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}],
            chunks=[
                {"doc_id": "d1", "filename": "leaseA.pdf", "category": "lease", "page": 2,
                 "unit_id": "unit-A", "unit_label": "Unit A",
                 "text": "Unit A tenancy ends 31 December 2026.",
                 "landlord_id": "l1", "property_id": "p1"},
                {"doc_id": "d2", "filename": "insurance.pdf", "category": "insurance", "page": 0,
                 "text": "Building insurance covers fire damage.",
                 "landlord_id": "l1", "property_id": "p1"},
            ],
        )
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": [],
            "intent": "document_question",
        })
        fake_llm = _FakeLLM("The tenancy ends 31 December 2026.")
        service = _build_service(fake_db, fake_store, fake_graph, fake_llm)

        payload = AskRequest(landlord_id="l1", property_id="p1", question="when does the lease end")
        response = await service.ask_documind(payload)

        citations_by_doc = {c.doc_id: c for c in response.citations}
        self.assertEqual(citations_by_doc["d1"].unit_id, "unit-A")
        self.assertEqual(citations_by_doc["d1"].unit_label, "Unit A")
        self.assertIsNone(citations_by_doc["d2"].unit_id)
        self.assertIsNone(citations_by_doc["d2"].unit_label)
        self.assertIn("— Unit A]", fake_llm.last_prompt)
        self.assertIn("— Property-wide]", fake_llm.last_prompt)
```

(Only one distinct non-null unit here, so this test stays valid after Task 8's ambiguity checkpoint lands.)

- [ ] **Step 3: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py::DocuMindServiceFlowTests::test_citations_and_context_carry_unit_fields -q`
Expected: FAIL with `AttributeError: 'Citation' object has no attribute 'unit_id'` (pydantic models reject unknown attribute access).

- [ ] **Step 4: Implement the model fields**

In `backend/models/documind_models.py`, extend `Citation`:

```python
class Citation(BaseModel):
    """Citation for a retrieved document chunk"""
    doc_id: str
    filename: str
    category: str
    page: int | None = None
    snippet: str  # First 200 chars of chunk
    score: float  # Relevance score (0.0 - 1.0)
    unit_id: str | None = None  # None = property-wide source
    unit_label: str | None = None  # Denormalized label captured at ingest
```

- [ ] **Step 5: Implement the citation builder + context header**

In `backend/rag/documind_service.py`, inside `ask_documind`'s citation loop, extend the `best_citation_by_page[page_key]` entry and the context line:

```python
            if existing is None or chunk_score > existing['score']:
                best_citation_by_page[page_key] = {
                    'doc_id': chunk['doc_id'],
                    'filename': chunk['filename'],
                    'category': chunk['category'],
                    'page': display_page,
                    'snippet': chunk['text'][:200],
                    'score': chunk_score,
                    'unit_id': chunk.get('unit_id'),
                    'unit_label': chunk.get('unit_label'),
                }
            unit_context = chunk.get('unit_label') or 'Property-wide'
            context_text += f"\n\n[Document {i+1}: {chunk['filename']}, Page {display_page if display_page is not None else 'N/A'} — {unit_context}]\n{chunk['text']}"
```

And the `Citation(...)` construction:

```python
        citations = [
            Citation(
                doc_id=c['doc_id'],
                filename=c['filename'],
                category=c['category'],
                page=c['page'],
                snippet=c['snippet'],
                score=c['score'],
                unit_id=c['unit_id'],
                unit_label=c['unit_label'],
            )
            for c in sorted(best_citation_by_page.values(), key=lambda c: c['score'], reverse=True)
        ]
```

- [ ] **Step 6: Run the flow suite**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -q`
Expected: PASS (all tests).

- [ ] **Step 7: Commit**

```bash
git add backend/models/documind_models.py backend/rag/documind_service.py backend/tests/test_documind_service_flows.py
git commit -m "feat: carry unit id/label into citations and LLM context headers" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Flutter citation unit badge (Phase 1, Flutter)

Parse the new citation fields and render a unit badge on the citation line, matching the Docs-tab badge style.

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/documind_document.dart` (`Citation` entity)
- Modify: `residex_app/lib/features/landlord/data/models/documind_models.dart` (`CitationModel` + `DocuMindAnswerModel.toEntity`)
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (`_buildCitationLine`)
- Test: `residex_app/test/features/landlord/documind_citation_model_test.dart` (create)
- Test: `residex_app/test/features/landlord/documind_screen_checkpoint_action_test.dart` (extend)

**Interfaces:**
- Consumes: backend JSON keys `unit_id` / `unit_label` on each citation (Task 3).
- Produces: `Citation` entity and `CitationModel` gain `final String? unitId; final String? unitLabel;` (optional constructor params `this.unitId, this.unitLabel`). Task 9's widget test and Task 13's label resolution consume these.

- [ ] **Step 1: Write the failing model test**

Create `residex_app/test/features/landlord/documind_citation_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/documind_models.dart';

void main() {
  test('CitationModel.fromJson parses unit fields', () {
    final model = CitationModel.fromJson({
      'doc_id': 'doc-1',
      'filename': 'leaseA.pdf',
      'category': 'lease',
      'page': 3,
      'snippet': 'Tenancy ends 31 December 2026.',
      'score': 0.95,
      'unit_id': 'unit-a',
      'unit_label': 'Unit A',
    });

    expect(model.unitId, 'unit-a');
    expect(model.unitLabel, 'Unit A');
  });

  test('CitationModel.fromJson defaults unit fields to null (pre-units responses)', () {
    final model = CitationModel.fromJson({
      'doc_id': 'doc-1',
      'filename': 'old.pdf',
      'category': 'utility',
      'snippet': 'water bill',
      'score': 0.5,
    });

    expect(model.unitId, isNull);
    expect(model.unitLabel, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/documind_citation_model_test.dart`
Expected: FAIL — compile error, `unitId` isn't defined for `CitationModel`.

- [ ] **Step 3: Implement entity and model**

In `residex_app/lib/features/landlord/domain/entities/documind_document.dart`, extend the `Citation` entity:

```dart
///Citation entity for Q&A responses
class Citation {
  final String docId;
  final String filename;
  final String category;
  final int? page;
  final String snippet;
  final double score;

  /// Unit the cited chunk belongs to; null = property-wide source.
  final String? unitId;

  /// Denormalized unit label captured at ingest (display fallback).
  final String? unitLabel;

  Citation({
    required this.docId,
    required this.filename,
    required this.category,
    this.page,
    required this.snippet,
    required this.score,
    this.unitId,
    this.unitLabel,
  });
}
```

In `residex_app/lib/features/landlord/data/models/documind_models.dart`, extend `CitationModel` the same way (fields `final String? unitId; final String? unitLabel;`, constructor params `this.unitId, this.unitLabel`), and:

```dart
  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      docId: json['doc_id'] as String? ?? '',
      filename: json['filename'] as String? ?? 'Unknown',
      category: json['category'] as String? ?? 'other',
      page: json['page'] as int?,
      snippet: json['snippet'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      unitId: json['unit_id'] as String?,
      unitLabel: json['unit_label'] as String?,
    );
  }
```

Add `'unit_id': unitId, 'unit_label': unitLabel,` to `CitationModel.toJson()`, and in `DocuMindAnswerModel.toEntity()` extend the citation mapping:

```dart
      citations: citations.map((c) => Citation(
        docId: c.docId,
        filename: c.filename,
        category: c.category,
        page: c.page,
        snippet: c.snippet,
        score: c.score,
        unitId: c.unitId,
        unitLabel: c.unitLabel,
      )).toList(),
```

- [ ] **Step 4: Run the model test**

Run: `cd residex_app && flutter test test/features/landlord/documind_citation_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing badge widget test**

Append to `residex_app/test/features/landlord/documind_screen_checkpoint_action_test.dart` (inside `main()`, reusing the existing imports and `Property` fixture pattern):

```dart
  testWidgets('DocuMind renders unit badge on citations', (tester) async {
    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? sessionId,
      int conversationTurn = 1,
      String? userAction,
    }) async {
      return DocuMindAnswer(
        answer: 'The lease ends 31 December 2026.',
        confidence: 0.9,
        citations: [
          Citation(
            docId: 'doc-1',
            filename: 'leaseA.pdf',
            category: 'lease',
            page: 3,
            snippet: 'Tenancy ends 31 December 2026.',
            score: 0.95,
            unitId: 'unit-a',
            unitLabel: 'Unit A',
          ),
        ],
        propertyName: 'Maple Residency',
        sessionId: 'session-badge',
        conversationTurn: 1,
      );
    }

    final testProperty = Property(
      id: 'prop-1',
      landlordId: 'landlord-1',
      name: 'Maple Residency',
      address: const PropertyAddress(
        street: '123 Main St',
        city: 'Kuala Lumpur',
        state: 'WP Kuala Lumpur',
        zipCode: '50000',
        country: 'Malaysia',
      ),
      type: PropertyType.apartment,
      purchasePrice: 500000,
      currentValue: 550000,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'when does the lease end?',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UNIT A'), findsOneWidget);
  });
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/documind_screen_checkpoint_action_test.dart`
Expected: FAIL — `find.text('UNIT A')` finds nothing (existing three tests still pass).

- [ ] **Step 7: Implement the citation badge**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, replace `_buildCitationLine` with:

```dart
  Widget _buildCitationLine(Citation citation) {
    return InkWell(
      onTap: () {
        if (_selectedPropertyId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              propertyId: _selectedPropertyId!,
              docId: citation.docId,
              filename: citation.filename,
              page: citation.page,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '${citation.filename} · p.${citation.page ?? '—'}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (citation.unitLabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  citation.unitLabel!.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 8: Run tests and analyzer**

Run: `cd residex_app && flutter test test/features/landlord/ && flutter analyze`
Expected: all tests PASS; analyze reports 0 errors.

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/documind_document.dart residex_app/lib/features/landlord/data/models/documind_models.dart "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart" residex_app/test/features/landlord/documind_citation_model_test.dart residex_app/test/features/landlord/documind_screen_checkpoint_action_test.dart
git commit -m "feat: show unit badge on chat citations" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Honest-unknown category predictor (Phase 2, backend)

Both predictor paths currently guess `available_categories[0]` when they have no signal ([category_predictor.py:55-58](backend/rag/category_predictor.py#L55-L58) and [:84-86](backend/rag/category_predictor.py#L84-L86)). Return an empty prediction instead.

**Files:**
- Modify: `backend/rag/category_predictor.py`
- Test: `backend/tests/test_documind_orchestration.py` (currently an **empty file** — this task creates its content)

**Interfaces:**
- Produces: `CategoryPredictor.predict` returns `{"predicted_categories": [], "confidence": 0.0, "reason": "no clear category signal"}` when neither the LLM parse nor keyword fallback finds a match. Task 6 depends on empty predictions reaching the orchestrator. The test file's `_FakeLLM`/`_LLMResponse` helpers are reused by Task 6 and Task 8.

- [ ] **Step 1: Write the failing tests**

Write `backend/tests/test_documind_orchestration.py` (replacing the empty file):

```python
import unittest

from rag.category_predictor import CategoryPredictor


class _LLMResponse:
    def __init__(self, content: str):
        self.content = content


class _FakeLLM:
    def __init__(self, content: str = "", raise_error: bool = False):
        self._content = content
        self._raise = raise_error

    def invoke(self, _prompt: str):
        if self._raise:
            raise RuntimeError("LLM unavailable")
        return _LLMResponse(self._content)


ALL_CATEGORIES = ["lease", "warranty", "insurance", "utility", "receipt"]


class CategoryPredictorHonestUnknownTests(unittest.TestCase):
    def test_unparseable_llm_output_returns_empty_prediction(self):
        predictor = CategoryPredictor(_FakeLLM("nonsense with no expected format"), ALL_CATEGORIES)

        result = predictor.predict("zzz qqq", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], [])
        self.assertEqual(result["confidence"], 0.0)
        self.assertEqual(result["reason"], "no clear category signal")

    def test_no_signal_keyword_fallback_returns_empty_prediction(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        result = predictor.predict("zzz qqq", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], [])
        self.assertEqual(result["confidence"], 0.0)
        self.assertEqual(result["reason"], "no clear category signal")

    def test_empty_prediction_is_independent_of_category_ordering(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        forward = predictor.predict("zzz qqq", ["lease", "warranty", "utility"])
        reversed_order = predictor.predict("zzz qqq", ["utility", "warranty", "lease"])

        self.assertEqual(forward["predicted_categories"], reversed_order["predicted_categories"])
        self.assertEqual(forward["predicted_categories"], [])

    def test_keyword_fallback_still_matches_real_signal(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        result = predictor.predict("when does the lease expire", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], ["lease"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_documind_orchestration.py -q`
Expected: FAIL — the first three tests get `["lease"]`/`["utility"]` (first available category) instead of `[]`; the last passes already.

- [ ] **Step 3: Implement**

In `backend/rag/category_predictor.py`, replace the LLM-parse default (the `if not predicted:` block) with:

```python
            if not predicted:
                return {
                    "predicted_categories": [],
                    "confidence": 0.0,
                    "reason": "no clear category signal",
                }
```

And in the keyword fallback, replace the `if not best:` default with:

```python
            best = [category for score, category in scored if score > 0]
            if not best:
                return {
                    "predicted_categories": [],
                    "confidence": 0.0,
                    "reason": "no clear category signal",
                }
```

(The matched-keyword return with `confidence: 0.55` stays as-is.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_documind_orchestration.py -q`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/category_predictor.py backend/tests/test_documind_orchestration.py
git commit -m "feat: category predictor returns honest unknown instead of first-category guess" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Orchestrator routes empty prediction to clarification (Phase 2, backend)

The graph's `_decide_action_node` only fires `ask_confirmation` when `predicted` is non-empty ([graph_orchestrator.py:150](backend/rag/graph_orchestrator.py#L150)) — exactly the gap the spec anticipated. An empty prediction for a document question must reach the category-clarification checkpoint, which already degrades gracefully to offering all available categories.

**Files:**
- Modify: `backend/rag/graph_orchestrator.py` (`_decide_action_node`, `_prepare_confirmation_node`)
- Test: `backend/tests/test_documind_orchestration.py` (extend)
- Test: `backend/tests/test_documind_service_flows.py` (extend)

**Interfaces:**
- Consumes: empty predictions from Task 5.
- Produces: graph action `ask_confirmation` whenever `available_categories` is non-empty and no explicit categories/checkpoint action apply — including `predicted_categories == []`. The `_FakeRouter`/`_FakePredictor` test helpers defined here are reused by Task 8.

- [ ] **Step 1: Write the failing orchestrator tests**

Append to `backend/tests/test_documind_orchestration.py`:

```python
from rag.graph_orchestrator import DocuMindGraphOrchestrator


class _FakeRouter:
    def route(self, text, recent_turns, property_name=None):
        return {
            "intent": "document_question",
            "rag_needed": True,
            "confidence": 0.9,
            "reason": "document question",
            "assistant_reply": "",
        }


class _FakePredictor:
    def __init__(self, result):
        self._result = result

    def predict(self, question, available_categories):
        return self._result


class GraphOrchestratorEmptyPredictionTests(unittest.IsolatedAsyncioTestCase):
    async def test_empty_prediction_routes_to_ask_confirmation(self):
        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor({
                "predicted_categories": [],
                "confidence": 0.0,
                "reason": "no clear category signal",
            }),
        )

        state = await orchestrator.run({
            "user_input": "zzz qqq",
            "explicit_categories": [],
            "available_categories": ["lease", "warranty"],
            "user_action": "",
            "recent_turns": [],
            "property_name": "Maple Residency",
        })

        self.assertEqual(state["action"], "ask_confirmation")
        self.assertEqual(state["predicted_categories"], [])

    async def test_no_available_categories_still_retrieves(self):
        # No uploaded docs at all: nothing to clarify against, fall through
        # to retrieve (which answers "no relevant documents").
        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor({
                "predicted_categories": [],
                "confidence": 0.0,
                "reason": "No uploaded categories for this property",
            }),
        )

        state = await orchestrator.run({
            "user_input": "when does the lease end",
            "explicit_categories": [],
            "available_categories": [],
            "user_action": "",
            "recent_turns": [],
            "property_name": "Maple Residency",
        })

        self.assertEqual(state["action"], "retrieve")
```

- [ ] **Step 2: Run tests to verify the new failure**

Run: `cd backend && python -m pytest tests/test_documind_orchestration.py -q`
Expected: FAIL — `test_empty_prediction_routes_to_ask_confirmation` gets `"retrieve"`; the other new test already passes.

- [ ] **Step 3: Implement the decision change**

In `backend/rag/graph_orchestrator.py`, in `_decide_action_node`, replace:

```python
        if predicted and available:
            return {**state, "action": "ask_confirmation"}
```

with:

```python
        if available:
            return {**state, "action": "ask_confirmation"}
```

And in `_prepare_confirmation_node`, give the empty-prediction case honest copy (the current template would read "search your the most relevant documents documents"):

```python
    async def _prepare_confirmation_node(self, state: DocuMindState) -> DocuMindState:
        predicted = state.get("predicted_categories", [])

        if predicted:
            prediction_label = ", ".join(predicted)
            message = (
                f"I am going to search your {prediction_label} documents to answer this accurately. "
                "Can you confirm, cancel, or choose another category?"
            )
        else:
            message = (
                "I couldn't tell which document category fits this question. "
                "Which category should I search?"
            )

        return {
            **state,
            "assistant_message": message,
        }
```

- [ ] **Step 4: Run the orchestration suite**

Run: `cd backend && python -m pytest tests/test_documind_orchestration.py -q`
Expected: PASS (all tests).

- [ ] **Step 5: Add the service-level degradation test**

Append to `DocuMindServiceFlowTests` in `backend/tests/test_documind_service_flows.py` (verifies the existing checkpoint builder offers **all** available categories when the prediction is empty):

```python
    async def test_empty_prediction_checkpoint_offers_all_available_categories(self):
        fake_db = _FakeDB(docs=[
            {"doc_id": "doc-1", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
            {"doc_id": "doc-2", "landlord_id": "l1", "property_id": "p1", "category": "warranty"},
        ])
        fake_store = _FakeConversationStore()
        fake_graph = _FakeGraphOrchestrator({
            "action": "ask_confirmation",
            "predicted_categories": [],
            "prediction_confidence": 0.0,
            "prediction_reason": "no clear category signal",
            "assistant_message": "Which category should I search?",
            "intent": "document_question",
        })
        service = _build_service(fake_db, fake_store, fake_graph, _FakeLLM("unused"))

        payload = AskRequest(landlord_id="l1", property_id="p1", question="zzz qqq")
        response = await service.ask_documind(payload)

        self.assertTrue(response.needs_category_clarification)
        self.assertEqual(response.clarification_options, ["lease", "warranty"])
        self.assertEqual(response.predicted_categories, [])
```

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -q`
Expected: PASS (this test needs no production change — it locks in the existing graceful degradation).

- [ ] **Step 6: Commit**

```bash
git add backend/rag/graph_orchestrator.py backend/tests/test_documind_orchestration.py backend/tests/test_documind_service_flows.py
git commit -m "feat: route empty category prediction to clarification checkpoint" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: UnitOption model + AskResponse unit-clarification fields (Phase 3, backend models)

Additive API surface for the unit-ambiguity checkpoint, plus serialization tests and the evaluation-harness scenario.

**Files:**
- Modify: `backend/models/documind_models.py`
- Test: `backend/tests/test_rex_routes_documind_ask_api.py` (extend)
- Test: `backend/tests/test_documind_evaluation.py` (extend — the spec's "one multi-unit ambiguity scenario")

**Interfaces:**
- Produces: `class UnitOption(BaseModel)` with `unit_id: str` and `unit_label: str`. `AskResponse` gains `needs_unit_clarification: bool = False` and `unit_options: List[UnitOption] = []`. `AskRequest.user_action` description documents `unit:<unit_id> | unit:all`. Task 8 constructs these; Task 9 parses their JSON (`needs_unit_clarification`, `unit_options[].unit_id/.unit_label`).

- [ ] **Step 1: Write the failing API serialization test**

In `backend/tests/test_rex_routes_documind_ask_api.py`, change the models import to `from models.documind_models import AskResponse, UnitOption` and add to `DocuMindAskApiTests`:

```python
    def test_documind_ask_serializes_unit_clarification_checkpoint(self):
        mocked_response = AskResponse(
            answer="That question matches documents from Unit A and Unit B. Which unit do you mean?",
            confidence=0.6,
            citations=[],
            property_name="Maple Residency",
            searched_categories=[],
            category_filter_mode="all",
            session_id="sess-42",
            conversation_turn=1,
            user_action_required=True,
            needs_unit_clarification=True,
            unit_options=[
                UnitOption(unit_id="unit-a", unit_label="Unit A"),
                UnitOption(unit_id="unit-b", unit_label="Unit B"),
                UnitOption(unit_id="all", unit_label="All units"),
            ],
        )

        with patch("api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)):
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "landlord_id": "landlord-1",
                    "property_id": "property-1",
                    "question": "when does the lease expire?",
                },
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["needs_unit_clarification"])
        self.assertEqual(
            [option["unit_id"] for option in data["unit_options"]],
            ["unit-a", "unit-b", "all"],
        )
        self.assertTrue(data["user_action_required"])
        self.assertEqual(data["citations"], [])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_ask_api.py -q`
Expected: FAIL with `ImportError: cannot import name 'UnitOption'`.

- [ ] **Step 3: Implement the models**

In `backend/models/documind_models.py`, add above `AskResponse`:

```python
class UnitOption(BaseModel):
    """One selectable unit in a unit-clarification checkpoint"""
    unit_id: str
    unit_label: str
```

In `AskResponse`, add after `action_reason`:

```python
    needs_unit_clarification: bool = Field(
        default=False,
        description="Whether frontend should ask user to choose a unit before answering",
    )
    unit_options: List[UnitOption] = Field(
        default_factory=list,
        description="Units whose documents matched; ends with sentinel {unit_id: 'all', unit_label: 'All units'}",
    )
```

In `AskRequest`, update the `user_action` field description to:

```python
    user_action: Optional[str] = Field(
        default=None,
        description="User response for checkpointed actions: confirm | cancel | override:<category> | unit:<unit_id> | unit:all"
    )
```

- [ ] **Step 4: Run the ask-API suite**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_ask_api.py -q`
Expected: PASS.

- [ ] **Step 5: Add the evaluation-harness scenario**

In `backend/tests/test_documind_evaluation.py`, change the models import to `from models.documind_models import AskResponse, Citation, UnitOption` and add to `DocuMindStructuralEvaluationTests`:

```python
    def test_multi_unit_ambiguity_checkpoint(self):
        """Multi-unit ambiguity: with no unit filter set, a question matching
        two units' documents must return a unit checkpoint (no blended
        answer, no citations) whose options end with the 'all' sentinel."""
        mocked_response = AskResponse(
            answer="That question matches documents from Unit A and Unit B. Which unit do you mean?",
            confidence=0.6,
            citations=[],
            property_name="Oakwood Apartments",
            searched_categories=["lease"],
            category_filter_mode="auto",
            session_id="sess-eval-5",
            conversation_turn=1,
            user_action_required=True,
            needs_unit_clarification=True,
            unit_options=[
                UnitOption(unit_id="unit-a", unit_label="Unit A"),
                UnitOption(unit_id="unit-b", unit_label="Unit B"),
                UnitOption(unit_id="all", unit_label="All units"),
            ],
            predicted_categories=["lease"],
            action_reason="Retrieved documents span multiple units",
        )

        with patch(
            "api.rex_routes.documind_service.ask_documind", new=AsyncMock(return_value=mocked_response)
        ) as mocked_ask:
            response = self.client.post(
                "/api/rex/documind/ask",
                json={
                    "landlord_id": "landlord-eval-5",
                    "property_id": "property-eval-5",
                    "question": "when does the lease expire?",
                    "session_id": "sess-eval-5",
                    "conversation_turn": 1,
                },
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["needs_unit_clarification"])
        self.assertTrue(data["user_action_required"])
        self.assertEqual(len(data["citations"]), 0)
        self.assertEqual(data["unit_options"][-1]["unit_id"], "all")
        self.assertEqual(data["unit_options"][-1]["unit_label"], "All units")

        mocked_ask.assert_awaited_once()
```

Run: `cd backend && python -m pytest tests/test_documind_evaluation.py -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/models/documind_models.py backend/tests/test_rex_routes_documind_ask_api.py backend/tests/test_documind_evaluation.py
git commit -m "feat: add UnitOption and unit-clarification fields to ask API models" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Unit-ambiguity checkpoint + resume in the service (Phase 3, backend)

A **post-retrieval** check in `ask_documind` (unit ambiguity is only knowable after seeing which units the retrieved chunks belong to), reusing the pending-confirmation machinery, plus `unit:*` resume handling in both the service dispatch and the graph (so a `unit:*` follow-up never re-enters the category checkpoint).

**Files:**
- Modify: `backend/rag/documind_service.py` (`ask_documind`)
- Modify: `backend/rag/graph_orchestrator.py` (`_route_conversation_node`, `_decide_action_node`)
- Test: `backend/tests/test_documind_service_flows.py` (extend)
- Test: `backend/tests/test_documind_orchestration.py` (extend)

**Interfaces:**
- Consumes: `UnitOption`, `AskResponse.needs_unit_clarification`/`unit_options` (Task 7); `chunk.get('unit_id')`/`chunk.get('unit_label')` (Tasks 1-2); `_FakeHybridRetriever.calls` (Task 1); `_FakeRouter`/`_FakePredictor` (Task 6).
- Produces: checkpoint fires when `payload.unit_id is None` AND `payload.user_action` is not a `unit:*` action AND retrieved chunks contain >= 2 distinct non-null `unit_id`s. Pending payload shape: `{"type": "unit", "question": <working_question>, "unit_options": [<UnitOption dicts>]}`. Resume actions: `unit:<unit_id>` (re-run pending question with that unit filter, id casing preserved) and `unit:all` (unfiltered, no re-check). Missing/expired pending -> the request is treated as a fresh question (existing fallback behavior).

- [ ] **Step 1: Write the failing graph test**

Append to `GraphOrchestratorEmptyPredictionTests` in `backend/tests/test_documind_orchestration.py`:

```python
    async def test_unit_action_routes_to_retrieve_without_new_checkpoint(self):
        orchestrator = DocuMindGraphOrchestrator(
            conversation_router=_FakeRouter(),
            category_predictor=_FakePredictor({
                "predicted_categories": ["lease"],
                "confidence": 0.8,
                "reason": "lease question",
            }),
        )

        state = await orchestrator.run({
            "user_input": "when does the lease expire?",
            "explicit_categories": [],
            "available_categories": ["lease"],
            "user_action": "unit:unit-A",
            "recent_turns": [],
            "property_name": "Maple Residency",
        })

        self.assertEqual(state["action"], "retrieve")
```

- [ ] **Step 2: Write the failing service tests**

Append a new test class to `backend/tests/test_documind_service_flows.py`:

```python
class DocuMindUnitClarificationTests(unittest.IsolatedAsyncioTestCase):
    def _multi_unit_db(self):
        return _FakeDB(
            docs=[
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
                {"doc_id": "doc-B", "landlord_id": "l1", "property_id": "p1", "category": "lease"},
            ],
            chunks=[
                {"doc_id": "doc-A", "filename": "leaseA.pdf", "category": "lease", "page": 1,
                 "unit_id": "unit-A", "unit_label": "Unit A",
                 "text": "Unit A tenancy ends 31 December 2026.",
                 "landlord_id": "l1", "property_id": "p1"},
                {"doc_id": "doc-B", "filename": "leaseB.pdf", "category": "lease", "page": 1,
                 "unit_id": "unit-B", "unit_label": "Unit B",
                 "text": "Unit B tenancy ends 30 June 2027.",
                 "landlord_id": "l1", "property_id": "p1"},
            ],
        )

    def _retrieve_graph(self):
        return _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["lease"],
            "prediction_reason": "lease question",
            "intent": "document_question",
        })

    def _unit_pending(self):
        return {
            "type": "unit",
            "question": "when does the lease expire?",
            "unit_options": [
                {"unit_id": "unit-A", "unit_label": "Unit A"},
                {"unit_id": "unit-B", "unit_label": "Unit B"},
                {"unit_id": "all", "unit_label": "All units"},
            ],
        }

    async def test_multi_unit_retrieval_without_filter_triggers_checkpoint(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("unused"))

        payload = AskRequest(landlord_id="l1", property_id="p1", question="when does the lease expire?")
        response = await service.ask_documind(payload)

        self.assertTrue(response.needs_unit_clarification)
        self.assertTrue(response.user_action_required)
        self.assertEqual(response.citations, [])
        self.assertEqual(
            [option.unit_id for option in response.unit_options],
            ["unit-A", "unit-B", "all"],
        )
        pending = fake_store.pending[response.session_id]
        self.assertEqual(pending["type"], "unit")
        self.assertEqual(pending["question"], "when does the lease expire?")

    async def test_unit_action_reruns_pending_question_with_unit_filter(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        fake_store.pending["session-7"] = self._unit_pending()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("It ends 31 December 2026."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="Unit A",
            session_id="session-7",
            user_action="unit:unit-A",
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertEqual(len(response.citations), 1)
        self.assertEqual(response.citations[0].unit_label, "Unit A")
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertEqual(retriever_call["unit_id"], "unit-A")
        self.assertEqual(retriever_call["question"], "when does the lease expire?")
        self.assertIsNone(fake_store.pending["session-7"])

    async def test_unit_all_action_answers_unfiltered_without_loop(self):
        fake_db = self._multi_unit_db()
        fake_store = _FakeConversationStore()
        fake_store.pending["session-8"] = self._unit_pending()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("Unit A ends 2026; Unit B ends 2027."))

        payload = AskRequest(
            landlord_id="l1",
            property_id="p1",
            question="All units",
            session_id="session-8",
            user_action="unit:all",
        )
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertFalse(response.user_action_required)
        self.assertEqual(len(response.citations), 2)
        retriever_call = service._hybrid_retriever.calls[-1]
        self.assertIsNone(retriever_call["unit_id"])
        self.assertEqual(retriever_call["question"], "when does the lease expire?")

    async def test_single_unit_plus_property_wide_does_not_trigger(self):
        fake_db = _FakeDB(
            docs=[{"landlord_id": "l1", "property_id": "p1", "category": "lease"}],
            chunks=[
                {"doc_id": "doc-A", "filename": "leaseA.pdf", "category": "lease", "page": 1,
                 "unit_id": "unit-A", "unit_label": "Unit A",
                 "text": "Unit A tenancy ends 31 December 2026.",
                 "landlord_id": "l1", "property_id": "p1"},
                # Pre-units chunk: no unit keys at all — property-wide.
                {"doc_id": "doc-C", "filename": "insurance.pdf", "category": "insurance", "page": 1,
                 "text": "Building insurance covers fire damage.",
                 "landlord_id": "l1", "property_id": "p1"},
            ],
        )
        fake_store = _FakeConversationStore()
        service = _build_service(fake_db, fake_store, self._retrieve_graph(), _FakeLLM("It ends 31 December 2026."))

        payload = AskRequest(landlord_id="l1", property_id="p1", question="when does the lease expire?")
        response = await service.ask_documind(payload)

        self.assertFalse(response.needs_unit_clarification)
        self.assertEqual(len(response.citations), 2)
```

Note the ids are deliberately mixed-case (`unit-A`): if the implementation lowercases the id out of `user_action`, the filter test fails — that's the point.

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_documind_orchestration.py tests/test_documind_service_flows.py -q`
Expected: FAIL — the new unit tests fail (`needs_unit_clarification` is False / retriever called with `unit_id=None`; verify the service tests fail).

- [ ] **Step 4: Implement the graph changes**

In `backend/rag/graph_orchestrator.py`:

In `_route_conversation_node`, change the checkpoint-action bypass condition to:

```python
        if user_action in {"confirm", "cancel"} or user_action.startswith(("override:", "unit:")):
```

In `_decide_action_node`, add after the `override:` branch:

```python
        if user_action.startswith("unit:"):
            return {**state, "action": "retrieve"}
```

- [ ] **Step 5: Implement the service dispatch (resume path)**

In `backend/rag/documind_service.py`, in `ask_documind`, change the block that begins `working_question = payload.question` to initialize the effective unit filter:

```python
        working_question = payload.question
        selected_categories: List[str] = []
        effective_unit_id = payload.unit_id
```

In the `else:` branch (no explicit categories), keep a raw copy of the action so unit ids keep their casing:

```python
            pending = self._conversation_store.get_pending_confirmation(session_id)
            user_action_raw = (payload.user_action or "").strip()
            user_action = user_action_raw.lower()
```

Then add a new branch between the `override:` branch and the `user_action in ALLOWED_CATEGORIES` branch:

```python
            elif user_action.startswith("unit:"):
                # Resume of a unit-ambiguity checkpoint. The unit id keeps its
                # original casing (Firestore ids are case-sensitive); the "all"
                # sentinel proceeds unfiltered. A missing pending confirmation
                # falls back to treating this as a fresh question.
                unit_target = user_action_raw.split(":", 1)[1].strip()
                if pending:
                    working_question = pending.get("question", payload.question)
                if unit_target and unit_target.lower() != "all":
                    effective_unit_id = unit_target
                self._conversation_store.clear_pending_confirmation(session_id)
                selected_categories = [
                    category for category in predicted_categories if category in ALLOWED_CATEGORIES
                ]
                if selected_categories:
                    category_filter_mode = "auto"
```

And change the retrieval call's unit filter from `unit_id=payload.unit_id` to:

```python
                unit_id=effective_unit_id,
```

- [ ] **Step 6: Implement the post-retrieval checkpoint**

Still in `ask_documind`, insert immediately **after** the `if not retrieved_chunks:` return block and **before** the `best_citation_by_page` dedupe comment:

```python
        # Unit-ambiguity checkpoint (post-retrieval — only knowable after
        # seeing which units the retrieved chunks belong to). Fires when the
        # chat isn't unit-scoped, this isn't already a unit-checkpoint
        # answer, and the chunks span two or more distinct units.
        checkpoint_action = (payload.user_action or "").strip().lower()
        distinct_unit_ids = {
            chunk.get('unit_id') for chunk in retrieved_chunks if chunk.get('unit_id')
        }
        if (
            payload.unit_id is None
            and not checkpoint_action.startswith("unit:")
            and len(distinct_unit_ids) >= 2
        ):
            labels_by_unit: dict[str, str] = {}
            for chunk in retrieved_chunks:
                chunk_unit_id = chunk.get('unit_id')
                if chunk_unit_id and chunk_unit_id not in labels_by_unit:
                    labels_by_unit[chunk_unit_id] = chunk.get('unit_label') or chunk_unit_id
            unit_options = [
                UnitOption(unit_id=unit_id, unit_label=unit_label)
                for unit_id, unit_label in sorted(labels_by_unit.items(), key=lambda item: item[1])
            ]
            unit_options.append(UnitOption(unit_id="all", unit_label="All units"))

            matched_labels = " and ".join(option.unit_label for option in unit_options[:-1])
            unit_prompt = (
                f"That question matches documents from {matched_labels}. "
                "Which unit do you mean?"
            )
            self._conversation_store.set_pending_confirmation(
                session_id,
                {
                    "type": "unit",
                    "question": working_question,
                    "unit_options": [option.model_dump() for option in unit_options],
                },
            )
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": working_question,
                    "intent": "document_question",
                    "action": "ask_unit_clarification",
                    "unit_options": [option.unit_id for option in unit_options],
                },
            )
            return AskResponse(
                answer=unit_prompt,
                confidence=0.6,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                needs_category_clarification=False,
                clarification_prompt=unit_prompt,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=True,
                needs_unit_clarification=True,
                unit_options=unit_options,
                predicted_categories=predicted_categories,
                action_reason="Retrieved documents span multiple units",
            )
```

(`UnitOption` is already imported via the existing `from models.documind_models import *`.)

- [ ] **Step 7: Run the backend suites**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py tests/test_documind_orchestration.py tests/test_retriever.py -q`
Expected: PASS (all tests, including every pre-existing flow test).

- [ ] **Step 8: Commit**

```bash
git add backend/rag/documind_service.py backend/rag/graph_orchestrator.py backend/tests/test_documind_service_flows.py backend/tests/test_documind_orchestration.py
git commit -m "feat: add unit-ambiguity clarification checkpoint with unit:* resume actions" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Flutter unit-clarification flow + unit-filter sync (Phase 3, Flutter)

Parse the checkpoint response, render unit options in the assistant text (same typed-reply pattern the category checkpoint uses), map typed replies to `unit:*` actions, and sync `selectedDocumindUnitProvider` when a specific unit is chosen so the Docs tab and follow-up questions stay scoped consistently.

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/documind_document.dart` (add `UnitOption` entity; extend `DocuMindAnswer`)
- Modify: `residex_app/lib/features/landlord/data/models/documind_models.dart` (add `UnitOptionModel`; extend `DocuMindAnswerModel`)
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`
- Test: `residex_app/test/features/landlord/documind_chat_logic_test.dart` (extend)
- Test: `residex_app/test/features/landlord/documind_screen_checkpoint_action_test.dart` (extend)

**Interfaces:**
- Consumes: backend JSON `needs_unit_clarification: bool` and `unit_options: [{unit_id, unit_label}]` (Tasks 7-8); `selectedDocumindUnitProvider` / `unitsForPropertyStreamProvider` (existing).
- Produces: domain `class UnitOption { final String unitId; final String unitLabel; }`; `DocuMindAnswer` gains `bool needsUnitClarification` (default `false`) and `List<UnitOption> unitOptions` (default `const []`); `mapDocuMindUserAction` gains optional param `List<UnitOption> unitOptions = const []` and returns `'unit:<unitId>'` / `'unit:all'`.

- [ ] **Step 1: Write the failing chat-logic tests**

Append to `residex_app/test/features/landlord/documind_chat_logic_test.dart` (inside `main()`; the `documind_document.dart` import is already present):

```dart
  group('mapDocuMindUserAction unit clarification', () {
    const categories = ['lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'];
    final unitOptions = [
      UnitOption(unitId: 'unit-A', unitLabel: 'Unit A'),
      UnitOption(unitId: 'unit-B', unitLabel: 'Unit B'),
      UnitOption(unitId: 'all', unitLabel: 'All units'),
    ];

    test('maps typed unit label to unit action preserving id casing', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'unit a',
        categories: categories,
        unitOptions: unitOptions,
      );

      expect(action, 'unit:unit-A');
    });

    test('maps all units reply to unit:all sentinel', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'all units',
        categories: categories,
        unitOptions: unitOptions,
      );

      expect(action, 'unit:all');
    });

    test('does not map category overrides while a unit checkpoint is pending', () {
      final action = mapDocuMindUserAction(
        awaitingUserAction: true,
        messageText: 'lease',
        categories: categories,
        unitOptions: unitOptions,
      );

      expect(action, isNull);
    });
  });

  group('buildDocuMindAssistantText unit clarification', () {
    test('renders unit options for a unit clarification checkpoint', () {
      final answer = DocuMindAnswer(
        answer:
            'That question matches documents from Unit A and Unit B. Which unit do you mean?',
        confidence: 0.6,
        citations: const [],
        propertyName: 'Maple Residency',
        userActionRequired: true,
        needsUnitClarification: true,
        unitOptions: [
          UnitOption(unitId: 'unit-A', unitLabel: 'Unit A'),
          UnitOption(unitId: 'unit-B', unitLabel: 'Unit B'),
          UnitOption(unitId: 'all', unitLabel: 'All units'),
        ],
      );

      final text = buildDocuMindAssistantText(
        answer: answer,
        categoryLabelResolver: (category) => category,
      );

      expect(text, contains('Reply with a unit'));
      expect(text, contains('• Unit A'));
      expect(text, contains('• All units'));
      expect(text, isNot(contains('`confirm`')));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/documind_chat_logic_test.dart`
Expected: FAIL — compile errors (`UnitOption` undefined, `unitOptions`/`needsUnitClarification` unknown parameters).

- [ ] **Step 3: Implement entity + model**

In `residex_app/lib/features/landlord/domain/entities/documind_document.dart`, add before `DocuMindAnswer`:

```dart
/// One selectable unit in a unit-clarification checkpoint.
class UnitOption {
  final String unitId;
  final String unitLabel;

  UnitOption({required this.unitId, required this.unitLabel});
}
```

Extend `DocuMindAnswer` with two fields and constructor defaults:

```dart
  final bool needsUnitClarification;
  final List<UnitOption> unitOptions;
```

```dart
    this.needsUnitClarification = false,
    this.unitOptions = const [],
```

In `residex_app/lib/features/landlord/data/models/documind_models.dart`, add:

```dart
/// Unit option model for unit-clarification checkpoints
class UnitOptionModel {
  final String unitId;
  final String unitLabel;

  UnitOptionModel({required this.unitId, required this.unitLabel});

  factory UnitOptionModel.fromJson(Map<String, dynamic> json) {
    return UnitOptionModel(
      unitId: json['unit_id'] as String? ?? '',
      unitLabel: json['unit_label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'unit_id': unitId, 'unit_label': unitLabel};

  UnitOption toEntity() => UnitOption(unitId: unitId, unitLabel: unitLabel);
}
```

Extend `DocuMindAnswerModel` with `final bool needsUnitClarification;` and `final List<UnitOptionModel> unitOptions;` (constructor defaults `this.needsUnitClarification = false, this.unitOptions = const []`), parse them in `fromJson`:

```dart
      needsUnitClarification: json['needs_unit_clarification'] as bool? ?? false,
      unitOptions: (json['unit_options'] as List<dynamic>? ?? [])
          .map((option) => UnitOptionModel.fromJson(option as Map<String, dynamic>))
          .toList(),
```

add to `toJson()`:

```dart
      'needs_unit_clarification': needsUnitClarification,
      'unit_options': unitOptions.map((option) => option.toJson()).toList(),
```

and to `toEntity()`:

```dart
      needsUnitClarification: needsUnitClarification,
      unitOptions: unitOptions.map((option) => option.toEntity()).toList(),
```

- [ ] **Step 4: Implement the chat logic**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart`, replace `mapDocuMindUserAction` with:

```dart
String? mapDocuMindUserAction({
  required bool awaitingUserAction,
  required String messageText,
  required List<String> categories,
  List<UnitOption> unitOptions = const [],
}) {
  if (!awaitingUserAction) {
    return null;
  }

  final normalized = messageText.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized == 'confirm' || normalized.contains('confirm')) {
    return 'confirm';
  }

  if (normalized == 'cancel' || normalized.contains('cancel')) {
    return 'cancel';
  }

  // A pending unit checkpoint takes over interpretation: match unit labels
  // (returning ids with original casing), then the "all" sentinel. Category
  // overrides are suspended so "lease" can't hijack a unit question.
  if (unitOptions.isNotEmpty) {
    for (final option in unitOptions) {
      if (option.unitId == 'all') continue;
      final label = option.unitLabel.toLowerCase();
      if (normalized == label || normalized.contains(label)) {
        return 'unit:${option.unitId}';
      }
    }
    if (normalized.contains('all')) {
      return 'unit:all';
    }
    return null;
  }

  for (final category in categories) {
    if (normalized == category || normalized.contains(category)) {
      return 'override:$category';
    }
  }

  return null;
}
```

In `buildDocuMindAssistantText`, replace the `if (answer.userActionRequired) { ... }` block with:

```dart
  if (answer.userActionRequired) {
    if (answer.needsUnitClarification && answer.unitOptions.isNotEmpty) {
      responseText += '\n\nReply with a unit, or `all units`:';
      responseText +=
          '\n${answer.unitOptions.map((option) => '• ${option.unitLabel}').join('\n')}';
    } else {
      final options = answer.clarificationOptions.isNotEmpty
          ? answer.clarificationOptions
          : answer.predictedCategories;
      if (options.isNotEmpty) {
        responseText += '\n\nReply with `confirm` or `cancel`, or type a category:';
        responseText += '\n${options.map((option) => '• $option').join('\n')}';
      }
    }
  }
```

- [ ] **Step 5: Run the chat-logic tests**

Run: `cd residex_app && flutter test test/features/landlord/documind_chat_logic_test.dart`
Expected: PASS (all tests).

- [ ] **Step 6: Write the failing widget test**

Append to `residex_app/test/features/landlord/documind_screen_checkpoint_action_test.dart`. Add imports at the top of the file:

```dart
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
```

Then the test:

```dart
  testWidgets('DocuMind sends unit action and syncs unit filter after unit checkpoint', (tester) async {
    final capturedUserActions = <String?>[];
    var callCount = 0;

    Future<DocuMindAnswer> askAction({
      required String propertyId,
      required String question,
      int topK = 4,
      List<String>? categories,
      String? sessionId,
      int conversationTurn = 1,
      String? userAction,
    }) async {
      capturedUserActions.add(userAction);
      callCount += 1;

      if (callCount == 1) {
        return DocuMindAnswer(
          answer:
              'That question matches documents from Unit A and Unit B. Which unit do you mean?',
          confidence: 0.6,
          citations: const [],
          propertyName: 'Maple Residency',
          userActionRequired: true,
          needsUnitClarification: true,
          unitOptions: [
            UnitOption(unitId: 'unit-A', unitLabel: 'Unit A'),
            UnitOption(unitId: 'unit-B', unitLabel: 'Unit B'),
            UnitOption(unitId: 'all', unitLabel: 'All units'),
          ],
          sessionId: 'session-unit-1',
          conversationTurn: 1,
        );
      }

      return DocuMindAnswer(
        answer: 'Unit A lease ends 31 December 2026.',
        confidence: 0.9,
        citations: const [],
        propertyName: 'Maple Residency',
        userActionRequired: false,
        sessionId: 'session-unit-1',
        conversationTurn: 2,
      );
    }

    final unitA = Unit(
      id: 'unit-A',
      propertyId: 'prop-1',
      label: 'Unit A',
      monthlyRent: 1200,
      isOccupied: true,
      createdAt: DateTime(2026, 1, 1),
    );
    final unitB = Unit(
      id: 'unit-B',
      propertyId: 'prop-1',
      label: 'Unit B',
      monthlyRent: 1300,
      isOccupied: false,
      createdAt: DateTime(2026, 1, 2),
    );

    final testProperty = Property(
      id: 'prop-1',
      landlordId: 'landlord-1',
      name: 'Maple Residency',
      address: const PropertyAddress(
        street: '123 Main St',
        city: 'Kuala Lumpur',
        state: 'WP Kuala Lumpur',
        zipCode: '50000',
        country: 'Malaysia',
      ),
      type: PropertyType.apartment,
      purchasePrice: 500000,
      currentValue: 550000,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
          askDocuMindQuestionActionProvider.overrideWith((ref) => askAction),
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => Stream.value([unitA, unitB]),
          ),
        ],
        child: const MaterialApp(home: DocuMindScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final dashChat = tester.widget<DashChat>(find.byType(DashChat));
    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'when does the lease expire?',
      ),
    );
    await tester.pumpAndSettle();

    dashChat.onSend(
      ChatMessage(
        user: ChatUser(id: 'test-user'),
        createdAt: DateTime.now(),
        text: 'Unit A',
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUserActions.length, 2);
    expect(capturedUserActions[0], isNull);
    expect(capturedUserActions[1], 'unit:unit-A');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DocuMindScreen)),
    );
    expect(container.read(selectedDocumindUnitProvider)?.id, 'unit-A');
  });
```

Run: `cd residex_app && flutter test test/features/landlord/documind_screen_checkpoint_action_test.dart`
Expected: FAIL — `capturedUserActions[1]` is null (screen doesn't pass unit options yet) and the unit filter is unset.

- [ ] **Step 7: Implement the screen wiring**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`:

Add state next to `_awaitingUserAction`:

```dart
  List<UnitOption> _pendingUnitOptions = const [];
```

In `_onSendMessage`, replace the `mapDocuMindUserAction` call and add the filter sync before `askAction`:

```dart
      final userAction = mapDocuMindUserAction(
        awaitingUserAction: _awaitingUserAction,
        messageText: message.text,
        categories: _categories,
        unitOptions: _pendingUnitOptions,
      );
      if (userAction != null &&
          userAction.startsWith('unit:') &&
          userAction != 'unit:all') {
        _syncUnitFilterFromAction(userAction.substring('unit:'.length));
      }
```

Add the helper method:

```dart
  /// Keep the header unit filter in sync with a unit chosen in chat, so the
  /// Docs tab and follow-up questions stay scoped to the same unit.
  void _syncUnitFilterFromAction(String unitId) {
    if (_selectedPropertyId == null) return;
    final units =
        ref.read(unitsForPropertyStreamProvider(_selectedPropertyId!)).value ??
            const <Unit>[];
    for (final unit in units) {
      if (unit.id == unitId) {
        ref.read(selectedDocumindUnitProvider.notifier).select(unit);
        break;
      }
    }
  }
```

In `_consumeAnswer`, after `_awaitingUserAction = answer.userActionRequired;`:

```dart
    _pendingUnitOptions =
        answer.userActionRequired ? answer.unitOptions : const [];
```

- [ ] **Step 8: Run all Flutter tests and analyzer**

Run: `cd residex_app && flutter test test/features/landlord/ && flutter analyze`
Expected: all tests PASS (including the three pre-existing checkpoint tests — they still compile because `unitOptions` is an optional parameter); analyze reports 0 errors.

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/documind_document.dart residex_app/lib/features/landlord/data/models/documind_models.dart "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart" "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart" residex_app/test/features/landlord/documind_chat_logic_test.dart residex_app/test/features/landlord/documind_screen_checkpoint_action_test.dart
git commit -m "feat: handle unit clarification checkpoint in chat and sync unit filter" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Lease-upload unit nudge (Phase 4, Flutter)

`_pickUploadUnit()` asks "Assign to a unit?" identically for every category. For leases on multi-unit properties, lead with units and demote "Whole property" to last with explanatory copy. Not hard-blocked — a property-wide master lease stays legitimate. Single-unit/no-unit properties keep today's skip behavior (the existing `units.isEmpty` early return is untouched).

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (`_pickUploadUnit`, its call site in `_uploadDocument`)
- Test: `residex_app/test/features/landlord/documind_upload_rules_test.dart` (create)

**Interfaces:**
- Produces: top-level function in `documind_screen.dart`: `List<Unit?> uploadUnitDialogOptions({required String category, required List<Unit> units})` where a `null` entry means the "Whole property" option. `_pickUploadUnit` gains a required `category` parameter. Task 14 adds `isAllowedUploadFilename` to the same test file.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/documind_upload_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_screen.dart';

void main() {
  final units = [
    Unit(
      id: 'u1',
      propertyId: 'p1',
      label: 'Unit 1',
      monthlyRent: 1000,
      isOccupied: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    Unit(
      id: 'u2',
      propertyId: 'p1',
      label: 'Unit 2',
      monthlyRent: 1100,
      isOccupied: false,
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  group('uploadUnitDialogOptions', () {
    test('lease uploads list units first and demote whole property to last', () {
      final options = uploadUnitDialogOptions(category: 'lease', units: units);

      expect(options.first?.id, 'u1');
      expect(options.last, isNull);
      expect(options.length, 3);
    });

    test('non-lease categories keep whole property first', () {
      final options = uploadUnitDialogOptions(category: 'insurance', units: units);

      expect(options.first, isNull);
      expect(options.sublist(1).map((unit) => unit!.id), ['u1', 'u2']);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_rules_test.dart`
Expected: FAIL — compile error, `uploadUnitDialogOptions` undefined.

- [ ] **Step 3: Implement**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, add a top-level function near the `_UploadUnitChoice` class at the bottom of the file:

```dart
/// Option order for the upload unit-picker dialog. A null entry is the
/// "Whole property" option. Leases lead with units (a lease almost always
/// belongs to one unit) and demote "Whole property" to last; every other
/// category keeps "Whole property" first.
List<Unit?> uploadUnitDialogOptions({
  required String category,
  required List<Unit> units,
}) {
  if (category == 'lease') {
    return [...units, null];
  }
  return [null, ...units];
}
```

Replace `_pickUploadUnit` with a category-aware version (the units fetch and `units.isEmpty` early return stay exactly as they are):

```dart
  Future<_UploadUnitChoice?> _pickUploadUnit({required String category}) async {
    List<Unit> units;
    try {
      units =
          await ref.read(unitsForPropertyProvider(_selectedPropertyId!).future);
    } catch (_) {
      // Unit lookup failing shouldn't block an upload; treat as no units.
      units = const <Unit>[];
    }
    if (units.isEmpty) return const _UploadUnitChoice(null);

    final isLease = category == 'lease';
    final orderedOptions =
        uploadUnitDialogOptions(category: category, units: units);

    if (!mounted) return null;
    return showDialog<_UploadUnitChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Assign to a unit?', style: AppTextStyles.titleMedium),
        children: [
          for (final unit in orderedOptions)
            if (unit == null)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(ctx, const _UploadUnitChoice(null)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.home_work_outlined,
                        size: 18, color: AppColors.primaryCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Whole property',
                              style: AppTextStyles.bodyMedium),
                          if (isLease)
                            Text(
                              'Leases usually belong to a specific unit',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, _UploadUnitChoice(unit)),
                child: Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 18, color: AppColors.primaryCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        unit.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
```

Update the call site in `_uploadDocument`:

```dart
      final unitChoice = await _pickUploadUnit(category: category);
```

- [ ] **Step 4: Run tests and analyzer**

Run: `cd residex_app && flutter test test/features/landlord/ && flutter analyze`
Expected: all tests PASS; analyze reports 0 errors.

- [ ] **Step 5: Commit**

```bash
git add "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart" residex_app/test/features/landlord/documind_upload_rules_test.dart
git commit -m "feat: nudge lease uploads toward a unit in the upload picker" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: Backend unassign-unit endpoint (Phase 6, backend)

`POST /api/rex/documind/documents/unassign-unit` batch-clears `unit_id`/`unit_label` on every matching `documind_docs` and `documind_chunks` record, converting them to property-wide. The backend keeps sole ownership of its collections — Flutter never writes them directly.

**Files:**
- Modify: `backend/rag/documind_service.py` (new method after `delete_documents_for_property`)
- Modify: `backend/api/rex_routes.py` (new route + import)
- Modify: `backend/models/documind_models.py` (request model)
- Test: `backend/tests/test_documind_service_flows.py` (extend, incl. fake-harness `update` support)
- Test: `backend/tests/test_rex_routes_documind_docs_api.py` (extend)

**Interfaces:**
- Produces: `async DocuMindService.unassign_unit_documents(landlord_id: str, property_id: str, unit_id: str) -> dict` returning `{"message", "unit_id", "documents_updated", "chunks_updated"}`; `class UnassignUnitRequest(BaseModel)` with `landlord_id: str, property_id: str, unit_id: str`; route `POST /api/rex/documind/documents/unassign-unit`. Task 12's Flutter datasource calls this endpoint. Test harness gains `update` on `_FakeRowRef` and `_FakeBatch`.

- [ ] **Step 1: Extend the fake harness with update support**

In `backend/tests/test_documind_service_flows.py`, add to `_FakeRowRef`:

```python
    def update(self, fields):
        self._row.update(fields)
```

And replace `_FakeBatch` with:

```python
class _FakeBatch:
    def __init__(self):
        self._ops = []

    def set(self, ref, data):
        self._ops.append(("set", ref, data))

    def update(self, ref, fields):
        self._ops.append(("update", ref, fields))

    def delete(self, ref):
        self._ops.append(("delete", ref, None))

    def commit(self):
        for op, ref, data in self._ops:
            if op == "set":
                ref.set(data)
            elif op == "update":
                ref.update(data)
            else:
                ref.delete()
```

- [ ] **Step 2: Write the failing service tests**

Append a new test class to the same file:

```python
class DocuMindUnassignUnitTests(unittest.IsolatedAsyncioTestCase):
    def _db_with_unit_docs(self):
        return _FakeDB(
            docs=[
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-A", "unit_label": "Unit A", "category": "lease"},
                {"doc_id": "doc-B", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-B", "unit_label": "Unit B", "category": "lease"},
                {"doc_id": "doc-C", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": None, "unit_label": None, "category": "insurance"},
            ],
            chunks=[
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-A", "unit_label": "Unit A", "text": "a"},
                {"doc_id": "doc-A", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-A", "unit_label": "Unit A", "text": "b"},
                {"doc_id": "doc-B", "landlord_id": "l1", "property_id": "p1",
                 "unit_id": "unit-B", "unit_label": "Unit B", "text": "c"},
            ],
        )

    async def test_unassign_clears_target_unit_only(self):
        fake_db = self._db_with_unit_docs()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.unassign_unit_documents("l1", "p1", "unit-A")

        self.assertEqual(result["documents_updated"], 1)
        self.assertEqual(result["chunks_updated"], 2)
        doc_a = next(d for d in fake_db.docs if d["doc_id"] == "doc-A")
        self.assertIsNone(doc_a["unit_id"])
        self.assertIsNone(doc_a["unit_label"])
        doc_b = next(d for d in fake_db.docs if d["doc_id"] == "doc-B")
        self.assertEqual(doc_b["unit_id"], "unit-B")
        self.assertEqual(doc_b["unit_label"], "Unit B")
        for chunk in fake_db.chunks:
            if chunk["doc_id"] == "doc-A":
                self.assertIsNone(chunk["unit_id"])
                self.assertIsNone(chunk["unit_label"])
            if chunk["doc_id"] == "doc-B":
                self.assertEqual(chunk["unit_id"], "unit-B")

    async def test_unassign_is_idempotent(self):
        fake_db = self._db_with_unit_docs()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.unassign_unit_documents("l1", "p1", "unit-A")
        second = await service.unassign_unit_documents("l1", "p1", "unit-A")

        self.assertEqual(second["documents_updated"], 0)
        self.assertEqual(second["chunks_updated"], 0)
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py::DocuMindUnassignUnitTests -q`
Expected: FAIL with `AttributeError: 'DocuMindService' object has no attribute 'unassign_unit_documents'`.

- [ ] **Step 4: Implement the service method**

In `backend/rag/documind_service.py`, add after `delete_documents_for_property`:

```python
    async def unassign_unit_documents(
        self,
        landlord_id: str,
        property_id: str,
        unit_id: str,
    ) -> dict:
        """
        Clear the unit assignment on every doc + chunk scoped to a unit,
        converting them to property-wide documents.

        Called by the app before deleting a unit so its documents are
        unassigned rather than orphaned with a stale unit_id. Idempotent: a
        unit with no assigned documents returns zero counts. A single batch
        is fine at this scale (Firestore's 500-op batch limit).
        """
        print(f"🔵 DocuMind: Unassign unit {unit_id} documents for property {property_id}")

        batch = self.db.batch()
        documents_updated = 0
        chunks_updated = 0

        docs_query = (
            self.db.collection('documind_docs')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in docs_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            documents_updated += 1

        chunks_query = (
            self.db.collection('documind_chunks')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in chunks_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            chunks_updated += 1

        if documents_updated or chunks_updated:
            batch.commit()

        print(f"✅ Unassigned {documents_updated} docs / {chunks_updated} chunks from unit {unit_id}")

        return {
            "message": "Unit documents unassigned",
            "unit_id": unit_id,
            "documents_updated": documents_updated,
            "chunks_updated": chunks_updated,
        }
```

- [ ] **Step 5: Run the service tests**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -q`
Expected: PASS (all tests).

- [ ] **Step 6: Write the failing route tests**

In `backend/tests/test_rex_routes_documind_docs_api.py`, add to `DocuMindDocumentsApiTests`:

```python
    def test_unassign_unit_documents_returns_200_and_calls_service(self):
        with patch(
            "api.rex_routes.documind_service.unassign_unit_documents",
            new=AsyncMock(return_value={
                "message": "Unit documents unassigned",
                "unit_id": "unit-9",
                "documents_updated": 2,
                "chunks_updated": 7,
            }),
        ) as mocked_unassign:
            response = self.client.post(
                "/api/rex/documind/documents/unassign-unit",
                json={
                    "landlord_id": "landlord-1",
                    "property_id": "property-1",
                    "unit_id": "unit-9",
                },
            )

            call_kwargs = mocked_unassign.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["documents_updated"], 2)
        self.assertEqual(call_kwargs["landlord_id"], "landlord-1")
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["unit_id"], "unit-9")

    def test_unassign_unit_documents_returns_422_when_missing_fields(self):
        response = self.client.post(
            "/api/rex/documind/documents/unassign-unit",
            json={"landlord_id": "landlord-1"},
        )
        self.assertEqual(response.status_code, 422)
```

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_docs_api.py -q`
Expected: FAIL — 404 for the unknown route.

- [ ] **Step 7: Implement the request model and route**

In `backend/models/documind_models.py`, add:

```python
class UnassignUnitRequest(BaseModel):
    """Request to convert one unit's documents to property-wide"""
    landlord_id: str
    property_id: str
    unit_id: str
```

In `backend/api/rex_routes.py`, update the import to include it:

```python
from models.documind_models import DocUploadResponse, AskRequest, AskResponse, DocListResponse, UnassignUnitRequest
```

Add after the `delete_property_documents` route:

```python
@router.post("/documind/documents/unassign-unit")
async def unassign_unit_documents(payload: UnassignUnitRequest):
    """
    Clear the unit assignment on all of a unit's documents and chunks,
    converting them to property-wide. Called before a unit is deleted so its
    documents don't keep a stale unit_id. Nothing is deleted; idempotent.

    Example:
        POST /api/rex/documind/documents/unassign-unit
        {"landlord_id": "landlord_456", "property_id": "property_789", "unit_id": "unit_9"}
    """
    return await documind_service.unassign_unit_documents(
        landlord_id=payload.landlord_id,
        property_id=payload.property_id,
        unit_id=payload.unit_id,
    )
```

- [ ] **Step 8: Run the route tests**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_docs_api.py -q`
Expected: PASS (all tests).

- [ ] **Step 9: Commit**

```bash
git add backend/rag/documind_service.py backend/api/rex_routes.py backend/models/documind_models.py backend/tests/test_documind_service_flows.py backend/tests/test_rex_routes_documind_docs_api.py
git commit -m "feat: add unassign-unit endpoint converting unit docs to property-wide" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 12: Flutter unassign-on-delete flow (Phase 6, Flutter)

When a unit with assigned documents is deleted, tell the user those documents will be kept as property-wide, and call the unassign endpoint before `deleteUnit`. Units with no documents keep today's flow untouched. (Spec mandates no widget test here — the flow is covered by the backend tests plus manual acceptance in Task 15; `flutter analyze` guards compilation.)

**Files:**
- Modify: `residex_app/lib/core/constants/api_constants.dart`
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`
- Modify: `residex_app/lib/features/landlord/domain/repositories/documind_repository.dart`
- Modify: `residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart`

**Interfaces:**
- Consumes: `POST /api/rex/documind/documents/unassign-unit` (Task 11); existing `currentLandlordIdProvider`, `listDocumentsUseCaseProvider`, `unitControllerProvider`.
- Produces: `ApiConstants.documindUnassignUnit`; datasource/repository method `Future<void> unassignUnitDocuments({required String landlordId, required String propertyId, required String unitId})`; provider `unassignUnitDocumentsActionProvider` with call shape `({required String propertyId, required String unitId})`.

- [ ] **Step 1: Add the endpoint constant**

In `residex_app/lib/core/constants/api_constants.dart`, add:

```dart
  static const String documindUnassignUnit = '/api/rex/documind/documents/unassign-unit';
```

- [ ] **Step 2: Add the datasource method**

In `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`, add after `deleteDocumentsForProperty`:

```dart
  /// Convert one unit's documents to property-wide (called before deleting
  /// the unit, so its documents don't keep a stale unit_id)
  Future<void> unassignUnitDocuments({
    required String landlordId,
    required String propertyId,
    required String unitId,
  }) async {
    print('🔵 DataSource: Unassign unit documents');
    print('   - Unit: $unitId');

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUnassignUnit}');

    try {
      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'landlord_id': landlordId,
          'property_id': propertyId,
          'unit_id': unitId,
        }),
      );

      print('✅ DataSource: Unassign response status ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ DataSource: Unassign failed: ${response.body}');
        throw Exception('Unassign failed: ${response.body}');
      }
    } catch (e) {
      print('❌ DataSource: Unassign error: $e');
      rethrow;
    }
  }
```

- [ ] **Step 3: Add repository interface + implementation**

In `residex_app/lib/features/landlord/domain/repositories/documind_repository.dart`, add to the abstract class:

```dart
  /// Convert one unit's documents to property-wide (before unit deletion)
  Future<void> unassignUnitDocuments({
    required String landlordId,
    required String propertyId,
    required String unitId,
  });
```

In `residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart`, add:

```dart
  @override
  Future<void> unassignUnitDocuments({
    required String landlordId,
    required String propertyId,
    required String unitId,
  }) async {
    print('🔵 Repository: Unassign unit documents for unit $unitId');

    try {
      await remoteDataSource.unassignUnitDocuments(
        landlordId: landlordId,
        propertyId: propertyId,
        unitId: unitId,
      );
      print('✅ Repository: Unit documents unassigned');
    } catch (e) {
      print('❌ Repository: Unassign failed: $e');
      rethrow;
    }
  }
```

- [ ] **Step 4: Add the action provider**

In `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`, add after `deleteDocumentActionProvider`:

```dart
/// Convert a unit's documents to property-wide before the unit is deleted.
final unassignUnitDocumentsActionProvider = Provider<
    Future<void> Function({
      required String propertyId,
      required String unitId,
    })>((ref) {
  return ({
    required String propertyId,
    required String unitId,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final repository = ref.read(documindRepositoryProvider);

    await repository.unassignUnitDocuments(
      landlordId: landlordId,
      propertyId: propertyId,
      unitId: unitId,
    );

    // Unassigned docs are now property-wide; refresh any doc list.
    ref.invalidate(documindDocumentsProvider(propertyId));
  };
});
```

- [ ] **Step 5: Wire the unit-delete flow**

In `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart`, add the import:

```dart
import '../../providers/documind_provider.dart';
```

Replace `_confirmDeleteUnit` with:

```dart
  Future<void> _confirmDeleteUnit(BuildContext context, WidgetRef ref, Unit unit) async {
    // Count documents assigned to this unit so the dialog can explain what
    // happens to them. A count failure must never block unit deletion.
    int assignedDocCount = 0;
    try {
      final landlordId = ref.read(currentLandlordIdProvider);
      final listDocuments = ref.read(listDocumentsUseCaseProvider);
      final docs = await listDocuments(
        landlordId: landlordId,
        propertyId: propertyId,
      );
      assignedDocCount = docs.where((doc) => doc.unitId == unit.id).length;
    } catch (_) {
      assignedDocCount = 0;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text('Delete Unit', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this unit?', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${unit.label} · RM ${unit.monthlyRent.toStringAsFixed(0)}/mo',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (assignedDocCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                '$assignedDocCount document${assignedDocCount == 1 ? '' : 's'} assigned to this unit will be kept as property-wide documents.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(unitControllerProvider);
      try {
        if (assignedDocCount > 0) {
          final unassignDocuments = ref.read(unassignUnitDocumentsActionProvider);
          await unassignDocuments(propertyId: propertyId, unitId: unit.id);
        }
        await controller.deleteUnit(propertyId, unit.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete unit: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
```

- [ ] **Step 6: Run analyzer and the Flutter suite**

Run: `cd residex_app && flutter analyze && flutter test test/features/landlord/`
Expected: 0 analyzer errors; all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/core/constants/api_constants.dart residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart residex_app/lib/features/landlord/domain/repositories/documind_repository.dart residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart residex_app/lib/features/landlord/presentation/providers/documind_provider.dart "residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart"
git commit -m "feat: unassign unit documents to property-wide before unit deletion" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 13: Live unit-label resolution (Phase 6, Flutter)

Displayed unit labels resolve by `unit_id` against the live units list (already streamed on every relevant screen), falling back to the stored denormalized `unit_label` when the unit no longer resolves. Applies to Docs-tab badges and the Task 4 citation badges. Accepted caveat (documented, not fixed): the backend's stored `unit_label` in LLM context headers stays stale until re-upload.

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/screens/2-Documind/unit_label_resolver.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (`_buildDocumentTile` unit badge, `_buildCitationLine` badge)
- Test: `residex_app/test/features/landlord/unit_label_resolver_test.dart` (create)

**Interfaces:**
- Consumes: `Citation.unitId/unitLabel` (Task 4), `DocuMindDocument.unitId/unitLabel` (existing), `unitsForPropertyStreamProvider` (existing).
- Produces: top-level `String? resolveUnitLabel({required String? unitId, required String? storedLabel, required List<Unit> liveUnits})`.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/unit_label_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/unit_label_resolver.dart';

void main() {
  final liveUnits = [
    Unit(
      id: 'unit-A',
      propertyId: 'p1',
      label: 'Studio A (renamed)',
      monthlyRent: 1000,
      isOccupied: true,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  test('resolves live label for an existing unit (rename-safe)', () {
    final label = resolveUnitLabel(
      unitId: 'unit-A',
      storedLabel: 'Unit A',
      liveUnits: liveUnits,
    );

    expect(label, 'Studio A (renamed)');
  });

  test('falls back to stored label when unit no longer resolves', () {
    final label = resolveUnitLabel(
      unitId: 'unit-gone',
      storedLabel: 'Unit B',
      liveUnits: liveUnits,
    );

    expect(label, 'Unit B');
  });

  test('returns null for property-wide records', () {
    final label = resolveUnitLabel(
      unitId: null,
      storedLabel: null,
      liveUnits: liveUnits,
    );

    expect(label, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/unit_label_resolver_test.dart`
Expected: FAIL — the imported file doesn't exist.

- [ ] **Step 3: Implement the resolver**

Create `residex_app/lib/features/landlord/presentation/screens/2-Documind/unit_label_resolver.dart`:

```dart
import '../../../domain/entities/unit.dart';

/// Resolve the unit label to display for a document or citation.
///
/// The stored label is a denormalized copy captured at upload time and goes
/// stale when a unit is renamed. Prefer the live units list; fall back to
/// the stored copy when the unit no longer resolves (deleted unit, list
/// still loading). Property-wide records (no unitId) never show a label.
String? resolveUnitLabel({
  required String? unitId,
  required String? storedLabel,
  required List<Unit> liveUnits,
}) {
  if (unitId == null) return null;
  for (final unit in liveUnits) {
    if (unit.id == unitId) return unit.label;
  }
  return storedLabel;
}
```

Run: `cd residex_app && flutter test test/features/landlord/unit_label_resolver_test.dart`
Expected: PASS.

- [ ] **Step 4: Apply it to both badge surfaces**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, add the import:

```dart
import 'unit_label_resolver.dart';
```

Add a small helper method to `_DocuMindScreenState`:

```dart
  /// Live units for the selected property (empty while loading/unavailable —
  /// resolveUnitLabel then falls back to the stored label).
  List<Unit> _liveUnits() {
    if (_selectedPropertyId == null) return const <Unit>[];
    return ref.watch(unitsForPropertyStreamProvider(_selectedPropertyId!)).value ??
        const <Unit>[];
  }
```

In `_buildDocumentTile`, at the top of the method, compute the display label:

```dart
    final displayUnitLabel = resolveUnitLabel(
      unitId: doc.unitId,
      storedLabel: doc.unitLabel,
      liveUnits: _liveUnits(),
    );
```

Then change the unit badge from `if (doc.unitLabel != null)` to `if (displayUnitLabel != null)` and its text from `doc.unitLabel!.toUpperCase()` to `displayUnitLabel.toUpperCase()`.

In `_buildCitationLine`, at the top of the method:

```dart
    final displayUnitLabel = resolveUnitLabel(
      unitId: citation.unitId,
      storedLabel: citation.unitLabel,
      liveUnits: _liveUnits(),
    );
```

Then change the badge condition from `if (citation.unitLabel != null)` to `if (displayUnitLabel != null)` and the badge text from `citation.unitLabel!.toUpperCase()` to `displayUnitLabel.toUpperCase()`.

- [ ] **Step 5: Run the full Flutter suite and analyzer**

Run: `cd residex_app && flutter test test/features/landlord/ && flutter analyze`
Expected: all tests PASS (the Task 4 badge test still passes: its units stream isn't overridden, so `resolveUnitLabel` falls back to the stored label); analyze reports 0 errors.

- [ ] **Step 6: Commit**

```bash
git add "residex_app/lib/features/landlord/presentation/screens/2-Documind/unit_label_resolver.dart" "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart" residex_app/test/features/landlord/unit_label_resolver_test.dart
git commit -m "feat: resolve unit badges against live units with stored-label fallback" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 14: PDF-only upload guard (Phase 6, Flutter)

The picker allows `.docx` but the backend ingest is `PyPDFLoader`-only and stores `application/pdf` unconditionally — today a selected DOCX fails only after upload. Decision 2026-07-08: PDF-only now; DOCX is future work.

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (`_uploadDocument` extension check + error copy; new top-level function)
- Test: `residex_app/test/features/landlord/documind_upload_rules_test.dart` (extend)

**Interfaces:**
- Produces: top-level `bool isAllowedUploadFilename(String filename)` in `documind_screen.dart`.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `residex_app/test/features/landlord/documind_upload_rules_test.dart`:

```dart
  group('isAllowedUploadFilename', () {
    test('accepts pdf regardless of case', () {
      expect(isAllowedUploadFilename('Lease.PDF'), isTrue);
      expect(isAllowedUploadFilename('lease.pdf'), isTrue);
    });

    test('rejects docx now that ingestion is PDF-only', () {
      expect(isAllowedUploadFilename('lease.docx'), isFalse);
    });

    test('rejects other extensions', () {
      expect(isAllowedUploadFilename('lease.txt'), isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/documind_upload_rules_test.dart`
Expected: FAIL — compile error, `isAllowedUploadFilename` undefined.

- [ ] **Step 3: Implement**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, add next to `uploadUnitDialogOptions`:

```dart
/// The backend ingest is PyPDFLoader-only and stores application/pdf, so
/// the picker must reject anything but PDF up front (DOCX is future work).
bool isAllowedUploadFilename(String filename) =>
    filename.toLowerCase().endsWith('.pdf');
```

In `_uploadDocument`, replace the extension check:

```dart
      final selectedFile = result.files.single;

      if (!isAllowedUploadFilename(selectedFile.name)) {
        _showSnackBar('Only PDF files are supported.', isError: true);
        return;
      }
```

(This removes the now-unused `selectedName`/`isAllowed` locals — delete them.)

- [ ] **Step 4: Run tests and analyzer**

Run: `cd residex_app && flutter test test/features/landlord/ && flutter analyze`
Expected: all tests PASS; analyze reports 0 errors (no unused-variable warnings left behind).

- [ ] **Step 5: Commit**

```bash
git add "residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart" residex_app/test/features/landlord/documind_upload_rules_test.dart
git commit -m "feat: restrict upload picker to PDF matching backend capability" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 15: Full-suite verification + demo-flow acceptance

**Files:**
- No production changes expected; fix anything the full suites surface.

- [ ] **Step 1: Full backend suite**

Run: `cd backend && python -m pytest tests -q` (timeout >= 600 s — the suite is import-heavy)
Expected: PASS — no failures across `test_retriever.py`, `test_documind_service_flows.py`, `test_documind_orchestration.py`, `test_rex_routes_documind_ask_api.py`, `test_rex_routes_documind_docs_api.py`, `test_documind_evaluation.py`.

- [ ] **Step 2: Full Flutter suite + analyzer**

Run: `cd residex_app && flutter analyze && flutter test`
Expected: 0 analyzer errors; all tests PASS.

- [ ] **Step 3: Manual demo-flow acceptance (requires running backend + emulator)**

This is the spec's acceptance test. With the backend and Android emulator running (see the project's run setup notes), on a property with Unit A and Unit B, each with an ingested lease PDF:

1. Upload a `lease` PDF -> the unit dialog lists units first with "Whole property" last, subtitled "Leases usually belong to a specific unit" (Phase 4).
2. In chat with no unit filter, ask "when does the lease expire?" -> assistant replies with the unit checkpoint listing Unit A / Unit B / All units (Phase 3).
3. Reply "Unit A" -> answer comes from Unit A only; the citation line reads `lease.pdf · p.N` with a `UNIT A` badge (Phase 1); the header unit filter now shows Unit A (Phase 3 provider sync).
4. Delete a unit that has documents -> dialog states the documents will be kept property-wide; after deletion the docs appear without unit badges and still answer in chat (Phase 6).
5. Attempt to upload a `.docx` -> rejected with "Only PDF files are supported." (Phase 6).

If any step fails, debug and fix before closing the plan (use superpowers:systematic-debugging).

- [ ] **Step 4: Commit any verification fixes**

Only if Steps 1-3 required changes:

```bash
git add -A
git commit -m "fix: address full-suite verification findings" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
