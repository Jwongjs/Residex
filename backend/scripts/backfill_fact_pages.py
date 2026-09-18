"""Backfill `fact_pages` for documents ingested before pages were located.

A citation derived from an extracted fact opens the document at the page that
states the value — but only when `fact_pages` exists. Fresh uploads get it at
ingestion; this gives it to everything already indexed, with no re-upload.

Run from the backend/ directory:

    uv run python scripts/backfill_fact_pages.py           # dry run (reports only)
    uv run python scripts/backfill_fact_pages.py --apply   # actually write

Dry run by default because it touches live Firestore: it must be able to
report exactly what it would write before writing anything.

Idempotent and re-runnable: a document that already has `fact_pages` is
skipped, so a partial run resumes cleanly.

Known imprecision: page text is reassembled from stored chunks, which overlap
by 200 characters and are not verbatim page text, so this may place marginally
fewer facts than fresh ingestion does. An unplaced fact stays page-less, which
is the safe direction — page 1 reads as an obvious fallback, a wrong page
reads as authoritative.
"""
import os
import sys
from collections import defaultdict
from typing import Dict, List, Tuple

# Put backend/ (this file's grandparent) on the path so `rag` imports whether
# launched as `python scripts/backfill_fact_pages.py` or `-m scripts...`.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from google.cloud import firestore  # noqa: E402  (import after load_dotenv)
from google.cloud.firestore_v1.base_query import FieldFilter  # noqa: E402

from rag.documents.fact_locator import locate_facts  # noqa: E402


def page_texts_from_chunks(chunks: List[dict]) -> List[str]:
    """Approximate per-page text from a document's stored chunks.

    Indexed by page number, so position i is page i — a page with no chunks
    becomes an empty string rather than shifting every later page and
    misplacing every fact after it.

    Chunks with no page cannot be attributed and are dropped; there is nothing
    truthful to do with them.
    """
    by_page: Dict[int, List[Tuple[int, str]]] = defaultdict(list)
    for chunk in chunks:
        page = chunk.get("page")
        if not isinstance(page, int) or isinstance(page, bool):
            continue
        by_page[page].append((chunk.get("chunk_index") or 0, chunk.get("text") or ""))
    if not by_page:
        return []
    return [
        " ".join(text for _, text in sorted(by_page.get(page, [])))
        for page in range(max(by_page) + 1)
    ]


def plan_backfill(
    docs: List[dict], chunks_by_doc: Dict[str, List[dict]]
) -> List[Tuple[str, Dict[str, int]]]:
    """(doc_id, fact_pages) for every document that needs a map written.

    A document is skipped when it already has `fact_pages`, when it has no
    facts, when it has no chunks, or when nothing could be located — writing
    an empty map would defeat the "already has fact_pages" skip on the next
    run and would claim a placement that was never made.
    """
    plan: List[Tuple[str, Dict[str, int]]] = []
    for doc in docs:
        if doc.get("fact_pages"):
            continue
        facts = doc.get("extracted_facts") or {}
        if not facts:
            continue
        chunks = chunks_by_doc.get(doc.get("doc_id")) or []
        if not chunks:
            continue
        located = locate_facts(facts, page_texts_from_chunks(chunks))
        if not located:
            continue
        plan.append((doc["doc_id"], located))
    return plan


def main() -> None:
    apply = "--apply" in sys.argv
    db = firestore.Client()

    docs = []
    for snap in db.collection("documind_docs").stream():
        data = snap.to_dict() or {}
        data.setdefault("doc_id", snap.id)
        docs.append(data)
    print(f"documind_docs: {len(docs)} document(s)")

    candidate_ids = {
        doc["doc_id"] for doc in docs
        if doc.get("extracted_facts") and not doc.get("fact_pages")
    }
    print(f"candidates (facts, no fact_pages): {len(candidate_ids)}")
    if not candidate_ids:
        print("Nothing to backfill.")
        return

    # Sorted in Python rather than order_by, which would need a composite
    # index alongside the doc_id filter.
    chunks_by_doc: Dict[str, List[dict]] = defaultdict(list)
    for doc_id in sorted(candidate_ids):
        query = db.collection("documind_chunks").where(
            filter=FieldFilter("doc_id", "==", doc_id)
        )
        for snap in query.stream():
            chunks_by_doc[doc_id].append(snap.to_dict() or {})

    plan = plan_backfill(docs, chunks_by_doc)
    by_id = {doc["doc_id"]: doc for doc in docs}
    for doc_id, fact_pages in plan:
        filename = by_id.get(doc_id, {}).get("filename", doc_id)
        placed = ", ".join(f"{key}=p.{index + 1}" for key, index in sorted(fact_pages.items()))
        total = len(by_id.get(doc_id, {}).get("extracted_facts") or {})
        print(f"  {filename}: {len(fact_pages)}/{total} located  ({placed})")
    print(f"\nwould write fact_pages for {len(plan)} of {len(candidate_ids)} candidate(s)")

    if not apply:
        print("Dry run — re-run with --apply to write the above.")
        return

    for doc_id, fact_pages in plan:
        db.collection("documind_docs").document(doc_id).update({"fact_pages": fact_pages})
    print(f"Wrote fact_pages for {len(plan)} document(s).")


if __name__ == "__main__":
    main()
