"""Correct the mis-extracted Ayer 8 lease facts.

The extractor stored monthly_rent=2500 and a fabricated 1-year term; the real
tenancy is RM8000/month, 2023-11-01 .. 2026-10-31. No app/API path edits lease
facts, so this patches the stored extracted_facts directly.

Read-modify-write: only monthly_rent / lease_start / lease_end change; every
other fact key is preserved. DRY-RUN by default — prints the before/after diff
and writes NOTHING. Re-run with --apply to commit.

    uv run python scripts/fix_ayer8_lease_facts.py            # preview only
    uv run python scripts/fix_ayer8_lease_facts.py --apply    # write it
"""
from __future__ import annotations

import sys

from dotenv import load_dotenv
load_dotenv()

from google.cloud import firestore

DOC_ID = "1512f295-8151-4e65-8d7b-81c3f60ef0a3"
EXPECT_PROPERTY_ID = "zHesu7tDJsNFhl3En2is"      # Ayer 8 — guard against wrong doc
EXPECT_CATEGORY = "lease"

CORRECTIONS = {
    "monthly_rent": 8000.0,
    "lease_start": "2023-11-01",   # 1 Nov 2023
    "lease_end": "2026-10-31",     # 31 Oct 2026
}

apply = "--apply" in sys.argv

db = firestore.Client()
doc_ref = db.collection("documind_docs").document(DOC_ID)
snap = doc_ref.get()

if not snap.exists:
    sys.exit(f"ABORT: document {DOC_ID} not found.")

data = snap.to_dict() or {}

# Guards: never write unless this is the exact lease document we diagnosed.
if data.get("property_id") != EXPECT_PROPERTY_ID:
    sys.exit(f"ABORT: property_id is {data.get('property_id')!r}, expected {EXPECT_PROPERTY_ID!r}.")
if data.get("category") != EXPECT_CATEGORY:
    sys.exit(f"ABORT: category is {data.get('category')!r}, expected {EXPECT_CATEGORY!r}.")

old_facts = dict(data.get("extracted_facts") or {})
new_facts = dict(old_facts)
new_facts.update(CORRECTIONS)

print(f"Document : {DOC_ID}")
print(f"Property : {data.get('property_id')}   unit_id={data.get('unit_id')!r}")
print("\nField changes:")
for key in CORRECTIONS:
    before = old_facts.get(key)
    after = new_facts[key]
    mark = " (unchanged)" if before == after else ""
    print(f"    {key:<13} {before!r:>14}  ->  {after!r}{mark}")

untouched = [k for k in old_facts if k not in CORRECTIONS]
print(f"\nPreserved facts ({len(untouched)}): {', '.join(untouched) or '(none)'}")

if not apply:
    print("\nDRY RUN — nothing written. Re-run with --apply to commit.")
    sys.exit(0)

doc_ref.update({"extracted_facts": new_facts})
print("\nWRITTEN. Re-reading to confirm...")
confirm = (doc_ref.get().to_dict() or {}).get("extracted_facts") or {}
for key in CORRECTIONS:
    print(f"    stored {key:<13} = {confirm.get(key)!r}")
