"""Read-only diagnostic: dump the stored lease + rental-invoice facts for a
property so we can see WHY the finance dashboard shows the wrong rent.

Does NOT write anything. Run from the backend directory so credentials
(.env / serviceAccountKey.json) resolve exactly as the app resolves them:

    uv run python scripts/diagnose_ayer8_lease.py            # all properties
    uv run python scripts/diagnose_ayer8_lease.py Ayer       # name contains "Ayer"

It prints, per property, every lease document (amount + span + upload order,
which is exactly what compute_finance_summary() selects on) and every
rental_invoice for 2023-2025 (an actual invoice overrides lease-derived rent).
"""
from __future__ import annotations

import sys

from dotenv import load_dotenv
load_dotenv()

from google.cloud import firestore

db = firestore.Client()

name_filter = (sys.argv[1] if len(sys.argv) > 1 else "").lower()


def _facts(doc):
    return doc.get("extracted_facts") or {}


# property_id -> display name
props = {}
for snap in db.collection("properties").stream():
    data = snap.to_dict() or {}
    props[snap.id] = data.get("name") or snap.id

# Gather all documind_docs grouped by property.
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
    invoices = [d for d in docs if d.get("category") == "rental_invoice"]

    print("=" * 78)
    print(f"PROPERTY  {name}   (property_id={pid})")
    print(f"  lease docs: {len(leases)}   rental_invoice docs: {len(invoices)}")

    print("\n  LEASES (upload order = precedence; LAST valid one wins the whole scope):")
    for d in sorted(leases, key=lambda x: (x.get("uploaded_at") is not None, x.get("uploaded_at"))):
        f = _facts(d)
        print(
            f"    - doc_id={d['doc_id']}  unit_id={d.get('unit_id')!r}"
            f"  uploaded_at={d.get('uploaded_at')}"
        )
        print(
            f"        monthly_rent={f.get('monthly_rent')!r}"
            f"  lease_start={f.get('lease_start')!r}"
            f"  lease_end={f.get('lease_end')!r}"
            f"  subtype={f.get('subtype')!r}"
        )

    inv_2325 = [
        d for d in invoices
        if str(_facts(d).get("period_month", ""))[:4] in {"2023", "2024", "2025"}
    ]
    print(f"\n  RENTAL INVOICES 2023-2025 ({len(inv_2325)}):")
    for d in sorted(inv_2325, key=lambda x: str(_facts(x).get("period_month", ""))):
        f = _facts(d)
        print(
            f"    - {f.get('period_month')!r:>10}  amount={f.get('amount')!r}"
            f"  unit_id={d.get('unit_id')!r}  doc_id={d['doc_id']}"
        )
    print()
