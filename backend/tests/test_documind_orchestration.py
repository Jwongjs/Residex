import unittest

from rag.category_predictor import CategoryPredictor


class _LLMResponse:
    def __init__(self, content: str):
        self.content = content


class _FakeLLM:
    def __init__(self, content: str = "", raise_error: bool = False):
        self._content = content
        self._raise = raise_error

    def invoke(self, _prompt: str):
        if self._raise:
            raise RuntimeError("LLM unavailable")
        return _LLMResponse(self._content)


ALL_CATEGORIES = ["lease", "warranty", "insurance", "utility", "receipt"]


class CategoryPredictorHonestUnknownTests(unittest.TestCase):
    def test_unparseable_llm_output_returns_empty_prediction(self):
        predictor = CategoryPredictor(_FakeLLM("nonsense with no expected format"), ALL_CATEGORIES)

        result = predictor.predict("zzz qqq", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], [])
        self.assertEqual(result["confidence"], 0.0)
        self.assertEqual(result["reason"], "no clear category signal")

    def test_no_signal_keyword_fallback_returns_empty_prediction(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        result = predictor.predict("zzz qqq", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], [])
        self.assertEqual(result["confidence"], 0.0)
        self.assertEqual(result["reason"], "no clear category signal")

    def test_empty_prediction_is_independent_of_category_ordering(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        forward = predictor.predict("zzz qqq", ["lease", "warranty", "utility"])
        reversed_order = predictor.predict("zzz qqq", ["utility", "warranty", "lease"])

        self.assertEqual(forward["predicted_categories"], reversed_order["predicted_categories"])
        self.assertEqual(forward["predicted_categories"], [])

    def test_keyword_fallback_still_matches_real_signal(self):
        predictor = CategoryPredictor(_FakeLLM(raise_error=True), ALL_CATEGORIES)

        result = predictor.predict("when does the lease expire", ["lease", "warranty"])

        self.assertEqual(result["predicted_categories"], ["lease"])


if __name__ == "__main__":
    unittest.main()
