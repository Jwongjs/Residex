from fastapi import APIRouter, UploadFile, File, Form, Query, HTTPException
from models.documind_models import DocUploadResponse, AskRequest, AskResponse, DocListResponse
from rag.documind_service import documind_service

router = APIRouter(prefix="/api/rex", tags=["rex-ai"])

# ========== DOCUMIND ROUTES ==========

@router.post("/documind/upload", response_model=DocUploadResponse)
async def documind_upload(
    landlord_id: str = Form(...),
    property_id: str = Form(...),
    category: str = Form(...),
    file: UploadFile = File(...),
    unit_id: str | None = Form(None),
    unit_label: str | None = Form(None),
):
    """
    Upload a PDF document for a property.

    Category options: 'lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'

    unit_id/unit_label are optional: omit them for property-wide documents
    (insurance, tax, building warranty); set them to scope the document to a
    single unit (a lease). unit_label is denormalized for display.
    """
    return await documind_service.ingest_document(
        landlord_id=landlord_id,
        property_id=property_id,
        category=category,
        file=file,
        unit_id=unit_id,
        unit_label=unit_label,
    )


@router.post("/documind/ask", response_model=AskResponse)
async def documind_ask(payload: AskRequest):
    """
    Ask a question about documents for a specific property.

    Uses LangGraph-orchestrated DocuMind flow with Firestore Vector Search.

    Flow highlights:
    - Random/greeting input -> purpose redirect response
    - Valid doc question without explicit category -> predicted category + confirmation checkpoint
    - Follow-up actions supported through `session_id` + `user_action`:
      - confirm
      - cancel
      - override:<category>

    Optional category filtering is supported via `payload.categories`.
    Allowed categories: 'lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'

    Examples:
    - categories=['warranty'] -> search only warranty documents
    - categories=['lease', 'insurance'] -> search across selected categories
    - categories omitted/null -> orchestration predicts categories and may request user confirmation
    - session_id provided -> continues prior conversation memory
    - user_action='confirm' -> executes previously suggested category action
    """
    return await documind_service.ask_documind(payload)


@router.get("/documind/documents", response_model=DocListResponse)
async def list_documents(
    landlord_id: str = Query(..., description="Landlord ID"),
    property_id: str | None = Query(None, description="Filter by property ID"),
    unit_id: str | None = Query(
        None,
        description="Filter by unit: returns this unit's documents plus property-wide documents",
    ),
):
    """
    List all documents for a landlord, optionally filtered by property and unit.

    Examples:
    - GET /api/rex/documind/documents?landlord_id=landlord_123
      → Returns ALL documents across all properties

    - GET /api/rex/documind/documents?landlord_id=landlord_123&property_id=property_1
      → Returns documents for specific property only

    - GET /api/rex/documind/documents?landlord_id=landlord_123&property_id=property_1&unit_id=unit_9
      → Returns unit_9's documents plus property-wide documents
    """
    return await documind_service.list_documents(landlord_id, property_id, unit_id)

@router.delete("/documind/documents/{doc_id}")
async def delete_document(
    doc_id: str,
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
    property_id: str = Query(..., description="Property ID for scoping"),
):
    """
    Delete a document and its associated chunks from Firestore.
    
    Security:
    - Validates landlord owns the document
    - Validates document belongs to property
    - Deletes from both 'documind_docs' and 'documind_chunks' collections
    
    Args:
        doc_id: Document ID to delete
        landlord_id: Landlord ID (validates ownership)
        property_id: Property ID (validates scoping)
    
    Returns:
        Success message with deletion count
    
    Example:
        DELETE /api/rex/documind/documents/abc123?landlord_id=landlord_456&property_id=property_789
    """
    return await documind_service.delete_document(
        landlord_id=landlord_id,
        property_id=property_id,
        doc_id=doc_id,
    )


@router.delete("/documind/properties/{property_id}/documents")
async def delete_property_documents(
    property_id: str,
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
):
    """
    Delete ALL documents for a property (metadata, chunks, stored PDFs).

    Used by the property-deletion cascade in the app. Idempotent — a property
    with no documents returns a zero-count success.

    Example:
        DELETE /api/rex/documind/properties/property_789/documents?landlord_id=landlord_456
    """
    return await documind_service.delete_documents_for_property(
        landlord_id=landlord_id,
        property_id=property_id,
    )


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