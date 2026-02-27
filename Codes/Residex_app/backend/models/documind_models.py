from pydantic import BaseModel
from typing import List, Optional

class DocUploadResponse(BaseModel):
    doc_id: str
    landlord_id: str
    property_id: Optional[str] = None
    filename: str
    status: str
    chunks_indexed: int = 0

class AskRequest(BaseModel):
    landlord_id: str
    question: str
    property_id: Optional[str] = None
    doc_ids: Optional[List[str]] = None
    top_k: int = 5

class Citation(BaseModel):
    doc_id: str
    page: Optional[int] = None
    snippet: str
    score: float

class AskResponse(BaseModel):
    answer: str
    confidence: float
    citations: List[Citation]