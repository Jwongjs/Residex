"""Read-only diagnostic: download a document's stored PDF from Cloud Storage
and report its page count + whether each page has extractable text/visible
content, to check whether a "blank in the viewer" report is a real
near-empty file rather than a page-jump bug.

    uv run python scripts/inspect_damai_lease_pdf.py <doc_id>
"""
from __future__ import annotations

import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

from firebase_admin import storage
from google.cloud import firestore
from pypdf import PdfReader

from firebase_app import ensure_initialized

doc_id = sys.argv[1] if len(sys.argv) > 1 else "5ab93781-cf04-4a63-bb94-4f21c64ef52b"

db = firestore.Client()
snap = db.collection("documind_docs").document(doc_id).get()
if not snap.exists:
    print(f"No such document: {doc_id}")
    sys.exit(1)

data = snap.to_dict() or {}
storage_path = data.get("storage_path")
print(f"doc_id={doc_id}  filename={data.get('filename')!r}  storage_path={storage_path!r}")

if not storage_path:
    print("No storage_path on this document.")
    sys.exit(1)

ensure_initialized()
bucket = storage.bucket()
blob = bucket.blob(storage_path)
raw = blob.download_as_bytes()
print(f"downloaded {len(raw)} bytes")

reader = PdfReader(io.BytesIO(raw))
print(f"page_count={len(reader.pages)}")
for i, page in enumerate(reader.pages):
    text = (page.extract_text() or "").strip()
    print(f"  page {i}: {len(text)} chars of text" + (f"  -> {text[:80]!r}" if text else "  -> EMPTY"))
