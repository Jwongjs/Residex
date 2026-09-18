"""Giving already-ingested documents the fact_pages map, with no re-upload.

The planner is pure — Firestore lives only in the script's main() — so these
tests need no mocks. The imprecision that matters is stated in the script's
docstring: chunk text overlaps and is reassembled rather than verbatim page
text, so a value split across a chunk boundary can be missed. An unplaced fact
stays page-less, which is the safe direction.
"""
import unittest

from scripts.backfill_fact_pages import page_texts_from_chunks, plan_backfill


def _chunk(doc_id, index, page, text):
    return {"doc_id": doc_id, "chunk_index": index, "page": page, "text": text}


class PageTextsFromChunksTests(unittest.TestCase):
    def test_groups_chunk_text_by_page_in_chunk_index_order(self):
        chunks = [
            _chunk("d1", 1, 0, "second half."),
            _chunk("d1", 0, 0, "first half,"),
            _chunk("d1", 2, 1, "page two."),
        ]
        self.assertEqual(
            page_texts_from_chunks(chunks),
            ["first half, second half.", "page two."],
        )

    def test_pages_with_no_chunks_become_empty_strings(self):
        # Index positions must line up with real page numbers, so a gap is a
        # blank page, not a shift that would misplace every later fact.
        chunks = [_chunk("d1", 0, 0, "cover"), _chunk("d1", 1, 3, "the value")]
        self.assertEqual(page_texts_from_chunks(chunks), ["cover", "", "", "the value"])

    def test_chunks_with_no_page_are_skipped(self):
        chunks = [_chunk("d1", 0, None, "unattributable"), _chunk("d1", 1, 0, "page one")]
        self.assertEqual(page_texts_from_chunks(chunks), ["page one"])

    def test_no_chunks_gives_no_pages(self):
        self.assertEqual(page_texts_from_chunks([]), [])


class PlanBackfillTests(unittest.TestCase):
    def _doc(self, doc_id="d1", facts=None, fact_pages=None):
        doc = {"doc_id": doc_id, "extracted_facts": facts if facts is not None else {"amount": 2400}}
        if fact_pages is not None:
            doc["fact_pages"] = fact_pages
        return doc

    def test_plans_the_located_map_for_a_document_that_needs_one(self):
        docs = [self._doc()]
        chunks = {"d1": [_chunk("d1", 0, 0, "cover"), _chunk("d1", 1, 1, "Total RM 2,400.00")]}
        self.assertEqual(plan_backfill(docs, chunks), [("d1", {"amount": 1})])

    def test_a_document_that_already_has_fact_pages_is_skipped(self):
        # Idempotent and re-runnable: a partial run resumes cleanly.
        docs = [self._doc(fact_pages={"amount": 1})]
        chunks = {"d1": [_chunk("d1", 0, 0, "Total RM 2,400.00")]}
        self.assertEqual(plan_backfill(docs, chunks), [])

    def test_a_document_with_no_facts_is_skipped(self):
        docs = [self._doc(facts={})]
        chunks = {"d1": [_chunk("d1", 0, 0, "Total RM 2,400.00")]}
        self.assertEqual(plan_backfill(docs, chunks), [])

    def test_a_document_with_no_chunks_is_skipped_without_error(self):
        self.assertEqual(plan_backfill([self._doc()], {}), [])

    def test_a_document_where_nothing_locates_is_not_written(self):
        # Writing an empty map would make the "already has fact_pages" skip
        # useless on the next run, and would claim we tried and succeeded.
        docs = [self._doc()]
        chunks = {"d1": [_chunk("d1", 0, 0, "nothing relevant here")]}
        self.assertEqual(plan_backfill(docs, chunks), [])

    def test_plans_several_documents_in_input_order(self):
        docs = [self._doc("d1"), self._doc("d2", facts={"lease_end": "2026-10-31"})]
        chunks = {
            "d1": [_chunk("d1", 0, 0, "RM 2,400.00")],
            "d2": [_chunk("d2", 0, 0, "cover"), _chunk("d2", 1, 2, "ends 31 October 2026")],
        }
        self.assertEqual(
            plan_backfill(docs, chunks),
            [("d1", {"amount": 0}), ("d2", {"lease_end": 2})],
        )


if __name__ == "__main__":
    unittest.main()
