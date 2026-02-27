import uuid
from fastapi import UploadFile
from models.documind_models import DocUploadResponse, AskRequest, AskResponse, Citation

async def ingest_document(landlord_id: str, property_id: str | None, file: UploadFile) -> DocUploadResponse:
    # TODO: OCR -> chunk -> embeddings -> vector store (LangChain)
    return DocUploadResponse(
        doc_id=str(uuid.uuid4()),
        landlord_id=landlord_id,
        property_id=property_id,
        filename=file.filename or "unknown",
        status="indexed",
        chunks_indexed=0,
    )

async def ask_documind(payload: AskRequest) -> AskResponse:
    # TODO: LangChain retriever + citations
    return AskResponse(
        answer="No indexed context yet.",
        confidence=0.0,
        citations=[],
    )

async def list_documents(landlord_id: str):
    # TODO: return firestore/postgres metadata
    return []