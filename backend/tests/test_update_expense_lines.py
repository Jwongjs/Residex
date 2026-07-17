import asyncio
import unittest

from rag.documind_service import documind_service


class TestUpdateExpenseLinesValidation(unittest.TestCase):
    def test_rejects_lines_with_unknown_subtypes(self):
        with self.assertRaises(ValueError):
            asyncio.run(documind_service.update_expense_lines(
                doc_id="missing",
                landlord_id="landlord-1",
                lines=[{"subtype": "bogus", "amount": 10.0}],
            ))

    def test_rejects_empty_list(self):
        with self.assertRaises(ValueError):
            asyncio.run(documind_service.update_expense_lines(
                doc_id="missing", landlord_id="landlord-1", lines=[],
            ))
