import unittest

from rag.documind_service import (
    ALLOWED_CATEGORIES,
    CATEGORY_ORDER,
    expand_categories_for_query,
    normalize_category,
)


class CategoryAliasTests(unittest.TestCase):
    def test_allowed_categories_are_the_seven_new_names(self):
        self.assertEqual(
            ALLOWED_CATEGORIES,
            {"lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice"},
        )
        self.assertEqual(sorted(ALLOWED_CATEGORIES), sorted(CATEGORY_ORDER))

    def test_normalize_maps_legacy_names(self):
        self.assertEqual(normalize_category("utility"), "upkeep")
        self.assertEqual(normalize_category("receipt"), "rental_invoice")
        self.assertEqual(normalize_category("warranty"), "upkeep")

    def test_normalize_passes_through_current_names_and_none(self):
        self.assertEqual(normalize_category("lease"), "lease")
        self.assertEqual(normalize_category(" Loan "), "loan")
        self.assertIsNone(normalize_category(None))

    def test_expand_adds_legacy_spellings(self):
        self.assertEqual(
            expand_categories_for_query(["upkeep"]), ["upkeep", "utility", "warranty"]
        )
        self.assertEqual(
            expand_categories_for_query(["rental_invoice"]), ["rental_invoice", "receipt"]
        )
        self.assertEqual(expand_categories_for_query(["lease"]), ["lease"])
