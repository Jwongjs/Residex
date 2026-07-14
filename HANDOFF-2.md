# ResiDex — Session Handoff 2

**Date:** 2026-07-05 · **Branch:** `main` · **Last commit:** `a38dcb1`
**Supersedes:** `HANDOFF.md` (still useful for sections 1, 3, 6 — project overview, design system, how-to-run — which haven't changed). This file covers everything since `19d4964`.

---

## 1. What happened this session (11 commits, `19d4964` → `a38dcb1`)

### Round-3 quick wins — all shipped
Spec: `docs/superpowers/specs/2026-07-05-round-3-quick-wins-design.md`

Resolved every item queued in the old HANDOFF.md's "NEXT WORK" section:

| Commit | Item(s) resolved |
|---|---|
| `268aed4` | #1 Restored `ResidexLogo` (recovered from `ddc03ee^`, re-themed to Slate Teal) on splash + homepage. #2 Removed the Documind template-question suggestion cards. #5 Restyled the add/edit-property dialog. |
| `ee179d9` | #5 (continued) Forced floating labels, dropped icons on tight financial fields so labels stop truncating. |
| `691237f` | #5 (continued) Gave City its own row, split State/Zip into a 2-column row. |
| `65e06c2` | **#3 — the "duplicate popup" question.** Resolved by removing the certified-extract card entirely and attaching the citation/relevance-meter widget directly to the chat bubble via `dash_chat_2`'s `MessageOptions.bottom` + `ChatMessage.customProperties`. **Correction to the old HANDOFF.md:** its "Known Baselines" table claimed dash_chat_2 0.0.21 has no `messageBuilder`/per-message custom widget support — that was wrong. It does, via `MessageOptions.bottom`. Don't re-introduce a floating overlay card if this comes up again. |

Items #6/#7 (rent belongs at unit-level, not property-level) and #4 (new background shape concept) from the old handoff were **not addressed this session** — still open, still need a data-model discussion before implementing (property entity currently has a property-level `monthlyRent` field; moving it to unit-level is a schema change, not a quick win).

### Citation card correctness fixes (post round-3)
Design doc for the relevance meter itself (shipped earlier, before this session): `docs/superpowers/specs/2026-07-05-documind-citation-meter-design.md` — the fixes below are follow-on bugs found after that shipped.

| Commit | Fix |
|---|---|
| `bd4b2a2` | Normalized relevance score to a real 0–1 range (was showing meaningless values in some cases), dropped a duplicate citation the LLM was echoing into its own answer text, switched the answer bubble to render markdown (`flutter_markdown`) instead of raw text. |
| `049ff8a` | Swapped the Chat/Docs toggle order in the Documind header (user preference — Chat first). |
| `6ee70fb` | Three more citation-card bugs, found by re-testing after the above: **(a)** the same source could appear twice in one answer with two different relevance bars — multiple chunks from the same page each get an independent cross-encoder score; now deduped by `(filename, page)`, keeping the highest-scoring chunk per page (context sent to the LLM is untouched, only the *display* is deduped). **(b)** pages showed 0-indexed (`p.0`) because PyPDF's page metadata is 0-based and was never converted for display — now `+1`'d at the point citations/context are built. **(c)** a citation appearing in the card implies non-zero relevance, so its bar now has a minimum visible fill (8%, `_minRelevanceBarFill` in `documind_screen.dart`) purely for rendering — the true score is untouched, still what's sorted/compared. Also: the backend process had been running since before `bd4b2a2` and was serving a stale prompt (Python doesn't hot-reload) — restarted it. |

**Verified:** backend `pytest tests/` → 17 passed / 2 pre-existing failures (same `_build_service()` harness gap as before, confirmed unrelated to these changes by running the identical suite against the pre-fix commit). `flutter analyze` → 0 errors, 260 info-level issues (unchanged baseline).

### New feature, brainstormed + planned (not yet implemented)
"Tap a citation to view the original source document" — user-requested, walked through the full brainstorming → spec → plan pipeline this session:

- **Spec:** `docs/superpowers/specs/2026-07-05-citation-source-viewer-design.md`
- **Plan:** `docs/superpowers/plans/2026-07-05-citation-source-viewer.md` (5 tasks, TDD steps, exact file paths/line numbers)

**Design in one paragraph:** original PDFs aren't persisted anywhere today — only extracted text + embeddings survive ingestion. This feature uploads the original PDF to Firebase Storage at ingest time (`firebase-admin`, already an installed-but-unused dependency), records the storage path on the `documind_docs` Firestore doc, adds a scoped `GET .../documents/{doc_id}/view-url` endpoint that issues 10-minute signed URLs, and on the Flutter side adds a data/repository/usecase chain + an on-device file cache (keyed by `doc_id`, so repeat views never re-download) + a `DocumentViewerScreen` using `syncfusion_flutter_pdfviewer` that jumps to the cited page on open.

**Key decisions made during brainstorming (don't re-litigate without new information):**
- **PDF-only, no DOCX.** The upload dialog's file picker accepts `.docx`, but the backend only ever wired up `PyPDFLoader` — DOCX text extraction was never actually implemented. This is a pre-existing gap, flagged but explicitly out of scope for the viewer feature.
- **No backfill.** Documents uploaded before this feature ships have no Storage copy; their citations just won't be tap-viewable (or will show the same "not available" message as a deleted document). This is a demo/portfolio app — re-uploading test docs is trivial, so backfill tooling wasn't worth building.
- **Cloud storage, not local-only.** A fully on-device store was explicitly rejected — if the uploading device is lost/reset/replaced, every citation older than that becomes permanently unopenable with no recovery path. User confirmed durability across devices matters more than avoiding a small Storage bill. Cost is controlled instead via an on-device cache (pay for egress once per document, not once per view).
- **`syncfusion_flutter_pdfviewer`** chosen over `flutter_pdfview` for its built-in page-jump API; Syncfusion's Community License free tier should cover a solo portfolio project but wasn't independently re-verified against current Syncfusion licensing terms.

**Not started:** none of the 5 plan tasks have been implemented yet. Next session should either dispatch subagent-driven execution or inline-execute the plan (both options were offered; awaiting user choice).

---

## 2. Corrections to information in the old HANDOFF.md

- **§8 "Known baselines" table, dash_chat_2 row:** was wrong. It does support per-message custom widgets (`MessageOptions.bottom` + `ChatMessage.customProperties`); the certified-extract-card architecture was replaced because of this, not despite it.
- **Backend pytest baseline row:** confirmed still accurate — 17 passed / 2 pre-existing failures, same root cause (`_build_service()` test harness doesn't wire `_hybrid_retriever`).
- **`flutter analyze` baseline row:** confirmed still accurate — 0 errors, 260 issues.

---

## 3. Known gaps / things to watch

- **DOCX upload vs. ingestion mismatch** (see above) — the upload dialog offers `.docx` as a file type but nothing on the backend processes it. Not fixed, not currently blocking anything, but a user who uploads a `.docx` today gets silently mis-served (worth checking what actually happens — likely a `PyPDFLoader` failure on a non-PDF file — if this surfaces as a bug report).
- **Property-level vs. unit-level rent** — old HANDOFF.md items #6/#7, still unresolved, still needs a brainstorm before touching (schema change).
- **New background/layout concept** — old HANDOFF.md item #4, still unresolved, still just a verbal description from the user, needs clarification before spec'ing.
- **Disk space:** mid-session the C: drive hit 0 bytes free, which caused a pytest/backend-startup failure that looked at first like a code regression but wasn't. User freed space manually; `residex_app/build/` (~4.3GB, fully regenerable) was identified as a deletion candidate but the user hasn't approved removing it. If disk space becomes tight again, that's the first place to look.
- **Untracked `.superpowers/` files:** several SDD brief/report/ledger files from this session's subagent-driven work are untracked in git (`.superpowers/sdd/task-*.md`, `.superpowers/brainstorm/`, etc.) — process artifacts, not source, but flagging so they're not mistaken for missing work if `git status` looks noisy.

---

## 4. How to run

Unchanged from `HANDOFF.md` §6 — see that file. Quick reference:

```powershell
# Backend
cd backend
$env:PYTHONIOENCODING = "utf-8"
python main.py   # health: GET http://localhost:8000/health

# Frontend
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
flutter emulators --launch documind_light
cd residex_app; flutter run
```

---

## 5. Suggested next steps

1. Decide execution mode for the citation-source-viewer plan (subagent-driven vs. inline) and implement it, OR
2. Pick up the still-open items from the old handoff: rent data-model discussion (#6/#7) or the background/layout concept (#4) — both need a brainstorm session before any code.
