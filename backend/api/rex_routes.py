import asyncio
import json

from fastapi import APIRouter, UploadFile, File, Form, Query, HTTPException, Depends
from fastapi.responses import StreamingResponse
from api.auth import verify_firebase_token, current_landlord_id
from models.documind_models import DocUploadResponse, AskRequest, AskResponse, DocListResponse, UnassignUnitRequest, FinanceSummaryResponse, FactsUpdateRequest, FactsUpdateResponse, DocumentRenameRequest, DocumentRenameResponse, ShareBasisUpdateRequest, ShareBasisUpdateResponse, PaymentExceptionRequest, PaymentExceptionResponse, DocumentExceptionRequest, DocumentExceptionResponse, RentRecoveryRequest, RentRecoveryResponse, ManualLoanEntryRequest, ManualLoanEntryResponse, ManualLoanEntryListResponse, UnitLoanExemptionRequest
from rag.documind_service import documind_service

router = APIRouter(
    prefix="/api/rex",
    tags=["rex-ai"],
    dependencies=[Depends(verify_firebase_token)],
)

# ========== DOCUMIND ROUTES ==========

@router.post("/documind/upload", response_model=DocUploadResponse)
async def documind_upload(
    property_id: str = Form(...),
    category: str = Form(...),
    file: UploadFile = File(...),
    unit_id: str | None = Form(None),
    unit_label: str | None = Form(None),
    landlord_id: str = Depends(current_landlord_id),
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


@router.post("/documind/upload/stream")
async def documind_upload_stream(
    property_id: str = Form(...),
    category: str = Form(...),
    file: UploadFile = File(...),
    unit_id: str | None = Form(None),
    unit_label: str | None = Form(None),
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Same as /documind/upload but streams newline-delimited JSON progress
    events as the ingestion pipeline runs, then a final result (or error)
    event. Media type application/x-ndjson.
    """
    queue: asyncio.Queue = asyncio.Queue()

    async def run() -> None:
        def progress(stage: str) -> None:
            queue.put_nowait({"type": "stage", "stage": stage})

        try:
            result = await documind_service.ingest_document(
                landlord_id=landlord_id,
                property_id=property_id,
                category=category,
                file=file,
                unit_id=unit_id,
                unit_label=unit_label,
                progress=progress,
            )
            queue.put_nowait({"type": "result", "result": result.model_dump(mode="json")})
        except Exception as e:  # noqa: BLE001 - surfaced to the client as an error event
            queue.put_nowait({"type": "error", "message": str(e)})
        finally:
            queue.put_nowait(None)

    async def stream():
        task = asyncio.create_task(run())
        try:
            while True:
                event = await queue.get()
                if event is None:
                    break
                yield json.dumps(event) + "\n"
        finally:
            await task

    return StreamingResponse(stream(), media_type="application/x-ndjson")


@router.patch("/documind/documents/{doc_id}/facts", response_model=FactsUpdateResponse)
async def update_document_facts(
    doc_id: str,
    payload: FactsUpdateRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Replace a document's reviewed expense lines (Expenses uploads).

    Subtypes are whitelist-validated server-side; a body with no valid
    line returns 400 and the stored facts stay untouched.
    """
    try:
        result = await documind_service.update_expense_lines(
            doc_id=doc_id,
            landlord_id=landlord_id,
            lines=[line.model_dump() for line in payload.expense_lines],
        )
        return FactsUpdateResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/documind/documents/{doc_id}/filename", response_model=DocumentRenameResponse)
async def rename_document(
    doc_id: str,
    payload: DocumentRenameRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Rename a document's display filename (ownership-scoped).

    A blank or over-long name returns 400; a doc that isn't the landlord's is
    reported as not found. Only the label changes — the stored file and its
    indexed chunks' text are untouched (chunk filenames are re-synced so
    citations show the new name).
    """
    try:
        result = await documind_service.rename_document(
            doc_id=doc_id,
            landlord_id=landlord_id,
            filename=payload.filename,
        )
        return DocumentRenameResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/documind/documents/{doc_id}/share-basis",
              response_model=ShareBasisUpdateResponse)
async def set_document_share_basis(
    doc_id: str,
    payload: ShareBasisUpdateRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Record whether this document states the whole property's figures ('full')
    or is already split to the landlord's share ('mine').

    Any other value returns 400 and the stored document is untouched; a doc
    that isn't the landlord's is reported as not found.
    """
    try:
        result = await documind_service.set_document_share_basis(
            doc_id=doc_id,
            landlord_id=landlord_id,
            share_basis=payload.share_basis,
        )
        return ShareBasisUpdateResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/documind/ask", response_model=AskResponse)
async def documind_ask(payload: AskRequest, landlord_id: str = Depends(current_landlord_id)):
    """
    Ask a question about documents for a specific property.

    Uses LangGraph-orchestrated DocuMind flow with Firestore Vector Search.

    Flow highlights:
    - Random/greeting input -> purpose redirect response
    - Valid doc question without explicit category -> predicted categories scope the search
      when confident; otherwise the whole corpus is searched
    - Finance question -> computed by the finance engine, narrated by the LLM

    Optional category filtering is supported via `payload.categories`.
    Allowed categories: 'lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice'

    Examples:
    - categories=['upkeep'] -> search only upkeep documents
    - categories=['lease', 'insurance'] -> search across selected categories
    - categories omitted/null -> orchestration predicts categories
    - session_id provided -> continues prior conversation memory
    - unit_id provided -> scopes the search to that unit plus property-wide documents
    """
    return await documind_service.ask_documind(payload, landlord_id)


@router.get("/documind/documents", response_model=DocListResponse)
async def list_documents(
    property_id: str | None = Query(None, description="Filter by property ID"),
    unit_id: str | None = Query(
        None,
        description="Filter by unit: returns this unit's documents plus property-wide documents",
    ),
    landlord_id: str = Depends(current_landlord_id),
):
    """
    List all documents for a landlord, optionally filtered by property and unit.

    Examples:
    - GET /api/rex/documind/documents
      → Returns ALL documents across all properties

    - GET /api/rex/documind/documents?property_id=property_1
      → Returns documents for specific property only

    - GET /api/rex/documind/documents?property_id=property_1&unit_id=unit_9
      → Returns unit_9's documents plus property-wide documents
    """
    return await documind_service.list_documents(landlord_id, property_id, unit_id)


@router.get("/documind/finance/summary", response_model=FinanceSummaryResponse)
async def finance_summary(
    year: int = Query(..., ge=2000, le=2100, description="Calendar year (YA)"),
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Deterministic finance summary for one landlord and calendar year.

    Zero LLM: extracted facts are folded fresh on every request (compute-on-
    read). Statutory Rental Income is an estimate for the landlord's tax
    agent and always ships with its caveats.
    """
    return await documind_service.get_finance_summary(landlord_id, year)

@router.put("/documind/finance/payment-exception", response_model=PaymentExceptionResponse)
async def set_payment_exception(
    payload: PaymentExceptionRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Mark one month as 'no payment received' for a property or unit scope.

    Excludes that month from Received Rent, Net P/L, and Statutory Rental
    Income; the month still counts as tenanted for expense proration.
    Idempotent — re-marking the same month overwrites the reason.
    """
    try:
        return await documind_service.set_payment_exception(
            landlord_id=landlord_id,
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
    property_id: str = Query(..., description="Property ID"),
    month: str = Query(..., description="Calendar month, YYYY-MM"),
    unit_id: str | None = Query(None, description="Unit ID; omit for a whole-property mark"),
    landlord_id: str = Depends(current_landlord_id),
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
async def set_document_unavailable(
    payload: DocumentExceptionRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Acknowledge that a coverage gap cannot be filled for one (year, category).
    The year then settles as complete-with-gaps: no longer counted as
    'missing' in the coverage grid, and no longer blocks the statutory
    estimate. Idempotent — re-marking the same scope is a no-op.
    """
    try:
        return await documind_service.set_document_unavailable(
            landlord_id=landlord_id,
            property_id=payload.property_id,
            year=payload.year,
            category=payload.category,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/document-exception")
async def clear_document_unavailable(
    property_id: str = Query(..., description="Property ID"),
    year: int = Query(..., ge=2000, le=2100),
    category: str = Query(..., description="The category or tax label previously marked unavailable"),
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Clear an 'unavailable' mark. Idempotent — clearing an unmarked scope is
    a no-op, not an error.
    """
    return await documind_service.clear_document_unavailable(
        landlord_id=landlord_id, property_id=property_id, year=year, category=category,
    )


@router.put("/documind/finance/rent-recovery", response_model=RentRecoveryResponse)
async def record_rent_recovery(
    payload: RentRecoveryRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Book a written-off month's rent as income in the year it actually
    arrived. The original (written-off) year is never reopened or
    recomputed — this adds a distinct 'Recovered rent' line to the year
    the money was received. Requires the month to already be on file as
    written_off.
    """
    try:
        return await documind_service.record_rent_recovery(
            landlord_id=landlord_id,
            property_id=payload.property_id,
            unit_id=payload.unit_id,
            original_month=payload.original_month,
            amount=payload.amount,
            received_year=payload.received_year,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/rent-recovery")
async def clear_rent_recovery(
    property_id: str = Query(..., description="Property ID"),
    original_month: str = Query(..., description="The written-off month the recovery was recorded against, YYYY-MM"),
    unit_id: str | None = Query(None, description="Unit ID; omit for a whole-property mark"),
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Remove a recorded rent recovery. Idempotent — clearing an unrecorded
    scope is a no-op, not an error.
    """
    return await documind_service.clear_rent_recovery(
        landlord_id=landlord_id, property_id=property_id, unit_id=unit_id, original_month=original_month,
    )


@router.put("/documind/finance/manual-loan-entry", response_model=ManualLoanEntryResponse)
async def record_manual_loan_entry(
    payload: ManualLoanEntryRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """Book manually-entered loan interest/principal for a period, for
    landlords whose bank statement cadence makes uploading inconvenient. The
    figures flow through the same two-tier loan pipeline as an uploaded
    statement. Idempotent per (property, year, month)."""
    try:
        return await documind_service.record_manual_loan_entry(
            landlord_id=landlord_id,
            property_id=payload.property_id,
            unit_id=payload.unit_id,
            year=payload.year,
            cadence=payload.cadence,
            interest_paid=payload.interest_paid,
            principal_paid=payload.principal_paid,
            month=payload.month,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/manual-loan-entry")
async def delete_manual_loan_entry(
    property_id: str = Query(..., description="Property ID"),
    unit_id: str | None = Query(None, description="Unit ID; omit for a whole-property entry"),
    year: int = Query(..., ge=2000, le=2100),
    month: int | None = Query(None, ge=1, le=12, description="Month for a monthly entry; omit for annual"),
    landlord_id: str = Depends(current_landlord_id),
):
    """Remove a manual loan entry. Idempotent — deleting an absent entry is a
    no-op, not an error."""
    return await documind_service.delete_manual_loan_entry(
        landlord_id=landlord_id, property_id=property_id, unit_id=unit_id, year=year, month=month,
    )


@router.get("/documind/finance/manual-loan-entry", response_model=ManualLoanEntryListResponse)
async def list_manual_loan_entries(
    property_id: str = Query(..., description="Property ID"),
    year: int | None = Query(None, ge=2000, le=2100, description="Omit for every year"),
    landlord_id: str = Depends(current_landlord_id),
):
    """Manual loan entries for one property, for the finance-tab list/edit UI.
    Omitting `year` returns every year, which the "remove loan tracking" guard
    needs because that action is retroactive across all years."""
    entries = documind_service.list_manual_loan_entries(landlord_id, property_id, year)
    return {"entries": entries}


@router.put("/documind/finance/unit-loan-exemption")
async def set_unit_loan_exemption(
    payload: UnitLoanExemptionRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """Mark a unit as having no loan (excludes it from the loan-figure
    completeness check). Idempotent."""
    try:
        return await documind_service.set_unit_loan_exemption(
            landlord_id=landlord_id, property_id=payload.property_id, unit_id=payload.unit_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/unit-loan-exemption")
async def clear_unit_loan_exemption(
    property_id: str = Query(..., description="Property ID"),
    unit_id: str = Query(..., description="Unit ID"),
    landlord_id: str = Depends(current_landlord_id),
):
    """Remove a unit's no-loan mark. Idempotent."""
    return await documind_service.clear_unit_loan_exemption(
        landlord_id=landlord_id, property_id=property_id, unit_id=unit_id,
    )


@router.delete("/documind/documents/{doc_id}")
async def delete_document(
    doc_id: str,
    property_id: str = Query(..., description="Property ID for scoping"),
    landlord_id: str = Depends(current_landlord_id),
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
        DELETE /api/rex/documind/documents/abc123?property_id=property_789
    """
    return await documind_service.delete_document(
        landlord_id=landlord_id,
        property_id=property_id,
        doc_id=doc_id,
    )


@router.delete("/documind/properties/{property_id}/documents")
async def delete_property_documents(
    property_id: str,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Delete ALL documents for a property (metadata, chunks, stored PDFs).

    Used by the property-deletion cascade in the app. Idempotent — a property
    with no documents returns a zero-count success.

    Example:
        DELETE /api/rex/documind/properties/property_789/documents
    """
    return await documind_service.delete_documents_for_property(
        landlord_id=landlord_id,
        property_id=property_id,
    )


@router.post("/documind/documents/unassign-unit")
async def unassign_unit_documents(
    payload: UnassignUnitRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Clear the unit assignment on all of a unit's documents and chunks,
    converting them to property-wide. Called before a unit is deleted so its
    documents don't keep a stale unit_id. Nothing is deleted; idempotent.

    Example:
        POST /api/rex/documind/documents/unassign-unit
        {"property_id": "property_789", "unit_id": "unit_9"}
    """
    return await documind_service.unassign_unit_documents(
        landlord_id=landlord_id,
        property_id=payload.property_id,
        unit_id=payload.unit_id,
    )


@router.get("/documind/documents/{doc_id}/view-url")
async def get_document_view_url(
    doc_id: str,
    property_id: str = Query(..., description="Property ID for scoping"),
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Get a short-lived signed URL to view a document's original PDF.

    Example:
        GET /api/rex/documind/documents/abc123/view-url?property_id=property_789
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