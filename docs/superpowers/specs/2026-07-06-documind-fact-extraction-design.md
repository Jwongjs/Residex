# DocuMind Fact Extraction & Expiry Intelligence — Design Spec

**Date:** 2026-07-06
**Status:** Draft (pending user review)
**Origin:** [`docs/2026-07-06-documind-unit-scoping-and-product-evaluation.md`](../../2026-07-06-documind-unit-scoping-and-product-evaluation.md) §3, "The single highest-leverage next step".
**Relationship:** Expands and supersedes the Phase 5 sketch in [`2026-07-06-documind-unit-intelligence-design.md`](2026-07-06-documind-unit-intelligence-design.md). Independent of that spec's other phases (1–4 and 6) — no ordering dependency either way.

## Problem

Documents are indexed for retrieval only. The ingest pipeline (`documind_service.py:219-329`: parse → chunk → embed → batch-write chunks → upload PDF → write `documind_docs` metadata) extracts nothing structured — a lease's expiry date, rent, and deposit exist only as embedded prose. Consequences:

- **Units own no facts.** "Unit A's lease ends 2026-09-01" is answerable only by asking the chatbot the right question at the right time. The unit↔document link is a list filter, not knowledge.
- **The app is entirely reactive.** The dashboard (`landlord_dashboard_screen.dart:133-152`) shows stat tiles, a DocuMind entry card, and property rows — nothing proactive. A landlord learns a lease lapsed by noticing it themselves, which is precisely the failure mode the product exists to prevent.
- **The demo has no closing beat.** "Ask a question, get an answer" is table stakes (NotebookLM does it); "Unit A's lease expires in 60 days" is the system-of-record moment that differentiates the product (evaluation §3).

Current-state facts verified against the codebase:
- Backend `list_documents` (`documind_service.py:720-781`) already supports landlord-wide queries — `property_id` is optional — so a cross-property expiry fold needs no new endpoint.
- The Flutter datasource mirror (`documind_remote_datasource.dart:111-115`) likewise takes optional `propertyId`/`unitId`.
- `CategoryPredictor` (`category_predictor.py`) establishes the house pattern for small injected-LLM helpers: constructor-injected `llm`, semicolon `key=value` response format, defensive parse, deterministic fallback — fully testable with a fake LLM.
- `UnitsScreen` (`4-Portfolio/units_screen.dart`) renders one row per unit (label, rent, occupancy) with no document awareness.

## Goals

- At ingest, one additional LLM call extracts category-specific structured facts (dates, amounts) from the document text and stores them on the document's metadata.
- A unit's facts are queryable through the existing documents list (no new endpoint), and `UnitsScreen` displays the key lease facts on each unit row.
- A dashboard "Upcoming expiries" tile lists every lease/warranty/insurance end date within the next 90 days across the landlord's whole portfolio, soonest first, tappable through to the relevant document.
- Extraction is strictly best-effort: an extraction failure never blocks, delays, or degrades document ingestion.

## Non-goals

- **No push notifications** (FCM stays README roadmap Phase 3) — "reminders" in v1 means the in-app expiry tile, not scheduled alerts.
- **No fact editing UI** — v1 facts are read-only; the correction path is re-uploading the document.
- **No backfill/re-extraction endpoint** for already-ingested documents — demo data is re-uploaded through the app, matching the no-migration stance of the unit-level-rent spec.
- **No extraction for `utility`, `receipt`, `other`** — v1 covers only the reminder-driving categories (lease, warranty, insurance). Spend/analytics folds over receipts are a separate future feature.
- **No OCR or new parsers** — extraction reads the text `PyPDFLoader` already produced; scanned-image PDFs that yield no text yield no facts, silently. Ingestion is PDF-only (decision 2026-07-08); DOCX support is future work — the upload picker is aligned to PDF-only in the unit-intelligence spec's Phase 6.
- **No writes to the Flutter-owned `properties/{pid}/units/{uid}` subcollection** — the backend stays owner of its own collections; "a unit's facts" is a query, not a copy.

## Architecture

### FactExtractor (new, backend)

`backend/rag/fact_extractor.py`, mirroring `CategoryPredictor`'s shape: constructor takes the injected `llm`; one public method `extract(category: str, text: str) -> dict | None`. Returns `None` immediately for non-extractable categories. Prompt asks for the category's schema in the same semicolon `key=value` response format `CategoryPredictor` already uses (proven parseable, trivially fake-able in tests):

```
lease_end=2026-09-01;monthly_rent=1500;deposit=3000;lease_start=2025-09-01;confidence=0.9
```

Per-category schemas (fields the prompt requests; `?` = optional, omitted when absent):

| Category | Fields |
|---|---|
| `lease` | `monthly_rent`, `deposit`, `lease_start`, `lease_end`, `tenant_name?` |
| `warranty` | `item`, `warranty_end` |
| `insurance` | `policy_end`, `premium?`, `policy_number?` |

Parse rules: dates must normalize to ISO `YYYY-MM-DD` (the prompt demands it; the parser validates with `date.fromisoformat` and drops non-conforming values); amounts parse as floats, dropping currency symbols; any unparseable field is omitted, never guessed. An empty parse result or LLM exception returns `None`. No keyword fallback — unlike category prediction, there is no sane heuristic for extracting a date, and per the evaluation's predictor critique, admitting "unknown" beats fabricating.

Input text: the concatenation of `pages` text already loaded at `documind_service.py:245`, truncated to the first ~8,000 characters — key lease/warranty/policy terms front-load in real documents, and this bounds cost/latency to one small call.

### Ingest hook (backend, modified)

In `ingest_document`, between the chunk batch-commit (`:294`) and the metadata write (`:305`), wrapped so no exception escapes:

```python
extracted_facts = None
try:
    extracted_facts = self._fact_extractor.extract(category, full_text)
except Exception as e:
    print(f"⚠️ Fact extraction failed (non-blocking): {e}")
```

The metadata document (`documind_docs`) gains three optional fields:

```python
'extracted_facts': extracted_facts,        # dict | None, e.g. {'lease_end': '2026-09-01', 'monthly_rent': 1500.0}
'facts_confidence': confidence,            # float | None, from the extractor's confidence field
'facts_extracted_at': firestore.SERVER_TIMESTAMP,   # only when extraction succeeded
```

### API surface (backend, modified)

- `DocumentInfo` (`documind_models.py:102-113`) gains `extracted_facts: dict | None = None` and `facts_confidence: float | None = None`; `list_documents` (`documind_service.py:762-773`) passes them through from the metadata document. Docs written before this feature simply have no field → `None`, no special-casing.
- `DocUploadResponse` gains `extracted_facts: dict | None = None` so the upload flow can immediately confirm what was captured ("Lease indexed — ends 2026-09-01").
- No new routes.

## Flutter surfacing

**Model layer:** `DocuMindDocumentModel` (`data/models/documind_models.dart`) and the `DocuMindDocument` entity parse the two new optional fields. Dates are parsed with `DateTime.tryParse`; a failed parse is treated as absent.

**Upcoming-expiries provider** (new, in the documind providers file): fetches landlord-wide documents via the existing `listDocuments(landlordId)` (no `propertyId`), and folds every doc whose `extracted_facts` contains `lease_end` / `warranty_end` / `policy_end` within the next 90 days into a sorted (soonest-first) list of expiry entries `{docId, propertyId, unitId?, unitLabel?, category, filename, kind, date}`. When one unit has multiple documents of the same category with facts, only the most recently uploaded one counts — a re-uploaded lease supersedes the old one's dates. The fold is pure Dart over the fetched list (portfolio sizes here are tens of docs, not thousands).

**Dashboard tile:** an "UPCOMING EXPIRIES" card inserted in `_buildContent` after the stat tile row (`landlord_dashboard_screen.dart:133`), styled like the existing `_buildDocumindEntryCard` glass card. Shows up to 3 entries — e.g. `Unit A · Lease ends 1 Sep 2026 (in 57 days)` — with urgency color (≤30 days error red, ≤60 amber, else standard) using existing `AppColors` tokens and icon glyphs (no emoji, per app convention). Empty state: the tile is hidden entirely (no "nothing expiring" noise). Tapping an entry navigates to the DocuMind screen with that property selected and, when the entry is unit-scoped, the unit filter (`selectedDocumindUnitProvider`) preset.

**`UnitsScreen` facts line:** the screen already knows its `propertyId`; one documents fetch per screen build (existing provider) maps `unitId → most recent lease doc's facts`. A unit row whose unit has lease facts shows a secondary line: `Lease ends 2026-09-01 · RM 1,500/mo` (synthetic example). Units without facts render exactly as today.

## Data flow

1. **Upload:** landlord uploads `unit-a-lease.pdf` (category `lease`, Unit A) → ingest parses/chunks/embeds as today → `FactExtractor.extract('lease', text)` → metadata written with `extracted_facts` → upload confirmation surfaces the captured end date.
2. **List:** Docs tab and `UnitsScreen` receive `extracted_facts` on each `DocumentInfo` through the unchanged list endpoint.
3. **Dashboard:** `upcomingExpiriesProvider` folds landlord-wide docs → tile renders the ≤90-day entries → tap lands on DocuMind scoped to that property/unit.
4. **Demo beat:** create property with units → upload Unit A's lease → dashboard immediately shows "Unit A · Lease ends … (in 57 days)" → tap through → ask the chatbot for the clause → cited answer.

## Error handling

- Extraction failure (LLM error, empty text, garbage response) → `extracted_facts: None`, document still fully indexed; the only trace is a log line. This invariant is test-enforced.
- Scanned PDFs with no text layer produce empty `full_text` → extractor returns `None` before calling the LLM.
- Expiry provider skips docs with `None` facts, missing date fields, or dates that fail `DateTime.tryParse` — a malformed date can never crash the dashboard.
- Deleted units: per the unit-intelligence spec's Phase 6, deleting a unit unassigns its documents to property-wide, so their expiry entries surface as property-level. Expiry-entry unit labels are resolved live by `unit_id` against the units list, falling back to the stored label — an entry can never point at a unit picker option that no longer exists.
- Dates are calendar dates (no timezones); "days remaining" is computed against the device's local date.
- `facts_confidence` is stored but v1 surfaces facts regardless of confidence — with re-upload as the correction path, hiding low-confidence facts would just make the feature look broken. Revisit if judged demos show bad extractions.

## Testing

- **`FactExtractor` unit tests** (new file, fake LLM per `CategoryPredictor` test pattern): well-formed response → parsed dict; partial response → partial dict with malformed fields dropped; garbage/empty response → `None`; LLM raises → `None`; non-extractable category → `None` without invoking the LLM; non-ISO date dropped by `fromisoformat` validation.
- **Ingest flow** (extend `test_documind_service_flows.py`): extraction raising mid-ingest still indexes the document and writes metadata with `extracted_facts: None`; successful extraction lands in the metadata write and in `DocUploadResponse`.
- **List passthrough** (extend `test_rex_routes_documind_docs_api.py`): docs with and without `extracted_facts` round-trip correctly; pre-feature docs (no field) yield `None`.
- **Flutter:** `flutter analyze` stays at the 0-error baseline; a pure-Dart unit test for the expiry fold (90-day window boundary, soonest-first ordering, most-recent-doc-wins dedupe, malformed-date skip). Manual acceptance: the four-step demo beat above.

## Migration

None. All fields are additive and optional; existing `documind_docs` documents without `extracted_facts` behave as "no facts" everywhere. Demo documents are re-uploaded through the app to gain facts — no backfill code.
