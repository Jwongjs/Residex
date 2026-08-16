import json
import unittest
from datetime import datetime
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from api.auth import verify_firebase_token
from models.documind_models import DocListResponse, DocUploadResponse, DocumentInfo


class DocuMindDocumentsApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        app.dependency_overrides[verify_firebase_token] = lambda: {"uid": "landlord_123"}

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_documind_upload_returns_200_and_calls_service(self):
        mocked_upload_response = DocUploadResponse(
            doc_id="doc-123",
            landlord_id="landlord-1",
            property_id="property-1",
            category="lease",
            filename="lease.pdf",
            status="indexed",
            chunks_indexed=12,
            extracted_facts={"monthly_rent": 1500.0, "lease_end": "2026-09-01"},
            facts_confidence=0.9,
        )

        with patch("api.rex_routes.documind_service.ingest_document", new=AsyncMock(return_value=mocked_upload_response)) as mocked_ingest:
            response = self.client.post(
                "/api/rex/documind/upload",
                data={
                    "property_id": "property-1",
                    "category": "lease",
                },
                files={"file": ("lease.pdf", b"%PDF-1.4 test content", "application/pdf")},
            )

            call_kwargs = mocked_ingest.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["doc_id"], "doc-123")
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not the wire value ("landlord-1") sent above
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["category"], "lease")
        self.assertEqual(call_kwargs["file"].filename, "lease.pdf")
        self.assertEqual(response.json()["extracted_facts"]["monthly_rent"], 1500.0)
        self.assertEqual(response.json()["facts_confidence"], 0.9)

    def test_documind_upload_stream_emits_stages_then_result(self):
        mocked_upload_response = DocUploadResponse(
            doc_id="doc-1",
            landlord_id="l1",
            property_id="p1",
            category="lease",
            filename="lease.pdf",
            status="indexed",
            chunks_indexed=3,
        )

        async def fake_ingest(*args, progress=None, **kwargs):
            for stage in ["received", "reading", "organising", "indexing", "details"]:
                progress(stage)
            return mocked_upload_response

        with patch("api.rex_routes.documind_service.ingest_document", new=AsyncMock(side_effect=fake_ingest)):
            response = self.client.post(
                "/api/rex/documind/upload/stream",
                data={"property_id": "p1", "category": "lease"},
                files={"file": ("lease.pdf", b"%PDF-1.4 x", "application/pdf")},
            )

        self.assertEqual(response.status_code, 200)
        lines = [json.loads(line) for line in response.text.splitlines() if line.strip()]
        self.assertEqual(
            [e["stage"] for e in lines if e["type"] == "stage"],
            ["received", "reading", "organising", "indexing", "details"],
        )
        result_events = [e for e in lines if e["type"] == "result"]
        self.assertEqual(len(result_events), 1)
        self.assertEqual(result_events[0]["result"]["doc_id"], "doc-1")
        self.assertEqual(result_events[0]["result"]["chunks_indexed"], 3)

    def test_documind_upload_stream_emits_error_on_failure(self):
        async def boom(*args, progress=None, **kwargs):
            raise ValueError("bad category")

        with patch("api.rex_routes.documind_service.ingest_document", new=AsyncMock(side_effect=boom)):
            response = self.client.post(
                "/api/rex/documind/upload/stream",
                data={"property_id": "p1", "category": "nope"},
                files={"file": ("x.pdf", b"%PDF-1.4 x", "application/pdf")},
            )

        self.assertEqual(response.status_code, 200)
        lines = [json.loads(line) for line in response.text.splitlines() if line.strip()]
        error_events = [e for e in lines if e["type"] == "error"]
        self.assertEqual(len(error_events), 1)
        self.assertIn("bad category", error_events[0]["message"])

    def test_documind_upload_returns_422_when_missing_file(self):
        response = self.client.post(
            "/api/rex/documind/upload",
            data={
                "property_id": "property-1",
                "category": "warranty",
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_list_documents_returns_200_and_forwards_filters(self):
        mocked_list_response = DocListResponse(
            documents=[
                DocumentInfo(
                    doc_id="doc-1",
                    landlord_id="landlord-1",
                    property_id="property-1",
                    category="lease",
                    filename="lease.pdf",
                    uploaded_at=datetime(2026, 3, 18, 12, 0, 0),
                    chunks_indexed=5,
                    file_size=1024,
                )
            ],
            total_count=1,
            filtered_by_property="property-1",
        )

        with patch("api.rex_routes.documind_service.list_documents", new=AsyncMock(return_value=mocked_list_response)) as mocked_list:
            response = self.client.get(
                "/api/rex/documind/documents",
                params={
                    "property_id": "property-1",
                },
            )

            call_args = mocked_list.await_args.args

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["total_count"], 1)
        self.assertEqual(payload["documents"][0]["filename"], "lease.pdf")
        self.assertEqual(call_args[0], "landlord_123")  # token uid, not the wire value ("landlord-1") sent above
        self.assertEqual(call_args[1], "property-1")

    def test_list_documents_succeeds_without_landlord_id_query_param(self):
        # landlord_id is no longer a client-supplied query param — it comes
        # from the authenticated token (see Depends(current_landlord_id)),
        # so omitting it from the query string is no longer a 422; the
        # authenticated (overridden) identity is used instead.
        with patch(
            "api.rex_routes.documind_service.list_documents",
            new=AsyncMock(return_value=DocListResponse(documents=[], total_count=0)),
        ) as mocked_list:
            response = self.client.get("/api/rex/documind/documents")
            call_args = mocked_list.await_args.args

        self.assertEqual(response.status_code, 200)
        self.assertEqual(call_args[0], "landlord_123")

    def test_delete_document_returns_200_and_calls_service(self):
        with patch(
            "api.rex_routes.documind_service.delete_document",
            new=AsyncMock(
                return_value={
                    "message": "Document deleted successfully",
                    "doc_id": "doc-1",
                    "filename": "lease.pdf",
                    "chunks_deleted": 3,
                }
            ),
        ) as mocked_delete:
            response = self.client.delete(
                "/api/rex/documind/documents/doc-1",
                params={"property_id": "property-1"},
            )

            call_kwargs = mocked_delete.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["doc_id"], "doc-1")
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not the wire value ("landlord-1") sent above
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["doc_id"], "doc-1")

    def test_delete_document_returns_422_without_required_query(self):
        response = self.client.delete("/api/rex/documind/documents/doc-1")
        self.assertEqual(response.status_code, 422)

    def test_rename_document_returns_200_and_calls_service(self):
        with patch(
            "api.rex_routes.documind_service.rename_document",
            new=AsyncMock(return_value={"doc_id": "doc-1", "filename": "Ayer 8 lease 2023.pdf"}),
        ) as mocked_rename:
            response = self.client.patch(
                "/api/rex/documind/documents/doc-1/filename",
                json={"filename": "Ayer 8 lease 2023.pdf"},
            )
            call_kwargs = mocked_rename.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["filename"], "Ayer 8 lease 2023.pdf")
        self.assertEqual(call_kwargs["doc_id"], "doc-1")
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not the wire value ("landlord-1") sent above
        self.assertEqual(call_kwargs["filename"], "Ayer 8 lease 2023.pdf")

    def test_rename_document_returns_400_on_invalid_name(self):
        with patch(
            "api.rex_routes.documind_service.rename_document",
            new=AsyncMock(side_effect=ValueError("Filename cannot be empty.")),
        ):
            response = self.client.patch(
                "/api/rex/documind/documents/doc-1/filename",
                json={"filename": "   "},
            )
        self.assertEqual(response.status_code, 400)

    def test_set_share_basis_returns_200_and_calls_service(self):
        with patch(
            "api.rex_routes.documind_service.set_document_share_basis",
            new=AsyncMock(return_value={"doc_id": "doc-1", "share_basis": "mine"}),
        ) as mocked:
            response = self.client.patch(
                "/api/rex/documind/documents/doc-1/share-basis",
                json={"share_basis": "mine"},
            )
            call_kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["share_basis"], "mine")
        self.assertEqual(call_kwargs["doc_id"], "doc-1")
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not any wire value
        self.assertEqual(call_kwargs["share_basis"], "mine")

    def test_set_share_basis_returns_400_on_an_unknown_value(self):
        with patch(
            "api.rex_routes.documind_service.set_document_share_basis",
            new=AsyncMock(side_effect=ValueError("Unknown share basis.")),
        ):
            response = self.client.patch(
                "/api/rex/documind/documents/doc-1/share-basis",
                json={"share_basis": "sometimes"},
            )
        self.assertEqual(response.status_code, 400)

    def test_get_document_view_url_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.get_document_view_url",
            new=AsyncMock(return_value="https://fake-storage.example/doc-1.pdf?exp=123"),
        ) as mocked_view_url:
            response = self.client.get(
                "/api/rex/documind/documents/doc-1/view-url",
                params={"property_id": "property-1"},
            )

            call_kwargs = mocked_view_url.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["view_url"], "https://fake-storage.example/doc-1.pdf?exp=123")
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not the wire value ("landlord-1") sent above
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["doc_id"], "doc-1")

    def test_get_document_view_url_returns_404_when_not_found(self):
        with patch(
            "api.rex_routes.documind_service.get_document_view_url",
            new=AsyncMock(side_effect=ValueError("Document doc-1 not found")),
        ):
            response = self.client.get(
                "/api/rex/documind/documents/doc-1/view-url",
                params={"property_id": "property-1"},
            )

        self.assertEqual(response.status_code, 404)

    def test_get_document_view_url_returns_422_without_required_query(self):
        response = self.client.get("/api/rex/documind/documents/doc-1/view-url")
        self.assertEqual(response.status_code, 422)

    def test_unassign_unit_documents_returns_200_and_calls_service(self):
        with patch(
            "api.rex_routes.documind_service.unassign_unit_documents",
            new=AsyncMock(return_value={
                "message": "Unit documents unassigned",
                "unit_id": "unit-9",
                "documents_updated": 2,
                "chunks_updated": 7,
            }),
        ) as mocked_unassign:
            response = self.client.post(
                "/api/rex/documind/documents/unassign-unit",
                json={
                    "property_id": "property-1",
                    "unit_id": "unit-9",
                },
            )

            call_kwargs = mocked_unassign.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["documents_updated"], 2)
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not the wire value ("landlord-1") sent above
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["unit_id"], "unit-9")

    def test_unassign_unit_documents_returns_422_when_missing_fields(self):
        response = self.client.post(
            "/api/rex/documind/documents/unassign-unit",
            json={},
        )
        self.assertEqual(response.status_code, 422)

    def test_list_documents_without_token_is_401(self):
        # A fresh client with no auth override installed.
        from main import app
        from fastapi.testclient import TestClient
        app.dependency_overrides.clear()   # exercise the REAL auth dependency, not the override
        bare = TestClient(app)
        r = bare.get("/api/rex/documind/documents?property_id=p1")
        assert r.status_code == 401
        assert r.json()["detail"]["code"] == "token_missing"


if __name__ == "__main__":
    unittest.main()