from fastapi import APIRouter, UploadFile, File, Form, Query, HTTPException
from models.documind_models import DocUploadResponse, AskRequest, AskResponse, DocListResponse, UnassignUnitRequest, FinanceSummaryResponse, FactsUpdateRequest, FactsUpdateResponse, PaymentExceptionRequest, PaymentExceptionResponse, DocumentExceptionRequest, DocumentExceptionResponse
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
    Upload a document (PDF, or JPG/PNG photo) for a property.

    Category options: 'lease', 'insurance', 'loan', 'tax', 'upkeep',
    'maintenance', 'rental_invoice' (legacy names utility/receipt/warranty are
    accepted and stored under their new equivalents)

    unit_id/unit_label are optional: omit them for property-wide documents
    (insurance, tax, building warranty); set them to scope the document to a
    single unit (a lease). unit_label is denormalized for display.
    """
    try:
        return await documind_service.ingest_document(
            landlord_id=landlord_id,
            property_id=property_id,
            category=category,
            file=file,
            unit_id=unit_id,
            unit_label=unit_label,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/documind/documents/{doc_id}/facts", response_model=FactsUpdateResponse)
async def update_document_facts(doc_id: str, payload: FactsUpdateRequest):
    """
    Replace a document's reviewed expense lines (Expenses uploads).

    Subtypes are whitelist-validated server-side; a body with no valid
    line returns 400 and the stored facts stay untouched.
    """
    try:
        result = await documind_service.update_expense_lines(
            doc_id=doc_id,
            landlord_id=payload.landlord_id,
            lines=[line.model_dump() for line in payload.expense_lines],
        )
        return FactsUpdateResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


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
    Allowed categories: 'lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice'

    Examples:
    - categories=['upkeep'] -> search only upkeep documents
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


@router.get("/documind/finance/summary", response_model=FinanceSummaryResponse)
async def finance_summary(
    landlord_id: str = Query(..., description="Landlord ID"),
    year: int = Query(..., ge=2000, le=2100, description="Calendar year (YA)"),
):
    """
    Deterministic finance summary for one landlord and calendar year.

    Zero LLM: extracted facts are folded fresh on every request (compute-on-
    read). Statutory Rental Income is an estimate for the landlord's tax
    agent and always ships with its caveats.
    """
    return await documind_service.get_finance_summary(landlord_id, year)

@router.put("/documind/finance/payment-exception", response_model=PaymentExceptionResponse)
async def set_payment_exception(payload: PaymentExceptionRequest):
    """
    Mark one month as 'no payment received' for a property or unit scope.

    Excludes that month from Received Rent, Net P/L, and Statutory Rental
    Income; the month still counts as tenanted for expense proration.
    Idempotent — re-marking the same month overwrites the reason.
    """
    try:
        return await documind_service.set_payment_exception(
            landlord_id=payload.landlord_id,
            property_id=payload.property_id,
            unit_id=payload.unit_id,
            month=payload.month,
            reason=payload.reason,
            state=payload.state,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/payment-exception")
async def clear_payment_exception(
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
    property_id: str = Query(..., description="Property ID"),
    month: str = Query(..., description="Calendar month, YYYY-MM"),
    unit_id: str | None = Query(None, description="Unit ID; omit for a whole-property mark"),
):
    """
    Clear a 'no payment received' mark. Idempotent — clearing an unmarked
    month is a no-op, not an error.
    """
    return await documind_service.clear_payment_exception(
        landlord_id=landlord_id,
        property_id=property_id,
        unit_id=unit_id,
        month=month,
    )


@router.put("/documind/finance/document-exception", response_model=DocumentExceptionResponse)
async def set_document_unavailable(payload: DocumentExceptionRequest):
    """
    Acknowledge that a coverage gap cannot be filled for one (year, category).
    The year then settles as complete-with-gaps: no longer counted as
    'missing' in the coverage grid, and no longer blocks the statutory
    estimate. Idempotent — re-marking the same scope is a no-op.
    """
    try:
        return await documind_service.set_document_unavailable(
            landlord_id=payload.landlord_id,
            property_id=payload.property_id,
            year=payload.year,
            category=payload.category,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/document-exception")
async def clear_document_unavailable(
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
    property_id: str = Query(..., description="Property ID"),
    year: int = Query(..., ge=2000, le=2100),
    category: str = Query(..., description="The category or tax label previously marked unavailable"),
):
    """
    Clear an 'unavailable' mark. Idempotent — clearing an unmarked scope is
    a no-op, not an error.
    """
    return await documind_service.clear_document_unavailable(
        landlord_id=landlord_id, property_id=property_id, year=year, category=category,
    )


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


@router.post("/documind/documents/unassign-unit")
async def unassign_unit_documents(payload: UnassignUnitRequest):
    """
    Clear the unit assignment on all of a unit's documents and chunks,
    converting them to property-wide. Called before a unit is deleted so its
    documents don't keep a stale unit_id. Nothing is deleted; idempotent.

    Example:
        POST /api/rex/documind/documents/unassign-unit
        {"landlord_id": "landlord_456", "property_id": "property_789", "unit_id": "unit_9"}
    """
    return await documind_service.unassign_unit_documents(
        landlord_id=payload.landlord_id,
        property_id=payload.property_id,
        unit_id=payload.unit_id,
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