# Android closed-beta release: design

**Date:** 2026-08-28
**Status:** Approved by user; revised 2026-08-28 after a feasibility check, ready for implementation planning
**Supersedes:** the "Phase 2 (deferred)" section of `docs/superpowers/specs/2026-08-02-production-hardening-phase-1-design.md` — this spec makes the concrete choices that were left open there.

> **Revision note (2026-08-28, post-feasibility-check).** The first draft of this spec specified a 4 OCPU/24GB Oracle VM running all models locally. A feasibility check found that shape no longer exists on Oracle's free tier and that CPU-only ARM cannot serve the 7B fact-extraction model at interactive latency. Sections 1, 4 and the new "Feasibility findings" section reflect the corrected plan. The overall architecture (VM + Caddy + systemd + Play closed testing) survived the check unchanged.

## Goal

Make Residex (the DocuMind-focused Flutter app) installable and fully functional on real Android devices for a closed beta of ~10-30 invited landlords, without changing the OCR/embeddings privacy model (documents still never leave a machine you control).

## Context

Today the app only works against a backend running on the developer's own machine, reached at the hardcoded loopback address `http://10.0.2.2:8000` (Android emulator's alias for the host). Release builds sign with the debug keystore. Neither works for a phone that isn't the emulator on this PC. [[documind-production-hardening]] tracked this as "Phase 2 — deferred" pending a hosting decision; this spec makes that decision and the surrounding release mechanics concrete.

Phase 1 (already implemented, merge-ready on `feat/finance-tab-restructure`) closed the actual authorization hole: every route requires a verified Firebase ID token, and `landlord_id` was removed from the wire entirely. This spec builds on top of that — it does not reopen or redo Phase 1.

## Decisions made (in order)

1. **Audience:** closed beta, ~10-30 invited landlords (not public, not solo-only).
2. **Backend hosting:** Oracle Cloud **Always-Free ARM VM**, at the current free shape of **2 OCPU / 12GB** (see Feasibility findings F1). Rejected: Cloud Run + fully hosted models (rejected on privacy grounds, not cost); Oracle Pay-As-You-Go upgrade (would restore 4 OCPU/24GB free but requires a card on file); a paid VPS (~€4-6/mo).
5. **Model placement (revised):** Tesseract OCR, `nomic-embed-text` embeddings, and the MiniLM CrossEncoder reranker stay **local on the VM**; `qwen2.5:7b` **fact extraction moves to Groq**, behind the existing `rag/pii_scrub.py` gate. This preserves the substantive privacy property from [[documind-local-hybrid-decision]] — raw document bytes and full page text never leave the VM — while relocating the one stage that CPU-only ARM cannot serve (F2). It also continues a direction the live `.env` already took (`CHAT_PROVIDER=groq`, `GROQ_FACT_CATEGORIES`).
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
   ├─► Ollama (localhost:11434) — nomic-embed-text embeddings only
   ├─► Tesseract (local binary) — OCR
   ├─► CrossEncoder reranker (in-process, torch/sentence-transformers)
   ├─► Firestore (Google Cloud, via serviceAccountKey.json / ADC)
   └─► Groq (hosted — chat generation AND fact extraction, behind the PII-scrub gate)
```

Everything below the "systemd service" line is the same backend that runs on the developer's machine today, relocated — with one deliberate configuration change: `FACT_PROVIDER` moves from `ollama` to `groq` (F2). That is an env-var change, not a code change; the provider seam already exists in `documind_service.py`. The only new infrastructure is the VM itself, the reverse proxy, and the process supervisor.

**Privacy boundary after this change.** Raw document bytes, page images, and full OCR text never leave the VM. What crosses to Groq is the same class of data that already crosses today for chat: PII-scrubbed text spans. `qwen2.5vl:7b` is not deployed (it is not on the default OCR path — `TesseractOcr` is), and `qwen2.5:7b` is not deployed at all.

## Components touched

### 1. Oracle VM provisioning + backend deployment
- Provision the Always-Free ARM shape at **2 OCPU / 12GB** (the current free ceiling — F1). Expect to contend with "Out of host capacity" (F3); a retry loop may be needed, and the implementation plan should carry a fallback if capacity never materialises.
- Install Python 3.11, `uv`, Tesseract **including the Malay traineddata package** (`tesseract-ocr-msa` — `OCR_LANG` defaults to `eng+msa`, so omitting it silently degrades Malay OCR; F6), and Ollama; pull **only `nomic-embed-text`**. `qwen3:4b` / `qwen2.5:7b` / `qwen2.5vl:7b` are **not** deployed (F2).
- Deploy backend code (git clone or rsync — implementation plan decides which), install deps via `uv pip install -r requirements.txt` (plain `pip` fails with `resolution-too-deep` on this unpinned file).
- Copy `.env` and `serviceAccountKey.json` to the VM out-of-band (scp/manual), same secrets-handling pattern as local dev — never committed. Set `FACT_PROVIDER=groq` in the VM's `.env`.
- **Pin `requirements.txt`** before this deploy (currently fully unpinned — fine on a dev machine reinstalled ad hoc, risky on a server nobody is watching). **Resolve the lockfile on the VM, not on the Windows dev machine** — `torch`, `grpcio` and `scikit-learn` resolve to different wheels on `aarch64`, so a Windows-generated pin set is not installable on the target (F5).
- Open ports 80/443 in **both** the OCI security list *and* the instance's own `iptables` — Oracle's Ubuntu images ship restrictive local firewall rules, and opening only the cloud-side security list is the most common way this deploy appears to hang (F8).

### 2. Process supervision
- Run the backend as a **systemd service** (`documind-backend.service` or similar): starts on boot, restarts on crash. Replaces the current "someone has a terminal open with `python main.py` running" model, which does not survive a VM reboot or an SSH session dropping.

### 3. TLS termination
- Register a **DuckDNS** subdomain, point its A record at the VM's public IP. **Not nip.io/sslip.io** — those are a single registered domain sharing one global Let's Encrypt rate-limit bucket, which is routinely exhausted by automated traffic; DuckDNS is on the Public Suffix List and therefore gets its own per-subdomain limit (F4).
- Install **Caddy** as a reverse proxy in front of uvicorn (proxying `https://<name>.duckdns.org` → `localhost:8000`). Caddy handles Let's Encrypt certificate issuance and renewal automatically — no manual certbot timer to maintain.
- Firewall: only ports 80/443 open to the public internet; uvicorn (8000), Ollama (11434) stay bound to localhost, unreachable from outside the VM.

### 4. Flutter app configuration
- `api_constants.dart`: `baseUrl` changes from `http://10.0.2.2:8000` to `https://<name>.duckdns.org`. The commented-out alternatives (localhost, LAN IP) stay as comments for future local-dev switching, or get cleaned up — implementation plan's call.
- `main.dart`: `FirebaseAppCheck.instance.activate(androidProvider: ...)` changes from `AndroidProvider.debug` to `AndroidProvider.playIntegrity`. This is necessary for correctness, not just hardening — the debug provider requires each tester's device to be manually registered in the Firebase console, which does not scale to a 10-30 person beta and would otherwise silently fail/no-op on every real tester's phone.
  - **Backend App Check verification is explicitly out of scope for this release.** It does not currently exist anywhere in the backend (confirmed: no reference to App Check tokens in `backend/`). Adding it is new server-side work (a new dependency/verification step on every request), not a config flip. Firebase Auth (Phase 1, already shipped) plus Play's invite-only closed-testing list are the real access gates for this beta; App Check enforcement is a good future hardening item, not a blocker now.

### 5. Android release signing
- Generate a real upload keystore (`keytool -genkey ...`) and a `key.properties` file (gitignored, never committed).
- Wire `key.properties` into `residex_app/android/app/build.gradle.kts`'s `release` block, replacing `signingConfig = signingConfigs.getByName("debug")`. Play Console will reject an upload signed with the debug keystore, so this is a hard blocker for distribution, not optional polish.
- **Register the Play App Signing certificate fingerprints in Firebase (F7).** Play App Signing re-signs the uploaded bundle with Google's own key, so the certificate on testers' installed app is *not* the upload keystore's. The app authenticates by certificate fingerprint in two places — `google_sign_in` (`pubspec.yaml:47`) and App Check Play Integrity — and **both fail silently for every tester** if only the upload key's fingerprint is registered. After the first bundle upload, copy the **Play App Signing SHA-1 and SHA-256** from Play Console → Setup → App signing into the Firebase Android app, and re-download `google-services.json`. This failure mode reproduces on no developer machine, so it must be handled by construction rather than found in testing.
- Bump `versionCode` (`pubspec.yaml` `version: 1.0.0+1` → `+2`, etc.) for every Play upload; Play rejects a re-used version code.
- Verify the built artifact is signed with the intended key before upload: `apksigner verify --print-certs`.

### 5b. Release-build shakeout (R8)
`isMinifyEnabled = true` and `isShrinkResources = true` are already set on the release build type, but since release has only ever been signed with the debug key, a real release build has almost certainly never been exercised end-to-end. Flutter + Firebase + R8 is a well-known source of defects that appear *only* in release (reflection-based deserialization stripped by the shrinker). `proguard-rules.pro` covers Flutter/camera/image-picker/permission-handler but has no Firebase-specific keep rules. Budget explicit time to smoke-test a release build on a physical device; treat "works in debug" as no evidence at all here (F9).

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

## Feasibility findings (2026-08-28)

Verified against the codebase and current external facts before implementation planning. Each is referenced above as F1-F9.

| # | Finding | Impact |
|---|---|---|
| **F1** | Oracle **halved** Always-Free ARM from 4 OCPU/24GB to **2 OCPU/12GB**, effective 2026-06-15, with auto-termination of oversized instances enforced **2026-08-18** (billing allowance 3,000→1,500 OCPU-hours/mo). No public announcement. PAYG accounts retain 4/24 free. | **Invalidated the original spec's shape.** Now targeting 2 OCPU/12GB. |
| **F2** | Dev machine has an **RTX 3050 + 16 threads**; the VM has **2 ARM cores and no GPU**. `OllamaChat` defaults to `qwen2.5:7b` with a **600 s timeout** (`rag/providers/ollama_chat.py:38,40`) — already slow *with* GPU assist. CPU-only ARM would put fact extraction at multi-minute-to-timeout per document. | **Fact extraction moved to Groq.** The "code just relocates" premise was true for correctness, false for performance. |
| **F3** | A1.Flex "Out of host capacity" is a chronic, long-running condition; idle Always-Free instances are also subject to reclamation. | Provisioning may take repeated attempts; needs a fallback plan. |
| **F4** | nip.io/sslip.io are a single registered domain sharing one global Let's Encrypt rate-limit bucket, routinely exhausted. DuckDNS is on the Public Suffix List. | DuckDNS specified; nip.io removed as an option. |
| **F5** | `requirements.txt` includes `sentence-transformers` (→ torch) and `scikit-learn`; these resolve to different wheels on `aarch64`. | Lockfile must be resolved on the VM, not on Windows. |
| **F6** | `OCR_LANG` defaults to `eng+msa` (`rag/documents/pdf_ocr.py:55`); Malay traineddata ships as a separate distro package. | `tesseract-ocr-msa` added to the install list. |
| **F7** | App uses `google_sign_in` (`pubspec.yaml:47`) and is switching to App Check Play Integrity — both authenticate by app certificate fingerprint, which **Play App Signing changes**. | Registering Play's SHA-1/SHA-256 in Firebase added as an explicit step. Silent, tester-only failure otherwise. |
| **F8** | Oracle Ubuntu images ship restrictive in-instance `iptables` independent of the OCI security list. | Both layers must be opened. |
| **F9** | `pytest` is **not** in `requirements.txt` (0 occurrences); R8 minification is enabled on a release build type that has only ever been signed with the debug key. | Dev-deps install needed for the on-VM test step; release build needs explicit shakeout. |
| **F10** | **Measured** (2026-08-29) the three stages that stay local, on 2 threads with the GPU excluded — see table below. All install and fit; **embeddings, not OCR, are the dominant ingestion cost** (~11× slower on CPU, and batching does not help). | Confirms 2 OCPU/12GB is workable. Sets the latency expectation to verify on the real VM. |

### F10 detail — measured local-stage cost

Install feasibility confirmed: `torch` 2.5.1 publishes a `manylinux2014_aarch64` wheel (91.9 MB); Ollama ships arm64 Linux builds; Tesseract is a distro package. No source builds required.

**Memory: ~3 GB of the 12 GB budget** — 893 MB measured for torch + CrossEncoder, plus ~1 GB Ollama/`nomic-embed-text`, ~400 MB FastAPI/langchain/Firestore, ~700 MB OS. The halved tier costs cores, not RAM.

| Stage | GPU / 16 threads | Forced CPU, 2 threads |
|---|---|---|
| Embeddings, per 1000-char chunk | 90 ms | **989 ms** (~11×) |
| Rerank, 15 pairs = one question (`fetch_k=15`) | — | **~1.5 s** |
| Tesseract OCR, per A4 page @150-200 dpi | — | **2.1-3.9 s** |

Projected upload latency on the VM, at `chunk_size=1000` (`ingestion_service.py:104`), so a 10-page document is ~25-38 chunks:
- **Digital PDF, 10 pages** (no OCR — all current test fixtures are this shape): **~30 s**
- **Scanned/photographed, 10 pages**: **~60-120 s**

Rerank is per-question, not per-upload, so chat latency stays ~1.5-2.5 s before the Groq call.

*Caveat:* measured on x86 laptop cores pinned to 2 threads, not Ampere Altra. Treat magnitudes as ±50%; the ratios and cost ranking should hold. **Verify on the real VM before inviting testers** (see the ingestion-latency step in the verification plan).

*Escape hatch, and its cost:* if ingestion proves too slow, the remaining lever is hosting embeddings too — but that is the lever that actually breaks the privacy property. Fact extraction sends PII-scrubbed spans; **embedding would send full chunk text**. Do not take that step casually.

Unchanged by the check: the reverse-proxy/systemd/Play-closed-testing architecture, the Phase 1 auth model, and the decision to defer invite-only signup, CORS tightening, backend App Check enforcement, rate limiting, and crash monitoring.

## Testing / verification plan

- **Backend on VM:** `py -3.11 -m pytest tests/ -q` passes on the VM the same as locally (sanity-checks the deploy didn't silently break anything via dependency pinning). Note `pytest` is not in `requirements.txt` — a dev-deps install is a prerequisite for this step (F9).
- **Ingestion latency:** time a real document upload end-to-end on the VM before inviting testers. This is the metric F2 is about; if it is unacceptable even with Groq fact extraction, the hosting decision needs revisiting rather than shipping a beta that feels broken.
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
- Fallback if Oracle A1 capacity never materialises (F3): retry script, a different region, PAYG upgrade, or a paid VPS.
- Whether `GROQ_FACT_CATEGORIES` should be widened now that all fact extraction routes to Groq, or left as-is.
