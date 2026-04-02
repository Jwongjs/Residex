from __future__ import annotations

from typing import Dict, Any, List


class CategoryPredictor:
    """Predicts likely document categories for a question."""

    def __init__(self, llm, allowed_categories: List[str]):
        self._llm = llm
        self._allowed = allowed_categories

    def predict(self, question: str, available_categories: List[str]) -> Dict[str, Any]:
        if not available_categories:
            return {
                "predicted_categories": [],
                "confidence": 0.0,
                "reason": "No uploaded categories for this property",
            }

        try:
            prompt = f"""
You are helping route a property-document query.

Question: {question}
Available categories: {", ".join(available_categories)}

Pick up to 2 best categories from AVAILABLE categories only.
Respond exactly in this format:
categories=<comma separated categories>;confidence=<0.0-1.0>;reason=<short reason>
""".strip()

            response = self._llm.invoke(prompt)
            content = str(response.content).strip()

            predicted: List[str] = []
            confidence = 0.5
            reason = "LLM prediction"

            for part in content.split(";"):
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

            if not predicted:
                predicted = [available_categories[0]]
                confidence = min(confidence, 0.5)
                reason = "No clear parse; defaulted to first available category"

            return {
                "predicted_categories": predicted[:2],
                "confidence": confidence,
                "reason": reason,
            }
        except Exception:
            lowered = (question or "").lower()
            fallback_keywords = {
                "lease": ["lease", "tenant", "pets", "rent", "deposit"],
                "warranty": ["warranty", "covered", "claim", "expiry"],
                "insurance": ["insurance", "policy", "premium", "liability"],
                "utility": ["utility", "electric", "water", "gas", "bill"],
                "receipt": ["receipt", "invoice", "payment", "repair", "maintenance"],
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
                best = [available_categories[0]]

            return {
                "predicted_categories": best[:2],
                "confidence": 0.55,
                "reason": "Keyword fallback",
            }
