"""Deterministic finance engine: pure functions, no LLM, no I/O.

Folds extracted facts into per-unit monthly income, per-property
Received Rent / Direct Expenses / Rental Income/Loss, portfolio Net P/L,
and Malaysian statutory rental income (s.4(d), YA = calendar year).
Malformed or missing facts are skipped silently — they surface through
missing_categories/caveats, never as errors.
"""
from __future__ import annotations

import re
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Set, Tuple

from rag.fact_extractor import (
    EXPENSE_SUBTYPE_CATEGORY,
    EXPENSE_SUBTYPE_RHYTHM,
    LANDLORD_BORNE_SUBTYPES,
    NEVER_DEDUCTIBLE_SUBTYPES,
    RENEWAL_ONLY_SUBTYPES,
)

_EXPENSE_LINE_LABELS = {
    "loan_interest": "Loan interest",
    "assessment_tax": "Assessment tax",
    "quit_rent": "Quit rent",
    "parcel_rent": "Parcel rent",
    "maintenance": "Maintenance fees",
    "sinking_fund": "Sinking fund",
    "insurance_premium": "Insurance premium",
    "upkeep": "Upkeep",
    "utilities": "Utilities",
    "late_penalty": "Late payment charge",
    "renovation": "Renovation",
    "loan_principal": "Loan principal",
    "management_fee": "Property management fee",
    "rent_collection": "Rent collection fee",
    "security_fee": "Security fee",
    "pest_control": "Pest control",
    "agent_commission": "Agent commission",
    "legal_fee": "Legal fees",
    "stamp_duty": "Stamp duty",
    "advertising": "Advertising",
    "sst": "Service tax (SST)",
}

# Categories that feed the fold; also the per-property completeness report.
FINANCE_CATEGORIES = ["rental_invoice", "loan", "tax", "upkeep", "maintenance", "insurance"]

STATUTORY_NOTE = "Estimate — for your tax agent"
LOSS_FLOOR_NOTE = (
    "Rental loss cannot be set off against other income and cannot be carried forward"
)
MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

_TAX_LABELS = {
    "assessment": "Assessment tax",
    "quit_rent": "Quit rent",
    "parcel_rent": "Parcel rent",
}


def _round2(value: float) -> float:
    return round(float(value), 2)


def _ym(value: Any) -> Optional[Tuple[int, int]]:
    """'YYYY-MM' or 'YYYY-MM-DD' -> (year, month); None when unparseable."""
    if not isinstance(value, str) or len(value) < 7:
        return None
    try:
        return (int(value[0:4]), int(value[5:7]))
    except ValueError:
        return None


def _amount(facts: Dict[str, Any], key: str) -> Optional[float]:
    value = facts.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _uploaded_key(doc: Dict[str, Any]):
    # Tuple so None (pre-feature docs) sorts oldest without comparing
    # naive/aware datetimes against each other.
    value = doc.get("uploaded_at")
    return (value is not None, value or datetime.min)


def _months_in_scope(year: int, today: date) -> List[int]:
    """Jan..Dec of the target year, future months excluded."""
    if year > today.year:
        return []
    if year == today.year:
        return list(range(1, today.month + 1))
    return list(range(1, 13))


def _scope_income(
    prop_docs: List[Dict[str, Any]],
    unit_id: Optional[str],
    year: int,
    months: List[int],
    exceptions: List[Dict[str, Any]],
):
    """Income rows for one scope (unit_id None = property-wide documents).

    Precedence per month: exception (marked unpaid) > invoice (actual) >
    lease coverage (derived) > vacant. A marked month still counts toward
    `rented` — the tenant occupied and expenses were incurred, only the
    income is excluded. Returns (month_rows, rented, actual_sum,
    derived_sum, vacant_months, derived_months, unpaid_months) where
    unpaid_months is a list of (month, reason, state, billed_amount)."""
    exception_by_month: Dict[int, Dict[str, Any]] = {}
    for exc in exceptions:
        if not isinstance(exc, dict) or exc.get("unit_id") != unit_id:
            continue
        ym = _ym(exc.get("month"))
        if ym is None or ym[0] != year:
            continue
        exception_by_month[ym[1]] = {
            "reason": exc.get("reason"),
            "state": exc.get("state") or "outstanding",
        }

    invoice_by_month: Dict[int, float] = {}
    for doc in sorted(
        (d for d in prop_docs
         if d.get("category") == "rental_invoice" and d.get("unit_id") == unit_id),
        key=_uploaded_key,
    ):
        facts = doc["extracted_facts"]
        amount = _amount(facts, "amount")
        ym = _ym(facts.get("period_month"))
        if amount is None or ym is None or ym[0] != year:
            continue
        invoice_by_month[ym[1]] = amount  # ascending sort: later upload wins

    lease_facts: Optional[Dict[str, Any]] = None
    for doc in sorted(
        (d for d in prop_docs
         if d.get("category") == "lease" and d.get("unit_id") == unit_id),
        key=_uploaded_key,
    ):
        facts = doc["extracted_facts"]
        if (
            _amount(facts, "monthly_rent") is not None
            and _ym(facts.get("lease_start"))
            and _ym(facts.get("lease_end"))
        ):
            lease_facts = facts  # most recent valid lease wins

    month_rows: List[Dict[str, Any]] = []
    rented = 0
    actual_sum = 0.0
    derived_sum = 0.0
    vacant_months: List[int] = []
    derived_months: List[int] = []
    unpaid_months: List[Tuple[int, Optional[str], str, Optional[float]]] = []
    for month in months:
        if month in exception_by_month:
            info = exception_by_month[month]
            reason, state = info["reason"], info["state"]
            billed = invoice_by_month.get(month)
            if billed is None and lease_facts is not None and (
                _ym(lease_facts["lease_start"]) <= (year, month) <= _ym(lease_facts["lease_end"])
            ):
                billed = _amount(lease_facts, "monthly_rent")
            row: Dict[str, Any] = {
                "month": month, "source": "unpaid", "amount": 0.0, "payment_state": state,
            }
            if billed is not None:
                row["billed_amount"] = _round2(billed)
            if reason:
                row["reason"] = reason
            month_rows.append(row)
            rented += 1
            unpaid_months.append((month, reason, state, billed))
            continue
        if month in invoice_by_month:
            amount = invoice_by_month[month]
            month_rows.append({"month": month, "source": "actual", "amount": _round2(amount)})
            actual_sum += amount
            rented += 1
            continue
        if lease_facts is not None and (
            _ym(lease_facts["lease_start"]) <= (year, month) <= _ym(lease_facts["lease_end"])
        ):
            amount = _amount(lease_facts, "monthly_rent")
            month_rows.append({"month": month, "source": "derived", "amount": _round2(amount)})
            derived_sum += amount
            rented += 1
            derived_months.append(month)
            continue
        month_rows.append({"month": month, "source": "vacant", "amount": 0.0})
        vacant_months.append(month)
    return month_rows, rented, actual_sum, derived_sum, vacant_months, derived_months, unpaid_months


def _renewal_years(prop_docs: List[Dict[str, Any]]) -> set:
    """Years in which a lease document marked `renewal` starts."""
    years = set()
    for doc in prop_docs:
        facts = doc.get("extracted_facts")
        if not isinstance(facts, dict) or doc.get("category") != "lease":
            continue
        if facts.get("subtype") != "renewal":
            continue
        ym = _ym(facts.get("lease_start"))
        if ym is not None:
            years.add(ym[0])
    return years


def _line_deductible(
    subtype: Optional[str],
    utilities_paid_by: Optional[str],
    letting_deductible: bool,
) -> bool:
    """Whether an expense line feeds direct_expenses.

    Penalties and capital outlay never do. Utilities do only when the
    property profile says the landlord bears them. Letting costs do only
    when a renewal tenancy for the year is on file — absence of evidence
    reads as a first letting, because the excluded line stays visible and
    correctable while a silent over-claim would not."""
    if subtype in NEVER_DEDUCTIBLE_SUBTYPES:
        return False
    if subtype in LANDLORD_BORNE_SUBTYPES:
        return utilities_paid_by == "landlord"
    if subtype in RENEWAL_ONLY_SUBTYPES:
        return letting_deductible
    return True


def _line_paid_by_landlord(
    subtype: Optional[str],
    utilities_paid_by: Optional[str],
) -> bool:
    """Whether the landlord actually bears this cost — feeds Overall Net P/L.

    Only utilities the tenant pays are excluded (not the landlord's outflow at
    all). Penalties, loan principal, capital works and first-letting costs are
    all real money the landlord paid, so they count toward Net P/L even though
    LHDN disallows them as statutory deductions."""
    if subtype in LANDLORD_BORNE_SUBTYPES:
        return utilities_paid_by == "landlord"
    return True


def _expense_lines(
    prop_docs: List[Dict[str, Any]],
    year: int,
    utilities_paid_by: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """Deductible expense lines allocated to the target year.

    Allocation rules (spec schema table): loan interest by the statement's
    period_year (agreements are informational only); tax by period_year
    (installments stay separate lines and sum naturally); upkeep by
    service_date's year; maintenance by period_start's year (fallback
    period_end); insurance premium by policy_start's year (fallback
    policy_end); lease renewal_fee only when subtype=renewal, by
    lease_start's year. Combined 'expenses' documents contribute one line
    per validated item, mapped to its finance category via
    EXPENSE_SUBTYPE_CATEGORY; a line belongs to the year when its
    period_year matches or its date falls in the year."""
    letting_deductible = year in _renewal_years(prop_docs)
    lines: List[Dict[str, Any]] = []
    for doc in prop_docs:
        facts = doc["extracted_facts"]
        category = doc.get("category")
        if category == "expenses":
            for item in (facts.get("expense_lines") or []):
                if not isinstance(item, dict):
                    continue
                subtype = item.get("subtype")
                mapped = EXPENSE_SUBTYPE_CATEGORY.get(subtype)
                amount = _amount(item, "amount")
                ym = _ym(item.get("date"))
                in_year = item.get("period_year") == year or (ym is not None and ym[0] == year)
                if mapped is None or amount is None or not in_year:
                    continue
                lines.append({
                    "doc_id": doc["doc_id"],
                    "category": mapped,
                    "subtype": subtype,
                    "description": item.get("description") or _EXPENSE_LINE_LABELS[subtype],
                    "amount": _round2(amount),
                    "date": item.get("date") or str(item.get("period_year") or year),
                    "unit_id": doc.get("unit_id"),
                    "deductible": _line_deductible(
                        subtype, utilities_paid_by, letting_deductible
                    ),
                    "paid_by_landlord": _line_paid_by_landlord(subtype, utilities_paid_by),
                })
            continue
        entry = None  # (amount, description, date_str)
        if category == "loan":
            if facts.get("subtype") == "interest_statement" \
                    and facts.get("period_year") == year:
                interest = _amount(facts, "interest_paid")
                if interest is not None:
                    entry = (interest, "Loan interest", str(year))
                principal = _amount(facts, "principal_paid")
                if principal is not None:
                    # Principal is the landlord's cash out but never a statutory
                    # deduction (LHDN: only interest deducts). It rides Net P/L.
                    lines.append({
                        "doc_id": doc["doc_id"],
                        "category": "loan",
                        "subtype": "loan_principal",
                        "description": "Loan principal",
                        "amount": _round2(principal),
                        "date": str(year),
                        "unit_id": doc.get("unit_id"),
                        "deductible": _line_deductible(
                            "loan_principal", utilities_paid_by, letting_deductible
                        ),
                        "paid_by_landlord": _line_paid_by_landlord(
                            "loan_principal", utilities_paid_by
                        ),
                    })
        elif category == "tax":
            amount = _amount(facts, "amount")
            if amount is not None and facts.get("period_year") == year:
                label = _TAX_LABELS.get(facts.get("subtype"), "Property tax")
                if facts.get("installment"):
                    label = f"{label} ({facts['installment']})"
                entry = (amount, label, str(year))
        elif category == "upkeep":
            amount = _amount(facts, "amount")
            ym = _ym(facts.get("service_date"))
            if amount is not None and ym and ym[0] == year:
                entry = (amount, facts.get("description") or "Upkeep", facts.get("service_date"))
        elif category == "maintenance":
            amount = _amount(facts, "amount")
            ym = _ym(facts.get("period_start")) or _ym(facts.get("period_end"))
            if amount is not None and ym and ym[0] == year:
                entry = (
                    amount,
                    facts.get("description") or "Maintenance fees & sinking fund",
                    facts.get("period_start") or facts.get("period_end"),
                )
        elif category == "insurance":
            premium = _amount(facts, "premium")
            ym = _ym(facts.get("policy_start")) or _ym(facts.get("policy_end"))
            if premium is not None and ym and ym[0] == year:
                entry = (premium, "Insurance premium", facts.get("policy_start") or facts.get("policy_end"))
        elif category == "lease":
            fee = _amount(facts, "renewal_fee")
            ym = _ym(facts.get("lease_start"))
            if facts.get("subtype") == "renewal" and fee is not None and ym and ym[0] == year:
                entry = (fee, "Tenancy renewal fee", facts.get("lease_start"))
        if entry is not None:
            amount, description, when = entry
            lines.append({
                "doc_id": doc["doc_id"],
                "category": category,
                "subtype": facts.get("subtype"),
                "description": description,
                "amount": _round2(amount),
                "date": when,
                "unit_id": doc.get("unit_id"),
                "deductible": _line_deductible(
                    facts.get("subtype"), utilities_paid_by, letting_deductible
                ),
                "paid_by_landlord": _line_paid_by_landlord(
                    facts.get("subtype"), utilities_paid_by
                ),
            })
    return lines


def _dedup_expense_lines(lines: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Collapse exact-duplicate expense lines that differ only by their source
    document — e.g. the same bill uploaded twice, or a scanner backfill line
    that also arrived through the LLM. Two lines are the same charge when their
    unit, category, subtype, description, date and amount all match; doc_id is
    deliberately excluded from the key so re-uploads collapse. Distinct tax
    installments ('... (1 of 2)' vs '(2 of 2)') differ in description and
    semi-annual payments differ in date, so neither is ever merged. Applied
    before every downstream sum, so lines, direct_expenses and contribution
    stay consistent (the app never recomputes)."""
    seen = set()
    deduped: List[Dict[str, Any]] = []
    for line in lines:
        key = (
            line.get("unit_id"),
            line.get("category"),
            line.get("subtype"),
            line.get("description"),
            line.get("date"),
            line.get("amount"),
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(line)
    return deduped


def _document_years(doc: Dict[str, Any]) -> List[int]:
    """All years a document's facts reference, for the coverage window
    fallback and per-year completeness. Mirrors _expense_lines' allocation
    fields (excluding 'expenses', handled separately since its lines carry
    their own categories)."""
    facts = doc.get("extracted_facts")
    if not isinstance(facts, dict):
        return []
    category = doc.get("category")
    years: List[int] = []

    def add_year(value):
        ym = _ym(value)
        if ym:
            years.append(ym[0])

    def add_period_year(value):
        if isinstance(value, int):
            years.append(value)

    if category == "lease":
        add_year(facts.get("lease_start"))
    elif category == "rental_invoice":
        add_year(facts.get("period_month"))
    elif category in ("loan", "tax"):
        add_period_year(facts.get("period_year"))
    elif category == "upkeep":
        add_year(facts.get("service_date"))
    elif category == "maintenance":
        add_year(facts.get("period_start"))
        add_year(facts.get("period_end"))
    elif category == "insurance":
        add_year(facts.get("policy_start"))
        add_year(facts.get("policy_end"))
    elif category == "expenses":
        for item in (facts.get("expense_lines") or []):
            if not isinstance(item, dict):
                continue
            add_period_year(item.get("period_year"))
            add_year(item.get("date"))
    return years


# Bundled 'expenses' lines name the assessment differently from a typed tax
# document's subtype; normalise so coverage counts evidence from both.
_EXPENSE_TAX_SUBTYPE = {
    "assessment_tax": "assessment",
    "quit_rent": "quit_rent",
    "parcel_rent": "parcel_rent",
}

# Typed single-subtype documents (not a bundled 'expenses' statement) whose
# own subtype maps onto the same tag vocabulary as expense_lines.
_TAX_SUBTYPE_TAG = {v: k for k, v in _EXPENSE_TAX_SUBTYPE.items()}
_LOAN_SUBTYPE_TAG = {"interest_statement": "loan_interest"}  # 'agreement' carries no expense tag
_CATEGORY_FIXED_TAG = {"maintenance": "maintenance", "insurance": "insurance_premium", "upkeep": "upkeep"}


def document_tags(category: str, facts: Optional[Dict[str, Any]]) -> List[Dict[str, str]]:
    """Sub-category tags for one document (design spec §9) — derived at read
    time from extracted_facts, never stored. Each tag carries its clustering
    rhythm so callers never need their own copy of which tags are periodic."""
    facts = facts or {}
    names: List[str] = []
    if category == "expenses":
        seen: Set[str] = set()
        for item in (facts.get("expense_lines") or []):
            if not isinstance(item, dict):
                continue
            subtype = item.get("subtype")
            if subtype in EXPENSE_SUBTYPE_CATEGORY and subtype not in seen:
                seen.add(subtype)
                names.append(subtype)
    elif category == "tax":
        tag = _TAX_SUBTYPE_TAG.get(facts.get("subtype"))
        if tag:
            names.append(tag)
    elif category == "loan":
        tag = _LOAN_SUBTYPE_TAG.get(facts.get("subtype"))
        if tag:
            names.append(tag)
    elif category in _CATEGORY_FIXED_TAG:
        names.append(_CATEGORY_FIXED_TAG[category])
    return [{"tag": name, "rhythm": EXPENSE_SUBTYPE_RHYTHM[name]} for name in names]


def _month_span(start: Tuple[int, int], end: Tuple[int, int]):
    """Inclusive (year, month) pairs walking from start to end."""
    year, month = start
    while (year, month) <= end:
        yield (year, month)
        month += 1
        if month > 12:
            year, month = year + 1, 1


def _maintenance_months_covered(prop_docs: List[Dict[str, Any]], year: int) -> Set[int]:
    """Distinct months of `year` with at least one extracted maintenance or
    sinking-fund fact — from a typed 'maintenance' document's period span,
    or a bundled 'expenses' line's own date. A line naming only period_year
    cannot fill a specific slot (spec §4), so it is not counted here even
    though the coarse yearly presence check in `years_with_category` still
    sees it."""
    months: Set[int] = set()
    for doc in prop_docs:
        facts = doc.get("extracted_facts")
        if not isinstance(facts, dict):
            continue
        category = doc.get("category")
        if category == "maintenance":
            start = _ym(facts.get("period_start")) or _ym(facts.get("period_end"))
            if start is None:
                continue
            end = _ym(facts.get("period_end")) or start
            for span_year, span_month in _month_span(start, end):
                if span_year == year:
                    months.add(span_month)
        elif category == "expenses":
            for item in (facts.get("expense_lines") or []):
                if not isinstance(item, dict):
                    continue
                if EXPENSE_SUBTYPE_CATEGORY.get(item.get("subtype")) != "maintenance":
                    continue
                ym = _ym(item.get("date"))
                if ym is not None and ym[0] == year:
                    months.add(ym[1])
    return months


_INSTALLMENT_RE = re.compile(r"(\d+)\s*(?:/|of|drpd|daripada)\s*(\d+)", re.IGNORECASE)


def _parse_installment(value: Any) -> Tuple[Optional[int], Optional[int]]:
    """(sequence, total) from a label like '1/2', '2 of 2', 'ansuran 1/3'.
    (None, None) when the text declares no sane numeric pair — including a
    council that simply never mentions installments, which must never
    false-trigger a gap."""
    if not isinstance(value, str):
        return (None, None)
    match = _INSTALLMENT_RE.search(value)
    if not match:
        return (None, None)
    sequence, total = int(match.group(1)), int(match.group(2))
    if sequence < 1 or total < 1 or sequence > total:
        return (None, None)
    return (sequence, total)


def _installment_gaps(
    prop_docs: List[Dict[str, Any]],
    year: int,
    suppressed_subtypes: Optional[Set[str]] = None,
) -> List[Dict[str, Any]]:
    """Tax subtypes for `year` whose own bills declare N installments but
    fewer distinct ones were uploaded — from a typed 'tax' document or an
    'installment' marker on a bundled 'expenses' line alike, so a strata
    statement that lists a second installment among its other charges
    counts exactly as a standalone tax bill would.

    The expectation is evidence-based: it comes only from an 'x/N' label on
    the landlord's own bill, never a hardcoded council schedule.

    `suppressed_subtypes` lets a landlord's 'mark unavailable' acknowledgement
    silence a gap here too — otherwise a permanently-missing second
    installment could never be closed out, contradicting the mechanism's own
    purpose."""
    seen: Dict[str, set] = {}
    expected: Dict[str, int] = {}

    def record(subtype: Optional[str], installment: Any, year_matches: bool) -> None:
        if not subtype or not year_matches:
            return
        sequence, total = _parse_installment(installment)
        if total is None:
            return
        expected[subtype] = max(expected.get(subtype, 0), total)
        seen.setdefault(subtype, set()).add(sequence)

    for doc in prop_docs:
        facts = doc.get("extracted_facts")
        if not isinstance(facts, dict):
            continue
        category = doc.get("category")
        if category == "tax":
            record(facts.get("subtype"), facts.get("installment"), facts.get("period_year") == year)
        elif category == "expenses":
            for item in (facts.get("expense_lines") or []):
                if not isinstance(item, dict):
                    continue
                subtype = _EXPENSE_TAX_SUBTYPE.get(item.get("subtype"))
                item_year = item.get("period_year")
                if not isinstance(item_year, int):
                    ym = _ym(item.get("date"))
                    item_year = ym[0] if ym else None
                record(subtype, item.get("installment"), item_year == year)

    gaps = []
    for subtype, total in sorted(expected.items()):
        if subtype in (suppressed_subtypes or set()):
            continue
        have = len(seen.get(subtype, set()))
        if have < total:
            gaps.append({
                "label": _TAX_LABELS.get(subtype, "Property tax"),
                "have": have,
                "expect": total,
            })
    return gaps


def _expected_tax_subtypes(prop: Dict[str, Any]) -> List[Tuple[str, Tuple[str, ...]]]:
    """(label, subtypes that satisfy it) pairs this property should hold.

    Assessment always. For the land-office tax, landed is always quit rent;
    strata may be billed parcel rent (individual strata titles) OR an
    apportioned quit rent via the management (master title), so either
    satisfies one shared slot — never assert which. Empty when the type is
    unknown, which keeps the generic 'tax' bucket."""
    property_type = prop.get("property_type")
    if property_type == "landed":
        return [("assessment", ("assessment",)), ("quit_rent", ("quit_rent",))]
    if property_type == "strata":
        return [
            ("assessment", ("assessment",)),
            ("land_office_tax", ("quit_rent", "parcel_rent")),
        ]
    return []


def _tax_subtype_years(prop_docs: List[Dict[str, Any]]) -> Dict[str, set]:
    """Years each tax subtype has evidence for, from typed tax documents and
    from bundled 'expenses' lines alike."""
    years: Dict[str, set] = {}
    for doc in prop_docs:
        facts = doc.get("extracted_facts")
        if not isinstance(facts, dict):
            continue
        category = doc.get("category")
        if category == "tax":
            subtype = facts.get("subtype")
            year = facts.get("period_year")
            if subtype and isinstance(year, int):
                years.setdefault(subtype, set()).add(year)
        elif category == "expenses":
            for item in (facts.get("expense_lines") or []):
                if not isinstance(item, dict):
                    continue
                subtype = _EXPENSE_TAX_SUBTYPE.get(item.get("subtype"))
                if subtype is None:
                    continue
                year = item.get("period_year")
                if not isinstance(year, int):
                    ym = _ym(item.get("date"))
                    year = ym[0] if ym else None
                if isinstance(year, int):
                    years.setdefault(subtype, set()).add(year)
    return years


def _expected_categories(prop: Dict[str, Any]) -> List[str]:
    """Finance categories this property should hold documents for.

    An unknown property_type keeps the full list, so properties registered
    before the profile existed behave exactly as they do today."""
    expected = list(FINANCE_CATEGORIES)
    property_type = prop.get("property_type")
    if property_type == "landed":
        expected.remove("maintenance")  # no management corporation
    elif property_type == "strata":
        expected.remove("insurance")  # inside the MC master policy
    if prop.get("has_mortgage") is False:
        expected.remove("loan")
    return expected


def _expected_record_categories(prop: Dict[str, Any]) -> List[str]:
    """The flattened category/tax-subtype vocabulary this property is ever
    expected to hold expense documents for — the Records grid's column
    set (spec §9). Excludes rental_invoice (rent has its own records
    surface, spec §9) and upkeep (never flagged missing, spec §2)."""
    tax_subtypes = _expected_tax_subtypes(prop)
    labels = [label for label, _ in tax_subtypes] if tax_subtypes else ["tax"]
    categories = [
        c for c in _expected_categories(prop)
        if c not in ("rental_invoice", "tax", "upkeep")
    ]
    return labels + categories


def _property_coverage(
    prop_docs: List[Dict[str, Any]],
    current_year: int,
    expected: Optional[List[str]] = None,
    tax_subtypes: Optional[List[Tuple[str, Tuple[str, ...]]]] = None,
    unavailable: Optional[Dict[int, Set[str]]] = None,
    track_from_year: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """Per-year document-completeness report from the property's earliest
    lease_start (fallback: earliest document year found) through
    current_year. rental_invoice is only flagged missing for years the
    lease actually covered; expense categories are flagged across the
    whole window regardless of tenancy."""
    lease_years: List[int] = []
    lease_spans: List[Tuple[Tuple[int, int], Tuple[int, int]]] = []
    all_years: List[int] = []
    for doc in prop_docs:
        all_years.extend(_document_years(doc))
        if doc.get("category") != "lease":
            continue
        facts = doc.get("extracted_facts")
        if not isinstance(facts, dict):
            continue
        start = _ym(facts.get("lease_start"))
        end = _ym(facts.get("lease_end"))
        if start:
            lease_years.append(start[0])
        if start and end:
            lease_spans.append((start, end))

    if lease_years:
        start_year = min(lease_years)
    elif all_years:
        start_year = min(all_years)
    else:
        return []
    start_year = min(start_year, current_year)
    if isinstance(track_from_year, int):
        start_year = max(start_year, track_from_year)

    years_covered_by_lease = {y for (s, e) in lease_spans for y in range(s[0], e[0] + 1)}

    years_with_category: Dict[str, set] = {c: set() for c in FINANCE_CATEGORIES}
    for doc in prop_docs:
        category = doc.get("category")
        facts = doc.get("extracted_facts")
        if not isinstance(facts, dict):
            continue
        if category == "expenses":
            for item in (facts.get("expense_lines") or []):
                if not isinstance(item, dict):
                    continue
                mapped = EXPENSE_SUBTYPE_CATEGORY.get(item.get("subtype"))
                if mapped is None or mapped not in years_with_category:
                    continue
                item_year = item.get("period_year")
                if not isinstance(item_year, int):
                    ym = _ym(item.get("date"))
                    item_year = ym[0] if ym else None
                if item_year is not None:
                    years_with_category[mapped].add(item_year)
        elif category in years_with_category:
            for year in _document_years(doc):
                years_with_category[category].add(year)

    subtype_years = _tax_subtype_years(prop_docs) if tax_subtypes else {}

    coverage: List[Dict[str, Any]] = []
    for year in range(start_year, current_year + 1):
        missing = []
        unavailable_list: List[str] = []
        unavailable_for_year = (unavailable or {}).get(year, set())
        partial_categories: List[Dict[str, Any]] = []
        for category in (expected if expected is not None else FINANCE_CATEGORIES):
            if category == "rental_invoice" and year not in years_covered_by_lease:
                continue  # no tenancy that year — nothing to invoice
            if category in unavailable_for_year:
                unavailable_list.append(category)
                continue
            if category == "tax" and tax_subtypes:
                for label, satisfying in tax_subtypes:
                    if label in unavailable_for_year:
                        unavailable_list.append(label)
                        continue
                    if not any(year in subtype_years.get(s, set()) for s in satisfying):
                        missing.append(label)
                continue
            if category == "maintenance":
                have = len(_maintenance_months_covered(prop_docs, year))
                if have == 0:
                    missing.append(category)
                elif have < 12:
                    partial_categories.append({"category": "maintenance", "have": have, "expect": 12})
                continue
            if year not in years_with_category[category]:
                missing.append(category)
        coverage.append({
            "year": year,
            "missing": missing,
            "partial_installments": _installment_gaps(prop_docs, year, unavailable_for_year),
            "partial_categories": partial_categories,
            "unavailable": unavailable_list,
        })
    return coverage


def _year_is_complete(coverage_rows: List[Dict[str, Any]], year: int) -> bool:
    """True when the requested year has no missing category, no partial
    tax installment, and no partial maintenance month — the only state
    that may safely feed the statutory estimate (spec §7.2)."""
    row = next((r for r in coverage_rows if r["year"] == year), None)
    if row is None:
        return False
    return not row["missing"] and not row["partial_installments"] and not row["partial_categories"]


def _month_label(value: Optional[str]) -> str:
    """'2025-08' -> 'Aug 2025'; passes through anything unparseable."""
    ym = _ym(value)
    if ym is None:
        return value or ""
    return f"{MONTH_NAMES[ym[1] - 1]} {ym[0]}"


def compute_finance_summary(
    *,
    year: int,
    today: date,
    documents: List[Dict[str, Any]],
    properties: List[Dict[str, Any]],
    units_by_property: Dict[str, List[Dict[str, Any]]],
    payment_exceptions: Optional[List[Dict[str, Any]]] = None,
    document_exceptions: Optional[List[Dict[str, Any]]] = None,
    rent_recoveries: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    months = _months_in_scope(year, today)

    property_blocks: List[Dict[str, Any]] = []
    caveats: List[str] = [
        "Income assumes rent billed equals rent received — invoices are the "
        "ledger, payment is not confirmed.",
    ]
    missing_categories: Dict[str, List[str]] = {}
    expense_breakdown: Dict[str, float] = {}
    total_received = 0.0
    total_derived = 0.0
    total_outstanding = 0.0
    total_expenses = 0.0
    statutory_sum = 0.0
    derived_notes: List[str] = []
    vacant_notes: List[str] = []
    unpaid_notes: List[str] = []
    share_notes: List[str] = []
    non_deductible_notes: List[str] = []
    incomplete_notes: List[str] = []

    for prop in properties:
        pid = prop["property_id"]
        name = prop.get("name") or pid
        share = float(prop.get("ownership_share") or 1.0)
        prop_docs = [
            d for d in documents
            if d.get("property_id") == pid and isinstance(d.get("extracted_facts"), dict)
        ]
        prop_exceptions = [
            e for e in (payment_exceptions or [])
            if isinstance(e, dict) and e.get("property_id") == pid
        ]
        prop_unavailable: Dict[int, set] = {}
        for exc in (document_exceptions or []):
            if not isinstance(exc, dict) or exc.get("property_id") != pid:
                continue
            exc_year, category = exc.get("year"), exc.get("category")
            if isinstance(exc_year, int) and category:
                prop_unavailable.setdefault(exc_year, set()).add(category)

        # Income scopes: each real unit, plus a synthetic whole-property scope
        # when property-wide income documents exist (or the property has no
        # units at all) — single-let houses work without units.
        scopes = [
            {"unit_id": u["unit_id"], "label": u.get("label") or u["unit_id"]}
            for u in units_by_property.get(pid, [])
        ]
        has_property_wide_income = any(
            d.get("unit_id") is None and d.get("category") in ("rental_invoice", "lease")
            for d in prop_docs
        )
        if has_property_wide_income or not scopes:
            scopes.append({"unit_id": None, "label": "Whole property"})

        expense_lines = _dedup_expense_lines(
            _expense_lines(prop_docs, year, prop.get("utilities_paid_by"))
        )
        lines_by_unit: Dict[Optional[str], List[Dict[str, Any]]] = {}
        for line in expense_lines:
            lines_by_unit.setdefault(line.get("unit_id"), []).append(line)

        unit_blocks: List[Dict[str, Any]] = []
        prop_actual = 0.0
        prop_derived = 0.0
        prop_outstanding = 0.0
        fractions: List[float] = []
        prorated_expenses = 0.0

        for scope in scopes:
            month_rows, rented, actual_sum, derived_sum, vacant, derived, unpaid = _scope_income(
                prop_docs, scope["unit_id"], year, months, prop_exceptions
            )
            fraction = (rented / len(months)) if months else 0.0
            fractions.append(fraction)
            unit_lines = (
                lines_by_unit.get(scope["unit_id"], [])
                if scope["unit_id"] is not None else []
            )
            unit_expense_total = sum(
                l["amount"] for l in unit_lines if l["deductible"]
            )
            prorated_expenses += unit_expense_total * fraction
            prop_actual += actual_sum
            prop_derived += derived_sum
            # Suppress the synthetic whole-property scope from the rendered rows
            # (and its would-be caveats) when it holds no income and the property
            # has real units — otherwise it shows as a confusing "Whole property
            # — RM 0.00" row beside the units that carry the data. Income,
            # expense and fraction totals above are all zero for an empty scope,
            # so this changes only what is displayed.
            if scope["unit_id"] is None and rented == 0 and units_by_property.get(pid):
                continue
            unit_blocks.append({
                "unit_id": scope["unit_id"],
                "label": scope["label"],
                "rented_months": rented,
                "contribution": _round2(actual_sum + derived_sum - unit_expense_total),
                "months": month_rows,
                "missing_invoice_months": vacant,
                "expense_lines": unit_lines,
            })
            if derived:
                derived_notes.append(
                    f"{name} — {scope['label']}: "
                    + ", ".join(MONTH_NAMES[m - 1] for m in derived)
                )
            for m in vacant:
                vacant_notes.append(
                    f"No invoice recorded for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                )
            for m, reason, state, billed in unpaid:
                if state == "written_off":
                    note = f"Written off as unrecoverable for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                else:
                    note = f"No payment received for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                    if billed:
                        prop_outstanding += billed
                if reason:
                    note += f": {reason}"
                unpaid_notes.append(note)

        # Property-level expenses (no unit) prorate by the property's average
        # rented fraction; a fully-rented year = factor 1.0 so the reference
        # scenario reproduces exactly.
        property_level_lines = lines_by_unit.get(None, [])
        avg_fraction = (sum(fractions) / len(fractions)) if fractions else 0.0
        prorated_expenses += sum(
            l["amount"] for l in property_level_lines if l["deductible"]
        ) * avg_fraction

        coverage_rows = _property_coverage(
            prop_docs, today.year, _expected_categories(prop),
            _expected_tax_subtypes(prop), prop_unavailable, prop.get("track_from_year"),
        )
        complete = _year_is_complete(coverage_rows, year)

        recovered_lines: List[Dict[str, Any]] = []
        prop_recovered = 0.0
        for r in (rent_recoveries or []):
            if not isinstance(r, dict) or r.get("property_id") != pid or r.get("received_year") != year:
                continue
            amount = _amount(r, "amount")
            if amount is None:
                continue
            prop_recovered += amount
            recovered_lines.append({
                "unit_id": r.get("unit_id"),
                "original_month": r.get("original_month"),
                "amount": _round2(amount),
                "label": f"Recovered rent — {_month_label(r.get('original_month'))}",
            })
        if recovered_lines:
            recovered_summary = ", ".join(
                f"{line['label']} (RM{line['amount']:,.2f})" for line in recovered_lines
            )
            unpaid_notes.append(f"{name}: recovered rent booked this year — {recovered_summary}")

        received = prop_actual + prop_derived + prop_recovered
        direct = sum(l["amount"] for l in expense_lines if l["deductible"])
        if complete:
            statutory_sum += share * (received - prorated_expenses)
        else:
            incomplete_notes.append(
                f"{name}: {year} records are incomplete — excluded from the statutory estimate."
            )

        contributing = {l["category"] for l in expense_lines if l["deductible"]}
        if any(row["source"] == "actual" for u in unit_blocks for row in u["months"]):
            contributing.add("rental_invoice")
        missing = [c for c in _expected_categories(prop) if c not in contributing]
        if missing:
            missing_categories[pid] = missing
            for category in missing:
                caveats.append(
                    f"No {category.replace('_', ' ')} document for {year} — {name}; "
                    "figures may be incomplete."
                )

        if share < 1.0:
            share_notes.append(f"Ownership share applied: {name} at {share:.0%}.")

        for line in expense_lines:
            if not line["deductible"]:
                continue
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0) + line["amount"]
            )

        excluded = _round2(sum(
            l["amount"] for l in expense_lines if not l["deductible"]
        ))
        if excluded:
            non_deductible_notes.append(
                f"{name}: RM{excluded:,.2f} of billed charges are not deductible "
                "(utilities, penalties, capital works) and are excluded from the "
                "figures."
            )

        if any(
            not l["deductible"] and l["subtype"] in RENEWAL_ONLY_SUBTYPES
            for l in expense_lines
        ):
            non_deductible_notes.append(
                f"{name}: letting costs are excluded as first-letting expenses "
                "— upload the renewal tenancy agreement if this was a renewal."
            )

        total_received += received
        total_derived += prop_derived
        total_outstanding += prop_outstanding
        total_expenses += direct

        property_blocks.append({
            "property_id": pid,
            "name": name,
            "ownership_share": share,
            "received_rent": _round2(received),
            "derived_rent": _round2(prop_derived),
            "outstanding_rent": _round2(prop_outstanding),
            "direct_expenses": _round2(direct),
            "rental_income_or_loss": _round2(received - direct),
            "units": unit_blocks,
            "expense_lines": expense_lines,
            "property_expense_lines": property_level_lines,
            "recovered_rent": recovered_lines,
            "complete": complete,
            "coverage": coverage_rows,
            "expected_categories": _expected_record_categories(prop),
        })

    statutory = _round2(statutory_sum)
    statutory_note = STATUTORY_NOTE
    if statutory < 0:
        statutory = 0.0
        statutory_note = f"{STATUTORY_NOTE}. {LOSS_FLOOR_NOTE}."

    if derived_notes:
        caveats.append(
            "Months backfilled from lease terms (no invoice): " + "; ".join(derived_notes)
        )
    caveats.extend(vacant_notes)
    caveats.extend(unpaid_notes)
    caveats.extend(share_notes)
    caveats.extend(non_deductible_notes)
    caveats.extend(incomplete_notes)

    return {
        "year": year,
        "totals": {
            "received_rent": _round2(total_received),
            "derived_rent": _round2(total_derived),
            "outstanding_rent": _round2(total_outstanding),
            "direct_expenses": _round2(total_expenses),
            "net_pl": _round2(total_received - total_expenses),
            "statutory_rental_income": statutory,
            "statutory_note": statutory_note,
        },
        "expense_breakdown": expense_breakdown,
        "properties": property_blocks,
        "caveats": caveats,
        "missing_categories": missing_categories,
    }
