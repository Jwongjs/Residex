import unittest

from rag.pii_scrub import scrub_for_hosted


class ScrubForHostedTests(unittest.TestCase):
    """All values here are synthetic, not real personal data."""

    def test_redacts_hyphenated_nric(self):
        self.assertEqual(scrub_for_hosted("IC 123456-78-9012 holder"), "IC [NRIC] holder")

    def test_redacts_plain_12_digit_nric(self):
        self.assertEqual(scrub_for_hosted("NRIC 123456789012."), "NRIC [NRIC].")

    def test_redacts_email(self):
        self.assertEqual(scrub_for_hosted("email tenant@example.com now"), "email [EMAIL] now")

    def test_redacts_malaysian_mobile_with_dash(self):
        self.assertEqual(scrub_for_hosted("call 012-3456789"), "call [PHONE]")

    def test_redacts_international_phone_with_spaces(self):
        self.assertEqual(scrub_for_hosted("intl +60 12-345 6789 end"), "intl [PHONE] end")

    def test_redacts_landline(self):
        self.assertEqual(scrub_for_hosted("office 03-12345678"), "office [PHONE]")

    def test_preserves_amounts_dates_and_clauses(self):
        text = "Rent RM 1,500.00 due 2026-07-19 clause 5.2"
        self.assertEqual(scrub_for_hosted(text), text)

    def test_empty_returns_empty(self):
        self.assertEqual(scrub_for_hosted(""), "")

    def test_multiple_pii_in_one_string(self):
        got = scrub_for_hosted("IC 123456-78-9012 tel 012-3456789 mail a@b.com")
        self.assertEqual(got, "IC [NRIC] tel [PHONE] mail [EMAIL]")


if __name__ == "__main__":
    unittest.main()
