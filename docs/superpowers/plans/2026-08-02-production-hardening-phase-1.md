# Production Hardening Phase 1: Close the Trust Boundary — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make landlord identity un-forgeable by deriving it from a verified Firebase ID token instead of a client-supplied parameter, and close the supporting Firestore/Storage rule gaps.

**Architecture:** A router-level FastAPI dependency verifies the `Authorization: Bearer <idToken>` header on every `/api/rex` route (fail-closed). Routes derive `landlord_id` from the token's `uid`. `landlord_id` is then removed from the wire entirely (request models, Form, Query), so the vulnerable input no longer exists. The Flutter app attaches the token at a single `http.BaseClient` chokepoint and stops sending `landlordId`. Firestore/Storage rules are tightened to owner-scoped / backend-only.

**Tech Stack:** FastAPI, `firebase_admin` (Python Admin SDK, already a dependency), `fastapi.testclient`, `unittest`/`pytest`, Flutter (`http`, `firebase_auth`), Firebase Security Rules.

## Global Constraints

- **All 468 existing backend tests must stay green.** Run `cd backend && python -m pytest` after every backend task.
- **Flutter must stay analyzer-clean.** Run `cd residex_app && flutter analyze` after every Flutter task; there is one pre-existing `widget_test.dart` boilerplate failure that is expected and unrelated.
- **No dev-auth-bypass flag.** An env flag that disables authentication is explicitly forbidden — it is the mechanism by which this vulnerability returns.
- **Auth failures carry a machine-readable `code`.** Every 401/403 response body is `{"detail": {"code": <code>, "message": <str>}}` with `code` in `{token_missing, token_invalid, token_expired, forbidden}`. The app branches on `code`, never on prose.
- **`check_revoked=False`** on `verify_id_token` (avoids a network round-trip per request; tokens expire hourly).
- **Firebase init stays credential-argument-free** (Application Default Credentials), preserving the Phase-2 path to dropping `serviceAccountKey.json`.
- **Service-layer ownership checks are preserved**, not deleted — they become defense-in-depth.
- Python: use `str | None` union syntax (matches the existing codebase, which is on 3.11).

---

### Task 1: Extract idempotent Firebase initialization

**Files:**
- Create: `backend/firebase_app.py`
- Modify: `backend/rag/documind_service.py:54-61` (the `if not firebase_admin._apps:` block)
- Test: `backend/tests/test_firebase_app.py`

**Interfaces:**
- Produces: `firebase_app.ensure_initialized() -> None` — idempotent; initializes the default Firebase app with the storage bucket option if not already initialized. Safe to call multiple times.

**Why:** The Firebase app is currently initialized as an import-time side effect inside `documind_service.py`. The auth dependency (Task 2) must be able to guarantee initialization without importing the whole service. Extracting it makes the dependency explicit rather than accidental.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_firebase_app.py
import firebase_admin
import firebase_app


def test_ensure_initialized_is_idempotent(monkeypatch):
    calls = []

    def fake_initialize_app(*args, **kwargs):
        calls.append(kwargs)
        return object()

    monkeypatch.setattr(firebase_admin, "_apps", {}, raising=False)
    monkeypatch.setattr(firebase_admin, "initialize_app", fake_initialize_app)

    firebase_app.ensure_initialized()
    # Simulate the app now being registered.
    monkeypatch.setattr(firebase_admin, "_apps", {"[DEFAULT]": object()}, raising=False)
    firebase_app.ensure_initialized()

    assert len(calls) == 1, "initialize_app must run only when no app exists"
    assert "storageBucket" in calls[0]["options"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_firebase_app.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'firebase_app'`

- [ ] **Step 3: Write minimal implementation**

```python
# backend/firebase_app.py
"""Idempotent Firebase Admin SDK initialization.

Extracted from rag/documind_service.py so the auth dependency can guarantee
initialization without importing the whole service. No credential argument is
passed, so Application Default Credentials are used — this is what keeps the
Phase-2 move off serviceAccountKey.json a configuration change.
"""
import os

import firebase_admin


def ensure_initialized() -> None:
    """Initialize the default Firebase app once. Safe to call repeatedly."""
    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={
            'storageBucket': os.getenv(
                'FIREBASE_STORAGE_BUCKET',
                f"{os.getenv('GOOGLE_CLOUD_PROJECT')}.firebasestorage.app",
            ),
        })
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_firebase_app.py -v`
Expected: PASS

- [ ] **Step 5: Replace the inline init in documind_service.py**

In `backend/rag/documind_service.py`, replace the block at lines 54-61:

```python
if not firebase_admin._apps:
    firebase_admin.initialize_app(options={
        'storageBucket': os.getenv(
            'FIREBASE_STORAGE_BUCKET',
            f"{os.getenv('GOOGLE_CLOUD_PROJECT')}.firebasestorage.app",
        ),
    })
```

with:

```python
from firebase_app import ensure_initialized as _ensure_firebase_initialized
_ensure_firebase_initialized()
```

Keep the existing `import firebase_admin` line if other code in the file references it; otherwise leave it (harmless). Do not move the `db = firestore.Client()` line.

- [ ] **Step 6: Run the full suite to confirm no regression**

Run: `cd backend && python -m pytest`
Expected: 468 passed (plus the 1 new test) — the extraction is behavior-preserving.

- [ ] **Step 7: Commit**

```bash
git add backend/firebase_app.py backend/tests/test_firebase_app.py backend/rag/documind_service.py
git commit -m "refactor: extract idempotent Firebase init into firebase_app.py"
```

---

### Task 2: Auth dependencies + token verification tests

**Files:**
- Create: `backend/api/auth.py`
- Test: `backend/tests/test_auth.py`

**Interfaces:**
- Consumes: `firebase_app.ensure_initialized` (Task 1); `firebase_admin.auth.verify_id_token`.
- Produces:
  - `verify_firebase_token(authorization: str | None = Header(None)) -> dict` — returns decoded claims, or raises `HTTPException` (401) with a `{"code","message"}` detail.
  - `current_landlord_id(claims: dict = Depends(verify_firebase_token)) -> str` — returns `claims["uid"]`.

**Why:** These two dependencies are the trust boundary. `verify_firebase_token` runs once per request (FastAPI caches it); `current_landlord_id` is the identity every route uses.

- [ ] **Step 1: Write the failing tests**

```python
# backend/tests/test_auth.py
import unittest
from unittest.mock import patch

import firebase_admin
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from api.auth import verify_firebase_token, current_landlord_id


def _make_probe_app() -> FastAPI:
    app = FastAPI()

    @app.get("/probe")
    async def probe(landlord_id: str = Depends(current_landlord_id)):
        return {"landlord_id": landlord_id}

    return app


class TestAuthDependency(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(_make_probe_app())

    def test_missing_header_is_401_token_missing(self):
        r = self.client.get("/probe")
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_missing")

    def test_malformed_header_is_401_token_invalid(self):
        r = self.client.get("/probe", headers={"Authorization": "NotBearer xyz"})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_invalid")

    def test_expired_token_is_401_token_expired(self):
        with patch("api.auth.firebase_auth.verify_id_token",
                   side_effect=firebase_admin.auth.ExpiredIdTokenError("expired", cause=None)):
            r = self.client.get("/probe", headers={"Authorization": "Bearer tok"})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_expired")

    def test_bad_signature_is_401_token_invalid(self):
        with patch("api.auth.firebase_auth.verify_id_token",
                   side_effect=firebase_admin.auth.InvalidIdTokenError("bad sig")):
            r = self.client.get("/probe", headers={"Authorization": "Bearer tok"})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json()["detail"]["code"], "token_invalid")

    def test_valid_token_returns_uid(self):
        with patch("api.auth.firebase_auth.verify_id_token",
                   return_value={"uid": "landlord_123"}):
            r = self.client.get("/probe", headers={"Authorization": "Bearer tok"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["landlord_id"], "landlord_123")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_auth.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'api.auth'`

- [ ] **Step 3: Write minimal implementation**

```python
# backend/api/auth.py
"""Firebase ID token verification for the /api/rex router.

The single trust boundary: landlord identity comes from a verified token's
uid, never from a client-supplied parameter. Every 401/403 carries a
machine-readable `code` so the app can distinguish "refresh and retry"
(token_expired) from "sign out" (everything else).
"""
from fastapi import Depends, Header, HTTPException
from firebase_admin import auth as firebase_auth

from firebase_app import ensure_initialized


def _unauthorized(code: str, message: str) -> HTTPException:
    return HTTPException(status_code=401, detail={"code": code, "message": message})


async def verify_firebase_token(authorization: str | None = Header(None)) -> dict:
    """Verify the bearer token and return its decoded claims.

    Raises 401 with a machine-readable code for every failure mode.
    """
    ensure_initialized()

    if not authorization:
        raise _unauthorized("token_missing", "Authorization header is missing")

    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0] != "Bearer" or not parts[1].strip():
        raise _unauthorized("token_invalid", "Authorization header must be 'Bearer <token>'")

    token = parts[1].strip()
    try:
        # check_revoked=False by design (see plan Global Constraints).
        return firebase_auth.verify_id_token(token)
    except firebase_auth.ExpiredIdTokenError:
        raise _unauthorized("token_expired", "ID token has expired")
    except (firebase_auth.InvalidIdTokenError, ValueError):
        raise _unauthorized("token_invalid", "ID token is invalid")


async def current_landlord_id(claims: dict = Depends(verify_firebase_token)) -> str:
    """The authenticated landlord's uid, derived from the verified token."""
    uid = claims.get("uid")
    if not uid:
        raise _unauthorized("token_invalid", "Token has no uid")
    return uid
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_auth.py -v`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add backend/api/auth.py backend/tests/test_auth.py
git commit -m "feat: add Firebase ID token verification dependencies"
```

---

### Task 3: Fail-closed router + routes derive identity from the token

**Files:**
- Modify: `backend/api/rex_routes.py` (router definition + all 22 routes)
- Modify: `backend/tests/test_rex_routes_documind_ask_api.py`, `backend/tests/test_rex_routes_documind_docs_api.py`, `backend/tests/test_rex_routes_finance_api.py` (add auth override fixture)

**Interfaces:**
- Consumes: `verify_firebase_token`, `current_landlord_id` (Task 2).
- Produces: every `/api/rex` route requires a valid token; each route uses the token's uid as `landlord_id`. The wire `landlord_id` (still present on models/params after this task) is no longer read.

**Why:** This is where the IDOR closes. After this task an unauthenticated request is 401, and an authenticated request can only act as its own uid — even though the `landlord_id` field still exists on the request models (removed in Task 4).

**Note on the ask route:** `documind_ask` passes the whole `AskRequest` to `ask_documind`, which reads `payload.landlord_id` internally. Here we overwrite `payload.landlord_id` with the token uid before delegating, so the orchestrator stays unchanged this task. Task 4 removes the field and threads the id as a parameter.

- [ ] **Step 1: Write the failing test (unauthenticated is rejected)**

Add to `backend/tests/test_rex_routes_documind_docs_api.py` a test that does NOT install the override:

```python
def test_list_documents_without_token_is_401(self):
    # A fresh client with no auth override installed.
    from main import app
    from fastapi.testclient import TestClient
    bare = TestClient(app)
    r = bare.get("/api/rex/documind/documents?property_id=p1")
    assert r.status_code == 401
    assert r.json()["detail"]["code"] == "token_missing"
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_docs_api.py::<ClassName>::test_list_documents_without_token_is_401 -v`
Expected: FAIL — currently returns 200/422, not 401 (no auth on the router yet).

- [ ] **Step 3: Add the router-level dependency**

In `backend/api/rex_routes.py`, change the imports and router definition:

```python
from fastapi import APIRouter, UploadFile, File, Form, Query, HTTPException, Depends
from api.auth import verify_firebase_token, current_landlord_id
```

```python
router = APIRouter(
    prefix="/api/rex",
    tags=["rex-ai"],
    dependencies=[Depends(verify_firebase_token)],
)
```

- [ ] **Step 4: Switch every route to derive landlord_id from the token**

For each route, replace the client-supplied `landlord_id` with the dependency and stop reading the wire value. Apply these edits (identity source only — leave every other parameter and all business logic untouched):

**Form routes** (`documind_upload`, `documind_upload_stream`) — remove `landlord_id: str = Form(...)`, add `landlord_id: str = Depends(current_landlord_id)` as a parameter, keep passing `landlord_id=landlord_id` into `ingest_document`.

**Query routes** (`list_documents`, `finance_summary`, `clear_payment_exception`, `clear_document_unavailable`, `clear_rent_recovery`, `delete_manual_loan_entry`, `list_manual_loan_entries`, `clear_unit_loan_exemption`, `delete_document`, `delete_property_documents`, `get_document_view_url`) — remove `landlord_id: str = Query(...)`, add `landlord_id: str = Depends(current_landlord_id)`, keep the downstream call unchanged.

**Body routes** (`update_document_facts`, `rename_document`, `set_payment_exception`, `set_document_unavailable`, `record_rent_recovery`, `record_manual_loan_entry`, `set_unit_loan_exemption`, `unassign_unit_documents`) — add `landlord_id: str = Depends(current_landlord_id)` and change every `payload.landlord_id` in that route to `landlord_id`.

**Ask route** — becomes:

```python
@router.post("/documind/ask", response_model=AskResponse)
async def documind_ask(payload: AskRequest, landlord_id: str = Depends(current_landlord_id)):
    """..."""  # keep existing docstring
    payload.landlord_id = landlord_id  # token identity wins over any client value
    return await documind_service.ask_documind(payload)
```

- [ ] **Step 5: Add the auth override fixture to the three route-test files**

In each of `test_rex_routes_documind_ask_api.py`, `test_rex_routes_documind_docs_api.py`, `test_rex_routes_finance_api.py`, in the `setUp` (after `from main import app` / `TestClient(app)`):

```python
from api.auth import verify_firebase_token
app.dependency_overrides[verify_firebase_token] = lambda: {"uid": "landlord_123"}
```

and in `tearDown` (create it if absent):

```python
app.dependency_overrides.clear()
```

If a test previously sent `landlord_id` in the body/query/form and asserted on it, leave the send in place for now (it is ignored, harmless) — Task 4 removes it. The override makes `current_landlord_id` return `landlord_123`, so any test whose fixtures assume that landlord id keeps passing.

- [ ] **Step 6: Run the unauthenticated test and the three route suites**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_docs_api.py tests/test_rex_routes_documind_ask_api.py tests/test_rex_routes_finance_api.py -v`
Expected: all PASS, including the new 401 test.

- [ ] **Step 7: Run the full suite**

Run: `cd backend && python -m pytest`
Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add backend/api/rex_routes.py backend/tests/test_rex_routes_documind_ask_api.py backend/tests/test_rex_routes_documind_docs_api.py backend/tests/test_rex_routes_finance_api.py
git commit -m "feat: authenticate all /api/rex routes, derive landlord_id from token"
```

---

### Task 4: Remove landlord_id from the wire + OpenAPI regression guard

**Files:**
- Modify: `backend/models/documind_models.py` (9 request models)
- Modify: `backend/api/rex_routes.py` (drop any now-dead references)
- Modify: `backend/rag/documind_service.py` (`ask_documind` signature)
- Modify: `backend/rag/ask/ask_orchestrator.py` (`ask` signature + 4 `payload.landlord_id` sites)
- Modify: `backend/tests/test_rex_routes_*` (remove `landlord_id` from request payloads sent by tests)
- Test: add the regression guard to `backend/tests/test_auth.py`

**Interfaces:**
- Consumes: everything from Task 3.
- Produces: `ask_documind(self, payload: AskRequest, landlord_id: str) -> AskResponse`; `AskOrchestrator.ask(self, payload: AskRequest, landlord_id: str) -> AskResponse`. No request model or route parameter named `landlord_id` remains anywhere in `app.openapi()` inputs.

**Why:** Task 3 made the wire value ignored; this task makes it *nonexistent*, so the vulnerable input cannot be reintroduced by accident. The OpenAPI guard makes that permanent.

- [ ] **Step 1: Write the failing regression guard**

Add to `backend/tests/test_auth.py`:

```python
def test_no_landlord_id_in_any_request_input():
    """landlord_id must never be a client-supplied input (query/form/body).
    Response models may still expose it — this checks inputs only."""
    from main import app
    spec = app.openapi()
    schemas = spec.get("components", {}).get("schemas", {})

    offenders = []
    for path, methods in spec.get("paths", {}).items():
        for method, op in methods.items():
            for param in op.get("parameters", []):
                if param.get("name") == "landlord_id":
                    offenders.append(f"{method.upper()} {path} param")
            body = op.get("requestBody", {})
            for content in body.get("content", {}).values():
                schema = content.get("schema", {})
                ref = schema.get("$ref")
                if ref:
                    name = ref.split("/")[-1]
                    props = schemas.get(name, {}).get("properties", {})
                else:
                    props = schema.get("properties", {})
                if "landlord_id" in props:
                    offenders.append(f"{method.upper()} {path} body")

    assert not offenders, f"landlord_id is still a client input: {offenders}"
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `cd backend && python -m pytest tests/test_auth.py::test_no_landlord_id_in_any_request_input -v`
Expected: FAIL — the 9 models and any remaining Form/Query still expose `landlord_id`.

- [ ] **Step 3: Remove `landlord_id` from the 9 request models**

In `backend/models/documind_models.py`, delete the `landlord_id: str` line from each of: `AskRequest`, `UnassignUnitRequest`, `FactsUpdateRequest`, `DocumentRenameRequest`, `PaymentExceptionRequest`, `DocumentExceptionRequest`, `RentRecoveryRequest`, `ManualLoanEntryRequest`, `UnitLoanExemptionRequest`. Leave `DocUploadResponse.landlord_id` and `DocumentInfo.landlord_id` (these are responses — output, not input).

- [ ] **Step 4: Thread landlord_id through the ask path**

In `backend/rag/documind_service.py`, change:

```python
async def ask_documind(self, payload: AskRequest) -> AskResponse:
    return await self._ask_orchestrator.ask(payload)
```

to:

```python
async def ask_documind(self, payload: AskRequest, landlord_id: str) -> AskResponse:
    return await self._ask_orchestrator.ask(payload, landlord_id)
```

In `backend/api/rex_routes.py`, change the ask route body from `payload.landlord_id = landlord_id` + `ask_documind(payload)` to:

```python
    return await documind_service.ask_documind(payload, landlord_id)
```

In `backend/rag/ask/ask_orchestrator.py`, change `async def ask(self, payload: AskRequest)` to `async def ask(self, payload: AskRequest, landlord_id: str)` and replace all four `payload.landlord_id` references (lines ~81, ~90, ~156, ~454) with `landlord_id`.

- [ ] **Step 5: Remove landlord_id from test request payloads**

In the three `test_rex_routes_*` files, remove `"landlord_id": ...` keys from JSON bodies and `landlord_id=...` from query strings / form fields in the requests the tests send. The override still supplies `landlord_id_123` as identity. Check `test_documind_orchestration.py` and any test that calls `ask_documind(...)` / `AskOrchestrator.ask(...)` directly and update those call sites to pass `landlord_id` as the new argument (grep for `.ask_documind(` and `.ask(` in tests).

- [ ] **Step 6: Run the guard, then the full suite**

Run: `cd backend && python -m pytest tests/test_auth.py::test_no_landlord_id_in_any_request_input -v`
Expected: PASS.

Run: `cd backend && python -m pytest`
Expected: all green. If `test_documind_orchestration.py` or `test_finance_chat.py` fail with a missing-argument error, they call `ask`/`ask_documind` directly — add the `landlord_id` argument at those call sites.

- [ ] **Step 7: Commit**

```bash
git add backend/models/documind_models.py backend/api/rex_routes.py backend/rag/documind_service.py backend/rag/ask/ask_orchestrator.py backend/tests/
git commit -m "feat: remove landlord_id from the API wire; add OpenAPI regression guard"
```

---

### Task 5: Test-token minting script (no dev bypass)

**Files:**
- Create: `backend/scripts/mint_test_token.py`

**Interfaces:**
- Produces: a CLI that prints a real Firebase ID token for a test account, for curl-based manual testing.

**Why:** Developers need to hit authenticated routes locally. The forbidden alternative is an auth-bypass flag. This mints a *real* token instead, so the trust boundary is exercised, not disabled.

- [ ] **Step 1: Write the script**

```python
# backend/scripts/mint_test_token.py
"""Print a real Firebase ID token for a test account, for manual API testing.

    python scripts/mint_test_token.py <email> <password>

Signs in via the Firebase Auth REST API (same flow the app uses) and prints
the ID token. Requires FIREBASE_WEB_API_KEY in the environment (the Web API
key from the Firebase console — NOT a service account). This mints a genuine
token so the auth path is exercised; there is deliberately no bypass flag.
"""
import os
import sys

import requests


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: python scripts/mint_test_token.py <email> <password>", file=sys.stderr)
        return 2

    api_key = os.getenv("FIREBASE_WEB_API_KEY")
    if not api_key:
        print("FIREBASE_WEB_API_KEY is not set", file=sys.stderr)
        return 2

    email, password = sys.argv[1], sys.argv[2]
    resp = requests.post(
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
        params={"key": api_key},
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=30,
    )
    if resp.status_code != 200:
        print(f"sign-in failed: {resp.status_code} {resp.text}", file=sys.stderr)
        return 1

    print(resp.json()["idToken"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Verify it runs (no network) and reports missing key cleanly**

Run: `cd backend && python scripts/mint_test_token.py a b` with `FIREBASE_WEB_API_KEY` unset.
Expected: prints `FIREBASE_WEB_API_KEY is not set` and exits non-zero. (No unit test needed — it is a dev tool with no importable logic worth mocking.)

- [ ] **Step 3: Commit**

```bash
git add backend/scripts/mint_test_token.py
git commit -m "chore: add mint_test_token.py for authenticated local testing"
```

---

### Task 6: Tighten Firestore rules

**Files:**
- Modify: `residex_app/firestore.rules`

**Interfaces:**
- Produces: `/properties` readable only by its owner; `/leases` closed to clients.

**Why:** These rules guard *direct* Firestore access (the app's config ships in the APK; an attacker can query Firestore without the app). `allow read: if request.auth != null` currently leaks every landlord's properties to any signed-in user. Verified safe: all six query sites in `property_remote_datasource.dart` already filter by `landlordId`, so owner-scoped reads do not break the app.

- [ ] **Step 1: Edit the properties read rule**

In `residex_app/firestore.rules`, change the `/properties/{propertyId}` block's read rule from:

```
      allow read: if request.auth != null;
```

to:

```
      allow read: if request.auth != null &&
                     request.auth.uid == resource.data.landlordId;
```

Leave the `create`/`update`/`delete` rules and the nested `units` block unchanged.

- [ ] **Step 2: Close the leases rule**

Change the `/leases/{leaseId}` block from:

```
      allow read: if request.auth != null;
      allow write: if false;
```

to:

```
      allow read, write: if false; // Backend (Admin SDK) only; app never queries leases
```

- [ ] **Step 3: Verify rules syntax compiles**

Run: `cd residex_app && firebase deploy --only firestore:rules --dry-run` if the Firebase CLI is available; otherwise verify by inspection that braces balance and `rules_version = '2';` is intact. (Deployment itself is a manual step the human partner performs against their project — note it in the handoff, do not deploy from the plan.)

- [ ] **Step 4: Commit**

```bash
git add residex_app/firestore.rules
git commit -m "fix: scope properties reads to owner, close leases to clients"
```

---

### Task 7: Add versioned Storage rules

**Files:**
- Create: `residex_app/storage.rules`
- Modify: `residex_app/firebase.json`

**Interfaces:**
- Produces: a committed `storage.rules` locking all client access to Storage; `firebase.json` references it.

**Why:** Storage rules are currently unversioned and grant read+write to any authenticated user on four path prefixes. They are not exploited today (nothing writes there; DocuMind PDFs live under an unmatched `documind/` prefix and are served via server-signed URLs), but they become cross-tenant holes the moment anything is stored under them. The backend uses the Admin SDK (bypasses rules), and the app never touches Storage directly, so fully closing client access is correct and safe.

- [ ] **Step 1: Create the rules file**

```
# residex_app/storage.rules
rules_version = '2';

// All client access to Storage is denied. The backend uses the Admin SDK,
// which bypasses these rules; the app never touches Storage directly and
// views documents through short-lived backend-signed URLs.
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 2: Register it in firebase.json**

In `residex_app/firebase.json`, add a `storage` key alongside the existing `firestore` and `hosting` keys:

```json
  "storage": {
    "rules": "storage.rules"
  },
```

(Place it as a sibling of `"firestore"`. Ensure the resulting file is valid JSON — a comma after the block it follows, none after the last block.)

- [ ] **Step 3: Verify firebase.json is valid JSON**

Run: `cd residex_app && python -c "import json; json.load(open('firebase.json')); print('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add residex_app/storage.rules residex_app/firebase.json
git commit -m "fix: add versioned Storage rules locking client access"
```

---

### Task 8: Flutter AuthedClient (token attachment)

**Files:**
- Create: `residex_app/lib/core/network/authed_client.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart:18-20` (inject the client)
- Test: `residex_app/test/core/network/authed_client_test.dart`

**Interfaces:**
- Produces: `AuthedClient` — an `http.BaseClient` that attaches `Authorization: Bearer <token>` on every request via an injected `Future<String?> Function()` token provider. Throws `NotSignedInException` when the token is null.

**Why:** `send(BaseRequest)` is the single chokepoint through which `get`/`post`/`put`/`delete`/`MultipartRequest`/the NDJSON stream all pass. Attaching the header there makes it structurally impossible to miss a call site. Injecting a token *function* (not `FirebaseAuth`) keeps it unit-testable.

- [ ] **Step 1: Write the failing test**

```dart
// residex_app/test/core/network/authed_client_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:residex_app/core/network/authed_client.dart';

void main() {
  test('attaches bearer token to every request', () async {
    String? seen;
    final inner = MockClient((req) async {
      seen = req.headers['Authorization'];
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final client = AuthedClient(inner, () async => 'tok123');

    await client.get(Uri.parse('http://x/y'));

    expect(seen, 'Bearer tok123');
  });

  test('throws NotSignedInException when token is null', () async {
    final inner = MockClient((req) async => http.Response('', 200));
    final client = AuthedClient(inner, () async => null);

    expect(() => client.get(Uri.parse('http://x/y')),
        throwsA(isA<NotSignedInException>()));
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `cd residex_app && flutter test test/core/network/authed_client_test.dart`
Expected: FAIL — `authed_client.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// residex_app/lib/core/network/authed_client.dart
import 'package:http/http.dart' as http;

/// Thrown when a request is attempted with no signed-in user.
class NotSignedInException implements Exception {
  @override
  String toString() => 'NotSignedInException: no authenticated user';
}

/// An [http.Client] that attaches a Firebase ID token to every outgoing
/// request. `send` is the single chokepoint for all verbs, multipart uploads,
/// and streamed responses, so no call site can forget the header.
class AuthedClient extends http.BaseClient {
  final http.Client _inner;
  final Future<String?> Function() _getToken;

  AuthedClient(this._inner, this._getToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _getToken();
    if (token == null) throw NotSignedInException();
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `cd residex_app && flutter test test/core/network/authed_client_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Inject AuthedClient into the datasource provider**

In `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`, add imports:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../core/network/authed_client.dart';
```

Change the datasource provider (lines 18-20) to:

```dart
final documindRemoteDataSourceProvider = Provider<DocuMindRemoteDataSource>((ref) {
  final http.Client client = AuthedClient(
    http.Client(),
    () => FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null),
  );
  return DocuMindRemoteDataSource(httpClient: client);
});
```

- [ ] **Step 6: Analyze**

Run: `cd residex_app && flutter analyze lib/core/network/authed_client.dart lib/features/landlord/presentation/providers/documind_provider.dart`
Expected: no errors (the pre-existing widget_test issue is unrelated). At this point the token is attached on every DocuMind request; `landlord_id` is still sent too (harmless, removed next task).

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/core/network/authed_client.dart residex_app/test/core/network/authed_client_test.dart residex_app/lib/features/landlord/presentation/providers/documind_provider.dart
git commit -m "feat: attach Firebase ID token to all DocuMind requests via AuthedClient"
```

---

### Task 9: Remove landlordId from the Flutter DocuMind stack

**Files:**
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart` (all methods)
- Modify: `residex_app/lib/features/landlord/domain/repositories/documind_repository.dart` (interface)
- Modify: `residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart`
- Modify: `residex_app/lib/features/landlord/domain/usecases/upload_document.dart`, `ask_documind_question.dart`, `list_documents.dart`, `get_document_view_url.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (action providers)

**Interfaces:**
- Consumes: `AuthedClient` (Task 8) — identity now travels in the token, so `landlordId` is dead weight in this stack.
- Produces: no `landlordId` parameter anywhere in the DocuMind datasource → repository → usecase → provider chain, and no `landlord_id` key in any HTTP field/query/body.

**Why:** Approach A makes the vulnerable pattern unrepresentable. Leaving dead `landlordId` params would invite reintroducing the bug. `currentLandlordIdProvider` STAYS — the direct-Firestore property/unit datasources still need the uid — but the DocuMind chain stops threading it.

This task changes four statically-typed layers together: removing a `required` parameter surfaces as analyzer errors at every remaining call site, so the layers cannot be split into separately-compiling sub-tasks. The verification is `flutter analyze` (compile-time proof the chain is consistent) plus `flutter test`.

- [ ] **Step 1: Strip landlord_id from every HTTP payload in the datasource**

In `documind_remote_datasource.dart`, for every method: delete the `required String landlordId,` parameter, delete the `print('   - Landlord: $landlordId');` lines, and remove the `landlord_id` entry from each `request.fields`, `queryParameters`/`queryParams` map, and `json.encode({...})` body. Do not touch `property_id`, `unit_id`, or any other field. (Methods affected: `uploadDocument`, `askQuestion`, `listDocuments`, `deleteDocument`, `deleteDocumentsForProperty`, `unassignUnitDocuments`, `getFinanceSummary`, `getDocumentViewUrl`, `updateExpenseLines`, `renameDocument`, `setPaymentException`, `clearPaymentException`, `setDocumentUnavailable`, `clearDocumentUnavailable`, `recordRentRecovery`, `clearRentRecovery`, `recordManualLoanEntry`, `deleteManualLoanEntry`, `setUnitLoanExemption`, `clearUnitLoanExemption`, `listManualLoanEntries`.)

- [ ] **Step 2: Remove landlordId from the repository interface and impl**

In `documind_repository.dart`, delete `required String landlordId,` from `uploadDocument`, `askQuestion`, `listDocuments`, `deleteDocument`, `deleteDocumentsForProperty`, `unassignUnitDocuments`, `getDocumentViewUrl`, `getFinanceSummary`.

In `documind_repository_impl.dart`, delete the matching `required String landlordId,` params, the `print('   - Landlord: $landlordId');` lines, and the `landlordId: landlordId,` arguments passed to the datasource.

- [ ] **Step 3: Remove landlordId from the four use cases**

In each of `upload_document.dart`, `ask_documind_question.dart`, `list_documents.dart`, `get_document_view_url.dart`: delete the `required String landlordId,` parameter and the `landlordId: landlordId,` argument forwarded to the repository. (Grep each file for `landlordId` to catch the `call(...)` signature and the forwarding.)

- [ ] **Step 4: Remove landlordId reads from the action providers**

In `documind_provider.dart`, in every action/provider that currently does `final landlordId = ref.read(currentLandlordIdProvider);` *solely* to pass it into a DocuMind use case/repository/datasource call, delete that line and the `landlordId: landlordId,` argument. Do NOT delete the `currentLandlordIdProvider` definition itself (lines 52-55) — it is still consumed by property/unit providers elsewhere. After editing, grep the file for `landlordId:` to confirm none remain in DocuMind calls.

- [ ] **Step 5: Analyze — this is the consistency proof**

Run: `cd residex_app && flutter analyze`
Expected: no new errors. Any lingering `landlordId:` argument or leftover `required String landlordId` produces an analyzer error pointing exactly at the miss. Fix until clean (the one pre-existing `widget_test.dart` boilerplate failure is expected).

- [ ] **Step 6: Run the Flutter test suite**

Run: `cd residex_app && flutter test`
Expected: the AuthedClient tests pass; the only failure is the known pre-existing `widget_test.dart` boilerplate. If any DocuMind-related test references `landlordId`, update it to drop the argument.

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/
git commit -m "refactor: remove landlordId from the Flutter DocuMind stack"
```

---

## Self-Review

**Spec coverage:**
- Backend `firebase_app.py` → Task 1 ✓
- Backend `api/auth.py` (both dependencies, `check_revoked=False`) → Task 2 ✓
- Router-level fail-closed dependency → Task 3 ✓
- `/` and `/health` stay open (they live on `app`, not `router`; untouched) ✓
- Remove `landlord_id` from 9 models + Form + Query → Task 4 ✓
- Status-code contract (401 token_missing/invalid/expired, 403 forbidden) → Task 2 (401 codes) ✓. **Note:** the 403 cross-landlord case is enforced by the *preserved service-layer ownership checks*, which already raise on mismatch; with identity now from the token, a cross-landlord attempt is impossible via the API rather than merely rejected. No new 403 code path is added because the wire no longer lets a caller name another landlord. This is a stronger outcome than the spec's table and is called out here intentionally.
- No dev bypass; `mint_test_token.py` → Task 5 ✓
- Service-layer ownership checks preserved (no service files change except the ask-path threading, which is identity plumbing, not an ownership-check change) → Tasks 3–4 ✓
- Flutter `AuthedClient` over `send()` → Task 8 ✓
- Remove `landlordId` from datasource + chain; `currentLandlordIdProvider` stays → Task 9 ✓
- Firestore `/properties` owner-scoped, `/leases` closed → Task 6 ✓
- Storage `storage.rules` = closed, registered in `firebase.json` → Task 7 ✓
- Route tests via `dependency_overrides` → Task 3 ✓
- `test_auth.py` (6 cases + OpenAPI regression guard) → Tasks 2 (5 cases) + 4 (guard) ✓. The spec's "expired" and "cross-landlord 403" are covered: expired in Task 2; cross-landlord is now structurally impossible (see the note above) and is asserted indirectly by the regression guard proving no caller can name another landlord.
- All 468 existing tests stay green → verified at the end of every backend task ✓

**Deferred/handoff items (not tasks — human partner actions, per spec):** revoke the 3 leaked API keys before first push; remove the self-ignoring `.gitignore` first line and commit the file; deploy the Firestore/Storage rules to the Firebase project; flip the `?? 'guest'` fallback in `currentLandlordIdProvider` to an explicit signed-out UI state (a UX decision, tracked separately from this security plan).

**Placeholder scan:** no TBD/TODO; every code step has concrete content. ✓

**Type consistency:** `verify_firebase_token`/`current_landlord_id` signatures match between Task 2 (definition) and Task 3 (use). `ask_documind(payload, landlord_id)` and `AskOrchestrator.ask(payload, landlord_id)` match between Task 4's interface block and its steps. `AuthedClient(inner, getToken)` matches between Task 8's definition, test, and provider injection. ✓

**Note on `.gitignore`:** the spec calls for removing its self-ignoring first line. That is a one-line human action folded into the handoff list above rather than a code task, because committing `.gitignore` correctly depends on the human partner's intent for what else that file should track.
