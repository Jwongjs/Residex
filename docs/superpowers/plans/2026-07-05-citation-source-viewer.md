# Citation Source Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a citation in the Documind relevance-meter widget opens the original source PDF, jumped to the cited page.

**Architecture:** Backend uploads the original PDF to Firebase Storage at ingest time (via the already-installed `firebase-admin` SDK) and records the storage path on the `documind_docs` Firestore document. A new scoped endpoint issues short-lived signed URLs for viewing. The Flutter app adds a thin data/repository/usecase chain to fetch that URL, caches the downloaded PDF on-device by `doc_id`, and opens it in a new `DocumentViewerScreen` using `syncfusion_flutter_pdfviewer`, jumped to the cited page.

**Tech Stack:** FastAPI + `firebase-admin` (Storage) + Firestore (Python backend); Flutter + Riverpod + `http` + `path_provider` + `syncfusion_flutter_pdfviewer` (client).

## Global Constraints

- PDFs only — DOCX ingestion isn't implemented on the backend today; this feature is not extended to DOCX.
- No backfill — documents uploaded before this feature ships have no Storage copy and are not retroactively viewable.
- No changes to retrieval/scoring — `_rerank`, citation dedup, and relevance-bar rendering are untouched.
- Follow existing print-statement/error-handling conventions in each file (this codebase uses emoji-free code in new work per the current standing rule — new code added by this plan must not use emoji in print statements or user-facing strings, even though some pre-existing surrounding code still does; do not retrofit unrelated existing lines).
- Signed URLs expire after 10 minutes.

---

### Task 1: Backend — Firebase Storage upload on ingest

**Files:**
- Modify: `backend/rag/documind_service.py:1-30` (imports, module-level init)
- Modify: `backend/rag/documind_service.py:72-96` (`__init__`, add `storage_bucket` property)
- Modify: `backend/rag/documind_service.py:201-299` (`ingest_document`)
- Test: `backend/tests/test_documind_service_flows.py` (new test class/methods)

**Interfaces:**
- Consumes: `firebase_admin` (already in `requirements.txt`), `os.getenv("GOOGLE_CLOUD_PROJECT")` (already used elsewhere in this codebase per `HANDOFF.md`), the existing `documind_docs` Firestore collection.
- Produces: `DocuMindService.storage_bucket` (lazy property, returns a `firebase_admin.storage.bucket()` object), a new `storage_path` field on every `documind_docs` document (format: `documind/{landlord_id}/{property_id}/{doc_id}.pdf`), written during `ingest_document`.

- [ ] **Step 1: Write the failing test for storage upload during ingest**

Add to `backend/tests/test_documind_service_flows.py` (append near the other test classes, after existing imports — add `from unittest.mock import MagicMock` to the existing `unittest.mock` import line if not already present):

```python
class _FakeBlob:
    def __init__(self, bucket, path):
        self.bucket = bucket
        self.path = path
        self.uploaded_content = None
        self.uploaded_content_type = None

    def upload_from_string(self, content, content_type=None):
        self.uploaded_content = content
        self.uploaded_content_type = content_type
        self.bucket.blobs[self.path] = self


class _FakeStorageBucket:
    def __init__(self):
        self.blobs = {}

    def blob(self, path):
        return _FakeBlob(self, path)


class DocuMindServiceStorageTests(unittest.IsolatedAsyncioTestCase):
    async def test_ingest_document_uploads_pdf_to_storage(self):
        fake_db = _FakeDB()
        fake_bucket = _FakeStorageBucket()
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket

        pdf_bytes = b"%PDF-1.4 fake content"

        class _FakeUploadFile:
            filename = "lease.pdf"

            async def read(self):
                return pdf_bytes

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documind_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            fake_page = MagicMock()
            fake_page.page_content = "Some lease text"
            fake_page.metadata = {"page": 0}
            loader_mock.return_value.load.return_value = [fake_page]

            response = await service.ingest_document(
                landlord_id="l1",
                property_id="p1",
                category="lease",
                file=_FakeUploadFile(),
            )

        expected_path = f"documind/l1/p1/{response.doc_id}.pdf"
        self.assertIn(expected_path, fake_bucket.blobs)
        self.assertEqual(fake_bucket.blobs[expected_path].uploaded_content, pdf_bytes)
        self.assertEqual(fake_bucket.blobs[expected_path].uploaded_content_type, "application/pdf")

        stored_doc = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored_doc["storage_path"], expected_path)
```

Note: `_build_service`, `_FakeDB`, `_FakeConversationStore`, `_FakeGraphOrchestrator`, `_FakeLLM`, `_FakeEmbeddings` already exist in this file (see lines 21-180) — reuse them as-is. `_FakeDB.docs` is a plain list the fake `documind_docs` collection writes into (confirmed via `_FakeCollectionQuery` in the same file) — `doc_ref.set(...)` in the real code needs to append/update that list for this assertion to work, which the existing `_FakeCollection`/`_FakeDB` fixtures already support for reads but you must confirm `set()` is faked too. If `_FakeDB` doesn't yet support `.set()` on a `documind_docs` document reference (it currently only supports `.document()` for `properties`, per `_FakeCollection.document()` at line 116-119), add that support in this same step: extend `_FakeCollection.document()` to also handle `"documind_docs"` by returning a small fake doc-reference object whose `.set(data)` appends `{**data, "doc_id": doc_id}` to `self._db.docs`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py::DocuMindServiceStorageTests::test_ingest_document_uploads_pdf_to_storage -v`
Expected: FAIL — `AttributeError: 'DocuMindService' object has no attribute '_storage_bucket'` (or similar, since the property/upload code doesn't exist yet).

- [ ] **Step 3: Add firebase_admin initialization and storage_bucket property**

In `backend/rag/documind_service.py`, add to the imports near the top (after the existing `from google.cloud import firestore` block, around line 20-23):

```python
import firebase_admin
from firebase_admin import storage as firebase_storage
```

After the existing module-level `db = firestore.Client()` (line 50), add:

```python
if not firebase_admin._apps:
    firebase_admin.initialize_app(options={
        'storageBucket': f"{os.getenv('GOOGLE_CLOUD_PROJECT')}.appspot.com",
    })
```

In `class DocuMindService.__init__` (currently lines 72-87), add one line after `self._db = db`:

```python
        self._storage_bucket = None
```

After the existing `embeddings` property (ends around line 109), add a new lazy property:

```python
    @property
    def storage_bucket(self):
        """Lazy-load the Firebase Storage bucket (only when first accessed)."""
        if self._storage_bucket is None:
            self._storage_bucket = firebase_storage.bucket()
        return self._storage_bucket
```

- [ ] **Step 4: Wire the upload into ingest_document**

In `backend/rag/documind_service.py`, `ingest_document` (currently spans lines 201-299). The method currently reads the upload into `content` (line 218: `content = await file.read()`) and writes it to `temp_path`. Keep that, but also upload the same `content` bytes to Storage. Modify the block starting at the existing "Step 6: Store document metadata" comment (around line 275-287) to add the storage path:

```python
            # Step 5.5: Upload original PDF to Firebase Storage
            storage_path = f"documind/{landlord_id}/{property_id}/{doc_id}.pdf"
            blob = self.storage_bucket.blob(storage_path)
            blob.upload_from_string(content, content_type="application/pdf")

            # Step 6: Store document metadata
            file_size = os.path.getsize(temp_path)
            doc_ref = self.db.collection('documind_docs').document(doc_id)
            doc_ref.set({
                'landlord_id': landlord_id,
                'property_id': property_id,
                'category': category,
                'filename': file.filename,
                'chunks_indexed': len(chunk_documents),
                'file_size': file_size,
                'storage_path': storage_path,
                'status': 'indexed',
                'uploaded_at': firestore.SERVER_TIMESTAMP,
            })
```

(This replaces the existing "Step 6" block — same code, plus the new `storage_path` upload before it and the new field in the `doc_ref.set(...)` call.)

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py::DocuMindServiceStorageTests::test_ingest_document_uploads_pdf_to_storage -v`
Expected: PASS

- [ ] **Step 6: Run the full existing suite to confirm no regressions**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py tests/test_retriever.py tests/test_rex_routes_documind_docs_api.py -v`
Expected: same baseline as before this change (4 passed / 2 pre-existing failures in `test_documind_service_flows.py`, per `HANDOFF.md`), plus the new test passing, plus `test_retriever.py` and `test_rex_routes_documind_docs_api.py` unaffected.

- [ ] **Step 7: Add firebase-admin to requirements and commit**

`firebase-admin` is already in `backend/requirements.txt` (confirmed) — no change needed there.

```bash
cd backend
git add rag/documind_service.py tests/test_documind_service_flows.py
git commit -m "feat: upload original PDF to Firebase Storage on document ingest"
```

---

### Task 2: Backend — view-url endpoint + Storage cleanup on delete

**Files:**
- Modify: `backend/rag/documind_service.py:741-812` (`delete_document`)
- Modify: `backend/rag/documind_service.py` (new method `get_document_view_url`)
- Modify: `backend/api/rex_routes.py` (new route)
- Test: `backend/tests/test_documind_service_flows.py` (new test method)
- Test: `backend/tests/test_rex_routes_documind_docs_api.py` (new test methods)

**Interfaces:**
- Consumes: `DocuMindService.storage_bucket` (from Task 1), `documind_docs` collection's `storage_path` field (from Task 1).
- Produces: `DocuMindService.get_document_view_url(landlord_id: str, property_id: str, doc_id: str) -> str` (returns a signed URL string, raises `ValueError` if not found/mismatched, matching the existing `delete_document` error convention); route `GET /api/rex/documind/documents/{doc_id}/view-url` returning `{"view_url": "<signed url>"}`, 404 on not found.

- [ ] **Step 1: Write the failing test for get_document_view_url**

Add to `backend/tests/test_documind_service_flows.py`, inside (or near) the `DocuMindServiceStorageTests` class added in Task 1:

```python
    async def test_get_document_view_url_returns_signed_url(self):
        fake_db = _FakeDB(docs=[{
            "landlord_id": "l1",
            "property_id": "p1",
            "storage_path": "documind/l1/p1/doc-1.pdf",
        }])
        fake_bucket = _FakeStorageBucket()

        class _FakeBlobWithSignedUrl(_FakeBlob):
            def generate_signed_url(self, expiration, method="GET"):
                return f"https://fake-storage.example/{self.path}?exp={expiration}"

        fake_bucket.blob = lambda path: _FakeBlobWithSignedUrl(fake_bucket, path)

        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket

        # _FakeDB needs a document() lookup for "documind_docs" keyed by doc_id,
        # matching the extension made in Task 1 Step 1 for ingest's doc_ref.set().
        # Reuse that same fake document-reference support here for .get().
        url = await service.get_document_view_url(landlord_id="l1", property_id="p1", doc_id="doc-1")

        self.assertIn("documind/l1/p1/doc-1.pdf", url)

    async def test_get_document_view_url_raises_when_not_found(self):
        fake_db = _FakeDB(docs=[])
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.get_document_view_url(landlord_id="l1", property_id="p1", doc_id="missing-doc")
```

Note: this test requires `_FakeDB`'s `documind_docs` document-reference support (added in Task 1 Step 1) to also support `.get()` returning a snapshot with `.exists` and `.to_dict()`, matching the pattern already used for `properties` via `_FakePropertyRef`/`_FakePropertyDoc` (lines 50-64 of the test file). If Task 1 only added `.set()` support, extend the same fake doc-reference class in this step to also implement `.get()` returning a `_FakeSnapshot`-like object with `.exists` (True if a matching row exists in `fake_db.docs` by `doc_id`, else False) and `.to_dict()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -k "view_url" -v`
Expected: FAIL — `AttributeError: 'DocuMindService' object has no attribute 'get_document_view_url'`

- [ ] **Step 3: Implement get_document_view_url**

In `backend/rag/documind_service.py`, add a new method near `delete_document` (after it, or before — either is fine since Python doesn't require declaration order within a class):

```python
    async def get_document_view_url(
        self,
        landlord_id: str,
        property_id: str,
        doc_id: str,
    ) -> str:
        """
        Generate a short-lived signed URL to view a document's original PDF.

        Raises:
            ValueError: If document not found or ownership/scope mismatch.
        """
        doc_ref = self.db.collection('documind_docs').document(doc_id)
        doc_snapshot = doc_ref.get()

        if not doc_snapshot.exists:
            raise ValueError(f"Document {doc_id} not found")

        doc_data = doc_snapshot.to_dict()

        if doc_data.get('landlord_id') != landlord_id:
            raise ValueError(f"Document {doc_id} does not belong to landlord {landlord_id}")

        if doc_data.get('property_id') != property_id:
            raise ValueError(f"Document {doc_id} does not belong to property {property_id}")

        storage_path = doc_data.get('storage_path')
        if not storage_path:
            raise ValueError(f"Document {doc_id} has no stored file")

        blob = self.storage_bucket.blob(storage_path)
        return blob.generate_signed_url(expiration=timedelta(minutes=10), method="GET")
```

Add `from datetime import timedelta` to the existing `from datetime import datetime` import line near the top of the file (or add as a separate import line if that's cleaner — check the existing line first and extend it: `from datetime import datetime, timedelta`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -k "view_url" -v`
Expected: PASS (both tests)

- [ ] **Step 5: Add Storage cleanup to delete_document**

In `backend/rag/documind_service.py`, `delete_document` (lines 741-812). After the existing "Step 3: Delete all chunks" block and before "Step 4: Delete document metadata" (around line 802-804), add Storage cleanup using the already-fetched `doc_data`:

```python
        # Step 3.5: Delete the original file from Storage, if one exists
        storage_path = doc_data.get('storage_path')
        if storage_path:
            try:
                self.storage_bucket.blob(storage_path).delete()
                print(f"Deleted storage object {storage_path}")
            except Exception as e:
                print(f"Warning: could not delete storage object {storage_path}: {e}")
```

- [ ] **Step 6: Write the failing test for delete_document Storage cleanup**

Add to `DocuMindServiceStorageTests` in `backend/tests/test_documind_service_flows.py`:

```python
    async def test_delete_document_removes_storage_object(self):
        fake_db = _FakeDB(docs=[{
            "landlord_id": "l1",
            "property_id": "p1",
            "storage_path": "documind/l1/p1/doc-1.pdf",
            "filename": "lease.pdf",
        }])
        fake_bucket = _FakeStorageBucket()
        deleted_paths = []

        class _FakeDeletableBlob(_FakeBlob):
            def delete(self):
                deleted_paths.append(self.path)

        fake_bucket.blob = lambda path: _FakeDeletableBlob(fake_bucket, path)

        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        service._storage_bucket = fake_bucket

        await service.delete_document(landlord_id="l1", property_id="p1", doc_id="doc-1")

        self.assertIn("documind/l1/p1/doc-1.pdf", deleted_paths)
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -k "storage" -v`
Expected: PASS (all storage-related tests, including this new one)

- [ ] **Step 8: Add the view-url route**

In `backend/api/rex_routes.py`, add `from fastapi import HTTPException` to the existing `from fastapi import ...` import line (line 1), then add a new route after the existing `delete_document` route (end of file):

```python
@router.get("/documind/documents/{doc_id}/view-url")
async def get_document_view_url(
    doc_id: str,
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
    property_id: str = Query(..., description="Property ID for scoping"),
):
    """
    Get a short-lived signed URL to view a document's original PDF.

    Example:
        GET /api/rex/documind/documents/abc123/view-url?landlord_id=landlord_456&property_id=property_789
    """
    try:
        view_url = await documind_service.get_document_view_url(
            landlord_id=landlord_id,
            property_id=property_id,
            doc_id=doc_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    return {"view_url": view_url}
```

- [ ] **Step 9: Write the failing route test**

Add to `backend/tests/test_rex_routes_documind_docs_api.py`, inside `DocuMindDocumentsApiTests`:

```python
    def test_get_document_view_url_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.get_document_view_url",
            new=AsyncMock(return_value="https://fake-storage.example/doc-1.pdf?exp=123"),
        ) as mocked_view_url:
            response = self.client.get(
                "/api/rex/documind/documents/doc-1/view-url",
                params={"landlord_id": "landlord-1", "property_id": "property-1"},
            )

            call_kwargs = mocked_view_url.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["view_url"], "https://fake-storage.example/doc-1.pdf?exp=123")
        self.assertEqual(call_kwargs["landlord_id"], "landlord-1")
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["doc_id"], "doc-1")

    def test_get_document_view_url_returns_404_when_not_found(self):
        with patch(
            "api.rex_routes.documind_service.get_document_view_url",
            new=AsyncMock(side_effect=ValueError("Document doc-1 not found")),
        ):
            response = self.client.get(
                "/api/rex/documind/documents/doc-1/view-url",
                params={"landlord_id": "landlord-1", "property_id": "property-1"},
            )

        self.assertEqual(response.status_code, 404)

    def test_get_document_view_url_returns_422_without_required_query(self):
        response = self.client.get("/api/rex/documind/documents/doc-1/view-url")
        self.assertEqual(response.status_code, 422)
```

- [ ] **Step 10: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_docs_api.py -v`
Expected: all PASS, including the 3 new tests.

- [ ] **Step 11: Run the full backend suite and commit**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py tests/test_retriever.py tests/test_rex_routes_documind_docs_api.py -v`
Expected: same baseline as Task 1 Step 6, plus all new tests passing.

```bash
cd backend
git add rag/documind_service.py api/rex_routes.py tests/test_documind_service_flows.py tests/test_rex_routes_documind_docs_api.py
git commit -m "feat: add view-url endpoint and Storage cleanup on document delete"
```

---

### Task 3: Flutter — data/repository/usecase chain for fetching the view URL

**Files:**
- Modify: `residex_app/lib/core/constants/api_constants.dart`
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`
- Modify: `residex_app/lib/features/landlord/domain/repositories/documind_repository.dart`
- Modify: `residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart`
- Create: `residex_app/lib/features/landlord/domain/usecases/get_document_view_url.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`

**Interfaces:**
- Consumes: `Citation.docId` (existing entity field, `residex_app/lib/features/landlord/domain/entities/documind_document.dart:26`), `ApiConstants.baseUrl` (existing).
- Produces: `documindGetViewUrlActionProvider` — a Riverpod `Provider<Future<String> Function({required String propertyId, required String docId})>`, consumed by Task 5.

- [ ] **Step 1: Add the API constant**

In `residex_app/lib/core/constants/api_constants.dart`, add a new static field after `documindList`:

```dart
  static const String documindList = '/api/rex/documind/documents';
  static String documindViewUrl(String docId) => '/api/rex/documind/documents/$docId/view-url';
```

- [ ] **Step 2: Add the datasource method**

In `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`, add a new method at the end of the class, before the closing `}`:

```dart
  /// Get a short-lived signed URL to view a document's original PDF
  Future<String> getDocumentViewUrl({
    required String landlordId,
    required String propertyId,
    required String docId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindViewUrl(docId)}')
        .replace(queryParameters: {
      'landlord_id': landlordId,
      'property_id': propertyId,
    });

    final response = await httpClient.get(uri);

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      return jsonResponse['view_url'] as String;
    } else if (response.statusCode == 404) {
      throw DocumentNotFoundException(docId);
    } else {
      throw Exception('Failed to get view URL: ${response.body}');
    }
  }
}

/// Thrown when a cited document no longer exists (e.g. deleted, or predates
/// Storage-backed viewing).
class DocumentNotFoundException implements Exception {
  final String docId;
  const DocumentNotFoundException(this.docId);

  @override
  String toString() => 'Document $docId not found';
}
```

(Note: this replaces the file's final closing `}` — the new exception class is declared at file scope, after the class body.)

- [ ] **Step 3: Add the repository interface method**

In `residex_app/lib/features/landlord/domain/repositories/documind_repository.dart`, add to the abstract class, after `deleteDocument`:

```dart
  /// Get a short-lived signed URL to view a document's original PDF
  Future<String> getDocumentViewUrl({
    required String landlordId,
    required String propertyId,
    required String docId,
  });
```

- [ ] **Step 4: Implement the repository method**

In `residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart`, add to the class, after `deleteDocument`:

```dart
  @override
  Future<String> getDocumentViewUrl({
    required String landlordId,
    required String propertyId,
    required String docId,
  }) async {
    return await remoteDataSource.getDocumentViewUrl(
      landlordId: landlordId,
      propertyId: propertyId,
      docId: docId,
    );
  }
```

Note: this rethrows `DocumentNotFoundException` unchanged (no try/catch needed here) so callers can catch it specifically.

- [ ] **Step 5: Create the usecase**

Create `residex_app/lib/features/landlord/domain/usecases/get_document_view_url.dart`:

```dart
import '../repositories/documind_repository.dart';

/// Use case: get a short-lived signed URL to view a document's original PDF
class GetDocumentViewUrl {
  final DocuMindRepository repository;

  const GetDocumentViewUrl(this.repository);

  Future<String> call({
    required String landlordId,
    required String propertyId,
    required String docId,
  }) async {
    return await repository.getDocumentViewUrl(
      landlordId: landlordId,
      propertyId: propertyId,
      docId: docId,
    );
  }
}
```

- [ ] **Step 6: Wire the provider**

In `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`, add the import at the top:

```dart
import '../../domain/usecases/get_document_view_url.dart';
```

Add a use case provider after `listDocumentsUseCaseProvider` (around line 39):

```dart
final getDocumentViewUrlUseCaseProvider = Provider<GetDocumentViewUrl>((ref) {
  final repository = ref.watch(documindRepositoryProvider);
  return GetDocumentViewUrl(repository);
});
```

Add an action provider after `deleteDocumentActionProvider` (end of file):

```dart

final documindGetViewUrlActionProvider = Provider<
  Future<String> Function({
    required String propertyId,
    required String docId,
  })
>((ref) {
  return ({
    required String propertyId,
    required String docId,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final useCase = ref.read(getDocumentViewUrlUseCaseProvider);

    return await useCase(
      landlordId: landlordId,
      propertyId: propertyId,
      docId: docId,
    );
  };
});
```

- [ ] **Step 7: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/data/datasources/documind_remote_datasource.dart lib/features/landlord/domain/repositories/documind_repository.dart lib/features/landlord/data/repositories/documind_repository_impl.dart lib/features/landlord/domain/usecases/get_document_view_url.dart lib/features/landlord/presentation/providers/documind_provider.dart`
Expected: No errors (matches the project's 0-error baseline).

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/core/constants/api_constants.dart \
        residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart \
        residex_app/lib/features/landlord/domain/repositories/documind_repository.dart \
        residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart \
        residex_app/lib/features/landlord/domain/usecases/get_document_view_url.dart \
        residex_app/lib/features/landlord/presentation/providers/documind_provider.dart
git commit -m "feat: add data/repository/usecase chain for citation view-url"
```

---

### Task 4: Flutter — on-device PDF cache

**Files:**
- Create: `residex_app/lib/features/landlord/data/datasources/document_file_cache.dart`

**Interfaces:**
- Consumes: `path_provider` (`getApplicationDocumentsDirectory()`), `http` (existing package), `dart:io` (`File`).
- Produces: `DocumentFileCache.getOrDownload({required String docId, required Future<String> Function() fetchViewUrl}) -> Future<File>`, consumed by Task 5's `DocumentViewerScreen`.

- [ ] **Step 1: Create the cache class**

Create `residex_app/lib/features/landlord/data/datasources/document_file_cache.dart`:

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Caches downloaded citation PDFs on-device, keyed by doc_id, so repeat
/// views of the same document don't re-download from Storage.
class DocumentFileCache {
  final http.Client httpClient;

  DocumentFileCache({http.Client? httpClient}) : httpClient = httpClient ?? http.Client();

  Future<File> _cacheFileFor(String docId) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/documind_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/$docId.pdf');
  }

  /// Returns a cached local file for [docId] if one exists, otherwise calls
  /// [fetchViewUrl] to get a fresh signed URL, downloads it, caches it, and
  /// returns the resulting file.
  Future<File> getOrDownload({
    required String docId,
    required Future<String> Function() fetchViewUrl,
  }) async {
    final cacheFile = await _cacheFileFor(docId);

    if (await cacheFile.exists()) {
      return cacheFile;
    }

    final viewUrl = await fetchViewUrl();
    final response = await httpClient.get(Uri.parse(viewUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to download document: ${response.statusCode}');
    }

    await cacheFile.writeAsBytes(response.bodyBytes);
    return cacheFile;
  }
}
```

- [ ] **Step 2: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/data/datasources/document_file_cache.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add residex_app/lib/features/landlord/data/datasources/document_file_cache.dart
git commit -m "feat: add on-device file cache for citation source PDFs"
```

---

### Task 5: Flutter — DocumentViewerScreen + wiring the tap

**Files:**
- Add dependency: `residex_app/pubspec.yaml`
- Create: `residex_app/lib/features/landlord/presentation/screens/2-Documind/document_viewer_screen.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart:1139-1184` (`_buildCitationLine`)

**Interfaces:**
- Consumes: `documindGetViewUrlActionProvider` (Task 3), `DocumentFileCache` (Task 4), `Citation` entity (existing: `docId`, `filename`, `page`, `score`).
- Produces: `DocumentViewerScreen` widget, pushed via `Navigator.push` (not a named go_router route — this is a modal/pushed detail screen, not a tab destination, matching how e.g. dialogs are already pushed in this codebase).

- [ ] **Step 1: Add the PDF viewer dependency**

In `residex_app/pubspec.yaml`, add after `flutter_markdown: ^0.7.3` (line 71):

```yaml
  syncfusion_flutter_pdfviewer: ^30.1.37
```

Run: `cd residex_app && flutter pub get`
Expected: dependency resolves successfully.

- [ ] **Step 2: Verify the SfPdfViewer API before writing the screen**

The code below assumes `SfPdfViewer.file(file, controller:, onDocumentLoaded:)` and `PdfViewerController.jumpToPage(int)` exist with these exact names — based on general knowledge of `syncfusion_flutter_pdfviewer`, not confirmed against this project's installed copy (the package isn't in `pubspec.lock` until Step 1 runs). Before writing the screen, open the installed package source to confirm:

Run: `find "$USERPROFILE/AppData/Local/Pub/Cache/hosted/pub.dev" -maxdepth 1 -iname "syncfusion_flutter_pdfviewer-*"` (Windows/Git Bash) to locate the installed version, then check `lib/src/pdfviewer/pdfviewer.dart` (or search `lib/` for `class SfPdfViewer` and `class PdfViewerController`) for the actual constructor parameters and controller methods. If the names differ from what's used below, adjust the code in Step 3 accordingly — the intent (load a local file, jump to a 1-indexed page once loaded) stays the same regardless of exact API names.

- [ ] **Step 3: Create the viewer screen**

Create `residex_app/lib/features/landlord/presentation/screens/2-Documind/document_viewer_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/datasources/document_file_cache.dart';
import '../../../data/datasources/documind_remote_datasource.dart';
import '../../providers/documind_provider.dart';

/// Opens a cited source PDF, jumped to the page it was cited from.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String docId;
  final String filename;
  final int? page;

  const DocumentViewerScreen({
    super.key,
    required this.propertyId,
    required this.docId,
    required this.filename,
    this.page,
  });

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  final _cache = DocumentFileCache();
  final _controller = PdfViewerController();
  late final Future<File> _fileFuture;

  @override
  void initState() {
    super.initState();
    final getViewUrl = ref.read(documindGetViewUrlActionProvider);
    _fileFuture = _cache.getOrDownload(
      docId: widget.docId,
      fetchViewUrl: () => getViewUrl(propertyId: widget.propertyId, docId: widget.docId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(widget.filename, style: AppTextStyles.titleMedium, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.paper,
      ),
      body: FutureBuilder<File>(
        future: _fileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.registry));
          }

          if (snapshot.hasError) {
            final isNotFound = snapshot.error is DocumentNotFoundException;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isNotFound
                      ? 'This document is no longer available.'
                      : 'Could not load this document.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SfPdfViewer.file(
            snapshot.data!,
            controller: _controller,
            onDocumentLoaded: (_) {
              if (widget.page != null && widget.page! > 0) {
                _controller.jumpToPage(widget.page!);
              }
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/screens/2-Documind/document_viewer_screen.dart`
Expected: No errors.

- [ ] **Step 5: Wire the tap in _buildCitationLine**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, the current `_buildCitationLine` (lines 1139-1184) returns a bare `Padding`. Wrap it in a tap handler. Replace:

```dart
  Widget _buildCitationLine(Citation citation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
```

with:

```dart
  Widget _buildCitationLine(Citation citation) {
    return InkWell(
      onTap: () {
        if (_selectedPropertyId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              propertyId: _selectedPropertyId!,
              docId: citation.docId,
              filename: citation.filename,
              page: citation.page,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
```

And update the matching closing braces at the end of the method — the existing method ends with:

```dart
        ],
      ),
    );
  }
```

which becomes (one extra closing `)` for the added `Padding`, one extra closing `)` for `InkWell`):

```dart
          ],
        ),
      ),
    );
  }
```

Add the import at the top of `documind_screen.dart`, alongside the other local imports (near `import 'documind_chat_logic.dart';`):

```dart
import 'document_viewer_screen.dart';
```

- [ ] **Step 6: Run flutter analyze on the full app**

Run: `cd residex_app && flutter analyze`
Expected: 0 errors, same info-issue baseline as before this change (plus possibly a couple new info-level lints from the new file, which is fine — check there are no new errors or warnings specifically).

- [ ] **Step 7: Manual verification**

Start the backend (`cd backend && python main.py`) and run the app on the Android emulator (per `HANDOFF.md` run instructions). Upload a fresh PDF document, ask a question that returns a citation for it, tap the citation row, and confirm:
- The viewer opens and lands on the cited page.
- Tapping the same citation again (or the same document cited elsewhere) opens instantly (served from cache — no visible loading spinner delay on the second open).
- Deleting the document, then tapping a citation for it in existing chat history, shows "This document is no longer available" instead of crashing.

- [ ] **Step 8: Commit**

```bash
git add residex_app/pubspec.yaml residex_app/pubspec.lock \
        residex_app/lib/features/landlord/presentation/screens/2-Documind/document_viewer_screen.dart \
        residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart
git commit -m "feat: open cited source PDF at the cited page on citation tap"
```

---

## Self-Review Notes

- **Spec coverage:** Storage upload (Task 1) covered, view-url endpoint + delete cleanup (Task 2) covered, client fetch chain (Task 3) covered, on-device cache (Task 4) covered, viewer screen + tap wiring + error handling (Task 5) covered. PDF-only scope, no-backfill, no-retrieval-changes constraints are respected throughout (no DOCX handling added, no `_rerank`/dedup touched).
- **Type consistency:** `Citation.docId`/`filename`/`page` (Flutter) used consistently in Tasks 3-5 matches the existing entity in `documind_document.dart:26-31`. `get_document_view_url` (backend) and `getDocumentViewUrl` (Flutter datasource/repository/usecase) are named consistently across Tasks 2-3. `DocumentNotFoundException` defined in Task 3 Step 2 is referenced in Task 5 Step 2 — same name, same file origin.
- **No placeholders:** all steps contain complete, runnable code.
