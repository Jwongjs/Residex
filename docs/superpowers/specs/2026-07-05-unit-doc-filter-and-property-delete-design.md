# Unit-Level Document Filtering + Property Deletion — Design

**Date:** 2026-07-05 · **Status:** Approved by user (design presented in-session, all three scoping questions answered with the recommended options)

## Goal

Two related features building on the new `properties/{id}/units` model:

1. **Unit-aware documents** — documents can optionally be assigned to a unit at upload; chat retrieval and the docs list can filter by unit. Filter layers become property → unit (optional) → category.
2. **Property deletion** — a delete action in the UI with a full cascade: property doc, its units subcollection, and all its Documind documents (chunks, metadata, stored PDFs).

## Decisions (locked with user)

- **Unit assignment is optional.** Upload dialog gets a "Unit" dropdown defaulting to "Whole property". Leases go to a unit; insurance/tax/building docs stay property-wide.
- **Unit filter = that unit's docs + property-wide docs.** Questions about Unit 3 also need building-level context.
- **Full cascade on property delete.** No orphaned chunks/PDFs; chat can never cite a deleted property's docs.
- **No backfill.** Existing docs have no `unit_id` field and are treated as property-wide forever.

## Feature 1: Unit-aware documents

### Backend data model

- `documind_docs` and `documind_chunks` gain two optional fields: `unit_id` (string|null) and `unit_label` (string|null, denormalized for display so listing never needs unit lookups).
- Old docs/chunks lack the fields entirely. **Because Firestore `where` filters cannot match documents missing a field, unit filtering is a Python post-filter, never a Firestore query filter.** Rule: a chunk/doc is visible under unit U iff `data.get('unit_id') in (None, U)`.

### Backend API (`backend/api/rex_routes.py`, `backend/rag/documind_service.py`, `backend/rag/retriever.py`)

- **Upload** (`POST /documind/upload`): new optional Form fields `unit_id`, `unit_label`. Stored on the metadata doc and every chunk (null when absent).
- **Ask** (`POST /documind/ask`): optional `unit_id` on `AskRequest`. `HybridRetriever.retrieve` gains optional `unit_id` param; after `_dense_search` returns candidates and **before** reranking, drop candidates where `c.get('unit_id')` is neither `None` nor the requested id (saves cross-encoder work).
- **List** (`GET /documind/documents`): optional `unit_id` query param; same post-filter applied to the streamed docs. `DocumentInfo` gains `unit_id`/`unit_label` so the app can show badges.

### Flutter UI

- **Upload dialog** (in `documind_screen.dart`): after a property is selected, show a "Unit" dropdown fed by `unitsForPropertyProvider(propertyId)`, default "Whole property" (sends no unit fields).
- **Documind header**: unit dropdown next to the existing property selector, default "All units". Selecting a unit scopes both the Docs list and chat questions (`unit_id` flows through datasource → repository → usecase → provider, mirroring the existing `categories` parameter).
- **Docs list rows**: show a small unit badge (the `unit_label`) when a doc is unit-assigned.

### Edge case (accepted)

Deleting a unit leaves its docs with a dangling `unit_id`. They remain visible under "All units" with their stale denormalized label, and are excluded when filtering by a *different* unit — same as before the deletion. No cleanup pass (demo app).

## Feature 2: Property deletion (full cascade)

### Backend

New endpoint: `DELETE /documind/properties/{property_id}/documents?landlord_id=...` → `documind_service.delete_documents_for_property(landlord_id, property_id)`. Streams `documind_docs` where `landlord_id`+`property_id` match and reuses the existing per-doc deletion logic (chunks batch-delete, Storage blob delete, metadata delete). Returns `{documents_deleted, chunks_deleted}`. Idempotent: zero matches is success.

### Flutter

- `PropertyCard` gains an `onDelete` callback rendered as a delete icon next to the existing edit icon.
- `landlord_portfolio_screen.dart` wires it to a confirmation dialog (styled like the unit-delete dialog) spelling out the cascade: the property, all its units, and all its documents/PDFs.
- On confirm, child-first order so a mid-failure never strands unreachable data:
  1. Backend bulk document delete (via new datasource → repository → usecase chain method).
  2. Delete all docs in `properties/{id}/units` (client-side, via existing `UnitRemoteDataSource`; add `deleteAllUnitsForProperty`).
  3. Delete the property doc (existing `deleteProperty` chain — already fully built, just never wired to UI).
- Failure at any step → SnackBar with the error; retry is safe (each step idempotent).

## Testing

- Backend pytest: unit-filter tests for `retrieve` post-filter and `list_documents` (old-doc-without-field case included), bulk-delete test extending the existing fake-Firestore fixtures in `test_documind_service_flows.py`.
- `flutter analyze`: 0 errors.
- Manual verification: upload with/without unit, filter chat + docs by unit, delete a property and confirm Firestore/Storage are clean.

## Out of scope

- DOCX ingestion (pre-existing gap), backfilling old docs, unit-delete doc cleanup, Cloud Functions.

## Build order

1. Property deletion (small, self-contained).
2. Unit-aware documents backend.
3. Unit-aware documents Flutter UI.
