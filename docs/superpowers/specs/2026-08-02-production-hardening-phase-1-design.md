# Production Hardening, Phase 1: Close the Trust Boundary

**Date:** 2026-08-02
**Status:** Approved, ready for implementation planning
**Scope:** Backend authentication, Firestore/Storage rules, credential hygiene

## Context

Residex is being prepared for a **closed-testing Android release to roughly 10-30
invited landlords**, handling real tenancy agreements, IC numbers, and bank
statements. An audit of the repo turned up one critical vulnerability and several
supporting gaps.

The critical one: **the backend has no authentication.** `landlord_id` is a
client-supplied `Form`, `Query`, or body parameter on all 22 routes in
`backend/api/rex_routes.py`. Any caller can pass another landlord's ID and read,
edit, or delete their documents and financial records. The ownership checks that
exist in the service layer are real, but they verify a value the client itself
supplied, so they verify nothing.

Everything in this phase is **hosting-independent**. The separate question of
where the backend runs in production — Cloud Run with hosted models versus a
free always-on VM running Ollama locally — is explicitly deferred to Phase 2.
That decision does not block, and must not delay, closing this hole.

### Deliberately out of scope for Phase 1

Named here so they are conscious deferrals rather than oversights:

- **App Check enforcement** on the backend, and the `AndroidProvider.debug` →
  `playIntegrity` flip. Belongs with release configuration.
- **Rate limiting.** A 30-person closed beta does not need it.
- **Release signing.** The app currently release-builds with the debug keystore
  (`android/app/build.gradle.kts:49`); Play will reject that. Release config work.
- **Hosting and the backend URL.** `api_constants.dart` points at the emulator
  loopback `http://10.0.2.2:8000` over cleartext. Phase 2.
- **Provider/model placement.** Phase 2.

## Design

### Backend

#### `backend/firebase_app.py` (new)

An idempotent `ensure_initialized()`. Today the `firebase_admin.initialize_app(...)`
call lives at import scope in `rag/documind_service.py:54`, which means an auth
dependency would work only as a side effect of import ordering. Extracting it
makes that dependency explicit. Both `documind_service` and the auth module call
it; whichever runs first wins.

The existing call passes no credential argument, so it resolves Application
Default Credentials. That behaviour is preserved exactly.

One caveat for Phase 2, recorded here so it is not discovered late: dropping
`serviceAccountKey.json` in favour of an ambient runtime identity is *not* a pure
environment change. `blob.generate_signed_url(...)` in
`documents/document_lifecycle_service.py:352` needs a private key to sign, which
ambient credentials do not have. On Cloud Run it requires passing
`service_account_email` and using the IAM `signBlob` API, plus the
`iam.serviceAccountTokenCreator` role. That is Phase 2 work, but it is a code
change, not just configuration.

#### `backend/api/auth.py` (new)

```python
async def verify_firebase_token(authorization: str | None = Header(None)) -> dict
async def current_landlord_id(claims: dict = Depends(verify_firebase_token)) -> str
```

`verify_firebase_token` extracts the bearer token, calls
`firebase_admin.auth.verify_id_token`, and returns the decoded claims.
`current_landlord_id` returns `claims["uid"]`.

`check_revoked` stays `False`. Setting it `True` costs a network round-trip per
request to catch admin-revoked sessions, which a 30-person beta will not hit, and
ID tokens expire hourly regardless.

#### Router wiring

```python
router = APIRouter(prefix="/api/rex", tags=["rex-ai"],
                   dependencies=[Depends(verify_firebase_token)])
```

This is the load-bearing decision. Authentication attaches to the **router**, not
to individual routes, so every current route and every route added later is
authenticated by default and cannot be forgotten. Routes needing the identity
declare `landlord_id: str = Depends(current_landlord_id)`.

FastAPI caches sub-dependencies per request, so `verify_firebase_token` executes
once even though both the router-level and route-level dependencies reference it.
No `request.state` juggling.

`/` and `/health` live on `app` in `main.py`, not on the router, and stay
unauthenticated for uptime checks. Intentional.

#### Wire changes

`landlord_id` is removed from the public API entirely:

- 9 Pydantic request models in `models/documind_models.py`: `AskRequest`,
  `UnassignUnitRequest`, `FactsUpdateRequest`, `DocumentRenameRequest`,
  `PaymentExceptionRequest`, `DocumentExceptionRequest`, `RentRecoveryRequest`,
  `ManualLoanEntryRequest`, `UnitLoanExemptionRequest`
- `Form(...)` parameters on both upload routes
- `Query(...)` parameters on the GET and DELETE routes

After this change there is no client-supplied landlord identity anywhere in the
API surface. This is the point of Approach A: the fix is not "add 22 checks," it
is "remove the untrusted input those checks existed to guard."

#### Status code contract

| Condition | Code | App behaviour |
|---|---|---|
| Missing or malformed header, bad signature, absent `uid` | 401 | Sign out |
| Expired token | 401 + `token_expired` | Refresh, retry once, stay signed in |
| Valid token, resource owned by another landlord | 403 | Show error |

Distinguishing expiry from invalidity matters: the app must refresh rather than
sign the user out on a merely stale token. 400/404/422 semantics are unchanged.

The discriminator is a machine-readable `code` inside FastAPI's `detail` object,
so the app branches on a stable value rather than parsing prose:

```json
{"detail": {"code": "token_expired", "message": "ID token has expired"}}
```

Codes: `token_expired`, `token_invalid`, `token_missing`, `forbidden`. All 401
responses carry one; the app treats only `token_expired` as retryable.

#### Service-layer ownership checks are preserved

The existing checks (for example `documents/document_lifecycle_service.py:342`,
and `_require_owned_property` in `finance/finance_overrides_repository.py`) are
**not** removed as now-redundant. They stop being the only line of defense and
become genuine defense-in-depth. No service-layer files change in this phase.

#### No development bypass

A `DEV_AUTH_BYPASS`-style environment flag is **explicitly rejected**, despite
being convenient. A flag whose purpose is to disable authentication is exactly
the mechanism by which this vulnerability returns, and it will eventually be set
in the wrong environment.

Instead, `backend/scripts/mint_test_token.py` signs a test account in through the
Firebase Auth REST endpoint and prints a real ID token for curl. Same
convenience, no footgun.

### Flutter app

#### Authenticated HTTP client

A class extending `http.BaseClient` overriding `send()`:

```dart
class AuthedClient extends http.BaseClient {
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw NotSignedInException();
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }
}
```

`send(BaseRequest)` is the single chokepoint through which `get`, `post`, `put`,
`delete`, `MultipartRequest`, and the NDJSON streaming upload all pass. Attaching
the header there makes it structurally impossible to miss a call site — the same
reasoning as router-level dependencies on the backend.

`getIdToken()` auto-refreshes when the cached token is expired or near expiry, so
the common case needs no retry logic. Reactive force-refresh
(`getIdToken(true)`) and retry-once applies to **plain requests only**: a consumed
multipart body cannot be replayed, and rebuilding it is not worth the complexity
at this stage. An upload landing in that window surfaces an error and the user
retries.

#### Datasource changes

`required String landlordId` is removed from the ~20 methods in
`documind_remote_datasource.dart`, along with every site that writes it into
form fields, query parameters, or JSON bodies. Callers in the providers stop
passing it.

The `currentLandlordId` provider **stays** — the direct-Firestore paths for
properties and units still need the uid. Its `?? 'guest'` fallback
(`documind_provider.dart:54`) becomes an explicit signed-out state rather than a
magic string.

### Firestore rules

```
match /properties/{propertyId} {
  allow read: if request.auth != null && request.auth.uid == resource.data.landlordId;
```

Currently `allow read: if request.auth != null`, meaning any signed-in user can
read every landlord's properties.

**Verified safe:** all six query sites in `property_remote_datasource.dart`
already filter `.where('landlordId', isEqualTo: landlordId)`. This verification
was necessary because **Firestore rules are not filters** — a query that does not
constrain to the owner is rejected outright rather than silently returning fewer
results. This remains the change most likely to break something at runtime, so it
requires a manual pass through the app after the rules deploy.

`/leases` becomes `allow read, write: if false`. The app references leases only
in a dashboard string; it never queries the collection.

### Storage rules

A new `storage.rules`, registered in `firebase.json` (which currently declares
only `firestore` and `hosting`), set to `allow read, write: if false`.

Confirmed correct rather than over-tight: the backend uses the Admin SDK, which
bypasses rules entirely, and the app never touches Storage directly —
`firebase_storage` appears in `pubspec.yaml` but is unused in `lib/`. Uploads go
through the backend and views return backend-generated signed URLs.

The deployed rules were retrieved from the console and are **not** in version
control. They are permissive but, as it happens, not currently exploitable:

```
match /contracts/{leaseId}          { allow read, write: if isAuthenticated(); }
match /maintenance/{ticketId}/{f}   { allow read, write: if isAuthenticated(); }
match /bills/{billId}/{f}           { allow read, write: if isAuthenticated(); }
match /documents/{documentId}/{f}   { allow read, write: if isAuthenticated(); }
match /profiles/{userId}            { allow read: if isAuthenticated();
                                      allow write: if isOwner(userId); }
```

Four of these grant read *and write* to any authenticated user. They are harmless
today only because nothing writes to those paths — no Dart file imports
`firebase_storage` — and because DocuMind's own documents live under
`documind/{landlord_id}/{property_id}/{doc_id}` (`documents/ingestion_service.py:176`),
which no `match` block covers. Firebase Storage denies unmatched paths by default,
so those PDFs are already unreachable from clients; they are served exclusively
through 10-minute signed URLs generated server-side
(`documents/document_lifecycle_service.py:352`) using the Admin SDK, which bypasses
rules.

So this is wrong-by-default rather than currently-exploited: each of those four
blocks becomes a real cross-tenant read/write hole the moment anything is stored
under it. Replacing the whole file with `allow read, write: if false` is both
correct and zero-risk given no client code touches Storage.

### Credential hygiene

`serviceAccountKey.json` and `backend/.env` were **never committed**. No rotation
required for either, and no history to clean.

`backend_reference_example/.env` **is tracked**, with 10 populated values
including `TAVILY_API_KEY`, `LANGCHAIN_API_KEY`, and `LLAMA_CLOUD_API_KEY`. It has
never reached the remote — verified against `origin/main`, `origin/branch1`, and
`origin/branch2` — but the local branch is **235 commits ahead of `origin/main`**,
so pushing for production work would publish them.

The folder was untracked in commit `9d5dc9f`, which stops it tracking forward but
does **not** purge the keys from history — they remain in the 235 unpushed commits.

**Action: revoke those three keys.** Preferred over rewriting history. The folder
was reference material from an earlier project, unrelated to Residex, so the keys
are almost certainly disposable; revocation is a five-minute job with zero risk,
while `filter-repo` across 235 unpushed commits is a genuine footgun. This is
independent of the rest of this phase and should be done before the first push.

`.gitignore` self-ignores — its own first line is `.gitignore` — which is why none
of its rules bind for anyone but the local checkout. Remove that line and commit
the file.

## Testing

- **Route tests.** `app.dependency_overrides[verify_firebase_token] = lambda: {"uid": "landlord_123"}`
  in `setUp`, cleared in `tearDown`. One fixture change per class across
  `test_rex_routes_documind_ask_api.py`, `test_rex_routes_documind_docs_api.py`,
  and `test_rex_routes_finance_api.py` — not a per-test rewrite.
- **New `backend/tests/test_auth.py`.** Missing header, malformed header, expired
  token, bad signature, valid token, and cross-landlord 403. Firebase verification
  is patched at `firebase_admin.auth.verify_id_token` so these tests exercise the
  dependency's real branching logic without a live Firebase project.
- **Regression guard**, in the same file. A test walking `app.openapi()` asserting
  that no operation has a parameter named `landlord_id` and no request-body schema
  carries a `landlord_id` property. This is what makes the fix permanent rather
  than a one-time cleanup, and a single assertion covers Query, Form, and body
  simultaneously.
- **All 468 existing tests stay green.**

## Migration note

`documind_provider.dart:54` falls back to `'guest'` when signed out, so data
written under `landlord_id = 'guest'` would become unreachable once identity comes
from the token. **Checked: zero such documents exist**, so there is no migration
to perform. The `'guest'` fallback is still replaced with an explicit signed-out
state, to prevent the class of orphaned data rather than to clean any up.

## Success criteria

1. Every route under `/api/rex` rejects an unauthenticated request with 401.
2. No `landlord_id` appears anywhere in the OpenAPI schema, enforced by test.
3. A valid token for landlord A cannot read, modify, or delete landlord B's
   documents or finance records — verified by test, not by inspection.
4. `properties` and `leases` are no longer readable by arbitrary signed-in users.
5. Storage is closed to direct client access, and the rules are in version control.
6. The three exposed third-party API keys are revoked.
7. All 468 existing tests plus the new auth tests pass.
