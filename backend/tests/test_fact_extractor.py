import unittest

from rag.fact_extractor import (
    FactExtractor,
    EXPENSE_SUBTYPE_CATEGORY,
    LANDLORD_BORNE_SUBTYPES,
    NEVER_DEDUCTIBLE_SUBTYPES,
    validate_expense_lines,
)


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


class _SequenceLLM:
    """Returns a different canned response per successive invoke() call,
    holding the last content once the sequence is exhausted. Needed once a
    single extract() call can trigger more than one LLM invocation."""

    def __init__(self, contents):
        self._contents = list(contents)
        self.invocations = 0
        self.prompts = []

    def invoke(self, prompt):
        self.prompts.append(prompt)
        index = min(self.invocations, len(self._contents) - 1)
        self.invocations += 1
        return _LLMResponse(self._contents[index])


class _FirstThenRaisingLLM:
    """First invoke() succeeds; every call after that raises. Simulates the
    clause-extraction call failing independently of the primary one."""

    def __init__(self, first_content):
        self._first_content = first_content
        self.invocations = 0

    def invoke(self, prompt):
        self.invocations += 1
        if self.invocations == 1:
            return _LLMResponse(self._first_content)
        raise RuntimeError("boom")


class UtilitiesLiabilityExtractionTests(unittest.TestCase):
    _LEASE_FIELDS = "monthly_rent=1500;lease_start=2025-09-01;confidence=0.9"

    def test_lease_extraction_makes_two_llm_calls(self):
        llm = _SequenceLLM([self._LEASE_FIELDS, "{}"])
        FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertEqual(llm.invocations, 2)

    def test_non_lease_category_makes_only_one_llm_call(self):
        llm = _SequenceLLM(["amount=100;confidence=0.9"])
        FactExtractor(llm).extract("tax", "CUKAI TAKSIRAN bill ...")
        self.assertEqual(llm.invocations, 1)

    def test_utilities_clause_with_quote_and_ref_is_captured(self):
        clause_json = (
            '{"utilities_liability": "tenant", "clause_ref": "Clause 5.2", '
            '"quote": "To pay all charges due and incurred in respect of '
            'electricity, water and all other utilities supplied to the '
            'Said Premises.", "confidence": 0.9}'
        )
        llm = _SequenceLLM([self._LEASE_FIELDS, clause_json])
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertEqual(facts["utilities_liability"], "tenant")
        self.assertEqual(facts["utilities_clause_ref"], "Clause 5.2")
        self.assertTrue(facts["utilities_clause_quote"].startswith("To pay all charges"))
        # Existing lease fields are untouched by the merge.
        self.assertEqual(facts["monthly_rent"], 1500.0)
        self.assertEqual(facts["lease_start"], "2025-09-01")

    def test_utilities_clause_without_quote_is_dropped(self):
        clause_json = '{"utilities_liability": "tenant", "clause_ref": "Clause 5.2"}'
        llm = _SequenceLLM([self._LEASE_FIELDS, clause_json])
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertNotIn("utilities_liability", facts)
        self.assertNotIn("utilities_clause_quote", facts)
        self.assertNotIn("utilities_clause_ref", facts)

    def test_utilities_clause_invalid_liability_value_is_dropped(self):
        clause_json = '{"utilities_liability": "unclear", "quote": "some text"}'
        llm = _SequenceLLM([self._LEASE_FIELDS, clause_json])
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertNotIn("utilities_liability", facts)

    def test_utilities_clause_empty_response_is_dropped(self):
        llm = _SequenceLLM([self._LEASE_FIELDS, "{}"])
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertNotIn("utilities_liability", facts)
        self.assertEqual(facts["monthly_rent"], 1500.0)  # primary fields unaffected

    def test_utilities_clause_bad_json_is_dropped(self):
        llm = _SequenceLLM([self._LEASE_FIELDS, "not json at all"])
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertNotIn("utilities_liability", facts)
        self.assertEqual(facts["monthly_rent"], 1500.0)

    def test_utilities_clause_quote_truncated_to_500_chars(self):
        long_quote = "x" * 600
        clause_json = f'{{"utilities_liability": "landlord", "quote": "{long_quote}"}}'
        llm = _SequenceLLM([self._LEASE_FIELDS, clause_json])
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertEqual(len(facts["utilities_clause_quote"]), 500)

    def test_utilities_clause_llm_exception_is_non_blocking(self):
        llm = _FirstThenRaisingLLM(self._LEASE_FIELDS)
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertEqual(facts["monthly_rent"], 1500.0)
        self.assertNotIn("utilities_liability", facts)

    def test_only_utilities_clause_found_still_returns_facts(self):
        # Primary field extraction finds nothing in this document, but the
        # clause is present -- the facts dict must not be discarded.
        clause_json = '{"utilities_liability": "tenant", "quote": "Tenant pays all utilities."}'
        llm = _SequenceLLM(["I could not find any lease fields.", clause_json])
        facts = FactExtractor(llm).extract("lease", "TENANCY AGREEMENT ...")
        self.assertEqual(facts["utilities_liability"], "tenant")
        self.assertNotIn("monthly_rent", facts)


class _FakeExpensesLlm:
    def __init__(self, content):
        self._content = content

    def invoke(self, prompt):
        class _R:
            pass

        r = _R()
        r.content = self._content
        return r


class TestExpenseLineExtraction(unittest.TestCase):
    def test_combined_statement_yields_validated_lines(self):
        payload = (
            '```json\n'
            '{"lines": ['
            '{"subtype": "maintenance", "description": "Service charge Q1", "amount": "RM 1,050.00", "period_year": 2025},'
            '{"subtype": "sinking_fund", "amount": 210.0, "period_year": 2025},'
            '{"subtype": "insurance_premium", "amount": 1800.0, "date": "2025-03-01"},'
            '{"subtype": "quit_rent", "amount": 316.87, "period_year": 2025},'
            '{"subtype": "made_up_charge", "amount": 999.0}'
            '], "policy_end": "2026-03-01", "confidence": 0.9}\n```'
        )
        facts = FactExtractor(_FakeExpensesLlm(payload)).extract("expenses", "statement text")
        self.assertEqual(len(facts["expense_lines"]), 4)  # bogus subtype dropped
        self.assertEqual(facts["expense_lines"][0]["amount"], 1050.0)  # currency stripped
        self.assertEqual(facts["policy_end"], "2026-03-01")
        self.assertEqual(facts["confidence"], 0.9)

    def test_no_valid_lines_returns_none(self):
        facts = FactExtractor(
            _FakeExpensesLlm('{"lines": [{"subtype": "nonsense", "amount": 10}]}')
        ).extract("expenses", "text")
        self.assertIsNone(facts)

    def test_unparseable_json_returns_none(self):
        facts = FactExtractor(_FakeExpensesLlm("not json at all")).extract("expenses", "text")
        self.assertIsNone(facts)


class TestValidateExpenseLines(unittest.TestCase):
    def test_bad_dates_and_years_are_dropped_from_the_line_not_the_list(self):
        cleaned = validate_expense_lines([
            {"subtype": "upkeep", "amount": 150, "date": "31/12/2025", "period_year": "20255"},
        ])
        self.assertEqual(cleaned, [{"subtype": "upkeep", "amount": 150.0}])

    def test_every_subtype_maps_to_a_finance_category(self):
        for subtype, category in EXPENSE_SUBTYPE_CATEGORY.items():
            self.assertIn(category, {
                "loan", "tax", "maintenance", "insurance", "upkeep",
                "management", "letting", "sst",
                "utilities", "late_penalty", "renovation", "loan_principal",
            })

    def test_non_deductible_subtypes_are_declared_subtypes(self):
        for subtype in NEVER_DEDUCTIBLE_SUBTYPES | LANDLORD_BORNE_SUBTYPES:
            self.assertIn(subtype, EXPENSE_SUBTYPE_CATEGORY)

    def test_installment_passes_through_on_a_bundled_line(self):
        lines = validate_expense_lines([
            {"subtype": "assessment_tax", "amount": 400.0, "period_year": 2025,
             "installment": "1/2"},
        ])
        self.assertEqual(lines[0]["installment"], "1/2")

    def test_installment_omitted_when_blank(self):
        lines = validate_expense_lines([
            {"subtype": "maintenance", "amount": 250.0, "date": "2025-03-01"},
        ])
        self.assertNotIn("installment", lines[0])
