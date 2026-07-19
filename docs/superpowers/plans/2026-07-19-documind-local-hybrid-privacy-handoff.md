# Handoff — DocuMind Local-Hybrid Privacy Architecture (Option 3)

**Date:** 2026-07-19 · **Branch:** main (work-in-place, user-consented) · **From:** Plan E session + local-stack experiment

## The decision (user-approved)

Adopt **Option 3 — hybrid**: self-host the sensitive legs (OCR, embeddings, and anything that sees raw document text) on our own machine/server via Ollama; use a hosted LLM API only for chat-style generation. Hard requirement, user verbatim:

> "the system should prevent sensitive information from chunks be passed onto the hosted API"

Context: real documents (signed tenancy agreements, tax bills) contain names, addresses, NRIC numbers, IC photos, signatures. NRIC is sensitive personal data under Malaysian PDPA. The Gemini **free tier** may use submitted data for product improvement — unacceptable for these docs.

## What is already done (committed on main)

- **Plan E complete** (`1ad3f6d`..`0e277ee`): 3 display folders, camera/photo/file upload sources, expense-line review sheet with PATCH save, expiry tile reads `policy_end`, plus regression fix `0e277ee` (granular `_overrideCategories` for chat checkpoint).
- **Ingestion bug root-caused and fixed** (`5d4a753`, 152 backend tests pass):
  - Trigger: `2023 Final Agreement Ayer 8 and JNT 25102023 [Signed].pdf` — 15 pages, **all scanned images, zero text layer** → OCR fallback → ~30 chunks.
  - Bug 1: `embeddings` property in [backend/rag/documind_service.py](../../../backend/rag/documind_service.py) was missing its `None` guard → re-created the Gemini client per chunk (the "Initializing Gemini embeddings" loop the user saw).
  - Bug 2: per-chunk `embed_query` calls → ~30 rate-limited API calls with retry grind until 429 quota exhaustion.
  - Fix: client built once; single batched `embed_documents`; batch failure fails fast into the existing metadata-only path. Tests: `EmbeddingClientAndBatchingTests` in `tests/test_documind_service_flows.py`.
- **Local stack installed on this machine** (RTX 3050 4 GB VRAM, 15.4 GB RAM, Ryzen 7 5800H):
  - Ollama at `%LOCALAPPDATA%\Programs\Ollama` (add to PATH; server `http://localhost:11434`) with models: `nomic-embed-text` (**768-dim — matches `EMBED_DIM` at documind_service.py:39, so the Firestore vector index shape is unchanged**), `qwen3:4b` (chat), `qwen2.5vl:7b` (vision OCR).
  - Tesseract at `C:\Program Files\Tesseract-OCR\tesseract.exe` (**eng traineddata only — Malay not installed**; bills contain Malay).
- **Benchmark script:** [backend/scripts/local_stack_bench.py](../../../backend/scripts/local_stack_bench.py) — embeddings (30×1000-char batch, cold+warm), OCR (Tesseract vs qwen2.5vl on real agreement page 3 + real maintenance-bill photo), chat (qwen3:4b, cold+warm, tok/s).
  - **Numbers were still running at handoff — no results recorded yet.** Rerun with `cd backend && python -u scripts/local_stack_bench.py`.
  - ⚠️ The script writes OCR output (contains PII) to `Path(__file__).parent` — **before running the repo copy, redirect `SCRATCH` to a temp dir so PII text never lands in the repo.** Do not commit its outputs.
  - Success criteria agreed with user: 30-chunk embed in seconds; OCR page in seconds-to-tens-of-seconds; chat ≥10 tok/s with first token in a few seconds.

## Target architecture

| Leg | Provider | Notes |
|---|---|---|
| OCR (scanned PDFs, photos) | **Local** — qwen2.5vl:7b via Ollama, or Tesseract if VLM too slow | Replaces the Gemini call in [backend/rag/pdf_ocr.py](../../../backend/rag/pdf_ocr.py) |
| Embeddings (ingest + query) | **Local** — nomic-embed-text via Ollama | Ingest at documind_service.py Step 4; query at [backend/rag/retriever.py](../../../backend/rag/retriever.py) `embed_query`. Use nomic prefixes: `search_document:` / `search_query:` |
| Fact extraction | **Local** (qwen3:4b JSON) — it sees full leading text, so it must not go hosted unscrubbed | [backend/rag/fact_extractor.py](../../../backend/rag/fact_extractor.py) |
| Chat / answer generation | **Hosted** (Gemini; move to paid tier) | Context chunks pass through the PII gate first |
| Category prediction / router | Decide: local or hosted-with-scrub (sees question text only) | |

**PII gate (new module, the user's hard requirement):** a pure `scrub_for_hosted(text) -> str` in `backend/rag/` applied at every boundary where text leaves to a hosted API (chat context assembly, and any hosted prompt). Regex-reliable: Malaysian NRIC (`\d{6}-\d{2}-\d{4}` + unhyphenated 12-digit), phone, email → replace with `[NRIC]`/`[PHONE]`/`[EMAIL]` tokens. Names/addresses are NOT regex-catchable — mitigate by keeping full-text legs local (above) so the hosted API only ever sees chunk excerpts post-scrub. Unit-test the scrubber with synthetic values only.

**Provider wiring:** env flags read in `documind_service.py` (e.g. `EMBEDDINGS_PROVIDER=ollama|gemini`, `OCR_PROVIDER=local|gemini`, `CHAT_PROVIDER`, `OLLAMA_BASE_URL`). A tiny adapter class exposing `embed_documents`/`embed_query` over Ollama's `/api/embed` (plain `requests`) avoids adding `langchain-ollama` as a dependency; `langchain-ollama` is the alternative if chat also goes local later. **`langchain-ollama` is NOT installed.**

## Known consequences / gotchas

- **Switching embedding models changes the vector space** → all existing `documind_chunks` must be re-embedded (migration script: iterate chunks, re-embed `text` locally, overwrite `embedding`). Currently 11 Damai docs. Dim stays 768 so the Firestore index needs no change. Retriever and ingest must always use the same provider.
- `MAX_OCR_PAGES = 10` in pdf_ocr.py silently drops pages 11-15 of the agreement (unindexed). Fix alongside the OCR provider work (per-page loop or second batch).
- Production framing (discussed, user-aligned): phone → hosted backend → models; "local" means "on the backend host". Serverless can't hold Ollama models resident — needs a persistent VM (GPU ≈ $250+/mo) when it leaves the laptop. `api_constants.dart:2` hardcodes `http://10.0.2.2:8000` — production needs HTTPS + real URL regardless.
- Ayer 8 real docs are staged on the emulator (`/sdcard/Download/ayer8` for file picker, `/sdcard/Pictures/ayer8` in gallery). Old synthetic ayer8 docs already deleted from backend. Property `Jji2DVn5QrY1fP3V7maY` is *probably* Ayer 8 but the user could not confirm — **do not write to it via the API without confirming**; user uploads in-app.

## Next steps (ordered)

1. Rerun/collect benchmark numbers; record them here; verdict vs the success criteria (decides qwen2.5vl vs Tesseract for OCR, and whether chat-local is even plausible later).
2. Ollama embeddings adapter + `EMBEDDINGS_PROVIDER` flag + tests (mirror `_FakeEmbeddings` harness pattern in `test_documind_service_flows.py`; TDD).
3. OCR provider flag in the `PdfOcr` path (+ fix the 10-page cap) + tests.
4. PII scrub module + tests; apply at the chat-context boundary in `ask_documind` and any remaining hosted prompt.
5. Fact extraction → local model (or scrubbed), tests.
6. Chunk re-embedding migration script; run it; verify search still returns the Damai fixtures.
7. E2E on emulator: upload the real signed agreement → ingestion completes with zero hosted calls for OCR/embeddings; chat still answers; review sheet flow intact.

## Environment quick-reference

- Backend: `cd backend && python -m pytest tests -q` → 152 pass. Launch stack per `run_all.ps1` (see memory `documind-run-setup`).
- Flutter: `cd residex_app && flutter test test/features/landlord` → 54 pass (repo-root `widget_test.dart` boilerplate failure is pre-existing).
- App conventions: no emoji in UI (icons only); clean-architecture layering; the app formats, never computes.
- GateGuard hooks are active in this repo: present facts before the first Bash of a session and before every Edit/Write (importers via Grep, affected symbols, data shapes, verbatim user instruction), then retry the identical call.
