"""Render a document's extracted facts for the answer prompt.

Retrieval can miss the one chunk that states a value. A Malaysian tenancy
agreement puts its dates in a Schedule table that the body only
cross-references, and that table embeds poorly against a natural question —
measured on live data, the Schedule chunk was absent from the fetch_k=15
candidate set entirely and still ranked 21st of 42 when every chunk was
fetched and reranked. The facts were already parsed correctly at upload, so
this block puts them in front of the model rather than depending on the table
surviving retrieval.

Pure: no Firestore, no LLM, no network.
"""
from typing import Iterable, Optional, Tuple

# Storage keys are snake_case; the model reads these labels instead.
_LABELS = {
    "lease_start": "Lease start",
    "lease_end": "Lease end",
    "monthly_rent": "Monthly rent (RM)",
    "deposit": "Deposit (RM)",
    "tenant_name": "Tenant",
    "subtype": "Agreement type",
    "period_month": "Period",
    "amount": "Amount (RM)",
    "due_date": "Due date",
    "provider": "Provider",
}


def _label(key: str) -> str:
    """Known keys get a curated label; anything else becomes readable rather
    than being dropped, so a newly extracted fact still reaches the model."""
    if key in _LABELS:
        return _LABELS[key]
    return key.replace("_", " ").capitalize()


def _render_lines(facts: dict) -> list[str]:
    """The value lines for one document, shared by the prompt block and the
    citation snippet so the two can never drift apart.

    Structured values (expense_lines is a list[dict]) are skipped: a raw
    Python repr would inject hundreds of tokens of literal into every
    prompt that retrieves the document. Those rows already reach the
    model through the excerpts and the finance engine; this is for
    the scalar facts retrieval keeps losing.
    """
    return [
        f"    - {_label(key)}: {value}"
        for key, value in sorted(facts.items())
        if value is not None and value != "" and not isinstance(value, (list, dict))
    ]


def facts_snippet(facts: dict) -> str:
    """The rendered values for a single document, with no filename header —
    what a citation shows so the landlord sees the value being cited."""
    return "\n".join(line.strip() for line in _render_lines(facts))


def build_facts_block(
    docs: Iterable[Tuple[str, Optional[str], dict]],
) -> str:
    """(filename, unit_label, facts) triples -> prompt block.

    Returns "" when there is nothing worth showing, so the caller can
    concatenate unconditionally without emitting an empty header.
    """
    sections = []
    for filename, unit_label, facts in docs:
        if not facts:
            continue
        lines = _render_lines(facts)
        if not lines:
            continue
        scope = unit_label or "Property-wide"
        sections.append(f"[{filename} — {scope}]\n" + "\n".join(lines))
    return "\n\n".join(sections)
