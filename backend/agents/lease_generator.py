import uuid
from models.lease_models import LeaseGenerateRequest, LeaseGenerateResponse

REQUIRED_CLAUSES = [
    "rent_due_date", "termination", "deposit_terms", "maintenance_responsibility"
]

async def generate_lease(payload: LeaseGenerateRequest) -> LeaseGenerateResponse:
    # TODO: Replace with Gemini call (structured output)
    markdown = f"# Residential Lease Agreement\n\nProperty: {payload.property_id}\nTenant: {payload.tenant.full_name}\n"
    missing = [c for c in REQUIRED_CLAUSES if c not in payload.optional_clauses]
    flags = ["review_required"] if missing else []

    return LeaseGenerateResponse(
        lease_id=str(uuid.uuid4()),
        title="Generated Lease",
        markdown=markdown,
        risk_flags=flags,
        missing_clauses=missing,
        pdf_url=None,
    )