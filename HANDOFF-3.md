# ResiDex — Session Handoff 3

**Date:** 2026-07-15 · **Branch:** `main` · **This session's work is committed as `6e69601`** (feat: LLM search routing replaces DocuMind checkpoints; chat UX overhaul — 48 files, everything since `3a5b0f5`)
**Supersedes:** `HANDOFF-2.md` for current state. `backend/ARCHITECTURE.md` (written this session) is now the authoritative system overview — read it first.

---

## 1. TL;DR

This session redesigned DocuMind's interaction model from **"ask permission, then search"** to **"route silently, ask almost never."** The category and unit confirmation checkpoints are gone as gatekeepers; an LLM search router (tool-call style) now decides the search parameters — categories *and* unit — from the question plus the recent conversation, with a deterministic fallback so LLM failure can never block answering. The chat's unit dropdown was removed entirely. Plus a batch of UI/UX fixes (labeled occupancy switch, keyboard overlap, typing indicator, citation truncation, quick-reply chips).

**The backend must be restarted** to serve this behavior (Python doesn't hot-reload; the user kept seeing old checkpoints from a stale process during this session — that's the first thing to rule out when "it still does X").

## 2. What shipped (commit `6e69601`)

### Round 1 — six UI/UX improvements (user-requested)
| Item | Fix | Where |
|---|---|---|
| Unlabeled unit toggle | OCCUPIED/VACANT caption + tooltip above the switch | `units_screen.dart` |
| House-type property missing from portfolio stats | Evaluated: rent/occupancy live only on Units; zero-unit property contributes nothing (`0 < 0`). Guidance text added to empty units screen. **User still needs to add one "Whole House" unit to 1 Curve** (RM 1,850, occupied) | `units_screen.dart`; assessment in chat |
| Unit dropdown on Docs tab | Made chat-only, Docs list unfiltered — then the dropdown was removed altogether in Round 4 | `documind_screen.dart`, `documind_provider.dart` |
| Checkpoint answers required typing | Quick-reply chips under checkpoint bubbles (Confirm/Cancel/categories/unit labels); chips send their text as a normal message → same `mapDocuMindUserAction` path | `documind_screen.dart`, `documind_chat_logic.dart` (`buildDocuMindQuickReplies`) |
| Keyboard merged with "Ask Me Anything" empty state | v1 (`MediaQuery.viewInsets`) FAILED — a resizing Scaffold consumes viewInsets before its body reads them. v2: own `FocusNode` passed to dash_chat's `InputOptions.focusNode`; empty state hides on focus | `documind_screen.dart` |
| Citation line truncated the page number | Filename is the only elastic part; ` · p.X` pinned; unit badge capped at 110px | `documind_screen.dart` `_buildCitationLine` |
| Full-screen "thinking" spinner | Replaced with dash_chat_2 `typingUsers` 3-dot bubble; sends ignored while in flight | `documind_screen.dart` |

### Round 2 — checkpoint redesign (backend)
- **Category confirmation removed**: `_decide_action_node` always retrieves for fresh questions (`graph_orchestrator.py`). Predicted categories apply silently when router confidence ≥ 0.45, else search all. Confirm/cancel/override paths kept for legacy resumes only.
- **Post-retrieval unit-span checkpoint deleted** (it fired whenever top-k chunks happened to span 2 units — the cause of every annoying scenario). Replaced by question-side routing + prompt rule 5 (never blend units; per-unit breakdowns; totals show per-unit + combined).
- **Deterministic `resolve_unit_mention`** (`documind_service.py`, module-level, pure): scoped / aggregate ("all units", "per unit"…) / multi (several labels named) / unknown (honest "no Unit D — your units are…" answer, no retrieval) / ambiguous (the ONE surviving checkpoint: a reference matching several units, e.g. "unit A" vs "Unit A-1"/"Unit A-2").

### Round 3 — LLM tool-style routing (user's idea)
- `category_predictor.py` rewritten into a **unified search router**: one Gemini call returns categories + `unit=<id|all>` + `unknown_unit`, parsed from the `key=value;` line format. Output validated (only real unit ids scope; label echo accepted; hallucinated id → `unit_decided=False`).
- `unit_decided=False` (failure/garbage) → service falls back to `resolve_unit_mention`. **LLM routing can never make things worse — that's the built-in "revert."**
- Graph state carries `available_units`, `routed_unit_id`, `unknown_unit_mention`, `unit_routing_decided`. Service priority: payload `unit_id` (API-only now) → LLM decision → deterministic matcher.
- Still 3 LLM calls per document question (conversation router → search router → answer). Unit routing added zero calls.
- LangGraph purpose intact: the router upgraded an existing node; no free-running `bind_tools` loop (deliberately avoided — latency/cost/failure modes).

### Round 4 — dropdown removed + conversational continuity
- Unit dropdown, `selectedDocumindUnitProvider`, property-switch reset, and checkpoint→dropdown sync all deleted from Flutter. Ask requests no longer send `unit_id`.
- Router prompt now includes the **last 3 conversation turns** + rule: follow-ups naming no unit keep the conversation's unit. So "Unit A's rent?" → "and when does it end?" stays on Unit A.
- Unit badges on citations are the sole (sufficient) visible scope signal.

### Docs
- `backend/ARCHITECTURE.md` — full system overview (written this session, updated for all the above). NOTE: git tracks it as `backend/architecture.md` (old deleted file, case-insensitive Windows FS) — harmless, but stage it by the lowercase name.
- `demo_documents/SETUP_AND_TEST_GUIDE.md` — **rewritten for the checkpoint-free model**: scenarios are phrasing-driven (U1 explicit unit, U2 continuity follow-up, U3 aggregate + RM 7,200 total, U4 per-unit attribution, U6 unknown-unit correction, U13 vacant unit, G2 UX spot-checks), with a restart-the-backend warning and the optional "Whole House" unit for Ipoh's portfolio stats.
- The commit also picks up the previously-untracked demo pack (12 PDFs + sources + generator), `backend/scripts/cleanup_orphan_chunks.py`, older docs/specs/plans, and HANDOFF 1+2.

## 3. Verification

- Backend: **74 passed** — run with `py -3.11 -m pytest tests/ -q` from `backend/` (the repo `.venv` lacks `pytest` and `sentence_transformers`; system Python 3.11 has both).
- Flutter: **29 passed** (`flutter test test/features`), `flutter analyze` 0 errors. Two PRE-EXISTING warnings (not this session's): unused import in `landlord_portfolio_provider.dart:1`, unused `_lastQuestion` in `documind_screen.dart`.
- New test coverage: `resolve_unit_mention` suite, router parsing (unit id/label echo/unknown/hallucination/failure), recent-turns-reach-prompt, LLM-routed scoping + unknown-unit flows, quick-reply round-trip through `mapDocuMindUserAction`.

## 4. User action queue (in order)

1. **Restart the backend** — required for every routing change above.
2. Run `backend/scripts/cleanup_orphan_chunks.py` (dry-run first, then `--apply`) — purges orphan chunks left by the pre-fix storage-bucket 404 uploads. Mutates Firestore; needs user creds/consent. Never run it unprompted.
3. Add one unit to 1 Curve Ipoh ("Whole House", RM 1,850, toggle Occupied) so portfolio stats include the house.
4. Re-run the demo scenarios — `demo_documents/SETUP_AND_TEST_GUIDE.md` is **up to date** with the new behavior (phrasing-driven scenarios, no dropdown, no checkpoints). Work through its pass checklist (U1–U13, L1–L2, G1–G2).

## 5. Open items / watch list

- **Watch: router judgment calls.** The deterministic fallback only covers LLM *failures*, not bad judgment (e.g. a follow-up that jumps scope unexpectedly). If that shows up in testing, the fix is prompt tuning in `category_predictor.py`, or reverting Round 4 (the dropdown is a small isolated widget to restore).
- Optional ingest hardening (upload PDF to Storage *before* chunk writes, eliminating the orphan-chunk class) — offered earlier, never answered.
- Fact-extraction plan `docs/superpowers/plans/2026-07-08-documind-fact-extraction.md` — still unexecuted, user hasn't asked.
- Backend runs from earlier context: launch details in memory file `documind-run-setup.md` (`~/.claude/projects/.../memory/`).
- Left deliberately uncommitted: `__pycache__` churn and `.superpowers/` tool state.

## 6. Gotchas learned this session (don't relearn)

- A resizing `Scaffold` consumes `MediaQuery.viewInsets` — keyboard detection inside its body always reads 0. Use the input's `FocusNode`.
- dash_chat_2 0.0.21 supports `typingUsers` (animated dots) and `InputOptions.focusNode` — no fork needed.
- The backend serves stale code until restarted; "the fix didn't work" usually means the old process is still up.
- GateGuard hook blocks the first Write/Edit/Bash per file per turn demanding facts; present the 4 facts, then retry the identical call (subsequent calls to the same file pass).
- Firestore unit filtering must be a Python post-filter: pre-unit docs have no `unit_id` field, and a where-clause can't match a missing field.
