# DocuMind Unit Intelligence — Design Spec

**Date:** 2026-07-06
**Status:** Draft (pending user review)
**Origin:** [`docs/2026-07-06-documind-unit-scoping-and-product-evaluation.md`](../../2026-07-06-documind-unit-scoping-and-product-evaluation.md) — incorporates every improvement identified there.

## Problem

Units exist as a storage/filter dimension but are invisible to everything that *reasons* over documents. Four verified gaps (evaluation §1) plus one category-routing defect (evaluation §2):

1. **Citations can't name their unit.** `unit_label` is stored on every chunk (`documind_service.py:266-267`) and the retriever propagates `unit_id` (`retriever.py:99`), but the citation builder (`documind_service.py:607-635`) and the `Citation` model (`documind_models.py:46-53`) drop it. The chat UI shows `filename · p.N` with no unit badge, even though the Docs tab already renders unit badges (`documind_screen.dart:915-936`). The answer-synthesis context has the same blindness: excerpts are headed `[Document N: filename, Page P]` with no unit label (`documind_service.py:623`), so even a correct answer cannot attribute statements to a specific unit.
2. **The ask flow is unit-blind.** The orchestrator has a category-clarification checkpoint (`ask_confirmation` action, `documind_service.py:426-468`) but no unit equivalent. With no unit filter set, "when does the lease expire?" on a multi-unit property blends chunks from several leases into one answer.
3. **Upload has no category→scope nudge.** `_pickUploadUnit()` (`documind_screen.dart:1064`) asks "Assign to a unit?" identically for every category. A lease saved as "whole property" pollutes every unit's filtered view forever (property-wide docs always pass the unit filter).
4. **Units own no derived facts.** Nothing extracts lease expiry / rent / warranty end from documents into anything queryable. The unit↔document link is a list filter, not knowledge.
5. **Category predictor guesses instead of admitting unknown.** On no-parse/no-keyword-match it returns `available_categories[0]` with fabricated ~0.5 confidence (`category_predictor.py:55-58, 84-86`) — an ordering-dependent guess that can filter retrieval to the wrong category and silently exclude the right documents.
6. **Unit lifecycle orphans documents.** Deleting a unit (`unit_remote_datasource.dart:110-114`) removes only the unit record — its documents keep a stale `unit_id`/`unit_label`, vanish from every unit-filtered view (the deleted unit is gone from the filter dropdown, and other units' filters exclude them), and keep displaying the stale badge. Renaming a unit likewise leaves the denormalized `unit_label` stale on every doc, chunk, and (post-Phase-1) citation.
7. **The upload UI accepts `.docx` the backend can't parse.** The picker allows `.pdf`/`.docx` (`documind_screen.dart:1134-1135`) but `ingest_document` runs `PyPDFLoader` unconditionally and stores `application/pdf` (`documind_service.py:244`, `:298-300`). Decision: PDF-only for now; DOCX ingestion is future work.

## Goals

- Every citation in a chat answer can display which unit its source document belongs to — and the LLM's context identifies each excerpt's unit, so "All units" answers can attribute per unit.
- A unit-ambiguous question (retrieval hits ≥2 units' documents, no unit filter set) triggers a "which unit?" checkpoint instead of a blended answer — reusing the existing confirmation machinery.
- Uploading a `lease` on a multi-unit property nudges the user toward picking a unit.
- The category predictor returns "unknown" (empty prediction) when it has no signal, routing to the existing category clarification flow instead of guessing.
- Deleting or renaming a unit never corrupts document scoping: deletion unassigns its documents to property-wide, and displayed unit labels are resolved live rather than trusted from denormalized copies.
- The upload picker matches actual backend capability: PDF-only until a DOCX loader ships.
- Key dated facts (lease end, warranty end, policy end + rent/deposit) are extracted at ingest and surfaced per unit and as upcoming-expiry alerts. *(Phase 5 — stretch; ship Phases 1–4 first.)*

## Non-goals

- No new categories (quit rent/assessment, inspection reports) — deferred until after the presentation (evaluation §2).
- No FCM/push notifications — expiry surfacing is in-app only (README roadmap Phase 3 stays future work).
- No change to the two-axis model itself: `unit_id` stays optional on any document; unit filter keeps returning unit docs **plus** property-wide docs. The evaluation's verdict is extend, don't redesign.
- No editing of extracted facts in v1 (read-only display; re-upload to correct).
- No OCR/parser work — extraction operates on the already-parsed PDF text.
- No DOCX ingestion — PDF-only for now (user decision, 2026-07-08); a DOCX loader (plus correct storage content type) is future work. Phase 6 aligns the upload picker to this.
- No tenant-side, gamification, or visual-polish work (evaluation §3: hold the landlord-scope line).

## Architecture

Six phases, each independently shippable, ordered by (demo value ÷ effort). Phases 1–2 are small and unblock the demo flow; Phase 3 is the headline behavior; Phase 4 is a Flutter-only tweak; Phase 5 is the strategic bet and the only phase introducing a new ingest step; Phase 6 is small hygiene work covering the post-spec cross-check findings.

### Phase 1 — Unit-aware citations (backend + Flutter, small)

**Backend:**
- `retriever.py` result mapping: alongside the existing `'unit_id': chunk.get('unit_id')`, propagate `'unit_label': chunk.get('unit_label')`.
- `Citation` (`documind_models.py`): add `unit_id: str | None = None` and `unit_label: str | None = None`.
- Citation builder (`documind_service.py:607-635`): carry `chunk.get('unit_id')` / `chunk.get('unit_label')` into `best_citation_by_page` entries and the `Citation(...)` construction. Pre-units chunks (no key) naturally yield `None` → property-wide, no special-casing.
- Answer-synthesis context header (`documind_service.py:623`): include the unit in each excerpt header — `[Document N: filename, Page P — Unit A]` when `unit_label` is present, `— Property-wide` otherwise — so the LLM can attribute statements per unit when answering across units (essential for the "All units" path in Phase 3).

**Flutter:**
- `CitationModel.fromJson` (`data/models/documind_models.dart:106+`) and the domain `Citation` entity: add nullable `unitId`/`unitLabel`.
- `_buildCitationLine` (`documind_screen.dart:1369+`): render `'${citation.filename} · p.N'` → append ` · UNIT A` badge when `unitLabel != null`, styled like the existing Docs-tab unit badge (`documind_screen.dart:915-936`) so the two surfaces match.

### Phase 2 — Honest-unknown category predictor (backend only, small)

- `category_predictor.py`: in **both** the LLM-parse path (`:55-58`) and the keyword fallback (`:84-86`), when nothing matches return `predicted_categories: []`, `confidence: 0.0`, `reason: "no clear category signal"` — never `available_categories[0]`.
- Orchestrator contract: an empty prediction for a document question must route to `ask_confirmation` (the existing checkpoint at `documind_service.py:426` already builds options as `predicted + remaining available`, which degrades gracefully to "all available categories" when predicted is empty). Verify the graph's ask_confirmation trigger condition treats empty-prediction as low-confidence; adjust the threshold check if it currently only fires on non-empty predictions.
- Regression tests (extend `test_documind_orchestration.py` / add predictor unit tests): (a) no-signal question → empty prediction, not first category; (b) result is independent of `available_categories` ordering; (c) empty prediction → `needs_category_clarification=True` with all available categories offered.

### Phase 3 — Unit-ambiguity clarification checkpoint (backend + Flutter, medium)

A **post-retrieval** checkpoint, not a new graph node — unit ambiguity is only knowable after seeing which units the retrieved chunks belong to.

**Trigger** (in `documind_service.ask`, immediately after retrieval succeeds at `documind_service.py:545-552`): fire when **all** hold:
- `payload.unit_id` is `None` (user hasn't already scoped the chat), and
- `payload.user_action` is not a `unit:*` action (prevents re-trigger loops), and
- retrieved chunks contain **≥ 2 distinct non-null `unit_id`s**.

Single-unit properties, no-unit properties, property-wide-only retrievals, and already-filtered requests never trigger.

**Checkpoint response:** reuse the pending-confirmation machinery (`set_pending_confirmation`, storing `{question, unit_options}`):
- `AskResponse` gains `needs_unit_clarification: bool = False` and `unit_options: List[UnitOption]` where `UnitOption = {unit_id: str, unit_label: str}` (plus a sentinel `{unit_id: "all", unit_label: "All units"}` appended last).
- `clarification_prompt` reused: e.g. *"That question matches documents from Unit A and Unit B. Which unit do you mean?"*
- `user_action_required=True`, `citations=[]` (no answer yet).

**Resume path** (in the existing `user_action` dispatch, `documind_service.py:512-542`): new action forms `unit:<unit_id>` (re-run retrieval on the pending question with that unit filter) and `unit:all` (proceed unfiltered, no re-check). Both clear the pending confirmation.

**Flutter:** the chat's existing clarification-chip handling (category options) gains a parallel branch: when `needs_unit_clarification`, render one chip per `unit_options` entry; tapping sends the same question with `user_action: 'unit:<id>'`. Also set the `selectedDocumindUnitProvider` filter when a specific unit is chosen, so the Docs tab and follow-up questions stay scoped consistently.

**Tests:** service-level fake-retriever tests — multi-unit chunks + no filter → checkpoint with correct options; `unit:unit-A` action → filtered retrieval of pending question; `unit:all` → unfiltered answer, no loop; chunks from one unit + property-wide → **no** checkpoint.

### Phase 4 — Lease-upload unit nudge (Flutter only, small)

- `_pickUploadUnit()` (`documind_screen.dart:1064`) gains a `category` parameter (already available at the `_uploadDocument(category)` call site, `:1149`).
- When `category == 'lease'` and units exist: unit options listed first, "Whole property" demoted to last with subtitle copy *"Leases usually belong to a specific unit"*. Not hard-blocked — a property-wide master lease is legitimate; single-unit/no-unit properties keep today's skip behavior.
- All other categories: dialog unchanged.

### Phase 5 — Structured fact extraction + expiry surfacing (backend + Flutter, large; stretch)

The evaluation's "single highest-leverage step": units own facts, not just filtered lists. Spun out into its own full spec — see [`2026-07-06-documind-fact-extraction-design.md`](2026-07-06-documind-fact-extraction-design.md) for the complete design (FactExtractor, `documind_docs.extracted_facts` storage, upcoming-expiries dashboard tile, `UnitsScreen` facts line, tests). Independent of the other phases — no ordering dependency either way.

### Phase 6 — Unit lifecycle hygiene + PDF-only upload guard (backend + Flutter, small)

Covers the gaps surfaced by the post-spec cross-check (Problem items 6–7).

**Unit deletion — unassign, don't orphan:**
- New backend endpoint `POST /api/rex/documind/documents/unassign-unit` taking `(landlord_id, property_id, unit_id)`: batch-clears `unit_id`/`unit_label` on every matching `documind_docs` and `documind_chunks` record, converting them to property-wide. The backend keeps sole ownership of its collections — Flutter never writes them directly.
- Flutter unit-delete flow: when the unit has assigned documents (count taken from the already-fetched docs list), the delete-confirmation dialog states "N document(s) assigned to this unit will be kept as property-wide documents"; on confirm, call unassign first, then `deleteUnit`. Units with no documents keep today's flow untouched.
- Interaction with fact extraction (Phase 5 spec): an unassigned doc's expiry entries simply become property-level — no special-casing needed.

**Unit rename — resolve labels live:**
- Flutter resolves displayed unit labels by `unit_id` against the live units list (already streamed on every relevant screen), falling back to the stored denormalized `unit_label` when the unit no longer resolves. Applies to Docs-tab badges and Phase 1 citation badges.
- Accepted caveat: the backend's stored `unit_label` (used in the Phase 1 LLM context header) stays stale until re-upload — on-screen labels are always current; LLM attribution text may lag a rename. Documented, not fixed, in v1.

**PDF-only upload guard (decision 2026-07-08: PDF now, DOCX future):**
- Remove `.docx` from the picker allowlist and update the error copy to "Only PDF files are supported." (`documind_screen.dart:1134-1135`) — the backend ingest is `PyPDFLoader`-only and stores `application/pdf` unconditionally, so today a selected DOCX fails only after upload.
- Future DOCX work (a `Docx2txtLoader`-style path plus correct storage content type) is tracked in Non-goals, not here.

**Tests:** backend test for the unassign endpoint (target unit's docs and chunks cleared, other units untouched, idempotent on repeat); Flutter test for label resolution (existing unit → live label; deleted unit → stored-label fallback); picker test rejecting `.docx`.

## Data flow (target end state, demo flow)

1. Landlord uploads `lease.pdf` for Sunset Apartments, category `lease` → dialog leads with units (Phase 4) → picks Unit A → ingest chunks + extracts `lease_end` (Phase 5).
2. In chat, no unit filter set, asks "when does the lease expire?" → retrieval hits Unit A + Unit B lease chunks → checkpoint: *"Unit A / Unit B / All units"* (Phase 3).
3. Taps "Unit A" → answer synthesized from Unit A chunks only; citation reads `lease.pdf · p.3 · UNIT A` (Phase 1); Docs tab filter now shows Unit A (Phase 3 provider sync).
4. Dashboard shows "Unit A — lease expires in 60 days" (Phase 5).

## Error handling

- Phase 1: `None` unit fields flow through end-to-end untouched (pre-units chunks, property-wide docs) — no new failure modes.
- Phase 3: if the pending confirmation is missing/expired when a `unit:*` action arrives, fall back to treating the request as a fresh question (matches existing pending-confirmation fallback at `documind_service.py:536-542`).
- Phase 5: extraction is strictly best-effort; malformed LLM output → discard facts, log, continue. The expiry provider skips docs with missing/invalid dates.

## Testing

- Backend: pytest per phase as listed above, extending the existing suites (`test_retriever.py`, `test_documind_service_flows.py`, `test_documind_orchestration.py`, `test_rex_routes_documind_ask_api.py`). The evaluation harness (`test_documind_evaluation.py`) gains one multi-unit ambiguity scenario.
- Flutter: `flutter analyze` stays at the 0-error baseline; extend `documind_screen_checkpoint_action_test.dart` for the unit-chip branch (Phase 3). Manual verification of the four-step demo flow above is the acceptance test.

## Migration

None required. All new fields are optional/additive (`Citation.unit_label`, `AskResponse.needs_unit_clarification`/`unit_options`, `DocumentInfo.extracted_facts`); existing Firestore documents and pre-units chunks remain valid. Documents ingested before Phase 5 simply have no facts until re-uploaded — acceptable for demo data.
