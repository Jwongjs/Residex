from pydantic import BaseModel, Field
from typing import List, Optional, Dict

class TenantInput(BaseModel):
    full_name: str
    email: Optional[str] = None
    id_no: Optional[str] = None

class LeaseGenerateRequest(BaseModel):
    landlord_id: str
    property_id: str
    jurisdiction: str = "MY"
    language: str = "en"
    lease_type: str = "residential"
    start_date: str
    end_date: str
    monthly_rent: float = Field(ge=0)
    security_deposit: float = Field(ge=0)
    tenant: TenantInput
    optional_clauses: Dict[str, str] = {}

class LeaseGenerateResponse(BaseModel):
    lease_id: str
    title: str
    markdown: str
    risk_flags: List[str] = []
    missing_clauses: List[str] = []
    pdf_url: Optional[str] = None