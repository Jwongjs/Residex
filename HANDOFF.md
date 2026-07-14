# ResiDex — Session Handoff

**Date:** 2026-07-05 · **Branch:** `main` · **Last commit:** `19d4964`
**Purpose:** Full context for resuming work in a fresh session. Everything below is committed and verified unless marked otherwise.

---

## 1. What this project is now

**ResiDex** — a landlord-only rental-lifecycle app (rebranded from a dual-role "Residex" super app). Scope was deliberately cut to three features:

1. **Documind** — RAG document Q&A over a landlord's property documents (leases, warranties, bills)
2. **Property Management** — portfolio CRUD incl. unit/occupancy editing
3. **Auth** — landlord-only login/register (+ "Dev sign-in" bypass button)

- **Frontend:** Flutter 3.41.1 app in `residex_app/` (Riverpod, go_router, dash_chat_2 0.0.21, flutter_animate, google_fonts)
- **Backend:** FastAPI in `backend/` (port 8000), Firestore Vector Search (COSINE, 2048-dim cap), Gemini (`gemini-embedding-001` @ 768-dim via `output_dimensionality`, `gemini-2.5-flash` LLM)
- **RAG:** `HybridRetriever` — dense Firestore `find_nearest` (fetch_k=15) + CrossEncoder (`cross-encoder/ms-marco-MiniLM-L-6-v2`) rerank → top_k=4. BM25/RRF deferred (no corpus index).

This is a **portfolio piece for the user** (interview demo). Keep features minimal; polish matters.

---

## 2. Completed work (all committed)

### Backend plan — 10/10 tasks DONE
Plan: `docs/superpowers/plans/2026-07-02-landlord-scope-reduction-rag-improvement.md` · Ledger: `.superpowers/sdd/progress.md`
Commits `ae4c52b` → `8d17d87` (11 commits): tenant/lease code removed, HybridRetriever with **real rerank scores** (replaced fake `0.95 - i*0.1` citation scores), eval smoke harness, LangSmith config docs, `.env.example` fixed to real vars (`GOOGLE_API_KEY`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_APPLICATION_CREDENTIALS`, `DOCUMIND_EMBED_DIM`).
**Test baseline:** pytest 17 passed / 2 pre-existing failures (a `_build_service()` harness gap, not regressions).

### Frontend "Title Deed" redesign — Tasks 1–8 DONE
Spec: `docs/superpowers/specs/2026-07-03-residex-title-deed-redesign-design.md` · Plan: `docs/superpowers/plans/2026-07-03-residex-title-deed-redesign.md` · Ledger: `.superpowers/sdd/redesign-progress.md`
Commits `2d99cdf` → `19d4964` (8 commits):

| Commit | What |
|---|---|
| `2d99cdf` | Design tokens rewrite (AppColors/AppTextStyles/AppTheme/AppDimensions), 53 legacy color names kept as aliases |
| `3027798` | Deleted dead screens (Command/Finance/Community/REX subscreens), 3-tab shell (Dashboard · Documind · Portfolio), nav crash fix (`tabs.length ~/ 2` center) |
| `39c1f08` | Landlord-only auth (login/register rewrite, role toggle + social buttons removed) |
| `f328a0c` | Real Dashboard tab (live property data via `propertiesStreamProvider`) |
| `912493a` | Documind certified-extract citation card with relevance meters |
| `ddc03ee` | Portfolio verify, ResiDex rebrand (pubspec, manifest, Gemini prompts), dead-code sweep |
| `97608bf` | Fix round 1: Registry Green palette, 5 category colors, occupancy edit dialog, logout button, white-input-text bug fix |
| `19d4964` | Fix round 2: **Slate Teal** palette, Portfolio flat bg + white panels, opaque Documind input, Dashboard stat tiles/hero/greeting, light nav bar, **overflow fix** (extract card capped at 35% screen height, scrollable answer) |

**Analyze baseline:** `flutter analyze` → **0 errors, 260 issues** (info/warnings, pre-existing style lints).

---

## 3. Design system (current)

Fonts: **Fraunces** (display) · **IBM Plex Sans** (body) · **IBM Plex Mono** (utility).
Palette **Slate Teal** — token file `residex_app/lib/core/theme/app_colors.dart`. The primary accent token is named `registry` (conceptual name — **keep the name across palette swaps**, change only its value).

| Token | Value | | Token | Value |
|---|---|---|---|---|
| `paper` (bg) | `#F5F7F7` | | `sealRed` | `#A83A32` |
| `ink` (text) | `#0E1B1E` | | `deedGreen` (success) | `#2E7D5B` |
| `registry` (accent) | `#14595E` | | `warning` (ochre) | `#96690F` |
| `slate` | `#4F5E60` | | `card` | `#FFFFFF` |
| `hairline` | `#D2DAD9` | | `surfaceLight` | `#EBEFEF` |

Category colors: `catLease`=registry, `catWarranty #44519E`, `catInsurance #8C3A32`, `catUtility #96690F`, `catReceipt #6E4A8C`, `catOther`=slate.
Panel idiom: flat `paper` background, solid `card` panels with `hairline` border + `AppShadows.cardShadow`, 12px radius. No gradients, no translucent panel fills.

---

## 4. NEXT WORK — user feedback round 3 (NOT yet implemented)

Verbatim items from the user, queued and unstarted:

1. **Bring back the Residex old icon** and place it on the starting title (splash) screen & homepage. Note: Task 6 deleted `residex_logo.dart` + `app_gradients.dart` — recover from git history (`ddc03ee^`) or restyle to fit Slate Teal.
2. **Remove template questions** — the quick-question suggestion cards on the Documind screen.
3. **"Why is there another pop up that displays the same output as shown in the chatbot"** — the certified-extract card (`_buildCertifiedExtractCard` rendered above DashChat via `_lastAnswerForCard`) duplicates the answer already in chat history. User is questioning it; likely remove the card or make it citations-only (it was built as Task 5's signature element — discuss/decide before deleting).
4. **New background concept:** a top-rounded shape covering ~80% of the screen (bottom → up) containing the existing content and merging with the bottom nav bar; the uncovered top strip shows a nice accommodating image background.
5. **Edit/Add property dialog:** input labels truncate — can't read full titles (e.g. "purchase…", "Current V…"). File: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`.
6. **Add-property maybe shouldn't have a Monthly Rent input** — rent isn't fixed per property (varies per unit).
7. **When allowing modifications, emphasize unit and its respective monthly rent** — i.e. the edit flow should foreground per-unit occupancy + per-unit rent. Items 6+7 together imply moving rent from property-level to unit-level; check the `Property` entity fields before designing.

Items 6–7 (and possibly 4) may warrant a short brainstorm with the user before implementing — they change the data model / whole-app layout, not just styling.

---

## 5. Deferred (do NOT start without user go-ahead)

- **Finance tab** with real income/expense CRUD — user: "we are going to discuss the business acumen side of things after you finish developing."
- **BM25 + golden-dataset eval** for the retriever.
- Decision on dead files `profile_screen.dart` / `profile_editor_screen.dart` (unreferenced, still contain hex colors — flagged, not deleted).

---

## 6. How to run

`run_all.ps1` / `run_all.cmd` at repo root launches everything. Manual:

```powershell
# Backend (system Python311, NOT a venv)
cd backend
$env:PYTHONIOENCODING = "utf-8"   # emoji print() crashes cp1252 otherwise
python main.py                     # health: GET http://localhost:8000/health

# Frontend (Android emulator; app targets 10.0.2.2:8000)
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"  # ROOT, not \bin
flutter emulators --launch documind_light
cd residex_app; flutter run
```

- Use the **"Dev sign-in"** button on login to bypass Google Sign-In.
- Installing backend deps: **`uv pip install -r requirements.txt`** (plain pip fails with `resolution-too-deep`).
- `backend/.env` is permission-protected — don't read it; it and `serviceAccountKey.json` are present and correct.

---

## 7. Process conventions used this session

- **Subagent-driven development:** task briefs/reports/ledgers in `.superpowers/sdd/` (`redesign-progress.md` is the frontend ledger, `progress.md` the backend one). **Implementer-only mode** since the ~$50 cost checkpoint — no reviewer subagents; controller verifies diff + `flutter analyze` directly. User is cost-conscious; prefer inline work over spawning agents.
- **GateGuard fact-forcing hooks:** must present facts (importers via Grep/Glob, affected functions, verbatim user instruction) before Write/Edit/first-Bash each session; `rm -rf` blocked (delete per-file).
- **Recurring lesson (baked into every brief):** every task found at least one spot where the plan's assumptions didn't match the code — *read the real files before editing*.
- Commit style: single `feat:`/`chore:` commit per task, message pre-agreed in the brief.
- User feedback history: palette went Claude-like brass → Registry Green → **Slate Teal** (user's explicit pick from a 4-option comparison artifact). User twice stopped subagents mid-run; both times the working tree was assessed and finished inline.

---

## 8. Known baselines & failure modes

| Check | Expected |
|---|---|
| `flutter analyze` | 0 errors, 260 issues |
| `backend` pytest | 17 passed, 2 pre-existing failures (`_build_service()` harness gap) |
| Firestore embeddings | must stay ≤ 2048-dim → always use the service's `self.embeddings` property (768-capped), never a raw module-level embedder |
| dash_chat_2 0.0.21 | has **no** `messageBuilder` — custom cards render *above* the chat list, not inside it |
