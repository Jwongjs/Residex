# DocuMind `rag/` service decomposition — reorg report

Pure structural move of 16 of the 21 files in `backend/rag/` into four new
subfolders (`providers/`, `documents/`, `ask/`, `finance/`), with all
import-path and mock-patch-target references updated to match. No logic
changes. No `__init__.py` files added (namespace-package convention
preserved). No files renamed — only relocated.

## Files moved (git mv, history preserved)

**`rag/providers/`**
- `rag/ollama_chat.py` -> `rag/providers/ollama_chat.py`
- `rag/ollama_embeddings.py` -> `rag/providers/ollama_embeddings.py`
- `rag/groq_chat.py` -> `rag/providers/groq_chat.py`

**`rag/documents/`**
- `rag/ingestion_service.py` -> `rag/documents/ingestion_service.py`
- `rag/document_lifecycle_service.py` -> `rag/documents/document_lifecycle_service.py`
- `rag/pdf_ocr.py` -> `rag/documents/pdf_ocr.py`
- `rag/fact_extractor.py` -> `rag/documents/fact_extractor.py`
- `rag/expense_scanner.py` -> `rag/documents/expense_scanner.py`

**`rag/ask/`**
- `rag/ask_orchestrator.py` -> `rag/ask/ask_orchestrator.py`
- `rag/graph_orchestrator.py` -> `rag/ask/graph_orchestrator.py`
- `rag/conversation_router.py` -> `rag/ask/conversation_router.py`
- `rag/conversation_store.py` -> `rag/ask/conversation_store.py`
- `rag/category_predictor.py` -> `rag/ask/category_predictor.py`
- `rag/retriever.py` -> `rag/ask/retriever.py`

**`rag/finance/`**
- `rag/finance_engine.py` -> `rag/finance/finance_engine.py`
- `rag/finance_overrides_repository.py` -> `rag/finance/finance_overrides_repository.py`

**Unmoved (stayed at `rag/` root, as instructed):**
`rag/documind_service.py`, `rag/categories.py`, `rag/unit_resolution.py`,
`rag/property_directory.py`, `rag/pii_scrub.py`.

All 16 `git mv` operations registered as `R100` (pure rename, no content
diff) before the import-path edits were applied on top.

## Import / patch-target sites updated

Applied via a scripted regex substitution over `\brag\.<old_module>\b` ->
`rag.<new_dotted_path>` across exactly the files below (chosen after a
repo-wide grep for every old dotted path; this list turned out to match
the dispatch's "known reference sites" list plus the full test file set).

- `backend/rag/documind_service.py` — 15 lines updated (lines 19–29, 44–47 in
  the pre-edit file): `conversation_router`, `category_predictor`,
  `fact_extractor`, `ollama_chat`, `groq_chat`, `pdf_ocr`,
  `ollama_embeddings`, `conversation_store`, `graph_orchestrator`,
  `retriever`, `finance_engine`, `finance_overrides_repository`,
  `document_lifecycle_service`, `ingestion_service`, `ask_orchestrator`.
  (`categories`, `unit_resolution`, `property_directory` imports left
  untouched — correct, those didn't move.)
- `backend/rag/documents/document_lifecycle_service.py` — 2 replacements:
  `rag.fact_extractor` -> `rag.documents.fact_extractor`,
  `rag.finance_engine` -> `rag.finance.finance_engine`. (`rag.categories`
  import left unchanged.)
- `backend/rag/documents/fact_extractor.py` — 1 replacement:
  `rag.expense_scanner` -> `rag.documents.expense_scanner` (same-folder,
  kept as full absolute path per instructions, not made relative).
- `backend/rag/finance/finance_engine.py` — 1 replacement:
  `rag.fact_extractor` -> `rag.documents.fact_extractor`.
- `backend/rag/ask/ask_orchestrator.py` — 0 replacements needed; its
  imports of `rag.categories`, `rag.pii_scrub`, `rag.unit_resolution` are
  all unmoved targets, confirmed unchanged.
- `backend/rag/documents/ingestion_service.py` — 0 replacements needed;
  its `rag.categories` import is an unmoved target, confirmed unchanged.
- `backend/api/rex_routes.py` — confirmed no edit needed (only imports the
  unmoved `rag.documind_service`).
- `backend/scripts/reembed_chunks_local.py` — 1 replacement:
  `rag.ollama_embeddings` -> `rag.providers.ollama_embeddings`.
- Test files (18 files, 62 replacements total — both `from rag.X import Y`
  and `patch("rag.X....")` string targets):
  - `backend/tests/test_documind_groq_routing.py` — 2
  - `backend/tests/test_documind_orchestration.py` — 2
  - `backend/tests/test_documind_service_flows.py` — 14 (includes 6
    `patch("rag.ingestion_service.PyPDFLoader")` mock-target strings and 2
    inline `from rag.ollama_embeddings...` / `from rag.ollama_chat...`)
  - `backend/tests/test_expense_scanner.py` — 1
  - `backend/tests/test_expense_scanner_realdocs.py` — 1
  - `backend/tests/test_fact_extractor.py` — 3
  - `backend/tests/test_finance_chat.py` — 2
  - `backend/tests/test_finance_engine.py` — 10
  - `backend/tests/test_groq_chat.py` — 6 (5 are `patch("rag.groq_chat...")`
    mock targets)
  - `backend/tests/test_ocr_local.py` — 8 (7 are `patch("rag.pdf_ocr...")`
    mock targets)
  - `backend/tests/test_ollama_chat.py` — 6 (5 are
    `patch("rag.ollama_chat...")` mock targets)
  - `backend/tests/test_ollama_embeddings.py` — 5 (4 are
    `patch("rag.ollama_embeddings...")` mock targets)
  - `backend/tests/test_pdf_ocr.py` — 1
  - `backend/tests/test_retriever.py` — 1

Total: 15 (documind_service.py) + 2 + 1 + 1 (source files, excl. the two
zero-diff confirmations) + 1 (script) + 62 (tests) = 82 replacements.

### False positives correctly left alone

A broad grep for bare module names (not just `rag.X`) also matched local
variable/parameter names that happen to share a name with a moved module —
these are not import references and were correctly NOT touched:
- `rag/ask/ask_orchestrator.py`: constructor params/attrs
  `conversation_store`, `graph_orchestrator` (local names, not imports).
- `rag/ask/graph_orchestrator.py`: constructor params/attrs
  `conversation_router`, `category_predictor`.
- `rag/ask/retriever.py`: a docstring/comment mentioning "retriever".
- `rag/providers/ollama_embeddings.py`: a comment mentioning "retriever".

### Documentation files not touched (out of scope)

`architecture.md`, `Documind.md`, `DOCUMIND_CHECKLIST.md`, `EXPENSE_MODEL.md`,
`rag/GRAPH_OVERVIEW.md`, `rag/DOCUMENT_TYPE_CATEGORIES_AND_FILE_FORMATS.md`,
and `requirements.txt` contain prose references / relative-path links to
old filenames (e.g. `graph_orchestrator.py`, `fact_extractor.py:242`).
These are documentation, not code — the dispatch scoped this pass to Python
import/patch-target updates only ("pure structural move ... zero logic
changes"), so these were intentionally left as-is. Flagging in case a
follow-up doc-sync pass is wanted.

## Verification

1. **Post-move re-grep for stale old dotted paths** (entire `backend/`
   tree, `.py` files, excluding `__pycache__`):
   ```
   grep -rn --include="*.py" -E "\brag\.(ollama_chat|ollama_embeddings|groq_chat|
   ingestion_service|document_lifecycle_service|pdf_ocr|fact_extractor|
   expense_scanner|ask_orchestrator|graph_orchestrator|conversation_router|
   conversation_store|category_predictor|retriever|finance_engine|
   finance_overrides_repository)\b" .
   ```
   Result: **zero matches.**

2. **Import-chain check** (from `backend/`):
   ```
   python -c "import rag.documind_service"
   python -c "from api.rex_routes import router"
   ```
   Both succeeded. (First attempt without `PYTHONIOENCODING=utf-8` hit a
   pre-existing, unrelated `UnicodeEncodeError` from an emoji `print()` in
   `documind_service.py` on Windows' cp1252 console — not caused by this
   move; re-ran with `PYTHONIOENCODING=utf-8` and both imports succeeded
   cleanly, printing the normal service-init log lines.)

3. **Full test suite**:
   ```
   cd backend && python -m pytest tests/ -q
   ```
   Result: **468 passed** in 63.25s. Same count as before the move, no
   skips, no warnings, no errors — pristine.

4. **Structure check**: confirmed no `__init__.py` was created in any of
   the 4 new subfolders, and all 16 `git mv` calls registered as pure
   renames before the import edits were layered on top (`RM` status in
   `git status --short` for the 3 files that were both moved and edited:
   `document_lifecycle_service.py`, `fact_extractor.py`, `finance_engine.py`;
   `R` for the other 13 moved-but-unedited files).

## Issues / concerns

- None blocking. The only judgment call was leaving the `.md`/`.txt`
  documentation references to old file paths untouched, since the
  dispatch scoped this to code (import/patch-target) references — see
  "Documentation files not touched" above.
- Pre-existing, unrelated noise in the worktree: many `__pycache__/*.pyc`
  files show as modified/untracked in `git status` (present before this
  task started, per the tracked-`.pyc` convention already in this repo).
  These were **not** staged or committed as part of this reorg — only the
  16 renamed `.py` files and the `.py` files with actual import-path edits
  were staged.
