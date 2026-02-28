from fastapi import APIRouter, UploadFile, File, Form, Query
from models.lease_models import LeaseGenerateRequest, LeaseGenerateResponse
from models.documind_models import DocUploadResponse, AskRequest, AskResponse, DocListResponse
from agents.lease_generator import generate_lease
from rag.documind_service import documind_service

router = APIRouter(prefix="/api/rex", tags=["rex-ai"])

# ========== LEASE GENERATOR ROUTES ==========

@router.post("/lease/generate", response_model=LeaseGenerateResponse)
async def lease_generate(payload: LeaseGenerateRequest):
    return await generate_lease(payload)


# ========== DOCUMIND ROUTES ==========

@router.post("/documind/upload", response_model=DocUploadResponse)
async def documind_upload(
    landlord_id: str = Form(...),
    property_id: str = Form(...),
    category: str = Form(...),
    file: UploadFile = File(...)
):
    """
    Upload a PDF document for a property.
    
    Category options: 'lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'
    """
    return await documind_service.ingest_document(
        landlord_id=landlord_id,
        property_id=property_id,
        category=category,
        file=file
    )


@router.post("/documind/ask", response_model=AskResponse)
async def documind_ask(payload: AskRequest):
    """
    Ask a question about documents for a specific property.
    
    Uses Firestore Vector Search to find relevant chunks.
    """
    return await documind_service.ask_documind(payload)


@router.get("/documind/documents", response_model=DocListResponse)
async def list_documents(
    landlord_id: str = Query(..., description="Landlord ID"),
    property_id: str | None = Query(None, description="Filter by property ID")
):
    """
    List all documents for a landlord, optionally filtered by property.
    
    Examples:
    - GET /api/rex/documind/documents?landlord_id=landlord_123
      → Returns ALL documents across all properties
    
    - GET /api/rex/documind/documents?landlord_id=landlord_123&property_id=property_1
      → Returns documents for specific property only
    """
    return await documind_service.list_documents(landlord_id, property_id)

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