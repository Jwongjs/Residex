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
            '{"monthly_rent": "RM 1,500.00", "deposit": 3000, '
            '"lease_start": "2025-09-01", "lease_end": "2026-09-01", '
            '"tenant_name": "Aisha Binti Rahman", "subtype": "renewal", '
            '"renewal_fee": 250, "confidence": 0.9}'
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

    def test_loan_statement_extracts_principal_paid(self):
        llm = _FakeLLM(
            "subtype=interest statement;interest_paid=12408.31;"
            "principal_paid=8000.00;period_year=2026;confidence=0.85"
        )
        facts = FactExtractor(llm).extract("loan", "loan statement text")
        self.assertEqual(facts["interest_paid"], 12408.31)
        self.assertEqual(facts["principal_paid"], 8000.00)

    def test_malaysian_date_normalised_through_extract(self):
        # DD/MM/YYYY off a bill is recovered to ISO, not dropped.
        llm = _FakeLLM('{"lease_end": "01/09/2026", "monthly_rent": 1500, "confidence": 0.7}')
        facts = FactExtractor(llm).extract("lease", "some lease text")
        self.assertEqual(facts["lease_end"], "2026-09-01")
        self.assertEqual(facts["monthly_rent"], 1500.0)

    def test_unparseable_date_dropped(self):
        llm = _FakeLLM('{"lease_end": "next spring", "monthly_rent": 1500, "confidence": 0.7}')
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
    _LEASE_FIELDS = '{"monthly_rent": 1500, "lease_start": "2025-09-01", "confidence": 0.9}'

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


class TestExpenseExtractionRobustness(unittest.TestCase):
    """Silent-drop is the top complaint: a small model that fumbles JSON
    format (while getting the meaning right) currently yields no facts at
    all, indistinguishable from an empty document."""

    def test_trailing_commas_are_tolerated_without_a_retry(self):
        payload = ('{"lines": [{"subtype": "maintenance", "amount": 250, '
                   '"period_year": 2025,},], "confidence": 0.9,}')
        llm = _SequenceLLM([payload])
        facts = FactExtractor(llm).extract("expenses", "statement text")
        self.assertIsNotNone(facts)
        self.assertEqual(facts["expense_lines"][0]["subtype"], "maintenance")
        self.assertEqual(llm.invocations, 1)  # repaired in-place, no second call

    def test_unparseable_first_reply_triggers_one_repair_retry(self):
        good = ('{"lines": [{"subtype": "sinking_fund", "amount": 210, '
                '"period_year": 2025}], "confidence": 0.9}')
        llm = _SequenceLLM(
            ["Here are the charges: maintenance 250 and sinking fund 210.", good]
        )
        facts = FactExtractor(llm).extract("expenses", "statement text")
        self.assertIsNotNone(facts)
        self.assertEqual(facts["expense_lines"][0]["subtype"], "sinking_fund")
        self.assertEqual(llm.invocations, 2)

    def test_repair_retry_that_also_fails_returns_none(self):
        llm = _SequenceLLM(["totally not json", "still not json"])
        facts = FactExtractor(llm).extract("expenses", "statement text")
        self.assertIsNone(facts)
        self.assertEqual(llm.invocations, 2)  # exactly one retry, no loop

    def test_valid_but_empty_lines_do_not_trigger_a_retry(self):
        # Parsed fine, genuinely no charges -> do NOT re-ask (would invite a
        # hallucinated line). Guards the unparseable-vs-empty distinction.
        llm = _SequenceLLM(['{"lines": [], "confidence": 0.2}'])
        facts = FactExtractor(llm).extract("expenses", "statement text")
        self.assertIsNone(facts)
        self.assertEqual(llm.invocations, 1)


class TestExpensePromptGuards(unittest.TestCase):
    """Guards against re-introducing the reported prompt bugs: the echoed
    example description, missed sinking fund, and upkeep filed as maintenance."""

    def _expense_prompt(self):
        llm = _SequenceLLM(['{"lines": [], "confidence": 0.1}'])
        FactExtractor(llm).extract("expenses", "some statement text")
        return llm.prompts[0]

    def test_prompt_no_longer_contains_echoable_example_description(self):
        self.assertNotIn("Service charge Jan-Mar", self._expense_prompt())

    def test_prompt_forbids_copying_example_values(self):
        self.assertIn("never copy the example", self._expense_prompt().lower())

    def test_prompt_requests_a_separate_object_per_charge(self):
        self.assertIn("separate object for each", self._expense_prompt().lower())

    def test_prompt_disambiguates_repair_upkeep_from_maintenance(self):
        self.assertIn("upkeep, not maintenance", self._expense_prompt().lower())


class TestValidateExpenseLines(unittest.TestCase):
    def test_bad_dates_and_years_are_dropped_from_the_line_not_the_list(self):
        cleaned = validate_expense_lines([
            {"subtype": "upkeep", "amount": 150, "date": "whenever", "period_year": "20255"},
        ])
        self.assertEqual(cleaned, [{"subtype": "upkeep", "amount": 150.0}])

    def test_malaysian_date_normalised_on_expense_line(self):
        cleaned = validate_expense_lines([
            {"subtype": "upkeep", "amount": 150, "date": "31/12/2025", "period_year": 2025},
        ])
        self.assertEqual(cleaned, [{"subtype": "upkeep", "amount": 150.0, "date": "2025-12-31", "period_year": 2025}])

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


# The real FEB 2025 Ayer@8 chunk (user-supplied from Firestore). On 7b the LLM
# returned only the sinking fund and dropped the service charge, because the
# 0.00 GST cell precedes the real amount on that line. The scanner backfill
# must recover the maintenance charge in the extractor's final output.
_FEB_2025_CHUNK = (
    "Item Trnx Date DueDate Item Description From To GST Amount (RM) Code Amount (RM)\n"
    "1 04-02-2025 14-02-2025 SERVICE CHARGE 01/02/2025 28/02/2025 SRO 0.00 764.00\n"
    "2 01-02-2025 14-02-2025 SINKING FUND . 01/02/2025 28/02/2025 SRO Ss 9,00 76.40\n"
    "Total Amount 840.46 Total GST(6%) 0.00 Gross Total 840.40"
)


class ExpenseScannerBackfillTests(unittest.TestCase):
    def test_backfills_charge_the_llm_dropped(self):
        # LLM emits only the sinking fund, exactly as the real 7b run did.
        llm = _FakeLLM('{"lines": [{"subtype": "sinking_fund", "amount": 76.40, '
                       '"description": "Sinking Fund (Feb 2025)", "period_year": 2025}], '
                       '"confidence": 0.9}')
        facts = FactExtractor(llm).extract("expenses", _FEB_2025_CHUNK)
        by_subtype = {l["subtype"]: l["amount"] for l in facts["expense_lines"]}
        self.assertEqual(by_subtype.get("sinking_fund"), 76.40)
        self.assertEqual(by_subtype.get("maintenance"), 764.00)

    def test_llm_line_preserved_scanner_line_flagged(self):
        llm = _FakeLLM('{"lines": [{"subtype": "sinking_fund", "amount": 76.40}], '
                       '"confidence": 0.9}')
        facts = FactExtractor(llm).extract("expenses", _FEB_2025_CHUNK)
        maintenance = next(l for l in facts["expense_lines"] if l["subtype"] == "maintenance")
        self.assertEqual(maintenance.get("source"), "scanner")
        sinking = next(l for l in facts["expense_lines"] if l["subtype"] == "sinking_fund")
        self.assertNotEqual(sinking.get("source"), "scanner")

    def test_no_duplicate_when_llm_already_found_the_charge(self):
        llm = _FakeLLM('{"lines": ['
                       '{"subtype": "maintenance", "amount": 764.00}, '
                       '{"subtype": "sinking_fund", "amount": 76.40}], "confidence": 0.9}')
        facts = FactExtractor(llm).extract("expenses", _FEB_2025_CHUNK)
        maintenance = [l for l in facts["expense_lines"] if l["subtype"] == "maintenance"]
        self.assertEqual(len(maintenance), 1)

    def test_scanner_recovers_charges_when_llm_returns_nothing(self):
        # Even a parsed-but-empty reply should not lose deterministically
        # visible charges.
        llm = _FakeLLM('{"lines": [], "confidence": 0.0}')
        facts = FactExtractor(llm).extract("expenses", _FEB_2025_CHUNK)
        self.assertIsNotNone(facts)
        by_subtype = {l["subtype"]: l["amount"] for l in facts["expense_lines"]}
        self.assertEqual(by_subtype.get("maintenance"), 764.00)
        self.assertEqual(by_subtype.get("sinking_fund"), 76.40)


class CoerceDateToleranceTests(unittest.TestCase):
    """Dates arrive from OCR in mixed shapes. _coerce must normalise every
    supported shape to ISO YYYY-MM-DD so storage and every downstream reader
    (finance allocation, the folder month separators) see one format — and
    must still reject genuine garbage rather than guess."""

    def test_iso_date_passes_through(self):
        self.assertEqual(FactExtractor._coerce("expenses", "date", "2025-03-15"), "2025-03-15")

    def test_malaysian_slash_date_normalises_to_iso(self):
        # DD/MM/YYYY — the Malaysian convention printed on bills.
        self.assertEqual(FactExtractor._coerce("expenses", "date", "15/03/2025"), "2025-03-15")

    def test_malaysian_dash_date_normalises_to_iso(self):
        self.assertEqual(FactExtractor._coerce("expenses", "date", "15-03-2025"), "2025-03-15")

    def test_day_month_order_is_preserved_when_ambiguous(self):
        # 03/04/2025 is 3 April (DD/MM), never 4 March.
        self.assertEqual(FactExtractor._coerce("expenses", "date", "03/04/2025"), "2025-04-03")

    def test_out_of_range_date_is_rejected(self):
        self.assertIsNone(FactExtractor._coerce("expenses", "date", "32/01/2025"))

    def test_unparseable_date_is_rejected(self):
        self.assertIsNone(FactExtractor._coerce("expenses", "date", "sometime last spring"))


from rag.fact_extractor import _end_from_term, _start_from_term


class LeaseTermComputationTests(unittest.TestCase):
    """Deterministic tenancy-period math: when a document gives a start and a
    term but no explicit end date (or vice versa), compute the missing bound as
    start + term - 1 day (the Malaysian convention: a 2-year term commencing
    1 Jan 2023 runs to 31 Dec 2024)."""

    def test_end_from_two_year_term(self):
        self.assertEqual(_end_from_term("2023-01-01", 2, "years"), "2024-12-31")

    def test_end_from_one_year_term_mid_month(self):
        self.assertEqual(_end_from_term("2025-09-01", 1, "years"), "2026-08-31")

    def test_end_from_month_term(self):
        self.assertEqual(_end_from_term("2023-01-01", 24, "months"), "2024-12-31")

    def test_end_from_partial_year_in_months(self):
        self.assertEqual(_end_from_term("2023-01-01", 18, "months"), "2024-06-30")

    def test_start_from_end_and_term(self):
        self.assertEqual(_start_from_term("2024-12-31", 2, "years"), "2023-01-01")

    def test_invalid_term_returns_none(self):
        self.assertIsNone(_end_from_term("2023-01-01", 0, "years"))
        self.assertIsNone(_end_from_term("2023-01-01", 3, "weeks"))
        self.assertIsNone(_end_from_term("2023-01-01", None, "years"))
        self.assertIsNone(_end_from_term("not-a-date", 2, "years"))


class LeaseExtractionTests(unittest.TestCase):
    def _lease(self, payload_json):
        return FactExtractor(_FakeLLM(payload_json)).extract(
            "lease", "TENANCY AGREEMENT between Landlord and Tenant ...")

    def test_explicit_start_and_end_pass_through(self):
        facts = self._lease('{"lease_start":"2023-01-01","lease_end":"2024-12-31",'
                            '"monthly_rent":8000,"tenant_name":"Wong Chee Hin","confidence":0.9}')
        self.assertEqual(facts["lease_start"], "2023-01-01")
        self.assertEqual(facts["lease_end"], "2024-12-31")
        self.assertEqual(facts["monthly_rent"], 8000.0)
        self.assertEqual(facts["tenant_name"], "Wong Chee Hin")

    def test_end_computed_from_start_and_term(self):
        facts = self._lease('{"lease_start":"2023-01-01","term_value":2,'
                            '"term_unit":"years","monthly_rent":8000,"confidence":0.8}')
        self.assertEqual(facts["lease_end"], "2024-12-31")

    def test_explicit_end_wins_over_term(self):
        facts = self._lease('{"lease_start":"2023-01-01","lease_end":"2025-01-31",'
                            '"term_value":2,"term_unit":"years"}')
        self.assertEqual(facts["lease_end"], "2025-01-31")

    def test_no_end_and_no_term_leaves_end_absent(self):
        facts = self._lease('{"lease_start":"2023-01-01","monthly_rent":8000}')
        self.assertNotIn("lease_end", facts)
        self.assertEqual(facts["lease_start"], "2023-01-01")

    def test_start_computed_from_end_and_term(self):
        facts = self._lease('{"lease_end":"2024-12-31","term_value":24,"term_unit":"months"}')
        self.assertEqual(facts["lease_start"], "2023-01-01")


from rag.fact_extractor import _lease_input, LEASE_MAX_CHARS


class LeaseInputWindowTests(unittest.TestCase):
    """A tenancy agreement's Schedule — where the dates, rent and deposit are
    actually filled in — sits at the END. Plain head-truncation drops exactly
    those figures (confirmed from a real Ayer 8 log: the model saw only the
    boilerplate clauses and returned confidence 0.0). The lease window must keep
    the tail."""

    def test_short_text_returned_whole(self):
        text = "SHORT TENANCY AGREEMENT with all fields inline"
        self.assertEqual(_lease_input(text), text)

    def test_long_text_keeps_head_and_tail(self):
        head = "PARTIES: Landlord and Tenant. Clause 5.2 utilities. "
        schedule = " THE SCHEDULE Section 5 commencing 25/10/2023 Section 6 rent RM8000"
        text = head + ("x" * (LEASE_MAX_CHARS * 2)) + schedule
        window = _lease_input(text)
        self.assertIn("PARTIES: Landlord and Tenant", window)   # head kept
        self.assertIn("THE SCHEDULE", window)                   # schedule (tail) kept
        self.assertIn("rent RM8000", window)
        self.assertLessEqual(len(window), LEASE_MAX_CHARS + 16)

    def test_tail_preserved_when_schedule_is_last(self):
        text = ("A" * LEASE_MAX_CHARS) + " Section 6(a) RENT RINGGIT EIGHT THOUSAND"
        self.assertIn("RENT RINGGIT EIGHT THOUSAND", _lease_input(text))
