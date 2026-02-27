from fastapi import APIRouter, UploadFile, File, Form
from models.lease_models import LeaseGenerateRequest, LeaseGenerateResponse
from models.documind_models import DocUploadResponse, AskRequest, AskResponse
from agents.lease_generator import generate_lease
from rag.documind_service import ingest_document, ask_documind, list_documents

router = APIRouter(prefix="/api/rex", tags=["rex-ai"])

@router.post("/lease/generate", response_model=LeaseGenerateResponse)
async def lease_generate(payload: LeaseGenerateRequest):
    return await generate_lease(payload)

@router.post("/documind/upload", response_model=DocUploadResponse)
async def documind_upload(
    landlord_id: str = Form(...),
    property_id: str | None = Form(None),
    file: UploadFile = File(...)
):
    return await ingest_document(landlord_id=landlord_id, property_id=property_id, file=file)

@router.post("/documind/ask", response_model=AskResponse)
async def documind_ask(payload: AskRequest):
    return await ask_documind(payload)

@router.get("/documind/documents")
async def documind_documents(landlordId: str):
    return await list_documents(landlordId)