# Upload Progress Bar — Design Spec

**Date:** 2026-07-29
**Branch:** `feat/finance-tab-restructure`
**Status:** Approved for planning

## Goal

Replace the static "Uploading document..." spinner overlay with a real-time
progress bar that reflects the actual document-ingestion pipeline stage as it
runs, so a landlord uploading a document sees genuine progress (not a fake
animation) — especially reassuring for slow scanned/photographed documents that
hit OCR.

## Why (context)

Today `DocuMindRemoteDataSource.uploadDocument` makes a single blocking
multipart POST to `/documind/upload`; `request.send()` waits for the entire
`ingest_document` pipeline (temp save → text/OCR → chunk → embed → write chunks
→ fact-extract → store metadata) and returns only at the end. The UI
(`documents_screen.dart`, `_buildUploadOverlay`) shows a `CircularProgressIndicator`
with a fixed "Uploading document..." label — no per-stage signal exists.

## Approach

Stream stage events over the **same** POST response. No job store, no polling,
no websockets. The pipeline stays synchronous and narrates itself; the client
reads the streamed response line-by-line. Chosen over "job + poll" (more
infrastructure, extra round-trips) and "simulated animation" (not real progress).

## Architecture

### 1. Backend — stage-emitting pipeline

`ingest_document` gains one optional keyword parameter `progress` (a callable
taking a stage-key string), defaulting to `None`.

- At each stage boundary the pipeline calls `progress(stage_key)` **before**
  performing that stage's work, so a slow stage (OCR) shows the stage it is
  currently in, not the previous one.
- When `progress is None`, behaviour is byte-identical to today. The existing
  `/documind/upload` endpoint and all current tests remain untouched.

Stage keys emitted, mapped to the real pipeline steps:

| stage key    | emitted before…                                   |
|--------------|---------------------------------------------------|
| `received`   | after temp file saved (Step 1)                    |
| `reading`    | text-layer extraction / OCR fallback (Step 2)     |
| `organising` | chunk splitting (Step 3)                           |
| `indexing`   | embedding + Firestore chunk write (Steps 4–5)     |
| `details`    | fact extraction (Step 6)                           |
| `done`       | terminal event, carries the result payload        |

The backend emits **stage keys only** — no user-facing copy, no percentages.
Wording and progress fractions live in the Flutter app so they can be tuned
without a backend redeploy.

### 2. New streaming endpoint

`POST /documind/upload/stream` — same multipart form fields as `/documind/upload`
(`landlord_id`, `property_id`, `category`, `file`, optional `unit_id`,
`unit_label`). Returns a `StreamingResponse` with media type
`application/x-ndjson`. One JSON object per line:

```
{"type":"stage","stage":"received"}
{"type":"stage","stage":"reading"}
{"type":"stage","stage":"organising"}
{"type":"stage","stage":"indexing"}
{"type":"stage","stage":"details"}
{"type":"result","result": { ...DocUploadResponse fields... }}
```

On failure, the stream ends with:

```
{"type":"error","message":"<message>"}
```

A `await asyncio.sleep(0)` immediately after each emit lets the
`StreamingResponse` flush the line before the next (blocking) stage runs. This
does not change existing server concurrency characteristics — today's
`ingest_document` already blocks the event loop for the duration of a request.

The existing `/documind/upload` endpoint is kept as-is alongside the new one
(back-compat + existing tests). Both delegate to the same `ingest_document`, so
there is no duplicated pipeline logic.

### 3. Stage → label → percent mapping (Flutter app owns this)

| stage key    | landlord-friendly label        | percent |
|--------------|--------------------------------|---------|
| `received`   | Received your document         | 10      |
| `reading`    | Reading the document           | 30      |
| `organising` | Organising the contents        | 50      |
| `indexing`   | Making it searchable           | 75      |
| `details`    | Pulling out the key details    | 92      |
| `done`       | All set                        | 100     |

Patience line rendered beneath the bar:
> This can take up to a minute for scanned or photographed documents — hang tight.

An unknown stage key maps to the last known percent and a neutral label
("Processing…"), so adding a backend stage later never crashes an older client.

### 4. Client data flow

`DocuMindRemoteDataSource.uploadDocument` gains an optional
`void Function(String stageKey)? onProgress` parameter. It reads
`StreamedResponse.stream` transformed by `utf8.decoder` then
`const LineSplitter()`:

- `type == "stage"` → `onProgress?.call(stage)`
- `type == "result"` → deserialize into `DocuMindDocumentModel` and return it
- `type == "error"` → throw `Exception(message)`
- stream ends without a `result` → throw (treated as failure)

`onProgress` threads through the repository interface + impl, the
`UploadDocument` usecase, and `uploadDocumentActionProvider` as an optional
parameter. Every existing caller omits it and is unaffected.

The datasource points at `ApiConstants.documindUploadStream` (new constant for
`/documind/upload/stream`).

### 5. UI

New reusable widget `UploadProgressOverlay`:

- A determinate progress bar reusing the existing `ProgressBar` visual
  aesthetic (rounded, subtle glow), driven by the stage's percent.
- Current landlord-friendly label above/beside the bar.
- Percentage text (e.g. "75%").
- The patience line beneath.
- No emojis — plain typography and existing icon glyphs only; elegant and
  professional.

Representation: the stage is carried as a plain **stage-key string** end to
end. A pure mapping helper (`uploadStageDisplay(stageKey) -> (label, percent)`,
backed by a small ordered enum/table) converts it to the label + percent from
the table above. This keeps one source of truth for copy and fractions.

`documents_screen.dart` (the primary upload surface) already holds
`_isUploading`. It adds a `String? _uploadStage` field, passes
`onProgress: (s) => setState(() => _uploadStage = s)` into the
upload action, and renders `UploadProgressOverlay` in place of the current
static spinner overlay (`_buildUploadOverlay`, ~line 671). On completion or
error the overlay is dismissed and `_uploadStage` reset, matching the existing
`_isUploading` lifecycle.

`finance_screen.dart`'s expense-document upload keeps its current spinner; it
can adopt `UploadProgressOverlay` in a later change. Out of scope here.

## Error handling

- Internal partial degradation (embedding quota failure → metadata-only, empty
  OCR → 0 chunks) already resolves to `done` inside `ingest_document`, so the
  bar completes normally.
- A hard failure emits `{"type":"error",...}` (or breaks the stream); the
  datasource throws; the existing catch in `documents_screen._uploadDocument`
  shows the current error UI and clears the overlay.

## Testing

**Backend:**
- `ingest_document(progress=cb)` invokes `cb` with the stage keys
  `received, reading, organising, indexing, details` in order, then returns the
  `DocUploadResponse`. Existing fakes for OCR/embeddings/Firestore are reused.
- `ingest_document` with no `progress` still returns the same
  `DocUploadResponse` (covered by existing tests; add one explicit assertion
  that omitting `progress` calls nothing).
- `/documind/upload/stream` yields NDJSON `stage` lines in order followed by a
  single `result` line whose payload matches the non-streaming endpoint's
  response for the same input.

**Frontend:**
- `uploadDocument` parses a canned NDJSON stream: fires `onProgress` for each
  `stage` in order and returns the model from the `result` event.
- `uploadDocument` throws when the stream ends with an `error` event and when it
  ends with no `result`.
- `UploadProgressOverlay` renders the correct label, percentage, and patience
  line for a given stage; an unknown stage falls back to "Processing…".

## Global constraints

- **No emojis** anywhere in UI copy or code — use icon glyphs; elegant/professional.
- **Landlord-friendly labels** — no pipeline jargon ("embedding", "chunking")
  in user-facing text.
- **Backend produces authoritative data; the app never recomputes finance
  figures** — unaffected here, but the streaming refactor must not alter the
  `DocUploadResponse` contract.
- **WIP isolation:** this feature edits `backend/rag/documind_service.py`,
  `backend/api/rex_routes.py`,
  `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`,
  and `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`
  — all carry uncommitted multi-session WIP. Stage only each task's named files
  by explicit path; stash WIP before any task touching a WIP file and restore
  after. Never `git add -A`/`.`.
- **Windows tests:** prefix backend test commands with `PYTHONIOENCODING=utf-8`.
- **Do not push.** Commit per task only.
