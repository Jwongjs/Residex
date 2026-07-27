# Loan-Input Flexibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a landlord choose, per mortgaged property, how loan figures reach the finance engine — upload the statement (existing flow) or manually enter interest + principal, monthly or annually — with the manual entries flowing through the exact same two-tier loan pipeline.

**Architecture:** Two new per-property preferences (`loanInputCadence`, `loanInputMethod`) ride the existing `Property` serialization. Manual entries persist as synthetic records in a new Firestore collection modeled on `record_rent_recovery`; at read time `get_finance_summary` loads them and hands them to `compute_finance_summary`, which converts each into a synthetic **loan document** and appends it to the document fold. From there the existing loan branch of `_expense_lines` produces the interest line (deductible + landlord-paid) and principal line (landlord-paid only), and the existing loan doc-id dedup keeps manual entries distinct from uploads. No loan math, dedup, or Net P/L logic changes.

**Tech Stack:** Python 3.11 / FastAPI / Pydantic / Firestore (backend); Flutter / Riverpod 3.x (frontend). Backend tests: `unittest` under pytest. Frontend tests: `flutter_test`.

## Global Constraints

- **Do NOT push. Commit per task only.** (User standing rule: commit or push only when asked; per-task commits are pre-authorized for this execution, pushing is not.)
- **Never touch `.env` / `.env.example`** — permission-blocked.
- Every backend test command MUST be prefixed `PYTHONIOENCODING=utf-8` (cp1252 console crashes on emoji in service logs). Run backend tests from `backend/`; frontend from `residex_app/`.
- **Known pre-existing failure — do NOT fix and do NOT let it mask a new one:** `tests.test_documind_service_flows.EmbeddingClientAndBatchingTests.test_embeddings_property_creates_client_once_and_caches` (environment-caused; not surfaced under `pytest -q`).
- No emojis anywhere in UI or code — use icon glyphs; the app must read elegant/professional.
- **Architecture principle: the app never recomputes any figure.** The backend produces authoritative display data; any frontend subtotal is a display aid only.
- Preferences are shown only when the property's mortgage question is "Yes" (`hasMortgage == true`); hidden otherwise. Defaults when mortgage=Yes but unanswered: method `upload`, cadence `annual`.
- Wire names: `loan_input_cadence` ∈ {`monthly`,`annual`}; `loan_input_method` ∈ {`upload`,`manual`}.
- Manual-entry Firestore collection: `documind_manual_loan_entries`. Deterministic doc_id: `{property_id}__{year}` (annual) or `{property_id}__{year}__{month:02d}` (monthly). Synthetic loan-document doc_id (engine): `manual__{property_id}__{period}` where period = `{year}` or `{year}-{month:02d}`.
- A **zero (or absent) principal emits no principal line**; a zero/absent interest emits no interest line.
- Ownership is validated against the property's `landlordId` on every write, exactly like `record_rent_recovery`.
- Branch: `feat/finance-tab-restructure`. Work in place (no worktree).

---

### Task 1: Engine — turn manual loan entries into loan lines

**Files:**
- Modify: `backend/rag/finance_engine.py` (add `manual_loan_entries` param to `compute_finance_summary` at line 840; add `_manual_loan_documents` helper near the other module-level helpers, e.g. just above `compute_finance_summary`)
- Test: `backend/tests/test_finance_engine.py` (extend the `_summary` helper at line 52; add a new `ManualLoanEntryEngineTests` class near the loan tests)

**Interfaces:**
- Consumes: existing `_expense_lines` loan branch (interest line subtype `"interest_statement"`, principal line subtype `"loan_principal"`), existing loan dedup (doc_id discriminator).
- Produces: `compute_finance_summary(..., manual_loan_entries: Optional[List[Dict[str, Any]]] = None)`. Each entry dict shape: `{"property_id": str, "year": int, "month": Optional[int], "interest_paid": Optional[float], "principal_paid": Optional[float], "cadence": str}`.

- [ ] **Step 1: Write the failing tests**

Add to `backend/tests/test_finance_engine.py`. First extend the `_summary` helper (line 52) to forward the new param:

```python
def _summary(documents, properties, units=None, year=2025, today=date(2026, 7, 16),
             payment_exceptions=None, document_exceptions=None, rent_recoveries=None,
             manual_loan_entries=None):
    return compute_finance_summary(
        year=year,
        today=today,
        documents=documents,
        properties=properties,
        units_by_property=units or {},
        payment_exceptions=payment_exceptions,
        document_exceptions=document_exceptions,
        rent_recoveries=rent_recoveries,
        manual_loan_entries=manual_loan_entries,
    )
```

Then add the test class:

```python
class ManualLoanEntryEngineTests(unittest.TestCase):
    def test_annual_entry_becomes_interest_and_principal_lines(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 3000.0, "cadence": "annual"},
            ],
        )
        lines = summary["properties"][0]["expense_lines"]
        by_subtype = {l["subtype"]: l for l in lines}
        self.assertEqual(by_subtype["interest_statement"]["amount"], 5000.0)
        self.assertTrue(by_subtype["interest_statement"]["deductible"])
        self.assertTrue(by_subtype["interest_statement"]["paid_by_landlord"])
        self.assertEqual(by_subtype["loan_principal"]["amount"], 3000.0)
        self.assertFalse(by_subtype["loan_principal"]["deductible"])
        self.assertTrue(by_subtype["loan_principal"]["paid_by_landlord"])

    def test_zero_principal_emits_no_principal_line(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        subtypes = {l["subtype"] for l in summary["properties"][0]["expense_lines"]}
        self.assertIn("interest_statement", subtypes)
        self.assertNotIn("loan_principal", subtypes)

    def test_manual_and_uploaded_interest_both_count(self):
        summary = _summary(
            documents=[_doc("p1", "loan", {"subtype": "interest_statement",
                                           "interest_paid": 4000.0, "period_year": 2025})],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        interest = [l for l in summary["properties"][0]["expense_lines"]
                    if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in interest), 9000.0)

    def test_monthly_entries_each_produce_a_line(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            manual_loan_entries=[
                {"property_id": "p1", "year": 2025, "month": 1, "interest_paid": 500.0,
                 "principal_paid": 0.0, "cadence": "monthly"},
                {"property_id": "p1", "year": 2025, "month": 2, "interest_paid": 500.0,
                 "principal_paid": 0.0, "cadence": "monthly"},
            ],
        )
        interest = [l for l in summary["properties"][0]["expense_lines"]
                    if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in interest), 1000.0)

    def test_entry_for_a_different_year_is_ignored(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "House")],
            year=2025,
            manual_loan_entries=[
                {"property_id": "p1", "year": 2024, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        self.assertEqual(summary["properties"][0]["expense_lines"], [])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_finance_engine.py::ManualLoanEntryEngineTests -q`
Expected: FAIL — `compute_finance_summary() got an unexpected keyword argument 'manual_loan_entries'`.

- [ ] **Step 3: Implement**

In `backend/rag/finance_engine.py`, add the helper just above `def compute_finance_summary`:

```python
def _manual_loan_documents(
    manual_loan_entries: Optional[List[Dict[str, Any]]], year: int
) -> List[Dict[str, Any]]:
    """Turn manually-entered loan figures for the target year into synthetic
    loan documents, so they ride the exact same loan branch of _expense_lines
    (interest -> deductible+landlord-paid, principal -> landlord-paid only) and
    the same doc-id-discriminated loan dedup as uploaded statements. A synthetic
    doc_id 'manual__{property}__{period}' keeps each period distinct from every
    other manual period and from any uploaded statement. Zero/absent interest or
    principal is omitted so no empty line is emitted."""
    docs: List[Dict[str, Any]] = []
    for entry in (manual_loan_entries or []):
        if not isinstance(entry, dict) or entry.get("year") != year:
            continue
        month = entry.get("month")
        period = f"{year}-{int(month):02d}" if month else str(year)
        facts: Dict[str, Any] = {"subtype": "interest_statement", "period_year": year}
        interest = _amount(entry, "interest_paid")
        principal = _amount(entry, "principal_paid")
        if interest is not None and interest > 0:
            facts["interest_paid"] = interest
        if principal is not None and principal > 0:
            facts["principal_paid"] = principal
        docs.append({
            "doc_id": f"manual__{entry.get('property_id')}__{period}",
            "property_id": entry.get("property_id"),
            "unit_id": None,
            "unit_label": None,
            "category": "loan",
            "extracted_facts": facts,
            "uploaded_at": None,
        })
    return docs
```

Add the parameter to `compute_finance_summary` (line 840 signature) after `rent_recoveries`:

```python
    rent_recoveries: Optional[List[Dict[str, Any]]] = None,
    manual_loan_entries: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    months = _months_in_scope(year, today)
    documents = list(documents) + _manual_loan_documents(manual_loan_entries, year)
```

(The `documents = ...` line is the new first line of the body, immediately after the existing `months = _months_in_scope(...)` line.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_finance_engine.py -q`
Expected: PASS (new class + all existing engine tests still green).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat: engine folds manual loan entries into the two-tier loan pipeline"
```

---

### Task 2: Service — persist, list, and delete manual loan entries

**Files:**
- Modify: `backend/rag/documind_service.py` (add `_manual_loan_entry_doc_id`, `record_manual_loan_entry`, `delete_manual_loan_entry`, `list_manual_loan_entries` near `record_rent_recovery` at line 838; add a manual-entries read to `get_finance_summary` at line 1592–1615 and pass it through at line 1606)
- Modify: `backend/tests/test_documind_service_flows.py` (extend the fake DB: add `_FakeManualLoanEntryRef`, a `stream()` branch, a `document()` branch, and a `manual_loan_entries` list on `_FakeDB`; add a `ManualLoanEntryServiceTests` class)

**Interfaces:**
- Consumes: `compute_finance_summary(..., manual_loan_entries=...)` from Task 1.
- Produces:
  - `record_manual_loan_entry(*, landlord_id, property_id, year, cadence, interest_paid, principal_paid, month=None) -> dict`
  - `delete_manual_loan_entry(*, landlord_id, property_id, year, month=None) -> dict`
  - `list_manual_loan_entries(landlord_id, property_id, year) -> List[dict]`

- [ ] **Step 1: Write the failing tests**

First extend the fake DB in `backend/tests/test_documind_service_flows.py`.

Add a ref class after `_FakeRentRecoveryRef` (line 306):

```python
class _FakeManualLoanEntryRef:
    def __init__(self, db, doc_id):
        self._db = db
        self._doc_id = doc_id

    def set(self, data):
        self._db.manual_loan_entries = [
            row for row in self._db.manual_loan_entries if row.get("doc_id") != self._doc_id
        ]
        self._db.manual_loan_entries.append({**data, "doc_id": self._doc_id})

    def get(self):
        for row in self._db.manual_loan_entries:
            if row.get("doc_id") == self._doc_id:
                return _FakePropertyDoc(exists=True, data=row)
        return _FakePropertyDoc(exists=False, data={})

    def delete(self):
        self._db.manual_loan_entries = [
            row for row in self._db.manual_loan_entries if row.get("doc_id") != self._doc_id
        ]
```

In `_FakeCollectionQuery.stream()` (line 144), add a branch before the `else`:

```python
        elif self._name == "documind_manual_loan_entries":
            rows = self._db.manual_loan_entries
```

In `_FakeCollection.document()` (line 340), add before the final `raise NotImplementedError`:

```python
        if self._name == "documind_manual_loan_entries":
            return _FakeManualLoanEntryRef(self._db, _doc_id)
```

In `_FakeDB.__init__` (line 358), add the constructor arg `manual_loan_entries=None` and the attribute:

```python
    def __init__(self, docs=None, chunks=None, property_name="Test Property", units=None,
                 payment_exceptions=None, property_owners=None, document_exceptions=None,
                 rent_recoveries=None, manual_loan_entries=None):
        ...
        self.manual_loan_entries = manual_loan_entries or []
```

Then add the test class near `RentRecoveryServiceTests` (line 2145):

```python
class ManualLoanEntryServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_record_stores_an_annual_entry(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=3000.0,
        )

        self.assertEqual(result["interest_paid"], 5000.0)
        self.assertEqual(result["principal_paid"], 3000.0)
        self.assertEqual(len(fake_db.manual_loan_entries), 1)
        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__2025")

    async def test_monthly_entry_requires_a_month(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.record_manual_loan_entry(
                landlord_id="l1", property_id="p1", year=2025, cadence="monthly",
                interest_paid=500.0, principal_paid=0.0, month=None,
            )

    async def test_monthly_entry_keys_by_month(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="monthly",
            interest_paid=500.0, principal_paid=0.0, month=3,
        )

        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__2025__03")

    async def test_record_rejects_wrong_owner(self):
        fake_db = _FakeDB(property_owners={"p1": "someone-else"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.record_manual_loan_entry(
                landlord_id="l1", property_id="p1", year=2025, cadence="annual",
                interest_paid=5000.0, principal_paid=0.0,
            )
        self.assertEqual(fake_db.manual_loan_entries, [])

    async def test_record_rejects_negative_amount(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        with self.assertRaises(ValueError):
            await service.record_manual_loan_entry(
                landlord_id="l1", property_id="p1", year=2025, cadence="annual",
                interest_paid=-1.0, principal_paid=0.0,
            )

    async def test_record_is_idempotent_per_period(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=6000.0, principal_paid=0.0,
        )

        self.assertEqual(len(fake_db.manual_loan_entries), 1)
        self.assertEqual(fake_db.manual_loan_entries[0]["interest_paid"], 6000.0)

    async def test_list_returns_entries_for_the_year(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2024, cadence="annual",
            interest_paid=1000.0, principal_paid=0.0,
        )

        entries = service.list_manual_loan_entries("l1", "p1", 2025)

        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["interest_paid"], 5000.0)

    async def test_delete_is_idempotent(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        result = await service.delete_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025,
        )

        self.assertEqual(result["property_id"], "p1")
        self.assertEqual(fake_db.manual_loan_entries, [])

    async def test_get_finance_summary_folds_a_manual_entry(self):
        fake_db = _FakeDB(
            manual_loan_entries=[{
                "doc_id": "p1__2025", "landlord_id": "l1", "property_id": "p1",
                "year": 2025, "month": None, "interest_paid": 5000.0,
                "principal_paid": 3000.0, "cadence": "annual",
            }],
        )
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "House",
             "property_type": "landed", "has_mortgage": True},
        ]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        summary = await service.get_finance_summary("l1", 2025)

        subtypes = {l.subtype for l in summary.properties[0].expense_lines}
        self.assertIn("interest_statement", subtypes)
        self.assertIn("loan_principal", subtypes)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_documind_service_flows.py::ManualLoanEntryServiceTests -q`
Expected: FAIL — `AttributeError: 'DocuMindService' object has no attribute 'record_manual_loan_entry'`.

- [ ] **Step 3: Implement the service methods**

In `backend/rag/documind_service.py`, add after `clear_rent_recovery` (line 889):

```python
    def _manual_loan_entry_doc_id(self, property_id: str, year: int, month: Optional[int]) -> str:
        if month is not None:
            return f"{property_id}__{year}__{int(month):02d}"
        return f"{property_id}__{year}"

    async def record_manual_loan_entry(
        self, *, landlord_id: str, property_id: str, year: int, cadence: str,
        interest_paid: float, principal_paid: float, month: Optional[int] = None,
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
        property_ref = self.db.collection('properties').document(property_id)
        property_snapshot = property_ref.get()
        if not property_snapshot.exists or (property_snapshot.to_dict() or {}).get('landlordId') != landlord_id:
            raise ValueError(f"Property {property_id} not found for landlord {landlord_id}")
        doc_id = self._manual_loan_entry_doc_id(property_id, year, month)
        ref = self.db.collection('documind_manual_loan_entries').document(doc_id)
        ref.set({
            'landlord_id': landlord_id,
            'property_id': property_id,
            'year': year,
            'month': month,
            'interest_paid': float(interest_paid),
            'principal_paid': float(principal_paid),
            'cadence': cadence,
            'updated_at': firestore.SERVER_TIMESTAMP,
        })
        return {
            "property_id": property_id, "year": year, "month": month,
            "interest_paid": float(interest_paid), "principal_paid": float(principal_paid),
            "cadence": cadence,
        }

    async def delete_manual_loan_entry(
        self, *, landlord_id: str, property_id: str, year: int, month: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Remove a manual loan entry. Idempotent — deleting an absent entry is
        a no-op, not an error."""
        doc_id = self._manual_loan_entry_doc_id(property_id, year, month)
        ref = self.db.collection('documind_manual_loan_entries').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "year": year, "month": month}

    def list_manual_loan_entries(
        self, landlord_id: str, property_id: str, year: int,
    ) -> List[Dict[str, Any]]:
        """All manual loan entries for one property and year, for the finance-tab
        list/edit UI. Ownership-scoped by landlord_id."""
        query = self.db.collection('documind_manual_loan_entries').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        entries: List[Dict[str, Any]] = []
        for snap in query.stream():
            data = snap.to_dict() or {}
            if data.get("property_id") != property_id or data.get("year") != year:
                continue
            entries.append({
                "property_id": data.get("property_id"),
                "year": data.get("year"),
                "month": data.get("month"),
                "interest_paid": data.get("interest_paid"),
                "principal_paid": data.get("principal_paid"),
                "cadence": data.get("cadence"),
            })
        return entries
```

In `get_finance_summary`, after the `rent_recoveries` read loop (line 1604) and before `summary = compute_finance_summary(`, add:

```python
        manual_loan_entries = []
        manual_query = self.db.collection('documind_manual_loan_entries').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        for snap in manual_query.stream():
            data = snap.to_dict() or {}
            manual_loan_entries.append({
                "property_id": data.get("property_id"),
                "year": data.get("year"),
                "month": data.get("month"),
                "interest_paid": data.get("interest_paid"),
                "principal_paid": data.get("principal_paid"),
                "cadence": data.get("cadence"),
            })
```

And pass it into the call (add the kwarg after `rent_recoveries=rent_recoveries,`):

```python
            rent_recoveries=rent_recoveries,
            manual_loan_entries=manual_loan_entries,
        )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_documind_service_flows.py -q`
Expected: PASS (new class green; all existing service tests still green, except the documented pre-existing embedding failure which does not surface under `-q`).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/documind_service.py backend/tests/test_documind_service_flows.py
git commit -m "feat: persist, list, and delete manual loan entries; fold into finance summary"
```

---

### Task 3: API — request/response models + PUT/DELETE/GET routes

**Files:**
- Modify: `backend/models/documind_models.py` (add `ManualLoanEntryRequest`, `ManualLoanEntryResponse`, `ManualLoanEntryListResponse` after `RentRecoveryResponse` at line 363)
- Modify: `backend/api/rex_routes.py` (add the three models to the import at line 2; add three routes after `clear_rent_recovery` at line 260)
- Test: `backend/tests/test_rex_routes_finance_api.py` (add route tests near the rent-recovery tests at line 241)

**Interfaces:**
- Consumes: `documind_service.record_manual_loan_entry / delete_manual_loan_entry / list_manual_loan_entries` from Task 2.
- Produces: `PUT /api/rex/documind/finance/manual-loan-entry`, `DELETE /api/rex/documind/finance/manual-loan-entry`, `GET /api/rex/documind/finance/manual-loan-entry`.

- [ ] **Step 1: Write the failing tests**

Add to `backend/tests/test_rex_routes_finance_api.py` (it already imports `patch`, `AsyncMock`, `MagicMock` — verify at top; `list_manual_loan_entries` is sync so mock it with `MagicMock`):

```python
    def test_record_manual_loan_entry_returns_200_and_forwards_params(self):
        with patch(
            "api.rex_routes.documind_service.record_manual_loan_entry",
            new=AsyncMock(return_value={
                "property_id": "p1", "year": 2025, "month": None,
                "interest_paid": 5000.0, "principal_paid": 3000.0, "cadence": "annual",
            }),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/manual-loan-entry",
                json={
                    "landlord_id": "landlord-1", "property_id": "p1", "year": 2025,
                    "cadence": "annual", "interest_paid": 5000.0, "principal_paid": 3000.0,
                },
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["interest_paid"], 5000.0)
        self.assertEqual(kwargs["cadence"], "annual")

    def test_record_manual_loan_entry_monthly_without_month_is_422(self):
        response = self.client.put(
            "/api/rex/documind/finance/manual-loan-entry",
            json={
                "landlord_id": "landlord-1", "property_id": "p1", "year": 2025,
                "cadence": "monthly", "interest_paid": 500.0, "principal_paid": 0.0,
            },
        )
        self.assertEqual(response.status_code, 422)

    def test_record_manual_loan_entry_negative_amount_is_422(self):
        response = self.client.put(
            "/api/rex/documind/finance/manual-loan-entry",
            json={
                "landlord_id": "landlord-1", "property_id": "p1", "year": 2025,
                "cadence": "annual", "interest_paid": -1.0, "principal_paid": 0.0,
            },
        )
        self.assertEqual(response.status_code, 422)

    def test_delete_manual_loan_entry_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.delete_manual_loan_entry",
            new=AsyncMock(return_value={"property_id": "p1", "year": 2025, "month": None}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/manual-loan-entry",
                params={"landlord_id": "landlord-1", "property_id": "p1", "year": 2025},
            )
            kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["property_id"], "p1")

    def test_list_manual_loan_entries_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.list_manual_loan_entries",
            new=MagicMock(return_value=[{
                "property_id": "p1", "year": 2025, "month": None,
                "interest_paid": 5000.0, "principal_paid": 3000.0, "cadence": "annual",
            }]),
        ):
            response = self.client.get(
                "/api/rex/documind/finance/manual-loan-entry",
                params={"landlord_id": "landlord-1", "property_id": "p1", "year": 2025},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()["entries"]), 1)
        self.assertEqual(response.json()["entries"][0]["interest_paid"], 5000.0)
```

If `MagicMock` is not already imported at the top of the file, add it to the `from unittest.mock import ...` line.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_rex_routes_finance_api.py -q -k manual_loan`
Expected: FAIL — 404 (routes not defined) / import errors.

- [ ] **Step 3: Implement the models**

In `backend/models/documind_models.py`, after `RentRecoveryResponse` (line 363), add (ensure `model_validator` is imported from pydantic at the top — if only `BaseModel, Field` are imported, add `model_validator`):

```python
# ========== MANUAL LOAN ENTRY MODELS ==========

class ManualLoanEntryRequest(BaseModel):
    landlord_id: str
    property_id: str
    year: int = Field(..., ge=2000, le=2100)
    cadence: str = Field(..., description="'monthly' or 'annual'")
    interest_paid: float = Field(..., ge=0)
    principal_paid: float = Field(..., ge=0)
    month: Optional[int] = Field(None, ge=1, le=12, description="Required for monthly cadence")

    @model_validator(mode="after")
    def _check_cadence(self):
        if self.cadence not in ("monthly", "annual"):
            raise ValueError("cadence must be 'monthly' or 'annual'")
        if self.cadence == "monthly" and self.month is None:
            raise ValueError("monthly cadence requires a month (1-12)")
        return self


class ManualLoanEntryResponse(BaseModel):
    property_id: str
    year: int
    month: Optional[int] = None
    interest_paid: float
    principal_paid: float
    cadence: str


class ManualLoanEntryListResponse(BaseModel):
    entries: List[ManualLoanEntryResponse]
```

- [ ] **Step 4: Implement the routes**

In `backend/api/rex_routes.py`, extend the model import at line 2 with `ManualLoanEntryRequest, ManualLoanEntryResponse, ManualLoanEntryListResponse`. Add after `clear_rent_recovery` (line 260):

```python
@router.put("/documind/finance/manual-loan-entry", response_model=ManualLoanEntryResponse)
async def record_manual_loan_entry(payload: ManualLoanEntryRequest):
    """Book manually-entered loan interest/principal for a period, for
    landlords whose bank statement cadence makes uploading inconvenient. The
    figures flow through the same two-tier loan pipeline as an uploaded
    statement. Idempotent per (property, year, month)."""
    try:
        return await documind_service.record_manual_loan_entry(
            landlord_id=payload.landlord_id,
            property_id=payload.property_id,
            year=payload.year,
            cadence=payload.cadence,
            interest_paid=payload.interest_paid,
            principal_paid=payload.principal_paid,
            month=payload.month,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/manual-loan-entry")
async def delete_manual_loan_entry(
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
    property_id: str = Query(..., description="Property ID"),
    year: int = Query(..., ge=2000, le=2100),
    month: int | None = Query(None, ge=1, le=12, description="Month for a monthly entry; omit for annual"),
):
    """Remove a manual loan entry. Idempotent — deleting an absent entry is a
    no-op, not an error."""
    return await documind_service.delete_manual_loan_entry(
        landlord_id=landlord_id, property_id=property_id, year=year, month=month,
    )


@router.get("/documind/finance/manual-loan-entry", response_model=ManualLoanEntryListResponse)
async def list_manual_loan_entries(
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
    property_id: str = Query(..., description="Property ID"),
    year: int = Query(..., ge=2000, le=2100),
):
    """All manual loan entries for one property and year, for the finance-tab
    list/edit UI."""
    entries = documind_service.list_manual_loan_entries(landlord_id, property_id, year)
    return {"entries": entries}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_rex_routes_finance_api.py -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/models/documind_models.py backend/api/rex_routes.py backend/tests/test_rex_routes_finance_api.py
git commit -m "feat: manual-loan-entry API (PUT/DELETE/GET) with cadence validation"
```

---

### Task 4: Property entity/model — two loan-input preferences

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/property.dart` (add two fields, constructor params, copyWith)
- Modify: `residex_app/lib/features/landlord/data/models/property_model.dart` (constructor, fromEntity, toEntity, fromJson, toJson)
- Test: `residex_app/test/features/landlord/property_profile_fields_test.dart` (extend the existing round-trip tests)

**Interfaces:**
- Produces: `Property.loanInputCadence` (`String?`), `Property.loanInputMethod` (`String?`); wire keys `loan_input_cadence`, `loan_input_method`.

- [ ] **Step 1: Write the failing test**

In `residex_app/test/features/landlord/property_profile_fields_test.dart`, extend the `_propertyJson` helper with two params and the conditional keys, and add assertions:

```dart
Map<String, dynamic> _propertyJson({
  String? propertyType,
  bool? hasMortgage,
  int? trackFromYear,
  String? utilitiesPaidBy,
  String? loanInputCadence,
  String? loanInputMethod,
}) {
  return {
    // ...existing keys...
    if (propertyType != null) 'property_type': propertyType,
    if (hasMortgage != null) 'has_mortgage': hasMortgage,
    if (trackFromYear != null) 'track_from_year': trackFromYear,
    if (utilitiesPaidBy != null) 'utilities_paid_by': utilitiesPaidBy,
    if (loanInputCadence != null) 'loan_input_cadence': loanInputCadence,
    if (loanInputMethod != null) 'loan_input_method': loanInputMethod,
  };
}
```

In the first test ("profile fields parse and round-trip"), pass `loanInputCadence: 'monthly', loanInputMethod: 'manual'` into `_propertyJson(...)` and add:

```dart
    expect(model.loanInputCadence, 'monthly');
    expect(model.loanInputMethod, 'manual');
    expect(json['loan_input_cadence'], 'monthly');
    expect(json['loan_input_method'], 'manual');
```

In the second test ("absent profile fields fall back..."), add:

```dart
    expect(model.loanInputCadence, isNull);
    expect(model.loanInputMethod, isNull);
    expect(json['loan_input_cadence'], isNull);
    expect(json['loan_input_method'], isNull);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/property_profile_fields_test.dart`
Expected: FAIL — `The getter 'loanInputCadence' isn't defined for the type 'PropertyModel'`.

- [ ] **Step 3: Implement — entity**

In `property.dart`, after the `utilitiesPaidBy` field (line 135) add:

```dart
  /// 'monthly' | 'annual' — how often the landlord books loan figures. null
  /// until the mortgage question is answered "Yes". Informational for the
  /// upload method; shapes the manual-entry form.
  final String? loanInputCadence;

  /// 'upload' | 'manual' — whether loan figures arrive by uploaded statement
  /// (default) or manual entry. null until mortgage = Yes.
  final String? loanInputMethod;
```

Add to the constructor (after `this.utilitiesPaidBy = 'tenant',` at line 170):

```dart
    this.loanInputCadence,
    this.loanInputMethod,
```

Add to `copyWith` params (after `String? utilitiesPaidBy,` at line 208):

```dart
    String? loanInputCadence,
    String? loanInputMethod,
```

Add to the `copyWith` body (after `utilitiesPaidBy: utilitiesPaidBy ?? this.utilitiesPaidBy,` at line 229):

```dart
      loanInputCadence: loanInputCadence ?? this.loanInputCadence,
      loanInputMethod: loanInputMethod ?? this.loanInputMethod,
```

- [ ] **Step 4: Implement — model**

In `property_model.dart`:

Constructor (after `super.utilitiesPaidBy = 'tenant',` at line 21):

```dart
    super.loanInputCadence,
    super.loanInputMethod,
```

`fromEntity` (after `utilitiesPaidBy: property.utilitiesPaidBy,` at line 45):

```dart
      loanInputCadence: property.loanInputCadence,
      loanInputMethod: property.loanInputMethod,
```

`toEntity` (after `utilitiesPaidBy: utilitiesPaidBy,` at line 70):

```dart
      loanInputCadence: loanInputCadence,
      loanInputMethod: loanInputMethod,
```

`fromJson` (after `utilitiesPaidBy: json['utilities_paid_by'] as String? ?? 'tenant',` at line 106):

```dart
      loanInputCadence: json['loan_input_cadence'] as String?,
      loanInputMethod: json['loan_input_method'] as String?,
```

`toJson` (after `'utilities_paid_by': utilitiesPaidBy,` at line 145):

```dart
      'loan_input_cadence': loanInputCadence,
      'loan_input_method': loanInputMethod,
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/property_profile_fields_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/property.dart residex_app/lib/features/landlord/data/models/property_model.dart residex_app/test/features/landlord/property_profile_fields_test.dart
git commit -m "feat: loan-input cadence/method preferences on Property"
```

---

### Task 5: Registration/edit dialog — reveal and persist the two preferences

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart` (state fields; init from property; two selector widgets shown when `_hasMortgage == true`; persist on save)
- Test: `residex_app/test/features/landlord/add_property_dialog_loan_prefs_test.dart` (create)

**Interfaces:**
- Consumes: `Property.loanInputCadence` / `loanInputMethod` from Task 4; existing `AppChoiceChip`.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/add_property_dialog_loan_prefs_test.dart`. Mirror the ProviderScope + pump pattern used by sibling dialog/widget tests (see `registration_document_steps_test.dart` for the harness). Minimal behavior test: pumping the dialog in edit mode for a mortgaged property shows the cadence and method labels; for a non-mortgaged property they are absent.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/add_property_dialog.dart';

Property _property({bool? hasMortgage}) => Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Kiara Court',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      hasMortgage: hasMortgage,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('loan-input selectors appear when mortgage = Yes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: true))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('How do you record loan figures?'), findsOneWidget);
    expect(find.text('Upload statements'), findsOneWidget);
    expect(find.text('Enter manually'), findsOneWidget);
  });

  testWidgets('loan-input selectors hidden when mortgage != Yes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: false))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('How do you record loan figures?'), findsNothing);
  });
}
```

If the dialog needs a scrollable viewport to render in a test window, wrap the `home:` in a sized `Scaffold`/`SingleChildScrollView` following the sibling test that already does so; keep the finds the same.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/add_property_dialog_loan_prefs_test.dart`
Expected: FAIL — the label text is not found.

- [ ] **Step 3: Implement**

Add state fields near `_hasMortgage` (line 44):

```dart
  String? _loanInputCadence;
  String? _loanInputMethod;
```

In `initState`, inside the `if (property != null)` block (after `_hasMortgage = property.hasMortgage;` at line 79):

```dart
      _loanInputCadence = property.loanInputCadence;
      _loanInputMethod = property.loanInputMethod;
```

Add a builder method next to `_buildMortgageSelector` (after line 622). When mortgage=Yes but a pref is unset, seed the effective default for display (method `upload`, cadence `annual`) without mutating state until the user taps:

```dart
  Widget _buildLoanInputSelectors() {
    final method = _loanInputMethod ?? 'upload';
    final cadence = _loanInputCadence ?? 'annual';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How do you record loan figures?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'Upload statements',
              selected: method == 'upload',
              onSelected: (_) => setState(() => _loanInputMethod = 'upload'),
            ),
            AppChoiceChip(
              label: 'Enter manually',
              selected: method == 'manual',
              onSelected: (_) => setState(() => _loanInputMethod = 'manual'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('How often?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'Annually',
              selected: cadence == 'annual',
              onSelected: (_) => setState(() => _loanInputCadence = 'annual'),
            ),
            AppChoiceChip(
              label: 'Monthly',
              selected: cadence == 'monthly',
              onSelected: (_) => setState(() => _loanInputCadence = 'monthly'),
            ),
          ],
        ),
      ],
    );
  }
```

Show it under the mortgage selector in the build tree (after `_buildMortgageSelector(),` at line 412):

```dart
                      _buildMortgageSelector(),
                      if (_hasMortgage == true) ...[
                        const SizedBox(height: 16),
                        _buildLoanInputSelectors(),
                      ],
                      const SizedBox(height: 16),
```

Persist on save. In edit mode's `copyWith` (line 129) add:

```dart
          loanInputCadence: _hasMortgage == true ? (_loanInputCadence ?? 'annual') : null,
          loanInputMethod: _hasMortgage == true ? (_loanInputMethod ?? 'upload') : null,
```

In create mode's `Property(...)` (line 142) add the same two named args:

```dart
          loanInputCadence: _hasMortgage == true ? (_loanInputCadence ?? 'annual') : null,
          loanInputMethod: _hasMortgage == true ? (_loanInputMethod ?? 'upload') : null,
```

(When mortgage is not Yes, both persist as null — matching the "hidden and ignored" rule; existing data is only overwritten to null when the landlord explicitly changed the mortgage answer away from Yes.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd residex_app && flutter test test/features/landlord/add_property_dialog_loan_prefs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart residex_app/test/features/landlord/add_property_dialog_loan_prefs_test.dart
git commit -m "feat: reveal and persist loan-input preferences in the property dialog"
```

---

### Task 6: Datasource + providers + API constant

**Files:**
- Modify: `residex_app/lib/core/constants/api_constants.dart` (add `documindManualLoanEntry`)
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart` (add `recordManualLoanEntry`, `deleteManualLoanEntry`, `listManualLoanEntries`; add a small `ManualLoanEntry` DTO or return `List<Map<String, dynamic>>`)
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (add `recordManualLoanEntryActionProvider`, `deleteManualLoanEntryActionProvider`, and a `manualLoanEntriesProvider` family for listing; invalidate `financeSummaryProvider` after writes)
- Test: `residex_app/test/features/landlord/manual_loan_entry_datasource_test.dart` (create — use a mocked `http.Client` following the pattern already used to test the datasource, if one exists; otherwise a focused test that the request body/URL are correct)

**Interfaces:**
- Consumes: the Task 3 endpoints.
- Produces: datasource methods and Riverpod action/list providers used by Task 7.

- [ ] **Step 1: Write the failing test**

Inspect an existing datasource test for the http-mock harness (search `test/` for one that constructs `DocumindRemoteDataSource` with a fake `http.Client`). If present, mirror it. Create `residex_app/test/features/landlord/manual_loan_entry_datasource_test.dart` asserting that `recordManualLoanEntry(...)` issues a `PUT` to `.../documind/finance/manual-loan-entry` with a JSON body containing `landlord_id`, `property_id`, `year`, `cadence`, `interest_paid`, `principal_paid`, and (for monthly) `month`, and that a non-200 throws.

If no datasource-with-fake-client harness exists in the repo, instead write the test at the provider level is out of scope here — keep this test minimal and focused on request shape using a `MockClient` from `package:http/testing.dart` (already a transitive dep of `http`). Concrete skeleton:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:residex_app/features/landlord/data/datasources/documind_remote_datasource.dart';

void main() {
  test('recordManualLoanEntry PUTs the entry', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{}', 200);
    });
    final ds = DocumindRemoteDataSource(httpClient: client);

    await ds.recordManualLoanEntry(
      landlordId: 'l1', propertyId: 'p1', year: 2025,
      cadence: 'annual', interestPaid: 5000, principalPaid: 3000,
    );

    expect(captured.method, 'PUT');
    expect(captured.url.path, contains('/documind/finance/manual-loan-entry'));
    final body = json.decode(captured.body) as Map<String, dynamic>;
    expect(body['cadence'], 'annual');
    expect(body['interest_paid'], 5000);
  });
}
```

Adjust the `DocumindRemoteDataSource(...)` constructor call to match its actual signature (check whether `httpClient` is a named or positional param).

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_datasource_test.dart`
Expected: FAIL — `recordManualLoanEntry` not defined.

- [ ] **Step 3: Implement — constant**

In `api_constants.dart`, after `documindRentRecovery` (line 22):

```dart
  static const String documindManualLoanEntry = '/api/rex/documind/finance/manual-loan-entry';
```

- [ ] **Step 4: Implement — datasource**

In `documind_remote_datasource.dart`, add before the closing brace (after `clearRentRecovery`, line 482):

```dart
  /// Book manually-entered loan interest/principal for a period. Idempotent
  /// per (property, year, month). [month] is required only for monthly cadence.
  Future<void> recordManualLoanEntry({
    required String landlordId,
    required String propertyId,
    required int year,
    required String cadence,
    required double interestPaid,
    required double principalPaid,
    int? month,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindManualLoanEntry}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'landlord_id': landlordId,
        'property_id': propertyId,
        'year': year,
        'cadence': cadence,
        'interest_paid': interestPaid,
        'principal_paid': principalPaid,
        if (month != null) 'month': month,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to record manual loan entry: ${response.body}');
    }
  }

  /// Remove a manual loan entry. Idempotent.
  Future<void> deleteManualLoanEntry({
    required String landlordId,
    required String propertyId,
    required int year,
    int? month,
  }) async {
    final queryParameters = {
      'landlord_id': landlordId,
      'property_id': propertyId,
      'year': '$year',
      if (month != null) 'month': '$month',
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindManualLoanEntry}')
        .replace(queryParameters: queryParameters);
    final response = await httpClient.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete manual loan entry: ${response.body}');
    }
  }

  /// All manual loan entries for one property and year.
  Future<List<Map<String, dynamic>>> listManualLoanEntries({
    required String landlordId,
    required String propertyId,
    required int year,
  }) async {
    final queryParameters = {
      'landlord_id': landlordId,
      'property_id': propertyId,
      'year': '$year',
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindManualLoanEntry}')
        .replace(queryParameters: queryParameters);
    final response = await httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to list manual loan entries: ${response.body}');
    }
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    return ((decoded['entries'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map<String, dynamic>))
        .toList();
  }
```

- [ ] **Step 5: Implement — providers**

In `documind_provider.dart`, after `clearRentRecoveryActionProvider` (line 414), add action + list providers modeled on `recordRentRecoveryActionProvider`:

```dart
/// Book manually-entered loan figures for a period.
final recordManualLoanEntryActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required int year,
  required String cadence,
  required double interestPaid,
  required double principalPaid,
  int? month,
})>((ref) {
  return ({
    required String propertyId,
    required int year,
    required String cadence,
    required double interestPaid,
    required double principalPaid,
    int? month,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.recordManualLoanEntry(
      landlordId: landlordId, propertyId: propertyId, year: year, cadence: cadence,
      interestPaid: interestPaid, principalPaid: principalPaid, month: month,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Remove a manual loan entry.
final deleteManualLoanEntryActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required int year,
  int? month,
})>((ref) {
  return ({
    required String propertyId,
    required int year,
    int? month,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.deleteManualLoanEntry(
      landlordId: landlordId, propertyId: propertyId, year: year, month: month,
    );
    ref.invalidate(financeSummaryProvider);
  };
});
```

For listing, add a family FutureProvider keyed by `(propertyId, year)`. Use a small record or a value class as the family arg — mirror any existing `.family` provider in this file for the exact idiom:

```dart
final manualLoanEntriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ({String propertyId, int year})>((ref, arg) async {
  final landlordId = ref.read(currentLandlordIdProvider);
  final dataSource = ref.read(documindRemoteDataSourceProvider);
  return dataSource.listManualLoanEntries(
    landlordId: landlordId, propertyId: arg.propertyId, year: arg.year,
  );
});
```

- [ ] **Step 6: Run the test to verify it passes + analyze**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_datasource_test.dart`
Expected: PASS.
Run: `cd residex_app && flutter analyze`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/core/constants/api_constants.dart residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart residex_app/lib/features/landlord/presentation/providers/documind_provider.dart residex_app/test/features/landlord/manual_loan_entry_datasource_test.dart
git commit -m "feat: datasource + providers for manual loan entries"
```

---

### Task 7: Finance-tab manual-entry UI

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart` (the add/edit form + list, opened as a bottom sheet)
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart` (in `_buildPropertyBlock`, when the property's `loanInputMethod == 'manual'`, add an "Add loan figures" action that opens the sheet)
- Test: `residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `recordManualLoanEntryActionProvider`, `deleteManualLoanEntryActionProvider`, `manualLoanEntriesProvider` (Task 6); `propertyByIdProvider` (existing, `property_providers.dart:97`) to read the property's `loanInputMethod`/`loanInputCadence`.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart`. Mirror the ProviderScope-override harness used by `missing_documents_sheet_test.dart` (that sheet also calls a finance action provider — copy its override style). Test that the sheet renders interest + principal fields and, on save, calls the record action with the typed amounts.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart';

void main() {
  testWidgets('save calls the record action with entered amounts', (tester) async {
    double? capturedInterest;
    double? capturedPrincipal;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recordManualLoanEntryActionProvider.overrideWithValue(({
          required String propertyId,
          required int year,
          required String cadence,
          required double interestPaid,
          required double principalPaid,
          int? month,
        }) async {
          capturedInterest = interestPaid;
          capturedPrincipal = principalPaid;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: const MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1', year: 2025, cadence: 'annual',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('manual-loan-interest')), '5000');
    await tester.enterText(find.byKey(const Key('manual-loan-principal')), '3000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedInterest, 5000);
    expect(capturedPrincipal, 3000);
  });
}
```

Adjust override idiom (`overrideWithValue` vs `overrideWith`) to whatever `missing_documents_sheet_test.dart` uses for its action provider — match it exactly.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_sheet_test.dart`
Expected: FAIL — `ManualLoanEntrySheet` does not exist.

- [ ] **Step 3: Implement — the sheet**

Create `manual_loan_entry_sheet.dart`: a `ConsumerStatefulWidget` `ManualLoanEntrySheet({required String propertyId, required int year, required String cadence})`. For `cadence == 'monthly'`, include a month picker (1–12, `DropdownButton` or a chip row); for annual, omit month. Two `TextFormField`s keyed `manual-loan-interest` / `manual-loan-principal` (numeric, RM). A "Save" button that parses the amounts (default 0 for blank) and calls `ref.read(recordManualLoanEntryActionProvider)(...)`, then closes. Below the form, watch `manualLoanEntriesProvider((propertyId: propertyId, year: year))` and list existing entries with a remove icon that calls `deleteManualLoanEntryActionProvider`. No emojis; use `Icons.*` glyphs and the finance-tab `AppColors`/`AppTextStyles`. Follow the bottom-sheet chrome of `_showCaveats` (finance_screen.dart:220) for padding/shape.

- [ ] **Step 4: Implement — the entry point**

In `finance_screen.dart` `_buildPropertyBlock` (line 313), read the property and conditionally show the action. Because the block has only `PropertyFinance`, watch the property:

```dart
    final property = ref.watch(propertyByIdProvider(block.propertyId)).valueOrNull;
    final showManualLoan = property?.loanInputMethod == 'manual';
```

Add, after the mini-stat row / rental-income row (a sensible spot is just below the `Rental Income/Loss` row, before the units list), gated on `showManualLoan`:

```dart
          if (showManualLoan) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.paper,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => ManualLoanEntrySheet(
                    propertyId: block.propertyId,
                    year: summary.year,
                    cadence: property?.loanInputCadence ?? 'annual',
                  ),
                ),
                icon: const Icon(Icons.add, size: 18, color: AppColors.registry),
                label: Text('Add loan figures', style: AppTextStyles.labelLarge),
              ),
            ),
          ],
```

Add the imports for `propertyByIdProvider` (`../../providers/property_providers.dart`) and `ManualLoanEntrySheet` (`../../widgets/common/manual_loan_entry_sheet.dart`) at the top of `finance_screen.dart`.

- [ ] **Step 5: Run the test + analyze + the finance suite**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_sheet_test.dart`
Expected: PASS.
Run: `cd residex_app && flutter analyze`
Expected: no new issues.
Run: `cd residex_app && flutter test test/features/landlord/finance_screen_test.dart test/features/landlord/finance_screen_smoke_test.dart`
Expected: PASS (entry point does not break existing rendering — `propertyByIdProvider` returns null in those tests, so the action is simply hidden).

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart
git commit -m "feat: finance-tab manual loan entry sheet + entry point"
```

---

## Final verification (after all tasks)

- Backend: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest -q` → expect all pass (except the documented pre-existing embedding test, which does not surface under `-q`).
- Frontend: `cd residex_app && flutter test test/features/landlord/` → expect all pass.
- `cd residex_app && flutter analyze` → clean.

## Self-Review notes (author)

- **Spec coverage:** prefs on Property (Task 4) + dialog (Task 5); backend manual record (Task 2); API PUT/DELETE + GET-for-listing (Task 3); engine integration reusing helpers + doc-id dedup (Task 1); finance-tab UI (Task 7); mixing sums via distinct synthetic doc_id (Task 1 test `test_manual_and_uploaded_interest_both_count`); zero principal emits no line (Task 1 test); monthly vs annual keying (Tasks 1 & 2 tests); ownership + idempotency (Task 2 tests); month-required validation (Tasks 2 & 3). All spec sections mapped.
- **Type consistency:** `record_manual_loan_entry` / `delete_manual_loan_entry` / `list_manual_loan_entries` signatures identical across service (Task 2), routes (Task 3), datasource (Task 6). Provider family arg `({String propertyId, int year})` used identically in Tasks 6 & 7. Engine param name `manual_loan_entries` identical in Tasks 1 & 2.
- **Out of scope (unchanged):** OCR/extraction, upload flow, amortization, cadence reminders.
