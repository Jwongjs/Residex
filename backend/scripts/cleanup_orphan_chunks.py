"""Delete orphan documind_chunks (chunks whose doc_id has no documind_docs parent).

A failed upload (e.g. the Cloud Storage bucket 404 that happened before the fix)
writes chunks to Firestore *before* the document metadata record, so when the upload
step raises, the chunks are left with no parent doc: they are still retrievable by the
RAG search, but invisible in the Docs tab and undeletable from the app. Each failed
attempt adds another orphan set. This script purges them.

Run from the backend/ directory:

    uv run python scripts/cleanup_orphan_chunks.py           # dry run (counts only)
    uv run python scripts/cleanup_orphan_chunks.py --apply   # actually delete

Safe: it only deletes chunks whose doc_id is absent from documind_docs, so chunks of
successfully-uploaded documents are never touched.
"""
import sys
from collections import Counter

from dotenv import load_dotenv

load_dotenv()

from google.cloud import firestore  # noqa: E402  (import after load_dotenv)


def main() -> None:
    apply = "--apply" in sys.argv
    db = firestore.Client()

    valid_doc_ids = {d.id for d in db.collection("documind_docs").stream()}
    print(f"documind_docs: {len(valid_doc_ids)} valid document(s)")

    orphan_refs = []
    by_file: Counter = Counter()
    for chunk in db.collection("documind_chunks").stream():
        data = chunk.to_dict() or {}
        if data.get("doc_id") not in valid_doc_ids:
            orphan_refs.append(chunk.reference)
            by_file[(data.get("filename"), data.get("doc_id"))] += 1

    print(f"orphan chunks: {len(orphan_refs)}")
    for (filename, doc_id), n in sorted(by_file.items(), key=lambda x: -x[1]):
        print(f"  {n:>4}  {filename}  (doc_id={doc_id})")

    if not orphan_refs:
        print("Nothing to clean.")
        return
    if not apply:
        print("\nDry run — re-run with --apply to delete the above.")
        return

    deleted = 0
    while orphan_refs:
        batch = db.batch()
        window = orphan_refs[:400]  # Firestore batch limit is 500
        for ref in window:
            batch.delete(ref)
        batch.commit()
        deleted += len(window)
        orphan_refs = orphan_refs[400:]
    print(f"Deleted {deleted} orphan chunk(s).")


if __name__ == "__main__":
    main()
