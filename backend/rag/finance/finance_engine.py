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
from typing import Any, Callable, Dict, List, Optional, Set, Tuple

from rag.documents.fact_extractor import (
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

# Annual charges are billed once a year but often reprinted on every monthly
# strata statement. Collapse them per (unit, subtype, amount, year) so the one
# premium is not counted once per statement. Assessment tax is deliberately
# excluded — its instalments are legitimately several lines a year.
_ANNUAL_COLLAPSE_SUBTYPES = {"insurance_premium", "quit_rent", "parcel_rent"}


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
    prop: Optional[Dict[str, Any]] = None,
):
    """Income rows for one scope (unit_id None = property-wide documents).

    Precedence per month: exception (marked unpaid) > invoice (actual) >
    lease coverage (derived) > vacant. A marked month still counts toward
    `rented` — the tenant occupied and expenses were incurred, only the
    income is excluded.

    Returns (month_rows, rented, actual_full, actual_mine, derived_full,
    derived_mine, vacant_months, derived_months, unpaid_months). Income is
    split by the source document's share basis — a 'mine' figure is already
    the landlord's portion and must not be scaled again — and unpaid_months
    entries are (month, reason, state, billed_amount, basis)."""
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

    invoice_by_month: Dict[int, Tuple[float, str]] = {}
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
        # ascending sort: later upload wins, and brings its own basis with it
        invoice_by_month[ym[1]] = (amount, _document_share_basis(doc, prop or {}))

    lease_facts: Optional[Dict[str, Any]] = None
    lease_basis = "full"
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
            lease_basis = _document_share_basis(doc, prop or {})

    month_rows: List[Dict[str, Any]] = []
    rented = 0
    actual_full = 0.0
    actual_mine = 0.0
    derived_full = 0.0
    derived_mine = 0.0
    vacant_months: List[int] = []
    derived_months: List[int] = []
    unpaid_months: List[Tuple[int, Optional[str], str, Optional[float], str]] = []
    for month in months:
        if month in exception_by_month:
            info = exception_by_month[month]
            reason, state = info["reason"], info["state"]
            billed, billed_basis = None, "full"
            if month in invoice_by_month:
                billed, billed_basis = invoice_by_month[month]
            elif lease_facts is not None and (
                _ym(lease_facts["lease_start"]) <= (year, month) <= _ym(lease_facts["lease_end"])
            ):
                billed, billed_basis = _amount(lease_facts, "monthly_rent"), lease_basis
            row: Dict[str, Any] = {
                "month": month, "source": "unpaid", "amount": 0.0, "payment_state": state,
            }
            if billed is not None:
                row["billed_amount"] = _round2(billed)
                row["share_basis"] = billed_basis
            if reason:
                row["reason"] = reason
            month_rows.append(row)
            rented += 1
            unpaid_months.append((month, reason, state, billed, billed_basis))
            continue
        if month in invoice_by_month:
            amount, basis = invoice_by_month[month]
            month_rows.append({"month": month, "source": "actual",
                               "amount": _round2(amount), "share_basis": basis})
            if basis == "mine":
                actual_mine += amount
            else:
                actual_full += amount
            rented += 1
            continue
        if lease_facts is not None and (
            _ym(lease_facts["lease_start"]) <= (year, month) <= _ym(lease_facts["lease_end"])
        ):
            amount = _amount(lease_facts, "monthly_rent")
            month_rows.append({"month": month, "source": "derived",
                               "amount": _round2(amount), "share_basis": lease_basis})
            if lease_basis == "mine":
                derived_mine += amount
            else:
                derived_full += amount
            rented += 1
            derived_months.append(month)
            continue
        month_rows.append({"month": month, "source": "vacant", "amount": 0.0})
        vacant_months.append(month)
    return (month_rows, rented, actual_full, actual_mine, derived_full, derived_mine,
            vacant_months, derived_months, unpaid_months)


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
    prop: Optional[Dict[str, Any]] = None,
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
    period_year matches or its date falls in the year.

    Every emitted line carries `share_basis`, copied from its source document
    (see _document_share_basis). It is internal bookkeeping — _scaled_lines
    strips it from everything the payload renders."""
    letting_deductible = year in _renewal_years(prop_docs)
    lines: List[Dict[str, Any]] = []
    for doc in prop_docs:
        facts = doc["extracted_facts"]
        category = doc.get("category")
        basis = _document_share_basis(doc, prop or {})
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
                    "share_basis": basis,
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
                        "share_basis": basis,
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
                "share_basis": basis,
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
    stay consistent (the app never recomputes). Annual-cadence subtypes (see
    _ANNUAL_COLLAPSE_SUBTYPES) collapse instead to one per (unit, subtype,
    amount, year) — they're often reprinted on every monthly statement with a
    different date each time, so the exact-line key alone would not catch
    them; all other subtypes keep the exact-line key. Loan lines (category
    'loan') are dated with a fixed str(year) and a fixed description ('Loan
    interest' / 'Loan principal'), so two genuinely distinct statements in
    the same year with equal interest (or equal principal) would otherwise
    collapse to one — under-counting real cash out. Loans have no
    reprint-across-monthly-statements problem the way annual strata/insurance
    charges do (each is a distinct uploaded document), so doc_id is folded
    into their key as a per-statement discriminator; an exact reprocessing
    duplicate (same doc_id) still collapses."""
    seen = set()
    deduped: List[Dict[str, Any]] = []
    for line in lines:
        subtype = line.get("subtype")
        if subtype in _ANNUAL_COLLAPSE_SUBTYPES:
            ym = _ym(line.get("date"))
            year = ym[0] if ym is not None else line.get("date")
            key = ("__annual__", line.get("unit_id"), subtype, line.get("amount"), year)
        elif line.get("category") == "loan":
            key = (line.get("unit_id"), line.get("category"), subtype,
                   line.get("description"), line.get("date"), line.get("amount"),
                   line.get("doc_id"))
        else:
            key = (line.get("unit_id"), line.get("category"), subtype,
                   line.get("description"), line.get("date"), line.get("amount"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(line)
    return deduped


# The two ways a document can state an amount. 'full' is what the engine has
# always assumed and is the default at every step of the resolution below, so
# a landlord who never answers sees no change.
_SHARE_BASES = ("full", "mine")


def _document_share_basis(doc: Dict[str, Any], prop: Dict[str, Any]) -> str:
    """Which basis applies to one document (spec §3), first match wins:

    1. the document's own `share_basis` (set from the upload review sheet)
    2. the property's exception for that document's category
    3. the property's default
    4. 'full'

    Step 2 keys on the *document's* category, so a bundled 'expenses'
    statement — whose category is not one of the six a landlord can except —
    only ever takes step 1 or step 3. That is deliberate: a combined statement
    can mix bases, and the per-document answer is how it gets corrected.

    Step 2 is skipped entirely for a bundled 'expenses' document, even if
    `share_basis_exceptions` happens to carry an 'expenses' key (it never
    legitimately should, since the UI only ever writes the six offered
    categories, but the engine does not trust that and enforces it
    directly).
    """
    own = doc.get("share_basis")
    if own in _SHARE_BASES:
        return own
    exceptions = prop.get("share_basis_exceptions")
    if isinstance(exceptions, dict) and doc.get("category") != "expenses":
        by_category = exceptions.get(doc.get("category"))
        if by_category in _SHARE_BASES:
            return by_category
    default = prop.get("share_basis_default")
    return default if default in _SHARE_BASES else "full"


def _basis_share(basis: Optional[str], share: float) -> float:
    """The share that applies to one figure. A figure already stated at the
    landlord's portion is used verbatim; anything else is the whole
    property's and scales."""
    return 1.0 if basis == "mine" else share


# A typed loan document's interest line takes its subtype straight from the
# extracted facts ('interest_statement'); its principal line is hardcoded to
# 'loan_principal'. A bundled 'expenses' statement uses 'loan_interest' /
# 'loan_principal'. Three distinct spellings, and every one must be here — a
# missing spelling halves that document at partial share with a green suite.
# Keying off line["category"] == "loan" does NOT work either, because a
# bundled principal line maps to category 'loan_principal', not 'loan'.
_LOAN_EXEMPT_SUBTYPES = {"interest_statement", "loan_interest", "loan_principal"}


def _line_share(line: Dict[str, Any], share: float) -> float:
    """Loan interest and principal are the landlord's own borrowing, not a cost
    shared with co-owners, so they are never scaled by ownership share — and
    that beats basis, because basis is a claim about what a statement shows,
    not about who owes the money. A line from a document declared 'mine'
    already states the landlord's portion, so scaling it again would file a
    quarter of the truth at half ownership. Every other expense line scales
    normally."""
    if line.get("subtype") in _LOAN_EXEMPT_SUBTYPES:
        return 1.0
    return _basis_share(line.get("share_basis"), share)


def _share_for_unit(
    unit_id: Optional[str],
    unit_shares: Dict[str, float],
    property_share: float,
) -> float:
    """The ownership share that applies to an income scope or an expense line.

    A unit's own share wins. Anything not attributable to a unit — the
    synthetic whole-property income scope, a building-wide loan or quit rent —
    falls back to the property's own share, because it is not attributable to
    any one unit's co-ownership arrangement.

    A unit with no stored override is absent from `unit_shares` (not present
    as 1.0), so it inherits. That distinction is the whole point: a 50%-owned
    property whose units were never touched must stay at 50%.
    """
    if unit_id is None:
        return property_share
    return unit_shares.get(unit_id, property_share)


def _scaled_lines(
    lines: List[Dict[str, Any]],
    share_for: Callable[[Optional[str]], float],
) -> List[Dict[str, Any]]:
    """Copy expense lines with amounts at the share that applies to each line.

    Never mutates the input. The unscaled lines stay the basis for every
    property-level sum, so scaling is applied exactly once and no sum can be
    scaled twice. `share_for` maps a line's `unit_id` to its share — a unit's
    own override, or the property's for a line belonging to no unit.

    `share_basis` is internal and is removed from every copy, so a property
    with a stored basis answer renders a payload identical to one without
    wherever the figures are identical.

    A line whose resolved share is 1.0 is copied through unchanged and carries
    no `full_amount`, so a wholly-owned property's payload is content-identical
    to before. Below 1.0 each scaled line also carries `full_amount`, the
    source document's face value, so the app can show "your 50% of RM 1,200.00"
    beside the scaled figure. Loan lines and lines already stated at the
    landlord's share (see _line_share) resolve to 1.0 and so take the same
    unchanged path — there is no second figure to show.
    """
    out: List[Dict[str, Any]] = []
    for line in lines:
        line_share = _line_share(line, share_for(line.get("unit_id")))
        rendered = {k: v for k, v in line.items() if k != "share_basis"}
        if line_share == 1.0:
            out.append(rendered)
            continue
        rendered["amount"] = _round2(line_share * line["amount"])
        rendered["full_amount"] = _round2(line["amount"])
        out.append(rendered)
    return out


def _scaled_month_rows(rows: List[Dict[str, Any]], share: float) -> List[Dict[str, Any]]:
    """Copy month rows with amounts at the share that applies to each row.

    Mirrors _scaled_lines: never mutates the input, and below the applicable
    share carries the source figure in `full_amount` / `full_billed_amount` so
    the app can show "your 50% of RM 1,200.00" beside the scaled figure. A row
    whose source document is at basis 'mine' is already the landlord's figure
    and is copied through unscaled with no face value beside it.

    `share_basis` is internal and is removed from every copy, so a property
    with a stored basis answer renders a payload identical to one without
    wherever the figures are identical.
    """
    out: List[Dict[str, Any]] = []
    for row in rows:
        row_share = _basis_share(row.get("share_basis"), share)
        scaled = {k: v for k, v in row.items() if k != "share_basis"}
        if row_share != 1.0:
            if row.get("amount"):
                scaled["amount"] = _round2(row_share * row["amount"])
                scaled["full_amount"] = _round2(row["amount"])
            if row.get("billed_amount"):
                scaled["billed_amount"] = _round2(row_share * row["billed_amount"])
                scaled["full_billed_amount"] = _round2(row["billed_amount"])
        out.append(scaled)
    return out


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
    loan_expected_for: Optional[Callable[[int], bool]] = None,
) -> List[Dict[str, Any]]:
    """Per-year document-completeness report from the property's earliest
    lease_start (fallback: earliest document year found) through
    current_year. rental_invoice is only flagged missing for years the
    lease actually covered; expense categories are flagged across the
    whole window regardless of tenancy. `loan_expected_for` filters the
    'loan' category per year (mortgage settlement); omitted means every
    year in the window expects it, which is today's behaviour."""
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
            if category == "loan" and loan_expected_for is not None \
                    and not loan_expected_for(year):
                continue  # settled mortgage — this year expects nothing
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


def _manual_loan_documents(
    manual_loan_entries: Optional[List[Dict[str, Any]]], year: int
) -> List[Dict[str, Any]]:
    """Turn manually-entered loan figures for the target year into synthetic
    loan documents, so they ride the exact same loan branch of _expense_lines
    (interest -> deductible+landlord-paid, principal -> landlord-paid only) and
    the same doc-id-discriminated loan dedup as uploaded statements. A synthetic
    doc_id 'manual__{property}__{unit_id}__{period}' keeps each period distinct
    from every other manual period and from any uploaded statement. Zero/absent
    interest or principal is omitted so no empty line is emitted."""
    docs: List[Dict[str, Any]] = []
    for entry in (manual_loan_entries or []):
        if not isinstance(entry, dict) or entry.get("year") != year:
            continue
        month = entry.get("month")
        period = f"{year}-{int(month):02d}" if month else str(year)
        unit_id = entry.get("unit_id")
        unit_seg = f"{unit_id}__" if unit_id else ""
        facts: Dict[str, Any] = {"subtype": "interest_statement", "period_year": year}
        interest = _amount(entry, "interest_paid")
        principal = _amount(entry, "principal_paid")
        if interest is not None and interest > 0:
            facts["interest_paid"] = interest
        if principal is not None and principal > 0:
            facts["principal_paid"] = principal
        docs.append({
            "doc_id": f"manual__{entry.get('property_id')}__{unit_seg}{period}",
            "property_id": entry.get("property_id"),
            "unit_id": unit_id,
            "unit_label": None,
            "category": "loan",
            "extracted_facts": facts,
            "uploaded_at": None,
        })
    return docs


def _loan_settled_before(
    prop: Dict[str, Any], year: int, month: Optional[int] = None
) -> bool:
    """Whether a recorded settlement date puts this period *after* the final
    payment. The settlement month itself, and everything before it, is not
    settled — those periods still owe figures and must still reconcile.

    Deliberately says nothing about has_mortgage: this is only ever "did the
    landlord tell us the loan finished, and is this period after that". A
    malformed or absent mortgage_settled_on is treated as unset, so a bad value
    can never silently suppress a period's expectation."""
    settled = prop.get("mortgage_settled_on")
    if not settled:
        return False
    try:
        s_year, s_month = int(str(settled)[:4]), int(str(settled)[5:7])
    except (TypeError, ValueError):
        return False
    if not (1 <= s_month <= 12):
        return False
    if year != s_year:
        return year > s_year
    return month is not None and month > s_month


def _loan_expected_for(
    prop: Dict[str, Any], year: int, month: Optional[int] = None
) -> bool:
    """Whether loan figures are *tracked for completeness* in a period.

    Requires an affirmed mortgage — an unanswered one is not tracked. This is
    the completeness predicate only; do NOT reuse it to decide whether a loan
    *document* is expected. Those two differ precisely on the unanswered case:
    an unanswered mortgage is still nudged for a loan document (conservative —
    see _expected_categories, which drops 'loan' only on an explicit False) but
    is not held to a completeness standard it never opted into. Collapsing them
    tells every pre-existing property its year is complete when it is not.

    A settled mortgage stops expecting figures after its final month; history
    before it is unaffected, and has_mortgage stays True on a settled property
    because every year up to settlement must still reconcile."""
    if prop.get("has_mortgage") is not True:
        return False
    return not _loan_settled_before(prop, year, month)


def _loan_completeness(
    prop: Dict[str, Any],
    units: List[Dict[str, Any]],
    prop_docs: List[Dict[str, Any]],
    manual_entries: List[Dict[str, Any]],
    exemptions: List[Dict[str, Any]],
    year: int,
    months: List[int],
) -> tuple:
    """Per-unit loan resolution for the manual-entry button gate. A unit is
    resolved when it is marked no-loan, has an uploaded loan statement for the
    year, or has manual figures covering the cadence (annual: any entry;
    monthly: every in-scope month). Only meaningful for a mortgaged property in
    a year that still expects loan figures — otherwise returns (False, {})."""
    if not _loan_expected_for(prop, year):
        return False, {}
    cadence = prop.get("loan_input_cadence") or "annual"
    # Months past the settled month in the settlement year were never owed,
    # so a monthly-cadence property is not incomplete for lacking them.
    months = [m for m in months if _loan_expected_for(prop, year, m)]
    exempt_units = {e.get("unit_id") for e in exemptions}
    months_by_unit: Dict[Optional[str], set] = {}
    any_by_unit: set = set()
    for e in manual_entries:
        if e.get("year") != year:
            continue
        uid = e.get("unit_id")
        any_by_unit.add(uid)
        m = e.get("month")
        if m is not None:
            months_by_unit.setdefault(uid, set()).add(int(m))
    upload_units: set = set()
    for d in prop_docs:
        facts = d.get("extracted_facts")
        if d.get("category") == "loan" and isinstance(facts, dict) \
                and facts.get("period_year") == year \
                and not str(d.get("doc_id") or "").startswith("manual__"):
            upload_units.add(d.get("unit_id"))

    def resolved(uid):
        if uid in exempt_units or uid in upload_units:
            return True
        if cadence == "monthly":
            return set(months) <= months_by_unit.get(uid, set())
        return uid in any_by_unit

    status_by_unit: Dict[Optional[str], str] = {}
    incomplete = False
    if units:
        for u in units:
            uid = u["unit_id"]
            if uid in exempt_units:
                status_by_unit[uid] = "no_loan"
            elif resolved(uid):
                status_by_unit[uid] = "complete"
            else:
                status_by_unit[uid] = "incomplete"
                incomplete = True
    else:
        if resolved(None):
            status_by_unit[None] = "complete"
        else:
            status_by_unit[None] = "incomplete"
            incomplete = True
    return incomplete, status_by_unit


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
    manual_loan_entries: Optional[List[Dict[str, Any]]] = None,
    unit_loan_exemptions: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    months = _months_in_scope(year, today)
    documents = list(documents) + _manual_loan_documents(manual_loan_entries, year)

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
    total_landlord_expenses = 0.0
    statutory_sum = 0.0
    net_pl_sum = 0.0
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

        # Unit-level overrides for this property. Only units that actually
        # store a share appear here — absence means "inherit `share`", which
        # is why this is not a dict comprehension with a 1.0 default.
        unit_shares: Dict[str, float] = {}
        for u in units_by_property.get(pid, []):
            raw = u.get("ownership_share")
            if raw is None:
                continue
            try:
                unit_shares[u["unit_id"]] = float(raw)
            except (TypeError, ValueError):
                continue

        def share_for(unit_id: Optional[str]) -> float:
            # Closes over this iteration's `unit_shares` and `share`, and is
            # only ever called within this iteration.
            return _share_for_unit(unit_id, unit_shares, share)

        expense_lines = _dedup_expense_lines(
            _expense_lines(prop_docs, year, prop.get("utilities_paid_by"), prop)
        )
        prop_manual_entries = [
            e for e in (manual_loan_entries or [])
            if isinstance(e, dict) and e.get("property_id") == pid
        ]
        prop_exemptions = [
            x for x in (unit_loan_exemptions or [])
            if isinstance(x, dict) and x.get("property_id") == pid
        ]
        manual_loan_incomplete, loan_status_by_unit = _loan_completeness(
            prop, units_by_property.get(pid, []), prop_docs,
            prop_manual_entries, prop_exemptions, year, months,
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
            (month_rows, rented, actual_full, actual_mine, derived_full, derived_mine,
             vacant, derived, unpaid) = _scope_income(
                prop_docs, scope["unit_id"], year, months, prop_exceptions, prop
            )
            scope_share = share_for(scope["unit_id"])
            # Scaled here, per scope and per basis, then summed. `actual_sum`
            # and `derived_sum` are the landlord's own figures from here down.
            actual_sum = scope_share * actual_full + actual_mine
            derived_sum = scope_share * derived_full + derived_mine
            fraction = (rented / len(months)) if months else 0.0
            fractions.append(fraction)
            unit_lines = (
                lines_by_unit.get(scope["unit_id"], [])
                if scope["unit_id"] is not None else []
            )
            # Proration keeps using the real-unit lines only. The property-level
            # lines are prorated once, below, by avg_fraction — feeding them in
            # here as well would double-count them in the statutory total.
            prorated_expenses += fraction * sum(
                _line_share(l, share_for(l.get("unit_id"))) * l["amount"]
                for l in unit_lines if l["deductible"]
            )
            # Display lines: the synthetic whole-property scope shows the
            # property-level lines (a building-wide loan, quit rent) that belong
            # to no unit. For a single-let house that scope IS the property, so
            # showing an empty breakdown there hid the landlord's loan entirely.
            # Unit blocks are display-only — every total sums from `expense_lines`
            # — so widening what they show cannot move a total.
            display_lines = (
                unit_lines if scope["unit_id"] is not None
                else lines_by_unit.get(None, [])
            )
            # `actual_sum` / `derived_sum` are already scaled (per scope, per
            # basis — see above), so this is a plain accumulation, not a
            # second scaling.
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
            # Every figure the panel stacks — the gross line, the month strip
            # beneath it, and the two contribution totals — is built from the
            # SAME rounded rows the panel is handed (`scaled_months` /
            # `scaled_lines`, each computed once and reused as `months` /
            # `expense_lines`), not re-derived from an unrounded scalar.
            # `_round2(share * (actual_sum + derived_sum))` (round-the-sum)
            # is not the same number as summing the rounded per-row amounts
            # the strip renders (sum-the-rounded) — they disagree by a cent
            # at ordinary values (e.g. rent 1000.01 x12 at share 0.5: strip
            # sums to 6000.00, round-the-sum gives 6000.06) — so gross has to
            # be summed from `scaled_months` for the strip to sum to the
            # header by construction. `full_gross_income` is built the same
            # way, from each row's `full_amount`, so the percentage the app
            # derives as `gross / full_gross` stays internally coherent:
            # numerator and denominator are sums of the same per-row
            # roundings, not a rounded sum paired with a summed round.
            scaled_lines = _scaled_lines(display_lines, share_for)
            scaled_months = _scaled_month_rows(month_rows, scope_share)
            income_sources = ("actual", "derived")
            gross_income = _round2(sum(
                m["amount"] for m in scaled_months if m["source"] in income_sources
            ))
            block: Dict[str, Any] = {
                "unit_id": scope["unit_id"],
                "label": scope["label"],
                "ownership_share": scope_share,
                "rented_months": rented,
                "gross_income": gross_income,
                "contribution": _round2(gross_income - sum(
                    l["amount"] for l in scaled_lines if l["paid_by_landlord"]
                )),
                "statutory_contribution": _round2(gross_income - sum(
                    l["amount"] for l in scaled_lines if l["deductible"]
                )),
                "months": scaled_months,
                "missing_invoice_months": vacant,
                "expense_lines": scaled_lines,
                "loan_status": loan_status_by_unit.get(scope["unit_id"]),
            }
            # Emitted whenever it differs — i.e. whenever something really was
            # scaled. A unit whose income is entirely at basis 'mine' has no
            # second figure to show even at a partial share, and a unit with no
            # income at all has nothing to compare.
            full_gross_income = _round2(sum(
                m.get("full_amount", m["amount"]) for m in scaled_months
                if m["source"] in income_sources
            ))
            if full_gross_income != gross_income:
                block["full_gross_income"] = full_gross_income
            unit_blocks.append(block)
            if derived:
                derived_notes.append(
                    f"{name} — {scope['label']}: "
                    + ", ".join(MONTH_NAMES[m - 1] for m in derived)
                )
            for m in vacant:
                vacant_notes.append(
                    f"No invoice recorded for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                )
            for m, reason, state, billed, billed_basis in unpaid:
                if state == "written_off":
                    note = f"Written off as unrecoverable for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                else:
                    note = f"No payment received for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                    if billed:
                        prop_outstanding += _basis_share(billed_basis, scope_share) * billed
                if reason:
                    note += f": {reason}"
                unpaid_notes.append(note)

        # Property-level expenses (no unit) prorate by the property's average
        # rented fraction; a fully-rented year = factor 1.0 so the reference
        # scenario reproduces exactly.
        property_level_lines = lines_by_unit.get(None, [])
        avg_fraction = (sum(fractions) / len(fractions)) if fractions else 0.0
        prorated_expenses += avg_fraction * sum(
            _line_share(l, share_for(l.get("unit_id"))) * l["amount"]
            for l in property_level_lines if l["deductible"]
        )

        # Every expense-shaped total this property card stacks — EXPENSES and
        # the Net P/L / rental-income-or-loss beneath it — must reconcile
        # with what's actually printed on screen. Build the scaled line list
        # ONCE, exactly as it will be emitted below (`expense_lines` in the
        # block), and derive every total by summing ITS rounded rows —
        # mirrors the unit block's scaled_lines / scaled_months pattern.
        scaled_expense_lines = _scaled_lines(expense_lines, share_for)

        # Net P/L uses the landlord's full cash out (not prorated by occupancy,
        # matching how direct/statutory `direct` is summed below).
        landlord_paid = sum(
            l["amount"] for l in scaled_expense_lines if l["paid_by_landlord"]
        )

        coverage_rows = _property_coverage(
            prop_docs, today.year, _expected_categories(prop),
            _expected_tax_subtypes(prop), prop_unavailable, prop.get("track_from_year"),
            # Settlement only — NOT _loan_expected_for. A property whose
            # mortgage question was never answered must keep being nudged for
            # its loan document; only a date the landlord actually recorded
            # stops the asking.
            loan_expected_for=lambda y: not _loan_settled_before(prop, y),
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

        direct = sum(
            l["amount"] for l in scaled_expense_lines if l["deductible"]
        )

        # prop_actual / prop_derived / prop_outstanding arrive already scaled,
        # each by its own scope's share. Recovered rent is exempt (it is typed
        # in by the landlord at their own share — see the recovery sheet), so
        # nothing here is multiplied again.
        s_received = prop_actual + prop_derived + prop_recovered
        s_derived = prop_derived
        s_outstanding = prop_outstanding
        s_direct = direct
        s_landlord_paid = landlord_paid
        s_prorated = prorated_expenses

        # Round once, then subtract — the same rule as scaled_expense_lines
        # above. `_round2(a) - _round2(b)` is not `_round2(a - b)`; the
        # property card renders `a` and `b` as its RENTAL INCOME / EXPENSES
        # mini-stats and the subtraction result beneath them, so the total
        # must be built from the same rounded figures the card displays,
        # not re-derived from unrounded scalars.
        #
        # `s_prorated` is the one exception: `prorated_expenses` never
        # appears on screen anywhere (it only feeds the statutory-income tax
        # figure below), so there is no displayed subtraction for rounding
        # it early to protect. Rounding it early only injects avoidable
        # error into that tax figure, so it stays exact and only the
        # displayed operand (`r_received`) is rounded before the subtraction.
        r_received = _round2(s_received)
        r_derived = _round2(s_derived)
        r_outstanding = _round2(s_outstanding)
        r_direct = _round2(s_direct)
        r_landlord_paid = _round2(s_landlord_paid)

        # These per-property rounded figures are exactly what the cards
        # beneath the OVERALL totals row show (residex_app's
        # finance_summary_panel.dart stacks OVERALL RENTAL INCOME / OVERALL
        # EXPENSES / OVERALL NET PROFIT/LOSS as the identical subtraction,
        # one level up from the per-property card), so every cross-property
        # accumulator that feeds a displayed total is built from the
        # rounded per-property values — never from the raw scalars —
        # or the totals row can drift from the sum of the cards shown
        # beneath it. `s_prorated` itself still stays exact (see above —
        # it is never displayed on its own), but the PER-PROPERTY
        # statutory figure it produces (`r_received - s_prorated`) is
        # displayed on the card, so — same as every sibling accumulator
        # here — it is rounded to that displayed precision before being
        # added into `statutory_sum`. Without this, `statutory_sum` would
        # be the only accumulator summing an unrounded per-property
        # difference, and the totals row would silently drift from the
        # sum of the cards' own `statutory_contribution` values.
        total_received += r_received
        total_derived += r_derived
        total_outstanding += r_outstanding
        statutory_sum += _round2(r_received - s_prorated)
        net_pl_sum += r_received - r_landlord_paid
        total_expenses += r_direct
        total_landlord_expenses += r_landlord_paid
        if not complete:
            incomplete_notes.append(
                f"{name}: {year} records are incomplete — this statutory figure is "
                "provisional and will change as the remaining documents arrive."
            )

        contributing = {l["category"] for l in expense_lines if l["deductible"]}
        if any(row["source"] == "actual" for u in unit_blocks for row in u["months"]):
            contributing.add("rental_invoice")
        # Settlement only — NOT _loan_expected_for. _expected_categories has
        # already dropped 'loan' on an explicit "no mortgage"; what remains
        # includes the unanswered case, which must keep being nudged.
        expected_this_year = [
            c for c in _expected_categories(prop)
            if c != "loan" or not _loan_settled_before(prop, year)
        ]
        missing = [c for c in expected_this_year if c not in contributing]
        if missing:
            missing_categories[pid] = missing
            for category in missing:
                caveats.append(
                    f"No {category.replace('_', ' ')} document for {year} — {name}; "
                    "figures may be incomplete."
                )

        # Keyed on the shares actually rendered, not on the property's own:
        # a property owned outright can now contain a single co-owned unit,
        # and that unit's figures still need the warning.
        # The property's own share is always in the set, not just when there
        # are no unit blocks: it is what a building-wide loan or quit rent is
        # scaled by, so a property at 50% whose units are all owned outright
        # still has scaled figures to warn about. Mirrors the app's
        # property-card badge, which builds its range the same way
        # (finance_screen.dart) — keyed only on the units, the two surfaces
        # disagree about whether to say anything at all.
        resolved_shares = {u["ownership_share"] for u in unit_blocks} | {share}
        if any(s < 1.0 for s in resolved_shares):
            if len(resolved_shares) == 1:
                only = next(iter(resolved_shares))
                share_notes.append(
                    f"Ownership share applied: {name} at {only:.0%}. Loan interest "
                    "and principal are shown in full — they are your own borrowing."
                )
            else:
                lo, hi = min(resolved_shares), max(resolved_shares)
                share_notes.append(
                    f"Ownership share applied: {name} at {lo:.0%}–{hi:.0%} across "
                    "its units. Loan interest and principal are shown in full — "
                    "they are your own borrowing."
                )

        for line in expense_lines:
            if not line["deductible"]:
                continue
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0)
                + _line_share(line, share_for(line.get("unit_id"))) * line["amount"]
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

        property_blocks.append({
            "property_id": pid,
            "name": name,
            "ownership_share": share,
            "received_rent": r_received,
            "derived_rent": r_derived,
            "outstanding_rent": r_outstanding,
            "direct_expenses": r_direct,
            "landlord_expenses": r_landlord_paid,
            "rental_income_or_loss": _round2(r_received - r_direct),
            "net_pl": _round2(r_received - r_landlord_paid),
            "statutory_contribution": _round2(r_received - s_prorated),
            "units": unit_blocks,
            "expense_lines": scaled_expense_lines,
            "property_expense_lines": _scaled_lines(property_level_lines, share_for),
            "recovered_rent": recovered_lines,
            "complete": complete,
            "coverage": coverage_rows,
            "expected_categories": _expected_record_categories(prop),
            "manual_loan_incomplete": manual_loan_incomplete,
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
            "landlord_expenses": _round2(total_landlord_expenses),
            "net_pl": _round2(net_pl_sum),
            "statutory_rental_income": statutory,
            "statutory_note": statutory_note,
        },
        "expense_breakdown": expense_breakdown,
        "properties": property_blocks,
        "caveats": caveats,
        "missing_categories": missing_categories,
    }
