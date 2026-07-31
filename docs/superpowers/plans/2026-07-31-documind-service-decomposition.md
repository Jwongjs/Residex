# DocuMindService Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the 1992-line `DocuMindService` god-object (`backend/rag/documind_service.py`) into focused, single-responsibility modules, with zero behavior change and zero test edits required.

**Architecture:** `DocuMindService` becomes a thin composition root. Each of its six unrelated responsibilities (category taxonomy, unit-mention resolution, property/unit lookups, finance-override CRUD, document lifecycle, ingestion, ask/RAG orchestration) moves into its own module. `DocuMindService` keeps every method name currently referenced by `rex_routes.py` or by tests (including the private ones tests call directly: `_list_available_categories`, `_list_landlord_properties`) as a thin delegate to the new module. Two genuinely dead code paths found during analysis (an unused method, an unreachable lazy-load branch) are deleted rather than moved.

**Tech Stack:** Python 3.11, FastAPI, LangChain, LangGraph, Firestore, pytest (unittest-style + async).

## Global Constraints

- **No behavior change.** This is a pure structural refactor. Every existing test in `backend/tests/` must pass, unmodified, after every task.
- **Preserve the public/tested surface of `DocuMindService` exactly**, including private methods tests call directly: `_list_available_categories`, `_list_landlord_properties` (see `backend/tests/test_documind_service_flows.py:1440,2470`).
- **Preserve module-level re-exports from `rag.documind_service`:** `ALLOWED_CATEGORIES`, `CATEGORY_ORDER`, `EXPENSE_GROUP`, `LEGACY_CATEGORY_ALIASES`, `UPLOAD_CONTENT_TYPES`, `normalize_category`, `expand_categories_for_query`, `resolve_upload_kind`, `facts_status_for`, `resolve_unit_mention`, `DocuMindService`, `documind_service` — these are imported directly from `rag.documind_service` by `backend/tests/test_category_taxonomy.py`, `test_upload_kind.py`, and `test_documind_service_flows.py`.
- **One commit per task.** Never amend. Run the full backend suite before each commit: `cd backend && python -m pytest tests/ -q` (skip `test_ollama_*`, `test_groq_chat.py`, `test_ocr_local.py`, `test_reembed_chunks_local.py`, `test_expense_scanner_realdocs.py` only if they require live local services unavailable in your shell — otherwise include them).
- **Delete confirmed dead code found during analysis** (do not relocate it): `DocuMindService._normalize_category_selection` (defined at `documind_service.py:380-411`, zero callers anywhere in `backend/`, including tests — grep confirms), the module-level `embeddings`/`llm` eager singletons' now-provably-dead paths per Task 8.
- Follow existing repo conventions: no comments explaining *what* code does, only non-obvious *why*; keyword-only args (`*`) preserved exactly as in the source method signatures.

---

## File Structure

| File | Responsibility |
|---|---|
| `backend/rag/categories.py` | Category taxonomy constants + pure helpers (create) |
| `backend/rag/unit_resolution.py` | Deterministic unit-mention matching for chat questions (create) |
| `backend/rag/property_directory.py` | Read-only property/unit Firestore lookups shared by ask + finance (create) |
| `backend/rag/finance_overrides_repository.py` | CRUD for the 5 finance-override Firestore collections (create) |
| `backend/rag/document_lifecycle_service.py` | Document list/delete/rename/unassign/view-url/expense-line edits (create) |
| `backend/rag/ingestion_service.py` | The upload → OCR → chunk → embed → fact-extract pipeline (create) |
| `backend/rag/ask_orchestrator.py` | `ask_documind` — the LangGraph-driven chat/finance/retrieve flow (create) |
| `backend/rag/documind_service.py` | Slimmed to composition root + thin delegates (modify) |

---

### Task 1: Extract category taxonomy

**Files:**
- Create: `backend/rag/categories.py`
- Modify: `backend/rag/documind_service.py:48-127` (delete the moved definitions, replace with import)
- Test: `backend/tests/test_category_taxonomy.py`, `backend/tests/test_upload_kind.py`

**Interfaces:**
- Produces: `ALLOWED_CATEGORIES: set[str]`, `CATEGORY_ORDER: list[str]`, `LEGACY_CATEGORY_ALIASES: dict[str,str]`, `EXPENSE_GROUP: list[str]`, `UPLOAD_CONTENT_TYPES: dict[str,str]`, `resolve_upload_kind(filename) -> (ext, content_type)`, `facts_status_for(extracted_facts) -> str`, `normalize_category(category) -> str|None`, `expand_categories_for_query(categories) -> list[str]`.

- [ ] **Step 1: Create `backend/rag/categories.py`** with this exact content (moved verbatim from `documind_service.py:48-127`, no logic changes):

```python
import os
from typing import List, Optional, Tuple

UPLOAD_CONTENT_TYPES = {
    ".pdf": "application/pdf",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
}


def resolve_upload_kind(filename: Optional[str]) -> Tuple[str, str]:
    """(extension, content_type) for an upload; ValueError for anything the
    ingestion pipeline can't read."""
    ext = os.path.splitext(filename or "")[1].lower()
    content_type = UPLOAD_CONTENT_TYPES.get(ext)
    if content_type is None:
        raise ValueError("Unsupported file type. Upload a PDF or a JPG/PNG image.")
    return ext, content_type


# 7-category taxonomy (2026-07 financial-intelligence spec) plus the
# 'expenses' ingestion bucket (2026-07-18): combined statements upload as
# 'expenses' and carry line items instead of one amount. Documents stored
# before either rename keep their category strings; LEGACY_CATEGORY_ALIASES
# maps them at every read and expand_categories_for_query() widens
# stored-name queries. No data migration.
ALLOWED_CATEGORIES = {
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
}
CATEGORY_ORDER = [
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
]
LEGACY_CATEGORY_ALIASES = {
    "utility": "upkeep",
    "receipt": "rental_invoice",
    "warranty": "upkeep",
}
# Granular stored names the Expenses bucket groups at display/query time.
EXPENSE_GROUP = ["insurance", "loan", "tax", "upkeep", "maintenance"]


def facts_status_for(extracted_facts: Optional[dict]) -> str:
    """'ok' when ingest extraction captured something, 'needs_review' when it
    came back empty. Every supported category attempts extraction, so an empty
    result means a silent miss the user should be able to see and re-check —
    not a document that legitimately carries no facts."""
    return "ok" if extracted_facts else "needs_review"


def normalize_category(category: Optional[str]) -> Optional[str]:
    """Stored/legacy category -> current taxonomy name (read-time alias)."""
    if not category:
        return category
    lowered = category.strip().lower()
    return LEGACY_CATEGORY_ALIASES.get(lowered, lowered)


def expand_categories_for_query(categories: List[str]) -> List[str]:
    """Current-taxonomy filter -> every stored name it must match: legacy
    spellings (chunks written pre-rename still carry 'utility' etc.) and the
    expenses group in both directions — an 'expenses' filter matches granular
    docs, and a granular filter matches combined 'expenses' statements."""
    expanded: List[str] = []

    def _add(name: str) -> None:
        if name not in expanded:
            expanded.append(name)

    for category in categories:
        _add(category)
        for legacy, current in LEGACY_CATEGORY_ALIASES.items():
            if current == category:
                _add(legacy)
        if category == "expenses":
            for granular in EXPENSE_GROUP:
                _add(granular)
                for legacy, current in LEGACY_CATEGORY_ALIASES.items():
                    if current == granular:
                        _add(legacy)
        elif category in EXPENSE_GROUP:
            _add("expenses")
    return expanded
```

- [ ] **Step 2: In `backend/rag/documind_service.py`, delete lines 48-127** (the block from `UPLOAD_CONTENT_TYPES = {` through the end of `expand_categories_for_query`) and replace with:

```python
from rag.categories import (
    ALLOWED_CATEGORIES,
    CATEGORY_ORDER,
    EXPENSE_GROUP,
    LEGACY_CATEGORY_ALIASES,
    UPLOAD_CONTENT_TYPES,
    expand_categories_for_query,
    facts_status_for,
    normalize_category,
    resolve_upload_kind,
)
```

Place this import alongside the other `from rag...` imports near the top of the file (around line 31-42), not at the old line-48 location — imports belong grouped at the top.

- [ ] **Step 3: Run the affected tests**

Run: `cd backend && python -m pytest tests/test_category_taxonomy.py tests/test_upload_kind.py -v`
Expected: all PASS (these tests import `ALLOWED_CATEGORIES`, `CATEGORY_ORDER`, `EXPENSE_GROUP`, `expand_categories_for_query`, `normalize_category`, `resolve_upload_kind` from `rag.documind_service` — the re-export makes this transparent).

- [ ] **Step 4: Run the full suite**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count as the pre-refactor baseline (289 passed across the core files; full suite may include more).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/categories.py backend/rag/documind_service.py
git commit -m "refactor: extract category taxonomy into rag/categories.py"
```

---

### Task 2: Extract unit-mention resolution

**Files:**
- Create: `backend/rag/unit_resolution.py`
- Modify: `backend/rag/documind_service.py:129-193` (delete, replace with import)
- Test: `backend/tests/test_documind_service_flows.py` (imports `resolve_unit_mention` from `rag.documind_service`)

**Interfaces:**
- Produces: `resolve_unit_mention(question: str, units: List[Dict]) -> Dict` (same return shape as before: `{"kind": "none"|"scoped"|"multi"|"aggregate"|"ambiguous"|"unknown", ...}`).

- [ ] **Step 1: Create `backend/rag/unit_resolution.py`** with this exact content (moved verbatim from `documind_service.py:129-193`):

```python
import re
from typing import Dict, List

# Question-side unit reference resolution. Matching is deterministic and
# label-driven: "unit a" resolves to "Unit A-12-03" only when exactly one
# unit label starts with that reference at a segment boundary.
_UNIT_REF_PATTERN = re.compile(r"\bunit\s+([a-z0-9]+(?:-[a-z0-9]+)*)")
_AGGREGATE_UNIT_PHRASES = (
    "all units", "all the units", "all my units", "across units",
    "every unit", "each unit", "per unit", "between units",
)


def _label_matches_token(label: str, token: str) -> bool:
    label_norm = " ".join(label.lower().split())
    prefix = f"unit {token}"
    if label_norm == token or label_norm == prefix:
        return True
    if label_norm.startswith(prefix):
        # Boundary check so "unit a" never matches "Unit AB-2".
        return label_norm[len(prefix):][:1] in ("-", " ", ".")
    return False


def resolve_unit_mention(question: str, units: List[Dict]) -> Dict:
    """Decide which unit(s) a question refers to, before retrieval runs.

    units: [{"unit_id": ..., "label": ...}]. Returns a dict whose "kind" is:
      none      - no unit signal; search everything, attribute per unit
      scoped    - exactly one unit referenced -> {"unit": {...}}
      multi     - several units named deliberately; search everything
      aggregate - "all units"-style phrasing; search everything
      ambiguous - one reference matches several units -> {"candidates": [...]}
      unknown   - a unit was named that does not exist -> {"mention": str}
    """
    q = " ".join((question or "").lower().split())
    if not q or not units:
        return {"kind": "none"}

    named = [
        u for u in units
        if u.get("label") and " ".join(u["label"].lower().split()) in q
    ]
    if len(named) == 1:
        return {"kind": "scoped", "unit": named[0]}
    if len(named) >= 2:
        return {"kind": "multi"}

    if any(phrase in q for phrase in _AGGREGATE_UNIT_PHRASES):
        return {"kind": "aggregate"}

    resolved: Dict[str, Dict] = {}
    for token in _UNIT_REF_PATTERN.findall(q):
        candidates = [
            u for u in units
            if u.get("label") and _label_matches_token(u["label"], token)
        ]
        if not candidates:
            return {"kind": "unknown", "mention": f"Unit {token.upper()}"}
        if len(candidates) > 1:
            return {"kind": "ambiguous", "candidates": candidates}
        resolved[candidates[0]["unit_id"]] = candidates[0]

    if len(resolved) == 1:
        return {"kind": "scoped", "unit": next(iter(resolved.values()))}
    if len(resolved) >= 2:
        return {"kind": "multi"}
    return {"kind": "none"}
```

- [ ] **Step 2: In `backend/rag/documind_service.py`, delete lines 129-193** and add to the same import block from Task 1 Step 2:

```python
from rag.unit_resolution import resolve_unit_mention
```

- [ ] **Step 3: Run tests**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py -v`
Expected: all PASS.

- [ ] **Step 4: Run full suite**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count as Task 1.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/unit_resolution.py backend/rag/documind_service.py
git commit -m "refactor: extract unit-mention resolution into rag/unit_resolution.py"
```

---

### Task 3: Extract property/unit directory lookups

**Files:**
- Create: `backend/rag/property_directory.py`
- Modify: `backend/rag/documind_service.py` (replace bodies of `_get_property_name`, `_list_property_units`, `_list_landlord_properties` with delegates)
- Test: `backend/tests/test_documind_service_flows.py:2463-2470` (calls `service._list_landlord_properties("l1")` directly), plus ask/finance tests that exercise these indirectly.

**Interfaces:**
- Produces: `get_property_name(db, property_id) -> str`, `list_property_units(db, property_id) -> List[Dict]`, `list_landlord_properties(db, landlord_id) -> List[Dict]`.
- Consumes: nothing from earlier tasks.

- [ ] **Step 1: Create `backend/rag/property_directory.py`** — same bodies as `documind_service.py:413-423` (`_get_property_name`), `:460-479` (`_list_property_units`), `:481-512` (`_list_landlord_properties`), turned into module-level functions taking `db` explicitly instead of `self.db`:

```python
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
    """Unit ids + labels for a property. Empty on lookup failure so a
    units outage degrades to unscoped search instead of blocking."""
    try:
        snapshots = (
            db.collection('properties')
            .document(property_id)
            .collection('units')
            .stream()
        )
        return [
            {
                "unit_id": snap.id,
                "label": (snap.to_dict() or {}).get('label') or snap.id,
            }
            for snap in snapshots
        ]
    except Exception as e:
        print(f"⚠️ Unit lookup failed for property {property_id}: {e}")
        return []


def list_landlord_properties(db, landlord_id: str) -> List[Dict]:
    """Property ids/names/ownership shares for a landlord. The properties
    collection is Flutter-owned (field 'landlordId'); ownership_share is
    optional and defaults to 1.0. Empty on lookup failure."""
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
            results.append({
                "property_id": snap.id,
                "name": data.get('name') or snap.id,
                "ownership_share": share,
                "property_type": data.get('property_type'),
                "has_mortgage": data.get('has_mortgage'),
                "utilities_paid_by": data.get('utilities_paid_by'),
                "track_from_year": data.get('track_from_year'),
                "loan_input_cadence": data.get('loan_input_cadence'),
                "loan_input_method": data.get('loan_input_method'),
            })
        return results
    except Exception as e:
        print(f"⚠️ Property lookup failed for landlord {landlord_id}: {e}")
        return []
```

- [ ] **Step 2: In `backend/rag/documind_service.py`, replace the three method bodies** (keep the method names and signatures — tests call `_list_available_categories`/`_list_landlord_properties` directly on the instance):

Replace `documind_service.py:413-423`:
```python
    def _get_property_name(self, property_id: str) -> str:
        return property_directory.get_property_name(self.db, property_id)
```

Replace `documind_service.py:460-479`:
```python
    def _list_property_units(self, property_id: str) -> List[Dict]:
        return property_directory.list_property_units(self.db, property_id)
```

Replace `documind_service.py:481-512`:
```python
    def _list_landlord_properties(self, landlord_id: str) -> List[Dict]:
        return property_directory.list_landlord_properties(self.db, landlord_id)
```

Add to the top-level imports:
```python
from rag import property_directory
```

- [ ] **Step 3: Run tests**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py tests/test_rex_routes_documind_ask_api.py tests/test_rex_routes_finance_api.py -v`
Expected: all PASS.

- [ ] **Step 4: Run full suite**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/property_directory.py backend/rag/documind_service.py
git commit -m "refactor: extract property/unit directory lookups into rag/property_directory.py"
```

---

### Task 4: Extract finance-overrides repository

**Files:**
- Create: `backend/rag/finance_overrides_repository.py`
- Modify: `backend/rag/documind_service.py` (replace the 5 CRUD groups + `get_finance_summary`'s override-fetching with delegates)
- Test: `backend/tests/test_rex_routes_finance_api.py` (18 references — the widest coverage of this surface)

**Interfaces:**
- Produces: `FinanceOverridesRepository(db)` with methods `set_payment_exception`, `clear_payment_exception`, `set_document_unavailable`, `clear_document_unavailable`, `record_rent_recovery`, `clear_rent_recovery`, `record_manual_loan_entry`, `delete_manual_loan_entry`, `set_unit_loan_exemption`, `clear_unit_loan_exemption`, `list_manual_loan_entries(landlord_id, property_id, year)` (sync), `fetch_all(landlord_id) -> dict` (the 5 all-landlord lists `get_finance_summary` needs).
- Consumes: nothing from earlier tasks (only `google.cloud.firestore`).

This task also deduplicates the identical ownership check (`property exists and belongs to landlord_id, else ValueError`) that was copy-pasted 5 times in the source — same error message in all 5 (verified), so this is a pure simplification with no observable behavior change.

- [ ] **Step 1: Create `backend/rag/finance_overrides_repository.py`.** Move the bodies of `documind_service.py:768-1027` (everything from `_payment_exception_doc_id` through `list_manual_loan_entries`) into this class, replacing `self.db` with `self._db`, and replacing each method's inline ownership-check block:

```python
        property_ref = self.db.collection('properties').document(property_id)
        property_snapshot = property_ref.get()
        if not property_snapshot.exists or (property_snapshot.to_dict() or {}).get('landlordId') != landlord_id:
            raise ValueError(f"Property {property_id} not found for landlord {landlord_id}")
```
with a single call to the new private helper `self._require_owned_property(property_id, landlord_id)`. Also add `fetch_all`, moved verbatim from the five query loops in `documind_service.py:1704-1770` (payment_exceptions, document_exceptions, rent_recoveries, manual_loan_entries, unit_loan_exemptions), returning them as a dict:

```python
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
        doc_id = self._manual_loan_entry_doc_id(property_id, unit_id, year, month)
        ref = self._db.collection('documind_manual_loan_entries').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "year": year, "month": month}

    def list_manual_loan_entries(self, landlord_id: str, property_id: str, year: int) -> List[Dict[str, Any]]:
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
        self._require_owned_property(property_id, landlord_id)
        doc_id = self._unit_loan_exemption_doc_id(property_id, unit_id)
        ref = self._db.collection('documind_unit_loan_exemptions').document(doc_id)
        ref.set({
            'landlord_id': landlord_id, 'property_id': property_id, 'unit_id': unit_id,
            'marked_at': firestore.SERVER_TIMESTAMP,
        })
        return {"property_id": property_id, "unit_id": unit_id}

    async def clear_unit_loan_exemption(self, *, landlord_id: str, property_id: str, unit_id: str) -> Dict[str, Any]:
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
```

(`_PAYMENT_MONTH_RE` mirrors the precompiled pattern already at `documind_service.py:46` in the source — same regex, same validation behavior.)

- [ ] **Step 2: In `backend/rag/documind_service.py`**, delete `documind_service.py:768-1027` (the whole block from `_payment_exception_doc_id` through `list_manual_loan_entries`) and replace with thin delegates preserving every original signature:

```python
    async def set_payment_exception(self, *, landlord_id, property_id, month, unit_id=None, reason=None, state="outstanding"):
        return await self._finance_overrides.set_payment_exception(
            landlord_id=landlord_id, property_id=property_id, month=month,
            unit_id=unit_id, reason=reason, state=state,
        )

    async def clear_payment_exception(self, *, landlord_id, property_id, month, unit_id=None):
        return await self._finance_overrides.clear_payment_exception(
            landlord_id=landlord_id, property_id=property_id, month=month, unit_id=unit_id,
        )

    async def set_document_unavailable(self, *, landlord_id, property_id, year, category):
        return await self._finance_overrides.set_document_unavailable(
            landlord_id=landlord_id, property_id=property_id, year=year, category=category,
        )

    async def clear_document_unavailable(self, *, landlord_id, property_id, year, category):
        return await self._finance_overrides.clear_document_unavailable(
            landlord_id=landlord_id, property_id=property_id, year=year, category=category,
        )

    async def record_rent_recovery(self, *, landlord_id, property_id, original_month, amount, received_year, unit_id=None):
        return await self._finance_overrides.record_rent_recovery(
            landlord_id=landlord_id, property_id=property_id, original_month=original_month,
            amount=amount, received_year=received_year, unit_id=unit_id,
        )

    async def clear_rent_recovery(self, *, landlord_id, property_id, original_month, unit_id=None):
        return await self._finance_overrides.clear_rent_recovery(
            landlord_id=landlord_id, property_id=property_id, original_month=original_month, unit_id=unit_id,
        )

    async def record_manual_loan_entry(self, *, landlord_id, property_id, year, cadence, interest_paid, principal_paid, unit_id=None, month=None):
        return await self._finance_overrides.record_manual_loan_entry(
            landlord_id=landlord_id, property_id=property_id, year=year, cadence=cadence,
            interest_paid=interest_paid, principal_paid=principal_paid, unit_id=unit_id, month=month,
        )

    async def delete_manual_loan_entry(self, *, landlord_id, property_id, year, unit_id=None, month=None):
        return await self._finance_overrides.delete_manual_loan_entry(
            landlord_id=landlord_id, property_id=property_id, year=year, unit_id=unit_id, month=month,
        )

    async def set_unit_loan_exemption(self, *, landlord_id, property_id, unit_id):
        return await self._finance_overrides.set_unit_loan_exemption(
            landlord_id=landlord_id, property_id=property_id, unit_id=unit_id,
        )

    async def clear_unit_loan_exemption(self, *, landlord_id, property_id, unit_id):
        return await self._finance_overrides.clear_unit_loan_exemption(
            landlord_id=landlord_id, property_id=property_id, unit_id=unit_id,
        )

    def list_manual_loan_entries(self, landlord_id, property_id, year):
        return self._finance_overrides.list_manual_loan_entries(landlord_id, property_id, year)
```

Add to `__init__` (after `self._db = db`):
```python
        self._finance_overrides = FinanceOverridesRepository(self._db)
```

Add to imports:
```python
from rag.finance_overrides_repository import FinanceOverridesRepository
```

Delete the now-dead `_PAYMENT_MONTH_RE = re.compile(r"^\d{4}-\d{2}$")` module-level constant at `documind_service.py:46` — its only two callers were `set_payment_exception` and `record_rent_recovery`, both just deleted from this file (the pattern now lives in `finance_overrides_repository.py`). Confirm with `grep -n "_PAYMENT_MONTH_RE" backend/rag/documind_service.py` that no reference remains before deleting.

- [ ] **Step 3: In `get_finance_summary` (`documind_service.py:1678-1783`), replace the 5 query blocks** (`payment_exceptions = []` ... through `unit_loan_exemptions.append(...)`, i.e. lines ~1704-1769) with:

```python
        overrides = self._finance_overrides.fetch_all(landlord_id)
```

and update the `compute_finance_summary(...)` call to use `overrides["payment_exceptions"]`, `overrides["document_exceptions"]`, `overrides["rent_recoveries"]`, `overrides["manual_loan_entries"]`, `overrides["unit_loan_exemptions"]` in place of the old local variable names (same keyword arguments to `compute_finance_summary`, just sourced from the dict instead of local lists).

- [ ] **Step 4: Run tests**

Run: `cd backend && python -m pytest tests/test_rex_routes_finance_api.py tests/test_finance_engine.py tests/test_documind_service_flows.py -v`
Expected: all PASS.

- [ ] **Step 5: Run full suite**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/finance_overrides_repository.py backend/rag/documind_service.py
git commit -m "refactor: extract finance-overrides CRUD into rag/finance_overrides_repository.py"
```

---

### Task 5: Extract document lifecycle service

**Files:**
- Create: `backend/rag/document_lifecycle_service.py`
- Modify: `backend/rag/documind_service.py` (replace `list_documents`, `delete_document`, `delete_documents_for_property`, `unassign_unit_documents`, `get_document_view_url`, `update_expense_lines`, `rename_document` with delegates)
- Test: `backend/tests/test_rex_routes_documind_docs_api.py`, `backend/tests/test_update_expense_lines.py`

**Interfaces:**
- Produces: `DocumentLifecycleService(db, storage_bucket_getter)` with methods matching the originals: `list_documents`, `delete_document`, `delete_documents_for_property`, `unassign_unit_documents`, `get_document_view_url`, `update_expense_lines`, `rename_document`.
- Consumes: `rag.categories.normalize_category`, `rag.categories.facts_status_for` (Task 1), `rag.finance_engine.document_tags`, `rag.fact_extractor.validate_expense_lines`.

- [ ] **Step 1: Create `backend/rag/document_lifecycle_service.py`.** Move the bodies of `documind_service.py:710-734` (`update_expense_lines`), `:736-766` (`rename_document`), `:1610-1676` (`list_documents`), `:1785-1865` (`delete_document`), `:1867-1904` (`delete_documents_for_property`), `:1906-1957` (`unassign_unit_documents`), `:1959-1990` (`get_document_view_url`) verbatim, with these substitutions throughout: `self.db` → `self._db`, `self.storage_bucket` → `self._storage_bucket_getter()`, and (inside `delete_documents_for_property`) `self.delete_document(...)` → `self.delete_document(...)` unchanged (now calling its sibling method on the same class):

```python
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from models.documind_models import DocListResponse, DocumentInfo, DocumentTag
from rag.categories import facts_status_for, normalize_category
from rag.fact_extractor import validate_expense_lines
from rag.finance_engine import document_tags


class DocumentLifecycleService:
    """Document metadata lifecycle: listing, deletion, renaming, unit
    reassignment, expense-line edits, and signed view URLs. Distinct from
    ingestion (which creates a document) and ask (which reads chunks)."""

    def __init__(self, db, storage_bucket_getter):
        self._db = db
        self._storage_bucket_getter = storage_bucket_getter

    async def update_expense_lines(self, doc_id: str, landlord_id: str, lines: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Replace a document's expense_lines after user review. Validation
        reuses the extractor whitelist, so the API can never store a subtype
        the finance engine doesn't understand."""
        cleaned = validate_expense_lines(lines)
        if not cleaned:
            raise ValueError("No valid expense lines. Each line needs a known subtype and an amount.")
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise ValueError("Document not found.")
        data = snapshot.to_dict() or {}
        if data.get("landlord_id") != landlord_id:
            raise ValueError("Document not found.")
        facts = dict(data.get("extracted_facts") or {})
        facts["expense_lines"] = cleaned
        doc_ref.update({"extracted_facts": facts, "facts_extracted_at": firestore.SERVER_TIMESTAMP})
        return {"doc_id": doc_id, "extracted_facts": facts}

    async def rename_document(self, doc_id: str, landlord_id: str, filename: str) -> Dict[str, Any]:
        """Rename a document's display filename. Ownership-scoped: a doc that
        isn't the landlord's is reported as not found, never renamed. The
        stored file, chunks' text and embeddings are untouched — only the
        label changes, including on the chunks so citations show the new name."""
        cleaned = (filename or "").strip()
        if not cleaned:
            raise ValueError("Filename cannot be empty.")
        if len(cleaned) > 200:
            raise ValueError("Filename is too long (200 characters max).")
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise ValueError("Document not found.")
        data = snapshot.to_dict() or {}
        if data.get("landlord_id") != landlord_id:
            raise ValueError("Document not found.")
        doc_ref.update({"filename": cleaned})

        chunks_query = self._db.collection('documind_chunks').where(filter=FieldFilter('doc_id', '==', doc_id))
        batch = self._db.batch()
        for chunk_doc in chunks_query.stream():
            batch.update(chunk_doc.reference, {"filename": cleaned})
        batch.commit()

        return {"doc_id": doc_id, "filename": cleaned}

    async def list_documents(self, landlord_id: str, property_id: Optional[str] = None, unit_id: Optional[str] = None) -> DocListResponse:
        """
        List documents from Firestore metadata collection.

        Args:
            landlord_id: Filter by landlord
            property_id: Optional filter by specific property
            unit_id: Optional unit filter — matches documents assigned to
                this unit plus property-wide documents. Applied as a Python
                post-filter because docs uploaded before units existed have
                no unit_id field, which a Firestore where-clause can never
                match.

        Returns:
            DocListResponse with documents array, total_count
        """
        query = self._db.collection('documind_docs').where(filter=FieldFilter('landlord_id', '==', landlord_id))
        if property_id:
            query = query.where(filter=FieldFilter('property_id', '==', property_id))

        docs = query.stream()
        documents = []
        for doc in docs:
            data = doc.to_dict()
            if unit_id and data.get('unit_id') not in (None, unit_id):
                continue

            uploaded_at = data.get('uploaded_at')
            if isinstance(uploaded_at, firestore.SERVER_TIMESTAMP.__class__):
                uploaded_at = datetime.now()
            elif hasattr(uploaded_at, 'to_pydantic'):
                uploaded_at = uploaded_at.to_pydantic()

            category = normalize_category(data.get('category'))
            documents.append(DocumentInfo(
                doc_id=doc.id, landlord_id=data.get('landlord_id'), property_id=data.get('property_id'),
                category=category, filename=data.get('filename'), uploaded_at=uploaded_at,
                chunks_indexed=data.get('chunks_indexed'), file_size=data.get('file_size'),
                unit_id=data.get('unit_id'), unit_label=data.get('unit_label'),
                extracted_facts=data.get('extracted_facts'), facts_confidence=data.get('facts_confidence'),
                facts_status=facts_status_for(data.get('extracted_facts')),
                tags=[DocumentTag(**t) for t in document_tags(category, data.get('extracted_facts'))],
            ))

        return DocListResponse(documents=documents, total_count=len(documents), filtered_by_property=property_id)

    async def delete_document(self, landlord_id: str, property_id: str, doc_id: str) -> dict:
        """
        Delete a document and all its chunks from Firestore.

        Security:
        - Verifies landlord owns the document
        - Verifies document belongs to property
        - Cascades deletion to all chunks

        Args:
            landlord_id: Landlord ID for ownership verification
            property_id: Property ID for scoping
            doc_id: Document ID to delete

        Returns:
            dict with deletion summary

        Raises:
            ValueError: If document not found or ownership mismatch
        """
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        doc_snapshot = doc_ref.get()
        if not doc_snapshot.exists:
            raise ValueError(f"Document {doc_id} not found")
        doc_data = doc_snapshot.to_dict()
        if doc_data.get('landlord_id') != landlord_id:
            raise ValueError(f"Document {doc_id} does not belong to landlord {landlord_id}")
        if doc_data.get('property_id') != property_id:
            raise ValueError(f"Document {doc_id} does not belong to property {property_id}")

        chunks_ref = self._db.collection('documind_chunks')
        chunks_query = chunks_ref.where(filter=FieldFilter('doc_id', '==', doc_id))
        chunks_to_delete = chunks_query.stream()

        deleted_chunks_count = 0
        batch = self._db.batch()
        for chunk_doc in chunks_to_delete:
            batch.delete(chunk_doc.reference)
            deleted_chunks_count += 1
        if deleted_chunks_count > 0:
            batch.commit()

        storage_path = doc_data.get('storage_path')
        if storage_path:
            try:
                self._storage_bucket_getter().blob(storage_path).delete()
            except Exception as e:
                print(f"Warning: could not delete storage object {storage_path}: {e}")

        doc_ref.delete()

        return {
            "message": "Document deleted successfully", "doc_id": doc_id,
            "filename": doc_data.get('filename', 'Unknown'), "chunks_deleted": deleted_chunks_count,
        }

    async def delete_documents_for_property(self, landlord_id: str, property_id: str) -> dict:
        """
        Delete ALL documents (metadata + chunks + stored PDFs) for a property.

        Used by the property-deletion cascade in the app. Idempotent: a
        property with no documents returns a zero-count success.
        """
        docs_query = (
            self._db.collection('documind_docs')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
        )

        documents_deleted = 0
        chunks_deleted = 0
        for doc_snapshot in docs_query.stream():
            result = await self.delete_document(landlord_id=landlord_id, property_id=property_id, doc_id=doc_snapshot.id)
            documents_deleted += 1
            chunks_deleted += result.get('chunks_deleted', 0)

        return {
            "message": "Property documents deleted", "property_id": property_id,
            "documents_deleted": documents_deleted, "chunks_deleted": chunks_deleted,
        }

    async def unassign_unit_documents(self, landlord_id: str, property_id: str, unit_id: str) -> dict:
        """
        Clear the unit assignment on every doc + chunk scoped to a unit,
        converting them to property-wide documents.

        Called by the app before deleting a unit so its documents are
        unassigned rather than orphaned with a stale unit_id. Idempotent: a
        unit with no assigned documents returns zero counts. A single batch
        is fine at this scale (Firestore's 500-op batch limit).
        """
        batch = self._db.batch()
        documents_updated = 0
        chunks_updated = 0

        docs_query = (
            self._db.collection('documind_docs')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in docs_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            documents_updated += 1

        chunks_query = (
            self._db.collection('documind_chunks')
            .where(filter=FieldFilter('landlord_id', '==', landlord_id))
            .where(filter=FieldFilter('property_id', '==', property_id))
            .where(filter=FieldFilter('unit_id', '==', unit_id))
        )
        for snapshot in chunks_query.stream():
            batch.update(snapshot.reference, {'unit_id': None, 'unit_label': None})
            chunks_updated += 1

        if documents_updated or chunks_updated:
            batch.commit()

        return {
            "message": "Unit documents unassigned", "unit_id": unit_id,
            "documents_updated": documents_updated, "chunks_updated": chunks_updated,
        }

    async def get_document_view_url(self, landlord_id: str, property_id: str, doc_id: str) -> str:
        """
        Generate a short-lived signed URL to view a document's original PDF.

        Raises:
            ValueError: If document not found or ownership/scope mismatch.
        """
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        doc_snapshot = doc_ref.get()
        if not doc_snapshot.exists:
            raise ValueError(f"Document {doc_id} not found")
        doc_data = doc_snapshot.to_dict()
        if doc_data.get('landlord_id') != landlord_id:
            raise ValueError(f"Document {doc_id} does not belong to landlord {landlord_id}")
        if doc_data.get('property_id') != property_id:
            raise ValueError(f"Document {doc_id} does not belong to property {property_id}")
        storage_path = doc_data.get('storage_path')
        if not storage_path:
            raise ValueError(f"Document {doc_id} has no stored file")
        blob = self._storage_bucket_getter().blob(storage_path)
        return blob.generate_signed_url(expiration=timedelta(minutes=10), method="GET")
```

- [ ] **Step 2: In `backend/rag/documind_service.py`**, delete the 7 moved method bodies and replace with:

```python
    async def update_expense_lines(self, doc_id, landlord_id, lines):
        return await self._document_lifecycle.update_expense_lines(doc_id, landlord_id, lines)

    async def rename_document(self, doc_id, landlord_id, filename):
        return await self._document_lifecycle.rename_document(doc_id, landlord_id, filename)

    async def list_documents(self, landlord_id, property_id=None, unit_id=None):
        return await self._document_lifecycle.list_documents(landlord_id, property_id, unit_id)

    async def delete_document(self, landlord_id, property_id, doc_id):
        return await self._document_lifecycle.delete_document(landlord_id, property_id, doc_id)

    async def delete_documents_for_property(self, landlord_id, property_id):
        return await self._document_lifecycle.delete_documents_for_property(landlord_id, property_id)

    async def unassign_unit_documents(self, landlord_id, property_id, unit_id):
        return await self._document_lifecycle.unassign_unit_documents(landlord_id, property_id, unit_id)

    async def get_document_view_url(self, landlord_id, property_id, doc_id):
        return await self._document_lifecycle.get_document_view_url(landlord_id, property_id, doc_id)
```

Add to `__init__`:
```python
        self._document_lifecycle = DocumentLifecycleService(self._db, lambda: self.storage_bucket)
```

Add to imports:
```python
from rag.document_lifecycle_service import DocumentLifecycleService
```

- [ ] **Step 3: Run tests**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_docs_api.py tests/test_update_expense_lines.py -v`
Expected: all PASS.

- [ ] **Step 4: Run full suite**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/document_lifecycle_service.py backend/rag/documind_service.py
git commit -m "refactor: extract document lifecycle management into rag/document_lifecycle_service.py"
```

---

### Task 6: Extract ingestion service

**Files:**
- Create: `backend/rag/ingestion_service.py`
- Modify: `backend/rag/documind_service.py` (replace `ingest_document` body with a delegate)
- Test: `backend/tests/test_documind_service_flows.py` (ingestion-focused cases), `backend/tests/test_documind_groq_routing.py`

**Interfaces:**
- Produces: `IngestionService(db, storage_bucket_getter, embeddings_getter, pdf_ocr, extractor_for)` with one method: `async def ingest_document(self, landlord_id, property_id, category, file, unit_id=None, unit_label=None, progress=None) -> DocUploadResponse`.
- Consumes: `rag.categories.{normalize_category, ALLOWED_CATEGORIES, CATEGORY_ORDER, resolve_upload_kind, facts_status_for}` (Task 1).

- [ ] **Step 1: Create `backend/rag/ingestion_service.py`.** Move `documind_service.py:514-708` (`ingest_document`) verbatim, with these substitutions throughout the body: `self.db` → `self._db`, `self.embeddings` → `self._embeddings_getter()`, `self.storage_bucket` → `self._storage_bucket_getter()`. `self._pdf_ocr` and `self._extractor_for(category)` keep the same attribute names (now instance attributes set in `__init__` below).

```python
import asyncio
import os
import tempfile
import uuid
from typing import Callable, Optional

from fastapi import UploadFile
from google.cloud import firestore
from google.cloud.firestore_v1.vector import Vector
from langchain_community.document_loaders import PyPDFLoader
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter

from models.documind_models import DocUploadResponse
from rag.categories import ALLOWED_CATEGORIES, CATEGORY_ORDER, facts_status_for, normalize_category, resolve_upload_kind

OCR_TEXT_THRESHOLD = 200  # chars; below this a PDF is treated as scanned


class IngestionService:
    """Upload -> OCR fallback -> chunk -> embed -> fact-extract -> Firestore/Storage."""

    def __init__(self, db, storage_bucket_getter, embeddings_getter, pdf_ocr, extractor_for: Callable):
        self._db = db
        self._storage_bucket_getter = storage_bucket_getter
        self._embeddings_getter = embeddings_getter
        self._pdf_ocr = pdf_ocr
        self._extractor_for = extractor_for

    async def ingest_document(
        self,
        landlord_id: str,
        property_id: str,
        category: str,
        file: UploadFile,
        unit_id: Optional[str] = None,
        unit_label: Optional[str] = None,
        progress: Optional[Callable[[str], None]] = None,
    ) -> DocUploadResponse:
        """
        Ingest document into Firestore with vector embeddings.

        progress, when provided, is called with a stage key ("received",
        "reading", "organising", "indexing", "details") before each stage's
        work, so a streaming caller can report live progress. The tiny
        asyncio.sleep(0) after each emit yields control to the event loop so a
        StreamingResponse can flush the event before the (blocking) stage runs.
        """
        async def _emit(stage: str) -> None:
            if progress is not None:
                progress(stage)
                await asyncio.sleep(0)

        category = normalize_category(category)
        if category not in ALLOWED_CATEGORIES:
            raise ValueError(
                f"Unsupported category '{category}'. Allowed: {', '.join(CATEGORY_ORDER)}"
            )

        ext, content_type = resolve_upload_kind(file.filename)

        doc_id = str(uuid.uuid4())

        # Step 1: Save file temporarily
        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, f"{doc_id}_{file.filename}")
        try:
            with open(temp_path, "wb") as f:
                content = await file.read()
                f.write(content)

            print(f"📄 Saved temp file: {temp_path}")
            await _emit("received")

            await _emit("reading")
            if content_type == "application/pdf":
                # Step 2a: text-layer extraction, OCR fallback for scans.
                loader = PyPDFLoader(temp_path)
                pages = loader.load()
                total_text = sum(len((page.page_content or "").strip()) for page in pages)
                if total_text < OCR_TEXT_THRESHOLD:
                    transcripts = self._pdf_ocr.transcribe(content)
                    if transcripts:
                        pages = [
                            Document(page_content=text, metadata={"page": index})
                            for index, text in enumerate(transcripts)
                        ]
                        print(f"OCR fallback transcribed {len(pages)} page(s)")
            else:
                # Step 2b: images have no text layer — transcribe directly.
                pages = []
                transcripts = self._pdf_ocr.transcribe(content, mime_type=content_type)
                if transcripts:
                    pages = [
                        Document(page_content=text, metadata={"page": index})
                        for index, text in enumerate(transcripts)
                    ]
                    print(f"Transcribed image upload ({len(pages)} block(s))")

            await _emit("organising")
            # Step 3: Chunk text
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=1000,
                chunk_overlap=200,
            )
            chunks = text_splitter.split_documents(pages)

            print(f"📝 Split into {len(chunks)} chunks")

            await _emit("indexing")
            # Step 4: Embed every chunk in ONE batched call. A quota error
            # here fails fast and visibly (0 chunks, metadata-only) instead
            # of grinding chunk-by-chunk through retry backoff.
            vectors = []
            if chunks:
                try:
                    vectors = self._embeddings_getter().embed_documents(
                        [chunk.page_content for chunk in chunks]
                    )
                except Exception as e:
                    print(f"⚠️ Batch embedding failed; indexing metadata only: {e}")
                    vectors = []

            chunk_documents = []
            for i, (chunk, embedding) in enumerate(zip(chunks, vectors)):
                chunk_doc = {
                    'doc_id': doc_id,
                    'landlord_id': landlord_id,
                    'property_id': property_id,
                    'unit_id': unit_id,
                    'unit_label': unit_label,
                    'category': category,
                    'filename': file.filename,
                    'chunk_index': i,
                    'text': chunk.page_content,
                    'embedding': Vector(embedding),
                    # ✅ FIXED: Ensure page is always an integer (never None)
                    'page': chunk.metadata.get('page', 0) if chunk.metadata.get('page') is not None else 0,
                    'created_at': firestore.SERVER_TIMESTAMP,
                }
                chunk_documents.append(chunk_doc)

            print(f"✅ Generated {len(chunk_documents)} embeddings")

            if len(chunk_documents) == 0:
                # Scanned document whose OCR fallback also produced nothing:
                # keep the document (Storage + metadata, 0 chunks) so it still
                # lists and can be re-uploaded; there is just nothing to search.
                print("⚠️ No text extracted; indexing metadata with 0 chunks")

            # Step 5: Batch write chunks to Firestore
            batch = self._db.batch()
            for chunk_doc in chunk_documents:
                chunk_ref = self._db.collection('documind_chunks').document()
                batch.set(chunk_ref, chunk_doc)

            # Commit all chunks at once
            batch.commit()
            print(f"✅ Batch wrote {len(chunk_documents)} chunks to Firestore")

            await _emit("details")
            # Fact extraction (best-effort, one LLM call over the leading
            # text). Failure must never block indexing.
            extracted_facts = None
            facts_confidence = None
            try:
                full_text = "\n".join(page.page_content or "" for page in pages)
                facts = self._extractor_for(category).extract(category, full_text)
                if facts:
                    facts_confidence = facts.pop("confidence", None)
                    extracted_facts = facts or None
            except Exception as e:
                print(f"⚠️ Fact extraction failed (non-blocking): {e}")

            # Step 5.5: Upload original file to Firebase Storage
            storage_path = f"documind/{landlord_id}/{property_id}/{doc_id}{ext}"
            blob = self._storage_bucket_getter().blob(storage_path)
            blob.upload_from_string(content, content_type=content_type)

            # Step 6: Store document metadata
            file_size = os.path.getsize(temp_path)
            doc_ref = self._db.collection('documind_docs').document(doc_id)
            doc_ref.set({
                'landlord_id': landlord_id,
                'property_id': property_id,
                'unit_id': unit_id,
                'unit_label': unit_label,
                'category': category,
                'filename': file.filename,
                'chunks_indexed': len(chunk_documents),
                'file_size': file_size,
                'storage_path': storage_path,
                'status': 'indexed',
                'extracted_facts': extracted_facts,
                'facts_confidence': facts_confidence,
                'facts_status': facts_status_for(extracted_facts),
                'facts_extracted_at': firestore.SERVER_TIMESTAMP if extracted_facts else None,
                'uploaded_at': firestore.SERVER_TIMESTAMP,
            })

            print(f"✅ Indexed {file.filename}: {len(chunk_documents)} chunks")

            return DocUploadResponse(
                doc_id=doc_id,
                landlord_id=landlord_id,
                property_id=property_id,
                category=category,
                filename=file.filename,
                status="indexed",
                chunks_indexed=len(chunk_documents),
                extracted_facts=extracted_facts,
                facts_confidence=facts_confidence,
                facts_status=facts_status_for(extracted_facts),
            )

        except Exception as e:
            print(f"❌ Document ingestion failed: {e}")
            raise

        finally:
            # Step 7: Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                print(f"🗑️ Cleaned up temp file: {temp_path}")
```

(This is a verbatim move — every `print` line and comment from the original stays; only the `self.` targets listed above change. Corrected 2026-07-31: an earlier draft of this block had condensed the code and silently dropped the progress-log prints and several WHY-comments — e.g. the Step 4 batching rationale and the "scanned document whose OCR fallback also produced nothing" note. This version is a byte-for-byte substitution-only transcription of the source, verified by diff.)

- [ ] **Step 2: In `backend/rag/documind_service.py`**, delete `ingest_document`'s body (`documind_service.py:514-708`) and replace with:

```python
    async def ingest_document(self, landlord_id, property_id, category, file, unit_id=None, unit_label=None, progress=None):
        return await self._ingestion_service.ingest_document(
            landlord_id=landlord_id, property_id=property_id, category=category,
            file=file, unit_id=unit_id, unit_label=unit_label, progress=progress,
        )
```

Add to `__init__`:
```python
        self._ingestion_service = IngestionService(
            db=self._db,
            storage_bucket_getter=lambda: self.storage_bucket,
            embeddings_getter=lambda: self.embeddings,
            pdf_ocr=self._pdf_ocr,
            extractor_for=self._extractor_for,
        )
```
Place this line after `self._pdf_ocr = PdfOcr(self._llm)` is set (it's a dependency).

Add to imports:
```python
from rag.ingestion_service import IngestionService
```

Also delete the now-unused `OCR_TEXT_THRESHOLD = 200` constant from `documind_service.py:45` (moved into `ingestion_service.py`) — confirm with `grep -n OCR_TEXT_THRESHOLD backend/rag/documind_service.py` that nothing else in the file references it before deleting.

- [ ] **Step 3: Run tests**

Run: `cd backend && python -m pytest tests/test_documind_service_flows.py tests/test_documind_groq_routing.py -v`
Expected: all PASS.

- [ ] **Step 4: Run full suite**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/ingestion_service.py backend/rag/documind_service.py
git commit -m "refactor: extract ingestion pipeline into rag/ingestion_service.py"
```

---

### Task 7: Extract ask orchestrator

**Files:**
- Create: `backend/rag/ask_orchestrator.py`
- Modify: `backend/rag/documind_service.py` (replace `ask_documind` and `_narrate_finance_summary` with a delegate; delete dead `_normalize_category_selection`)
- Test: `backend/tests/test_rex_routes_documind_ask_api.py`, `backend/tests/test_documind_service_flows.py`, `backend/tests/test_documind_evaluation.py`, `backend/tests/test_finance_chat.py`

This is the largest and highest-risk task — `ask_documind` is 580 lines with many branches (conversation / finance / confirmation / cancel / unit-ambiguity / retrieve). Move it as one unit; do not attempt to further split it in this pass — that risks behavior drift without the payoff of a clean second seam. Getting it out of the god-object and behind its own interface is the win.

**Interfaces:**
- Produces: `AskOrchestrator(conversation_store, graph_orchestrator, hybrid_retriever, llm_getter, list_available_categories, get_property_name, list_property_units, get_finance_summary)` with one method: `async def ask(self, payload: AskRequest) -> AskResponse`.
- Consumes: `rag.categories.{normalize_category, expand_categories_for_query, ALLOWED_CATEGORIES}` (Task 1), `rag.unit_resolution.resolve_unit_mention` (Task 2), `rag.pii_scrub.scrub_for_hosted`.

- [ ] **Step 1: Delete dead code first.** Confirm `_normalize_category_selection` (`documind_service.py:380-411`) has zero callers:

Run: `cd backend && grep -rn "_normalize_category_selection" .`
Expected: only the method's own `def` line. If any caller appears, STOP and report it instead of deleting — do not delete code with a live caller.

Delete `documind_service.py:380-411` entirely (do not move it anywhere — it's dead).

- [ ] **Step 2: Create `backend/rag/ask_orchestrator.py`.** Move `documind_service.py:425-458` (`_narrate_finance_summary`, becomes a private method) and `:1029-1608` (`ask_documind`, becomes `ask`) verbatim, with these substitutions throughout:
  - `self._list_available_categories(...)` → unchanged (now an injected callable with the same name)
  - `self._get_property_name(...)` → unchanged (injected callable)
  - `self._conversation_store` → unchanged (injected object)
  - `self._list_property_units(...)` → unchanged (injected callable)
  - `self._graph_orchestrator` → unchanged (injected object)
  - `self.get_finance_summary(...)` → `self._get_finance_summary(...)`
  - `self.llm` → `self._llm_getter()`
  - `self._hybrid_retriever` → unchanged (injected object)
  - `self._narrate_finance_summary(...)` → unchanged (now a sibling private method on this same class)
  - `normalize_category`, `expand_categories_for_query`, `ALLOWED_CATEGORIES`, `resolve_unit_mention`, `scrub_for_hosted` → import from their new/existing modules instead of module-level names in `documind_service.py`

```python
from datetime import datetime
from typing import Dict, List, Optional

from models.documind_models import AskRequest, AskResponse, Citation, UnitOption
from rag.categories import ALLOWED_CATEGORIES, expand_categories_for_query, normalize_category
from rag.pii_scrub import scrub_for_hosted
from rag.unit_resolution import resolve_unit_mention


class AskOrchestrator:
    """The LangGraph-driven chat flow: route intent -> conversation / finance /
    confirmation / cancel / unit-clarification / retrieve+answer."""

    def __init__(
        self, *, conversation_store, graph_orchestrator, hybrid_retriever, llm_getter,
        list_available_categories, get_property_name, list_property_units, get_finance_summary,
    ):
        self._conversation_store = conversation_store
        self._graph_orchestrator = graph_orchestrator
        self._hybrid_retriever = hybrid_retriever
        self._llm_getter = llm_getter
        self._list_available_categories = list_available_categories
        self._get_property_name = get_property_name
        self._list_property_units = list_property_units
        self._get_finance_summary = get_finance_summary

    def _narrate_finance_summary(self, question: str, property_name: str, summary) -> str:
        """Turn the engine's computed JSON into a chat answer. The LLM narrates
        only — on any failure a deterministic headline line stands in, so the
        numbers shown are always the engine's."""
        totals = summary.totals
        top_caveat = summary.caveats[0] if summary.caveats else ""
        prompt = f"""You are DocuMind, answering a landlord's finance question.

**Question:** {question}
**Currently selected property (context only — figures below cover the whole portfolio):** {property_name}

**Computed figures for {summary.year} (authoritative):**
{summary.model_dump_json(indent=2)}

Rules:
1. Answer using ONLY the figures above, quoted exactly as given. NEVER recompute, derive, add, or estimate any number yourself.
2. If a figure the user wants is not present above, say it is not computed rather than deriving it.
3. When mentioning statutory rental income, always attach: "{totals.statutory_note}".
4. Include this caveat once: {top_caveat}
5. Amounts are in RM. Be concise; short bullet points are fine.

**Your Answer:**"""
        try:
            response = self._llm_getter().invoke(prompt)
            return response.content.strip()
        except Exception as e:
            print(f"❌ Finance narration failed: {e}")
            return (
                f"For {summary.year}: gross rent RM {totals.received_rent:,.2f}, "
                f"direct expenses RM {totals.direct_expenses:,.2f}, "
                f"net P/L RM {totals.net_pl:,.2f}. "
                f"Statutory rental income: RM {totals.statutory_rental_income:,.2f} "
                f"({totals.statutory_note})."
            )

    async def ask(self, payload: AskRequest) -> AskResponse:
        """
        Answer question using Firestore Vector Search.

        Flow:
        1. Generate embedding for question
        2. Vector search in Firestore (find_nearest)
        3. Build context from retrieved chunks
        4. Send to Gemini for answer synthesis
        5. Return answer with citations

        Args:
            payload: AskRequest with landlord_id, property_id, question, top_k

        Returns:
            AskResponse with answer, citations, confidence
        """

        category_filter_mode = "all"
        available_categories = self._list_available_categories(payload.landlord_id, payload.property_id)
        property_name = self._get_property_name(payload.property_id)

        # Normalize explicit category filters from payload
        requested_categories = payload.categories or []
        normalized_explicit = [category.strip().lower() for category in requested_categories if category and category.strip()]
        explicit_valid = [category for category in normalized_explicit if category in ALLOWED_CATEGORIES]

        session = self._conversation_store.get_or_create_session(
            landlord_id=payload.landlord_id,
            property_id=payload.property_id,
            session_id=payload.session_id,
        )
        session_id = session.get("session_id")
        turn_number = max(1, self._conversation_store.get_turn_count(session_id) + 1)
        recent_turns = session.get("conversation_turns", []) if isinstance(session, dict) else []

        # Units go into the graph so the routing node can decide the unit
        # scope in the same LLM call that picks categories.
        property_units = self._list_property_units(payload.property_id)

        graph_state = await self._graph_orchestrator.run({
            "user_input": payload.question,
            "explicit_categories": explicit_valid,
            "available_categories": available_categories,
            "available_units": property_units,
            "user_action": payload.user_action or "",
            "recent_turns": recent_turns,
            "property_name": property_name,
        })

        graph_action = graph_state.get("action", "retrieve")
        predicted_categories = graph_state.get("predicted_categories", [])
        action_reason = graph_state.get("prediction_reason") or graph_state.get("intent_reason")

        # Conversational mode: no retrieval required yet
        if graph_action == "conversation":
            answer = graph_state.get(
                "assistant_message",
                "Hey! If you have anything that needs help with on property documents, please let me know.",
            )
            if property_name != "Unknown Property" and property_name.lower() not in answer.lower():
                answer = f"For {property_name}, {answer}"
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": graph_state.get("intent", "conversation"),
                    "action": "conversation",
                    "answer": answer,
                },
            )
            return AskResponse(
                answer=answer,
                confidence=graph_state.get("intent_confidence", 0.9),
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="conversation",
                needs_category_clarification=False,
                clarification_prompt=None,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=[],
                action_reason=graph_state.get("intent_reason"),
            )

        # Finance branch: skip retrieval entirely — the deterministic engine
        # computes, the LLM only narrates (2 LLM calls total incl. the router).
        if graph_action == "finance":
            requested_year = graph_state.get("finance_year") or datetime.now().year
            try:
                summary = await self._get_finance_summary(payload.landlord_id, requested_year)
                answer = self._narrate_finance_summary(payload.question, property_name, summary)
            except Exception as e:
                print(f"❌ Finance summary failed: {e}")
                answer = (
                    "I couldn't compute your rental finances just now. "
                    "Please try again in a moment."
                )
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "finance_question",
                    "action": "finance",
                    "answer": answer,
                },
            )
            return AskResponse(
                answer=answer,
                confidence=0.9,
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="finance",
                needs_category_clarification=False,
                clarification_prompt=None,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=[],
                action_reason=graph_state.get("intent_reason"),
            )

        # Type 2 ambiguity: document question but category not explicit -> predict + confirm checkpoint
        if graph_action == "ask_confirmation":
            confirmation_message = graph_state.get("assistant_message", "Please confirm the document category to proceed.")
            if property_name != "Unknown Property" and property_name.lower() not in confirmation_message.lower():
                confirmation_message = f"For {property_name}, {confirmation_message}"
            confirmation_options = predicted_categories + [
                category for category in available_categories if category not in predicted_categories
            ]
            self._conversation_store.set_pending_confirmation(
                session_id,
                {
                    "question": payload.question,
                    "predicted_categories": predicted_categories,
                    "available_categories": available_categories,
                    "action_reason": action_reason,
                },
            )
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "document_question",
                    "action": "ask_confirmation",
                    "predicted_categories": predicted_categories,
                    "reason": action_reason,
                },
            )
            return AskResponse(
                answer=confirmation_message,
                confidence=graph_state.get("prediction_confidence", 0.6),
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="clarification",
                needs_category_clarification=True,
                clarification_prompt=confirmation_message,
                clarification_options=confirmation_options,
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=True,
                predicted_categories=predicted_categories,
                action_reason=action_reason,
            )

        if graph_action == "cancel":
            self._conversation_store.clear_pending_confirmation(session_id)
            cancel_message = graph_state.get(
                "assistant_message",
                "Understood. I cancelled that action. Ask me anytime about your property documents.",
            )
            if property_name != "Unknown Property" and property_name.lower() not in cancel_message.lower():
                cancel_message = f"For {property_name}, {cancel_message}"
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "document_question",
                    "action": "cancel",
                    "answer": cancel_message,
                },
            )
            return AskResponse(
                answer=cancel_message,
                confidence=0.9,
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="cancel",
                needs_category_clarification=False,
                clarification_prompt=None,
                clarification_options=[],
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=[],
                action_reason="User cancelled requested action",
            )

        working_question = payload.question
        selected_categories: List[str] = []
        effective_unit_id = payload.unit_id

        if explicit_valid:
            selected_categories = explicit_valid[:10]
            category_filter_mode = "explicit"
        else:
            pending = self._conversation_store.get_pending_confirmation(session_id)
            user_action_raw = (payload.user_action or "").strip()
            user_action = user_action_raw.lower()

            if user_action == "confirm":
                if pending and pending.get("predicted_categories"):
                    selected_categories = [
                        category for category in pending.get("predicted_categories", [])
                        if category in ALLOWED_CATEGORIES
                    ]
                    working_question = pending.get("question", payload.question)
                    category_filter_mode = "clarification_selected"
                self._conversation_store.clear_pending_confirmation(session_id)
            elif user_action.startswith("override:"):
                override_category = user_action.split(":", 1)[1].strip().lower()
                if override_category in ALLOWED_CATEGORIES:
                    selected_categories = [override_category]
                    working_question = pending.get("question", payload.question) if pending else payload.question
                    category_filter_mode = "clarification_selected"
                self._conversation_store.clear_pending_confirmation(session_id)
            elif user_action.startswith("unit:"):
                # Resume of a unit-ambiguity checkpoint. The unit id keeps its
                # original casing (Firestore ids are case-sensitive); the "all"
                # sentinel proceeds unfiltered. A missing pending confirmation
                # falls back to treating this as a fresh question.
                unit_target = user_action_raw.split(":", 1)[1].strip()
                if pending:
                    working_question = pending.get("question", payload.question)
                if unit_target and unit_target.lower() != "all":
                    effective_unit_id = unit_target
                # Reuse the ORIGINAL question's category scope (stashed when the
                # checkpoint fired) — the follow-up turn's text is just the unit
                # label, so re-predicting over it would drop the real scope.
                pending_categories = pending.get("selected_categories") if pending else None
                if pending_categories:
                    selected_categories = [
                        category for category in pending_categories if category in ALLOWED_CATEGORIES
                    ]
                    category_filter_mode = "clarification_selected"
                else:
                    selected_categories = [
                        category for category in predicted_categories if category in ALLOWED_CATEGORIES
                    ]
                    if selected_categories:
                        category_filter_mode = "auto"
                self._conversation_store.clear_pending_confirmation(session_id)
            elif user_action in ALLOWED_CATEGORIES:
                selected_categories = [user_action]
                working_question = pending.get("question", payload.question) if pending else payload.question
                category_filter_mode = "clarification_selected"
                self._conversation_store.clear_pending_confirmation(session_id)
            else:
                # Auto scope: apply the predicted categories only when the
                # predictor is reasonably confident; a weak prediction searches
                # the whole corpus rather than risking a wrong silent filter.
                if graph_state.get("prediction_confidence", 0.0) >= 0.45:
                    selected_categories = [
                        category for category in predicted_categories if category in ALLOWED_CATEGORIES
                    ]
                if selected_categories:
                    category_filter_mode = "auto"

        # Unit routing (skipped when the header dropdown already scopes the
        # chat or this turn resumes a unit checkpoint). The search-router LLM
        # decides the unit scope from the question when it can (tool-style
        # routing); when it couldn't, deterministic label matching takes over.
        # Either way: explicit references route silently, a reference matching
        # several units is the only case that still asks, and a reference to a
        # unit that does not exist gets an honest answer listing the real ones.
        user_action_lower = (payload.user_action or "").strip().lower()
        if effective_unit_id is None and not user_action_lower.startswith("unit:"):
            unit_ids = {unit["unit_id"] for unit in property_units}
            routed_unit_id = graph_state.get("routed_unit_id")
            unknown_mention = graph_state.get("unknown_unit_mention")
            ambiguous_candidates = None

            if unknown_mention:
                pass  # honest not-found answer below
            elif routed_unit_id and routed_unit_id in unit_ids:
                effective_unit_id = routed_unit_id
            elif not graph_state.get("unit_routing_decided"):
                unit_resolution = resolve_unit_mention(working_question, property_units)
                if unit_resolution["kind"] == "scoped":
                    effective_unit_id = unit_resolution["unit"]["unit_id"]
                elif unit_resolution["kind"] == "unknown":
                    unknown_mention = unit_resolution["mention"]
                elif unit_resolution["kind"] == "ambiguous":
                    ambiguous_candidates = unit_resolution["candidates"]

            if unknown_mention:
                unit_labels = ", ".join(sorted(u["label"] for u in property_units))
                not_found_message = (
                    f"I couldn't find {unknown_mention} in {property_name}. "
                    f"This property's units are: {unit_labels}. "
                    "Ask about one of those, or ask without naming a unit to search everything."
                )
                self._conversation_store.append_turn(
                    session_id,
                    {
                        "turn": turn_number,
                        "question": working_question,
                        "intent": "document_question",
                        "action": "unknown_unit",
                        "answer": not_found_message,
                    },
                )
                return AskResponse(
                    answer=not_found_message,
                    confidence=0.9,
                    citations=[],
                    property_name=property_name,
                    searched_categories=selected_categories,
                    category_filter_mode=category_filter_mode,
                    session_id=session_id,
                    conversation_turn=turn_number,
                    user_action_required=False,
                    predicted_categories=predicted_categories,
                    action_reason="Question referenced a unit that does not exist",
                )

            if ambiguous_candidates:
                unit_options = [
                    UnitOption(unit_id=u["unit_id"], unit_label=u["label"])
                    for u in sorted(ambiguous_candidates, key=lambda u: u["label"])
                ]
                unit_options.append(UnitOption(unit_id="all", unit_label="All units"))
                matched_labels = " and ".join(
                    option.unit_label for option in unit_options[:-1]
                )
                unit_prompt = (
                    f"That could mean {matched_labels}. Which unit do you mean?"
                )
                self._conversation_store.set_pending_confirmation(
                    session_id,
                    {
                        "type": "unit",
                        "question": working_question,
                        "selected_categories": selected_categories,
                        "unit_options": [option.model_dump() for option in unit_options],
                    },
                )
                self._conversation_store.append_turn(
                    session_id,
                    {
                        "turn": turn_number,
                        "question": working_question,
                        "intent": "document_question",
                        "action": "ask_unit_clarification",
                        "unit_options": [option.unit_id for option in unit_options],
                    },
                )
                return AskResponse(
                    answer=unit_prompt,
                    confidence=0.6,
                    citations=[],
                    property_name=property_name,
                    searched_categories=selected_categories,
                    category_filter_mode=category_filter_mode,
                    needs_category_clarification=False,
                    clarification_prompt=unit_prompt,
                    clarification_options=[],
                    session_id=session_id,
                    conversation_turn=turn_number,
                    user_action_required=True,
                    needs_unit_clarification=True,
                    unit_options=unit_options,
                    predicted_categories=predicted_categories,
                    action_reason="Unit reference matches multiple units",
                )
            # "multi", "aggregate", and "none" all search unscoped; the answer
            # prompt attributes every fact to its unit.

        try:
            retrieved_chunks = await self._hybrid_retriever.retrieve(
                question=working_question,
                landlord_id=payload.landlord_id,
                property_id=payload.property_id,
                top_k=payload.top_k,
                categories=expand_categories_for_query(selected_categories) if selected_categories else None,
                unit_id=effective_unit_id,
            )
            print(f"✅ Retrieved {len(retrieved_chunks)} chunks (hybrid dense+rerank)")
        except Exception as e:
            print(f"❌ Hybrid retrieval failed: {e}")
            return AskResponse(
                answer="I couldn't search your documents. Please check your Firestore vector index.",
                confidence=0.0,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=predicted_categories,
                action_reason="Vector search failure",
            )

        if not retrieved_chunks:
            if selected_categories:
                category_hint = ", ".join(selected_categories)
                not_found_message = f"I couldn't find relevant information in your {category_hint} documents for {property_name}."
            else:
                not_found_message = f"I couldn't find relevant information in your documents for {property_name}."
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": working_question,
                    "intent": "document_question",
                    "action": "retrieve_no_result",
                    "searched_categories": selected_categories,
                    "answer": not_found_message,
                },
            )
            return AskResponse(
                answer=not_found_message,
                confidence=0.0,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                session_id=session_id,
                conversation_turn=turn_number,
                user_action_required=False,
                predicted_categories=predicted_categories,
                action_reason="No chunks retrieved",
            )

        # No post-retrieval unit checkpoint: unit routing happened above from
        # the question text, and answers over mixed-unit chunks attribute every
        # fact to its unit (prompt rule 5) instead of blocking to ask.

        # Dedupe citations by (filename, page): multiple chunks can come from
        # the same page (overlapping splits), each with its own rerank score.
        # The LLM still sees every chunk's text via context_text below; this
        # only collapses what's shown as a citation, keeping the best score
        # per page so the same source never appears twice with two different
        # relevance bars.
        best_citation_by_page: dict[tuple[str, Optional[int]], dict] = {}
        context_text = ""
        for i, chunk in enumerate(retrieved_chunks):
            display_page = chunk['page'] + 1 if chunk.get('page') is not None else None
            page_key = (chunk['filename'], display_page)
            chunk_score = chunk.get('rerank_score', chunk.get('dense_score', 0.0))
            existing = best_citation_by_page.get(page_key)
            if existing is None or chunk_score > existing['score']:
                best_citation_by_page[page_key] = {
                    'doc_id': chunk['doc_id'],
                    'filename': chunk['filename'],
                    'category': normalize_category(chunk['category']),
                    'page': display_page,
                    'snippet': chunk['text'][:200],
                    'score': chunk_score,
                    'unit_id': chunk.get('unit_id'),
                    'unit_label': chunk.get('unit_label'),
                }
            unit_context = chunk.get('unit_label') or 'Property-wide'
            # PII gate: chunk text is the one place raw document content reaches
            # the hosted LLM. Scrub NRIC/phone/email here (citations to the app
            # keep the unscrubbed snippet — the user owns their own documents).
            safe_chunk_text = scrub_for_hosted(chunk['text'])
            context_text += f"\n\n[Document {i+1}: {chunk['filename']}, Page {display_page if display_page is not None else 'N/A'} — {unit_context}]\n{safe_chunk_text}"

        citations = [
            Citation(
                doc_id=c['doc_id'],
                filename=c['filename'],
                category=c['category'],
                page=c['page'],
                snippet=c['snippet'],
                score=c['score'],
                unit_id=c['unit_id'],
                unit_label=c['unit_label'],
            )
            for c in sorted(best_citation_by_page.values(), key=lambda c: c['score'], reverse=True)
        ]

        searched_categories_text = ", ".join(selected_categories) if selected_categories else "all categories"
        prompt = f"""You are DocuMind, an AI assistant specialized in property document management.

    **Your Purpose:**
    You help landlords understand their property documents across 7 categories:
    - Tenancy Agreements (lease terms, tenant details, rent, deposits, renewals)
    - Insurance Policies (coverage, premiums, policy periods)
    - Loans (loan agreements, bank interest statements)
    - Property Taxes (assessment tax, quit rent, parcel rent)
    - Upkeep (landlord-paid repairs and servicing)
    - Maintenance (management fees and sinking fund)
    - Rental Invoices (monthly rent billed to tenants)

    **User Question:**
    {working_question}

    **Current Property:**
    {property_name}

    **Categories Searched:**
    {searched_categories_text}

    **Relevant Document Excerpts:**
    {context_text}

    **Instructions:**
    1. **IF** the question is about property documents (lease, insurance, loan, tax, upkeep, maintenance, rental invoices):
    - Answer based ONLY on the context above
    - Do NOT cite sources or mention filenames/pages — the app displays sources separately
    - Format dates clearly (e.g., "15 March 2026")
    - Keep your answer detailed and informative but organized and concise (bullet points or numbered lists)

    2. **IF** the question is off-topic (weather, sports, general knowledge, personal advice):
    - Accomodate and Politely redirect to your purpose

    3. **IF** you cannot find the answer in the context:
    If there is uploaded documents to reference:
    - Mention that the inquired information is not found in the uploaded documents and list out the documents you have searched, only in its relevant category.
    Else if there are no uploaded documents to reference:
    - Say "You do not have any relevant uploaded documents for that matter. Please upload a [category name] document to get answers about [specific topic]."

    4. **DO NOT** make up information - only use what's provided in the context.

    5. **Unit attribution:** Each excerpt header names the unit it belongs to (or "Property-wide"). Never blend values from different units — attribute every figure to its unit. If the excerpts span multiple units, break the answer down per unit (e.g. "Unit A-12-03: ...", "Unit B-08-11: ..."). For totals across units, show each unit's value and then the combined total. Property-wide documents apply to the whole property.

    **Your Answer:**"""

        try:
            response = self._llm_getter().invoke(prompt)
            answer = response.content.strip()
            print(f"✅ Generated answer: {answer[:100]}...")
        except Exception as e:
            print(f"❌ Gemini answer generation failed: {e}")
            answer = "I encountered an error generating an answer. Please try again."

        response = AskResponse(
            answer=answer,
            confidence=0.95,  # Mock confidence
            citations=citations,
            property_name=property_name,
            searched_categories=selected_categories,
            category_filter_mode=category_filter_mode,
            needs_category_clarification=False,
            clarification_prompt=None,
            clarification_options=[],
            session_id=session_id,
            conversation_turn=turn_number,
            user_action_required=False,
            predicted_categories=predicted_categories,
            action_reason=action_reason,
        )

        self._conversation_store.append_turn(
            session_id,
            {
                "turn": turn_number,
                "question": working_question,
                "intent": "document_question",
                "action": "retrieve",
                "searched_categories": selected_categories,
                "answer": answer,
            },
        )

        return response
```

Two substitutions from the original `documind_service.py:1029-1608` body were applied above: `self.get_finance_summary(...)` → `self._get_finance_summary(...)` (finance branch), and `self.llm.invoke(prompt)` → `self._llm_getter().invoke(prompt)` (final answer synthesis). Everything else (`self._conversation_store`, `self._graph_orchestrator`, `self._hybrid_retriever`, `self._list_available_categories`, `self._get_property_name`, `self._list_property_units`, `self._narrate_finance_summary`) is unchanged — these are now `AskOrchestrator`'s own injected attributes/sibling method instead of `DocuMindService`'s.

- [ ] **Step 3: In `backend/rag/documind_service.py`**, delete `_narrate_finance_summary` (`:425-458`) and `ask_documind`'s body (`:1029-1608`), replacing the latter with:

```python
    async def ask_documind(self, payload: AskRequest) -> AskResponse:
        return await self._ask_orchestrator.ask(payload)
```

Add to `__init__` (after `self._graph_orchestrator = DocuMindGraphOrchestrator(...)`):
```python
        self._ask_orchestrator = AskOrchestrator(
            conversation_store=self._conversation_store,
            graph_orchestrator=self._graph_orchestrator,
            hybrid_retriever=self._hybrid_retriever,
            llm_getter=lambda: self.llm,
            list_available_categories=self._list_available_categories,
            get_property_name=self._get_property_name,
            list_property_units=self._list_property_units,
            get_finance_summary=self.get_finance_summary,
        )
```

Add to imports:
```python
from rag.ask_orchestrator import AskOrchestrator
```

- [ ] **Step 4: Run tests**

Run: `cd backend && python -m pytest tests/test_rex_routes_documind_ask_api.py tests/test_documind_service_flows.py tests/test_documind_evaluation.py tests/test_finance_chat.py -v`
Expected: all PASS. If anything fails, check first whether a substitution was missed (most likely culprit: a stray `self.llm` or `self.get_finance_summary` left un-substituted in the moved body).

- [ ] **Step 5: Run full suite**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count as Task 6.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/ask_orchestrator.py backend/rag/documind_service.py
git commit -m "refactor: extract ask/RAG orchestration into rag/ask_orchestrator.py"
```

---

### Task 8: Final cleanup — dead provider-wiring code + verification

**Files:**
- Modify: `backend/rag/documind_service.py`

Two more dead-code findings from the original analysis, isolated to what's left in `documind_service.py` after Tasks 1-7:

1. The module-level `embeddings = GoogleGenerativeAIEmbeddings(...)` singleton (original `documind_service.py:206-209`) is constructed at import time but never referenced anywhere — `self._embeddings` is always built lazily by the `embeddings` property instead. Confirm via `grep -rn "^embeddings" backend/rag/documind_service.py` and `grep -rn "documind_service\.embeddings\b" backend/` (should show no consumer other than the property itself) before deleting.
2. The `llm` **property**'s body (original `documind_service.py:294-304`, the lazy-load branch under `if self._llm is None:`) is unreachable: `__init__` sets `self._llm = llm` (the eager module-level singleton) directly, so `self._llm` is never `None`. The property declaration itself must stay (it's `self.llm` used throughout as an attribute access), but its dead branch should be simplified to just `return self._llm`.

- [ ] **Step 1: Confirm both findings** with the greps above. If either module-level `embeddings` or the `llm` property lazy branch turns out to have a live caller you find during the grep, stop and skip that part of this step — report it instead of deleting.

- [ ] **Step 2: Delete the dead module-level `embeddings` singleton** (the 4-line `embeddings = GoogleGenerativeAIEmbeddings(...)` block). Keep the module-level `llm = ChatGoogleGenerativeAI(...)` singleton — it IS used (`self._llm = llm` in `__init__`).

- [ ] **Step 3: Simplify the `llm` property** to:

```python
    @property
    def llm(self):
        return self._llm
```

(Removing the dead lazy-construction branch. `self._llm` is always set in `__init__`, so this property now just documents that `llm` is accessed as `self.llm` elsewhere in the codebase — safe, since no behavior path changes.)

- [ ] **Step 4: Verify the final file size and structure**

Run: `wc -l backend/rag/documind_service.py`
Expected: well under 400 lines (down from 1992) — mostly `__init__` wiring + thin delegates.

Run: `cd backend && grep -n "^    async def \|^    def " rag/documind_service.py`
Expected: every method that remains is either a delegate (1-3 line body) or genuinely composition-root logic (`get_finance_summary`, the lazy `db`/`embeddings`/`storage_bucket` properties, `_extractor_for`, `_configure_groq_extractor`, `_fact_llm`).

- [ ] **Step 5: Run the full suite one final time**

Run: `cd backend && python -m pytest tests/ -q`
Expected: same pass count as the pre-refactor baseline. This is the final gate — if this passes, the refactor is behavior-preserving end to end.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/documind_service.py
git commit -m "refactor: remove dead provider-wiring code, complete documind_service decomposition"
```

---

## Post-refactor summary (for the PR description / handoff doc update)

After Task 8, `backend/rag/documind_service.py` is a composition root wiring together:
- `IngestionService` (upload pipeline)
- `AskOrchestrator` (chat/RAG flow)
- `FinanceOverridesRepository` (5 override collections)
- `DocumentLifecycleService` (list/delete/rename/unassign/view-url)
- `property_directory` (shared read-only lookups)
- `categories` / `unit_resolution` (pure helpers, no Firestore dependency)

Update `docs/2026-07-29-pipeline-and-mobile-handoff.md` §3 after this lands — rough edge #6 ("uncommitted multi-session WIP") and the god-object shape are resolved; the remaining honest rough edges (hosted-Gemini defaults, hardcoded Gemini answer synthesis, category assigned two ways) are unchanged by this refactor and still worth flagging to the next reader.
