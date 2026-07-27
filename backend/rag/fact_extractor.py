from __future__ import annotations

import json
import os
import re
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

from rag.expense_scanner import backfill_expense_lines

MAX_INPUT_CHARS = 8000

# Leases get a larger, tail-inclusive budget: a tenancy agreement fills in its
# dates, rent and deposit in the SCHEDULE at the very end, so head-truncation to
# MAX_INPUT_CHARS drops exactly those figures. This fits comfortably in a hosted
# large-context model (the recommended lease provider) and within qwen2.5's
# window for the local fallback.
LEASE_MAX_CHARS = 30000

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
        "- interest_paid: total loan interest paid in the statement period\n"
        "- period_year: the year the statement covers\n"
        "- principal: original loan principal amount\n"
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
# Trailing comma before a closing } or ] — invalid JSON, but a shape a small
# model emits constantly. Stripped only as a repair after a strict parse fails,
# so well-formed replies are never touched.
_TRAILING_COMMA = re.compile(r",(\s*[}\]])")


def _loads_json_object(content: Optional[str]) -> Optional[Dict[str, Any]]:
    """First {...} object in an LLM reply, or None. Tolerant of the wrapping a
    small model adds around otherwise-correct JSON — prose before/after the
    object (sliced off by the outermost braces), markdown fences, and trailing
    commas. Returns None unless the parse yields a dict."""
    if not content:
        return None
    start = content.find("{")
    end = content.rfind("}")
    if start == -1 or end <= start:
        return None
    blob = content[start:end + 1]
    for candidate in (blob, _TRAILING_COMMA.sub(r"\1", blob)):
        try:
            payload = json.loads(candidate)
        except ValueError:
            continue
        return payload if isinstance(payload, dict) else None
    return None


def _lease_input(text: str) -> str:
    """The text window fed to lease extraction. Short agreements pass through
    whole; longer ones keep the HEAD (parties, operative + utilities clauses)
    AND the TAIL (the Schedule with the filled-in dates/rent/deposit), because a
    plain head cut would drop the Schedule and leave the model nothing to
    extract but boilerplate."""
    if len(text) <= LEASE_MAX_CHARS:
        return text
    half = LEASE_MAX_CHARS // 2
    return text[:half] + "\n...\n" + text[-half:]


def _term_months(value: Any, unit: Any) -> Optional[int]:
    """A tenancy term expressed as a whole number of months, or None. Accepts a
    value in years or months; anything else (weeks, missing, non-positive) is
    rejected so it can't fabricate a bound."""
    try:
        count = int(value)
    except (TypeError, ValueError):
        return None
    if count <= 0:
        return None
    normalized = str(unit or "").strip().lower()
    if normalized.startswith("year"):
        return count * 12
    if normalized.startswith("month"):
        return count
    return None


def _last_day_of_month(year: int, month: int) -> int:
    if month == 12:
        return 31
    return (date(year, month + 1, 1) - timedelta(days=1)).day


def _add_months(anchor: date, months: int) -> date:
    total = anchor.month - 1 + months
    year = anchor.year + total // 12
    month = total % 12 + 1
    day = min(anchor.day, _last_day_of_month(year, month))
    return date(year, month, day)


def _end_from_term(start_iso: str, term_value: Any, term_unit: Any) -> Optional[str]:
    """The tenancy end date implied by a start date plus a term, as ISO text, or
    None. end = start + term - 1 day (a 2-year term from 1 Jan 2023 ends
    31 Dec 2024)."""
    months = _term_months(term_value, term_unit)
    if months is None:
        return None
    try:
        start = date.fromisoformat(start_iso)
    except (TypeError, ValueError):
        return None
    return (_add_months(start, months) - timedelta(days=1)).isoformat()


def _start_from_term(end_iso: str, term_value: Any, term_unit: Any) -> Optional[str]:
    """The tenancy start date implied by an end date plus a term (the inverse of
    _end_from_term), as ISO text, or None."""
    months = _term_months(term_value, term_unit)
    if months is None:
        return None
    try:
        end = date.fromisoformat(end_iso)
    except (TypeError, ValueError):
        return None
    return (_add_months(end, -months) + timedelta(days=1)).isoformat()


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
        if category == "lease":
            return self._extract_lease_document(_lease_input(cleaned))
        fields = _FIELD_TYPES.get(category)
        if not fields:
            return None

        content = self._invoke_text(
            self._build_prompt(category, cleaned[:MAX_INPUT_CHARS]), label=category)
        if content is None:
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

    def _extract_lease_document(self, text: str) -> Optional[Dict[str, Any]]:
        """Full tenancy-agreement extraction: the date/rent/term fields plus the
        separate utilities-liability clause read. Kept as its own path (not the
        generic semicolon prompt) because tenancy periods are the hardest field
        — worded countless ways, and often a start + a term rather than an
        explicit end date."""
        facts = self._extract_lease(text)
        clause_facts = self._extract_utilities_liability(text)
        if clause_facts:
            facts.update(clause_facts)
        if not [key for key in facts if key != "confidence"]:
            return None
        return facts

    def _extract_lease(self, text: str) -> Dict[str, Any]:
        """Date-aware lease field extraction. The model reports the start, the
        end (only if printed) and the term (a duration, if stated) as separate
        fields; the end (or start) is then computed here from start + term when
        the document gives a term but not both bounds — deterministic date math
        the model is not trusted to do."""
        payload = _loads_json_object(self._invoke_text(self._lease_prompt(text), label="lease"))
        if payload is None:
            return {}

        facts: Dict[str, Any] = {}
        tenant = str(payload.get("tenant_name") or "").strip()
        if tenant:
            facts["tenant_name"] = tenant[:120]
        for money in ("monthly_rent", "deposit", "renewal_fee"):
            value = self._coerce("lease", "amount", str(payload.get(money) or ""))
            if value is not None:
                facts[money] = value
        subtype = self._coerce("lease", "subtype", str(payload.get("subtype") or ""))
        if subtype is not None:
            facts["subtype"] = subtype

        start = self._coerce("lease", "date", str(payload.get("lease_start") or ""))
        end = self._coerce("lease", "date", str(payload.get("lease_end") or ""))
        term_value = payload.get("term_value")
        term_unit = payload.get("term_unit")
        # Explicit dates always win; a term only fills a genuinely missing bound.
        if start and not end:
            end = _end_from_term(start, term_value, term_unit)
        elif end and not start:
            start = _start_from_term(end, term_value, term_unit)
        if start:
            facts["lease_start"] = start
        if end:
            facts["lease_end"] = end

        try:
            facts["confidence"] = max(0.0, min(1.0, float(payload.get("confidence"))))
        except (TypeError, ValueError):
            pass
        return facts

    def _lease_prompt(self, text: str) -> str:
        """The tenancy-agreement prompt. Separates commencement, expiry and term
        so the model never has to do date arithmetic — it reports what is
        printed, and _extract_lease computes any missing bound."""
        return f"""You are extracting structured facts from a Malaysian tenancy
agreement. These are worded in many different ways — read the period wording
carefully.

Document text (may be truncated):
{text}

Return ONLY a JSON object, no markdown fences, shaped exactly like:
{{"tenant_name": "...", "monthly_rent": 0, "deposit": 0, "renewal_fee": 0,
 "subtype": "new", "lease_start": "YYYY-MM-DD", "lease_end": "YYYY-MM-DD",
 "term_value": 0, "term_unit": "years", "confidence": 0.0}}

Field rules:
- lease_start = the COMMENCEMENT date the tenancy begins. Wording that
  introduces it: "commencing/commences/commenced on", "commencing from",
  "starting", "with effect from", "effective", "for a term ... from", Malay
  "bermula pada", "mulai".
- lease_end = the date the tenancy ENDS. Wording: "expiring/expires on",
  "ending/ends on", "terminating on", "until", "up to and including", "to",
  Malay "hingga", "sehingga", "tamat pada". Include lease_end ONLY if the
  document prints an end date explicitly.
- term_value + term_unit = the DURATION, when the document states a length
  rather than (or as well as) an end date: "for a term of two (2) years" ->
  term_value 2, term_unit "years"; "a period of 24 months" -> term_value 24,
  term_unit "months"; Malay "tempoh dua tahun". term_unit must be exactly
  "years" or "months". Do NOT calculate the end date yourself — just report the
  start and the term; leave lease_end out when it is not printed.
- monthly_rent = the RENT PER MONTH. If it is written in words with the figure
  in brackets, use the figure: "Ringgit Malaysia Eight Thousand (RM8,000.00)"
  -> 8000. Never confuse the rent with the deposit.
- deposit = security deposit; renewal_fee = any fee to renew (renewals only).
- subtype = "renewal" if it renews or extends an existing tenancy, else "new".
- tenant_name = the tenant's full name.

Rules:
- Omit any field not clearly stated. NEVER guess or invent a value.
- Dates ISO YYYY-MM-DD. Amounts plain numbers, no currency or separators.
- Always include confidence 0.0-1.0.
""".strip()

    def _expense_prompt(self, text: str, retry_after: Optional[str] = None) -> str:
        """The expense line-item prompt. `retry_after` (the previous unparseable
        reply) turns it into a stricter re-ask that only reformats — the model
        already did the reading, it just has to emit valid JSON this time."""
        retry_preamble = ""
        if retry_after is not None:
            retry_preamble = (
                "Your previous reply could not be parsed as JSON. Do NOT change "
                "the charges you found — output the SAME information, but this "
                "time as ONLY a valid JSON object, no prose and no markdown.\n\n"
            )
        return f"""{retry_preamble}You are extracting expense line items from a Malaysian landlord's property
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
- A single bill usually lists SEVERAL charges (e.g. a maintenance/service
  charge AND a separate sinking fund). Output a SEPARATE OBJECT FOR EACH
  distinct charge line — never merge them and never stop at the first one.
- A one-off repair or replacement of a specific item (water pump, air-cond,
  plumbing, wiring, lift motor) is UPKEEP, NOT MAINTENANCE. Classify a charge
  as `maintenance` ONLY when it is the recurring building service/management
  charge from a JMB/MC — never a repair invoice.
- NEVER invent amounts.
- Dates must be ISO YYYY-MM-DD; period_year a 4-digit year. Include
  whichever the document states.
- If an insurance premium appears, also report policy_start and policy_end.
- For description, copy the charge's own wording as printed on THIS document,
  or omit it. NEVER copy the example values below — they are only a shape
  guide, and every value you return must come from THIS document.

Respond with ONLY a JSON object, no markdown fences, shaped exactly like:
{{"lines": [{{"subtype": "<one allowed subtype>", "description": "...",
 "amount": 0, "date": "YYYY-MM-DD", "period_year": 0}}],
 "policy_start": null, "policy_end": null, "confidence": 0.0}}
""".strip()

    def _extract_expense_lines(self, text: str) -> Optional[Dict[str, Any]]:
        """JSON line-item extraction for combined expense documents. A first
        unparseable reply gets exactly one stricter re-ask (silent-drop is the
        top complaint); a reply that parses but lists nothing is taken at face
        value — re-asking there would only invite a hallucinated line."""
        content = self._invoke_text(self._expense_prompt(text), label="expenses")
        payload = _loads_json_object(content)
        if payload is None:
            content = self._invoke_text(
                self._expense_prompt(text, retry_after=content or ""), label="expenses:retry")
            payload = _loads_json_object(content)

        # Deterministic recall floor: append any labeled charge the model
        # dropped (or missed entirely on an unparseable reply), keyed off the
        # same OCR text. Runs even when the LLM produced nothing parseable.
        llm_lines = validate_expense_lines(payload.get("lines")) if payload else []
        lines = backfill_expense_lines(text, llm_lines)
        if not lines:
            return None
        facts: Dict[str, Any] = {"expense_lines": lines}
        if payload:
            for key in ("policy_start", "policy_end"):
                value = self._coerce("expenses", "date", str(payload.get(key) or ""))
                if value is not None:
                    facts[key] = value
            try:
                facts["confidence"] = max(0.0, min(1.0, float(payload.get("confidence"))))
            except (TypeError, ValueError):
                pass
        return facts

    def _invoke_text(self, prompt: str, label: str = "") -> Optional[str]:
        """One LLM call returning stripped text, or None on failure. Kept
        non-raising so a call failure just degrades to 'no facts'. Every fact
        call funnels through here, so it is also the single place chat logging
        is captured (set FACT_CHAT_LOG to a file path to record prompts and raw
        replies for tuning)."""
        try:
            content = str(self._llm.invoke(prompt).content).strip()
        except Exception as e:
            print(f"Fact extraction LLM call failed: {e}")
            self._log_chat(label, prompt, f"<error: {e}>")
            return None
        self._log_chat(label, prompt, content)
        return content

    def _log_chat(self, label: str, prompt: str, response: str) -> None:
        """Append one prompt/response record to FACT_CHAT_LOG (JSONL) when the
        env var is set. Best-effort and never raises — logging must not break
        ingest."""
        path = os.getenv("FACT_CHAT_LOG")
        if not path:
            return
        try:
            with open(path, "a", encoding="utf-8") as handle:
                handle.write(json.dumps({
                    "ts": datetime.now().isoformat(timespec="seconds"),
                    "label": label,
                    "model": getattr(self._llm, "model", None),
                    "prompt": prompt,
                    "response": response,
                }, ensure_ascii=False) + "\n")
        except Exception as e:
            print(f"FACT_CHAT_LOG write failed (non-blocking): {e}")

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
        payload = _loads_json_object(self._invoke_text(prompt, label="utilities_liability"))
        if payload is None:
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
                pass
            # Malaysian bills print DD/MM/YYYY or DD-MM-YYYY. Normalise to ISO
            # (day first, never month first) so storage and every downstream
            # reader see one format; a shape we can't map stays dropped.
            match = re.fullmatch(r"\s*(\d{1,2})[/-](\d{1,2})[/-](\d{4})\s*", raw)
            if match:
                day, month, year = match.group(1), match.group(2), match.group(3)
                iso = f"{year}-{int(month):02d}-{int(day):02d}"
                try:
                    date.fromisoformat(iso)
                    return iso
                except ValueError:
                    return None
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
