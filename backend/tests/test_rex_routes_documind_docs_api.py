import unittest
from datetime import datetime
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app
from models.documind_models import DocListResponse, DocUploadResponse, DocumentInfo


class DocuMindDocumentsApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_documind_upload_returns_200_and_calls_service(self):
        mocked_upload_response = DocUploadResponse(
            doc_id="doc-123",
            landlord_id="landlord-1",
            property_id="property-1",
            category="warranty",
            filename="warranty.pdf",
            status="indexed",
            chunks_indexed=12,
        )

        with patch("api.rex_routes.documind_service.ingest_document", new=AsyncMock(return_value=mocked_upload_response)) as mocked_ingest:
            response = self.client.post(
                "/api/rex/documind/upload",
                data={
                    "landlord_id": "landlord-1",
                    "property_id": "property-1",
                    "category": "warranty",
                },
                files={"file": ("warranty.pdf", b"%PDF-1.4 test content", "application/pdf")},
            )

            call_kwargs = mocked_ingest.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["doc_id"], "doc-123")
        self.assertEqual(call_kwargs["landlord_id"], "landlord-1")
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["category"], "warranty")
        self.assertEqual(call_kwargs["file"].filename, "warranty.pdf")

    def test_documind_upload_returns_422_when_missing_file(self):
        response = self.client.post(
            "/api/rex/documind/upload",
            data={
                "landlord_id": "landlord-1",
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
                    "landlord_id": "landlord-1",
                    "property_id": "property-1",
                },
            )

            call_args = mocked_list.await_args.args

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["total_count"], 1)
        self.assertEqual(payload["documents"][0]["filename"], "lease.pdf")
        self.assertEqual(call_args[0], "landlord-1")
        self.assertEqual(call_args[1], "property-1")

    def test_list_documents_returns_422_without_landlord_id(self):
        response = self.client.get("/api/rex/documind/documents")
        self.assertEqual(response.status_code, 422)

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
                params={"landlord_id": "landlord-1", "property_id": "property-1"},
            )

            call_kwargs = mocked_delete.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["doc_id"], "doc-1")
        self.assertEqual(call_kwargs["landlord_id"], "landlord-1")
        self.assertEqual(call_kwargs["property_id"], "property-1")
        self.assertEqual(call_kwargs["doc_id"], "doc-1")

    def test_delete_document_returns_422_without_required_query(self):
        response = self.client.delete("/api/rex/documind/documents/doc-1")
        self.assertEqual(response.status_code, 422)

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


if __name__ == "__main__":
    unittest.main()