from __future__ import annotations

from typing import Dict, Any, List, Optional


class CategoryPredictor:
    """Routes a question to search parameters: best-fit document categories
    and — when the property has units — which unit the question targets.

    One LLM call decides both (the "tool call" that parameterizes the search).
    On any failure the keyword fallback still scores categories, and
    unit_decided=False tells the caller to route units deterministically
    instead, so LLM routing can never make answering worse than before.
    """

    def __init__(self, llm, allowed_categories: List[str]):
        self._llm = llm
        self._allowed = allowed_categories

    def predict(
        self,
        question: str,
        available_categories: List[str],
        available_units: Optional[List[Dict[str, Any]]] = None,
        recent_turns: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        units = available_units or []
        if not available_categories:
            return {
                "predicted_categories": [],
                "confidence": 0.0,
                "reason": "No uploaded categories for this property",
                "unit_id": None,
                "unknown_unit": None,
                "unit_decided": False,
            }

        try:
            if units:
                unit_lines = "\n".join(
                    f"- id={unit['unit_id']} label={unit['label']}" for unit in units
                )
                unit_section = f"""
Units in this property:
{unit_lines}

For unit pick:
- the id of the single unit the question is about
- all when the question spans units, asks for a total, or names no unit
- if the question names no unit but the recent conversation is clearly about one specific unit, keep using that unit's id
- if the question names a unit that is NOT listed, use all and put the name the user wrote in unknown_unit
""".rstrip()
                response_format = (
                    "categories=<comma separated categories>;confidence=<0.0-1.0>;"
                    "reason=<short reason>;unit=<unit id or all>;unknown_unit=<name or none>"
                )
            else:
                unit_section = ""
                response_format = (
                    "categories=<comma separated categories>;confidence=<0.0-1.0>;reason=<short reason>"
                )

            # Recent turns give the router conversational continuity: a
            # follow-up like "and when does it end?" keeps the previous
            # turn's unit without the user re-naming it.
            context_lines: List[str] = []
            for turn in (recent_turns or [])[-3:]:
                if not turn.get("question"):
                    continue
                context_lines.append(f"User: {turn['question']}")
                answer = turn.get("answer")
                if answer:
                    context_lines.append(f"Assistant: {str(answer)[:200]}")
            context_section = (
                "\nRecent conversation (oldest first):\n" + "\n".join(context_lines) + "\n"
                if context_lines
                else ""
            )

            prompt = f"""
You are routing a property-document search for a landlord.
{context_section}
Question: {question}
Available categories: {", ".join(available_categories)}

Pick up to 2 best categories from AVAILABLE categories only. Leave categories empty if no category clearly fits (then every category is searched).
{unit_section}
Respond exactly in this format:
{response_format}
""".strip()

            response = self._llm.invoke(prompt)
            content = str(response.content).strip()

            predicted: List[str] = []
            confidence = 0.5
            reason = "LLM prediction"
            unit_value: Optional[str] = None
            unknown_unit: Optional[str] = None

            for part in content.split(";"):
                part = part.strip()
                if part.startswith("categories="):
                    raw = part.replace("categories=", "").strip().lower()
                    for item in [x.strip() for x in raw.split(",") if x.strip()]:
                        if item in available_categories and item not in predicted:
                            predicted.append(item)
                elif part.startswith("confidence="):
                    raw = part.replace("confidence=", "").strip()
                    try:
                        confidence = max(0.0, min(1.0, float(raw)))
                    except ValueError:
                        pass
                elif part.startswith("reason="):
                    reason = part.replace("reason=", "").strip()
                elif part.startswith("unit="):
                    unit_value = part.replace("unit=", "").strip()
                elif part.startswith("unknown_unit="):
                    raw = part.replace("unknown_unit=", "").strip()
                    if raw and raw.lower() not in ("none", "null"):
                        unknown_unit = raw

            # Only a validated unit id may scope the search; the model
            # sometimes echoes the label instead of the id, so accept that.
            routed_unit_id = None
            if unit_value:
                for unit in units:
                    if unit_value == unit["unit_id"] or (
                        unit.get("label") and unit_value.lower() == unit["label"].lower()
                    ):
                        routed_unit_id = unit["unit_id"]
                        break

            unit_decided = bool(units) and (
                routed_unit_id is not None
                or unknown_unit is not None
                or (unit_value or "").lower() == "all"
            )

            if not predicted:
                result = {
                    "predicted_categories": [],
                    "confidence": 0.0,
                    "reason": "no clear category signal",
                }
            else:
                result = {
                    "predicted_categories": predicted[:2],
                    "confidence": confidence,
                    "reason": reason,
                }
            result.update(
                {
                    "unit_id": routed_unit_id,
                    "unknown_unit": unknown_unit,
                    "unit_decided": unit_decided,
                }
            )
            return result
        except Exception:
            lowered = (question or "").lower()
            fallback_keywords = {
                "lease": ["lease", "tenant", "tenancy", "rent", "deposit", "pets"],
                "insurance": ["insurance", "policy", "premium", "liability"],
                "loan": ["loan", "mortgage", "interest", "bank", "financing"],
                "tax": ["tax", "assessment", "cukai", "quit rent", "parcel rent", "taksiran"],
                "upkeep": ["repair", "upkeep", "servicing", "plumbing", "aircon", "fix"],
                "maintenance": ["maintenance", "management", "sinking fund", "service charge"],
                "rental_invoice": ["invoice", "receipt", "payment", "rental invoice"],
            }

            scored = []
            for category in available_categories:
                score = 0
                for keyword in fallback_keywords.get(category, []):
                    if keyword in lowered:
                        score += 1
                scored.append((score, category))

            scored.sort(reverse=True)
            best = [category for score, category in scored if score > 0]
            if not best:
                return {
                    "predicted_categories": [],
                    "confidence": 0.0,
                    "reason": "no clear category signal",
                    "unit_id": None,
                    "unknown_unit": None,
                    "unit_decided": False,
                }

            return {
                "predicted_categories": best[:2],
                "confidence": 0.55,
                "reason": "Keyword fallback",
                "unit_id": None,
                "unknown_unit": None,
                "unit_decided": False,
            }
