"""Deterministic finance engine: pure functions, no LLM, no I/O.

Folds extracted facts into per-unit monthly income, per-property
Received Rent / Direct Expenses / Rental Income/Loss, portfolio Net P/L,
and Malaysian statutory rental income (s.4(d), YA = calendar year).
Malformed or missing facts are skipped silently — they surface through
missing_categories/caveats, never as errors.
"""
from __future__ import annotations

from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

from rag.fact_extractor import EXPENSE_SUBTYPE_CATEGORY

_EXPENSE_LINE_LABELS = {
    "loan_interest": "Loan interest",
    "assessment_tax": "Assessment tax",
    "quit_rent": "Quit rent",
    "parcel_rent": "Parcel rent",
    "maintenance": "Maintenance fees",
    "sinking_fund": "Sinking fund",
    "insurance_premium": "Insurance premium",
    "upkeep": "Upkeep",
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
    unpaid_months is a list of (month, reason|None)."""
    exception_by_month: Dict[int, Optional[str]] = {}
    for exc in exceptions:
        if not isinstance(exc, dict) or exc.get("unit_id") != unit_id:
            continue
        ym = _ym(exc.get("month"))
        if ym is None or ym[0] != year:
            continue
        exception_by_month[ym[1]] = exc.get("reason")

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
    unpaid_months: List[Tuple[int, Optional[str]]] = []
    for month in months:
        if month in exception_by_month:
            reason = exception_by_month[month]
            row: Dict[str, Any] = {"month": month, "source": "unpaid", "amount": 0.0}
            if reason:
                row["reason"] = reason
            month_rows.append(row)
            rented += 1
            unpaid_months.append((month, reason))
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


def _expense_lines(prop_docs: List[Dict[str, Any]], year: int) -> List[Dict[str, Any]]:
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
                })
            continue
        entry = None  # (amount, description, date_str)
        if category == "loan":
            amount = _amount(facts, "interest_paid")
            if facts.get("subtype") == "interest_statement" and amount is not None \
                    and facts.get("period_year") == year:
                entry = (amount, "Loan interest", str(year))
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
            })
    return lines


def compute_finance_summary(
    *,
    year: int,
    today: date,
    documents: List[Dict[str, Any]],
    properties: List[Dict[str, Any]],
    units_by_property: Dict[str, List[Dict[str, Any]]],
    payment_exceptions: Optional[List[Dict[str, Any]]] = None,
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
    total_expenses = 0.0
    statutory_sum = 0.0
    derived_notes: List[str] = []
    vacant_notes: List[str] = []
    unpaid_notes: List[str] = []
    share_notes: List[str] = []

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

        expense_lines = _expense_lines(prop_docs, year)
        lines_by_unit: Dict[Optional[str], List[Dict[str, Any]]] = {}
        for line in expense_lines:
            lines_by_unit.setdefault(line.get("unit_id"), []).append(line)

        unit_blocks: List[Dict[str, Any]] = []
        prop_actual = 0.0
        prop_derived = 0.0
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
            unit_expense_total = sum(l["amount"] for l in unit_lines)
            prorated_expenses += unit_expense_total * fraction
            unit_blocks.append({
                "unit_id": scope["unit_id"],
                "label": scope["label"],
                "rented_months": rented,
                "contribution": _round2(actual_sum + derived_sum - unit_expense_total),
                "months": month_rows,
                "missing_invoice_months": vacant,
                "expense_lines": unit_lines,
            })
            prop_actual += actual_sum
            prop_derived += derived_sum
            if derived:
                derived_notes.append(
                    f"{name} — {scope['label']}: "
                    + ", ".join(MONTH_NAMES[m - 1] for m in derived)
                )
            for m in vacant:
                vacant_notes.append(
                    f"No invoice recorded for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                )
            for m, reason in unpaid:
                note = f"No payment received for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                if reason:
                    note += f": {reason}"
                unpaid_notes.append(note)

        # Property-level expenses (no unit) prorate by the property's average
        # rented fraction; a fully-rented year = factor 1.0 so the reference
        # scenario reproduces exactly.
        property_level_lines = lines_by_unit.get(None, [])
        avg_fraction = (sum(fractions) / len(fractions)) if fractions else 0.0
        prorated_expenses += sum(l["amount"] for l in property_level_lines) * avg_fraction

        received = prop_actual + prop_derived
        direct = sum(l["amount"] for l in expense_lines)
        statutory_sum += share * (received - prorated_expenses)

        contributing = {l["category"] for l in expense_lines}
        if any(row["source"] == "actual" for u in unit_blocks for row in u["months"]):
            contributing.add("rental_invoice")
        missing = [c for c in FINANCE_CATEGORIES if c not in contributing]
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
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0) + line["amount"]
            )

        total_received += received
        total_derived += prop_derived
        total_expenses += direct

        property_blocks.append({
            "property_id": pid,
            "name": name,
            "ownership_share": share,
            "received_rent": _round2(received),
            "derived_rent": _round2(prop_derived),
            "direct_expenses": _round2(direct),
            "rental_income_or_loss": _round2(received - direct),
            "units": unit_blocks,
            "expense_lines": expense_lines,
            "property_expense_lines": property_level_lines,
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

    return {
        "year": year,
        "totals": {
            "received_rent": _round2(total_received),
            "derived_rent": _round2(total_derived),
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
