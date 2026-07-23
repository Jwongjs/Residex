from __future__ import annotations

import json
import re
from datetime import date
from typing import Any, Dict, List, Optional

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

# Canonical expense-line subtypes -> the finance category each amount rolls
# into. Single source of truth: extraction and the PATCH API validate against
# the keys; the finance engine maps breakdown rows with the values.
EXPENSE_SUBTYPE_CATEGORY: Dict[str, str] = {
    "loan_interest": "loan",
    "assessment_tax": "tax",
    "quit_rent": "tax",
    "parcel_rent": "tax",
    "maintenance": "maintenance",
    "sinking_fund": "maintenance",
    "insurance_premium": "insurance",
    "upkeep": "upkeep",
    # Recurring services a landlord or a guarded scheme is billed for.
    "management_fee": "management",
    "rent_collection": "management",
    "security_fee": "management",
    "pest_control": "upkeep",
    # Costs of putting the property on the market. Deductible on a renewal
    # only — see RENEWAL_ONLY_SUBTYPES.
    "agent_commission": "letting",
    "legal_fee": "letting",
    "stamp_duty": "letting",
    "advertising": "letting",
    # Service tax charged on any of the above.
    "sst": "sst",
    # Captured for visibility, never folded as a deduction by default. Each
    # keeps a bucket of its own so it can neither satisfy a coverage slot nor
    # inflate a deductible bucket.
    "utilities": "utilities",
    "late_penalty": "late_penalty",
    "renovation": "renovation",
    "loan_principal": "loan_principal",
}

# Penalties and capital outlay: never deductible against s.4(d) rental income.
NEVER_DEDUCTIBLE_SUBTYPES = {"late_penalty", "renovation", "loan_principal"}

# Deductible only when the property profile says the landlord bears the cost.
# The Malaysian default is the tenant (Ayer@8 tenancy clause 5.2), and
# under-claiming beats over-claiming.
LANDLORD_BORNE_SUBTYPES = {"utilities"}

# LHDN PR 12/2018: the cost of putting a property on the market for the
# first time is capital/preliminary. These deduct only when a renewal
# tenancy for the same year is on file.
RENEWAL_ONLY_SUBTYPES = {
    "agent_commission", "legal_fee", "stamp_duty", "advertising",
}

# Document-organization rhythm (design spec §9): which tags define a folder's
# identity (periodic), which merely ride along without ever splitting a folder
# (one_off), and which form their own folder only when they appear alone
# (ad_hoc). sst, late_penalty and loan_principal are not itemised in the
# spec's table — classified one_off because each always accompanies a real
# charge (the fee SST taxes, the bill a late penalty is charged against, the
# interest a principal portion amortises beside) and none is ever the sole
# line on a bill.
EXPENSE_SUBTYPE_RHYTHM: Dict[str, str] = {
    "maintenance": "periodic",
    "sinking_fund": "periodic",
    "utilities": "periodic",
    "management_fee": "periodic",
    "security_fee": "periodic",
    "rent_collection": "periodic",
    "insurance_premium": "one_off",
    "quit_rent": "one_off",
    "parcel_rent": "one_off",
    "assessment_tax": "one_off",
    "loan_interest": "one_off",
    "stamp_duty": "one_off",
    "agent_commission": "one_off",
    "legal_fee": "one_off",
    "advertising": "one_off",
    "sst": "one_off",
    "late_penalty": "one_off",
    "loan_principal": "one_off",
    "upkeep": "ad_hoc",
    "pest_control": "ad_hoc",
    "renovation": "ad_hoc",
}

# Classification is a lookup against this table, not model judgment — the
# Malay/English wording landlords actually see on Malaysian bills.
_EXPENSE_SYNONYMS = (
    "- loan_interest: housing loan interest, interest charged, faedah pinjaman\n"
    "- loan_principal: principal repayment, principal portion of an "
    "installment, bayaran pokok\n"
    "- assessment_tax: assessment, cukai pintu, cukai taksiran\n"
    "- quit_rent: quit rent, cukai tanah\n"
    "- parcel_rent: parcel rent, cukai petak\n"
    "- maintenance: service charge, caj perkhidmatan, maintenance fee, "
    "caj penyelenggaraan, or a management fee charged by a JMB/MC or "
    "building management\n"
    "- sinking_fund: sinking fund, kumpulan wang penjelas\n"
    "- management_fee: property management fee charged by a letting or "
    "estate agent for managing the tenancy — NOT a JMB/MC building charge, "
    "which is maintenance\n"
    "- rent_collection: rent collection fee or commission charged by an "
    "agent, yuran kutipan sewa\n"
    "- security_fee: guard house, security or patrol charge in a guarded "
    "scheme, caj keselamatan / pengawal\n"
    "- pest_control: pest control, fumigation, termite treatment, "
    "kawalan serangga\n"
    "- agent_commission: agent commission or brokerage for securing a "
    "tenant, komisen ejen\n"
    "- legal_fee: solicitor or legal fees for preparing the tenancy "
    "agreement, yuran guaman\n"
    "- stamp_duty: stamp duty on the tenancy agreement, duti setem\n"
    "- advertising: advertising or listing fees to market the property, "
    "kos iklan\n"
    "- sst: sales and service tax or service tax charged on a fee above, "
    "cukai perkhidmatan\n"
    "- insurance_premium: insurance premium, fire policy, houseowner policy, "
    "takaful contribution\n"
    "- upkeep: repairs, servicing, plumbing or electrical works\n"
    "- renovation: renovation, upgrading, improvement or addition works, "
    "kerja ubah suai\n"
    "- utilities: water meter billing, water sewerage billing, Indah Water, "
    "electricity or water billed through the management\n"
    "- late_penalty: late payment charge, late payment interest, denda lewat, "
    "faedah lewat bayar"
)


def validate_expense_lines(lines: Any) -> List[Dict[str, Any]]:
    """Whitelist-validated copy of expense line items; invalid entries are
    dropped, never guessed. Shared by extraction and the facts PATCH API."""
    if not isinstance(lines, list):
        return []
    cleaned: List[Dict[str, Any]] = []
    for line in lines:
        if not isinstance(line, dict):
            continue
        subtype = str(line.get("subtype") or "").strip().lower().replace(" ", "_")
        if subtype not in EXPENSE_SUBTYPE_CATEGORY:
            continue
        amount = FactExtractor._coerce("expenses", "amount", str(line.get("amount", "")))
        if amount is None:
            continue
        entry: Dict[str, Any] = {"subtype": subtype, "amount": amount}
        description = str(line.get("description") or "").strip()
        if description:
            entry["description"] = description[:200]
        date_value = FactExtractor._coerce("expenses", "date", str(line.get("date", "")))
        if date_value is not None:
            entry["date"] = date_value
        year_value = FactExtractor._coerce("expenses", "year", str(line.get("period_year", "")))
        if year_value is not None:
            entry["period_year"] = year_value
        installment_value = str(line.get("installment") or "").strip()
        if installment_value:
            entry["installment"] = installment_value[:20]
        cleaned.append(entry)
    return cleaned


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
        cleaned = (text or "").strip()
        if not cleaned:
            return None
        if category == "expenses":
            return self._extract_expense_lines(cleaned[:MAX_INPUT_CHARS])
        fields = _FIELD_TYPES.get(category)
        if not fields:
            return None

        try:
            prompt = self._build_prompt(category, cleaned[:MAX_INPUT_CHARS])
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()
        except Exception as e:
            print(f"Fact extraction LLM call failed: {e}")
            return None

        facts = self._parse(category, fields, content)
        if category == "lease":
            clause_facts = self._extract_utilities_liability(cleaned[:MAX_INPUT_CHARS])
            if clause_facts:
                facts.update(clause_facts)
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

    def _extract_expense_lines(self, text: str) -> Optional[Dict[str, Any]]:
        """JSON line-item extraction for combined expense documents."""
        prompt = f"""
You are extracting expense line items from a Malaysian landlord's property
expense document (bill, statement or receipt). One document may contain
several distinct charge types.

Document text (may be truncated):
{text}

Allowed subtypes and the wording that maps to each (classify strictly by
this table):
{_EXPENSE_SYNONYMS}

Rules:
- Extract ONLY charges billed TO the property owner. Ignore amounts the
  owner bills to a tenant, and ignore totals that duplicate itemised lines.
- One object per distinct charge. NEVER invent amounts.
- Dates must be ISO YYYY-MM-DD; period_year a 4-digit year. Include
  whichever the document states.
- If an insurance premium appears, also report policy_start and policy_end.

Respond with ONLY a JSON object, no markdown fences, shaped exactly like:
{{"lines": [{{"subtype": "maintenance", "description": "Service charge Jan-Mar",
 "amount": 1050.00, "date": "2025-01-01", "period_year": 2025}}],
 "policy_start": null, "policy_end": null, "confidence": 0.9}}
""".strip()
        try:
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()
        except Exception as e:
            print(f"Expense-line extraction LLM call failed: {e}")
            return None

        start = content.find("{")
        end = content.rfind("}")
        if start == -1 or end <= start:
            return None
        try:
            payload = json.loads(content[start:end + 1])
        except ValueError:
            return None
        if not isinstance(payload, dict):
            return None

        lines = validate_expense_lines(payload.get("lines"))
        if not lines:
            return None
        facts: Dict[str, Any] = {"expense_lines": lines}
        for key in ("policy_start", "policy_end"):
            value = self._coerce("expenses", "date", str(payload.get(key) or ""))
            if value is not None:
                facts[key] = value
        try:
            facts["confidence"] = max(0.0, min(1.0, float(payload.get("confidence"))))
        except (TypeError, ValueError):
            pass
        return facts

    def _extract_utilities_liability(self, text: str) -> Optional[Dict[str, Any]]:
        """Reads the tenancy agreement's utilities clause, quoting the exact
        text that supports the answer (spec §8). A second, independent LLM
        call kept separate from the semicolon-parsed lease fields above,
        because a verbatim clause quote can itself contain a semicolon,
        which would corrupt that format. Returns None unless BOTH a valid
        liability value AND a supporting quote are found -- the confirm-once
        prompt has nothing to show otherwise, and utilities_paid_by must
        never be set from an unconfirmed extraction. Best-effort: any
        failure here is non-blocking and never raises."""
        prompt = f"""
You are reading a Malaysian tenancy agreement to find the clause that says
who is liable for utilities (electricity, water, sewerage) at the rented
property.

Document text (may be truncated):
{text}

Find the clause assigning utilities liability to the tenant or the landlord.
Respond with ONLY a JSON object, no markdown fences, shaped exactly like:
{{"utilities_liability": "tenant", "clause_ref": "Clause 5.2",
 "quote": "the exact clause text, copied verbatim", "confidence": 0.9}}

Rules:
- utilities_liability must be exactly "tenant" or "landlord". If the clause
  is not clearly present, respond with {{}} -- NEVER guess.
- quote must be copied verbatim from the document text above, not paraphrased.
- clause_ref is the clause number or heading as printed (e.g. "Clause 5.2" or
  "Payment of Utilities"). Omit it if the document has no clause numbering.
""".strip()
        try:
            response = self._llm.invoke(prompt)
            content = str(response.content).strip()
        except Exception as e:
            print(f"Utilities-clause extraction LLM call failed: {e}")
            return None

        start = content.find("{")
        end = content.rfind("}")
        if start == -1 or end <= start:
            return None
        try:
            payload = json.loads(content[start:end + 1])
        except ValueError:
            return None
        if not isinstance(payload, dict):
            return None

        liability = str(payload.get("utilities_liability") or "").strip().lower()
        quote = str(payload.get("quote") or "").strip()
        if liability not in ("tenant", "landlord") or not quote:
            return None

        facts: Dict[str, Any] = {
            "utilities_liability": liability,
            "utilities_clause_quote": quote[:500],
        }
        clause_ref = str(payload.get("clause_ref") or "").strip()
        if clause_ref:
            facts["utilities_clause_ref"] = clause_ref[:60]
        return facts

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
