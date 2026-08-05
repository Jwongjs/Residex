"""Loading extracted facts for the documents retrieval actually hit.

Scope is deliberately narrow: only doc_ids present in the retrieved chunks.
The lookup must never raise — a facts failure degrades the answer to
chunks-only, it never fails the request.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.documind_service import DocuMindService


class _Snap:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return self._data


class _DocRef:
    def __init__(self, data):
        self._data = data

    def get(self):
        return _Snap(self._data)


class _ExplodingDocRef:
    def get(self):
        raise RuntimeError("firestore unavailable")


class _Collection:
    def __init__(self, docs, explode_on=None):
        self._docs = docs
        self._explode_on = explode_on

    def document(self, doc_id):
        if doc_id == self._explode_on:
            return _ExplodingDocRef()
        return _DocRef(self._docs.get(doc_id))


class _DB:
    def __init__(self, docs, explode_on=None):
        self._docs = docs
        self._explode_on = explode_on
        self.requested_collections = []

    def collection(self, name):
        self.requested_collections.append(name)
        return _Collection(self._docs, self._explode_on)


def _service(docs, explode_on=None):
    service = DocuMindService.__new__(DocuMindService)
    service._db = _DB(docs, explode_on)
    return service


class TestDocumentFactsLookup:
    def test_returns_filename_unit_label_and_facts(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": "Unit A",
                   "extracted_facts": {"lease_end": "2026-10-31"}},
        })
        assert service._get_document_facts(["d1"]) == [
            ("lease.pdf", "Unit A", {"lease_end": "2026-10-31"}),
        ]

    def test_deduplicates_doc_ids_preserving_order(self):
        service = _service({
            "d1": {"filename": "a.pdf", "unit_label": None,
                   "extracted_facts": {"amount": 1}},
            "d2": {"filename": "b.pdf", "unit_label": None,
                   "extracted_facts": {"amount": 2}},
        })
        result = service._get_document_facts(["d1", "d2", "d1"])
        assert [row[0] for row in result] == ["a.pdf", "b.pdf"]

    def test_document_without_facts_is_omitted(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": None, "extracted_facts": {}},
        })
        assert service._get_document_facts(["d1"]) == []

    def test_missing_document_is_omitted(self):
        service = _service({})
        assert service._get_document_facts(["nope"]) == []

    def test_firestore_error_is_swallowed_and_skips_that_doc(self):
        service = _service(
            {"d2": {"filename": "ok.pdf", "unit_label": None,
                    "extracted_facts": {"amount": 5}}},
            explode_on="d1",
        )
        # d1 raises; d2 must still come back.
        assert service._get_document_facts(["d1", "d2"]) == [
            ("ok.pdf", None, {"amount": 5}),
        ]

    def test_empty_input_makes_no_firestore_call(self):
        service = _service({})
        assert service._get_document_facts([]) == []
        assert service._db.requested_collections == []
