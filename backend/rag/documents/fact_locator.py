"""Locate the page that states each extracted fact.

Retrieval is always over chunks; extracted facts are fetched afterwards for
whichever documents those chunks belong to, so a fact citation carries no page
and opens the document at page 1 — the value a landlord most wants to verify
is the one whose citation cannot take them to it.

The page is not recoverable at query time: `FactExtractor.extract(category,
text)` runs on flat concatenated text with no page attribution. So it is
located at ingestion, where per-page text is still in scope, costing no extra
LLM call and no extra read.

Pure: no Firestore, no LLM, no network — the same discipline
`rag/ask/fact_context.py` sets, and the reason this module is fully testable
with no mocks.

A value that cannot be placed is absent from the result — never guessed, never
defaulted. A wrong page is the one outcome worse than no page: page 1 reads as
an obvious fallback, page 3 reads as authoritative.
"""
import math
import re
from typing import Any, Dict, List, Optional

_ISO_DATE = re.compile(r"\d{4}-\d{2}-\d{2}")

_MONTHS = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

# A 1-2 character form matches almost any page — clause numbers, list markers,
# "Page 3 of 12". Values that short generate no candidates rather than place a
# fact by coincidence.
_MIN_NUMERIC_FORM_LENGTH = 3


def _normalise(text: str) -> str:
    """Casefold and collapse whitespace runs, so a value split across a line
    break still matches the form searched for."""
    return re.sub(r"\s+", " ", text.casefold())


def _ordinal(day: int) -> str:
    """1 -> 1st, 12 -> 12th, 23 -> 23rd."""
    if 11 <= day % 100 <= 13:
        suffix = "th"
    else:
        suffix = {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
    return f"{day}{suffix}"


def _date_forms(value: str) -> List[str]:
    """The ways a Malaysian tenancy agreement or bank statement writes a date.

    Both padded and unpadded day/month, because "5 March 2026" is far more
    common in these documents than "05 March 2026".
    """
    year, month, day = int(value[0:4]), int(value[5:7]), int(value[8:10])
    if not (1 <= month <= 12 and 1 <= day <= 31):
        # A malformed stored value is still searched for literally rather than
        # crashing the ingest that produced it.
        return [value]
    name = _MONTHS[month - 1]
    abbrev = name[:3]
    forms = {
        value,
        f"{day:02d}/{month:02d}/{year}", f"{day}/{month}/{year}",
        f"{day:02d}-{month:02d}-{year}", f"{day}-{month}-{year}",
        f"{day:02d} {name} {year}", f"{day} {name} {year}",
        f"{day:02d} {abbrev} {year}", f"{day} {abbrev} {year}",
        f"{_ordinal(day)} {name} {year}",
        f"{name} {day}, {year}",
    }
    return sorted(forms)


def _number_forms(value: float) -> List[str]:
    """RM 2,400.00 and 2400 are the same amount; a document prints either."""
    forms = {f"{value:,.2f}", f"{value:.2f}"}
    if value == int(value):
        forms.add(str(int(value)))
        forms.add(f"{int(value):,}")
    if min(len(form) for form in forms) < _MIN_NUMERIC_FORM_LENGTH:
        return []
    return sorted(forms)


def candidate_forms(value: Any) -> List[str]:
    """The surface forms a stored value might take in the document text.

    Dispatch is on the value's shape, not the key name: a newly added fact
    field is located without editing this module, which is the whole point of
    not keying on names.
    """
    if value is None or isinstance(value, bool):
        return []
    if isinstance(value, (list, dict)):
        # `_render_lines` (fact_context.py) already skips these, so they never
        # reach a citation anyway.
        return []
    if isinstance(value, (int, float)):
        if not math.isfinite(float(value)):
            return []
        return [_normalise(form) for form in _number_forms(float(value))]
    text = str(value).strip()
    if not text:
        return []
    if _ISO_DATE.fullmatch(text):
        return [_normalise(form) for form in _date_forms(text)]
    return [_normalise(text)]


def _contains(page_text: str, form: str) -> bool:
    """Substring match, except that a numeric form must not be found inside a
    longer number: "2,400.00" occurs in "12,400.00", and citing the page that
    states RM 12,400 as the page stating RM 2,400 is the confidently-wrong
    outcome this module exists to avoid.

    The guard has to hold on BOTH sides, and the right-hand side is the easy
    one to get wrong. Rejecting only a following digit still lets "2,400" match
    inside "2,400,000.00", because the character after it is a comma — so an
    insurance policy printing a premium of RM 850 beside a sum insured of
    RM 850,000 would cite the sum insured. A separator followed by a digit is
    therefore part of a longer number too; a separator followed by anything
    else is sentence punctuation ("... totalling 2400." / "2400, plus fees")
    and still matches.
    """
    if form[:1].isdigit() or form[-1:].isdigit():
        pattern = r"(?<![\d.,])" + re.escape(form) + r"(?!\d)(?![.,]\d)"
        return re.search(pattern, page_text) is not None
    return form in page_text


def locate_facts(
    facts: Optional[Dict[str, Any]], pages: Optional[List[str]]
) -> Dict[str, int]:
    """{fact_key: 0-based page index} for every fact locatable in `pages`.

    Keys that cannot be placed are absent from the result — never guessed,
    never defaulted. Scans pages in order; the first page containing any
    candidate form wins.

    0-based, matching what `documind_chunks.page` stores, so the one
    +1-for-display conversion stays where it already is in the ask path.
    """
    normalised = [_normalise(text or "") for text in (pages or [])]
    located: Dict[str, int] = {}
    for key, value in (facts or {}).items():
        forms = candidate_forms(value)
        if not forms:
            continue
        for index, page_text in enumerate(normalised):
            if any(_contains(page_text, form) for form in forms):
                located[key] = index
                break
    return located
