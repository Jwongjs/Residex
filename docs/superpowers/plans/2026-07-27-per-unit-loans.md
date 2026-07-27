# Per-Unit Loans + Loan Folder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Attribute manual loan figures to a specific unit (so they land in that unit's Net P/L + statutory), gate the "Add loan figures" button on per-unit, per-year completeness with an explicit "No loan here" mark, and give loan documents their own Documents-tab folder.

**Architecture:** A manual loan entry gains a `unit_id`; the engine already routes unit-scoped expense lines into that unit's contribution, so attribution is a small change to the synthetic-document builder. A new per-unit `documind_unit_loan_exemptions` record (mirrors the existing acknowledgment pattern) lets the landlord declare a unit has no loan. The engine computes per-unit `loan_status` and a per-property `manual_loan_incomplete` flag for the viewed year (cadence-aware); the frontend gates the button on that flag. The loan folder is a display-only tweak to `folderKeyFor`.

**Tech Stack:** Python 3.11 / FastAPI / Pydantic / Firestore (backend); Flutter / Riverpod 3.x (frontend). Backend tests: `unittest` under pytest. Frontend: `flutter_test`.

## Global Constraints

- **Do NOT push. Commit per task only** (per-task commits pre-authorized for this run; pushing is not).
- **Never touch `.env` / `.env.example`** (permission-blocked).
- Every backend test command MUST be prefixed `PYTHONIOENCODING=utf-8`; run backend tests from `backend/`, frontend from `residex_app/`.
- **Known pre-existing failure — do NOT fix, do NOT let it mask a new one:** `tests.test_documind_service_flows.EmbeddingClientAndBatchingTests.test_embeddings_property_creates_client_once_and_caches` (not surfaced under `pytest -q`).
- **Uncommitted WIP hazard:** the working tree carries unrelated multi-session WIP (a Groq extractor + untracked `backend/rag/groq_chat.py`, `rename_document`, `facts_status`, a model bump) in `documind_service.py`, `rex_routes.py`, `api_constants.dart`, `documind_remote_datasource.dart`, `documind_provider.dart`, and the two backend test files. **Stage ONLY the files each task names, by explicit path — never `git add -A`/`.`.** Before every commit run `git diff --stat <the task's files>` and confirm only your changes are present.
- No emojis anywhere; the app must read elegant/professional.
- **The app never recomputes any figure** — the backend produces authoritative display data (including `loan_status` / `manual_loan_incomplete`); the frontend only reads it.
- Wire keys: `unit_id` (snake_case) on manual-entry + exemption payloads; `loan_status` ∈ {`complete`,`incomplete`,`no_loan`}; `manual_loan_incomplete` bool.
- Manual-entry doc_id: `{property_id}__{unit_id}__{year}[__mm]` for a unit; unchanged `{property_id}__{year}[__mm]` when `unit_id` is null. Engine synthetic loan-doc doc_id: `manual__{property}__{unit_id}__{period}` for a unit; unchanged `manual__{property}__{period}` when null. Exemption doc_id: `{property_id}__{unit_id}`.
- Ownership validated against the property's `landlordId` on every write.
- Branch: `feat/finance-tab-restructure`. Work in place.

---

### Task 1: Engine — attribute a manual loan entry to its unit

**Files:**
- Modify: `backend/rag/finance_engine.py` (`_manual_loan_documents`, lines 840-872)
- Test: `backend/tests/test_finance_engine.py` (add to `ManualLoanEntryEngineTests`)

**Interfaces:**
- Consumes: existing loan branch + unit routing (`lines_by_unit`).
- Produces: `_manual_loan_documents` reads `entry["unit_id"]` and emits a unit-scoped synthetic doc + doc_id.

- [ ] **Step 1: Write the failing tests**

Add to `ManualLoanEntryEngineTests` in `test_finance_engine.py`:

```python
    def test_entry_lands_in_its_units_contribution(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "Block")],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        units = {u["unit_id"]: u for u in summary["properties"][0]["units"]}
        # u1's statutory contribution is reduced by the 5000 deductible interest; u2 untouched.
        u1_loan = [l for l in units["u1"]["expense_lines"] if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in u1_loan), 5000.0)
        self.assertTrue(all(l["unit_id"] == "u1" for l in u1_loan))
        u2_loan = [l for l in units["u2"]["expense_lines"] if l["subtype"] == "interest_statement"]
        self.assertEqual(u2_loan, [])

    def test_two_units_same_period_amount_stay_distinct(self):
        summary = _summary(
            documents=[],
            properties=[_prop("p1", "Block")],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
                {"property_id": "p1", "unit_id": "u2", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        interest = [l for l in summary["properties"][0]["expense_lines"]
                    if l["subtype"] == "interest_statement"]
        self.assertEqual(sum(l["amount"] for l in interest), 2000.0)
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_finance_engine.py::ManualLoanEntryEngineTests -q`
Expected: FAIL — both units' figures collapse / land at property level (`unit_id` is hard-coded `None`).

- [ ] **Step 3: Implement**

In `_manual_loan_documents`, replace the period/doc_id/unit block. Change the `period` line and the appended dict:

```python
        month = entry.get("month")
        period = f"{year}-{int(month):02d}" if month else str(year)
        unit_id = entry.get("unit_id")
        unit_seg = f"{unit_id}__" if unit_id else ""
        facts: Dict[str, Any] = {"subtype": "interest_statement", "period_year": year}
        interest = _amount(entry, "interest_paid")
        principal = _amount(entry, "principal_paid")
        if interest is not None and interest > 0:
            facts["interest_paid"] = interest
        if principal is not None and principal > 0:
            facts["principal_paid"] = principal
        docs.append({
            "doc_id": f"manual__{entry.get('property_id')}__{unit_seg}{period}",
            "property_id": entry.get("property_id"),
            "unit_id": unit_id,
            "unit_label": None,
            "category": "loan",
            "extracted_facts": facts,
            "uploaded_at": None,
        })
```

(Update the docstring's doc_id example to `manual__{property}__{unit_id}__{period}`.)

- [ ] **Step 4: Run to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_finance_engine.py -q`
Expected: PASS (new tests + all existing engine tests, including the whole-property `unit_id=None` cases from the prior feature).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat: attribute manual loan entries to their unit"
```

---

### Task 2: Service — unit_id on manual entries + expose loan prefs

**Files:**
- Modify: `backend/rag/documind_service.py` (`_manual_loan_entry_doc_id`, `record_manual_loan_entry`, `delete_manual_loan_entry`, `list_manual_loan_entries`, and `_list_landlord_properties` at lines 497-505)
- Modify: `backend/tests/test_documind_service_flows.py` (add unit_id cases to `ManualLoanEntryServiceTests`)

**Interfaces:**
- Produces: `record_manual_loan_entry(..., unit_id=None)`, `delete_manual_loan_entry(..., unit_id=None)`, `list_manual_loan_entries` entries carry `unit_id`; `_list_landlord_properties` rows carry `loan_input_cadence`/`loan_input_method`.

- [ ] **Step 1: Write the failing tests**

Add to `ManualLoanEntryServiceTests`:

```python
    async def test_unit_scoped_entry_keys_by_unit(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", unit_id="u1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )

        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__u1__2025")
        self.assertEqual(fake_db.manual_loan_entries[0]["unit_id"], "u1")

    async def test_whole_property_entry_keeps_legacy_key(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))

        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )

        self.assertEqual(fake_db.manual_loan_entries[0]["doc_id"], "p1__2025")
        self.assertIsNone(fake_db.manual_loan_entries[0]["unit_id"])

    async def test_list_returns_unit_id(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        await service.record_manual_loan_entry(
            landlord_id="l1", property_id="p1", unit_id="u1", year=2025, cadence="annual",
            interest_paid=5000.0, principal_paid=0.0,
        )

        entries = service.list_manual_loan_entries("l1", "p1", 2025)

        self.assertEqual(entries[0]["unit_id"], "u1")
```

Also add a `_list_landlord_properties` test near `FinanceSummaryServiceTests` (or a new small test); mirror how other `_list_landlord_properties` fields are asserted — set `fake_db.properties_rows = [{"doc_id":"p1","landlordId":"l1","name":"H","loan_input_cadence":"monthly","loan_input_method":"manual"}]` and assert the returned dict carries both keys. If no direct test of `_list_landlord_properties` exists, assert via a `get_finance_summary` path is unnecessary — a focused unit test is fine:

```python
    async def test_list_landlord_properties_exposes_loan_prefs(self):
        fake_db = _FakeDB()
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "H",
             "loan_input_cadence": "monthly", "loan_input_method": "manual"},
        ]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_landlord_properties("l1")
        self.assertEqual(rows[0]["loan_input_cadence"], "monthly")
        self.assertEqual(rows[0]["loan_input_method"], "manual")
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_documind_service_flows.py::ManualLoanEntryServiceTests -q`
Expected: FAIL — `record_manual_loan_entry` has no `unit_id` kwarg / doc_id lacks the unit segment / prefs absent.

- [ ] **Step 3: Implement**

In `documind_service.py`:

`_manual_loan_entry_doc_id` gains unit_id:

```python
    def _manual_loan_entry_doc_id(self, property_id: str, unit_id: Optional[str], year: int, month: Optional[int]) -> str:
        unit_seg = f"{unit_id}__" if unit_id else ""
        if month is not None:
            return f"{property_id}__{unit_seg}{year}__{int(month):02d}"
        return f"{property_id}__{unit_seg}{year}"
```

`record_manual_loan_entry` signature adds `unit_id: Optional[str] = None` (after `property_id`), passes it to the doc_id, and stores `'unit_id': unit_id` in the record and the return dict. `delete_manual_loan_entry` adds `unit_id: Optional[str] = None` and passes it to the doc_id. `list_manual_loan_entries` adds `"unit_id": data.get("unit_id")` to each returned dict.

`_list_landlord_properties` results.append block (lines 497-505) adds:

```python
                    "loan_input_cadence": data.get('loan_input_cadence'),
                    "loan_input_method": data.get('loan_input_method'),
```

- [ ] **Step 4: Run to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_documind_service_flows.py -q`
Expected: PASS (all; the documented embedding failure does not surface under `-q`).

- [ ] **Step 5: Commit**

```bash
git add backend/rag/documind_service.py backend/tests/test_documind_service_flows.py
git commit -m "feat: unit_id on manual loan entries; expose loan prefs to the engine"
```

---

### Task 3: API — unit_id on the manual-entry endpoints

**Files:**
- Modify: `backend/models/documind_models.py` (`ManualLoanEntryRequest`, `ManualLoanEntryResponse` — add `unit_id`)
- Modify: `backend/api/rex_routes.py` (PUT forwards `unit_id`; DELETE gains a `unit_id` Query param)
- Test: `backend/tests/test_rex_routes_finance_api.py`

**Interfaces:** Consumes Task 2's service kwargs. Produces the `unit_id` field on the wire.

- [ ] **Step 1: Write the failing tests**

Add to `test_rex_routes_finance_api.py`:

```python
    def test_record_manual_loan_entry_forwards_unit_id(self):
        with patch(
            "api.rex_routes.documind_service.record_manual_loan_entry",
            new=AsyncMock(return_value={
                "property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                "interest_paid": 5000.0, "principal_paid": 0.0, "cadence": "annual",
            }),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/manual-loan-entry",
                json={"landlord_id": "l1", "property_id": "p1", "unit_id": "u1", "year": 2025,
                      "cadence": "annual", "interest_paid": 5000.0, "principal_paid": 0.0},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["unit_id"], "u1")
        self.assertEqual(response.json()["unit_id"], "u1")

    def test_delete_manual_loan_entry_forwards_unit_id(self):
        with patch(
            "api.rex_routes.documind_service.delete_manual_loan_entry",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/manual-loan-entry",
                params={"landlord_id": "l1", "property_id": "p1", "unit_id": "u1", "year": 2025},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["unit_id"], "u1")
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_rex_routes_finance_api.py -q -k manual_loan`
Expected: FAIL — `unit_id` not forwarded / not on the response model.

- [ ] **Step 3: Implement**

In `documind_models.py`, `ManualLoanEntryRequest` adds `unit_id: Optional[str] = None` (after `property_id`); `ManualLoanEntryResponse` adds `unit_id: Optional[str] = None`.

In `rex_routes.py`, the PUT route adds `unit_id=payload.unit_id,` to the `record_manual_loan_entry(...)` call. The DELETE route adds a param `unit_id: str | None = Query(None, description="Unit ID; omit for a whole-property entry")` and passes `unit_id=unit_id,` to `delete_manual_loan_entry(...)`.

- [ ] **Step 4: Run to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_rex_routes_finance_api.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/models/documind_models.py backend/api/rex_routes.py backend/tests/test_rex_routes_finance_api.py
git commit -m "feat: unit_id on the manual-loan-entry API"
```

---

### Task 4: Backend — unit-loan exemption ("No loan here")

**Files:**
- Modify: `backend/rag/documind_service.py` (`_unit_loan_exemption_doc_id`, `set_unit_loan_exemption`, `clear_unit_loan_exemption`, read in `get_finance_summary`)
- Modify: `backend/models/documind_models.py` (`UnitLoanExemptionRequest`)
- Modify: `backend/api/rex_routes.py` (PUT/DELETE `/documind/finance/unit-loan-exemption`; import the model)
- Modify: `backend/tests/test_documind_service_flows.py` (fake-DB wiring + `UnitLoanExemptionServiceTests`)
- Modify: `backend/tests/test_rex_routes_finance_api.py` (route tests)

**Interfaces:**
- Produces: `set_unit_loan_exemption(*, landlord_id, property_id, unit_id)`, `clear_unit_loan_exemption(*, landlord_id, property_id, unit_id)`; `get_finance_summary` passes `unit_loan_exemptions=[{property_id, unit_id}, …]` to `compute_finance_summary` (Task 5 consumes it).

- [ ] **Step 1: Write the failing tests**

Fake-DB wiring in `test_documind_service_flows.py`, mirroring `_FakeManualLoanEntryRef`: add a `_FakeUnitLoanExemptionRef` class (identical body, backed by `self._db.unit_loan_exemptions`), a `stream()` branch `elif self._name == "documind_unit_loan_exemptions": rows = self._db.unit_loan_exemptions`, a `document()` branch `if self._name == "documind_unit_loan_exemptions": return _FakeUnitLoanExemptionRef(self._db, _doc_id)`, and `self.unit_loan_exemptions = unit_loan_exemptions or []` + the `unit_loan_exemptions=None` ctor arg in `_FakeDB.__init__`.

Then:

```python
class UnitLoanExemptionServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_set_stores_the_mark(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        result = await service.set_unit_loan_exemption(landlord_id="l1", property_id="p1", unit_id="u1")
        self.assertEqual(result, {"property_id": "p1", "unit_id": "u1"})
        self.assertEqual(fake_db.unit_loan_exemptions[0]["doc_id"], "p1__u1")

    async def test_set_rejects_wrong_owner(self):
        fake_db = _FakeDB(property_owners={"p1": "someone-else"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        with self.assertRaises(ValueError):
            await service.set_unit_loan_exemption(landlord_id="l1", property_id="p1", unit_id="u1")
        self.assertEqual(fake_db.unit_loan_exemptions, [])

    async def test_clear_is_idempotent(self):
        fake_db = _FakeDB(property_owners={"p1": "l1"})
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        result = await service.clear_unit_loan_exemption(landlord_id="l1", property_id="p1", unit_id="u1")
        self.assertEqual(result, {"property_id": "p1", "unit_id": "u1"})
        self.assertEqual(fake_db.unit_loan_exemptions, [])
```

Route tests in `test_rex_routes_finance_api.py`:

```python
    def test_set_unit_loan_exemption_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.set_unit_loan_exemption",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": "u1"}),
        ) as mocked:
            response = self.client.put(
                "/api/rex/documind/finance/unit-loan-exemption",
                json={"landlord_id": "l1", "property_id": "p1", "unit_id": "u1"},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["unit_id"], "u1")

    def test_clear_unit_loan_exemption_returns_200(self):
        with patch(
            "api.rex_routes.documind_service.clear_unit_loan_exemption",
            new=AsyncMock(return_value={"property_id": "p1", "unit_id": "u1"}),
        ) as mocked:
            response = self.client.delete(
                "/api/rex/documind/finance/unit-loan-exemption",
                params={"landlord_id": "l1", "property_id": "p1", "unit_id": "u1"},
            )
            kwargs = mocked.await_args.kwargs
        self.assertEqual(response.status_code, 200)
        self.assertEqual(kwargs["property_id"], "p1")
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_documind_service_flows.py::UnitLoanExemptionServiceTests tests/test_rex_routes_finance_api.py -q -k "exemption or unit_loan"`
Expected: FAIL — methods/routes undefined.

- [ ] **Step 3: Implement the service**

In `documind_service.py`, after `clear_manual_loan_entry`/near the manual-entry methods:

```python
    def _unit_loan_exemption_doc_id(self, property_id: str, unit_id: str) -> str:
        return f"{property_id}__{unit_id}"

    async def set_unit_loan_exemption(
        self, *, landlord_id: str, property_id: str, unit_id: str,
    ) -> Dict[str, Any]:
        """Record that a unit has no loan, so it stops being expected in the
        loan-figure completeness check. Ownership-validated; idempotent."""
        property_ref = self.db.collection('properties').document(property_id)
        property_snapshot = property_ref.get()
        if not property_snapshot.exists or (property_snapshot.to_dict() or {}).get('landlordId') != landlord_id:
            raise ValueError(f"Property {property_id} not found for landlord {landlord_id}")
        doc_id = self._unit_loan_exemption_doc_id(property_id, unit_id)
        ref = self.db.collection('documind_unit_loan_exemptions').document(doc_id)
        ref.set({
            'landlord_id': landlord_id,
            'property_id': property_id,
            'unit_id': unit_id,
            'marked_at': firestore.SERVER_TIMESTAMP,
        })
        return {"property_id": property_id, "unit_id": unit_id}

    async def clear_unit_loan_exemption(
        self, *, landlord_id: str, property_id: str, unit_id: str,
    ) -> Dict[str, Any]:
        """Remove a unit's no-loan mark. Idempotent."""
        doc_id = self._unit_loan_exemption_doc_id(property_id, unit_id)
        ref = self.db.collection('documind_unit_loan_exemptions').document(doc_id)
        snapshot = ref.get()
        if snapshot.exists and (snapshot.to_dict() or {}).get("landlord_id") == landlord_id:
            ref.delete()
        return {"property_id": property_id, "unit_id": unit_id}
```

In `get_finance_summary`, after the `manual_loan_entries` read loop, add:

```python
        unit_loan_exemptions = []
        exemption_query = self.db.collection('documind_unit_loan_exemptions').where(
            filter=FieldFilter('landlord_id', '==', landlord_id)
        )
        for snap in exemption_query.stream():
            data = snap.to_dict() or {}
            unit_loan_exemptions.append({
                "property_id": data.get("property_id"),
                "unit_id": data.get("unit_id"),
            })
```

and pass `unit_loan_exemptions=unit_loan_exemptions,` into `compute_finance_summary(...)` (the param is added in Task 5; until then this kwarg would error — so **Task 4 adds the param with a default in `compute_finance_summary` as a no-op stub** to keep the suite green, and Task 5 gives it behavior). Add to `compute_finance_summary`'s signature now: `unit_loan_exemptions: Optional[List[Dict[str, Any]]] = None,`.

- [ ] **Step 4: Implement the models + routes**

`documind_models.py`:

```python
class UnitLoanExemptionRequest(BaseModel):
    landlord_id: str
    property_id: str
    unit_id: str = Field(..., min_length=1)
```

`rex_routes.py` — add `UnitLoanExemptionRequest` to the import, then:

```python
@router.put("/documind/finance/unit-loan-exemption")
async def set_unit_loan_exemption(payload: UnitLoanExemptionRequest):
    """Mark a unit as having no loan (excludes it from the loan-figure
    completeness check). Idempotent."""
    try:
        return await documind_service.set_unit_loan_exemption(
            landlord_id=payload.landlord_id, property_id=payload.property_id, unit_id=payload.unit_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/documind/finance/unit-loan-exemption")
async def clear_unit_loan_exemption(
    landlord_id: str = Query(..., description="Landlord ID for ownership verification"),
    property_id: str = Query(..., description="Property ID"),
    unit_id: str = Query(..., description="Unit ID"),
):
    """Remove a unit's no-loan mark. Idempotent."""
    return await documind_service.clear_unit_loan_exemption(
        landlord_id=landlord_id, property_id=property_id, unit_id=unit_id,
    )
```

- [ ] **Step 5: Run to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_documind_service_flows.py tests/test_rex_routes_finance_api.py -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/documind_service.py backend/models/documind_models.py backend/api/rex_routes.py backend/tests/test_documind_service_flows.py backend/tests/test_rex_routes_finance_api.py
git commit -m "feat: unit-loan exemption record + endpoints"
```

---

### Task 5: Engine — per-unit loan completeness + status

**Files:**
- Modify: `backend/rag/finance_engine.py` (add `_loan_completeness` helper; use `unit_loan_exemptions`; set `loan_status` on unit blocks and `manual_loan_incomplete` on property blocks)
- Modify: `backend/models/documind_models.py` (`UnitFinance.loan_status`, `PropertyFinance.manual_loan_incomplete`)
- Test: `backend/tests/test_finance_engine.py` (new `LoanCompletenessTests`)

**Interfaces:**
- Consumes: `unit_loan_exemptions` (Task 4), property prefs `loan_input_cadence`/`loan_input_method`/`has_mortgage` (Task 2).
- Produces: `manual_loan_incomplete: bool` per property block; `loan_status: Optional[str]` per unit block.

- [ ] **Step 1: Write the failing tests**

```python
class LoanCompletenessTests(unittest.TestCase):
    def _prop_manual(self, cadence="annual"):
        return {"property_id": "p1", "name": "Block", "ownership_share": 1.0,
                "has_mortgage": True, "loan_input_method": "manual",
                "loan_input_cadence": cadence}

    def test_incomplete_when_a_unit_has_no_figures(self):
        summary = _summary(
            documents=[], properties=[self._prop_manual()],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
        )
        block = summary["properties"][0]
        self.assertTrue(block["manual_loan_incomplete"])
        status = {u["unit_id"]: u["loan_status"] for u in block["units"]}
        self.assertEqual(status["u1"], "complete")
        self.assertEqual(status["u2"], "incomplete")

    def test_complete_when_every_unit_resolved(self):
        summary = _summary(
            documents=[], properties=[self._prop_manual()],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}, {"unit_id": "u2", "label": "A-2"}]},
            manual_loan_entries=[
                {"property_id": "p1", "unit_id": "u1", "year": 2025, "month": None,
                 "interest_paid": 1000.0, "principal_paid": 0.0, "cadence": "annual"},
            ],
            unit_loan_exemptions=[{"property_id": "p1", "unit_id": "u2"}],
        )
        block = summary["properties"][0]
        self.assertFalse(block["manual_loan_incomplete"])
        status = {u["unit_id"]: u["loan_status"] for u in block["units"]}
        self.assertEqual(status["u2"], "no_loan")

    def test_monthly_cadence_needs_all_in_scope_months(self):
        # Past year 2024 (today defaults to 2026-07-16): all 12 months required.
        entries = [{"property_id": "p1", "unit_id": "u1", "year": 2024, "month": m,
                    "interest_paid": 100.0, "principal_paid": 0.0, "cadence": "monthly"}
                   for m in range(1, 12)]  # only 11 of 12
        summary = _summary(
            documents=[], properties=[self._prop_manual("monthly")], year=2024,
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
            manual_loan_entries=entries,
        )
        self.assertTrue(summary["properties"][0]["manual_loan_incomplete"])

    def test_not_evaluated_for_upload_method(self):
        prop = self._prop_manual()
        prop["loan_input_method"] = "upload"
        summary = _summary(
            documents=[], properties=[prop],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
        )
        block = summary["properties"][0]
        self.assertFalse(block["manual_loan_incomplete"])
        self.assertIsNone(block["units"][0]["loan_status"])
```

Extend the `_summary` helper (line 52) to forward `unit_loan_exemptions=None`.

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_finance_engine.py::LoanCompletenessTests -q`
Expected: FAIL — `unit_loan_exemptions` kwarg / `manual_loan_incomplete` / `loan_status` absent.

- [ ] **Step 3: Implement the helper**

Add near `_manual_loan_documents`:

```python
def _loan_completeness(
    prop: Dict[str, Any],
    units: List[Dict[str, Any]],
    prop_docs: List[Dict[str, Any]],
    manual_entries: List[Dict[str, Any]],
    exemptions: List[Dict[str, Any]],
    year: int,
    months: List[int],
) -> tuple:
    """Per-unit loan resolution for the manual-entry button gate. A unit is
    resolved when it is marked no-loan, has an uploaded loan statement for the
    year, or has manual figures covering the cadence (annual: any entry;
    monthly: every in-scope month). Only meaningful for a mortgaged property on
    the manual method — otherwise returns (False, {})."""
    if prop.get("has_mortgage") is not True or prop.get("loan_input_method") != "manual":
        return False, {}
    cadence = prop.get("loan_input_cadence") or "annual"
    exempt_units = {e.get("unit_id") for e in exemptions}
    months_by_unit: Dict[Optional[str], set] = {}
    any_by_unit: set = set()
    for e in manual_entries:
        if e.get("year") != year:
            continue
        uid = e.get("unit_id")
        any_by_unit.add(uid)
        m = e.get("month")
        if m is not None:
            months_by_unit.setdefault(uid, set()).add(int(m))
    upload_units: set = set()
    for d in prop_docs:
        facts = d.get("extracted_facts")
        if d.get("category") == "loan" and isinstance(facts, dict) \
                and facts.get("period_year") == year \
                and not str(d.get("doc_id") or "").startswith("manual__"):
            upload_units.add(d.get("unit_id"))

    def resolved(uid):
        if uid in exempt_units or uid in upload_units:
            return True
        if cadence == "monthly":
            return set(months) <= months_by_unit.get(uid, set())
        return uid in any_by_unit

    status_by_unit: Dict[Optional[str], str] = {}
    incomplete = False
    if units:
        for u in units:
            uid = u["unit_id"]
            if uid in exempt_units:
                status_by_unit[uid] = "no_loan"
            elif resolved(uid):
                status_by_unit[uid] = "complete"
            else:
                status_by_unit[uid] = "incomplete"
                incomplete = True
    else:
        incomplete = not resolved(None)
    return incomplete, status_by_unit
```

- [ ] **Step 4: Wire it into `compute_finance_summary`**

Inside the `for prop in properties:` loop, after `expense_lines` is built and before/around unit-block assembly, compute:

```python
        prop_manual_entries = [
            e for e in (manual_loan_entries or [])
            if isinstance(e, dict) and e.get("property_id") == pid
        ]
        prop_exemptions = [
            x for x in (unit_loan_exemptions or [])
            if isinstance(x, dict) and x.get("property_id") == pid
        ]
        manual_loan_incomplete, loan_status_by_unit = _loan_completeness(
            prop, units_by_property.get(pid, []), prop_docs,
            prop_manual_entries, prop_exemptions, year, months,
        )
```

In the unit-block dict (the `unit_blocks.append({...})` near line 948), add:

```python
                "loan_status": loan_status_by_unit.get(scope["unit_id"]),
```

In the property-block dict (`property_blocks.append({...})` near line 1076), add:

```python
            "manual_loan_incomplete": manual_loan_incomplete,
```

- [ ] **Step 5: Update the models**

`documind_models.py`: `UnitFinance` adds `loan_status: Optional[str] = None`; `PropertyFinance` adds `manual_loan_incomplete: bool = False`.

- [ ] **Step 6: Run to verify they pass**

Run: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest tests/test_finance_engine.py -q`
Expected: PASS (new class + all existing).

- [ ] **Step 7: Commit**

```bash
git add backend/rag/finance_engine.py backend/models/documind_models.py backend/tests/test_finance_engine.py
git commit -m "feat: per-unit loan completeness (loan_status + manual_loan_incomplete)"
```

---

### Task 6: Frontend data — unit_id, exemption actions, summary parsing

**Files:**
- Modify: `residex_app/lib/core/constants/api_constants.dart` (`documindUnitLoanExemption`)
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart` (`unitId` on record/delete manual entry; `setUnitLoanExemption`/`clearUnitLoanExemption`)
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (`unitId` on the manual-entry action providers; new exemption action providers)
- Modify: `residex_app/lib/features/landlord/data/models/finance_summary_model.dart` (parse `loan_status`, `manual_loan_incomplete`)
- Modify: `residex_app/lib/features/landlord/domain/entities/finance_summary.dart` (`UnitFinance.loanStatus`, `PropertyFinance.manualLoanIncomplete`)
- Test: `residex_app/test/features/landlord/manual_loan_entry_datasource_test.dart` (extend) + `residex_app/test/features/landlord/finance_summary_model_test.dart` (extend)

**Interfaces:** Consumes Task 3/4 endpoints + Task 5 fields. Produces `unitId`-aware datasource/providers and parsed `loanStatus`/`manualLoanIncomplete`.

- [ ] **Step 1: Write the failing tests**

In `manual_loan_entry_datasource_test.dart`, add a test that `recordManualLoanEntry(..., unitId: 'u1')` puts `'unit_id': 'u1'` in the body, and that `setUnitLoanExemption` PUTs to `.../unit-loan-exemption` with `{landlord_id, property_id, unit_id}`. Mirror the existing `MockClient` harness.

In `finance_summary_model_test.dart`, add assertions that a unit JSON with `"loan_status": "no_loan"` parses to `unit.loanStatus == 'no_loan'`, and a property JSON with `"manual_loan_incomplete": true` parses to `block.manualLoanIncomplete == true` (and defaults to false/null when absent). Mirror the file's existing fixture-building style.

- [ ] **Step 2: Run to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_datasource_test.dart test/features/landlord/finance_summary_model_test.dart`
Expected: FAIL — `unitId` param / `setUnitLoanExemption` / `loanStatus` / `manualLoanIncomplete` undefined.

- [ ] **Step 3: Implement — constant + datasource**

`api_constants.dart` after `documindManualLoanEntry`:

```dart
  static const String documindUnitLoanExemption = '/api/rex/documind/finance/unit-loan-exemption';
```

`documind_remote_datasource.dart`: `recordManualLoanEntry` gains `String? unitId` and adds `if (unitId != null) 'unit_id': unitId,` to the JSON body; `deleteManualLoanEntry` gains `String? unitId` and adds `if (unitId != null) 'unit_id': unitId,` to the query params. Add:

```dart
  /// Mark a unit as having no loan (excludes it from loan-figure completeness).
  Future<void> setUnitLoanExemption({
    required String landlordId,
    required String propertyId,
    required String unitId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUnitLoanExemption}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'landlord_id': landlordId, 'property_id': propertyId, 'unit_id': unitId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark unit no-loan: ${response.body}');
    }
  }

  /// Remove a unit's no-loan mark. Idempotent.
  Future<void> clearUnitLoanExemption({
    required String landlordId,
    required String propertyId,
    required String unitId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUnitLoanExemption}')
        .replace(queryParameters: {
      'landlord_id': landlordId, 'property_id': propertyId, 'unit_id': unitId,
    });
    final response = await httpClient.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to clear unit no-loan mark: ${response.body}');
    }
  }
```

- [ ] **Step 4: Implement — providers**

`documind_provider.dart`: add `String? unitId` to the `recordManualLoanEntryActionProvider` and `deleteManualLoanEntryActionProvider` function types + bodies (pass `unitId: unitId` to the datasource). Add two providers mirroring them:

```dart
final setUnitLoanExemptionActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required String unitId,
})>((ref) {
  return ({required String propertyId, required String unitId}) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.setUnitLoanExemption(
      landlordId: landlordId, propertyId: propertyId, unitId: unitId,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

final clearUnitLoanExemptionActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required String unitId,
})>((ref) {
  return ({required String propertyId, required String unitId}) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.clearUnitLoanExemption(
      landlordId: landlordId, propertyId: propertyId, unitId: unitId,
    );
    ref.invalidate(financeSummaryProvider);
  };
});
```

- [ ] **Step 5: Implement — entity + parsing**

`finance_summary.dart`: `UnitFinance` adds `final String? loanStatus;` (constructor `this.loanStatus,`); `PropertyFinance` adds `final bool manualLoanIncomplete;` (constructor `this.manualLoanIncomplete = false,`).

`finance_summary_model.dart`: in `_unit(...)` add `loanStatus: json['loan_status'] as String?,`; in the `PropertyFinance(...)` return add `manualLoanIncomplete: json['manual_loan_incomplete'] as bool? ?? false,`.

- [ ] **Step 6: Run to verify they pass + analyze**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_datasource_test.dart test/features/landlord/finance_summary_model_test.dart`
Then: `cd residex_app && flutter analyze`
Expected: PASS; no new analyze issues.

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/core/constants/api_constants.dart residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart residex_app/lib/features/landlord/presentation/providers/documind_provider.dart residex_app/lib/features/landlord/data/models/finance_summary_model.dart residex_app/lib/features/landlord/domain/entities/finance_summary.dart residex_app/test/features/landlord/manual_loan_entry_datasource_test.dart residex_app/test/features/landlord/finance_summary_model_test.dart
git commit -m "feat: frontend data for per-unit loans + exemption + completeness fields"
```

---

### Task 7: Frontend UI — per-unit sheet + button gating

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart` (unit picker, per-unit Save, "No loan here"/Undo, unit-labeled entries)
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart` (pass units to the sheet; gate the button on `manualLoanIncomplete`)
- Test: `residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart` (extend) + `residex_app/test/features/landlord/finance_screen_test.dart` (extend)

**Interfaces:** Consumes Task 6 providers/fields. `ManualLoanEntrySheet` gains `List<UnitFinance> units`.

- [ ] **Step 1: Write the failing tests**

In `manual_loan_entry_sheet_test.dart`, keep the existing save test but pass `units: const []` (whole-property). Add a test: with `units: [UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 0, contribution: 0)]`, selecting unit "A-1" and saving forwards `unitId == 'u1'` to `recordManualLoanEntryActionProvider`; and tapping "No loan here" calls `setUnitLoanExemptionActionProvider` with `unitId == 'u1'`. Override both providers with capturing closures (mirror the existing override idiom).

In `finance_screen_test.dart`, extend the existing gate tests: the button is hidden when `manual_loan_incomplete` is false even with mortgage=Yes + method=manual, and shown when it is true. (Build the `FinanceSummary` with `manualLoanIncomplete` on the property block; keep the `propertyByIdProvider` override returning a mortgaged manual property.)

- [ ] **Step 2: Run to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_sheet_test.dart test/features/landlord/finance_screen_test.dart`
Expected: FAIL — `units` param / unit picker / gate-on-`manualLoanIncomplete` absent.

- [ ] **Step 3: Implement the sheet**

`ManualLoanEntrySheet` gains `final List<UnitFinance> units;` (required; empty = whole-property only). Add a selected-scope state `String? _selectedUnitId` (null = "Whole property"). At the top of the form, when `widget.units.isNotEmpty`, render a scope `DropdownButton<String?>` whose items are `"Whole property"` (value null) + each unit (`value: u.unitId, child: Text(u.label)`), bound to `_selectedUnitId`. `_save()` passes `unitId: _selectedUnitId`. `_remove(month)` passes `unitId: _selectedUnitId`.

Below the form, when a real unit is selected (`_selectedUnitId != null`), show its status + action: find `final u = widget.units.firstWhere((x) => x.unitId == _selectedUnitId)`; if `u.loanStatus == 'no_loan'` render a "No loan on this unit" chip + a `TextButton('Undo')` calling `clearUnitLoanExemptionActionProvider(propertyId:, unitId:)`; else a `TextButton.icon(Icons.block, 'No loan here')` calling `setUnitLoanExemptionActionProvider(propertyId:, unitId:)`. After either, the sheet stays open (the summary invalidation refreshes it via the provider).

In the recorded-entries list, label each row with its unit: prefix with the unit label when `entry['unit_id'] != null` (map from `widget.units`), else "Whole property". Filter the list to the selected scope so the landlord sees the entries for the unit they're editing. Keep numeric field keys `manual-loan-interest` / `manual-loan-principal`. No emojis; reuse `AppColors`/`AppTextStyles`/`formatRM`/`monthAbbrev`.

- [ ] **Step 4: Implement the finance-screen wiring**

In `finance_screen.dart` `_buildPropertyBlock`: change the gate (line ~319-320) to

```dart
    final property = ref.watch(propertyByIdProvider(block.propertyId)).value;
    final showManualLoan = block.manualLoanIncomplete &&
        property?.loanInputMethod == 'manual';
```

(`block.manualLoanIncomplete` is already false unless the backend saw mortgage=Yes + manual, so it is the authority; the `method` check keeps the sheet's cadence read meaningful.) In the `showModalBottomSheet` builder, pass `units: block.units.where((u) => u.unitId != null).toList()` to `ManualLoanEntrySheet`.

- [ ] **Step 5: Run to verify they pass + analyze + regression**

Run: `cd residex_app && flutter test test/features/landlord/manual_loan_entry_sheet_test.dart test/features/landlord/finance_screen_test.dart test/features/landlord/finance_screen_smoke_test.dart`
Then: `cd residex_app && flutter analyze`
Expected: PASS; no new issues.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat: per-unit manual loan sheet + gate button on completeness"
```

---

### Task 8: Loan document folder

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/providers/document_folders.dart` (`naturalFolderKey`, `proposedFolderName`)
- Test: `residex_app/test/features/landlord/document_folders_test.dart`

**Interfaces:** Produces a dedicated folder key for loan-category documents. Display-only — finance untouched.

- [ ] **Step 1: Write the failing test**

Add to `document_folders_test.dart` (mirror its `DocuMindDocument` fixture builder):

```dart
  test('a loan document gets its own Loan folder, not Expenses', () {
    final loanDoc = _doc(category: 'loan', tags: const []); // adjust to the file's fixture helper
    expect(naturalFolderKey(loanDoc), loanFolderKey);
    expect(proposedFolderName(loanFolderKey), 'Loan');
  });
```

(Use whatever `DocuMindDocument` constructor/fixture the existing tests use; the point is a `category: 'loan'` document with no periodic tags no longer maps to `untaggedFolderKey`/"Expenses".)

- [ ] **Step 2: Run to verify it fails**

Run: `cd residex_app && flutter test test/features/landlord/document_folders_test.dart`
Expected: FAIL — `loanFolderKey` undefined / loan doc still maps to `untaggedFolderKey`.

- [ ] **Step 3: Implement**

In `document_folders.dart`, add the sentinel and branch:

```dart
/// Sentinel folder key for loan-category documents, so they get their own
/// "Loan" folder instead of falling into the catch-all Expenses folder (their
/// tags are one-off, which otherwise yields no folder identity). Not a real
/// tag combination.
const String loanFolderKey = '__loan__';
```

At the top of `naturalFolderKey`, before the tag logic:

```dart
String naturalFolderKey(DocuMindDocument doc) {
  if (doc.category == 'loan') return loanFolderKey;
  final periodic = ...
```

In `proposedFolderName`, before the untagged check:

```dart
String proposedFolderName(String folderKey) {
  if (folderKey == loanFolderKey) return 'Loan';
  if (folderKey == untaggedFolderKey) return 'Expenses';
  ...
```

- [ ] **Step 4: Run to verify it passes + analyze**

Run: `cd residex_app && flutter test test/features/landlord/document_folders_test.dart`
Then: `cd residex_app && flutter analyze`
Expected: PASS; no new issues.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/providers/document_folders.dart residex_app/test/features/landlord/document_folders_test.dart
git commit -m "feat: loan documents get their own Loan folder"
```

---

## Final verification (after all tasks)

- Backend: `cd backend && PYTHONIOENCODING=utf-8 python -m pytest -q` → all pass (except the documented embedding test, which does not surface under `-q`).
- Frontend: `cd residex_app && flutter test test/features/landlord/` → all pass.
- `cd residex_app && flutter analyze` → no new issues.

## Self-Review notes (author)

- **Spec coverage:** Part A → Tasks 1-3; Part B → Tasks 4 (exemption), 5 (completeness), 6-7 (data + UI + gate); Part C → Task 8. Cadence-aware monthly completeness (Task 5 test). Whole-property backward-compat keys (Task 1/2). "app never recomputes" — completeness computed in the engine, read by the frontend.
- **Type consistency:** `unit_id` snake_case across datasource body/query (T6) → request/query params (T3/T4) → service kwargs (T2/T4) → engine entry/exemption dicts (T1/T5). `loan_status`/`manual_loan_incomplete` identical from engine (T5) → model (T5) → Dart parse (T6) → gate (T7). `ManualLoanEntrySheet.units: List<UnitFinance>` produced in T6, consumed in T7.
- **WIP isolation:** Tasks 2, 3, 4, 6 touch files that carry unrelated WIP — each task stages only its named files by path and diff-checks before commit.
- **Out of scope:** account numbers, amortization, per-unit `hasMortgage` field, upload-flow changes.
