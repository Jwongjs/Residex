import re
from typing import Any, Dict, List, Optional

from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

_PAYMENT_MONTH_RE = re.compile(r"^\d{4}-\d{2}$")


class FinanceOverridesRepository:
    """CRUD for the 5 Firestore collections that adjust the deterministic
    finance fold: payment exceptions, document-unavailable acknowledgements,
    rent recoveries, manual loan entries, and unit loan exemptions."""

    def __init__(self, db):
        self._db = db

    def _require_owned_property(self, property_id: str, landlord_id: str) -> None:
        property_ref = self._db.collection('properties').document(property_id)
        property_snapshot = property_ref.get()
        if not property_snapshot.exists or (property_snapshot.to_dict() or {}).get('landlordId') != landlord_id:
            raise ValueError(f"Property {property_id} not found for landlord {landlord_id}")

    # -- payment exceptions --------------------------------------------

    def _payment_exception_doc_id(self, property_id: str, unit_id: Optional[str], month: str) -> str:
        return f"{property_id}__{unit_id or 'property'}__{month}"

    async def set_payment_exception(
        self, *, landlord_id: str, property_id: str, month: str,
        unit_id: Optional[str] = None, reason: Optional[str] = None,
        state: str = "outstanding",
    ) -> Dict[str, Any]:
        """Upsert a 'no payment received' mark for one month. Deterministic
        doc id keeps set/clear idempotent — no duplicate marks possible."""
        if not _PAYMENT_MONTH_RE.match(month or ""):
            raise ValueError("month must be formatted YYYY-MM")
        self._require_owned_property(property_id, landlord_id)
        doc_id = self._payment_exception_doc_id(property_id, unit_id, month)
        ref = self._db.collection('documind_payment_exceptions').document(doc_id)
        ref.set({
            'landlord_id': landlord_id, 'property_id': property_id, 'unit_id': unit_id,
            'month': month, 'reason': reason, 'state': state,
            'created_at': firestore.SERVER_TIMESTAMP,
        })
        return {"property_id": property_id, "unit_id": unit_id, "month": month, "reason": reason, "state": state}

    async def clear_payment_exception(
        self, *, landlord_id: str, property_id: str, month: str, unit_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Remove a 'no payment received' mark, if any. Idempotent — clearing
        an unmarked month is a no-op, not an error."""
        doc_id = self._payment_exception_doc_id(property_id, unit_id, month)
        ref = self._db.collection('documind_payment_exceptions').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "unit_id": unit_id, "month": month}

    # -- document-unavailable acknowledgements ---------------------------

    def _document_exception_doc_id(self, property_id: str, year: int, category: str) -> str:
        return f"{property_id}__{year}__{category}"

    async def set_document_unavailable(
        self, *, landlord_id: str, property_id: str, year: int, category: str,
    ) -> Dict[str, Any]:
        """Acknowledge that a coverage gap cannot be filled, so the year
        settles as complete-with-gaps instead of nagging permanently.
        Idempotent — re-marking the same scope is a no-op."""
        self._require_owned_property(property_id, landlord_id)
        doc_id = self._document_exception_doc_id(property_id, year, category)
        ref = self._db.collection('documind_document_exceptions').document(doc_id)
        ref.set({
            'landlord_id': landlord_id, 'property_id': property_id, 'year': year,
            'category': category, 'marked_at': firestore.SERVER_TIMESTAMP,
        })
        return {"property_id": property_id, "year": year, "category": category}

    async def clear_document_unavailable(
        self, *, landlord_id: str, property_id: str, year: int, category: str,
    ) -> Dict[str, Any]:
        """Clear an 'unavailable' mark. Idempotent — clearing an unmarked
        scope is a no-op, not an error."""
        doc_id = self._document_exception_doc_id(property_id, year, category)
        ref = self._db.collection('documind_document_exceptions').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "year": year, "category": category}

    # -- rent recoveries --------------------------------------------------

    def _rent_recovery_doc_id(self, property_id: str, unit_id: Optional[str], original_month: str) -> str:
        return f"{property_id}__{unit_id or 'property'}__{original_month}"

    async def record_rent_recovery(
        self, *, landlord_id: str, property_id: str, original_month: str,
        amount: float, received_year: int, unit_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Book a written-off month's rent as income in the year it
        actually arrived, without reopening the original (frozen) year.
        Requires the month to already be on file as written_off — a
        recovery corrects a specific write-off, it is never a free-
        floating credit. Idempotent — recording the same scope again
        overwrites the amount/year."""
        if not _PAYMENT_MONTH_RE.match(original_month or ""):
            raise ValueError("original_month must be formatted YYYY-MM")
        self._require_owned_property(property_id, landlord_id)
        exception_id = self._payment_exception_doc_id(property_id, unit_id, original_month)
        exception_snapshot = self._db.collection('documind_payment_exceptions').document(exception_id).get()
        exception_data = exception_snapshot.to_dict() if exception_snapshot.exists else None
        if not exception_data or exception_data.get("state") != "written_off":
            raise ValueError(
                f"{original_month} is not on file as written_off for this scope; "
                "a recovery can only be recorded against a written-off month."
            )
        doc_id = self._rent_recovery_doc_id(property_id, unit_id, original_month)
        ref = self._db.collection('documind_rent_recoveries').document(doc_id)
        ref.set({
            'landlord_id': landlord_id, 'property_id': property_id, 'unit_id': unit_id,
            'original_month': original_month, 'amount': float(amount),
            'received_year': received_year, 'recorded_at': firestore.SERVER_TIMESTAMP,
        })
        return {
            "property_id": property_id, "unit_id": unit_id, "original_month": original_month,
            "amount": float(amount), "received_year": received_year,
        }

    async def clear_rent_recovery(
        self, *, landlord_id: str, property_id: str, original_month: str, unit_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Remove a recorded recovery. Idempotent — clearing an unrecorded
        scope is a no-op, not an error. Does not affect the underlying
        written_off exception."""
        doc_id = self._rent_recovery_doc_id(property_id, unit_id, original_month)
        ref = self._db.collection('documind_rent_recoveries').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "unit_id": unit_id, "original_month": original_month}

    # -- manual loan entries ----------------------------------------------

    def _manual_loan_entry_doc_id(self, property_id: str, unit_id: Optional[str], year: int, month: Optional[int]) -> str:
        unit_seg = f"{unit_id}__" if unit_id else ""
        if month is not None:
            return f"{property_id}__{unit_seg}{year}__{int(month):02d}"
        return f"{property_id}__{unit_seg}{year}"

    async def record_manual_loan_entry(
        self, *, landlord_id: str, property_id: str, year: int, cadence: str,
        interest_paid: float, principal_paid: float, unit_id: Optional[str] = None,
        month: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Book manually-entered loan interest/principal for a period, for
        landlords whose bank statement cadence makes uploading inconvenient.
        Ownership-validated against the property. Monthly cadence requires a
        1-12 month; annual ignores month. Amounts must be >= 0. Idempotent —
        re-entering the same period overwrites."""
        if cadence not in ("monthly", "annual"):
            raise ValueError("cadence must be 'monthly' or 'annual'")
        if cadence == "monthly":
            if month is None or not (1 <= int(month) <= 12):
                raise ValueError("monthly cadence requires a month in 1-12")
        else:
            month = None
        if interest_paid < 0 or principal_paid < 0:
            raise ValueError("interest_paid and principal_paid must be >= 0")
        self._require_owned_property(property_id, landlord_id)
        doc_id = self._manual_loan_entry_doc_id(property_id, unit_id, year, month)
        ref = self._db.collection('documind_manual_loan_entries').document(doc_id)
        ref.set({
            'landlord_id': landlord_id, 'property_id': property_id, 'unit_id': unit_id,
            'year': year, 'month': month, 'interest_paid': float(interest_paid),
            'principal_paid': float(principal_paid), 'cadence': cadence,
            'updated_at': firestore.SERVER_TIMESTAMP,
        })
        return {
            "property_id": property_id, "unit_id": unit_id, "year": year, "month": month,
            "interest_paid": float(interest_paid), "principal_paid": float(principal_paid),
            "cadence": cadence,
        }

    async def delete_manual_loan_entry(
        self, *, landlord_id: str, property_id: str, year: int, unit_id: Optional[str] = None,
        month: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Remove a manual loan entry. Idempotent — deleting an absent entry is
        a no-op, not an error."""
        doc_id = self._manual_loan_entry_doc_id(property_id, unit_id, year, month)
        ref = self._db.collection('documind_manual_loan_entries').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "year": year, "month": month}

    def list_manual_loan_entries(self, landlord_id: str, property_id: str, year: int) -> List[Dict[str, Any]]:
        """All manual loan entries for one property and year, for the finance-tab
        list/edit UI. Ownership-scoped by landlord_id."""
        query = self._db.collection('documind_manual_loan_entries').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        entries: List[Dict[str, Any]] = []
        for snap in query.stream():
            data = snap.to_dict() or {}
            if data.get("property_id") != property_id or data.get("year") != year:
                continue
            entries.append({
                "property_id": data.get("property_id"), "unit_id": data.get("unit_id"),
                "year": data.get("year"), "month": data.get("month"),
                "interest_paid": data.get("interest_paid"), "principal_paid": data.get("principal_paid"),
                "cadence": data.get("cadence"),
            })
        return entries

    # -- unit loan exemptions ----------------------------------------------

    def _unit_loan_exemption_doc_id(self, property_id: str, unit_id: str) -> str:
        return f"{property_id}__{unit_id}"

    async def set_unit_loan_exemption(self, *, landlord_id: str, property_id: str, unit_id: str) -> Dict[str, Any]:
        """Record that a unit has no loan, so it stops being expected in the
        loan-figure completeness check. Ownership-validated; idempotent."""
        self._require_owned_property(property_id, landlord_id)
        doc_id = self._unit_loan_exemption_doc_id(property_id, unit_id)
        ref = self._db.collection('documind_unit_loan_exemptions').document(doc_id)
        ref.set({
            'landlord_id': landlord_id, 'property_id': property_id, 'unit_id': unit_id,
            'marked_at': firestore.SERVER_TIMESTAMP,
        })
        return {"property_id": property_id, "unit_id": unit_id}

    async def clear_unit_loan_exemption(self, *, landlord_id: str, property_id: str, unit_id: str) -> Dict[str, Any]:
        """Remove a unit's no-loan mark. Idempotent."""
        doc_id = self._unit_loan_exemption_doc_id(property_id, unit_id)
        ref = self._db.collection('documind_unit_loan_exemptions').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "unit_id": unit_id}

    # -- bulk fetch for finance summary -------------------------------------

    def fetch_all(self, landlord_id: str) -> Dict[str, List[Dict[str, Any]]]:
        """All 5 override collections for a landlord, in the shape
        compute_finance_summary expects."""
        payment_exceptions = []
        for snap in self._db.collection('documind_payment_exceptions').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        ).stream():
            data = snap.to_dict() or {}
            payment_exceptions.append({
                "property_id": data.get("property_id"), "unit_id": data.get("unit_id"),
                "month": data.get("month"), "reason": data.get("reason"),
                "state": data.get("state") or "outstanding",
            })

        document_exceptions = []
        for snap in self._db.collection('documind_document_exceptions').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        ).stream():
            data = snap.to_dict() or {}
            document_exceptions.append({
                "property_id": data.get("property_id"), "year": data.get("year"),
                "category": data.get("category"),
            })

        rent_recoveries = []
        for snap in self._db.collection('documind_rent_recoveries').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        ).stream():
            data = snap.to_dict() or {}
            rent_recoveries.append({
                "property_id": data.get("property_id"), "unit_id": data.get("unit_id"),
                "original_month": data.get("original_month"), "amount": data.get("amount"),
                "received_year": data.get("received_year"),
            })

        manual_loan_entries = []
        for snap in self._db.collection('documind_manual_loan_entries').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        ).stream():
            data = snap.to_dict() or {}
            manual_loan_entries.append({
                "property_id": data.get("property_id"), "unit_id": data.get("unit_id"),
                "year": data.get("year"), "month": data.get("month"),
                "interest_paid": data.get("interest_paid"), "principal_paid": data.get("principal_paid"),
                "cadence": data.get("cadence"),
            })

        unit_loan_exemptions = []
        for snap in self._db.collection('documind_unit_loan_exemptions').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        ).stream():
            data = snap.to_dict() or {}
            unit_loan_exemptions.append({
                "property_id": data.get("property_id"), "unit_id": data.get("unit_id"),
            })

        return {
            "payment_exceptions": payment_exceptions,
            "document_exceptions": document_exceptions,
            "rent_recoveries": rent_recoveries,
            "manual_loan_entries": manual_loan_entries,
            "unit_loan_exemptions": unit_loan_exemptions,
        }
