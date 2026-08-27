# Android closed-beta release: design

**Date:** 2026-08-28
**Status:** Approved by user, ready for implementation planning
**Supersedes:** the "Phase 2 (deferred)" section of `docs/superpowers/specs/2026-08-02-production-hardening-phase-1-design.md` — this spec makes the concrete choices that were left open there.

## Goal

Make Residex (the DocuMind-focused Flutter app) installable and fully functional on real Android devices for a closed beta of ~10-30 invited landlords, without changing the OCR/embeddings privacy model (documents still never leave a machine you control).

## Context

Today the app only works against a backend running on the developer's own machine, reached at the hardcoded loopback address `http://10.0.2.2:8000` (Android emulator's alias for the host). Release builds sign with the debug keystore. Neither works for a phone that isn't the emulator on this PC. [[documind-production-hardening]] tracked this as "Phase 2 — deferred" pending a hosting decision; this spec makes that decision and the surrounding release mechanics concrete.

Phase 1 (already implemented, merge-ready on `feat/finance-tab-restructure`) closed the actual authorization hole: every route requires a verified Firebase ID token, and `landlord_id` was removed from the wire entirely. This spec builds on top of that — it does not reopen or redo Phase 1.

## Decisions made (in order)

1. **Audience:** closed beta, ~10-30 invited landlords (not public, not solo-only).
2. **Backend hosting:** Oracle Cloud **Always-Free ARM VM** (4 OCPU / 24GB), keeping OCR + embeddings + reranking local via Ollama/Tesseract — the original privacy promise in [[documind-local-hybrid-decision]] is preserved. Rejected: Cloud Run + hosted models (would send PII to a third-party API and cost a few $/mo; rejected on privacy grounds, not cost).
3. **Distribution:** Google Play Console **closed testing track** (not raw APK sideload) — feels like a normal app install for testers, and the delivery/update mechanism is Play's problem instead of the developer's.
4. **TLS/domain:** a free dynamic-DNS subdomain (DuckDNS or nip.io) pointed at the VM's public IP, rather than purchasing a domain — sufficient for Let's Encrypt to issue a real certificate.

## Architecture

```
Android phone (Play-installed APK)
   │  HTTPS
   ▼
Caddy (reverse proxy, auto Let's Encrypt TLS)  ◄── DNS: <name>.duckdns.org → VM public IP
   │  HTTP, localhost only
   ▼
uvicorn / FastAPI (systemd service, auto-restart)
   │
   ├─► Ollama (localhost:11434) — OCR text embedding, local fact-extraction models
   ├─► Tesseract (local binary) — OCR
   ├─► CrossEncoder reranker (in-process, torch/sentence-transformers)
   ├─► Firestore (Google Cloud, via serviceAccountKey.json / ADC)
   └─► Groq (hosted, chat generation only, behind the existing PII-scrub gate)
```

Everything below the "systemd service" line is **unchanged code** — it is the same backend that runs on the developer's machine today, relocated. The only new infrastructure is the VM itself, the reverse proxy, and the process supervisor.

## Components touched

### 1. Oracle VM provisioning + backend deployment
- Provision the Always-Free ARM shape (4 OCPU/24GB) — this is the shape size already validated as sufficient in prior notes for holding Ollama's models resident.
- Install Python 3.11, `uv`, Tesseract, Ollama; pull the three models already in use (`nomic-embed-text`, `qwen3:4b`, `qwen2.5vl:7b`).
- Deploy backend code (git clone or rsync — implementation plan decides which), install deps via `uv pip install -r requirements.txt`.
- Copy `.env` and `serviceAccountKey.json` to the VM out-of-band (scp/manual), same secrets-handling pattern as local dev — never committed.
- **Pin `requirements.txt`** before this deploy (currently fully unpinned — fine on a dev machine reinstalled ad hoc, risky on a server nobody is watching; a transitive dependency bump could silently break OCR/embeddings on a future redeploy). Pin to the versions currently resolved locally.

### 2. Process supervision
- Run the backend as a **systemd service** (`documind-backend.service` or similar): starts on boot, restarts on crash. Replaces the current "someone has a terminal open with `python main.py` running" model, which does not survive a VM reboot or an SSH session dropping.

### 3. TLS termination
- Register a DuckDNS (or nip.io) subdomain, point its A record at the VM's public IP.
- Install **Caddy** as a reverse proxy in front of uvicorn (proxying `https://<name>.duckdns.org` → `localhost:8000`). Caddy handles Let's Encrypt certificate issuance and renewal automatically — no manual certbot timer to maintain.
- Firewall: only ports 80/443 open to the public internet; uvicorn (8000), Ollama (11434) stay bound to localhost, unreachable from outside the VM.

### 4. Flutter app configuration
- `api_constants.dart`: `baseUrl` changes from `http://10.0.2.2:8000` to `https://<name>.duckdns.org`. The commented-out alternatives (localhost, LAN IP) stay as comments for future local-dev switching, or get cleaned up — implementation plan's call.
- `main.dart`: `FirebaseAppCheck.instance.activate(androidProvider: ...)` changes from `AndroidProvider.debug` to `AndroidProvider.playIntegrity`. This is necessary for correctness, not just hardening — the debug provider requires each tester's device to be manually registered in the Firebase console, which does not scale to a 10-30 person beta and would otherwise silently fail/no-op on every real tester's phone.
  - **Backend App Check verification is explicitly out of scope for this release.** It does not currently exist anywhere in the backend (confirmed: no reference to App Check tokens in `backend/`). Adding it is new server-side work (a new dependency/verification step on every request), not a config flip. Firebase Auth (Phase 1, already shipped) plus Play's invite-only closed-testing list are the real access gates for this beta; App Check enforcement is a good future hardening item, not a blocker now.

### 5. Android release signing
- Generate a real upload keystore (`keytool -genkey ...`) and a `key.properties` file (gitignored, never committed).
- Wire `key.properties` into `residex_app/android/app/build.gradle.kts`'s `release` block, replacing `signingConfig = signingConfigs.getByName("debug")`. Play Console will reject an upload signed with the debug keystore, so this is a hard blocker for distribution, not optional polish.

### 6. Play Console closed testing
- Create/use a Google Play developer account ($25 one-time).
- Host a privacy-policy page (a simple static page is sufficient for Play's requirement) and complete the Play **data-safety questionnaire** (what data the app collects/shares — Firebase Auth email, uploaded documents, etc.).
- Set up the **closed testing track**, add the ~10-30 landlords' emails as testers, distribute the opt-in link.
- Play's "12 testers opted in for 14 continuous days" gate only matters for *promoting* to a production listing — not relevant here, since closed testing itself is the whole goal of this release.

## Explicitly deferred (not in this release's scope)

Carried over from [[documind-production-hardening]]'s Phase 2 list, with an explicit call on each:

| Item | Decision | Why |
|---|---|---|
| Invite-only signup gate | **Deferred** | Phase 1 already closed the actual IDOR hole (open signup no longer grants lateral access to other landlords' data); Play's closed-testing list already restricts who can install the app at all. Redundant for this scope. |
| CORS tightening (`allow_origins=["*"]`) | **Deferred** | CORS is a browser-enforced protection; this app is Android-only with no browser client. Not a live exposure here. |
| Backend App Check verification | **Deferred** | New work, not existing config; Auth + Play's tester list are the real gates for a closed beta (see above). |
| Rate limiting | **Deferred** | No abuse vector identified yet for a ~10-30 person invited beta; revisit if usage patterns suggest otherwise. |
| Crash/error monitoring (e.g. Sentry) | **Deferred** | Nice-to-have for triaging beta feedback, not a blocker to getting the app installable. Candidate for a fast-follow. |

## Testing / verification plan

- **Backend on VM:** `py -3.11 -m pytest tests/ -q` passes on the VM the same as locally (sanity-checks the deploy didn't silently break anything via dependency pinning).
- **Connectivity:** `GET https://<name>.duckdns.org/health` returns `{"status":"healthy","database":"Firestore"}` from outside the VM's network (e.g. from a phone on cellular data, not the same LAN).
- **End-to-end on a real device:** install the signed release build via Play's internal/closed testing link (not `flutter run`) on a physical Android phone, sign in, upload a document, confirm OCR/fact-extraction/chat all complete successfully against the VM backend.
- **App Check:** confirm `.activate()` with `AndroidProvider.playIntegrity` succeeds (no error) on the real device — this was previously untestable off-emulator since the debug provider requires manual token registration.
- **Release signing:** confirm the built `.aab`/`.apk` is signed with the new upload keystore, not the debug one (`apksigner verify --print-certs`).

## Deliverable: release runbook

Per explicit user request, this work concludes with a written runbook documenting exactly how Residex is pushed to production / made downloadable for landlord testing — VM setup steps, deploy/update procedure, keystore handling, and the Play Console closed-testing flow — so the process is repeatable without re-deriving it. Location and exact form (single doc vs. split infra/release docs) is an implementation-plan decision.

## Open implementation questions (for the plan, not this spec)

- Git clone vs. rsync/scp for getting backend code onto the VM, and how future updates get deployed (manual redeploy vs. a simple script).
- Exact keystore generation command and where the keystore file itself is safely stored (it cannot be lost, or future app updates can never be signed to match the Play listing).
- Whether `.env`/`serviceAccountKey.json` transfer to the VM is manual (scp once) or scripted.
