from typing import Dict, List

from google.cloud.firestore_v1.base_query import FieldFilter


def get_property_name(db, property_id: str) -> str:
    """Fetch property name from Firestore for user-facing responses."""
    property_name = "Unknown Property"
    try:
        property_doc = db.collection('properties').document(property_id).get()
        if property_doc.exists:
            property_data = property_doc.to_dict()
            property_name = property_data.get('name') if property_data else 'Unknown Property'
    except Exception as e:
        print(f"⚠️ Could not fetch property name: {e}")
    return property_name


def list_property_units(db, property_id: str) -> List[Dict]:
    """Unit ids + labels + optional ownership share for a property. Empty on
    lookup failure so a units outage degrades to unscoped search instead of
    blocking.

    `ownership_share` is None when the unit stores none, which means "inherit
    the property's share". It is deliberately NOT defaulted to 1.0: a unit
    that has never been touched inside a 50%-owned property must follow the
    property, not silently claim full ownership.
    """
    try:
        snapshots = (
            db.collection('properties')
            .document(property_id)
            .collection('units')
            .stream()
        )
        rows = []
        for snap in snapshots:
            data = snap.to_dict() or {}
            raw = data.get('ownership_share')
            try:
                share = None if raw is None else float(raw)
            except (TypeError, ValueError):
                share = None
            rows.append({
                "unit_id": snap.id,
                "label": data.get('label') or snap.id,
                "ownership_share": share,
            })
        return rows
    except Exception as e:
        print(f"⚠️ Unit lookup failed for property {property_id}: {e}")
        return []


_SHARE_BASES = ("full", "mine")


def list_landlord_properties(db, landlord_id: str) -> List[Dict]:
    """Property ids/names/ownership shares/document-basis answers for a
    landlord. The properties collection is Flutter-owned (field 'landlordId');
    ownership_share is optional and defaults to 1.0. share_basis_default is
    None and share_basis_exceptions is {} unless the landlord answered — both
    resolve to 'full', which is what the engine has always assumed. Empty on
    lookup failure."""
    try:
        snapshots = (
            db.collection('properties')
            .where(filter=FieldFilter('landlordId', '==', landlord_id))
            .stream()
        )
        results = []
        for snap in snapshots:
            data = snap.to_dict() or {}
            try:
                share = float(data.get('ownership_share') or 1.0)
            except (TypeError, ValueError):
                share = 1.0
            basis_default = data.get('share_basis_default')
            if basis_default not in _SHARE_BASES:
                basis_default = None
            raw_exceptions = data.get('share_basis_exceptions')
            # Sanitised per entry, not all-or-nothing: one junk value must not
            # discard a category the landlord did answer correctly.
            basis_exceptions = {
                str(category): basis
                for category, basis in (raw_exceptions or {}).items()
                if basis in _SHARE_BASES
            } if isinstance(raw_exceptions, dict) else {}
            results.append({
                "property_id": snap.id,
                "name": data.get('name') or snap.id,
                "ownership_share": share,
                "property_type": data.get('property_type'),
                "has_mortgage": data.get('has_mortgage'),
                "utilities_paid_by": data.get('utilities_paid_by'),
                "track_from_year": data.get('track_from_year'),
                "loan_input_cadence": data.get('loan_input_cadence'),
                "mortgage_settled_on": data.get('mortgage_settled_on'),
                "share_basis_default": basis_default,
                "share_basis_exceptions": basis_exceptions,
            })
        return results
    except Exception as e:
        print(f"⚠️ Property lookup failed for landlord {landlord_id}: {e}")
        return []
