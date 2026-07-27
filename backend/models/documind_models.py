from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List, Dict, Any, Literal


class DocUploadResponse(BaseModel):
    """Response after uploading a document"""
    doc_id: str
    landlord_id: str
    property_id: str
    category: str
    filename: str
    status: str  # "indexed"
    chunks_indexed: int
    extracted_facts: Optional[dict] = None
    facts_confidence: Optional[float] = None
    # 'ok' when ingest captured facts; 'needs_review' when extraction came back
    # empty, so a silent miss is visible instead of looking like a doc that
    # simply has no facts.
    facts_status: str = "ok"


class AskRequest(BaseModel):
    """Request to ask DocuMind a question"""
    landlord_id: str
    property_id: str  # Scopes search to specific property
    question: str
    top_k: int = Field(default=4, ge=1, le=10, description="Number of chunks to retrieve")
    categories: Optional[List[str]] = Field(
        default=None,
        description="Optional category filters: lease, insurance, loan, tax, upkeep, maintenance, rental_invoice"
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


class DocumentTag(BaseModel):
    """One derived sub-category tag (design spec §9) — recomputed at read
    time, never stored. rhythm drives folder clustering: 'periodic' tags
    define a folder's identity, 'one_off' and 'ad_hoc' tags ride along."""
    tag: str
    rhythm: str  # 'periodic' | 'one_off' | 'ad_hoc'


class DocumentInfo(BaseModel):
    """Metadata for a single document"""
    doc_id: str
    landlord_id: str
    property_id: str
    category: str  # 'lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice' (legacy names normalized at read)
    filename: str
    uploaded_at: datetime
    chunks_indexed: int
    file_size: int | None = None  # In bytes
    unit_id: str | None = None  # None = property-wide document
    unit_label: str | None = None  # Denormalized label for display
    extracted_facts: Optional[dict] = None
    facts_confidence: Optional[float] = None
    # 'ok' | 'needs_review' — derived at read time from whether facts exist,
    # so legacy documents (stored before this field) surface correctly too.
    facts_status: str = "ok"
    tags: list[DocumentTag] = []


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


# ========== FINANCE SUMMARY MODELS ==========

class MonthIncome(BaseModel):
    """One month of one unit's income."""
    month: int  # 1-12
    source: str  # actual | derived | unpaid | vacant
    amount: float
    reason: Optional[str] = None
    payment_state: Optional[str] = None  # outstanding | written_off, only when source == 'unpaid'
    billed_amount: Optional[float] = None  # what the month would have been worth, when known


class ExpenseLine(BaseModel):
    """One expense line traceable to its source document. Non-deductible
    lines (utilities the tenant bears, penalties, capital works) are still
    carried so the landlord sees their whole bill; they simply do not feed
    the figures."""
    doc_id: str
    category: str
    subtype: Optional[str] = None
    description: Optional[str] = None
    amount: float
    date: Optional[str] = None
    unit_id: Optional[str] = None  # None = property-level expense
    deductible: bool = True


class UnitFinance(BaseModel):
    """One unit's year: monthly income strip + its own expenses."""
    unit_id: Optional[str] = None  # None = synthetic whole-property line
    label: str
    rented_months: int
    contribution: float  # income minus unit-scoped expenses
    months: List[MonthIncome]
    missing_invoice_months: List[int] = Field(default_factory=list)
    expense_lines: List[ExpenseLine] = Field(default_factory=list)


class InstallmentGap(BaseModel):
    """A tax whose own bill declares N installments, with fewer uploaded."""
    label: str
    have: int
    expect: int


class PartialCategory(BaseModel):
    """A periodic category with some but not all of its slots filled."""
    category: str
    have: int
    expect: int


class YearCoverage(BaseModel):
    """One year's document-completeness report for a property."""
    year: int
    missing: List[str] = Field(default_factory=list)
    partial_installments: List[InstallmentGap] = Field(default_factory=list)
    partial_categories: List[PartialCategory] = Field(default_factory=list)
    unavailable: List[str] = Field(default_factory=list)


class RecoveredRentLine(BaseModel):
    """A written-off month's rent, booked as income in the year it
    actually arrived. Never merged into that year's own month rows."""
    unit_id: Optional[str] = None
    original_month: str
    amount: float
    label: str


class PropertyFinance(BaseModel):
    """Per-property annual block (mirrors the reference sheet)."""
    property_id: str
    name: str
    ownership_share: float = 1.0
    complete: bool = True
    received_rent: float
    derived_rent: float
    outstanding_rent: float = 0.0
    direct_expenses: float
    rental_income_or_loss: float
    units: List[UnitFinance]
    expense_lines: List[ExpenseLine]  # all lines, itemized
    property_expense_lines: List[ExpenseLine]  # the property-level subset
    recovered_rent: List[RecoveredRentLine] = Field(default_factory=list)
    coverage: List[YearCoverage] = Field(default_factory=list)
    expected_categories: List[str] = Field(default_factory=list)


class FinanceTotals(BaseModel):
    received_rent: float
    derived_rent: float
    outstanding_rent: float = 0.0
    direct_expenses: float
    net_pl: float
    statutory_rental_income: float
    statutory_note: str


class FinanceSummaryResponse(BaseModel):
    """GET /api/rex/documind/finance/summary"""
    year: int
    totals: FinanceTotals
    expense_breakdown: Dict[str, float]
    properties: List[PropertyFinance]
    caveats: List[str]
    missing_categories: Dict[str, List[str]]


class ExpenseLineEdit(BaseModel):
    subtype: str
    amount: float
    description: Optional[str] = None
    date: Optional[str] = None
    period_year: Optional[int] = None
    installment: Optional[str] = None


class FactsUpdateRequest(BaseModel):
    landlord_id: str
    expense_lines: List[ExpenseLineEdit]


class FactsUpdateResponse(BaseModel):
    doc_id: str
    extracted_facts: Dict[str, Any]


class DocumentRenameRequest(BaseModel):
    landlord_id: str
    filename: str = Field(..., description="New display filename")


class DocumentRenameResponse(BaseModel):
    doc_id: str
    filename: str


# ========== PAYMENT EXCEPTION MODELS ==========

class PaymentExceptionRequest(BaseModel):
    landlord_id: str
    property_id: str
    month: str = Field(..., description="Calendar month, YYYY-MM")
    unit_id: Optional[str] = None
    reason: Optional[str] = None
    state: Literal["outstanding", "written_off"] = "outstanding"


class PaymentExceptionResponse(BaseModel):
    property_id: str
    unit_id: Optional[str] = None
    month: str
    reason: Optional[str] = None
    state: str = "outstanding"


# ========== DOCUMENT EXCEPTION MODELS ==========

class DocumentExceptionRequest(BaseModel):
    landlord_id: str
    property_id: str
    year: int = Field(..., ge=2000, le=2100)
    category: str = Field(
        ..., min_length=1,
        description="A label from that year's coverage 'missing' list, e.g. "
                    "maintenance, loan, assessment, quit_rent, land_office_tax",
    )


class DocumentExceptionResponse(BaseModel):
    property_id: str
    year: int
    category: str


# ========== RENT RECOVERY MODELS ==========

class RentRecoveryRequest(BaseModel):
    landlord_id: str
    property_id: str
    original_month: str = Field(..., description="The written-off month being recovered, YYYY-MM")
    amount: float = Field(..., gt=0)
    received_year: int = Field(..., ge=2000, le=2100, description="Calendar year the money actually arrived")
    unit_id: Optional[str] = None


class RentRecoveryResponse(BaseModel):
    property_id: str
    unit_id: Optional[str] = None
    original_month: str
    amount: float
    received_year: int