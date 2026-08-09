# Document Share Basis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop halving figures that arrive already split — let a landlord say how their documents come, so ownership share is applied exactly once to every figure.

**Architecture:** Every figure the engine reads carries a *basis*: `full` (the document states the whole property's amount — today's assumption) or `mine` (it already states the landlord's portion). The basis is resolved per document from the document's own answer, then a per-category exception on the property, then the property's default, then `full`. Expenses inherit it through one clause in `_line_share`, which every existing call site already routes through; income needs its two running totals split into `full` and `mine` buckets so only the `full` part is scaled. The landlord answers once at registration, and confirms per-document on the expenses review sheet that already fires after an upload.

**Tech Stack:** Python 3.11 + pytest (`backend/`), FastAPI, Flutter/Dart + Riverpod (`residex_app/`), Firestore, Pydantic response models.

## Global Constraints

- **Source spec:** `docs/superpowers/specs/2026-08-09-document-share-basis-design.md`. Every design decision comes from there; do not re-litigate them.
- **This plan assumes both earlier plans are fully complete and committed:**
  - `docs/superpowers/plans/2026-08-09-unit-panel-share-reconciliation.md` — it built `gross_income` / `full_gross_income`, `_scaled_month_rows`, and the recovery exemption in `s_received`.
  - `docs/superpowers/plans/2026-08-09-unit-level-ownership-share.md` — it built `_share_for_unit`, the per-property `share_for(unit_id)` closure, `_scaled_lines` taking a **callable** second argument, the per-scope `scope_share`, and `Unit.ownershipShare`.

  This plan edits code both of those wrote. **If `share_for`, `scope_share`, `_scaled_month_rows` or `Unit.ownershipShare` do not exist, stop and report** — do not implement them here.
- **Never run `git add -A` on this branch.** An unrelated fact-aware-answering / citation-precision workstream is live and uncommitted in the working tree, including hunks inside `backend/rag/documind_service.py` and `backend/tests/test_documind_service_flows.py`. Every commit step below names its exact files; add only those. Task 4 edits `documind_service.py` — add that one file, never the directory.
- **Never touch** `backend/rexAI.txt` or `backend/scripts/{diagnose,fix}_ayer8_lease*.py`.
- `residex_app/test/widget_test.dart` — "Counter increments smoke test" is a **pre-existing boilerplate failure** and must never be fixed. Flutter runs are green at **1 failed**, that one.
- **Loan is never declarable.** `loan` is excluded from every category list, and `_LOAN_EXEMPT_SUBTYPES` keeps winning over basis: a loan line resolves to 1.0 at any basis and any share. A landlord must not be able to halve their own interest deduction by answering a question about statements.
- **`full` is the default everywhere, always.** Absent property fields, absent document field, unparseable values — all resolve to `full`, which is exactly what the engine assumes today. **No figure moves on the day this ships and there is no migration.**
- **Firestore field naming:** `share_basis_default`, `share_basis_exceptions` (on the property) and `share_basis` (on the document) are **snake_case**, matching `ownership_share` / `utilities_paid_by` inside those otherwise camelCase collections. The backend reads the snake_case keys. Renaming them to camelCase breaks every calculation with a fully green Dart suite.
- **Test-fixture rule, from the spec:** a fixture at `ownership_share == 1.0` **cannot fail** against any part of this — basis never affects a share of 1.0, because scaling by 1.0 is identity either way. **Every new backend test below sets a partial share.**
- Backend suite: `cd backend && py -3.11 -m pytest tests/ -q` → **0 failed**.
- Flutter suite: `cd residex_app && flutter test` → **1 failed** (the boilerplate one above).
- Analyzer: `cd residex_app && flutter analyze` → **0 errors** (warnings/infos are pre-existing and fine).

## File Structure

| File | Responsibility in this plan |
| --- | --- |
| `backend/rag/property_directory.py` | Reads the property's stored default + exceptions out of Firestore (Task 1) |
| `backend/rag/finance/finance_engine.py` | Basis resolution, the `mine` clause in `_line_share`, expense lines stamped with their basis, income split into `full`/`mine` buckets (Tasks 2–3) |
| `backend/rag/documind_service.py` | Loads each document's own `share_basis` into the fold (Task 4) |
| `backend/rag/documents/document_lifecycle_service.py` | Writes a document's `share_basis` (Task 7) |
| `backend/models/documind_models.py` + `backend/api/rex_routes.py` | The PATCH endpoint's request/response and route (Task 7) |
| `residex_app/.../domain/entities/property.dart` + `data/models/property_model.dart` | The two stored property fields, Dart side (Task 5) |
| `residex_app/.../domain/share_basis.dart` | **New.** The §3a predicate and the resolution order, as pure functions used by both UI surfaces (Task 6) |
| `residex_app/.../widgets/common/add_property_dialog.dart` | The registration / edit question (Task 6) |
| `residex_app/.../widgets/common/expense_lines_review_sheet.dart` | The per-document chip (Task 8) |

---

### Task 1: The property's stored answer reaches the engine

Nothing computes yet. `list_landlord_properties` builds the property dicts the engine folds over, and it currently throws away anything it doesn't name — so the two new fields would be invisible to the engine even once the app writes them.

**Files:**
- Modify: `backend/rag/property_directory.py:41-72` (`list_landlord_properties`)
- Test: `backend/tests/test_documind_service_flows.py` (append a test class)

**Interfaces:**
- Consumes: nothing.
- Produces: each dict returned by `list_landlord_properties` gains
  - `"share_basis_default": Optional[str]` — `'full'` or `'mine'`, `None` when absent or not one of those two.
  - `"share_basis_exceptions": Dict[str, str]` — category → basis, `{}` when absent or malformed. Only entries whose value is `'full'` or `'mine'` survive.

  Task 2 reads both off `prop` inside the property loop.

> **Sanitise on read, not on use.** Every consumer of these fields is a comparison against the string `'mine'`, so a junk value would silently read as `full` — the safe direction, but it would also survive into `share_basis_exceptions` and confuse anyone reading the stored document. Filtering here means the engine only ever sees the two legal values, and `_document_share_basis` in Task 2 still defends itself anyway.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_documind_service_flows.py`, at the end of the file:

```python
class PropertyShareBasisLookupTests(unittest.IsolatedAsyncioTestCase):
    """The property's basis answers have to survive the Firestore read. A
    property that never answered reads as None / {} — which the engine
    resolves to 'full', today's behaviour."""

    def _rows(self, extra):
        fake_db = _FakeDB()
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Block", **extra},
        ]
        service = _build_service(fake_db, _FakeConversationStore(),
                                 _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        return service._list_landlord_properties("l1")

    async def test_stored_default_and_exceptions_are_returned(self):
        rows = self._rows({
            "share_basis_default": "mine",
            "share_basis_exceptions": {"tax": "full"},
        })
        self.assertEqual(rows[0]["share_basis_default"], "mine")
        self.assertEqual(rows[0]["share_basis_exceptions"], {"tax": "full"})

    async def test_absent_fields_read_as_none_and_empty(self):
        rows = self._rows({})
        self.assertIsNone(rows[0]["share_basis_default"])
        self.assertEqual(rows[0]["share_basis_exceptions"], {})

    async def test_an_unknown_default_is_dropped(self):
        rows = self._rows({"share_basis_default": "sometimes"})
        self.assertIsNone(rows[0]["share_basis_default"])

    async def test_unknown_exception_values_are_dropped_individually(self):
        rows = self._rows({
            "share_basis_exceptions": {"tax": "full", "upkeep": "maybe"},
        })
        self.assertEqual(rows[0]["share_basis_exceptions"], {"tax": "full"})

    async def test_a_non_map_exceptions_field_reads_as_empty(self):
        rows = self._rows({"share_basis_exceptions": ["tax"]})
        self.assertEqual(rows[0]["share_basis_exceptions"], {})

    async def test_the_existing_fields_still_come_back(self):
        # A guard: the new keys are added to a dict several other features
        # read, and dropping one of those would be silent here.
        rows = self._rows({"ownership_share": 0.5, "utilities_paid_by": "landlord"})
        self.assertEqual(rows[0]["ownership_share"], 0.5)
        self.assertEqual(rows[0]["utilities_paid_by"], "landlord")
        self.assertEqual(rows[0]["name"], "Block")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::PropertyShareBasisLookupTests -v`
Expected: FAIL — `KeyError: 'share_basis_default'` on the first five; `test_the_existing_fields_still_come_back` passes already (it is a guard).

- [ ] **Step 3: Read the fields**

In `backend/rag/property_directory.py`, add above `list_landlord_properties`:

```python
_SHARE_BASES = ("full", "mine")
```

Then, inside `list_landlord_properties`'s `for snap in snapshots:` loop, after the `share` parsing and before `results.append(...)`:

```python
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
```

and add the two keys to the appended dict, after `"ownership_share": share,`:

```python
                "share_basis_default": basis_default,
                "share_basis_exceptions": basis_exceptions,
```

Update the docstring's first line to name them:

```python
    """Property ids/names/ownership shares/document-basis answers for a
    landlord. The properties collection is Flutter-owned (field 'landlordId');
    ownership_share is optional and defaults to 1.0. share_basis_default is
    None and share_basis_exceptions is {} unless the landlord answered — both
    resolve to 'full', which is what the engine has always assumed. Empty on
    lookup failure."""
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::PropertyShareBasisLookupTests -v`
Expected: PASS, 6 tests.

- [ ] **Step 5: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** The property dicts also flow into the ask/chat path; nothing there enumerates keys. If something breaks on an extra key, stop and report rather than removing the key.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/property_directory.py backend/tests/test_documind_service_flows.py
git commit -m "feat(finance): read the property's document share basis answers"
```

---

### Task 2: Basis resolution, and every expense line carries its own

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` — new helpers beside `_LOAN_EXEMPT_SUBTYPES`; `_line_share`; `_expense_lines` and its one call site; `_scaled_lines`
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `prop["share_basis_default"]` / `prop["share_basis_exceptions"]` from Task 1, and `doc["share_basis"]` (Task 4 loads it; the engine tolerates its absence).
- Produces:
  - `_document_share_basis(doc: Dict[str, Any], prop: Dict[str, Any]) -> str` — always `'full'` or `'mine'`.
  - `_basis_share(basis: Optional[str], share: float) -> float` — the share that applies to one figure. Task 3 reuses it.
  - `_expense_lines(prop_docs, year, utilities_paid_by=None, prop=None)` — one new trailing optional parameter.
  - Every dict `_expense_lines` emits carries `"share_basis": str`. It is **internal**: `_scaled_lines` strips it from everything the payload renders.

> **Why `_line_share` and not the call sites.** There are eight places that weigh an expense line by share. Putting the `mine` clause inside `_line_share` makes all eight correct with no further change — and makes it impossible for a ninth to be added later that forgets.

> **Deliberate: a bundled `expenses` document can only ever take the default or its own override.** Resolution step 2 keys the exception map on the *document's* category (spec §3), and `expenses` is not one of the six offered categories, so no exception can ever match a combined statement. That is the reason the per-document chip exists — a statement that mixes a pre-split strata charge with a whole-property quit rent is answered on the sheet, not by a category rule. Test 5 below pins it.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_finance_engine.py`:

```python
def _basis_doc(pid, category, facts, basis=None, **kwargs):
    """A document with an explicit per-document share basis. `None` leaves the
    field off entirely, which is how every stored document looks today."""
    doc = _doc(pid, category, facts, **kwargs)
    if basis is not None:
        doc["share_basis"] = basis
    return doc


def _basis_prop(pid, name, share=1.0, default=None, exceptions=None):
    prop = _prop(pid, name, share=share)
    if default is not None:
        prop["share_basis_default"] = default
    if exceptions is not None:
        prop["share_basis_exceptions"] = exceptions
    return prop


class DocumentShareBasisExpenseTests(unittest.TestCase):
    """A 'mine' document already states the landlord's portion, so scaling it
    again files a quarter of the truth at half ownership. Every fixture here
    is at share 0.5 — at 1.0 basis cannot change any figure, so a fixture at
    full ownership cannot fail against any of this."""

    def _lines_at(self, doc_basis=None, **prop_kwargs):
        docs = [
            _basis_doc("p1", "maintenance",
                       {"amount": 1000.0, "period_start": "2025-02-01"},
                       basis=doc_basis),
            _doc("p1", "upkeep", {"amount": 400.0, "service_date": "2025-03-04"}),
        ]
        result = _summary(docs, [_basis_prop("p1", "Block", share=0.5, **prop_kwargs)])
        block = result["properties"][0]
        by_category = {l["category"]: l for l in block["expense_lines"]}
        return result, block, by_category

    def test_a_mine_line_is_not_scaled_and_a_full_line_beside_it_is(self):
        _, _, by_category = self._lines_at(doc_basis="mine")
        self.assertAlmostEqual(by_category["maintenance"]["amount"], 1000.0, places=2)
        self.assertAlmostEqual(by_category["upkeep"]["amount"], 200.0, places=2)

    def test_a_mine_line_carries_no_full_amount(self):
        # Matching the loan-line rule: there is no second figure to show.
        _, _, by_category = self._lines_at(doc_basis="mine")
        self.assertNotIn("full_amount", by_category["maintenance"])
        self.assertAlmostEqual(by_category["upkeep"]["full_amount"], 400.0, places=2)

    def test_the_document_override_beats_a_category_exception(self):
        _, _, by_category = self._lines_at(
            doc_basis="mine", exceptions={"maintenance": "full"}, default="full")
        self.assertAlmostEqual(by_category["maintenance"]["amount"], 1000.0, places=2)

    def test_a_category_exception_beats_the_default(self):
        _, _, by_category = self._lines_at(
            exceptions={"maintenance": "mine"}, default="full")
        self.assertAlmostEqual(by_category["maintenance"]["amount"], 1000.0, places=2)
        self.assertAlmostEqual(by_category["upkeep"]["amount"], 200.0, places=2)

    def test_the_default_beats_nothing_at_all(self):
        _, _, by_category = self._lines_at(default="mine")
        self.assertAlmostEqual(by_category["maintenance"]["amount"], 1000.0, places=2)
        self.assertAlmostEqual(by_category["upkeep"]["amount"], 400.0, places=2)

    def test_no_answer_anywhere_resolves_to_full(self):
        _, _, by_category = self._lines_at()
        self.assertAlmostEqual(by_category["maintenance"]["amount"], 500.0, places=2)
        self.assertAlmostEqual(by_category["upkeep"]["amount"], 200.0, places=2)

    def test_a_bundled_expenses_statement_ignores_category_exceptions(self):
        # Its category is 'expenses', which is not one of the six offered, so
        # a maintenance exception cannot reach its maintenance line. The
        # per-document chip is what answers a combined statement.
        docs = [_basis_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "maintenance", "amount": 1000.0, "period_year": 2025},
        ]})]
        result = _summary(docs, [_basis_prop("p1", "Block", share=0.5,
                                             exceptions={"maintenance": "mine"})])
        line = result["properties"][0]["expense_lines"][0]
        self.assertAlmostEqual(line["amount"], 500.0, places=2)

    def test_a_bundled_statement_does_follow_its_own_override(self):
        docs = [_basis_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "maintenance", "amount": 1000.0, "period_year": 2025},
        ]}, basis="mine")]
        result = _summary(docs, [_basis_prop("p1", "Block", share=0.5)])
        line = result["properties"][0]["expense_lines"][0]
        self.assertAlmostEqual(line["amount"], 1000.0, places=2)

    def test_direct_expenses_reconciles_against_the_rendered_lines(self):
        # THE EXISTING RECONCILIATION GATE, under a mixed basis. `direct` sums
        # across every line at once; left unaware of basis it reads 700.00
        # while the lines beneath it read 1000 + 200.
        _, block, _ = self._lines_at(doc_basis="mine")
        deductible = [l for l in block["expense_lines"] if l["deductible"]]
        self.assertAlmostEqual(
            block["direct_expenses"], sum(l["amount"] for l in deductible), places=2)
        self.assertAlmostEqual(block["direct_expenses"], 1200.0, places=2)

    def test_expense_breakdown_reconciles_against_the_rendered_lines(self):
        result, block, _ = self._lines_at(doc_basis="mine")
        totals = {}
        for line in block["expense_lines"]:
            if line["deductible"]:
                totals[line["category"]] = round(
                    totals.get(line["category"], 0.0) + line["amount"], 2)
        self.assertEqual(result["expense_breakdown"], totals)

    def test_a_loan_document_is_unaffected_by_every_basis_setting(self):
        # Including a property whose default is 'mine'. The loan exemption
        # wins first: interest is the landlord's own borrowing, and basis is a
        # claim about what a statement shows, not about who owes the money.
        docs = [_basis_doc("p1", "loan",
                           {"subtype": "interest_statement", "period_year": 2025,
                            "interest_paid": 1200.0, "principal_paid": 3000.0},
                           basis="mine")]
        result = _summary(docs, [_basis_prop("p1", "Block", share=0.5, default="mine")])
        by_subtype = {l["subtype"]: l for l in result["properties"][0]["expense_lines"]}
        self.assertAlmostEqual(by_subtype["interest_statement"]["amount"], 1200.0, places=2)
        self.assertAlmostEqual(by_subtype["loan_principal"]["amount"], 3000.0, places=2)
        self.assertNotIn("full_amount", by_subtype["interest_statement"])

    def test_rendered_lines_never_carry_the_internal_basis_marker(self):
        # share_basis is engine bookkeeping. Leaking it would make a property
        # with a stored default differ from one without at share 1.0, where
        # every figure is identical — see the equivalence test in task 3.
        _, block, _ = self._lines_at(doc_basis="mine")
        for line in block["expense_lines"] + block["property_expense_lines"]:
            self.assertNotIn("share_basis", line)
        for unit in block["units"]:
            for line in unit["expense_lines"]:
                self.assertNotIn("share_basis", line)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::DocumentShareBasisExpenseTests -v`
Expected: FAIL — every `mine` figure reads at half (500.00 instead of 1000.00). `test_no_answer_anywhere_resolves_to_full`, `test_a_loan_document_is_unaffected_by_every_basis_setting` and `test_rendered_lines_never_carry_the_internal_basis_marker` should already pass; they are guards, not drivers.

- [ ] **Step 3: Add the two resolvers**

In `backend/rag/finance/finance_engine.py`, immediately **above** the `_LOAN_EXEMPT_SUBTYPES` comment block:

```python
# The two ways a document can state an amount. 'full' is what the engine has
# always assumed and is the default at every step of the resolution below, so
# a landlord who never answers sees no change.
_SHARE_BASES = ("full", "mine")


def _document_share_basis(doc: Dict[str, Any], prop: Dict[str, Any]) -> str:
    """Which basis applies to one document (spec §3), first match wins:

    1. the document's own `share_basis` (set from the upload review sheet)
    2. the property's exception for that document's category
    3. the property's default
    4. 'full'

    Step 2 keys on the *document's* category, so a bundled 'expenses'
    statement — whose category is not one of the six a landlord can except —
    only ever takes step 1 or step 3. That is deliberate: a combined statement
    can mix bases, and the per-document answer is how it gets corrected.
    """
    own = doc.get("share_basis")
    if own in _SHARE_BASES:
        return own
    exceptions = prop.get("share_basis_exceptions")
    if isinstance(exceptions, dict):
        by_category = exceptions.get(doc.get("category"))
        if by_category in _SHARE_BASES:
            return by_category
    default = prop.get("share_basis_default")
    return default if default in _SHARE_BASES else "full"


def _basis_share(basis: Optional[str], share: float) -> float:
    """The share that applies to one figure. A figure already stated at the
    landlord's portion is used verbatim; anything else is the whole
    property's and scales."""
    return 1.0 if basis == "mine" else share
```

- [ ] **Step 4: Teach `_line_share` about basis**

Replace `_line_share` entirely:

```python
def _line_share(line: Dict[str, Any], share: float) -> float:
    """Loan interest and principal are the landlord's own borrowing, not a
    cost shared with co-owners, so they are never scaled by ownership share —
    and that beats basis, because basis is a claim about what a statement
    shows, not about who owes the money. A line from a document declared
    'mine' already states the landlord's portion, so scaling it again would
    file a quarter of the truth at half ownership. Every other expense line
    scales normally."""
    if line.get("subtype") in _LOAN_EXEMPT_SUBTYPES:
        return 1.0
    return _basis_share(line.get("share_basis"), share)
```

- [ ] **Step 5: Stamp each line with its document's basis**

In `_expense_lines`, change the signature (`finance_engine.py:259-263`) to:

```python
def _expense_lines(
    prop_docs: List[Dict[str, Any]],
    year: int,
    utilities_paid_by: Optional[str] = None,
    prop: Optional[Dict[str, Any]] = None,
) -> List[Dict[str, Any]]:
```

and append to its docstring:

```
    Every emitted line carries `share_basis`, copied from its source document
    (see _document_share_basis). It is internal bookkeeping — _scaled_lines
    strips it from everything the payload renders.
```

Inside the `for doc in prop_docs:` loop, immediately after `category = doc.get("category")`:

```python
        basis = _document_share_basis(doc, prop or {})
```

Then add `"share_basis": basis,` to **all three** dicts appended in that function — the bundled `expenses` item line, the hardcoded `loan_principal` line, and the `entry` line at the end. Put it directly after each `"unit_id": doc.get("unit_id"),`.

> All three. The `loan_principal` line is exempt from scaling anyway, so a missed stamp there changes nothing today — which is exactly why it would sit wrong until something else made it matter.

Update the single call site in the property loop:

```python
        expense_lines = _dedup_expense_lines(
            _expense_lines(prop_docs, year, prop.get("utilities_paid_by"), prop)
        )
```

- [ ] **Step 6: Verify there is exactly one call site**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py -q`

Then grep `finance_engine.py` for `_expense_lines(`. It matches four lines — the `def` (`:259`), the `def _dedup_expense_lines` (`:383`), the `_dedup_expense_lines(` call (`:1109`) and the one real call inside it (`:1110`). **Only that last one takes `prop`.** A second call site left on the old signature would silently resolve every document to `full`, which is today's behaviour and therefore invisible.

- [ ] **Step 7: Strip the marker from the rendered lines**

Replace `_scaled_lines` (the callable-taking version the unit-level-share plan installed) with:

```python
def _scaled_lines(
    lines: List[Dict[str, Any]],
    share_for: Callable[[Optional[str]], float],
) -> List[Dict[str, Any]]:
    """Copy expense lines with amounts at the share that applies to each line.

    Never mutates the input. The unscaled lines stay the basis for every
    property-level sum, so scaling is applied exactly once and no sum can be
    scaled twice. `share_for` maps a line's `unit_id` to its share — a unit's
    own override, or the property's for a line belonging to no unit.

    `share_basis` is internal and is removed from every copy, so a property
    with a stored basis answer renders a payload identical to one without
    wherever the figures are identical.

    A line whose resolved share is 1.0 is copied through unchanged and carries
    no `full_amount`, so a wholly-owned property's payload is content-identical
    to before. Below 1.0 each scaled line also carries `full_amount`, the
    source document's face value, so the app can show "your 50% of RM 1,200.00"
    beside the scaled figure. Loan lines and lines already stated at the
    landlord's share (see _line_share) resolve to 1.0 and so take the same
    unchanged path — there is no second figure to show.
    """
    out: List[Dict[str, Any]] = []
    for line in lines:
        line_share = _line_share(line, share_for(line.get("unit_id")))
        rendered = {k: v for k, v in line.items() if k != "share_basis"}
        if line_share == 1.0:
            out.append(rendered)
            continue
        rendered["amount"] = _round2(line_share * line["amount"])
        rendered["full_amount"] = _round2(line["amount"])
        out.append(rendered)
    return out
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::DocumentShareBasisExpenseTests -v`
Expected: PASS, 12 tests.

- [ ] **Step 9: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.** No existing fixture sets any basis field, so every document resolves to `full` and every existing figure is unchanged. If anything fails, stop and report it — do not adjust the failing test.

- [ ] **Step 10: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): scale expense lines by their document's share basis"
```

---

### Task 3: Income splits into full and mine buckets

Income does not pass through a per-line helper — it is two running totals scaled by one multiply per scope. So the split has to happen where the months are counted.

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` — `_scope_income` (`:107-205`), `_scaled_month_rows`, and the income half of the property loop
- Test: `backend/tests/test_finance_engine.py`

**Interfaces:**
- Consumes: `_document_share_basis` and `_basis_share` from Task 2; `share_for` / `scope_share` from the unit-level-share plan.
- Produces:
  - `_scope_income(...)` returns **nine** values instead of seven: `month_rows, rented, actual_full, actual_mine, derived_full, derived_mine, vacant_months, derived_months, unpaid_months`. The single call site changes with it; nothing else calls it.
  - `unpaid_months` entries become **5-tuples**: `(month, reason, state, billed_amount, basis)`.
  - `_scaled_month_rows` keeps its `(rows, share)` signature and decides per row.
  - `full_gross_income` is emitted whenever it **differs from** `gross_income`, replacing the `scope_share < 1.0` test.

> **The trap the earlier plans already named, now with a second edge.** `_scope_income` returns `billed` in both the rendered month rows *and* its `unpaid_months` tuples, and the tuple path feeds `prop_outstanding`. Both paths need the basis or a `mine` invoice's outstanding rent gets halved while its paid months do not — a discrepancy that shows up as an outstanding total that cannot be reconstructed from the strip above it.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_finance_engine.py`:

```python
class DocumentShareBasisIncomeTests(unittest.TestCase):
    """Income at 'mine' basis is already the landlord's money. Every fixture
    is at share 0.5 — basis cannot change a figure at 1.0."""

    def _summary_at(self, invoice_basis=None, lease_basis=None, **prop_kwargs):
        docs = [
            _basis_doc("p1", "lease",
                       {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                        "lease_end": "2025-12-31"},
                       basis=lease_basis, unit_id="u1"),
            _basis_doc("p1", "rental_invoice",
                       {"amount": 1000.0, "period_month": "2025-03"},
                       basis=invoice_basis, unit_id="u1"),
        ]
        result = _summary(docs, [_basis_prop("p1", "Block", share=0.5, **prop_kwargs)],
                          units={"p1": [{"unit_id": "u1", "label": "A-1"}]})
        return result, result["properties"][0], result["properties"][0]["units"][0]

    def test_mine_income_is_not_scaled_and_full_income_beside_it_is(self):
        # March arrives as an already-split invoice; the other 11 months are
        # derived from a whole-property lease. 1000 + 0.5 * 11000 = 6500.
        _, block, _ = self._summary_at(invoice_basis="mine")
        self.assertAlmostEqual(block["received_rent"], 6500.0, places=2)

    def test_the_unit_gross_income_uses_the_same_split(self):
        _, _, unit = self._summary_at(invoice_basis="mine")
        self.assertAlmostEqual(unit["gross_income"], 6500.0, places=2)

    def test_full_gross_income_is_the_unscaled_total(self):
        _, _, unit = self._summary_at(invoice_basis="mine")
        self.assertAlmostEqual(unit["full_gross_income"], 12000.0, places=2)

    def test_an_all_mine_unit_emits_no_full_gross_income(self):
        # Nothing was scaled, so there is no second figure and the panel must
        # not render "your 50% of" beneath a figure that was never halved.
        _, _, unit = self._summary_at(invoice_basis="mine", lease_basis="mine")
        self.assertAlmostEqual(unit["gross_income"], 12000.0, places=2)
        self.assertNotIn("full_gross_income", unit)

    def test_month_rows_follow_their_own_source_documents_basis(self):
        _, _, unit = self._summary_at(invoice_basis="mine")
        march = next(m for m in unit["months"] if m["month"] == 3)
        january = next(m for m in unit["months"] if m["month"] == 1)
        self.assertAlmostEqual(march["amount"], 1000.0, places=2)
        self.assertNotIn("full_amount", march)
        self.assertAlmostEqual(january["amount"], 500.0, places=2)
        self.assertAlmostEqual(january["full_amount"], 1000.0, places=2)

    def test_month_rows_never_carry_the_internal_basis_marker(self):
        _, _, unit = self._summary_at(invoice_basis="mine")
        for row in unit["months"]:
            self.assertNotIn("share_basis", row)

    def test_outstanding_rent_follows_the_billing_documents_basis(self):
        # The unpaid month is billed by the 'mine' invoice, so its outstanding
        # figure is already the landlord's — 1000, not 500.
        docs = [
            _basis_doc("p1", "rental_invoice",
                       {"amount": 1000.0, "period_month": "2025-03"},
                       basis="mine", unit_id="u1"),
        ]
        result = _summary(docs, [_basis_prop("p1", "Block", share=0.5)],
                          units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
                          payment_exceptions=[_exception("p1", "2025-03", unit_id="u1")])
        self.assertAlmostEqual(result["properties"][0]["outstanding_rent"], 1000.0,
                               places=2)

    def test_a_lease_category_exception_reaches_derived_months(self):
        # Derived income comes from the lease document, so a 'lease' exception
        # is what governs a backfilled month.
        _, block, _ = self._summary_at(exceptions={"lease": "mine"})
        # 11 derived months whole + March's invoice halved.
        self.assertAlmostEqual(block["received_rent"], 11500.0, places=2)

    def test_derived_rent_reports_the_scaled_derived_part(self):
        _, block, _ = self._summary_at(exceptions={"lease": "mine"})
        self.assertAlmostEqual(block["derived_rent"], 11000.0, places=2)

    def test_a_rental_invoice_exception_reaches_actual_months(self):
        _, block, _ = self._summary_at(exceptions={"rental_invoice": "mine"})
        self.assertAlmostEqual(block["received_rent"], 6500.0, places=2)


class ShareBasisEquivalenceTests(unittest.TestCase):
    """Spec §7: nothing moves on the day this ships. A stored answer that
    matches what the engine already assumed, and a partial-share property
    with no answer at all, must both produce exactly today's payload."""

    def _docs(self):
        # doc_id AND uploaded are pinned so repeated runs build byte-identical
        # documents — `_doc` derives both from a module-level counter that
        # advances on every call.
        stamp = datetime(2026, 1, 1)
        return [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"},
                 unit_id="u1", uploaded=stamp, doc_id="lease-u1"),
            _doc("p1", "maintenance", {"amount": 800.0, "period_start": "2025-02-01"},
                 unit_id="u1", uploaded=stamp, doc_id="maint-u1"),
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 1200.0},
                 uploaded=stamp, doc_id="loan-p1"),
        ]

    def _summary_for(self, prop):
        return _summary(self._docs(), [prop],
                        units={"p1": [{"unit_id": "u1", "label": "A-1"}]})

    def test_an_explicit_full_default_equals_no_answer_at_all(self):
        answered = self._summary_for(
            _basis_prop("p1", "Block", share=0.5, default="full", exceptions={}))
        unanswered = self._summary_for(_prop("p1", "Block", share=0.5))
        self.assertEqual(answered, unanswered)

    def test_a_mine_default_at_full_ownership_equals_no_answer_at_all(self):
        # Scaling by 1.0 is identity either way, so the two payloads must be
        # byte-identical — including the absence of any internal marker.
        answered = self._summary_for(
            _basis_prop("p1", "Block", share=1.0, default="mine"))
        unanswered = self._summary_for(_prop("p1", "Block", share=1.0))
        self.assertEqual(answered, unanswered)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::DocumentShareBasisIncomeTests tests/test_finance_engine.py::ShareBasisEquivalenceTests -v`
Expected: FAIL — every `mine` income figure reads at half (6000.00 instead of 6500.00). `ShareBasisEquivalenceTests` should already pass after Task 2; it is the regression guard. If it fails, stop and report — Task 2's strip is leaking, not the income split.

- [ ] **Step 3: Split `_scope_income`'s totals by basis**

`_scope_income` needs the property so it can resolve each source document's basis. Change its signature (`finance_engine.py:107-113`) to add a trailing parameter:

```python
def _scope_income(
    prop_docs: List[Dict[str, Any]],
    unit_id: Optional[str],
    year: int,
    months: List[int],
    exceptions: List[Dict[str, Any]],
    prop: Optional[Dict[str, Any]] = None,
):
```

and rewrite the tail of its docstring:

```
    Returns (month_rows, rented, actual_full, actual_mine, derived_full,
    derived_mine, vacant_months, derived_months, unpaid_months). Income is
    split by the source document's share basis — a 'mine' figure is already
    the landlord's portion and must not be scaled again — and unpaid_months
    entries are (month, reason, state, billed_amount, basis).
```

Inside, the invoice map must remember each month's basis. Replace the `invoice_by_month` block:

```python
    invoice_by_month: Dict[int, Tuple[float, str]] = {}
    for doc in sorted(
        (d for d in prop_docs
         if d.get("category") == "rental_invoice" and d.get("unit_id") == unit_id),
        key=_uploaded_key,
    ):
        facts = doc["extracted_facts"]
        amount = _amount(facts, "amount")
        ym = _ym(facts.get("period_month"))
        if amount is None or ym is None or ym[0] != year:
            continue
        # ascending sort: later upload wins, and brings its own basis with it
        invoice_by_month[ym[1]] = (amount, _document_share_basis(doc, prop or {}))
```

Replace the lease block's tail so the winning lease's basis is kept:

```python
    lease_facts: Optional[Dict[str, Any]] = None
    lease_basis = "full"
    for doc in sorted(
        (d for d in prop_docs
         if d.get("category") == "lease" and d.get("unit_id") == unit_id),
        key=_uploaded_key,
    ):
        facts = doc["extracted_facts"]
        if (
            _amount(facts, "monthly_rent") is not None
            and _ym(facts.get("lease_start"))
            and _ym(facts.get("lease_end"))
        ):
            lease_facts = facts  # most recent valid lease wins
            lease_basis = _document_share_basis(doc, prop or {})
```

Replace the four accumulators:

```python
    actual_full = 0.0
    actual_mine = 0.0
    derived_full = 0.0
    derived_mine = 0.0
```

(deleting `actual_sum` and `derived_sum`), and widen the unpaid list's type:

```python
    unpaid_months: List[Tuple[int, Optional[str], str, Optional[float], str]] = []
```

Then rewrite the month loop's three income branches. The exception branch:

```python
        if month in exception_by_month:
            info = exception_by_month[month]
            reason, state = info["reason"], info["state"]
            billed, billed_basis = None, "full"
            if month in invoice_by_month:
                billed, billed_basis = invoice_by_month[month]
            elif lease_facts is not None and (
                _ym(lease_facts["lease_start"]) <= (year, month) <= _ym(lease_facts["lease_end"])
            ):
                billed, billed_basis = _amount(lease_facts, "monthly_rent"), lease_basis
            row: Dict[str, Any] = {
                "month": month, "source": "unpaid", "amount": 0.0, "payment_state": state,
            }
            if billed is not None:
                row["billed_amount"] = _round2(billed)
                row["share_basis"] = billed_basis
            if reason:
                row["reason"] = reason
            month_rows.append(row)
            rented += 1
            unpaid_months.append((month, reason, state, billed, billed_basis))
            continue
```

The actual branch:

```python
        if month in invoice_by_month:
            amount, basis = invoice_by_month[month]
            month_rows.append({"month": month, "source": "actual",
                               "amount": _round2(amount), "share_basis": basis})
            if basis == "mine":
                actual_mine += amount
            else:
                actual_full += amount
            rented += 1
            continue
```

The derived branch:

```python
        if lease_facts is not None and (
            _ym(lease_facts["lease_start"]) <= (year, month) <= _ym(lease_facts["lease_end"])
        ):
            amount = _amount(lease_facts, "monthly_rent")
            month_rows.append({"month": month, "source": "derived",
                               "amount": _round2(amount), "share_basis": lease_basis})
            if lease_basis == "mine":
                derived_mine += amount
            else:
                derived_full += amount
            rented += 1
            derived_months.append(month)
            continue
```

And the return:

```python
    return (month_rows, rented, actual_full, actual_mine, derived_full, derived_mine,
            vacant_months, derived_months, unpaid_months)
```

- [ ] **Step 4: Teach `_scaled_month_rows` about basis**

The unit-panel plan added `_scaled_month_rows` beside `_scaled_lines`, with this body:

```python
    if share == 1.0:
        return list(rows)
    out: List[Dict[str, Any]] = []
    for row in rows:
        scaled = dict(row)
        if row.get("amount"):
            scaled["amount"] = _round2(share * row["amount"])
            scaled["full_amount"] = _round2(row["amount"])
        if row.get("billed_amount"):
            scaled["billed_amount"] = _round2(share * row["billed_amount"])
            scaled["full_billed_amount"] = _round2(row["billed_amount"])
        out.append(scaled)
    return out
```

Two things change and nothing else: the share is resolved per row, and the internal marker is stripped. The truthy `row.get("amount")` guards stay exactly as they are — a vacant or written-off row renders a state, not a figure. The `share == 1.0` early-out goes, because the copy now has to happen at every share in order to strip. Replace the whole function with:

```python
def _scaled_month_rows(rows: List[Dict[str, Any]], share: float) -> List[Dict[str, Any]]:
    """Copy month rows with amounts at the share that applies to each row.

    Mirrors _scaled_lines: never mutates the input, and below the applicable
    share carries the source figure in `full_amount` / `full_billed_amount` so
    the app can show "your 50% of RM 1,200.00" beside the scaled figure. A row
    whose source document is at basis 'mine' is already the landlord's figure
    and is copied through unscaled with no face value beside it.

    `share_basis` is internal and is removed from every copy, so a property
    with a stored basis answer renders a payload identical to one without
    wherever the figures are identical.
    """
    out: List[Dict[str, Any]] = []
    for row in rows:
        row_share = _basis_share(row.get("share_basis"), share)
        scaled = {k: v for k, v in row.items() if k != "share_basis"}
        if row_share != 1.0:
            if row.get("amount"):
                scaled["amount"] = _round2(row_share * row["amount"])
                scaled["full_amount"] = _round2(row["amount"])
            if row.get("billed_amount"):
                scaled["billed_amount"] = _round2(row_share * row["billed_amount"])
                scaled["full_billed_amount"] = _round2(row["billed_amount"])
        out.append(scaled)
    return out
```

- [ ] **Step 5: Split the income in the property loop**

Pass the property in, and unpack nine values. Replace the `_scope_income(...)` call at the top of `for scope in scopes:`:

```python
            (month_rows, rented, actual_full, actual_mine, derived_full, derived_mine,
             vacant, derived, unpaid) = _scope_income(
                prop_docs, scope["unit_id"], year, months, prop_exceptions, prop
            )
            scope_share = share_for(scope["unit_id"])
            # Scaled here, per scope and per basis, then summed. `actual_sum`
            # and `derived_sum` are the landlord's own figures from here down.
            actual_sum = scope_share * actual_full + actual_mine
            derived_sum = scope_share * derived_full + derived_mine
```

The unit-level-share plan left `prop_actual += scope_share * actual_sum` and `prop_derived += scope_share * derived_sum`. Those would now scale twice — replace them with:

```python
            prop_actual += actual_sum
            prop_derived += derived_sum
```

In the unit block, `gross_income` is already `_round2(scope_share * (actual_sum + derived_sum))`; with `actual_sum` / `derived_sum` now pre-scaled it becomes:

```python
            gross_income = _round2(actual_sum + derived_sum)
```

and the `full_gross_income` guard changes from `scope_share < 1.0` to a comparison:

```python
            # Emitted whenever it differs — i.e. whenever something really was
            # scaled. A unit whose income is entirely at basis 'mine' has no
            # second figure to show even at a partial share, and a unit with no
            # income at all has nothing to compare.
            full_gross = _round2(actual_full + actual_mine + derived_full + derived_mine)
            if full_gross != gross_income:
                block["full_gross_income"] = full_gross
```

Finally the outstanding accumulator, in the `for m, reason, state, billed in unpaid:` loop — widen the unpacking and weigh by the billing document's basis:

```python
            for m, reason, state, billed, billed_basis in unpaid:
                if state == "written_off":
                    note = f"Written off as unrecoverable for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                else:
                    note = f"No payment received for {MONTH_NAMES[m - 1]} — {scope['label']} ({name})"
                    if billed:
                        prop_outstanding += _basis_share(billed_basis, scope_share) * billed
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_finance_engine.py::DocumentShareBasisIncomeTests tests/test_finance_engine.py::ShareBasisEquivalenceTests -v`
Expected: PASS, 12 tests.

- [ ] **Step 7: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.**

**One predictable exception.** The `full_gross_income` guard moved from "the share is partial" to "the two figures differ", and those disagree in exactly one case: a unit with **no income at all** on a partial-share property, which used to emit `full_gross_income: 0.0` and now omits the key. If a single existing test fails on that, and only that, change its assertion from `assertEqual(unit["full_gross_income"], 0.0)` to `assertNotIn("full_gross_income", unit)` — the new behaviour is correct, because "your 50% of RM 0.00" is a sub-label under a figure that was never halved. **If anything else fails, stop and report it** rather than adjusting the test.

- [ ] **Step 8: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(finance): split rental income by its documents' share basis"
```

---

### Task 4: The service hands the engine both answers

The engine now understands basis and the property fields reach it, but the *document's* own override is still dropped on the floor: `get_finance_summary` builds each document dict by naming its keys, and `share_basis` is not one of them. This task closes that gap and proves the whole read path end to end — the failure mode being a fully green engine suite behind a feature that does nothing in the app.

**Files:**
- Modify: `backend/rag/documind_service.py:399-407`
- Test: `backend/tests/test_documind_service_flows.py` (append to `FinanceSummaryServiceTests`)

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: each document dict passed to `compute_finance_summary` gains `"share_basis": Optional[str]`.

- [ ] **Step 1: Write the failing tests**

Append inside `class FinanceSummaryServiceTests` in `backend/tests/test_documind_service_flows.py`:

```python
    async def test_get_finance_summary_reads_the_property_basis_default(self):
        statement = {
            "doc_id": "exp-1", "landlord_id": "l1", "property_id": "p1",
            "category": "expenses", "filename": "feb.pdf",
            "uploaded_at": datetime(2025, 2, 10),
            "extracted_facts": {"expense_lines": [
                {"subtype": "maintenance", "amount": 800.00, "date": "2025-02-01"},
            ]},
        }
        fake_db = _FakeDB(docs=[statement])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Ayer8",
             "ownership_share": 0.5, "share_basis_default": "mine"},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        # Already split by the agent: booked whole, not halved a second time.
        self.assertEqual(summary.totals.direct_expenses, 800.00)

    async def test_get_finance_summary_reads_the_documents_own_basis(self):
        # THE PLUMBING GATE. The engine handles `share_basis` on a document,
        # but this method builds its document dicts by naming keys — a missing
        # name here leaves the review sheet's chip writing to a field nothing
        # ever reads, with every engine test still green.
        statement = {
            "doc_id": "exp-1", "landlord_id": "l1", "property_id": "p1",
            "category": "expenses", "filename": "feb.pdf",
            "uploaded_at": datetime(2025, 2, 10),
            "share_basis": "full",
            "extracted_facts": {"expense_lines": [
                {"subtype": "maintenance", "amount": 800.00, "date": "2025-02-01"},
            ]},
        }
        fake_db = _FakeDB(docs=[statement])
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "Ayer8",
             "ownership_share": 0.5, "share_basis_default": "mine"},
        ]
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )

        summary = await service.get_finance_summary("l1", 2025)

        # The document says otherwise, and the document wins.
        self.assertEqual(summary.totals.direct_expenses, 400.00)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::FinanceSummaryServiceTests -v`
Expected: `test_get_finance_summary_reads_the_property_basis_default` PASSES already (Tasks 1–3 wired the property path); `test_get_finance_summary_reads_the_documents_own_basis` FAILS with `400.0 != 800.0` — the document's override never arrives, so the property default is still winning.

- [ ] **Step 3: Load the field**

In `backend/rag/documind_service.py`, inside `get_finance_summary`'s document loop, add one key after `"category": normalize_category(data.get("category")),`:

```python
                "share_basis": data.get("share_basis"),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::FinanceSummaryServiceTests -v`
Expected: PASS.

- [ ] **Step 5: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.**

- [ ] **Step 6: Commit**

Note `documind_service.py` carries unrelated uncommitted work — `git add` the file, and check `git diff --cached` shows only this one key before committing.

```bash
git add backend/rag/documind_service.py backend/tests/test_documind_service_flows.py
git diff --cached --stat
git commit -m "feat(finance): pass each document's share basis into the fold"
```

---

### Task 5: The property model carries the answers, Dart side

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/property.dart` — field declarations, constructor, `copyWith`, **and `withMortgageSettledOn`**
- Modify: `residex_app/lib/features/landlord/data/models/property_model.dart` — constructor, `fromEntity`, `toEntity`, `fromJson`, `toJson`
- Create: `residex_app/test/features/landlord/property_share_basis_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Property.shareBasisDefault` (`String`, default `'full'`)
  - `Property.shareBasisExceptions` (`Map<String, String>`, default `const {}`)
  - both on `copyWith`. Tasks 6 and 8 read and write them.

> **Non-nullable with a `'full'` default, deliberately.** The spec models absence as `full`, and `copyWith` coalesces with `?? this.field` — a nullable field could never be cleared back to null, so the "unanswered" state would be unreachable the moment anything wrote to it. A stored `'full'` and an absent field mean the same thing to the engine (Task 1 sanitises, Task 2 defaults), so the app can always write a value and never has to represent "no answer".

> **`withMortgageSettledOn` reconstructs `Property` field by field** and its own comment says it is kept beside `copyWith` "so a field added to Property later is obviously missing from both". Add both fields there too, or settling a mortgage silently resets a landlord's basis answers.

- [ ] **Step 1: Write the failing tests**

Create `residex_app/test/features/landlord/property_share_basis_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';

Map<String, dynamic> _json(Map<String, dynamic> extra) => <String, dynamic>{
      'landlordId': 'l1',
      'name': 'Ayer 8',
      'address': <String, dynamic>{
        'street': '1 Jalan Kiara',
        'city': 'KL',
        'state': 'WP',
        'zipCode': '50480',
        'country': 'Malaysia',
      },
      'type': 'condo',
      'purchasePrice': 500000,
      'currentValue': 550000,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      ...extra,
    };

PropertyModel _model({
  String shareBasisDefault = 'full',
  Map<String, String> shareBasisExceptions = const {},
}) =>
    PropertyModel(
      id: 'p1',
      landlordId: 'l1',
      name: 'Ayer 8',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      shareBasisDefault: shareBasisDefault,
      shareBasisExceptions: shareBasisExceptions,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Property share basis round-trip', () {
    test('parses a stored default and exception map', () {
      final property = PropertyModel.fromJson(
        _json({
          'share_basis_default': 'mine',
          'share_basis_exceptions': <String, dynamic>{'tax': 'full'},
        }),
        'p1',
      );

      expect(property.shareBasisDefault, 'mine');
      expect(property.shareBasisExceptions, {'tax': 'full'});
    });

    test('absent fields default to full with no exceptions', () {
      final property = PropertyModel.fromJson(_json({}), 'p1');

      expect(property.shareBasisDefault, 'full');
      expect(property.shareBasisExceptions, isEmpty);
    });

    test('an unrecognised stored default reads as full', () {
      final property = PropertyModel.fromJson(
        _json({'share_basis_default': 'sometimes'}),
        'p1',
      );

      expect(property.shareBasisDefault, 'full');
    });

    test('toJson writes both fields', () {
      final json = _model(
        shareBasisDefault: 'mine',
        shareBasisExceptions: const {'tax': 'full'},
      ).toJson();

      expect(json['share_basis_default'], 'mine');
      expect(json['share_basis_exceptions'], {'tax': 'full'});
    });

    test('copyWith carries and can replace both fields', () {
      final property = _model(shareBasisDefault: 'mine');

      expect(property.copyWith(name: 'Other').shareBasisDefault, 'mine');
      expect(property.copyWith(shareBasisDefault: 'full').shareBasisDefault, 'full');
      expect(
        property.copyWith(shareBasisExceptions: const {'upkeep': 'full'})
            .shareBasisExceptions,
        {'upkeep': 'full'},
      );
    });

    test('withMortgageSettledOn preserves both fields', () {
      // It rebuilds Property field by field, so a field missing from it is
      // silently reset the next time a mortgage is marked settled.
      final property = _model(
        shareBasisDefault: 'mine',
        shareBasisExceptions: const {'tax': 'full'},
      ).withMortgageSettledOn('2026-03');

      expect(property.shareBasisDefault, 'mine');
      expect(property.shareBasisExceptions, {'tax': 'full'});
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/property_share_basis_test.dart`
Expected: FAIL to compile — `The named parameter 'shareBasisDefault' isn't defined`.

- [ ] **Step 3: Add the fields to the entity**

In `residex_app/lib/features/landlord/domain/entities/property.dart`, after the `utilitiesPaidBy` declaration:

```dart
  /// 'full' (default) | 'mine' — whether this landlord's documents state the
  /// whole property's figures or their own portion already. 'full' is what
  /// the finance engine has always assumed, so it is the value for every
  /// property that has never answered, and a stored 'full' and an absent
  /// field mean exactly the same thing.
  final String shareBasisDefault;

  /// Category -> basis, holding only the categories that differ from
  /// [shareBasisDefault]. A category absent from this map inherits the
  /// default, so one added to the taxonomy later is never silently unset.
  /// Never contains 'loan': loan figures are the landlord's own borrowing and
  /// are not scaled by ownership share at all.
  final Map<String, String> shareBasisExceptions;
```

In the constructor, after `this.utilitiesPaidBy = 'tenant',`:

```dart
    this.shareBasisDefault = 'full',
    this.shareBasisExceptions = const {},
```

In `copyWith`'s parameter list, after `String? utilitiesPaidBy,`:

```dart
    String? shareBasisDefault,
    Map<String, String>? shareBasisExceptions,
```

and in its returned `Property(...)`, after `utilitiesPaidBy: utilitiesPaidBy ?? this.utilitiesPaidBy,`:

```dart
      shareBasisDefault: shareBasisDefault ?? this.shareBasisDefault,
      shareBasisExceptions: shareBasisExceptions ?? this.shareBasisExceptions,
```

In `withMortgageSettledOn`'s `Property(...)`, after `utilitiesPaidBy: utilitiesPaidBy,`:

```dart
        shareBasisDefault: shareBasisDefault,
        shareBasisExceptions: shareBasisExceptions,
```

- [ ] **Step 4: Serialize them**

In `residex_app/lib/features/landlord/data/models/property_model.dart`:

Constructor, after `super.utilitiesPaidBy = 'tenant',`:

```dart
    super.shareBasisDefault = 'full',
    super.shareBasisExceptions = const {},
```

`fromEntity`, after `utilitiesPaidBy: property.utilitiesPaidBy,`:

```dart
      shareBasisDefault: property.shareBasisDefault,
      shareBasisExceptions: property.shareBasisExceptions,
```

`toEntity`, after `utilitiesPaidBy: utilitiesPaidBy,`:

```dart
      shareBasisDefault: shareBasisDefault,
      shareBasisExceptions: shareBasisExceptions,
```

`fromJson`, after the `utilitiesPaidBy:` line:

```dart
      // Anything other than the two legal values reads as 'full' — the safe
      // direction, and the same defence the backend applies on read.
      shareBasisDefault: json['share_basis_default'] == 'mine' ? 'mine' : 'full',
      shareBasisExceptions: (json['share_basis_exceptions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          const {},
```

`toJson`, after `'utilities_paid_by': utilitiesPaidBy,`:

```dart
      'share_basis_default': shareBasisDefault,
      'share_basis_exceptions': shareBasisExceptions,
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/property_share_basis_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Run the suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (boilerplate only).

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/property.dart \
  residex_app/lib/features/landlord/data/models/property_model.dart \
  residex_app/test/features/landlord/property_share_basis_test.dart
git commit -m "feat(portfolio): carry the document share basis on the property model"
```

---

### Task 6: The landlord answers once, and only when it matters

Two things land together because they are one behaviour: the §3a predicate that decides whether any of this is ever shown, and the question itself.

**Files:**
- Create: `residex_app/lib/features/landlord/domain/share_basis.dart`
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`
- Create: `residex_app/test/features/landlord/share_basis_test.dart`
- Modify: `residex_app/test/features/landlord/property_profile_save_test.dart` (extend two helpers, append tests)

**Interfaces:**
- Consumes: `Property.shareBasisDefault` / `shareBasisExceptions` (Task 5), `Unit.ownershipShare` (unit-level-share plan Task 5).
- Produces, from `share_basis.dart`:
  - `const shareBasisFull = 'full'; const shareBasisMine = 'mine';`
  - `const Map<String, String> shareBasisCategories` — the six declarable categories and their display labels, **excluding loan**.
  - `bool shareApplies({required double propertyShare, required Iterable<double?> unitShares})`
  - `String resolveShareBasis({required Property property, required String category, String? documentBasis})`
  - `String oppositeShareBasis(String basis)`

  Task 8 uses `shareApplies` and `resolveShareBasis`.

> **The gate must not be `property.ownershipShare < 1.0`.** Unit-level ownership share has already shipped by the time this lands, so a property owned outright can contain one co-owned unit. Keyed on the property's own share, the question is never asked and the chip never appears for exactly that unit — whose documents do need a basis and would be scaled wrong in silence. `shareApplies` is the named predicate, and the third test below is the one that fails if it is written the naive way.

- [ ] **Step 1: Write the failing tests for the predicate**

Create `residex_app/test/features/landlord/share_basis_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/share_basis.dart';

Property _property({
  double ownershipShare = 1.0,
  String shareBasisDefault = 'full',
  Map<String, String> shareBasisExceptions = const {},
}) =>
    Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Ayer 8',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      ownershipShare: ownershipShare,
      shareBasisDefault: shareBasisDefault,
      shareBasisExceptions: shareBasisExceptions,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('shareApplies', () {
    test('a co-owned property qualifies on its own', () {
      expect(shareApplies(propertyShare: 0.5, unitShares: const []), isTrue);
    });

    test('a wholly-owned property with no unit overrides does not', () {
      expect(shareApplies(propertyShare: 1.0, unitShares: const [null, null]),
          isFalse);
    });

    test('a wholly-owned property with one co-owned unit qualifies', () {
      // THE GATE. Keyed on the property's own share this reads false, the
      // question is never asked, and that unit's documents are scaled with no
      // way for the landlord to say they arrived already split.
      expect(shareApplies(propertyShare: 1.0, unitShares: const [null, 0.5]),
          isTrue);
    });

    test('a unit explicitly at 100% does not qualify on its own', () {
      expect(shareApplies(propertyShare: 1.0, unitShares: const [1.0]), isFalse);
    });
  });

  group('resolveShareBasis', () {
    test('the document override wins over everything', () {
      expect(
        resolveShareBasis(
          property: _property(
            shareBasisDefault: 'full',
            shareBasisExceptions: const {'tax': 'full'},
          ),
          category: 'tax',
          documentBasis: 'mine',
        ),
        'mine',
      );
    });

    test('a category exception beats the default', () {
      expect(
        resolveShareBasis(
          property: _property(
            shareBasisDefault: 'full',
            shareBasisExceptions: const {'tax': 'mine'},
          ),
          category: 'tax',
        ),
        'mine',
      );
    });

    test('the default applies to a category with no exception', () {
      expect(
        resolveShareBasis(
          property: _property(shareBasisDefault: 'mine'),
          category: 'upkeep',
        ),
        'mine',
      );
    });

    test('a bundled expenses statement can only take the default', () {
      // 'expenses' is not a declarable category, so no exception can match —
      // which is exactly why the per-document chip exists.
      expect(
        resolveShareBasis(
          property: _property(
            shareBasisDefault: 'full',
            shareBasisExceptions: const {'maintenance': 'mine'},
          ),
          category: 'expenses',
        ),
        'full',
      );
    });

    test('an unanswered property resolves to full', () {
      expect(
        resolveShareBasis(property: _property(), category: 'maintenance'),
        'full',
      );
    });
  });

  test('loan is never offered as a declarable category', () {
    // Offering it would let a landlord halve their own interest deduction,
    // contradicting a settled rule the engine enforces unconditionally.
    expect(shareBasisCategories.containsKey('loan'), isFalse);
    expect(shareBasisCategories.keys, hasLength(6));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/share_basis_test.dart`
Expected: FAIL to compile — `Target of URI doesn't exist: '.../domain/share_basis.dart'`.

- [ ] **Step 3: Write the predicate and the resolution order**

Create `residex_app/lib/features/landlord/domain/share_basis.dart`:

```dart
import 'entities/property.dart';

/// The document states the whole property's figure. The finance engine
/// multiplies it by ownership share — what it has always done.
const String shareBasisFull = 'full';

/// The document already states only this landlord's portion, so the engine
/// uses it verbatim.
const String shareBasisMine = 'mine';

/// The categories a landlord may declare an exception for, with their display
/// labels.
///
/// **Loan is deliberately absent.** Loan interest and principal are never
/// scaled by ownership share — the mortgage is the landlord's own borrowing,
/// not a cost shared with co-owners. That is an ownership decision, not a
/// claim about what a statement shows, so offering `loan` here would let a
/// landlord contradict a settled rule and halve their own deduction.
const Map<String, String> shareBasisCategories = <String, String>{
  'lease': 'Tenancy agreements',
  'rental_invoice': 'Rent invoices',
  'tax': 'Assessment & quit rent',
  'upkeep': 'Repairs & upkeep',
  'maintenance': 'Maintenance & service charges',
  'insurance': 'Insurance',
};

/// Whether an ownership share applies anywhere under this property — the one
/// predicate every part of the share-basis feature is gated on.
///
/// **Not `property.ownershipShare < 1.0`.** A property owned outright can
/// contain a single co-owned unit, and that unit's documents need a basis
/// just as much. Keyed on the property's own share, the question would never
/// be asked and the upload chip would never appear for exactly that unit.
///
/// [unitShares] are the units' stored overrides, where null means "inherits
/// the property's" and therefore adds nothing the property's own share does
/// not already say.
bool shareApplies({
  required double propertyShare,
  required Iterable<double?> unitShares,
}) {
  if (propertyShare < 1.0) return true;
  return unitShares.any((share) => share != null && share < 1.0);
}

/// The basis that applies to one document: its own answer, then the
/// property's exception for its category, then the property's default, then
/// [shareBasisFull].
///
/// A bundled `expenses` statement's category is not one of
/// [shareBasisCategories], so no exception can ever match it — it takes its
/// own answer or the default, which is why the upload review sheet asks.
String resolveShareBasis({
  required Property property,
  required String category,
  String? documentBasis,
}) {
  if (documentBasis == shareBasisMine || documentBasis == shareBasisFull) {
    return documentBasis!;
  }
  final exception = property.shareBasisExceptions[category];
  if (exception == shareBasisMine || exception == shareBasisFull) {
    return exception!;
  }
  return property.shareBasisDefault == shareBasisMine
      ? shareBasisMine
      : shareBasisFull;
}

/// There are only two bases, so "this category is an exception" fully
/// determines its value: whatever the default is not.
String oppositeShareBasis(String basis) =>
    basis == shareBasisMine ? shareBasisFull : shareBasisMine;
```

- [ ] **Step 4: Run the predicate tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/share_basis_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Write the failing tests for the question**

In `residex_app/test/features/landlord/property_profile_save_test.dart`, three edits.

First, give `_FakeUnitRepository` a unit list so the dialog's §3a gate can see unit overrides:

```dart
class _FakeUnitRepository implements UnitRepository {
  _FakeUnitRepository([this.units = const []]);

  final List<Unit> units;

  @override
  Future<String> createUnit(Unit unit) async => 'u1';
  @override
  Future<void> deleteAllUnitsForProperty(String propertyId) async {}
  @override
  Future<void> deleteUnit(String propertyId, String unitId) async {}
  @override
  Future<List<Unit>> getUnitsForProperty(String propertyId) async => units;
  @override
  Future<void> updateUnit(Unit unit) async {}
  @override
  Stream<List<Unit>> streamUnitsForProperty(String propertyId) =>
      Stream.value(units);
}
```

Second, give `_property` and `_openEditDialog` the two new knobs. In `_property`, add a parameter `double ownershipShare = 1.0,` and pass `ownershipShare: ownershipShare,` to the `Property(...)`. In `_openEditDialog`, add parameters `double ownershipShare = 1.0,` and `List<Unit> units = const [],`, pass `ownershipShare: ownershipShare` into `_property(...)`, and add one override to the `ProviderScope`:

```dart
        unitRepositoryProvider.overrideWithValue(_FakeUnitRepository(units)),
```

> That override is new to `_openEditDialog` and strictly safer than what is there now: the dialog is about to watch the units provider, and without an override that read reaches the real data source, which only "passes" because the emulator host is unroutable from a desktop test runner.

Third, append to `main()`:

```dart
  testWidgets('a wholly-owned property is never asked about share basis',
      (tester) async {
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 1.0);

    expect(find.text('How do your documents arrive?'), findsNothing);
    expect(find.text('Already split to my share'), findsNothing);
  });

  testWidgets('a co-owned property is asked, and defaults to the full amount',
      (tester) async {
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    expect(find.text('How do your documents arrive?'), findsOneWidget);
    final full = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'At the full property amount'),
    );
    expect(full.selected, isTrue);
  });

  testWidgets('lowering the share on an existing property raises the question',
      (tester) async {
    // Spec §4: a property that already has documents must be asked at the
    // moment its share is set, because the answer changes existing figures.
    // The question is inline, so it has to appear as the field is typed —
    // which only works if the form rebuilds on that controller.
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 1.0);
    expect(find.text('How do your documents arrive?'), findsNothing);

    final shareField =
        find.widgetWithText(TextFormField, 'My share of this property (%)');
    await tester.ensureVisible(shareField);
    await tester.enterText(shareField, '50');
    await tester.pumpAndSettle();

    expect(find.text('How do your documents arrive?'), findsOneWidget);
  });

  testWidgets('a property at 100% with one co-owned unit is still asked',
      (tester) async {
    // THE §3a GATE. Keyed on the property's own share this property is at
    // 100% and says nothing, while that unit's documents still need a basis.
    await _openEditDialog(
      tester,
      hasMortgage: true,
      ownershipShare: 1.0,
      units: [
        Unit(
          id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
          isOccupied: true, ownershipShare: 0.5, createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.text('How do your documents arrive?'), findsOneWidget);
  });

  testWidgets('answering "already split" saves the default', (tester) async {
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Already split to my share'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.shareBasisDefault, 'mine');
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, isEmpty);
  });

  testWidgets('an exception stores the opposite of the default', (tester) async {
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Any exceptions?'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Assessment & quit rent'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    // Default is 'full', so an excepted category is 'mine'.
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, {'tax': 'mine'});
  });

  testWidgets('flipping the default flips every stored exception',
      (tester) async {
    // An exception means "this category differs". If the default moves and
    // the exceptions do not, every one of them silently becomes a no-op
    // duplicate of the default.
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Any exceptions?'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Assessment & quit rent'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Already split to my share'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.shareBasisDefault, 'mine');
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, {'tax': 'full'});
  });

  testWidgets('loan is never offered as an exception', (tester) async {
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Any exceptions?'));
    await tester.pumpAndSettle();

    expect(find.text('Loan statements'), findsNothing);
    expect(find.text('Assessment & quit rent'), findsOneWidget);
  });
```

`Unit` is already imported by this file (`domain/entities/unit.dart`, line 13), as is `AppChoiceChip`.

- [ ] **Step 6: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/property_profile_save_test.dart`
Expected: FAIL — `How do your documents arrive?` is not rendered. `a wholly-owned property is never asked about share basis` and `loan is never offered as an exception`'s first expectation pass trivially; they are guards.

- [ ] **Step 7: Add the question to the dialog**

In `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`, add one import:

```dart
import '../../../domain/share_basis.dart';
```

`unit_providers.dart` (line 9) and `domain/entities/unit.dart` (line 5) are already imported — the dialog creates units on its create branch — so `unitsForPropertyStreamProvider`, `Unit` and `AsyncValue` are all in scope already.

Add state beside `_hasMortgage`:

```dart
  String _shareBasisDefault = shareBasisFull;
  Map<String, String> _shareBasisExceptions = {};
  bool _showBasisExceptions = false;
```

In `initState`, inside the `if (property != null)` branch:

```dart
      _shareBasisDefault = property.shareBasisDefault;
      _shareBasisExceptions = Map<String, String>.from(property.shareBasisExceptions);
      _showBasisExceptions = _shareBasisExceptions.isNotEmpty;
```

and at the end of `initState`, unconditionally:

```dart
    // The question appears and disappears as the landlord types a share, so
    // the form has to rebuild on every keystroke in that one field.
    _ownershipShareController.addListener(_onShareChanged);
```

with, beside it:

```dart
  void _onShareChanged() => setState(() {});
```

and in `dispose`, before `_ownershipShareController.dispose();`:

```dart
    _ownershipShareController.removeListener(_onShareChanged);
```

Add the gate and the widget, beside the other `_build...` methods:

```dart
  /// The typed share, not the stored one: the landlord may be lowering it
  /// right now, and the question has to appear as they do it.
  double get _typedPropertyShare {
    final typed = double.tryParse(_ownershipShareController.text);
    return typed == null ? 1.0 : typed / 100.0;
  }

  /// The units whose overrides the §3a predicate has to consider.
  ///
  /// Split into a watch and a read on purpose: `ref.watch` is only legal
  /// during build, and `_handleSubmit` needs the same answer from outside it.
  /// At registration no units exist yet, so the predicate reduces to the
  /// property's own share.
  AsyncValue<List<Unit>> _watchUnits() {
    final property = widget.property;
    if (property == null) return AsyncValue<List<Unit>>.data(const []);
    return ref.watch(unitsForPropertyStreamProvider(property.id));
  }

  AsyncValue<List<Unit>> _readUnits() {
    final property = widget.property;
    if (property == null) return AsyncValue<List<Unit>>.data(const []);
    return ref.read(unitsForPropertyStreamProvider(property.id));
  }

  bool _shareAppliesFor(AsyncValue<List<Unit>> unitsAsync) => shareApplies(
        propertyShare: _typedPropertyShare,
        unitShares: (unitsAsync.value ?? const <Unit>[])
            .map((u) => u.ownershipShare),
      );

  Widget _buildShareBasisQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How do your documents arrive?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          'Bills for a co-owned property come either way. This decides whether '
          'we apply your share to them, or take them as already yours.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'At the full property amount',
              selected: _shareBasisDefault == shareBasisFull,
              onSelected: (_) => _setShareBasisDefault(shareBasisFull),
            ),
            AppChoiceChip(
              label: 'Already split to my share',
              selected: _shareBasisDefault == shareBasisMine,
              onSelected: (_) => _setShareBasisDefault(shareBasisMine),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_showBasisExceptions)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showBasisExceptions = true),
              child: Text('Any exceptions?',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.registry)),
            ),
          )
        else ...[
          Text('Tap any category that arrives the other way.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in shareBasisCategories.entries)
                AppChoiceChip(
                  label: entry.value,
                  selected: _shareBasisExceptions.containsKey(entry.key),
                  onSelected: (_) => _toggleBasisException(entry.key),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// An exception means "this category differs from the default", so moving
  /// the default has to move every exception with it — otherwise each one
  /// silently becomes a duplicate of the default and stops meaning anything.
  void _setShareBasisDefault(String basis) {
    setState(() {
      _shareBasisDefault = basis;
      final flipped = oppositeShareBasis(basis);
      _shareBasisExceptions = {
        for (final key in _shareBasisExceptions.keys) key: flipped,
      };
    });
  }

  void _toggleBasisException(String category) {
    setState(() {
      if (_shareBasisExceptions.containsKey(category)) {
        _shareBasisExceptions.remove(category);
      } else {
        _shareBasisExceptions[category] = oppositeShareBasis(_shareBasisDefault);
      }
    });
  }
```

Render it directly below the ownership-share field, replacing the `const SizedBox(height: 20),` that follows it:

```dart
                      _buildTextField(
                        controller: _ownershipShareController,
                        label: 'My share of this property (%)',
                        hint: '100 if solely owned',
                        keyboardType: TextInputType.number,
                        validator: _validateSharePercent,
                      ),
                      if (_shareAppliesFor(_watchUnits())) ...[
                        const SizedBox(height: 16),
                        _buildShareBasisQuestion(),
                      ],
                      const SizedBox(height: 20),
```

- [ ] **Step 8: Save the answers on both branches**

In `_handleSubmit`, above `final controller = ref.read(propertyControllerProvider);`:

```dart
      // Only the categories that actually differ are stored (spec §2), and a
      // property where no share applies keeps the defaults rather than
      // recording an answer nobody was asked for. `_readUnits`, not
      // `_watchUnits`: watching outside build throws.
      final basisApplies = _shareAppliesFor(_readUnits());
      final basisDefault = basisApplies ? _shareBasisDefault : shareBasisFull;
      final basisExceptions = basisApplies
          ? {
              for (final entry in _shareBasisExceptions.entries)
                if (entry.value != basisDefault) entry.key: entry.value,
            }
          : const <String, String>{};
```

In the edit-mode `Property(...)`, after `utilitiesPaidBy: existing.utilitiesPaidBy,`:

```dart
          shareBasisDefault: basisDefault,
          shareBasisExceptions: basisExceptions,
```

In the create-mode `Property(...)`, after `ownershipShare: ownershipShare,`:

```dart
          shareBasisDefault: basisDefault,
          shareBasisExceptions: basisExceptions,
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/property_profile_save_test.dart test/features/landlord/share_basis_test.dart`
Expected: PASS. If a tap fails to find its target, the dialog is taller than the test viewport — `_tap` already calls `ensureVisible`, so use it (as the appended tests do) rather than `tester.tap`.

- [ ] **Step 10: Run the suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (boilerplate only). `add_property_dialog_loan_prefs_test.dart` and `property_profile_fields_test.dart` also pump this dialog — their properties are at share 1.0 with no units, so the question is absent and nothing moves. If either fails, stop and report.

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.**

- [ ] **Step 11: Commit**

```bash
git add residex_app/lib/features/landlord/domain/share_basis.dart \
  residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart \
  residex_app/test/features/landlord/share_basis_test.dart \
  residex_app/test/features/landlord/property_profile_save_test.dart
git commit -m "feat(portfolio): ask how documents arrive when a share applies"
```

---

### Task 7: An endpoint to set one document's basis

The chip in Task 8 needs somewhere to write. This is the smallest possible sibling of the existing rename endpoint.

**Files:**
- Modify: `backend/models/documind_models.py` (after `DocumentRenameResponse`, `:301-309`)
- Modify: `backend/rag/documents/document_lifecycle_service.py` (after `rename_document`)
- Modify: `backend/rag/documind_service.py` (one passthrough beside `rename_document`, `:324-325`)
- Modify: `backend/api/rex_routes.py` (after the `/filename` route)
- Modify: `backend/tests/test_documind_service_flows.py` (`_FakeDocDocRef` gains `update`, plus a test class)
- Modify: `backend/tests/test_rex_routes_documind_docs_api.py` (route tests)

**Interfaces:**
- Consumes: nothing.
- Produces: `PATCH /api/rex/documind/documents/{doc_id}/share-basis`, body `{"share_basis": "full"|"mine"}`, response `{"doc_id", "share_basis"}`. Task 8 calls it.

- [ ] **Step 1: Write the failing tests**

First, `_FakeDocDocRef` has `get` and `delete` but no `update`, so no test can currently observe a document field being written. Add it after `get`:

```python
    def update(self, fields):
        index = self._find_index()
        if index is not None:
            self._db.docs[index].update(fields)
```

Then append to `backend/tests/test_documind_service_flows.py`:

```python
class SetDocumentShareBasisTests(unittest.IsolatedAsyncioTestCase):
    def _service(self, docs):
        return _build_service(_FakeDB(docs=docs), _FakeConversationStore(),
                              _FakeGraphOrchestrator({}), _FakeLLM("unused"))

    async def test_stores_the_basis_on_the_document(self):
        docs = [{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1",
                 "category": "expenses"}]
        service = self._service(docs)

        result = await service.set_document_share_basis(
            doc_id="d1", landlord_id="l1", share_basis="mine")

        self.assertEqual(result, {"doc_id": "d1", "share_basis": "mine"})
        self.assertEqual(docs[0]["share_basis"], "mine")

    async def test_rejects_an_unknown_basis(self):
        docs = [{"doc_id": "d1", "landlord_id": "l1", "property_id": "p1"}]
        service = self._service(docs)

        with self.assertRaises(ValueError):
            await service.set_document_share_basis(
                doc_id="d1", landlord_id="l1", share_basis="sometimes")
        self.assertNotIn("share_basis", docs[0])

    async def test_another_landlords_document_is_reported_as_not_found(self):
        docs = [{"doc_id": "d1", "landlord_id": "someone-else", "property_id": "p1"}]
        service = self._service(docs)

        with self.assertRaises(ValueError):
            await service.set_document_share_basis(
                doc_id="d1", landlord_id="l1", share_basis="mine")
        self.assertNotIn("share_basis", docs[0])

    async def test_a_missing_document_is_reported_as_not_found(self):
        service = self._service([])
        with self.assertRaises(ValueError):
            await service.set_document_share_basis(
                doc_id="nope", landlord_id="l1", share_basis="mine")
```

And append to `TestDocumindDocsApi` (the class holding the rename tests) in `backend/tests/test_rex_routes_documind_docs_api.py`:

```python
    def test_set_share_basis_returns_200_and_calls_service(self):
        with patch(
            "api.rex_routes.documind_service.set_document_share_basis",
            new=AsyncMock(return_value={"doc_id": "doc-1", "share_basis": "mine"}),
        ) as mocked:
            response = self.client.patch(
                "/api/rex/documind/documents/doc-1/share-basis",
                json={"share_basis": "mine"},
            )
            call_kwargs = mocked.await_args.kwargs

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["share_basis"], "mine")
        self.assertEqual(call_kwargs["doc_id"], "doc-1")
        self.assertEqual(call_kwargs["landlord_id"], "landlord_123")  # token uid, not any wire value
        self.assertEqual(call_kwargs["share_basis"], "mine")

    def test_set_share_basis_returns_400_on_an_unknown_value(self):
        with patch(
            "api.rex_routes.documind_service.set_document_share_basis",
            new=AsyncMock(side_effect=ValueError("Unknown share basis.")),
        ):
            response = self.client.patch(
                "/api/rex/documind/documents/doc-1/share-basis",
                json={"share_basis": "sometimes"},
            )
        self.assertEqual(response.status_code, 400)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::SetDocumentShareBasisTests tests/test_rex_routes_documind_docs_api.py -v`
Expected: FAIL — `AttributeError: 'DocuMindService' object has no attribute 'set_document_share_basis'`, and 404 on the route.

- [ ] **Step 3: Add the request/response models**

In `backend/models/documind_models.py`, after `DocumentRenameResponse`:

```python
class ShareBasisUpdateRequest(BaseModel):
    share_basis: str = Field(
        ..., description="'full' (states the whole property's amount) or "
                         "'mine' (already split to this landlord's share)")


class ShareBasisUpdateResponse(BaseModel):
    doc_id: str
    share_basis: str
```

- [ ] **Step 4: Add the lifecycle method**

In `backend/rag/documents/document_lifecycle_service.py`, after `rename_document`:

```python
    async def set_document_share_basis(
        self, doc_id: str, landlord_id: str, share_basis: str
    ) -> Dict[str, Any]:
        """Record whether one document states the whole property's figures or
        this landlord's share of them. Ownership-scoped: a doc that isn't the
        landlord's is reported as not found, never written.

        Validated against the two legal values rather than stored as given —
        anything else would read as 'full' downstream, silently discarding the
        landlord's answer instead of rejecting it.
        """
        if share_basis not in ("full", "mine"):
            raise ValueError("Share basis must be 'full' or 'mine'.")
        doc_ref = self._db.collection('documind_docs').document(doc_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise ValueError("Document not found.")
        data = snapshot.to_dict() or {}
        if data.get("landlord_id") != landlord_id:
            raise ValueError("Document not found.")
        doc_ref.update({"share_basis": share_basis})
        return {"doc_id": doc_id, "share_basis": share_basis}
```

Also extend the class docstring's list to name it: `"...unit reassignment, expense-line edits, share-basis answers, and signed view URLs."`

- [ ] **Step 5: Add the service passthrough**

In `backend/rag/documind_service.py`, immediately after `rename_document`:

```python
    async def set_document_share_basis(self, doc_id, landlord_id, share_basis):
        return await self._document_lifecycle.set_document_share_basis(
            doc_id, landlord_id, share_basis
        )
```

- [ ] **Step 6: Add the route**

In `backend/api/rex_routes.py`, after the `/filename` route, and add `ShareBasisUpdateRequest, ShareBasisUpdateResponse` to the `models.documind_models` import list at the top:

```python
@router.patch("/documind/documents/{doc_id}/share-basis",
              response_model=ShareBasisUpdateResponse)
async def set_document_share_basis(
    doc_id: str,
    payload: ShareBasisUpdateRequest,
    landlord_id: str = Depends(current_landlord_id),
):
    """
    Record whether this document states the whole property's figures ('full')
    or is already split to the landlord's share ('mine').

    Any other value returns 400 and the stored document is untouched; a doc
    that isn't the landlord's is reported as not found.
    """
    try:
        result = await documind_service.set_document_share_basis(
            doc_id=doc_id,
            landlord_id=landlord_id,
            share_basis=payload.share_basis,
        )
        return ShareBasisUpdateResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd backend && py -3.11 -m pytest tests/test_documind_service_flows.py::SetDocumentShareBasisTests tests/test_rex_routes_documind_docs_api.py -v`
Expected: PASS.

- [ ] **Step 8: Run the full backend suite**

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.**

- [ ] **Step 9: Commit**

`documind_service.py` and `test_documind_service_flows.py` both carry unrelated uncommitted work — stage them by name and check the staged diff before committing.

```bash
git add backend/models/documind_models.py \
  backend/rag/documents/document_lifecycle_service.py \
  backend/rag/documind_service.py \
  backend/api/rex_routes.py \
  backend/tests/test_documind_service_flows.py \
  backend/tests/test_rex_routes_documind_docs_api.py
git diff --cached --stat
git commit -m "feat(documind): endpoint to set one document's share basis"
```

---

### Task 8: The chip on the upload review sheet

A combined statement is corrected at the one moment its figures are on screen — the sheet that already opens after an `expenses` upload.

**Files:**
- Modify: `residex_app/lib/core/constants/api_constants.dart`
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart`
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:60-67` and `.../5-Documents/documents_screen.dart:1314-1321` (both call sites)
- Test: `residex_app/test/features/landlord/expense_lines_review_sheet_test.dart`

**Interfaces:**
- Consumes: the endpoint from Task 7; `shareApplies` / `resolveShareBasis` from Task 6.
- Produces: `showExpenseLinesReviewSheet(context, {required docId, required initialLines, required propertyId})` — **`propertyId` is new and required**, so both call sites must pass it.

> **The chip is per document, not per line.** One statement genuinely can mix bases, but a toggle per extracted charge is four decisions on a four-line statement, every upload, to serve a case that is rare inside an already-uncommon one. A landlord whose statement truly mixes can split it across two uploads.

- [ ] **Step 1: Write the failing tests**

Rewrite `_pumpSheet` in `residex_app/test/features/landlord/expense_lines_review_sheet_test.dart` and append tests. The existing three tests keep working because a null property gates the chip off:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart';

Property _property({
  double ownershipShare = 1.0,
  String shareBasisDefault = 'full',
}) =>
    Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Ayer 8',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      ownershipShare: ownershipShare,
      shareBasisDefault: shareBasisDefault,
      createdAt: DateTime(2026, 1, 1),
    );

/// Records what the chip wrote, in place of the real HTTP action.
class _BasisRecorder {
  String? docId;
  String? basis;
}

Future<void> _pumpSheet(
  WidgetTester tester,
  List<Map<String, dynamic>> lines, {
  Property? property,
  List<Unit> units = const [],
  _BasisRecorder? recorder,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Overridden even when null so the sheet never reaches the real data
        // source from a desktop test runner.
        propertyByIdProvider.overrideWith((ref, id) async => property),
        unitsForPropertyStreamProvider
            .overrideWith((ref, id) => Stream.value(units)),
        if (recorder != null)
          setDocumentShareBasisActionProvider.overrideWithValue(
            ({required String docId, required String shareBasis}) async {
              recorder.docId = docId;
              recorder.basis = shareBasis;
            },
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ExpenseLinesReviewSheet(
            docId: 'doc-1', propertyId: 'p1', initialLines: lines,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

Then append inside `main()`:

```dart
  testWidgets('no chip when no share applies', (tester) async {
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 1.0),
    );

    expect(find.text('At the full property amount'), findsNothing);
  });

  testWidgets('the chip is pre-set to the resolved default', (tester) async {
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 0.5, shareBasisDefault: 'mine'),
    );

    final mine = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'Already split to my share'),
    );
    expect(mine.selected, isTrue,
        reason: 'the landlord confirms rather than answers');
  });

  testWidgets('a property at 100% with one co-owned unit still shows the chip',
      (tester) async {
    // THE §3a GATE, on this surface. Keyed on the property's own share this
    // passes silently and the feature is simply absent for that unit.
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 1.0),
      units: [
        Unit(
          id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
          isOccupied: true, ownershipShare: 0.5, createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.text('At the full property amount'), findsOneWidget);
  });

  testWidgets('changing the chip writes the basis for that document',
      (tester) async {
    final recorder = _BasisRecorder();
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 0.5),
      recorder: recorder,
    );

    await tester.tap(find.text('Already split to my share'));
    await tester.pumpAndSettle();

    expect(recorder.docId, 'doc-1');
    expect(recorder.basis, 'mine');
  });

  testWidgets('confirming the pre-set answer writes nothing', (tester) async {
    // "Looks right" is the common path and must not put a redundant override
    // on every expenses document a co-owner ever uploads.
    final recorder = _BasisRecorder();
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 0.5),
      recorder: recorder,
    );

    await tester.tap(find.text('At the full property amount'));
    await tester.pumpAndSettle();

    expect(recorder.basis, isNull);
  });
```

Add `import 'package:residex_app/features/landlord/presentation/widgets/common/app_choice_chip.dart';` to the file's imports.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd residex_app && flutter test test/features/landlord/expense_lines_review_sheet_test.dart`
Expected: FAIL to compile — `The named parameter 'propertyId' isn't defined` and `Undefined name 'setDocumentShareBasisActionProvider'`.

- [ ] **Step 3: Add the endpoint constant and the datasource call**

In `residex_app/lib/core/constants/api_constants.dart`, beside `documindRenameDocument`:

```dart
  static String documindShareBasis(String docId) => '/api/rex/documind/documents/$docId/share-basis';
```

In `documind_remote_datasource.dart`, after `renameDocument`:

```dart
  /// Record whether one document states the whole property's figures
  /// ('full') or is already split to the landlord's share ('mine').
  Future<void> setDocumentShareBasis({
    required String docId,
    required String shareBasis,
  }) async {
    final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.documindShareBasis(docId)}');
    final response = await httpClient.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'share_basis': shareBasis}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set share basis: ${response.body}');
    }
  }
```

- [ ] **Step 4: Add the action provider**

In `documind_provider.dart`, after `updateExpenseLinesActionProvider`:

```dart
/// Record one document's share basis. The figures depend on it, so the
/// finance fold and its year options are invalidated alongside the document
/// list — exactly as an expense-line edit does.
final setDocumentShareBasisActionProvider = Provider<Future<void> Function({
  required String docId,
  required String shareBasis,
})>((ref) {
  return ({
    required String docId,
    required String shareBasis,
  }) async {
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.setDocumentShareBasis(
      docId: docId,
      shareBasis: shareBasis,
    );
    ref.invalidate(documindDocumentsProvider);
    ref.invalidate(financeSummaryProvider);
    ref.invalidate(financeYearsProvider);
  };
});
```

- [ ] **Step 5: Put the chip on the sheet**

In `expense_lines_review_sheet.dart`, add the imports:

```dart
import '../../../domain/share_basis.dart';
import '../../providers/property_providers.dart';
import '../../providers/unit_providers.dart';
import 'app_choice_chip.dart';
```

Thread `propertyId` through both the function and the widget:

```dart
Future<void> showExpenseLinesReviewSheet(
  BuildContext context, {
  required String docId,
  required String propertyId,
  required List<Map<String, dynamic>> initialLines,
}) {
```

passing `propertyId: propertyId,` into the constructed `ExpenseLinesReviewSheet`, and:

```dart
class ExpenseLinesReviewSheet extends ConsumerStatefulWidget {
  final String docId;
  final String propertyId;
  final List<Map<String, dynamic>> initialLines;

  const ExpenseLinesReviewSheet({
    super.key,
    required this.docId,
    required this.propertyId,
    required this.initialLines,
  });
```

In the state class, add:

```dart
  /// Null until the property resolves. Once set it is the chip's selection,
  /// and it starts at the resolved default so the landlord confirms rather
  /// than answers.
  String? _basis;
  bool _savingBasis = false;

  Future<void> _setBasis(String basis) async {
    if (basis == _basis) return; // confirming the pre-set answer writes nothing
    final previous = _basis;
    setState(() {
      _basis = basis;
      _savingBasis = true;
    });
    try {
      await ref.read(setDocumentShareBasisActionProvider)(
        docId: widget.docId,
        shareBasis: basis,
      );
      if (mounted) setState(() => _savingBasis = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _basis = previous;
          _savingBasis = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saving failed: $e')),
        );
      }
    }
  }

  Widget _buildBasisChip(Property property) {
    // 'expenses': this sheet only ever opens for an expenses upload (see the
    // gate in uploadDocumentForCategory), and that category is not one a
    // landlord can except — so it resolves to the property default, which is
    // exactly why this per-document answer exists.
    _basis ??= resolveShareBasis(property: property, category: 'expenses');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('These amounts are:',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'At the full property amount',
              selected: _basis == shareBasisFull,
              onSelected: (_) {
                if (!_savingBasis) _setBasis(shareBasisFull);
              },
            ),
            AppChoiceChip(
              label: 'Already split to my share',
              selected: _basis == shareBasisMine,
              onSelected: (_) {
                if (!_savingBasis) _setBasis(shareBasisMine);
              },
            ),
          ],
        ),
      ],
    );
  }
```

In `build`, above the `Flexible` holding the list, insert the gated chip:

```dart
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final property =
                ref.watch(propertyByIdProvider(widget.propertyId)).value;
            if (property == null) return const SizedBox.shrink();
            final unitShares = (ref
                        .watch(unitsForPropertyStreamProvider(widget.propertyId))
                        .value ??
                    const [])
                .map((u) => u.ownershipShare);
            if (!shareApplies(
                propertyShare: property.ownershipShare, unitShares: unitShares)) {
              return const SizedBox.shrink();
            }
            return _buildBasisChip(property);
          }),
```

and add `import '../../../domain/entities/property.dart';` for `_buildBasisChip`'s parameter type.

- [ ] **Step 6: Pass `propertyId` at both call sites**

In `finance_screen.dart` (`:60-67`), inside `uploadDocumentForCategory`:

```dart
        await showExpenseLinesReviewSheet(
          context,
          docId: uploaded.docId,
          propertyId: propertyId,
          initialLines: [
```

In `documents_screen.dart` (`:1314-1321`):

```dart
          await showExpenseLinesReviewSheet(
            context,
            docId: uploaded.docId,
            propertyId: _selectedPropertyId!,
            initialLines: [
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd residex_app && flutter test test/features/landlord/expense_lines_review_sheet_test.dart`
Expected: PASS, 8 tests (the three existing ones plus five new).

- [ ] **Step 8: Run the suite and the analyzer**

Run: `cd residex_app && flutter test`
Expected: **1 failed** (boilerplate only). `documents_screen_test.dart` and `finance_screen_test.dart` pump the screens that call the sheet; neither uploads, so neither reaches it.

Run: `cd residex_app && flutter analyze`
Expected: **0 errors.** A missed call site is a compile error, not a warning — `propertyId` is required.

Run: `cd backend && py -3.11 -m pytest tests/ -q`
Expected: **0 failed.**

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib/core/constants/api_constants.dart \
  residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart \
  residex_app/lib/features/landlord/presentation/providers/documind_provider.dart \
  residex_app/lib/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart \
  residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart \
  residex_app/lib/features/landlord/presentation/screens/5-Documents/documents_screen.dart \
  residex_app/test/features/landlord/expense_lines_review_sheet_test.dart
git commit -m "feat(finance): confirm a statement's share basis at upload"
```

---

## Manual verification

The automated tests cover the arithmetic and the widgets. This is the end-to-end path they cannot reach, because both answers have to survive a real Firestore round trip and come back through the fold.

1. Take a property at **100%** with at least one document and confirm the finance figures. Note the Direct Expenses total.
2. Edit the property, set its share to **50%**. The question *"How do your documents arrive?"* appears as you type, pre-set to **At the full property amount**. Save.
3. Finance tab: every non-loan figure has halved; loan interest is unchanged. This is today's behaviour and must not have moved.
4. Edit the property again, choose **Already split to my share**, save. Finance tab: the same figures are back at their full values — because the engine now takes them verbatim instead of halving them.
5. Edit once more, open **Any exceptions?**, tap **Assessment & quit rent**, save. Only the tax figures halve; everything else stays whole.
6. Upload a combined expenses statement to that property. The review sheet opens with the chip pre-set to **Already split to my share** (the property default). Change it to **At the full property amount** — that one statement's lines halve while the rest of the property's figures stay as they were.
7. Set the property back to **100%** and confirm the question disappears, the chip stops appearing on upload, and every figure is back where step 1 left it. Nothing about a wholly-owned property is touched by any of this.
8. On a property at **100%** containing one unit at **50%**: the question still appears and the chip still renders. This is the §3a gate, and it is the one thing no amount of clicking around a co-owned property would reveal.

---

## Notes for whoever executes this

- **Tasks 2 and 3 are one behaviour split across two commits.** Between them, expenses honour basis while income still does not. That intermediate state is green only because no existing fixture sets a basis field. Do not ship Task 2 and stop.
- **Task 4 is not optional plumbing.** Tasks 1–3 make the engine correct; without Task 4 the chip in Task 8 writes to a field nothing ever reads, and every backend test stays green. Its second test is the gate.
- **If an existing test fails at any step, stop and report it** — with one named exception, in Task 3 Step 7 (`full_gross_income` on a zero-income unit at a partial share). Every other existing fixture resolves to `full`, so nothing existing should move. A test that needs adjusting means the change did something this plan did not intend.
- **The dedup key does not include `share_basis`.** Two lines identical in unit, category, subtype, description, date and amount but differing in basis collapse to whichever arrived first. That is the existing re-upload dedup working as designed — a re-uploaded bill is the same charge — and splitting the key would make a corrected re-upload double-count instead. Worth knowing if a landlord reports that re-uploading a statement did not change its basis; the fix is the chip on the new upload, not the dedup key.
- The open risk the spec names is unaddressed by design: a landlord who answers "already split" and later changes managing agent will silently under-report until they notice. The flat per-category model is what makes a future sanity check possible.
