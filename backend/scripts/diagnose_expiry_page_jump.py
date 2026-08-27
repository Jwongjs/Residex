"""Read-only diagnostic: for a given unit/property name filter, dump each
lease document's stored `fact_pages` alongside its `lease_end` value, plus
the document's file_size, to see why the dashboard's expiry-tile page jump
behaves inconsistently across documents (blank viewer vs. landing on page 1).

Does NOT write anything.

    uv run python scripts/diagnose_expiry_page_jump.py            # all
    uv run python scripts/diagnose_expiry_page_jump.py Damai      # name contains "Damai"
"""
from __future__ import annotations

import sys

from dotenv import load_dotenv
load_dotenv()

from google.cloud import firestore

db = firestore.Client()

name_filter = (sys.argv[1] if len(sys.argv) > 1 else "").lower()

props = {}
for snap in db.collection("properties").stream():
    data = snap.to_dict() or {}
    props[snap.id] = data.get("name") or snap.id

by_prop = {}
for snap in db.collection("documind_docs").stream():
    data = snap.to_dict() or {}
    data["doc_id"] = snap.id
    by_prop.setdefault(data.get("property_id"), []).append(data)

for pid, name in sorted(props.items(), key=lambda kv: (kv[1] or "").lower()):
    if name_filter and name_filter not in (name or "").lower():
        continue
    docs = by_prop.get(pid, [])
    leases = [d for d in docs if d.get("category") == "lease"]
    if not leases:
        continue

    print("=" * 78)
    print(f"PROPERTY  {name}   (property_id={pid})")
    for d in leases:
        facts = d.get("extracted_facts") or {}
        fact_pages = d.get("fact_pages")
        print(
            f"  doc_id={d['doc_id']}  unit_id={d.get('unit_id')!r}"
            f"  unit_label={d.get('unit_label')!r}"
        )
        print(
            f"      filename={d.get('filename')!r}"
            f"  file_size={d.get('file_size')!r}"
            f"  chunks_indexed={d.get('chunks_indexed')!r}"
        )
        print(
            f"      lease_end={facts.get('lease_end')!r}"
            f"  fact_pages={fact_pages!r}"
        )
    print()
