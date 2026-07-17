import unittest

from rag.documind_service import (
    ALLOWED_CATEGORIES,
    CATEGORY_ORDER,
    EXPENSE_GROUP,
    expand_categories_for_query,
    normalize_category,
)


class CategoryAliasTests(unittest.TestCase):
    def test_allowed_categories_are_the_seven_new_names_plus_expenses(self):
        self.assertEqual(
            ALLOWED_CATEGORIES,
            {"lease", "insurance", "loan", "tax", "upkeep", "maintenance",
             "rental_invoice", "expenses"},
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
            expand_categories_for_query(["upkeep"]),
            ["upkeep", "utility", "warranty", "expenses"],
        )
        self.assertEqual(
            expand_categories_for_query(["rental_invoice"]), ["rental_invoice", "receipt"]
        )
        self.assertEqual(expand_categories_for_query(["lease"]), ["lease"])

    def test_expenses_category_is_allowed(self):
        self.assertIn("expenses", ALLOWED_CATEGORIES)
        self.assertIn("expenses", CATEGORY_ORDER)

    def test_expenses_filter_expands_to_granular_and_legacy_names(self):
        expanded = expand_categories_for_query(["expenses"])
        for name in ["expenses", "insurance", "loan", "tax", "upkeep",
                     "maintenance", "utility", "warranty"]:
            self.assertIn(name, expanded)
        self.assertNotIn("lease", expanded)
        self.assertNotIn("rental_invoice", expanded)

    def test_granular_expense_filter_includes_combined_statements(self):
        self.assertEqual(
            expand_categories_for_query(["insurance"]), ["insurance", "expenses"]
        )
        self.assertEqual(
            expand_categories_for_query(["upkeep"]),
            ["upkeep", "utility", "warranty", "expenses"],
        )

    def test_lease_filter_is_unchanged(self):
        self.assertEqual(expand_categories_for_query(["lease"]), ["lease"])
