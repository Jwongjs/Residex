from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from models.documind_models import DocListResponse, DocumentInfo, DocumentTag
from rag.categories import facts_status_for, normalize_category
from rag.fact_extractor import validate_expense_lines
from rag.finance_engine import document_tags


class DocumentLifecycleService:
    """Document metadata lifecycle: listing, deletion, renaming, unit
    reassignment, expense-line edits, and signed view URLs. Distinct from
    ingestion (which creates a document) and ask (which reads chunks)."""

    def __init__(self, db, storage_bucket_getter):
        self._db = db
        self._storage_bucket_getter = storage_bucket_getter

    async def update_expense_lines(
        self, doc_id: str, landlord_id: str, lines: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Replace a document's expense_lines after user review. Validation
        reuses the extractor whitelist, so the API can never store a subtype
        the finance engine doesn't understand."""
        cleaned = validate_expense_lines(lines)
        if not cleaned:
            raise ValueError(
                "No valid expense lines. Each line needs a known subtype and an amount."
            )
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise ValueError("Document not found.")
        data = snapshot.to_dict() or {}
        if data.get("landlord_id") != landlord_id:
            raise ValueError("Document not found.")
        facts = dict(data.get("extracted_facts") or {})
        facts["expense_lines"] = cleaned
        doc_ref.update({
            "extracted_facts": facts,
            "facts_extracted_at": firestore.SERVER_TIMESTAMP,
        })
        return {"doc_id": doc_id, "extracted_facts": facts}

    async def rename_document(
        self, doc_id: str, landlord_id: str, filename: str
    ) -> Dict[str, Any]:
        """Rename a document's display filename. Ownership-scoped: a doc that
        isn't the landlord's is reported as not found, never renamed. The
        stored file, chunks' text and embeddings are untouched — only the
        label changes, including on the chunks so citations show the new name."""
        cleaned = (filename or "").strip()
        if not cleaned:
            raise ValueError("Filename cannot be empty.")
        if len(cleaned) > 200:
            raise ValueError("Filename is too long (200 characters max).")
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise ValueError("Document not found.")
        data = snapshot.to_dict() or {}
        if data.get("landlord_id") != landlord_id:
            raise ValueError("Document not found.")
        doc_ref.update({"filename": cleaned})

        # Keep chunk filenames in sync so RAG citations show the new label.
        chunks_query = self._db.collection('documind_chunks').where(
            filter=FieldFilter('doc_id', '==', doc_id)
        )
        batch = self._db.batch()
        for chunk_doc in chunks_query.stream():
            batch.update(chunk_doc.reference, {"filename": cleaned})
        batch.commit()

        return {"doc_id": doc_id, "filename": cleaned}

    async def list_documents(
        self,
        landlord_id: str,
        property_id: Optional[str] = None,
        unit_id: Optional[str] = None,
    ) -> DocListResponse:
        """
        List documents from Firestore metadata collection.

        Args:
            landlord_id: Filter by landlord
            property_id: Optional filter by specific property
            unit_id: Optional unit filter — matches documents assigned to
                this unit plus property-wide documents. Applied as a Python
                post-filter because docs uploaded before units existed have
                no unit_id field, which a Firestore where-clause can never
                match.

        Returns:
            DocListResponse with documents array, total_count
        """
        query = self._db.collection('documind_docs').where(filter=FieldFilter('landlord_id', '==', landlord_id))

        if property_id:
            query = query.where(filter=FieldFilter('property_id', '==', property_id))

        docs = query.stream()

        documents = []
        for doc in docs:
            data = doc.to_dict()

            if unit_id and data.get('unit_id') not in (None, unit_id):
                continue

            # Convert Firestore Timestamp to datetime
            uploaded_at = data.get('uploaded_at')
            if isinstance(uploaded_at, firestore.SERVER_TIMESTAMP.__class__):
                uploaded_at = datetime.now()
            elif hasattr(uploaded_at, 'to_pydantic'):
                uploaded_at = uploaded_at.to_pydantic()

            category = normalize_category(data.get('category'))
            documents.append(DocumentInfo(
                doc_id=doc.id,
                landlord_id=data.get('landlord_id'),
                property_id=data.get('property_id'),
                category=category,
                filename=data.get('filename'),
                uploaded_at=uploaded_at,
                chunks_indexed=data.get('chunks_indexed'),
                file_size=data.get('file_size'),
                unit_id=data.get('unit_id'),
                unit_label=data.get('unit_label'),
                extracted_facts=data.get('extracted_facts'),
                facts_confidence=data.get('facts_confidence'),
                facts_status=facts_status_for(data.get('extracted_facts')),
                tags=[DocumentTag(**t) for t in document_tags(category, data.get('extracted_facts'))],
            ))

        print(f"✅ Listed {len(documents)} documents")

        return DocListResponse(
            documents=documents,
            total_count=len(documents),
            filtered_by_property=property_id
        )

    async def delete_document(
        self,
        landlord_id: str,
        property_id: str,
        doc_id: str
    ) -> dict:
        """
        Delete a document and all its chunks from Firestore.

        Security:
        - Verifies landlord owns the document
        - Verifies document belongs to property
        - Cascades deletion to all chunks

        Args:
            landlord_id: Landlord ID for ownership verification
            property_id: Property ID for scoping
            doc_id: Document ID to delete

        Returns:
            dict with deletion summary

        Raises:
            ValueError: If document not found or ownership mismatch
        """
        print(f"🔵 DocuMind: Delete document {doc_id}")
        print(f"   - Landlord: {landlord_id}")
        print(f"   - Property: {property_id}")

        # Step 1: Verify document exists and ownership
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        doc_snapshot = doc_ref.get()

        if not doc_snapshot.exists:
            raise ValueError(f"Document {doc_id} not found")

        doc_data = doc_snapshot.to_dict()

        # Step 2: Validate ownership
        if doc_data.get('landlord_id') != landlord_id:
            raise ValueError(f"Document {doc_id} does not belong to landlord {landlord_id}")

        if doc_data.get('property_id') != property_id:
            raise ValueError(f"Document {doc_id} does not belong to property {property_id}")

        # Step 3: Delete all chunks associated with this document
        chunks_ref = self._db.collection('documind_chunks')
        chunks_query = chunks_ref.where(filter=FieldFilter('doc_id', '==', doc_id))
        chunks_to_delete = chunks_query.stream()

        deleted_chunks_count = 0
        batch = self._db.batch()

        for chunk_doc in chunks_to_delete:
            batch.delete(chunk_doc.reference)
            deleted_chunks_count += 1

        # Commit chunk deletions
        if deleted_chunks_count > 0:
            batch.commit()
            print(f"✅ Deleted {deleted_chunks_count} chunks")

        # Step 3.5: Delete the original file from Storage, if one exists
        storage_path = doc_data.get('storage_path')
        if storage_path:
            try:
                self._storage_bucket_getter().blob(storage_path).delete()
                print(f"Deleted storage object {storage_path}")
            except Exception as e:
                print(f"Warning: could not delete storage object {storage_path}: {e}")

        # Step 4: Delete document metadata
        doc_ref.delete()
        print(f"✅ Deleted document {doc_id}")

        return {
            "message": "Document deleted successfully",
            "doc_id": doc_id,
            "filename": doc_data.get('filename', 'Unknown'),
            "chunks_deleted": deleted_chunks_count,
        }

    async def delete_documents_for_property(
        self,
        landlord_id: str,
        property_id: str,
    ) -> dict:
        """
        Delete ALL documents (metadata + chunks + stored PDFs) for a property.

        Used by the property-deletion cascade in the app. Idempotent: a
        property with no documents returns a zero-count success.
        """
        print(f"🔵 DocuMind: Delete all documents for property {property_id}")

        docs_query = (
            self._db.collection('documind_docs')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
        )

        documents_deleted = 0
        chunks_deleted = 0
        for doc_snapshot in docs_query.stream():
            result = await self.delete_document(
                landlord_id=landlord_id,
                property_id=property_id,
                doc_id=doc_snapshot.id,
            )
            documents_deleted += 1
            chunks_deleted += result.get('chunks_deleted', 0)

        print(f"✅ Deleted {documents_deleted} documents / {chunks_deleted} chunks for property {property_id}")

        return {
            "message": "Property documents deleted",
            "property_id": property_id,
            "documents_deleted": documents_deleted,
            "chunks_deleted": chunks_deleted,
        }

    async def unassign_unit_documents(
        self,
        landlord_id: str,
        property_id: str,
        unit_id: str,
    ) -> dict:
        """
        Clear the unit assignment on every doc + chunk scoped to a unit,
        converting them to property-wide documents.

        Called by the app before deleting a unit so its documents are
        unassigned rather than orphaned with a stale unit_id. Idempotent: a
        unit with no assigned documents returns zero counts. A single batch
        is fine at this scale (Firestore's 500-op batch limit).
        """
        print(f"🔵 DocuMind: Unassign unit {unit_id} documents for property {property_id}")

        batch = self._db.batch()
        documents_updated = 0
        chunks_updated = 0

        docs_query = (
            self._db.collection('documind_docs')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in docs_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            documents_updated += 1

        chunks_query = (
            self._db.collection('documind_chunks')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in chunks_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            chunks_updated += 1

        if documents_updated or chunks_updated:
            batch.commit()

        print(f"✅ Unassigned {documents_updated} docs / {chunks_updated} chunks from unit {unit_id}")

        return {
            "message": "Unit documents unassigned",
            "unit_id": unit_id,
            "documents_updated": documents_updated,
            "chunks_updated": chunks_updated,
        }

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
        doc_ref = self._db.collection('documind_docs').document(doc_id)
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

        blob = self._storage_bucket_getter().blob(storage_path)
        return blob.generate_signed_url(expiration=timedelta(minutes=10), method="GET")
