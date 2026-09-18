from pydantic import BaseModel, Field, model_validator
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
    source: str = "excerpt"  # "excerpt" | "extracted_facts"


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
    session_id: Optional[str] = Field(
        default=None,
        description="Conversation session id to continue follow-up actions"
    )
    conversation_turn: int = Field(
        default=1,
        ge=1,
        description="Current conversation turn in the session"
    )
    predicted_categories: List[str] = Field(
        default_factory=list,
        description="Categories the orchestrator predicted for the question"
    )
    action_reason: Optional[str] = Field(
        default=None,
        description="Why the orchestrator answered or scoped the search the way it did"
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
    # Maps an extracted_facts key to the 0-based PDF page it was read from.
    # {} for documents ingested before pages were located.
    fact_pages: Optional[dict] = None


class DocListResponse(BaseModel):
    """Response for document listing"""
    documents: list[DocumentInfo]
    total_count: int
    filtered_by_property: str | None = None  # property_id if filtered


class UnassignUnitRequest(BaseModel):
    """Request to convert one unit's documents to property-wide"""
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
    full_amount: Optional[float] = None  # invoiced face value when a share < 1.0 scaled `amount`
    full_billed_amount: Optional[float] = None  # face value when a share < 1.0 scaled `billed_amount`


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
    full_amount: Optional[float] = None  # document face value when a share < 1.0 scaled `amount`
    date: Optional[str] = None
    unit_id: Optional[str] = None  # None = property-level expense
    deductible: bool = True
    paid_by_landlord: bool = True


class UnitFinance(BaseModel):
    """One unit's year: monthly income strip + its own expenses."""
    unit_id: Optional[str] = None  # None = synthetic whole-property line
    label: str
    ownership_share: float = 1.0  # the resolved share this scope's income was
    # scaled at: the unit's own override if it stored one, else the property's.
    rented_months: int
    gross_income: float = 0.0  # the landlord's share of the year's rent; the app
    # renders it above the expense subtotal, so it must equal what `contribution`
    # was actually built from rather than being re-derived from `months`
    full_gross_income: Optional[float] = None  # whole-property gross when a share < 1.0 scaled it
    contribution: float  # income minus unit-scoped LANDLORD-PAID expenses (Net P/L)
    statutory_contribution: float  # income minus unit-scoped STATUTORY-deductible
    months: List[MonthIncome]
    missing_invoice_months: List[int] = Field(default_factory=list)
    expense_lines: List[ExpenseLine] = Field(default_factory=list)
    loan_status: Optional[str] = None  # complete | incomplete | no_loan


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
    landlord_expenses: float = 0.0  # landlord cash out; pairs with net_pl
    rental_income_or_loss: float
    net_pl: float
    statutory_contribution: Optional[float] = None
    units: List[UnitFinance]
    expense_lines: List[ExpenseLine]  # all lines, itemized
    property_expense_lines: List[ExpenseLine]  # the property-level subset
    recovered_rent: List[RecoveredRentLine] = Field(default_factory=list)
    coverage: List[YearCoverage] = Field(default_factory=list)
    expected_categories: List[str] = Field(default_factory=list)
    manual_loan_incomplete: bool = False


class FinanceTotals(BaseModel):
    received_rent: float
    derived_rent: float
    outstanding_rent: float = 0.0
    direct_expenses: float
    landlord_expenses: float = 0.0
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
    expense_lines: List[ExpenseLineEdit]


class FactsUpdateResponse(BaseModel):
    doc_id: str
    extracted_facts: Dict[str, Any]


class DocumentRenameRequest(BaseModel):
    filename: str = Field(..., description="New display filename")


class DocumentRenameResponse(BaseModel):
    doc_id: str
    filename: str


class ShareBasisUpdateRequest(BaseModel):
    share_basis: str = Field(
        ..., description="'full' (states the whole property's amount) or "
                         "'mine' (already split to this landlord's share)")


class ShareBasisUpdateResponse(BaseModel):
    doc_id: str
    share_basis: str


# ========== PAYMENT EXCEPTION MODELS ==========

class PaymentExceptionRequest(BaseModel):
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


# ========== MANUAL LOAN ENTRY MODELS ==========

class ManualLoanEntryRequest(BaseModel):
    property_id: str
    unit_id: Optional[str] = None
    year: int = Field(..., ge=2000, le=2100)
    cadence: str = Field(..., description="'monthly' or 'annual'")
    interest_paid: float = Field(..., ge=0)
    principal_paid: float = Field(..., ge=0)
    month: Optional[int] = Field(None, ge=1, le=12, description="Required for monthly cadence")

    @model_validator(mode="after")
    def _check_cadence(self):
        if self.cadence not in ("monthly", "annual"):
            raise ValueError("cadence must be 'monthly' or 'annual'")
        if self.cadence == "monthly" and self.month is None:
            raise ValueError("monthly cadence requires a month (1-12)")
        return self


class ManualLoanEntryResponse(BaseModel):
    property_id: str
    unit_id: Optional[str] = None
    year: int
    month: Optional[int] = None
    interest_paid: float
    principal_paid: float
    cadence: str


class ManualLoanEntryListResponse(BaseModel):
    entries: List[ManualLoanEntryResponse]


# ========== UNIT LOAN EXEMPTION MODELS ==========

class UnitLoanExemptionRequest(BaseModel):
    property_id: str
    unit_id: str = Field(..., min_length=1)