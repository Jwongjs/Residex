# Citation Source Viewer (Design)

**Date:** 2026-07-05
**Status:** Approved, pre-implementation
**Scope:** New feature — tapping a citation in the Documind relevance meter opens the original source PDF, jumped to the cited page.

---

## 1. Background

Today, `Citation` (in both the backend `documind_models.py` and the Flutter `documind_document.dart`) carries `doc_id`, `filename`, `category`, `page`, `snippet`, and `score` — but no reference to the original file, because the original file doesn't exist anywhere after ingestion. `ingest_document` in `documind_service.py` saves the uploaded PDF to a temp file, extracts text via `PyPDFLoader`, generates embeddings, and discards the temp file — only extracted text chunks + embeddings persist in Firestore.

This means "tap a citation to view the source" requires persisting the original file somewhere durable, plus a way to fetch and render it with a page-jump in the Flutter app.

Cost/durability tradeoffs were discussed and resolved:
- A fully local (on-device only) store was rejected — if the uploading device is lost, reset, or replaced, every citation referencing files from that device becomes permanently unopenable with no recovery path. Durability across devices/reinstalls matters.
- A cloud-backed store (Firebase Storage) was chosen instead, paired with an on-device cache so repeat views of the same document don't re-download. Storage + egress costs for landlord documents (small PDFs, occasional views) are minor; Q&A itself never touches Storage since that's driven entirely by Firestore text/embeddings — this feature only adds cost when a user actively taps to view a source.

---

## 2. Storage & ingestion

- Add `google-cloud-storage` to backend dependencies. Reuses the same service-account credentials already used for `google-cloud-firestore` (ambient application-default credentials via `GOOGLE_APPLICATION_CREDENTIALS`) — no new auth setup.
- In `ingest_document`, after the existing text-extraction steps, upload the original PDF bytes (already read into memory / on temp disk during ingestion) to Firebase Storage at a path like:
  `documind/{landlord_id}/{property_id}/{doc_id}.pdf`
- Store this storage path so it can be looked up by `doc_id` later — either as a field on each chunk document (simplest, no new collection) or a small per-`doc_id` metadata document. Given chunks already carry `doc_id`, `filename`, etc. per-chunk, adding `storage_path` alongside those existing fields is the simpler option and avoids a new collection.
- In `delete_document` (`documind_service.py:741`), also delete the corresponding Storage object so Storage and Firestore stay in sync — no orphaned files after a document is removed.

## 3. Fetching a document to view

New endpoint: `GET /api/rex/documind/documents/{doc_id}/view-url?landlord_id=...&property_id=...`

- Verifies the `doc_id` belongs to the given `landlord_id`/`property_id` (same scoping already used elsewhere, e.g. `delete_document`).
- If found, generates a short-lived signed URL (10-minute expiry) for the Storage object and returns it.
- If the `doc_id` doesn't exist (deleted, or predates this feature and was never uploaded to Storage), returns 404.
- The Flutter client never holds long-lived Storage credentials — it always goes through this endpoint, keeping document access scoped the same way as the rest of the API.

## 4. Client-side viewing

Dependencies: `syncfusion_flutter_pdfviewer` (page-jump support, works across this app's Android/iOS/Windows targets), plus `path_provider` for a local file cache.

- **Tap target:** the entire citation row in `_buildCitationLine` becomes tappable (not just the filename text), consistent with other list rows in the app (e.g. property cards).
- **Cache check:** a simple file cache keyed by `doc_id`, stored under the app's documents directory (`path_provider`). If a cached copy exists, skip the network fetch entirely.
- **Cache miss:** call the view-url endpoint, download the PDF from the returned signed URL, write it to the cache, then proceed to view.
- **Viewing:** open a new `DocumentViewerScreen` (new screen/route) with `SfPdfViewer.file(...)`, using its controller to jump to `citation.page` once the document finishes loading.
- **Error handling:** if the view-url call 404s or the download fails for any reason, show a snackbar — "This document is no longer available" — instead of opening a broken/empty viewer.

## 5. Scope boundaries

- **PDFs only.** DOCX ingestion isn't implemented on the backend today (`PyPDFLoader` is the only loader wired up, even though the upload dialog's file picker accepts `.docx`) — that's a separate, pre-existing gap, not addressed by this feature. Citations for DOCX-derived chunks (if any ever exist) simply won't have a Storage-backed viewer; this is a latent inconsistency to flag, not fix here.
- **No backfill.** Documents uploaded before this feature ships have no Storage copy. Their citations show as today (no tap-to-view), or tapping shows the same "not available" message as a deleted document — whichever the 404 path naturally produces, since there's no storage_path field on those old chunk records.
- **No changes to retrieval/scoring.** This feature is purely additive to citation display — it doesn't touch `_rerank`, the dedup logic, or the relevance-bar rendering added in the prior fix pass.

## 6. Testing / verification

- Backend: unit test for the new view-url endpoint (found → signed URL returned; not-found/wrong-scope → 404); verify `delete_document` also removes the Storage object (can mock the storage client, matching the existing `_build_service()` test harness pattern).
- Flutter: `flutter analyze` clean; manual check — tap a citation for a freshly uploaded document, confirm the viewer opens and lands on the correct page; tap a citation for a deleted document, confirm the friendly error shows instead of a crash; re-tap the same citation twice, confirm the second open is instant (served from cache, no second network fetch — can verify via a debug print or network log).
- No impact to existing backend test suite baseline (17 passed / 2 pre-existing failures, unrelated to this change).
