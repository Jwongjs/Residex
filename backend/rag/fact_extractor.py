from __future__ import annotations

import re
from datetime import date
from typing import Any, Dict, Optional

MAX_INPUT_CHARS = 8000

# Fields requested per category. The parser is the enforcement layer:
# anything failing its type check is dropped, never guessed.
_FIELD_TYPES: Dict[str, Dict[str, str]] = {
    "lease": {
        "monthly_rent": "amount",
        "deposit": "amount",
        "lease_start": "date",
        "lease_end": "date",
        "tenant_name": "text",
        "subtype": "subtype",
        "renewal_fee": "amount",
    },
    "rental_invoice": {
        "amount": "amount",
        "period_month": "month",
        "invoice_date": "date",
    },
    "loan": {
        "subtype": "subtype",
        "interest_paid": "amount",
        "period_year": "year",
        "principal": "amount",
        "interest_rate": "amount",
        "lender": "text",
    },
    "tax": {
        "subtype": "subtype",
        "amount": "amount",
        "period_year": "year",
        "installment": "text",
    },
    "upkeep": {
        "amount": "amount",
        "service_date": "date",
        "description": "text",
    },
    "maintenance": {
        "amount": "amount",
        "period_start": "date",
        "period_end": "date",
        "description": "text",
    },
    "insurance": {
        "premium": "amount",
        "policy_start": "date",
        "policy_end": "date",
        "policy_number": "text",
    },
}

_SUBTYPES: Dict[str, set] = {
    "lease": {"new", "renewal"},
    "loan": {"agreement", "interest_statement"},
    "tax": {"assessment", "quit_rent", "parcel_rent"},
}

_FIELD_HINTS: Dict[str, str] = {
    "lease": (
        "- monthly_rent: monthly rent amount\n"
        "- deposit: security deposit amount\n"
        "- lease_start: tenancy start date\n"
        "- lease_end: tenancy end date\n"
        "- tenant_name: tenant full name\n"
        "- subtype: new | renewal\n"
        "- renewal_fee: fee charged for renewing the tenancy (renewals only)"
    ),
    "rental_invoice": (
        "- amount: rent billed for the month\n"
        "- period_month: the month being billed, as YYYY-MM\n"
        "- invoice_date: date the invoice was issued"
    ),
    "loan": (
        "- subtype: agreement | interest_statement\n"
        "- interest_paid: total loan interest paid in the statement year\n"
        "- period_year: the year the interest statement covers\n"
        "- principal: loan principal amount\n"
        "- interest_rate: annual interest rate (number only)\n"
        "- lender: bank or lender name"
    ),
    "tax": (
        "- subtype: assessment | quit_rent | parcel_rent "
        "(cukai pintu/taksiran = assessment, cukai tanah = quit_rent)\n"
        "- amount: amount payable on this bill\n"
        "- period_year: the year the bill covers\n"
        "- installment: installment description when the bill is one of several (e.g. 1/2)"
    ),
    "upkeep": (
        "- amount: amount paid for the repair or servicing\n"
        "- service_date: date of the service or invoice\n"
        "- description: short description of the work"
    ),
    "maintenance": (
        "- amount: management/maintenance charge amount (include sinking fund)\n"
        "- period_start: start of the period the charge covers\n"
        "- period_end: end of the period the charge covers\n"
        "- description: short description of the charge"
    ),
    "insurance": (
        "- premium: policy premium amount\n"
        "- policy_start: policy period start date\n"
        "- policy_end: policy period end date\n"
        "- policy_number: policy number"
    ),
}

_AMOUNT_STRIP = re.compile(r"[^0-9.\-]")
_SKIP_VALUES = {"", "none", "null", "unknown", "n/a", "na", "-"}


class FactExtractor:
    """Best-effort structured fact extraction at ingest.

    Mirrors CategoryPredictor's house pattern: constructor-injected llm,
    semicolon key=value response format, defensive parse. No keyword
    fallback — these figures feed tax computations, so "unknown" beats
    fabrication.
    """

    def __init__(self, llm):
        self._llm = llm

    def extract(self, category: str, text: str) -> Optional[Dict[str, Any]]:
        """Validated facts (plus a 'confidence' key when provided) or None.
        Never raises on LLM or parse trouble."""
        fields = _FIELD_TYPES.get(category)
        if not fields:
            return None
        cleaned = (text or "").strip()
        if not cleaned:
            return None

        try:
            prompt = self._build_prompt(category, cleaned[:MAX_INPUT_CHARS])
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()
        except Exception as e:
            print(f"⚠️ Fact extraction LLM call failed: {e}")
            return None

        facts = self._parse(category, fields, content)
        if not [key for key in facts if key != "confidence"]:
            return None
        return facts

    def _build_prompt(self, category: str, text: str) -> str:
        subtype_rule = ""
        if category in _SUBTYPES:
            subtype_rule = (
                "- subtype must be exactly one of: "
                f"{', '.join(sorted(_SUBTYPES[category]))}. Omit it when unclear.\n"
            )
        return f"""
You are extracting structured facts from a landlord's {category} document.

Document text (may be truncated):
{text}

Extract ONLY these fields:
{_FIELD_HINTS[category]}

Rules:
- Omit any field that is not clearly stated in the text. NEVER guess.
- Dates must be ISO format YYYY-MM-DD. period_month must be YYYY-MM. period_year must be a 4-digit year.
- Amounts must be plain numbers with no currency symbols or thousands separators.
{subtype_rule}- Always include confidence=<0.0-1.0> for the extraction overall.

Respond with ONLY one line of semicolon-separated key=value pairs, e.g.:
amount=460.63;period_year=2026;confidence=0.9
""".strip()

    def _parse(self, category: str, fields: Dict[str, str], content: str) -> Dict[str, Any]:
        facts: Dict[str, Any] = {}
        for part in content.split(";"):
            part = part.strip()
            if "=" not in part:
                continue
            key, raw = part.split("=", 1)
            key = key.strip().lower()
            raw = raw.strip()
            if raw.lower() in _SKIP_VALUES:
                continue
            if key == "confidence":
                try:
                    facts["confidence"] = max(0.0, min(1.0, float(raw)))
                except ValueError:
                    pass
                continue
            field_type = fields.get(key)
            if field_type is None:
                continue
            value = self._coerce(category, field_type, raw)
            if value is not None:
                facts[key] = value
        return facts

    @staticmethod
    def _coerce(category: str, field_type: str, raw: str) -> Optional[Any]:
        if field_type == "date":
            try:
                date.fromisoformat(raw)
                return raw
            except ValueError:
                return None
        if field_type == "month":
            try:
                date.fromisoformat(f"{raw}-01")
                return raw
            except ValueError:
                return None
        if field_type == "year":
            if raw.isdigit() and len(raw) == 4:
                return int(raw)
            return None
        if field_type == "amount":
            stripped = _AMOUNT_STRIP.sub("", raw)
            try:
                return float(stripped)
            except ValueError:
                return None
        if field_type == "subtype":
            candidate = raw.lower().replace(" ", "_")
            if candidate in _SUBTYPES.get(category, set()):
                return candidate
            return None
        return raw  # text
