import unittest

from rag.documents import table_extraction
from rag.documents.table_extraction import (
    looks_reconstructed,
    plain_text,
    reconstruct_rows,
)

PAGE_WIDTH = 2000
HEADER = ("level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\t"
          "left\ttop\twidth\theight\tconf\ttext")


def tsv(lines, page_width=PAGE_WIDTH):
    """Tesseract TSV for `lines`, each (block, line, y, [(x, text), ...]).

    Emitted in the order given, so a test can reproduce Tesseract handing back
    a table's label column as its own trailing block.
    """
    rows = [HEADER, f"1\t1\t0\t0\t0\t0\t0\t0\t{page_width}\t3000\t-1\t"]
    for block, line, y, words in lines:
        for i, (x, text) in enumerate(words):
            rows.append(f"5\t1\t{block}\t1\t{line}\t{i}\t{x}\t{y}\t"
                        f"{len(text) * 12}\t30\t96\t{text}")
    return "\n".join(rows)


def row_words(x, text, step=12):
    """Words laid left to right from `x`, spaced as ordinary word gaps."""
    out, cursor = [], x
    for word in text.split():
        out.append((cursor, word))
        cursor += len(word) * step + 15
    return out


class ReconstructRowsTests(unittest.TestCase):
    def test_wrapped_cell_joins_the_row_above_not_its_own_row(self):
        page = tsv([
            (1, 0, 100, [(100, "1."), (400, "Term"), (900, "Three")]),
            (1, 1, 140, [(900, "(3)"), (930, "year")]),   # wrapped, indented
            (1, 2, 180, [(100, "2."), (400, "Commencing"), (900, "01-11-2023")]),
            (1, 3, 220, [(100, "3."), (400, "Terminating"), (900, "31-10-2026")]),
            (1, 4, 260, [(100, "4."), (400, "Deposit"), (900, "RM16,000")]),
        ])
        rows = reconstruct_rows(page)
        self.assertEqual(len(rows), 4)
        self.assertIn("Three (3) year", rows[0])
        self.assertIn("Terminating", rows[2])
        self.assertIn("31-10-2026", rows[2])

    def test_label_column_emitted_as_a_trailing_block_is_put_back_in_order(self):
        """The Ayer 8 Schedule failure: Tesseract segments the section-number
        column as its own block and emits it after every value, so plain text
        arrives with the labels in a lump at the end of the page."""
        page = tsv([
            (1, 0, 100, [(400, "Commencing"), (900, "01-11-2023")]),
            (1, 1, 140, [(400, "Terminating"), (900, "31-10-2026")]),
            (1, 2, 180, [(400, "Monthly"), (900, "RM8,000")]),
            (1, 3, 220, [(400, "Deposit"), (900, "RM16,000")]),
            (9, 0, 100, [(100, "5b.")]),   # the detached label column,
            (9, 1, 140, [(100, "5c.")]),   # emitted last by Tesseract but
            (9, 2, 180, [(100, "6a.")]),   # belonging beside the values above
            (9, 3, 220, [(100, "7.")]),
        ])
        rows = reconstruct_rows(page)
        self.assertEqual(len(rows), 4)
        self.assertTrue(rows[1].startswith("5c."), rows[1])
        self.assertIn("31-10-2026", rows[1])
        self.assertIn("Terminating", rows[1])

    def test_hyphen_broken_label_does_not_open_a_second_row(self):
        page = tsv([
            (1, 0, 100, [(100, "SEC-")]),
            (1, 1, 130, [(100, "TION"), (400, "Items"), (900, "Particulars")]),
            (1, 2, 180, [(100, "1."), (400, "Term"), (900, "Three")]),
            (1, 3, 220, [(100, "2."), (400, "Rent"), (900, "RM8,000")]),
            (1, 4, 260, [(100, "3."), (400, "Deposit"), (900, "RM16,000")]),
        ])
        rows = reconstruct_rows(page)
        self.assertTrue(rows[0].startswith("SECTION"), rows[0])

    def test_prose_page_is_not_a_table(self):
        lines = [(1, i, 100 + i * 40,
                  row_words(100, "the tenant shall pay the rent monthly"))
                 for i in range(8)]
        self.assertIsNone(reconstruct_rows(tsv(lines)))

    def test_too_few_rows_is_not_a_table(self):
        page = tsv([
            (1, 0, 100, [(100, "1."), (400, "Term"), (900, "Three")]),
            (1, 1, 140, [(100, "2."), (400, "Rent"), (900, "RM8,000")]),
        ])
        self.assertIsNone(reconstruct_rows(page))

    def test_empty_and_malformed_tsv_return_none(self):
        self.assertIsNone(reconstruct_rows(""))
        self.assertIsNone(reconstruct_rows("not a tsv at all"))
        self.assertIsNone(reconstruct_rows(HEADER))

    def test_ocr_rule_glyphs_become_cell_boundaries(self):
        page = tsv([
            (1, 0, 100, [(100, "1."), (400, "Term"), (700, "|"), (900, "Three")]),
            (1, 1, 140, [(100, "2."), (400, "Rent"), (700, "|"), (900, "RM8,000")]),
            (1, 2, 180, [(100, "3."), (400, "Dep"), (700, "|"), (900, "RM16,000")]),
            (1, 3, 220, [(100, "4."), (400, "Use"), (700, "|"), (900, "Office")]),
        ])
        rows = reconstruct_rows(page)
        self.assertEqual(rows[0].count(" | "), 2, rows[0])


class PlainTextTests(unittest.TestCase):
    def test_two_column_prose_keeps_tesseracts_order_not_geometric_order(self):
        """Sorting by y would interleave the columns line by line. Only the
        table path, which has established the page IS a table, may re-sort."""
        page = tsv([
            (1, 0, 100, [(100, "left-one")]),
            (1, 1, 140, [(100, "left-two")]),
            (2, 0, 100, [(1200, "right-one")]),
            (2, 1, 140, [(1200, "right-two")]),
        ])
        self.assertEqual(plain_text(page).split(),
                         ["left-one", "left-two", "right-one", "right-two"])

    def test_plain_text_of_empty_tsv_is_empty(self):
        self.assertEqual(plain_text(""), "")


class PageTextTests(unittest.TestCase):
    def test_table_page_is_emitted_as_blank_line_separated_rows(self):
        page = tsv([
            (1, 0, 100, [(100, "1."), (400, "Term"), (900, "Three")]),
            (1, 1, 140, [(100, "2."), (400, "Commencing"), (900, "01-11-2023")]),
            (1, 2, 180, [(100, "3."), (400, "Terminating"), (900, "31-10-2026")]),
            (1, 3, 220, [(100, "4."), (400, "Deposit"), (900, "RM16,000")]),
        ])
        text = table_extraction.page_text(page)
        self.assertEqual(len(text.split("\n\n")), 4)
        self.assertTrue(looks_reconstructed(text))

    def test_prose_page_falls_back_to_the_plain_transcription(self):
        lines = [(1, i, 100 + i * 40,
                  row_words(100, "the tenant shall pay the rent monthly"))
                 for i in range(8)]
        page = tsv(lines)
        self.assertEqual(table_extraction.page_text(page), plain_text(page))


class LooksReconstructedTests(unittest.TestCase):
    def test_recognises_only_its_own_output_shape(self):
        self.assertTrue(looks_reconstructed(
            "1. | Term | Three\n\n2. | Rent | RM8,000\n\n3. | Dep | RM16,000\n\n4. | x"))
        self.assertFalse(looks_reconstructed(
            "A paragraph.\n\nAnother one.\n\nA third.\n\nA fourth."))
        self.assertFalse(looks_reconstructed(""))
        self.assertFalse(looks_reconstructed(None))


class NonTsvOutputTests(unittest.TestCase):
    """A Tesseract build that ignores `tessedit_create_tsv` returns ordinary
    text. Parsing that as TSV finds no words, and returning "" would turn every
    scanned page blank -- an OCR outage that looks like an empty document."""

    def test_plain_transcription_is_passed_through_untouched(self):
        transcription = "INVOICE\nService charge RM880.00\nTotal RM840.40"
        self.assertEqual(table_extraction.page_text(transcription), transcription)
        self.assertEqual(plain_text(transcription), transcription)

    def test_a_genuinely_blank_tsv_page_stays_blank(self):
        self.assertEqual(table_extraction.page_text(HEADER), "")

    def test_is_tsv_discriminates(self):
        self.assertTrue(table_extraction.is_tsv(HEADER))
        self.assertFalse(table_extraction.is_tsv("hello world"))
        self.assertFalse(table_extraction.is_tsv(""))


if __name__ == "__main__":
    unittest.main()
