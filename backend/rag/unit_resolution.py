import re
from typing import Dict, List

# Question-side unit reference resolution. Matching is deterministic and
# label-driven: "unit a" resolves to "Unit A-12-03" only when exactly one
# unit label starts with that reference at a segment boundary.
_UNIT_REF_PATTERN = re.compile(r"\bunit\s+([a-z0-9]+(?:-[a-z0-9]+)*)")
_AGGREGATE_UNIT_PHRASES = (
    "all units", "all the units", "all my units", "across units",
    "every unit", "each unit", "per unit", "between units",
)


def _label_matches_token(label: str, token: str) -> bool:
    label_norm = " ".join(label.lower().split())
    prefix = f"unit {token}"
    if label_norm == token or label_norm == prefix:
        return True
    if label_norm.startswith(prefix):
        # Boundary check so "unit a" never matches "Unit AB-2".
        return label_norm[len(prefix):][:1] in ("-", " ", ".")
    return False


def resolve_unit_mention(question: str, units: List[Dict]) -> Dict:
    """Decide which unit(s) a question refers to, before retrieval runs.

    units: [{"unit_id": ..., "label": ...}]. Returns a dict whose "kind" is:
      none      - no unit signal; search everything, attribute per unit
      scoped    - exactly one unit referenced -> {"unit": {...}}
      multi     - several units named deliberately; search everything
      aggregate - "all units"-style phrasing; search everything
      ambiguous - one reference matches several units -> {"candidates": [...]}
      unknown   - a unit was named that does not exist -> {"mention": str}
    """
    q = " ".join((question or "").lower().split())
    if not q or not units:
        return {"kind": "none"}

    named = [
        u for u in units
        if u.get("label") and " ".join(u["label"].lower().split()) in q
    ]
    if len(named) == 1:
        return {"kind": "scoped", "unit": named[0]}
    if len(named) >= 2:
        return {"kind": "multi"}

    if any(phrase in q for phrase in _AGGREGATE_UNIT_PHRASES):
        return {"kind": "aggregate"}

    resolved: Dict[str, Dict] = {}
    for token in _UNIT_REF_PATTERN.findall(q):
        candidates = [
            u for u in units
            if u.get("label") and _label_matches_token(u["label"], token)
        ]
        if not candidates:
            return {"kind": "unknown", "mention": f"Unit {token.upper()}"}
        if len(candidates) > 1:
            return {"kind": "ambiguous", "candidates": candidates}
        resolved[candidates[0]["unit_id"]] = candidates[0]

    if len(resolved) == 1:
        return {"kind": "scoped", "unit": next(iter(resolved.values()))}
    if len(resolved) >= 2:
        return {"kind": "multi"}
    return {"kind": "none"}
