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
        lines = [
            f"    - {_label(key)}: {value}"
            for key, value in sorted(facts.items())
            if value is not None and value != ""
        ]
        if not lines:
            continue
        scope = unit_label or "Property-wide"
        sections.append(f"[{filename} — {scope}]\n" + "\n".join(lines))
    return "\n\n".join(sections)
