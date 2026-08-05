"""The facts block that goes in front of the answer prompt.

Pure rendering: no Firestore, no LLM. The block exists because retrieval can
miss the one chunk stating a value (a tenancy agreement's Schedule table), so
these tests pin the shape the model will read.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.ask.fact_context import build_facts_block


class TestEmptyCases:
    def test_no_documents_returns_empty_string(self):
        assert build_facts_block([]) == ""

    def test_document_without_facts_is_omitted(self):
        assert build_facts_block([("lease.pdf", "Unit A", {})]) == ""

    def test_facts_with_only_blank_values_are_omitted(self):
        assert build_facts_block([("lease.pdf", None, {"lease_end": None, "deposit": ""})]) == ""


class TestRendering:
    def test_renders_humanised_labels_and_values(self):
        block = build_facts_block([
            ("Ayer8 lease.pdf", "Unit B2-1-2",
             {"lease_end": "2026-10-31", "monthly_rent": 8000.0}),
        ])
        assert "Ayer8 lease.pdf" in block
        assert "Unit B2-1-2" in block
        assert "Lease end: 2026-10-31" in block
        assert "Monthly rent (RM): 8000.0" in block
        # Raw storage keys must not leak into the prompt.
        assert "lease_end" not in block

    def test_unknown_key_falls_back_to_readable_form(self):
        block = build_facts_block([("x.pdf", None, {"policy_number": "P-1"})])
        assert "Policy number: P-1" in block

    def test_missing_unit_label_reads_property_wide(self):
        block = build_facts_block([("quitrent.pdf", None, {"amount": 120.0})])
        assert "Property-wide" in block

    def test_blank_values_are_skipped_but_siblings_survive(self):
        block = build_facts_block([
            ("lease.pdf", None, {"lease_end": "2026-10-31", "deposit": None}),
        ])
        assert "Lease end: 2026-10-31" in block
        assert "Deposit" not in block

    def test_multiple_documents_render_as_separate_sections(self):
        block = build_facts_block([
            ("a.pdf", "Unit A", {"lease_end": "2026-10-31"}),
            ("b.pdf", "Unit B", {"lease_end": "2027-01-31"}),
        ])
        assert "a.pdf" in block and "b.pdf" in block
        assert "2026-10-31" in block and "2027-01-31" in block

    def test_structured_values_are_skipped(self):
        # expense_lines is a list[dict]; its repr would be hundreds of tokens
        # of Python literal in every prompt that retrieves the document.
        block = build_facts_block([
            ("bill.pdf", None, {
                "amount": 120.0,
                "expense_lines": [{"subtype": "quit_rent", "amount": 120.0}],
            }),
        ])
        assert "Amount (RM): 120.0" in block
        assert "subtype" not in block
        assert "Expense lines" not in block

    def test_tenant_name_is_included(self):
        # Explicit decision: names are permitted through to the trusted provider.
        block = build_facts_block([("lease.pdf", None, {"tenant_name": "JNT Sdn. Bhd."})])
        assert "Tenant: JNT Sdn. Bhd." in block


class TestFactsSnippet:
    def test_renders_the_same_lines_without_a_filename_header(self):
        from rag.ask.fact_context import facts_snippet
        snippet = facts_snippet({"lease_end": "2026-10-31", "monthly_rent": 8000.0})
        assert "Lease end: 2026-10-31" in snippet
        assert "Monthly rent (RM): 8000.0" in snippet
        assert "[" not in snippet  # no document header

    def test_empty_facts_give_empty_string(self):
        from rag.ask.fact_context import facts_snippet
        assert facts_snippet({}) == ""

    def test_skips_structured_and_blank_values_like_the_block_does(self):
        from rag.ask.fact_context import facts_snippet
        snippet = facts_snippet({
            "amount": 120.0, "expense_lines": [{"a": 1}], "note": None,
        })
        assert "Amount (RM): 120.0" in snippet
        assert "Expense lines" not in snippet
        assert "Note" not in snippet
