"""Locating the page that states an extracted fact.

Pure: no Firestore, no LLM, no network — so these tests use no mocks. The
contract that matters most is the negative one: a value that cannot be placed
is ABSENT from the result. A wrong page is worse than no page, because page 1
reads as an obvious fallback and page 3 reads as authoritative.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.documents.fact_locator import candidate_forms, locate_facts


class TestDateForms:
    def test_iso_date_is_found_from_long_form_prose(self):
        pages = ["cover page", "This Agreement commences on 15 March 2026."]
        assert locate_facts({"lease_start": "2026-03-15"}, pages) == {"lease_start": 1}

    def test_iso_date_is_found_from_slashed_form(self):
        assert locate_facts({"d": "2026-03-15"}, ["due 15/03/2026"]) == {"d": 0}

    def test_iso_date_is_found_from_ordinal_form(self):
        assert locate_facts({"d": "2026-03-15"}, ["the 15th March 2026"]) == {"d": 0}

    def test_iso_date_is_found_from_its_own_iso_form(self):
        assert locate_facts({"d": "2026-03-15"}, ["expiry 2026-03-15"]) == {"d": 0}

    def test_single_digit_day_is_found_without_a_leading_zero(self):
        # Malaysian agreements write "5 March 2026", not "05 March 2026".
        assert locate_facts({"d": "2026-03-05"}, ["dated 5 March 2026"]) == {"d": 0}

    def test_month_first_form_is_found(self):
        assert locate_facts({"d": "2026-03-15"}, ["on March 15, 2026"]) == {"d": 0}

    def test_nonsense_date_falls_back_to_the_literal_string(self):
        # A malformed stored value must not crash the locator.
        assert candidate_forms("2026-99-99") == ["2026-99-99"]


class TestNumberForms:
    def test_amount_is_found_from_a_formatted_ringgit_figure(self):
        assert locate_facts({"amount": 2400}, ["Total: RM 2,400.00"]) == {"amount": 0}

    def test_amount_is_found_from_a_bare_integer(self):
        assert locate_facts({"amount": 2400}, ["rent is 2400 per month"]) == {"amount": 0}

    def test_float_amount_is_found_from_its_two_decimal_form(self):
        assert locate_facts({"amount": 1234.56}, ["RM 1,234.56 due"]) == {"amount": 0}

    def test_amount_is_not_found_inside_a_larger_amount(self):
        # "2,400.00" is a substring of "12,400.00". Plain substring matching
        # would cite the page stating RM 12,400 as the page stating RM 2,400.
        assert locate_facts({"amount": 2400}, ["Total: RM 12,400.00"]) == {}

    def test_amount_is_not_found_inside_a_longer_bare_number(self):
        assert locate_facts({"amount": 2400}, ["reference 24001234"]) == {}

    def test_amount_is_not_found_inside_a_thousands_separated_larger_amount(self):
        # The right-hand mirror of the case above, and the one a plain
        # "not followed by a digit" guard misses: the character after "2,400"
        # in "2,400,000.00" is a comma. An insurance policy states a premium
        # of RM 850 and a sum insured of RM 850,000 on the same page.
        assert locate_facts({"amount": 2400}, ["value RM 2,400,000.00"]) == {}
        assert locate_facts({"amount": 850}, ["Sum Insured RM 850,000"]) == {}
        assert locate_facts({"amount": 100}, ["Sum insured: RM 100,000.00"]) == {}

    def test_amount_is_not_found_inside_a_longer_decimal(self):
        assert locate_facts({"amount": 2400}, ["Total: RM 2,400.50"]) == {}

    def test_a_trailing_separator_that_is_punctuation_still_matches(self):
        # "2400." ending a sentence and "2400," in a list are not longer
        # numbers; the guard must not over-reject them.
        assert locate_facts({"amount": 2400}, ["rent totalling 2400."]) == {"amount": 0}
        assert locate_facts({"amount": 2400}, ["2400, plus service charge"]) == {"amount": 0}

    def test_short_numbers_generate_no_candidates(self):
        # A 1-2 digit run appears on nearly every page (clause numbers, list
        # markers, "Page 3 of 12"); placing a fact on that is coincidence.
        assert candidate_forms(50) == []
        assert candidate_forms(7.0) == []
        assert locate_facts({"amount": 50}, ["clause 50 applies"]) == {}


class TestTextForms:
    def test_text_is_found_case_insensitively(self):
        facts = {"tenant_name": "JNT Sdn. Bhd."}
        assert locate_facts(facts, ["signed by jnt sdn. bhd."]) == {"tenant_name": 0}

    def test_text_is_found_across_a_line_break(self):
        facts = {"tenant_name": "JNT Sdn. Bhd."}
        pages = ["signed by JNT\n   Sdn. Bhd. on the date below"]
        assert locate_facts(facts, pages) == {"tenant_name": 0}


class TestPageSelection:
    def test_first_matching_page_wins(self):
        pages = ["nothing", "RM 2,400.00 stated here", "and RM 2,400.00 again"]
        assert locate_facts({"amount": 2400}, pages) == {"amount": 1}

    def test_absent_value_is_missing_from_the_map_not_mapped_to_zero(self):
        result = locate_facts({"amount": 2400}, ["nothing relevant"])
        assert result == {}
        assert "amount" not in result

    def test_each_fact_is_located_independently(self):
        pages = ["RM 2,400.00", "ends 15 March 2026"]
        assert locate_facts({"amount": 2400, "lease_end": "2026-03-15"}, pages) == {
            "amount": 0, "lease_end": 1,
        }


class TestSkippedValues:
    def test_structured_values_are_skipped(self):
        # _render_lines already skips these, so they never reach a citation.
        assert candidate_forms([{"subtype": "quit_rent"}]) == []
        assert candidate_forms({"a": 1}) == []
        assert locate_facts({"expense_lines": [{"amount": 2400}]}, ["RM 2,400.00"]) == {}

    def test_none_and_blank_and_bool_are_skipped(self):
        assert candidate_forms(None) == []
        assert candidate_forms("") == []
        assert candidate_forms("   ") == []
        assert candidate_forms(True) == []


class TestEmptyCases:
    def test_empty_facts_returns_empty_map(self):
        assert locate_facts({}, ["some text"]) == {}

    def test_empty_pages_returns_empty_map(self):
        assert locate_facts({"amount": 2400}, []) == {}

    def test_none_arguments_return_cleanly(self):
        assert locate_facts(None, None) == {}

    def test_a_none_page_is_treated_as_empty_text(self):
        assert locate_facts({"amount": 2400}, [None, "RM 2,400.00"]) == {"amount": 1}
