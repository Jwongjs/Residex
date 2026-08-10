"""Read-only: list every stored rent recovery on a partial-share property.

The finance engine currently multiplies recovered rent by ownership_share on
read (finance_engine.py:1274). The unit-panel share reconciliation plan stops
doing that, because the recovery sheet will ask the landlord for their own
share directly. Recoveries already stored at face value on a property with
share < 1.0 would therefore start being booked in full.

Writes nothing. Run before the engine change:
    cd backend && uv run python scripts/audit_rent_recovery_shares.py
"""
import os
import sys

# Put backend/ (this file's grandparent) on the path so `rag` imports whether
# launched as `python scripts/...` or `-m scripts...`.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from google.cloud import firestore  # noqa: E402  (import after load_dotenv)


def main() -> int:
    db = firestore.Client()
    shares = {}
    for snap in db.collection('documind_properties').stream():
        data = snap.to_dict() or {}
        share = data.get('ownership_share')
        shares[snap.id] = (
            data.get('name') or snap.id,
            1.0 if share is None else float(share),
        )

    affected = []
    total = 0
    for snap in db.collection('documind_rent_recoveries').stream():
        data = snap.to_dict() or {}
        total += 1
        pid = data.get('property_id')
        name, share = shares.get(pid, (pid, 1.0))
        if share < 1.0:
            affected.append((snap.id, name, share, data.get('original_month'),
                             data.get('received_year'), data.get('amount')))

    print(f"{total} rent recovery record(s) scanned.")
    if not affected:
        print("0 on a partial-share property — no correction needed.")
        return 0

    print(f"{len(affected)} on a partial-share property:\n")
    for doc_id, name, share, month, year, amount in affected:
        print(f"  {doc_id}")
        print(f"    property   {name} at {share:.0%}")
        print(f"    original   {month}   received {year}")
        print(f"    amount     RM {float(amount or 0):,.2f}"
              f"  ->  would become RM {float(amount or 0) * share:,.2f}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
