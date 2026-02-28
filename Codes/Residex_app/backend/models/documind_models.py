from pydantic import BaseModel, Field
from datetime import datetime


class DocUploadResponse(BaseModel):
    """Response after uploading a document"""
    doc_id: str
    landlord_id: str
    property_id: str
    category: str
    filename: str
    status: str  # "indexed"
    chunks_indexed: int


class AskRequest(BaseModel):
    """Request to ask DocuMind a question"""
    landlord_id: str
    property_id: str  # Scopes search to specific property
    question: str
    top_k: int = Field(default=4, ge=1, le=10, description="Number of chunks to retrieve")


class Citation(BaseModel):
    """Citation for a retrieved document chunk"""
    doc_id: str
    filename: str
    category: str
    page: int | None = None
    snippet: str  # First 200 chars of chunk
    score: float  # Relevance score (0.0 - 1.0)


class AskResponse(BaseModel):
    """Response from DocuMind Q&A"""
    answer: str
    confidence: float  # 0.0 - 1.0
    citations: list[Citation]
    property_name: str  # For UI display


class DocumentInfo(BaseModel):
    """Metadata for a single document"""
    doc_id: str
    landlord_id: str
    property_id: str
    category: str  # 'lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'
    filename: str
    uploaded_at: datetime
    chunks_indexed: int
    file_size: int | None = None  # In bytes


class DocListResponse(BaseModel):
    """Response for document listing"""
    documents: list[DocumentInfo]
    total_count: int
    filtered_by_property: str | None = None  # property_id if filtered