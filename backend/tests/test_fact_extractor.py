import unittest

from rag.fact_extractor import FactExtractor


class _LLMResponse:
    def __init__(self, content):
        self.content = content


class _FakeLLM:
    def __init__(self, content):
        self._content = content
        self.invocations = 0
        self.last_prompt = None

    def invoke(self, prompt):
        self.invocations += 1
        self.last_prompt = prompt
        return _LLMResponse(self._content)


class _RaisingLLM:
    def invoke(self, prompt):
        raise RuntimeError("boom")


class FactExtractorTests(unittest.TestCase):
    def test_lease_well_formed_response_parses(self):
        llm = _FakeLLM(
            "monthly_rent=RM 1,500.00;deposit=3000;lease_start=2025-09-01;"
            "lease_end=2026-09-01;tenant_name=Aisha Binti Rahman;subtype=renewal;"
            "renewal_fee=250;confidence=0.9"
        )
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT dated ...")
        self.assertEqual(facts["monthly_rent"], 1500.0)
        self.assertEqual(facts["deposit"], 3000.0)
        self.assertEqual(facts["lease_start"], "2025-09-01")
        self.assertEqual(facts["lease_end"], "2026-09-01")
        self.assertEqual(facts["tenant_name"], "Aisha Binti Rahman")
        self.assertEqual(facts["subtype"], "renewal")
        self.assertEqual(facts["renewal_fee"], 250.0)
        self.assertEqual(facts["confidence"], 0.9)

    def test_invalid_subtype_dropped_other_fields_kept(self):
        llm = _FakeLLM("subtype=extension;amount=460.63;period_year=2026;confidence=0.8")
        facts = FactExtractor(llm).extract("tax", "CUKAI TAKSIRAN bill ...")
        self.assertNotIn("subtype", facts)
        self.assertEqual(facts["amount"], 460.63)
        self.assertEqual(facts["period_year"], 2026)

    def test_loan_subtype_space_normalized_to_underscore(self):
        llm = _FakeLLM("subtype=interest statement;interest_paid=12408.31;period_year=2026;confidence=0.85")
        facts = FactExtractor(llm).extract("loan", "YEAR END INTEREST STATEMENT ...")
        self.assertEqual(facts["subtype"], "interest_statement")
        self.assertEqual(facts["interest_paid"], 12408.31)

    def test_non_iso_date_dropped(self):
        llm = _FakeLLM("lease_end=01/09/2026;monthly_rent=1500;confidence=0.7")
        facts = FactExtractor(llm).extract("lease", "some lease text")
        self.assertNotIn("lease_end", facts)
        self.assertEqual(facts["monthly_rent"], 1500.0)

    def test_period_month_validated_as_yyyy_mm(self):
        good = FactExtractor(_FakeLLM("amount=1200;period_month=2026-07;confidence=0.9")) \
            .extract("rental_invoice", "invoice text")
        self.assertEqual(good["period_month"], "2026-07")
        bad = FactExtractor(_FakeLLM("amount=1200;period_month=2026-13;confidence=0.9")) \
            .extract("rental_invoice", "invoice text")
        self.assertNotIn("period_month", bad)

    def test_none_and_unknown_values_skipped(self):
        llm = _FakeLLM("premium=none;policy_end=2027-01-31;policy_number=unknown;confidence=0.8")
        facts = FactExtractor(llm).extract("insurance", "policy schedule")
        self.assertEqual(facts, {"policy_end": "2027-01-31", "confidence": 0.8})

    def test_garbage_and_confidence_only_return_none(self):
        self.assertIsNone(
            FactExtractor(_FakeLLM("I could not find any facts.")).extract("lease", "text")
        )
        self.assertIsNone(
            FactExtractor(_FakeLLM("confidence=0.4")).extract("lease", "text")
        )

    def test_llm_exception_returns_none(self):
        self.assertIsNone(FactExtractor(_RaisingLLM()).extract("lease", "text"))

    def test_unknown_category_and_empty_text_skip_llm(self):
        llm = _FakeLLM("amount=1")
        self.assertIsNone(FactExtractor(llm).extract("other", "text"))
        self.assertIsNone(FactExtractor(llm).extract("lease", "   "))
        self.assertEqual(llm.invocations, 0)

    def test_input_text_truncated_to_cap(self):
        llm = _FakeLLM("amount=100;service_date=2026-03-12;confidence=0.9")
        FactExtractor(llm).extract("upkeep", "x" * 20000)
        self.assertLess(len(llm.last_prompt), 12000)
