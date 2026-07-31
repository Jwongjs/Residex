"""Deterministic recall floor for expense line items.

The fact-extraction LLM occasionally drops a clearly-labeled charge on noisy
OCR. Confirmed live misses on the Ayer@8 corpus: JAN fire insurance and JUN
service charge, plus the FEB service charge (the 0.00 GST column was linearized
ahead of the real amount, so the model read the charge as zero).

This scanner runs over the SAME OCR text, matches only unambiguous Malaysian
charge labels (English + Malay), and pulls the amount off each labeled charge.
It cross-checks the LLM's output and backfills only charges the LLM missed — it
never replaces the model.

Segmentation, not line-splitting: the stored OCR is one continuous blob with no
reliable newlines. So the scanner finds every charge label and every total /
boundary word, sorts them by position, and reads each charge's amount from the
span between that label and the next anchor. That span is the one place a
charge's own amount lives, and bounding it at the next label-or-total is what
stops a charge from bleeding into the grand total.

Design limits, by intent:
- A charge registers only when a mapped label and a money value share its span.
- The RIGHTMOST positive value in the span wins — that is the Amount column on
  these bills, past any leading GST/tax cell of 0.00. A bill that printed tax
  AFTER the amount would need per-template handling.
- Only labels with no owner-vs-tenant / JMB-vs-agent ambiguity are mapped;
  water/utilities, late penalties and agent fees are left to the model.
"""
from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Tuple

# Unambiguous, pattern-shaped charge labels → the EXPENSE_SUBTYPE_CATEGORY
# subtype they map to. Labels a landlord literally sees printed as a line item
# on a Malaysian strata/utility bill, English or Malay, with no context-
# dependent classification.
_LABEL_SUBTYPE: Dict[str, str] = {
    "service charge": "maintenance",
    "maintenance charge": "maintenance",
    "maintenance fee": "maintenance",
    "caj penyelenggaraan": "maintenance",
    "caj perkhidmatan": "maintenance",
    "sinking fund": "sinking_fund",
    "kumpulan wang penjelas": "sinking_fund",
    "quit rent": "quit_rent",
    "cukai tanah": "quit_rent",
    "parcel rent": "parcel_rent",
    "cukai petak": "parcel_rent",
    "assessment tax": "assessment_tax",
    "cukai pintu": "assessment_tax",
    "cukai taksiran": "assessment_tax",
    "fire insurance": "insurance_premium",
    "insurance premium": "insurance_premium",
    "houseowner": "insurance_premium",
}

# Words that end a charge's amount span: itemised totals and closing lines, in
# English and Malay. Without these a charge's span would run into the grand
# total (e.g. JAN's "Gross Total 840.40", JUN's "Baki (RM)").
_BOUNDARIES: Tuple[str, ...] = (
    "total", "gross", "outstanding", "nett", "open credit",
    "baki", "jumlah", "amaun perlu", "important note",
)

# A money value: digits (with thousands separators) ending in a 2-digit decimal
# introduced by '.' OR ',' (OCR renders the Malaysian decimal both ways — APR
# printed the service charge as "764,00"). Requiring the 2-decimal tail is what
# keeps item numbers, years and DD/MM/YYYY or DD-MM-YYYY date columns out.
_AMOUNT = re.compile(r"\d[\d.,]*[.,]\d{2}(?!\d)")

# A DD/MM/YYYY or DD-MM-YYYY date (2- or 4-digit year). Once a charge's amounts
# have started, the next date token marks the start of the following row, so it
# closes the charge's amount cluster.
_DATE = re.compile(r"\d{1,2}[-/]\d{1,2}[-/]\d{2,4}")


def _money_value(token: str) -> float:
    """Parse a money token to a float. The LAST '.'/',' is the decimal point;
    any earlier separators are thousands groupings. "1,626.81" -> 1626.81,
    "764,00" -> 764.00, "764.00" -> 764.00."""
    idx = max(token.rfind("."), token.rfind(","))
    integer = re.sub(r"[.,]", "", token[:idx])
    frac = token[idx + 1: idx + 3]
    return float(f"{integer or '0'}.{frac}")


def _charge_amount(span: str) -> Optional[float]:
    """The charge's own amount from the span after its label.

    Reads the first amount cluster — consecutive money values with no date token
    between them — and returns the last positive value in it. That steps past a
    leading GST/tax cell of 0.00 (or an OCR-garbled one like "9,00"), while
    stopping before the next row's amount (a date token separates the rows) and
    before any grand total (the boundary words bound the span upstream)."""
    last_positive: Optional[float] = None
    prev_end: Optional[int] = None
    for match in _AMOUNT.finditer(span):
        if prev_end is not None and _DATE.search(span[prev_end:match.start()]):
            break  # a date after amounts began = the next row; cluster ends
        value = _money_value(match.group(0))
        if value > 0:
            last_positive = value
        prev_end = match.end()
    return last_positive


def scan_expense_lines(text: str) -> List[Dict[str, Any]]:
    """Deterministically detect labeled charges in OCR text.

    Returns one entry per (subtype, amount) found, each {"subtype", "amount",
    "label"}. A charge registers only when a mapped label and a positive amount
    share the label's span; totals and unmapped labels are skipped.
    """
    lowered = text.lower()

    # Collect anchors as (start, end, subtype_or_None). Charge labels carry a
    # subtype; boundary words carry None and only serve to cut a span short.
    anchors: List[Tuple[int, int, Optional[str]]] = []
    for label, subtype in _LABEL_SUBTYPE.items():
        start = lowered.find(label)
        while start != -1:
            anchors.append((start, start + len(label), subtype))
            start = lowered.find(label, start + len(label))
    for word in _BOUNDARIES:
        start = lowered.find(word)
        while start != -1:
            anchors.append((start, start + len(word), None))
            start = lowered.find(word, start + len(word))
    anchors.sort()

    found: List[Dict[str, Any]] = []
    seen: set = set()
    for i, (start, end, subtype) in enumerate(anchors):
        if subtype is None:
            continue
        span_end = anchors[i + 1][0] if i + 1 < len(anchors) else len(text)
        amount = _charge_amount(text[end:span_end])
        if amount is None:
            continue
        key = (subtype, round(amount, 2))
        if key in seen:
            continue
        seen.add(key)
        found.append({"subtype": subtype, "amount": amount})
    return found


def backfill_expense_lines(
    text: str, llm_lines: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Merge the LLM's expense lines with deterministic detections.

    The LLM's lines are kept verbatim (they carry description/date/period the
    scanner can't). Any scanned charge whose (subtype, amount) the LLM did not
    already return is appended, flagged `source="scanner"` so it stays auditable
    and can surface as machine-detected in the UI.
    """
    merged: List[Dict[str, Any]] = [dict(line) for line in llm_lines]
    present = {
        (str(line.get("subtype")), round(float(line.get("amount", 0)), 2))
        for line in llm_lines
        if line.get("amount") is not None
    }
    for detection in scan_expense_lines(text):
        key = (detection["subtype"], round(detection["amount"], 2))
        if key in present:
            continue
        present.add(key)
        merged.append(
            {
                "subtype": detection["subtype"],
                "amount": detection["amount"],
                "source": "scanner",
            }
        )
    return merged
