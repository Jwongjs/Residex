from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List


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
    categories: Optional[List[str]] = Field(
        default=None,
        description="Optional category filters: lease, warranty, insurance, utility, receipt, other"
    )
    unit_id: Optional[str] = Field(
        default=None,
        description="Optional unit filter: matches chunks assigned to this unit plus property-wide chunks (no unit)"
    )
    session_id: Optional[str] = Field(
        default=None,
        description="Optional conversation session id for multi-turn DocuMind orchestration"
    )
    conversation_turn: int = Field(
        default=1,
        ge=1,
        description="Conversation turn number when continuing an existing session"
    )
    user_action: Optional[str] = Field(
        default=None,
        description="User response for checkpointed actions: confirm | cancel | override:<category> | unit:<unit_id> | unit:all"
    )


class Citation(BaseModel):
    """Citation for a retrieved document chunk"""
    doc_id: str
    filename: str
    category: str
    page: int | None = None
    snippet: str  # First 200 chars of chunk
    score: float  # Relevance score (0.0 - 1.0)
    unit_id: str | None = None  # None = property-wide source
    unit_label: str | None = None  # Denormalized label captured at ingest


class UnitOption(BaseModel):
    """One selectable unit in a unit-clarification checkpoint"""
    unit_id: str
    unit_label: str


class AskResponse(BaseModel):
    """Response from DocuMind Q&A"""
    answer: str
    confidence: float  # 0.0 - 1.0
    citations: list[Citation]
    property_name: str  # For UI display
    searched_categories: List[str] = Field(default_factory=list)
    category_filter_mode: str = Field(
        default="all",
        description="Category filtering mode: explicit, auto, all"
    )
    needs_category_clarification: bool = Field(
        default=False,
        description="Whether frontend should ask user to choose a category before searching"
    )
    clarification_prompt: Optional[str] = Field(
        default=None,
        description="Prompt shown when category clarification is needed"
    )
    clarification_options: List[str] = Field(
        default_factory=list,
        description="Suggested categories for user to choose"
    )
    session_id: Optional[str] = Field(
        default=None,
        description="Conversation session id to continue follow-up actions"
    )
    conversation_turn: int = Field(
        default=1,
        ge=1,
        description="Current conversation turn in the session"
    )
    user_action_required: bool = Field(
        default=False,
        description="When true, frontend should prompt user to confirm/override/cancel next action"
    )
    predicted_categories: List[str] = Field(
        default_factory=list,
        description="Categories predicted by orchestrator before user confirmation"
    )
    action_reason: Optional[str] = Field(
        default=None,
        description="Reasoning shown to user for the suggested action"
    )
    needs_unit_clarification: bool = Field(
        default=False,
        description="Whether frontend should ask user to choose a unit before answering",
    )
    unit_options: List[UnitOption] = Field(
        default_factory=list,
        description="Units whose documents matched; ends with sentinel {unit_id: 'all', unit_label: 'All units'}",
    )


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
    unit_id: str | None = None  # None = property-wide document
    unit_label: str | None = None  # Denormalized label for display


class DocListResponse(BaseModel):
    """Response for document listing"""
    documents: list[DocumentInfo]
    total_count: int
    filtered_by_property: str | None = None  # property_id if filtered


class UnassignUnitRequest(BaseModel):
    """Request to convert one unit's documents to property-wide"""
    landlord_id: str
    property_id: str
    unit_id: str