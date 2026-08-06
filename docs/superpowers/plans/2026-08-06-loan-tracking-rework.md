# Loan Tracking Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the loan entry-method fork, stop scaling loan interest and principal by ownership share, make "Not sure" honest, and let a landlord record that their mortgage is settled.

**Architecture:** Four independent faults in one subsystem. The fork removal is a field deletion across a known call-site set. The ownership-share fix introduces one predicate (`_line_share`) applied at every point `share` multiplies an expense-derived quantity. The "Not sure" fix is a call-site change in the property dialog's edit-mode save. Settlement adds one atomic `Property` field plus one predicate (`_loan_expected_for`) that the coverage grid, the missing list and the loan-completeness check all read.

**Tech Stack:** Python 3.11 backend (`backend/`, stdlib `unittest` run under pytest), Flutter/Dart app (`residex_app/`, Riverpod, `flutter_test`), Firestore.

**Spec:** `docs/superpowers/specs/2026-08-06-loan-tracking-rework-design.md`

## Global Constraints

- **Never run `git add -A`.** This branch (`feat/finance-tab-restructure`) carries unrelated uncommitted WIP. Every commit lists its file paths explicitly.
- **Never touch, modify or commit** `backend/rexAI.txt`, `backend/scripts/diagnose_ayer8_lease.py`, `backend/scripts/fix_ayer8_lease_facts.py`, or anything under `demo_documents/`.
- **`.env` files are permission-protected — do not read them.**
- **No emoji in app UI.** Icon glyphs only (`Icons.*`). Project convention, applied retroactively.
- **`test/widget_test.dart`'s "Counter increments smoke test" is a pre-existing boilerplate failure.** It must never be "fixed" and its failure is the only acceptable Flutter failure.
- Backend tests: `py -3.11 -m pytest tests/ -q` from `backend/`, using **system Python, not a venv**.
- Flutter tests: `flutter test` from `residex_app/`.
- Riverpod 3.x: `StateProvider` is legacy and needs `import 'package:flutter_riverpod/legacy.dart'`. No task here should need one.
- Backend storage keys are `snake_case`; Dart entity fields are `camelCase`. The mapping lives in `property_model.dart` (`toJson`/`fromJson`) and `backend/rag/property_directory.py`.

---

## Corrections to the spec

Three things the spec states that the code does not support. Each is resolved below; implementers should follow **this plan**, not the spec, where they differ.

**1. `_LOAN_EXEMPT_SUBTYPES` in spec §2 is wrong and would silently miss loan interest.**
The spec proposes `{"loan_interest", "loan_principal"}`. But a *typed* loan document's interest line takes its subtype straight from the extracted facts (`finance_engine.py:367` — `"subtype": facts.get("subtype")`), and that value is `"interest_statement"`, not `"loan_interest"` — confirmed by `_manual_loan_documents` (line 878) which builds `{"subtype": "interest_statement", ...}`, and by the existing assertion in `tests/test_finance_engine.py:1888`. Only the principal line is hardcoded to `"loan_principal"` (line 320). Separately, a *bundled* `expenses` document can carry `loan_interest` / `loan_principal` line items (`EXPENSE_SUBTYPE_CATEGORY` in `fact_extractor.py`).

The correct set is **`{"interest_statement", "loan_interest", "loan_principal"}`**. Keying off `line["category"] == "loan"` instead does **not** work: bundled `loan_principal` maps to category `"loan_principal"`, not `"loan"`.

Had the spec's set shipped, every uploaded loan statement and every manually-entered figure would still have been halved at 50% share — the exact bug this change exists to fix, with a passing-looking test suite.

**2. Spec §1 says to remove `loanInputMethod` from `Property`'s `==` and `hashCode`.** Those are id-only (`property.dart:255-263`) and never referenced the field. Nothing to remove.

**3. Spec §4's settlement control cannot clear the date through `copyWith`.** `Property.copyWith` coalesces every field with `?? this.field`, so `copyWith(mortgageSettledOn: null)` is a no-op — and the spec's non-goals forbid changing that. Task 6 adds a single-purpose `Property.withMortgageSettledOn(String?)` that constructs the entity explicitly. It lives on the entity, beside `copyWith`, so a future field addition is visible in one place rather than silently dropped by a full-field construction copy-pasted into the finance screen.

## File Structure

**Backend**

| File | Responsibility after this plan |
| --- | --- |
| `backend/rag/finance/finance_engine.py` | Adds `_line_share` (per-line ownership weighting) and `_loan_expected_for` (per-period loan expectation). Loses the `loan_input_method` gate. |
| `backend/rag/property_directory.py` | Loses `loan_input_method`, gains `mortgage_settled_on`. |
| `backend/tests/test_finance_engine.py` | Engine behaviour, including the reconciliation gate. |
| `backend/tests/test_documind_service_flows.py` | Property-row passthrough assertions. |

**Frontend**

| File | Responsibility after this plan |
| --- | --- |
| `residex_app/lib/features/landlord/domain/entities/property.dart` | Loses `loanInputMethod`; gains `mortgageSettledOn` + `withMortgageSettledOn`. |
| `.../data/models/property_model.dart` | Serialization for both changes. |
| `.../presentation/widgets/common/add_property_dialog.dart` | Loses the method question; mortgage becomes Yes/No; edit-save stops coalescing; gains the Yes→No confirmation. |
| `.../presentation/screens/5-Documents/documents_screen.dart` | Loans folder unconditional. |
| `.../presentation/screens/3-Finance/finance_screen.dart` | Loan row gated on `hasMortgage`; share copy corrected; settlement control + settled state; completeness denominator. |
| `residex_app/test/features/landlord/property_profile_save_test.dart` | Renamed from `loan_input_method_save_test.dart`; keeps its dialog-through-a-real-save harness. |
| `residex_app/test/features/landlord/documents_loan_folder_test.dart` | Rewritten: the folder is unconditional. |
| `residex_app/test/features/landlord/finance_screen_test.dart` | Loan-row gating, settlement UI. |

**Deleted:** `residex_app/test/features/landlord/loan_input_method_dialog_test.dart` (tests only the removed fork).

## Task order and dependency

```
Task 1 (backend fork) ─┐
Task 2 (frontend fork) ─┼─> Task 3 (§2 share)   [independent of 4-8]
                        ├─> Task 4 (§3a Not sure) ──> Task 5 (§3b confirmation)
                        └─> Task 6 (§4 model) ──> Task 7 (§4 engine) ──> Task 8 (§4 UI)
```

Tasks 1 and 2 are independent of each other (different languages, no shared file) but everything else depends on both. Task 3 is independent of 4–8. Task 8 depends on 7 only for the completeness denominator's backend bound.

**Execution routing** (spec §"Execution routing", carried forward; `routing-plan-execution` decides finally):

- **Direct:** Tasks 1, 2, 4, 5, 6.
- **Subagent-driven-development with independent review:** Tasks 3 and 7. Both rewrite finance-engine logic producing tax figures, and both fail silently — Task 3 by making two totals on one screen disagree, Task 7 by suppressing a year's expectation.
- **Task 8** is presentation work, but its completeness-denominator change is arithmetic the landlord reads as a completeness claim. Recommend direct with the test list below enforced; escalate if the implementer needs to touch anything outside `finance_screen.dart`.

---

### Task 1: Backend — remove the `loan_input_method` gate

**Files:**
- Modify: `backend/rag/finance/finance_engine.py:906-912`
- Modify: `backend/rag/property_directory.py:67`
- Test: `backend/tests/test_finance_engine.py` (class `LoanCompletenessTests`, ~line 1892)
- Test: `backend/tests/test_documind_service_flows.py:2565-2574`

**Interfaces:**
- Consumes: nothing.
- Produces: `_loan_completeness(prop, units, prop_docs, manual_entries, exemptions, year, months)` — unchanged signature, but now returns a real result for **any** property with `has_mortgage is True`, regardless of `loan_input_method`. Property rows from `list_landlord_properties` no longer carry a `loan_input_method` key.

- [ ] **Step 1: Write the failing tests**

In `backend/tests/test_finance_engine.py`, inside `class LoanCompletenessTests`, replace the helper and the last test.

Replace the helper (currently at line ~1893):

```python
    def _prop_mortgaged(self, cadence="annual"):
        return {"property_id": "p1", "name": "Block", "ownership_share": 1.0,
                "has_mortgage": True, "loan_input_cadence": cadence}
```

Update every `self._prop_manual(` call in that class to `self._prop_mortgaged(` (there are five: the four in `test_incomplete_when_a_unit_has_no_figures`, `test_complete_when_every_unit_resolved`, `test_monthly_cadence_needs_all_in_scope_months`, `test_whole_property_scope_complete_when_manual_entry_present`, `test_whole_property_scope_incomplete_when_no_figures`, plus the one in the test being replaced below).

Replace `test_not_evaluated_for_upload_method` (line ~1964) entirely with:

```python
    def test_evaluated_for_any_mortgaged_property(self):
        # The entry-method fork is gone: completeness tracking applies to every
        # mortgaged property, not only ones that once answered "manual".
        summary = _summary(
            documents=[], properties=[self._prop_mortgaged()],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
        )
        block = summary["properties"][0]
        self.assertTrue(block["manual_loan_incomplete"])
        self.assertEqual(block["units"][0]["loan_status"], "incomplete")

    def test_not_evaluated_when_not_mortgaged(self):
        prop = self._prop_mortgaged()
        prop["has_mortgage"] = False
        summary = _summary(
            documents=[], properties=[prop],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
        )
        block = summary["properties"][0]
        self.assertFalse(block["manual_loan_incomplete"])
        self.assertIsNone(block["units"][0]["loan_status"])

    def test_not_evaluated_when_mortgage_unanswered(self):
        prop = self._prop_mortgaged()
        prop["has_mortgage"] = None
        summary = _summary(
            documents=[], properties=[prop],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
        )
        self.assertFalse(summary["properties"][0]["manual_loan_incomplete"])
```

In `backend/tests/test_documind_service_flows.py`, rewrite `test_list_landlord_properties_exposes_loan_prefs` (line 2565):

```python
    async def test_list_landlord_properties_exposes_loan_prefs(self):
        fake_db = _FakeDB()
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "H",
             "loan_input_cadence": "monthly"},
        ]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_landlord_properties("l1")
        self.assertEqual(rows[0]["loan_input_cadence"], "monthly")
        self.assertNotIn("loan_input_method", rows[0])
```

Also delete the stale `"loan_input_method": "manual",` key from the fixture at line 1931 (it is inert once the passthrough is gone, but leaving it implies the field still means something).

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd backend && py -3.11 -m pytest tests/test_finance_engine.py::LoanCompletenessTests tests/test_documind_service_flows.py -q -k "loan"
```

Expected: `test_evaluated_for_any_mortgaged_property` FAILS (`manual_loan_incomplete` is False — the method gate returns early) and `test_list_landlord_properties_exposes_loan_prefs` FAILS on `assertNotIn`.

- [ ] **Step 3: Remove the gate**

`backend/rag/finance/finance_engine.py`, replace lines 906-912:

```python
    """Per-unit loan resolution for the manual-entry button gate. A unit is
    resolved when it is marked no-loan, has an uploaded loan statement for the
    year, or has manual figures covering the cadence (annual: any entry;
    monthly: every in-scope month). Only meaningful for a mortgaged property —
    otherwise returns (False, {})."""
    if prop.get("has_mortgage") is not True:
        return False, {}
```

`backend/rag/property_directory.py`, delete line 67 (`"loan_input_method": data.get('loan_input_method'),`).

- [ ] **Step 4: Run the full backend suite**

```bash
cd backend && py -3.11 -m pytest tests/ -q
```

Expected: PASS, no failures.

- [ ] **Step 5: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/rag/property_directory.py backend/tests/test_finance_engine.py backend/tests/test_documind_service_flows.py
git commit -m "feat(loans): loan completeness applies to every mortgaged property

Removes the loan_input_method gate. A property that never answered the
entry-method question (every existing property) now receives loan
completeness tracking, which is what it should always have had."
```

---

### Task 2: Frontend — delete the `loanInputMethod` field

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/property.dart:142-144, 181, 221, 244`
- Modify: `residex_app/lib/features/landlord/data/models/property_model.dart:23, 49, 76, 114, 155`
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart:47-50, 86, 132-154, 168-169, 194-195, 452-456, 668-755`
- Modify: `residex_app/lib/features/landlord/presentation/screens/5-Documents/documents_screen.dart:46-59, 92`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:300-311`
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart:13`
- Rename + rewrite: `residex_app/test/features/landlord/loan_input_method_save_test.dart` → `residex_app/test/features/landlord/property_profile_save_test.dart`
- Rewrite: `residex_app/test/features/landlord/documents_loan_folder_test.dart`
- Modify: `residex_app/test/features/landlord/finance_screen_test.dart:179-204` and its `_fakeProperty` call sites
- Modify: `residex_app/test/features/landlord/property_profile_fields_test.dart:11, 32, 45, 54, 62, 72, 80`
- Modify: `residex_app/test/features/landlord/add_property_dialog_loan_prefs_test.dart:31-48`
- Delete: `residex_app/test/features/landlord/loan_input_method_dialog_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1 (different language, no shared file).
- Produces: `Property` no longer has a `loanInputMethod` field. `_categoriesFor(Property?)` in `documents_screen.dart` always returns `['lease', 'rental_invoice', 'loan', 'expenses']`. `finance_screen.dart`'s `showManualLoan` is `property?.hasMortgage == true`.

> **This task does not compile until it is finished.** Deleting a field from `Property` breaks every reference at once. Work through the file list in order (entity → model → screens → dialog → tests) and only run `flutter test` at the end.

- [ ] **Step 1: Rewrite the folder test to the new expectation**

Replace the body of `residex_app/test/features/landlord/documents_loan_folder_test.dart`. Keep the file's existing imports, the `_pump...` harness and the `propertyWith` helper, but drop `loanInputMethod` from the helper's parameters and from the `Property(...)` it builds, then replace the four tests at lines 49-121 with:

```dart
  testWidgets('the Loans & Financing tile is shown for a mortgaged property',
      (tester) async {
    await _pumpDocuments(tester, propertyWith(hasMortgage: true));
    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('the Loans & Financing tile is shown for an unmortgaged property',
      (tester) async {
    await _pumpDocuments(tester, propertyWith(hasMortgage: false));
    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('the Loans & Financing tile is shown when the mortgage question '
      'is unanswered', (tester) async {
    await _pumpDocuments(tester, propertyWith(hasMortgage: null));
    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('the Loans & Financing tile is shown when the property fails to load',
      (tester) async {
    await _pumpDocuments(tester, null);
    expect(find.text('Loans & Financing'), findsOneWidget);
  });
```

Adapt `_pumpDocuments` / `propertyWith` to the names already in the file (the current helper is `propertyWith(String? loanInputMethod)` at line 16; widen it to `propertyWith({bool? hasMortgage})` and make the property override nullable so the failed-load case can pass `null`). The test at line 80 (`neither folder state offers manual entry`) and line 122 stay as they are — they assert the nudge never offers manual entry, which is still true.

- [ ] **Step 2: Run it to verify it fails**

```bash
cd residex_app && flutter test test/features/landlord/documents_loan_folder_test.dart
```

Expected: the first test FAILS — a mortgaged property built with the old default still hits the `loanInputMethod == 'manual'` branch only if the helper set it; more reliably, the file will not compile once `propertyWith` drops the parameter. Either failure is the signal to proceed.

- [ ] **Step 3: Remove the field from the entity and model**

`property.dart`: delete lines 142-144 (the doc comment and `final String? loanInputMethod;`), line 181 (`this.loanInputMethod,`), line 221 (`String? loanInputMethod,`) and line 244 (`loanInputMethod: loanInputMethod ?? this.loanInputMethod,`). Leave `==` and `hashCode` alone — they are id-only and never referenced the field.

`property_model.dart`: delete line 23 (`super.loanInputMethod,`), line 49, line 76, line 114 and line 155.

- [ ] **Step 4: Remove the field from the screens**

`documents_screen.dart`, replace lines 46-59:

```dart
  // Display folders (stored categories collapse via displayCategoryFor;
  // uploads from the Expenses folder send category 'expenses' so the
  // backend runs line-item extraction).
  //
  // Every folder is unconditional. Loans was once hidden for landlords who
  // answered "I'll type the figures" at registration; that fork is gone —
  // upload to the folder or type at the finance panel, both always available.
  List<String> _categoriesFor(Property? property) =>
      const ['lease', 'rental_invoice', 'loan', 'expenses'];
```

The stale-selection fallback at lines 257-274 becomes unreachable (the returned list is now constant, so `_selectedCategory` can never fall outside it). Delete the `if` block at lines 261-274 along with its comment at 258-260, and delete the now-stale mention of the Loans folder in the comment at line 92. Leave `_categoriesFor` itself in place — line 415 still calls it, and keeping the single accessor means a future conditional folder has one place to live.

`finance_screen.dart`, replace lines 300-311:

```dart
    final rawMissing = summary.missingCategories[block.propertyId] ?? const [];
    // 'loan' nudges like any other category: a mortgaged property with no
    // figures booked by either route genuinely is missing a document.
    final missing = rawMissing;
    // Both loan routes are always available, so the panel row — the
    // discoverable manual route — is shown for any mortgaged property.
    final showManualLoan = property?.hasMortgage == true;
```

(Keep `rawMissing`/`missing` as two names only if the intermediate reads better; collapsing to a single `missing` local is equally acceptable and is what a reviewer will expect.)

`manual_loan_entry_sheet.dart:13`: reword the doc comment so it no longer says `loanInputMethod == 'manual'`. Replace that clause with "opened from the finance panel's loan figures row".

- [ ] **Step 5: Remove the question from the dialog**

`add_property_dialog.dart`:
- Delete lines 47-50 (the `_loanInputMethod` doc comment and field).
- Delete line 86 (`_loanInputMethod = property.loanInputMethod;`).
- Delete lines 453-456 (the `if (_hasMortgage == true) ... _buildLoanMethodSelector()` block), leaving `_buildMortgageSelector()` at line 452 followed directly by `const SizedBox(height: 16)` and `_buildYearPicker()`.
- Delete `_buildLoanMethodSelector` and `_loanMethodCard` entirely (lines 668-755).
- In the edit branch, delete lines 136-154 (the whole `copyWith`/`effectiveHasMortgage` comment block and the `effectiveHasMortgage` local) and line 169 (`loanInputMethod: ...`). Replace `hasMortgage: effectiveHasMortgage,` at line 165 with `hasMortgage: _hasMortgage ?? existing.hasMortgage,` for now — **Task 4 changes this line again**; leaving it coalescing here keeps this task purely a field deletion with no behaviour change. Keep a short comment explaining why the branch constructs `Property` explicitly rather than using `copyWith` (copyWith cannot clear a nullable field).
- Delete line 195 (`loanInputMethod: ...`) from the create branch.

- [ ] **Step 6: Update the remaining tests**

- Delete `residex_app/test/features/landlord/loan_input_method_dialog_test.dart`. Every one of its four tests asserts the presence or selection of the removed cards.
- Rename `loan_input_method_save_test.dart` to `property_profile_save_test.dart` (`git mv`). Keep lines 1-219 (the fake repositories, `_property`, `_openEditDialog`, `_tap`, `_openCreateDialog`, `_submitCreateDialog`, `_dismissRegistrationSteps`) with two edits: drop the `loanInputMethod` parameter from `_property` and from `_openEditDialog`, and update the file's header comment to describe what it now covers (the dialog's save path, driven through a real fake repository). In `main()`, delete every test from line 269 to 343 and rewrite the two at 222 and 242:

```dart
void main() {
  testWidgets('answering No on a mortgaged property writes hasMortgage false',
      (tester) async {
    final fakeRepo = await _openEditDialog(tester, hasMortgage: true);

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated, isNotNull);
    expect(fakeRepo.lastUpdated!.hasMortgage, false);
  });

  testWidgets('creating a property with Yes writes hasMortgage true',
      (tester) async {
    final fakeRepo = await _openCreateDialog(tester);

    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();

    await _submitCreateDialog(tester);

    expect(fakeRepo.lastCreated, isNotNull);
    expect(fakeRepo.lastCreated!.hasMortgage, true);

    await _dismissRegistrationSteps(tester);
  });
}
```

Both helpers stay in use, so no private element goes unreferenced.

- `finance_screen_test.dart`: drop the `loanInputMethod` parameter from `_fakeProperty` (lines 179-204) and default `loanInputCadence` to `'annual'` when it is not passed. Update every `_fakeProperty(...)` call to drop the argument. Then fix the tests that no longer describe reality:
  - line 241 `"Add loan figures" is hidden when loanInputMethod is manual but hasMortgage is not true` → rename to `"Add loan figures" is hidden when hasMortgage is not true`.
  - line 280 → rename to `"Add loan figures" shows for a mortgaged property`.
  - line 304 (`hasMortgage: true, loanInputMethod: null`) previously asserted the row was **hidden**. It must now assert the row is **shown** — this is the documented dead end the rework exists to close. Rewrite the assertion and its comment accordingly.
  - line 339 (`loanInputMethod: 'upload'`) and line 377 (`loan button depends only on loanInputMethod`) are about the removed fork. Delete both.
  - line 534 (`_fakeProperty(hasMortgage: true, loanInputMethod: 'upload')`) previously asserted the loan nudge was **not** filtered. With `missing` no longer filtered at all, fold it into whichever neighbouring test asserts the nudge count, or delete it as redundant.
- `property_profile_fields_test.dart`: drop `loanInputMethod` from the helper (lines 11, 32) and delete the four assertions at 45/54, 62, 72, 80 that reference it.
- `add_property_dialog_loan_prefs_test.dart`: the test at line 31 (`cadence question stays gone; loan method question is back under new wording`) asserts the method question is present. Rewrite it to assert both questions are absent:

```dart
  testWidgets('neither the cadence nor the loan method question is asked',
      (tester) async {
    await _pumpDialog(tester);
    expect(find.textContaining('How often'), findsNothing);
    expect(find.textContaining('How will loan figures arrive'), findsNothing);
    expect(find.text('Upload statements'), findsNothing);
    expect(find.text('Enter figures myself'), findsNothing);
  });
```

Use whatever pump helper the file already defines; if it inlines `pumpWidget`, inline it here the same way.

- [ ] **Step 7: Run the full Flutter suite**

```bash
cd residex_app && flutter analyze && flutter test
```

Expected: `flutter analyze` clean of new warnings; `flutter test` green except the pre-existing `test/widget_test.dart` "Counter increments smoke test" failure.

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/property.dart \
        residex_app/lib/features/landlord/data/models/property_model.dart \
        residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart \
        residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart \
        residex_app/lib/features/landlord/presentation/screens/5-Documents/documents_screen.dart \
        residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart \
        residex_app/test/features/landlord/
git commit -m "feat(loans): delete the loan entry-method fork

Both routes are permanently available: upload to the Loans & Financing
folder, or type figures at the property panel. The folder is
unconditional and the panel row is gated on hasMortgage alone, which
closes the dead end where every existing property (loanInputMethod null)
had no route to manual entry at all."
```

---

### Task 3: Loan interest and principal are never scaled by ownership share

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` — new `_line_share` near line 427, then lines 427-444, 1068-1074, 1085-1110, 1139-1147, 1177, 1188-1190, 1212-1220
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:392-398`
- Test: `backend/tests/test_finance_engine.py` (new class `LoanShareExemptionTests`)

**Interfaces:**
- Consumes: Task 1's `_loan_completeness` (unchanged signature).
- Produces: `_line_share(line: Dict[str, Any], share: float) -> float` and `_LOAN_EXEMPT_SUBTYPES: set[str]`, both module-private in `finance_engine.py`. `_scaled_lines(lines, share)` keeps its signature; loan lines in its output carry **no** `full_amount` key even when `share < 1.0`.

> **All eight sites change together.** The failure mode is not a crash — it is two totals on the same screen quietly disagreeing. Step 1's reconciliation test is the gate that catches a missed site; do not weaken it.

- [ ] **Step 1: Write the failing tests**

Add to `backend/tests/test_finance_engine.py`:

```python
class LoanShareExemptionTests(unittest.TestCase):
    """Loan interest and principal are the landlord's own borrowing, not a
    cost shared with co-owners, so they pass through at face value at any
    ownership share. Every other expense line still scales."""

    def _docs(self):
        return [
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 8200.0, "principal_paid": 3000.0}),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 1000.0, "period_year": 2025},
            ]}),
        ]

    def test_direct_expenses_reconciles_against_its_own_lines_at_half_share(self):
        # THE GATE. direct_expenses must equal the sum of the deductible
        # expense_lines the app renders beneath it. A site missed in the
        # per-line conversion breaks this and nothing else.
        result = _summary(self._docs(), [_prop("p1", "Block", share=0.5)])
        block = result["properties"][0]
        deductible = [l for l in block["expense_lines"] if l["deductible"]]
        self.assertAlmostEqual(
            block["direct_expenses"], sum(l["amount"] for l in deductible), places=2
        )

    def test_direct_expenses_reconciles_at_full_share(self):
        result = _summary(self._docs(), [_prop("p1", "Block", share=1.0)])
        block = result["properties"][0]
        deductible = [l for l in block["expense_lines"] if l["deductible"]]
        self.assertAlmostEqual(
            block["direct_expenses"], sum(l["amount"] for l in deductible), places=2
        )

    def test_loan_interest_is_whole_and_other_expenses_are_halved(self):
        result = _summary(self._docs(), [_prop("p1", "Block", share=0.5)])
        block = result["properties"][0]
        by_subtype = {l["subtype"]: l for l in block["expense_lines"]}
        self.assertEqual(by_subtype["interest_statement"]["amount"], 8200.0)
        self.assertEqual(by_subtype["loan_principal"]["amount"], 3000.0)
        self.assertEqual(by_subtype["maintenance"]["amount"], 500.0)
        # 8200 (whole) + 500 (half of 1000); principal is never deductible.
        self.assertAlmostEqual(block["direct_expenses"], 8700.0, places=2)

    def test_loan_lines_carry_no_full_amount_and_others_do(self):
        result = _summary(self._docs(), [_prop("p1", "Block", share=0.5)])
        by_subtype = {l["subtype"]: l
                      for l in result["properties"][0]["expense_lines"]}
        self.assertNotIn("full_amount", by_subtype["interest_statement"])
        self.assertNotIn("full_amount", by_subtype["loan_principal"])
        self.assertEqual(by_subtype["maintenance"]["full_amount"], 1000.0)

    def test_principal_passes_whole_through_landlord_expenses_and_net_pl(self):
        result = _summary(self._docs(), [_prop("p1", "Block", share=0.5)])
        block = result["properties"][0]
        # landlord_expenses = 8200 interest + 3000 principal (both whole)
        #                     + 500 maintenance (halved)
        self.assertAlmostEqual(block["landlord_expenses"], 11700.0, places=2)
        self.assertAlmostEqual(
            block["net_pl"], block["received_rent"] - 11700.0, places=2
        )

    def test_expense_breakdown_matches_the_lines(self):
        result = _summary(self._docs(), [_prop("p1", "Block", share=0.5)])
        breakdown = result["expense_breakdown"]
        self.assertAlmostEqual(breakdown["loan"], 8200.0, places=2)
        self.assertAlmostEqual(breakdown["maintenance"], 500.0, places=2)

    def test_bundled_expenses_loan_lines_are_exempt_too(self):
        # A bundled 'expenses' statement carries subtype 'loan_interest',
        # not 'interest_statement' — both must be exempt.
        docs = [_doc("p1", "expenses", {"expense_lines": [
            {"subtype": "loan_interest", "amount": 4000.0, "period_year": 2025},
            {"subtype": "loan_principal", "amount": 2000.0, "period_year": 2025},
        ]})]
        result = _summary(docs, [_prop("p1", "Block", share=0.5)])
        by_subtype = {l["subtype"]: l
                      for l in result["properties"][0]["expense_lines"]}
        self.assertEqual(by_subtype["loan_interest"]["amount"], 4000.0)
        self.assertEqual(by_subtype["loan_principal"]["amount"], 2000.0)

    def test_unit_scoped_loan_lines_are_exempt(self):
        docs = [
            _doc("p1", "loan", {"subtype": "interest_statement", "period_year": 2025,
                                "interest_paid": 1200.0}, unit_id="u1"),
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u1"),
        ]
        result = _summary(docs, [_prop("p1", "Block", share=0.5)],
                          units={"p1": [{"unit_id": "u1", "label": "A-1"}]})
        unit = result["properties"][0]["units"][0]
        loan = next(l for l in unit["expense_lines"]
                    if l["subtype"] == "interest_statement")
        self.assertEqual(loan["amount"], 1200.0)

    def test_full_share_property_is_unchanged(self):
        # The overwhelmingly common case must be byte-identical to before.
        docs = self._docs()
        result = _summary(docs, [_prop("p1", "Block", share=1.0)])
        block = result["properties"][0]
        self.assertAlmostEqual(block["direct_expenses"], 9200.0, places=2)
        self.assertAlmostEqual(block["landlord_expenses"], 12200.0, places=2)
        for line in block["expense_lines"]:
            self.assertNotIn("full_amount", line)
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd backend && py -3.11 -m pytest tests/test_finance_engine.py::LoanShareExemptionTests -q
```

Expected: `test_loan_interest_is_whole_and_other_expenses_are_halved` FAILS with `4100.0 != 8200.0` (interest halved). Note that the two reconciliation tests may **pass** before the change — today every line scales uniformly, so they already reconcile. They are the regression gate for the change, not its trigger.

- [ ] **Step 3: Add the predicate**

Insert immediately above `_scaled_lines` in `backend/rag/finance/finance_engine.py` (before line 427):

```python
# A typed loan document's interest line takes its subtype straight from the
# extracted facts ('interest_statement'); its principal line is hardcoded to
# 'loan_principal'. A bundled 'expenses' statement uses 'loan_interest' /
# 'loan_principal'. All four spellings must be here — keying off
# line["category"] == "loan" does NOT work, because a bundled principal line
# maps to category 'loan_principal', not 'loan'.
_LOAN_EXEMPT_SUBTYPES = {"interest_statement", "loan_interest", "loan_principal"}


def _line_share(line: Dict[str, Any], share: float) -> float:
    """Loan interest and principal are the landlord's own borrowing, not a cost
    shared with co-owners, so they are never scaled by ownership share. Every
    other expense line scales normally."""
    return 1.0 if line.get("subtype") in _LOAN_EXEMPT_SUBTYPES else share
```

- [ ] **Step 4: Convert all eight sites**

**(a) `_scaled_lines` (line 427).** Signature and the `share == 1.0` early return stay; `full_amount` is emitted only for lines actually scaled:

```python
def _scaled_lines(lines: List[Dict[str, Any]], share: float) -> List[Dict[str, Any]]:
    """Copy expense lines with amounts at the landlord's ownership share.

    Never mutates the input. The unscaled lines stay the basis for every
    property-level sum, so scaling is applied exactly once and no sum can be
    scaled twice. At share 1.0 the lines are returned unchanged (no
    `full_amount`), so the overwhelmingly common case is byte-identical to
    before. Below 1.0 each scaled line also carries `full_amount`, the source
    document's face value, so the app can show "your 50% of RM 1,200.00"
    beside the scaled figure. Loan lines (see _line_share) are not scaled and
    so carry no `full_amount` — there is no second figure to show."""
    if share == 1.0:
        return list(lines)
    out: List[Dict[str, Any]] = []
    for line in lines:
        line_share = _line_share(line, share)
        if line_share == 1.0:
            out.append(dict(line))
            continue
        out.append({**line,
                    "amount": _round2(line_share * line["amount"]),
                    "full_amount": _round2(line["amount"])})
    return out
```

**(b) unit proration (lines 1068-1074).** Replace `unit_deductible_total` with a per-line-weighted sum:

```python
            # Proration keeps using the real-unit lines only. The property-level
            # lines are prorated once, below, by avg_fraction — feeding them in
            # here as well would double-count them in the statutory total.
            prorated_expenses += fraction * sum(
                _line_share(l, share) * l["amount"] for l in unit_lines if l["deductible"]
            )
```

**(c)/(d) unit `contribution` and `statutory_contribution` (lines 1085-1110).** Replace the two `display_*_total` locals with already-weighted sums and take the `share *` off the expense term only:

```python
            display_deductible_scaled = sum(
                _line_share(l, share) * l["amount"]
                for l in display_lines if l["deductible"]
            )
            display_landlord_scaled = sum(
                _line_share(l, share) * l["amount"]
                for l in display_lines if l["paid_by_landlord"]
            )
```

and in the `unit_blocks.append({...})` dict:

```python
                "contribution": _round2(
                    share * (actual_sum + derived_sum) - display_landlord_scaled
                ),
                "statutory_contribution": _round2(
                    share * (actual_sum + derived_sum) - display_deductible_scaled
                ),
```

**Income keeps its `share *`.** Only the expense term moved inside.

**(e) property-level proration (lines 1141-1143):**

```python
        prorated_expenses += avg_fraction * sum(
            _line_share(l, share) * l["amount"]
            for l in property_level_lines if l["deductible"]
        )
```

**(f) `landlord_paid` (line 1147):**

```python
        landlord_paid = sum(
            _line_share(l, share) * l["amount"]
            for l in expense_lines if l["paid_by_landlord"]
        )
```

**(g) `direct` (line 1177):**

```python
        direct = sum(
            _line_share(l, share) * l["amount"] for l in expense_lines if l["deductible"]
        )
```

**Then lines 1179-1190**: the three expense accumulators are already weighted, so drop their trailing `share *`. Keep the `s_` names — everything downstream reads them. Do **not** add `_round2` here; the existing values are unrounded and the output dict rounds at the boundary.

```python
        # Ownership share is applied once, here, to every *income* figure this
        # property contributes; expense figures are already per-line weighted
        # above (see _line_share), because loan interest and principal are not
        # shared with co-owners. The already-scaled values then feed the
        # cross-property totals. Each property carries its own share, so a
        # total can never be correctly scaled after the fact.
        s_received = share * received
        s_derived = share * prop_derived
        s_outstanding = share * prop_outstanding
        s_direct = direct
        s_landlord_paid = landlord_paid
        s_prorated = prorated_expenses
```

**(h) `expense_breakdown` (line 1219):**

```python
            expense_breakdown[line["category"]] = _round2(
                expense_breakdown.get(line["category"], 0.0)
                + _line_share(line, share) * line["amount"]
            )
```

**Leave `excluded` (line 1222) alone.** It sums non-deductible amounts unscaled while every other displayed figure is scaled. That is a pre-existing inconsistency, not introduced here, and the spec deliberately leaves it. Do not "fix" it.

- [ ] **Step 5: Correct the copy in both places**

`backend/rag/finance/finance_engine.py:1213`:

```python
        if share < 1.0:
            share_notes.append(
                f"Ownership share applied: {name} at {share:.0%}. Loan interest "
                "and principal are shown in full — they are your own borrowing."
            )
```

`residex_app/.../3-Finance/finance_screen.dart:392-398`:

```dart
          if (block.ownershipShare < 1.0) ...[
            const SizedBox(height: 4),
            Text(
              'Shown at your ${(block.ownershipShare * 100).toStringAsFixed(0)}% share. '
              'Loan interest and principal are shown in full.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
```

**`_buildLoanFiguresRow` needs no change.** It already reads raw booked entries rather than expense lines (`finance_screen.dart:500-507`) — a deliberate carve-out against exactly this scaling. It now stops being a special case and simply agrees with the engine. Update its doc comment to say so.

- [ ] **Step 6: Run the tests**

```bash
cd backend && py -3.11 -m pytest tests/ -q
cd ../residex_app && flutter test
```

Expected: backend green; Flutter green except the known `widget_test.dart` boilerplate failure. If any *existing* backend test that asserts a share-scaled loan figure fails, it is asserting the old (wrong) behaviour — update it and say so in the commit message.

- [ ] **Step 7: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py \
        residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart
git commit -m "fix(finance): stop scaling loan interest and principal by ownership share

A landlord owning 50% who is the sole borrower saw half their loan
interest in Direct Expenses, statutory and net P&L. Ownership weighting
now runs per line (_line_share) instead of once per property, and loan
lines pass through whole. Guarded by a reconciliation test asserting
direct_expenses equals the sum of its own deductible lines at both 1.0
and 0.5 share, which is what catches a missed site."
```

---

### Task 4: The mortgage question becomes Yes/No, and edit-mode save stops coalescing

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart:132-166, 637-666`
- Test: `residex_app/test/features/landlord/property_profile_save_test.dart` (renamed in Task 2)

**Interfaces:**
- Consumes: Task 2's `add_property_dialog.dart` (no `_loanInputMethod`, no `effectiveHasMortgage`).
- Produces: the edit branch writes `structureType`, `hasMortgage` and `trackFromYear` raw from state. `_buildMortgageSelector` renders exactly two chips.

- [ ] **Step 1: Write the failing tests**

Add to `residex_app/test/features/landlord/property_profile_save_test.dart`:

```dart
  testWidgets('the mortgage question offers Yes and No only', (tester) async {
    await _openEditDialog(tester, hasMortgage: true);

    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    // "Not sure" survives on the structure-type question for commercial
    // properties and in the track-from-year picker's label; this property is
    // a condo, so neither is on screen and a bare finder is unambiguous.
    expect(find.text('Not sure'), findsNothing);
  });

  testWidgets('a property with an unanswered mortgage shows neither chip selected',
      (tester) async {
    final fakeRepo = await _openEditDialog(tester, hasMortgage: null);

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    // Nothing was tapped, so nothing was answered — and the save must not
    // invent an answer.
    expect(fakeRepo.lastUpdated!.hasMortgage, isNull);
  });

  testWidgets('selecting "Not sure" for structure type persists null on save',
      (tester) async {
    // The bug: edit-mode save coalesced every field with `?? existing.field`,
    // so tapping "Not sure" on an already-answered property was a no-op.
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true, type: PropertyType.commercial,
      structureType: PropertyStructureType.strata,
    );

    await _tap(tester, find.text('Not sure'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.structureType, isNull);
  });

  testWidgets('selecting "Not sure" for track-from year persists null on save',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true, trackFromYear: 2024,
    );

    await _tap(tester, find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Not sure (default)'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.trackFromYear, isNull);
  });
```

Widen `_property` and `_openEditDialog` with optional `PropertyType type = PropertyType.condo`, `PropertyStructureType? structureType`, `int? trackFromYear` parameters, threading each into the `Property(...)` construction. `_openEditDialog` already returns the fake repo; every test above reads it from that return value.

- [ ] **Step 2: Run to verify they fail**

```bash
cd residex_app && flutter test test/features/landlord/property_profile_save_test.dart
```

Expected: the "Not sure" tests FAIL (`structureType` comes back `strata`, `trackFromYear` comes back `2024` — coalesced), and the Yes/No test FAILS finding a third chip.

- [ ] **Step 3: Remove the "Not sure" mortgage chip**

`add_property_dialog.dart`, delete lines 657-661 — the third `AppChoiceChip`. Add a comment above the `Wrap`:

```dart
        // Yes/No only. A property owner is not unsure whether they have a
        // mortgage; the third chip existed because null was the initial state,
        // and a property that has never answered simply shows neither chip
        // selected. structureType and trackFromYear keep their "Not sure" —
        // title type and tracking start are real unknowns.
```

- [ ] **Step 4: Stop coalescing on save**

In the edit branch (around lines 164-166), replace the three coalescing writes:

```dart
          // Written raw from state, not coalesced with `?? existing.field`:
          // initState seeds all three from the existing property, so the state
          // variable *is* the landlord's current answer, and coalescing could
          // only ever undo a deliberate "Not sure".
          structureType: _selectedStructureType,
          hasMortgage: _hasMortgage,
          trackFromYear: _trackFromYear,
```

- [ ] **Step 5: Run the tests**

```bash
cd residex_app && flutter test
```

Expected: green except the known `widget_test.dart` failure.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart \
        residex_app/test/features/landlord/property_profile_save_test.dart
git commit -m "fix(properties): make \"Not sure\" persist, and drop it from the mortgage question

Edit-mode save coalesced structureType/hasMortgage/trackFromYear with
`?? existing.field`, so tapping \"Not sure\" on an already-answered
property did nothing. They are now written raw from state. The mortgage
question is Yes/No — an owner is not unsure whether they have one."
```

---

### Task 5: Confirm before switching a mortgaged property with booked figures to "No"

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart` (`_handleSubmit`, around line 106)
- Test: `residex_app/test/features/landlord/property_profile_save_test.dart`

**Interfaces:**
- Consumes: Task 4's raw-from-state edit branch.
- Produces: `_handleSubmit` awaits a confirmation before saving when the edit branch is flipping `hasMortgage` from `true` to `false` **and** the property has booked loan figures for the current year. Reads `manualLoanEntriesProvider((propertyId: existing.id, year: DateTime.now().year))`.

- [ ] **Step 1: Write the failing tests**

```dart
  testWidgets('flipping Yes to No with booked figures raises a confirmation',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {'interest_paid': 8200.0, 'principal_paid': 0.0, 'month': null, 'unit_id': null},
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Remove loan tracking for this property?'), findsOneWidget);
    expect(find.textContaining('RM 8,200.00'), findsOneWidget);
    expect(find.textContaining('mark it settled instead'), findsOneWidget);
    expect(fakeRepo.lastUpdated, isNull, reason: 'nothing saves until confirmed');
  });

  testWidgets('cancelling the confirmation restores Yes and saves nothing',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {'interest_paid': 8200.0, 'principal_paid': 0.0, 'month': null, 'unit_id': null},
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated, isNull);
    // The Yes chip is selected again, so the dialog does not sit in a state
    // that contradicts what is stored.
    final yes = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'Yes'),
    );
    expect(yes.selected, isTrue);
  });

  testWidgets('confirming saves hasMortgage false', (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {'interest_paid': 8200.0, 'principal_paid': 0.0, 'month': null, 'unit_id': null},
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Remove tracking'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.hasMortgage, false);
  });

  testWidgets('flipping Yes to No with no booked figures saves without asking',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true, loanEntries: const [],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Remove loan tracking for this property?'), findsNothing);
    expect(fakeRepo.lastUpdated!.hasMortgage, false);
  });
```

Add a `List<Map<String, dynamic>>? loanEntries` parameter to `_openEditDialog` and, when it is non-null, add `manualLoanEntriesProvider.overrideWith((ref, args) async => loanEntries)` to the `ProviderScope` overrides. Import `finance_providers.dart` (or wherever `manualLoanEntriesProvider` is declared — `documind_provider.dart` per `finance_screen_test.dart`'s imports) and `app_choice_chip.dart`.

If `AppChoiceChip` does not expose a public `selected` field, assert the restored state by a means the widget does support (e.g. re-tapping Save and observing the confirmation appears again is **not** acceptable — it proves nothing about the chip). Prefer adding a zero-size keyed probe to `AppChoiceChip` the way `_loanMethodCard` did (`Key('mortgage-yes-selected')`), which is the pattern this codebase already uses for exactly this problem.

- [ ] **Step 2: Run to verify they fail**

```bash
cd residex_app && flutter test test/features/landlord/property_profile_save_test.dart
```

Expected: the first three FAIL — no confirmation is shown and the save goes straight through.

- [ ] **Step 3: Implement the confirmation**

In `add_property_dialog.dart`, add above `_handleSubmit`:

```dart
  /// "No" means *never had a mortgage* — it retroactively stops expecting loan
  /// figures for every historical year. A landlord who has simply finished
  /// paying wants settlement instead, which keeps history intact. Naming the
  /// right tool here is what stops them reaching for the destructive one.
  ///
  /// Returns true when the save may proceed.
  Future<bool> _confirmRemovingLoanTracking(Property existing) async {
    if (!(existing.hasMortgage == true && _hasMortgage == false)) return true;

    final entries = await ref.read(
      manualLoanEntriesProvider(
        (propertyId: existing.id, year: DateTime.now().year),
      ).future,
    );
    if (entries.isEmpty) return true;

    final booked = entries.fold<double>(
      0,
      (total, e) =>
          total +
          ((e['interest_paid'] as num?)?.toDouble() ?? 0) +
          ((e['principal_paid'] as num?)?.toDouble() ?? 0),
    );

    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Remove loan tracking for this property?',
            style: AppTextStyles.titleMedium),
        content: Text(
          'This property has ${formatRM(booked)} of ${DateTime.now().year} loan '
          "figures recorded. They'll stay in your finance totals but will no "
          'longer be visible or editable.\n\n'
          'If your mortgage is fully repaid, mark it settled instead so your '
          'past years stay accurate.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove tracking'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      // Restore the stored answer so the form never sits contradicting what
      // is saved.
      if (mounted) setState(() => _hasMortgage = true);
      return false;
    }
    return true;
  }
```

Call it in `_handleSubmit`'s edit branch, **before** `setState(() => _isLoading = true)` so the spinner never runs behind a modal:

```dart
    final existing = widget.property;
    if (existing != null && !await _confirmRemovingLoanTracking(existing)) {
      return;
    }

    setState(() => _isLoading = true);
```

This requires moving the `final existing = widget.property;` read (currently line 130) above the `setState`, and reusing that local in the branch below rather than re-reading it. Import `formatRM` from wherever `finance_screen.dart` imports it.

- [ ] **Step 4: Run the tests**

```bash
cd residex_app && flutter test
```

Expected: green except the known `widget_test.dart` failure.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart \
        residex_app/test/features/landlord/property_profile_save_test.dart
git commit -m "feat(loans): confirm before answering No on a property with booked figures

\"No\" means never had a mortgage and retroactively stops expecting loan
figures for every historical year. The confirmation says the figures are
kept, and points at settlement as the non-destructive alternative."
```

---

### Task 6: `mortgageSettledOn` — model and persistence

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/property.dart` (field, constructor, `copyWith`, new `withMortgageSettledOn`)
- Modify: `residex_app/lib/features/landlord/data/models/property_model.dart` (constructor, `fromEntity`, `toEntity`, `fromJson`, `toJson`)
- Modify: `backend/rag/property_directory.py:58-68`
- Test: `residex_app/test/features/landlord/property_profile_fields_test.dart`
- Test: `backend/tests/test_documind_service_flows.py` (`test_list_landlord_properties_exposes_loan_prefs`)

**Interfaces:**
- Consumes: Task 2's `Property` (no `loanInputMethod`).
- Produces:
  - `Property.mortgageSettledOn` — `String?` in `'YYYY-MM'` form. Atomic rather than a year/month pair so it cannot land half-set.
  - `Property.withMortgageSettledOn(String? value) -> Property` — the **only** way to clear it; `copyWith` cannot (`?? this.field`).
  - Firestore/JSON key `mortgage_settled_on`.
  - Backend property rows carry `"mortgage_settled_on"`, consumed by Task 7.

- [ ] **Step 1: Write the failing tests**

Add to `residex_app/test/features/landlord/property_profile_fields_test.dart` (following the file's existing helper style, which builds a JSON map and round-trips it):

```dart
  test('mortgage_settled_on round-trips through the model', () {
    final model = PropertyModel.fromJson(
      _json(mortgageSettledOn: '2027-03'), 'p1',
    );
    expect(model.mortgageSettledOn, '2027-03');
    expect(model.toJson()['mortgage_settled_on'], '2027-03');
  });

  test('an absent mortgage_settled_on parses as null', () {
    final model = PropertyModel.fromJson(_json(), 'p1');
    expect(model.mortgageSettledOn, isNull);
    expect(model.toJson()['mortgage_settled_on'], isNull);
  });

  test('withMortgageSettledOn can clear the date, which copyWith cannot', () {
    final settled = PropertyModel.fromJson(
      _json(mortgageSettledOn: '2027-03'), 'p1',
    ).toEntity();

    expect(settled.copyWith(mortgageSettledOn: null).mortgageSettledOn, '2027-03',
        reason: 'copyWith coalesces — this is why withMortgageSettledOn exists');
    expect(settled.withMortgageSettledOn(null).mortgageSettledOn, isNull);
    expect(settled.withMortgageSettledOn('2028-01').mortgageSettledOn, '2028-01');
  });

  test('withMortgageSettledOn preserves every other field', () {
    final before = PropertyModel.fromJson(
      _json(mortgageSettledOn: '2027-03'), 'p1',
    ).toEntity();
    final after = before.withMortgageSettledOn(null);

    expect(after.id, before.id);
    expect(after.landlordId, before.landlordId);
    expect(after.name, before.name);
    expect(after.type, before.type);
    expect(after.purchasePrice, before.purchasePrice);
    expect(after.currentValue, before.currentValue);
    expect(after.ownershipShare, before.ownershipShare);
    expect(after.structureType, before.structureType);
    expect(after.hasMortgage, before.hasMortgage);
    expect(after.trackFromYear, before.trackFromYear);
    expect(after.utilitiesPaidBy, before.utilitiesPaidBy);
    expect(after.loanInputCadence, before.loanInputCadence);
    expect(after.nextSetupStep, before.nextSetupStep);
    expect(after.foldersEnabled, before.foldersEnabled);
    expect(after.folderNames, before.folderNames);
    expect(after.folderMoves, before.folderMoves);
    expect(after.photos, before.photos);
    expect(after.createdAt, before.createdAt);
    expect(after.updatedAt, before.updatedAt);
  });
```

Add a `String? mortgageSettledOn` parameter to the file's existing `_json` helper (line 11 area), emitting `if (mortgageSettledOn != null) 'mortgage_settled_on': mortgageSettledOn,`.

The last test is the one that matters: `withMortgageSettledOn` constructs `Property` explicitly, and a field added to the entity later would be silently dropped without it.

In `backend/tests/test_documind_service_flows.py`, extend the property-row test:

```python
    async def test_list_landlord_properties_exposes_loan_prefs(self):
        fake_db = _FakeDB()
        fake_db.properties_rows = [
            {"doc_id": "p1", "landlordId": "l1", "name": "H",
             "loan_input_cadence": "monthly", "mortgage_settled_on": "2027-03"},
        ]
        service = _build_service(fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused"))
        rows = service._list_landlord_properties("l1")
        self.assertEqual(rows[0]["loan_input_cadence"], "monthly")
        self.assertEqual(rows[0]["mortgage_settled_on"], "2027-03")
        self.assertNotIn("loan_input_method", rows[0])
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd residex_app && flutter test test/features/landlord/property_profile_fields_test.dart
cd ../backend && py -3.11 -m pytest tests/test_documind_service_flows.py -q -k loan_prefs
```

Expected: Dart FAILS to compile (`mortgageSettledOn` undefined); Python FAILS on the `mortgage_settled_on` assertion.

- [ ] **Step 3: Add the field**

`property.dart` — declare it beside `loanInputCadence`:

```dart
  /// 'YYYY-MM' — the month the mortgage was fully repaid, or null if it is
  /// still running. [hasMortgage] stays true on a settled property: it did
  /// have a mortgage, and historical years must still expect and reconcile
  /// loan figures. Atomic rather than a year/month pair so it cannot land
  /// half-set.
  final String? mortgageSettledOn;
```

Add `this.mortgageSettledOn,` to the constructor (after `this.loanInputCadence,`), `String? mortgageSettledOn,` to `copyWith`'s parameters and `mortgageSettledOn: mortgageSettledOn ?? this.mortgageSettledOn,` to its body — the coalescing is deliberate and matches every other field.

Then add, immediately after `copyWith`:

```dart
  /// The only way to *clear* the settlement date. [copyWith] coalesces every
  /// field with `?? this.field`, so `copyWith(mortgageSettledOn: null)` is a
  /// no-op — a footgun for a field whose whole point is being cleared when a
  /// landlord corrects a mistake. Named explicitly so the asymmetry is
  /// visible at the call site, and kept here beside copyWith so a field added
  /// to Property later is obviously missing from both.
  Property withMortgageSettledOn(String? value) => Property(
        id: id,
        landlordId: landlordId,
        name: name,
        address: address,
        type: type,
        purchasePrice: purchasePrice,
        currentValue: currentValue,
        ownershipShare: ownershipShare,
        structureType: structureType,
        hasMortgage: hasMortgage,
        trackFromYear: trackFromYear,
        utilitiesPaidBy: utilitiesPaidBy,
        loanInputCadence: loanInputCadence,
        mortgageSettledOn: value,
        nextSetupStep: nextSetupStep,
        foldersEnabled: foldersEnabled,
        folderNames: folderNames,
        folderMoves: folderMoves,
        photos: photos,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
```

`property_model.dart` — add `super.mortgageSettledOn,` to the constructor, `mortgageSettledOn: property.mortgageSettledOn,` to `fromEntity`, `mortgageSettledOn: mortgageSettledOn,` to `toEntity`, `mortgageSettledOn: json['mortgage_settled_on'] as String?,` to `fromJson`, and `'mortgage_settled_on': mortgageSettledOn,` to `toJson`. Place each beside the corresponding `loanInputCadence` line.

`backend/rag/property_directory.py` — add to the appended dict (where line 67 used to be):

```python
                "mortgage_settled_on": data.get('mortgage_settled_on'),
```

- [ ] **Step 4: Run the tests**

```bash
cd residex_app && flutter test
cd ../backend && py -3.11 -m pytest tests/ -q
```

Expected: both green (Flutter modulo the known `widget_test.dart` failure).

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/property.dart \
        residex_app/lib/features/landlord/data/models/property_model.dart \
        residex_app/test/features/landlord/property_profile_fields_test.dart \
        backend/rag/property_directory.py \
        backend/tests/test_documind_service_flows.py
git commit -m "feat(loans): add Property.mortgageSettledOn

A 'YYYY-MM' string, atomic so it cannot land half-set, carried through
to the backend as mortgage_settled_on. withMortgageSettledOn is the only
way to clear it — copyWith coalesces nulls, which would silently ignore
a landlord correcting the date."
```

---

### Task 7: `_loan_expected_for` — the engine stops expecting loan figures after settlement

**Files:**
- Modify: `backend/rag/finance/finance_engine.py` — new `_loan_expected_for` near line 897, then `_property_coverage` (736-743, 804-830), `_loan_completeness` (897-958), and the call sites at 1043-1046, 1149-1152, 1203
- Test: `backend/tests/test_finance_engine.py` (new class `MortgageSettlementTests`)

**Interfaces:**
- Consumes: Task 1's ungated `_loan_completeness`; Task 6's `mortgage_settled_on` key on property rows.
- Produces:
  - `_loan_expected_for(prop: Dict[str, Any], year: int, month: Optional[int] = None) -> bool`
  - `_property_coverage(...)` gains a keyword-only-in-practice trailing parameter `loan_expected_for: Optional[Callable[[int], bool]] = None`. Existing callers that omit it get today's behaviour exactly.
  - `_expected_categories(prop)` **stays year-agnostic.** It still feeds `_expected_record_categories` (the Records grid column set), which must keep its loan column on a settled property so history stays readable.

> **The substantive design decision.** The spec flagged that `_expected_categories` is year-agnostic while it feeds both the coverage grid (which iterates years internally) and the per-year `missing` list. Threading a year through `_expected_categories` would change the Records grid's column set as a side effect. Instead the year-dependence is pushed to the two consumers: `_property_coverage` filters `'loan'` inside its own year loop via an injected callable, and the `missing` list filters once for the selected year. `_expected_categories` is untouched.

- [ ] **Step 1: Write the failing tests**

```python
class MortgageSettlementTests(unittest.TestCase):
    def _prop(self, settled=None, cadence="annual"):
        row = {"property_id": "p1", "name": "Block", "ownership_share": 1.0,
               "has_mortgage": True, "loan_input_cadence": cadence}
        if settled is not None:
            row["mortgage_settled_on"] = settled
        return row

    def _lease(self):
        # Gives _property_coverage a window to walk (2026 through today's year).
        return _doc("p1", "lease", {"monthly_rent": 1000.0,
                                    "lease_start": "2026-01-01",
                                    "lease_end": "2028-12-31"})

    def _missing_for(self, year, settled=None):
        summary = _summary(
            [self._lease()], [self._prop(settled)], year=year,
            today=date(2029, 6, 15),
        )
        return summary["missing_categories"].get("p1", [])

    def test_year_before_settlement_still_expects_loan(self):
        self.assertIn("loan", self._missing_for(2026, settled="2027-03"))

    def test_settlement_year_still_expects_loan(self):
        self.assertIn("loan", self._missing_for(2027, settled="2027-03"))

    def test_year_after_settlement_does_not_expect_loan(self):
        self.assertNotIn("loan", self._missing_for(2028, settled="2027-03"))

    def test_unsettled_property_expects_loan_in_every_year(self):
        self.assertIn("loan", self._missing_for(2028))

    def test_malformed_settlement_date_is_treated_as_unset(self):
        # Never silently suppress a year's expectation on unparseable data.
        for bad in ("not-a-date", "2027", "", "20XX-03", None):
            with self.subTest(bad=bad):
                self.assertIn("loan", self._missing_for(2028, settled=bad))

    def test_coverage_grid_stops_flagging_loan_after_settlement(self):
        summary = _summary(
            [self._lease()], [self._prop("2027-03")], year=2028,
            today=date(2029, 6, 15),
        )
        coverage = {row["year"]: row for row in summary["properties"][0]["coverage"]}
        self.assertIn("loan", coverage[2026]["missing"])
        self.assertIn("loan", coverage[2027]["missing"])
        self.assertNotIn("loan", coverage[2028]["missing"])
        self.assertNotIn("loan", coverage[2029]["missing"])

    def test_records_grid_keeps_its_loan_column_after_settlement(self):
        # The column set is the property's whole-history vocabulary, not one
        # year's expectation — a settled property's past years still hold
        # loan documents and must still have somewhere to show them.
        summary = _summary(
            [self._lease()], [self._prop("2027-03")], year=2028,
            today=date(2029, 6, 15),
        )
        self.assertIn("loan", summary["properties"][0]["expected_categories"])

    def test_completeness_resolves_for_years_after_settlement(self):
        summary = _summary(
            [], [self._prop("2027-03")], year=2028, today=date(2029, 6, 15),
        )
        self.assertFalse(summary["properties"][0]["manual_loan_incomplete"])

    def test_completeness_still_incomplete_in_the_settlement_year(self):
        summary = _summary(
            [], [self._prop("2027-03")], year=2027, today=date(2029, 6, 15),
        )
        self.assertTrue(summary["properties"][0]["manual_loan_incomplete"])

    def test_monthly_cadence_ignores_months_after_the_settled_month(self):
        entries = [{"property_id": "p1", "unit_id": None, "year": 2027,
                    "month": m, "interest_paid": 100.0, "principal_paid": 0.0,
                    "cadence": "monthly"} for m in (1, 2, 3)]
        summary = _summary(
            [], [self._prop("2027-03", cadence="monthly")], year=2027,
            today=date(2029, 6, 15), manual_loan_entries=entries,
        )
        self.assertFalse(summary["properties"][0]["manual_loan_incomplete"])

    def test_monthly_cadence_still_flags_a_gap_before_the_settled_month(self):
        entries = [{"property_id": "p1", "unit_id": None, "year": 2027,
                    "month": m, "interest_paid": 100.0, "principal_paid": 0.0,
                    "cadence": "monthly"} for m in (1, 3)]
        summary = _summary(
            [], [self._prop("2027-03", cadence="monthly")], year=2027,
            today=date(2029, 6, 15), manual_loan_entries=entries,
        )
        self.assertTrue(summary["properties"][0]["manual_loan_incomplete"])

    def test_has_mortgage_stays_true_and_history_still_reconciles(self):
        docs = [self._lease(),
                _doc("p1", "loan", {"subtype": "interest_statement",
                                    "period_year": 2026, "interest_paid": 5000.0})]
        summary = _summary(docs, [self._prop("2027-03")], year=2026,
                           today=date(2029, 6, 15))
        block = summary["properties"][0]
        self.assertNotIn("loan", summary["missing_categories"].get("p1", []))
        self.assertAlmostEqual(block["direct_expenses"], 5000.0, places=2)
```

Confirm the summary's top-level key name for the missing map before writing (`missing_categories` per `finance_engine.py:1205`) and the coverage row's key names (`year`, `missing`) by reading `_property_coverage`'s returned dict around line 830.

- [ ] **Step 2: Run to verify they fail**

```bash
cd backend && py -3.11 -m pytest tests/test_finance_engine.py::MortgageSettlementTests -q
```

Expected: the three "after settlement" tests FAIL — `'loan'` is still expected and completeness is still incomplete.

- [ ] **Step 3: Add the predicate**

Insert above `_loan_completeness` in `backend/rag/finance/finance_engine.py`:

```python
def _loan_expected_for(
    prop: Dict[str, Any], year: int, month: Optional[int] = None
) -> bool:
    """Whether loan figures are expected for a period. A settled mortgage stops
    expecting them after its final month; history before it is unaffected.
    has_mortgage stays True on a settled property — it did have a mortgage, and
    every year up to settlement must still reconcile.

    A malformed mortgage_settled_on is treated as unset: never silently
    suppress a year's expectation on unparseable data."""
    if prop.get("has_mortgage") is not True:
        return False
    settled = prop.get("mortgage_settled_on")
    if not settled:
        return True
    try:
        s_year, s_month = int(str(settled)[:4]), int(str(settled)[5:7])
    except (TypeError, ValueError):
        return True
    if year != s_year:
        return year < s_year
    return month is None or month <= s_month
```

Add `Callable` to the `typing` import at the top of the file if it is not already there.

- [ ] **Step 4: Thread it through `_property_coverage`**

Add the parameter to the signature (line 736-743):

```python
def _property_coverage(
    prop_docs: List[Dict[str, Any]],
    current_year: int,
    expected: Optional[List[str]] = None,
    tax_subtypes: Optional[List[Tuple[str, Tuple[str, ...]]]] = None,
    unavailable: Optional[Dict[int, Set[str]]] = None,
    track_from_year: Optional[int] = None,
    loan_expected_for: Optional[Callable[[int], bool]] = None,
) -> List[Dict[str, Any]]:
```

Extend the docstring with one sentence: *"`loan_expected_for` filters the 'loan' category per year (mortgage settlement); omitted means every year in the window expects it, which is today's behaviour."*

Inside the year loop, immediately after `for category in (expected if expected is not None else FINANCE_CATEGORIES):` (line 809), add as the first check:

```python
            if category == "loan" and loan_expected_for is not None \
                    and not loan_expected_for(year):
                continue  # settled mortgage — this year expects nothing
```

It must precede the `unavailable_for_year` check so a settled year is neither flagged missing nor listed as acknowledged-unavailable.

Update the call site at line 1149-1152:

```python
        coverage_rows = _property_coverage(
            prop_docs, today.year, _expected_categories(prop),
            _expected_tax_subtypes(prop), prop_unavailable, prop.get("track_from_year"),
            loan_expected_for=lambda y: _loan_expected_for(prop, y),
        )
```

- [ ] **Step 5: Filter the per-year `missing` list**

Replace line 1203:

```python
        expected_this_year = [
            c for c in _expected_categories(prop)
            if c != "loan" or _loan_expected_for(prop, year)
        ]
        missing = [c for c in expected_this_year if c not in contributing]
```

- [ ] **Step 6: Teach `_loan_completeness` about settlement**

In `_loan_completeness`, replace the gate added in Task 1:

```python
    if not _loan_expected_for(prop, year):
        return False, {}
    cadence = prop.get("loan_input_cadence") or "annual"
    # Months past the settled month in the settlement year were never owed,
    # so a monthly-cadence property is not incomplete for lacking them.
    months = [m for m in months if _loan_expected_for(prop, year, m)]
```

`_loan_expected_for(prop, year)` with `month=None` already returns False for a non-mortgaged property and for years after settlement, so this replaces the `has_mortgage` check rather than sitting beside it. Rebinding `months` is local to the function (the caller's list is not mutated), and the `resolved()` closure below reads it through the enclosing scope — verify that after editing, since `resolved` captures `months` by name.

Update the docstring's last sentence to: *"Only meaningful for a mortgaged property in a year that still expects loan figures — otherwise returns (False, {})."*

- [ ] **Step 7: Run the tests**

```bash
cd backend && py -3.11 -m pytest tests/ -q
```

Expected: green. If an existing coverage or completeness test breaks, check whether it passes a property with `has_mortgage` unset — `_loan_expected_for` returns False there, matching `_loan_completeness`'s Task 1 behaviour but **differing** from `_expected_categories`, which only drops `'loan'` when `has_mortgage is False`. That asymmetry is deliberate and pre-existing: an *unanswered* mortgage keeps expecting loan documents (conservative), but is not tracked for completeness. Do not "unify" them.

- [ ] **Step 8: Commit**

```bash
git add backend/rag/finance/finance_engine.py backend/tests/test_finance_engine.py
git commit -m "feat(loans): stop expecting loan figures after a mortgage is settled

One predicate, _loan_expected_for(prop, year, month), read by the
coverage grid, the per-year missing list and the completeness check.
has_mortgage stays true so history before settlement still reconciles.
A malformed mortgage_settled_on is treated as unset — a bad value must
never silently suppress a year's expectation.

_expected_categories stays year-agnostic: it also feeds the Records grid
column set, which must keep its loan column on a settled property."
```

---

### Task 8: The settlement control and settled state in the Loan figures block

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart:500-660`
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`

**Interfaces:**
- Consumes: Task 6's `Property.mortgageSettledOn` / `withMortgageSettledOn`; Task 7's backend behaviour (a settled year emits no `'loan'` in `missingCategories` and `manualLoanIncomplete == false`).
- Produces: no new public API. `_buildLoanFiguresRow` gains a settled branch and a settlement control; `_buildLoanCompletenessLine`'s denominator is derived rather than hardcoded.

**The three states** (spec §4). "Settlement year" means the year in `mortgageSettledOn`.

| Year vs settlement | Block renders |
| --- | --- |
| settlement year or earlier, no figures | "Add loan figures" + a quiet "Mortgage paid off?" control beside it |
| settlement year or earlier, figures present | Title row with Modify (one action only), figures, completeness sub-line, then a quiet settled line beneath |
| after the settlement year | `Mortgage settled · March 2027` with a control to correct or clear the date |
| not settled at all | as today, plus the "Mortgage paid off?" control in both empty and populated states |

The control must be reachable in **both** the empty and populated states: a settled mortgage produces the empty state in every later year, which is precisely when a landlord needs it.

- [ ] **Step 1: Write the failing tests**

Add to `residex_app/test/features/landlord/finance_screen_test.dart`. Extend `_fakeProperty` with `String? mortgageSettledOn`.

```dart
  testWidgets('the settled control is reachable from the empty state',
      (tester) async {
    await _pumpScreenWithLoanEntries(
      tester, 2026, _summaryWithProperty(2026, complete: true),
      _fakeProperty(hasMortgage: true), const [],
    );

    expect(find.text('Add loan figures'), findsOneWidget);
    expect(find.text('Mortgage paid off?'), findsOneWidget);
  });

  testWidgets('the settled control is reachable from the populated state',
      (tester) async {
    await _pumpScreenWithLoanEntries(
      tester, 2026, _summaryWithProperty(2026, complete: true),
      _fakeProperty(hasMortgage: true),
      [{'interest_paid': 8200.0, 'principal_paid': 0.0, 'month': null, 'unit_id': null}],
    );

    expect(find.text('Modify'), findsOneWidget);
    expect(find.text('Mortgage paid off?'), findsOneWidget);
  });

  testWidgets('a year after settlement collapses to the settled state',
      (tester) async {
    await _pumpScreenWithLoanEntries(
      tester, 2028, _summaryWithProperty(2028, complete: true),
      _fakeProperty(hasMortgage: true, mortgageSettledOn: '2027-03'), const [],
    );

    expect(find.text('Mortgage settled · March 2027'), findsOneWidget);
    expect(find.text('Add loan figures'), findsNothing);
  });

  testWidgets('the settlement year itself still behaves normally',
      (tester) async {
    await _pumpScreenWithLoanEntries(
      tester, 2027, _summaryWithProperty(2027, complete: true),
      _fakeProperty(hasMortgage: true, mortgageSettledOn: '2027-03'),
      [{'interest_paid': 2000.0, 'principal_paid': 0.0, 'month': null, 'unit_id': null}],
    );

    expect(find.text('Loan figures · 2027'), findsOneWidget);
    expect(find.text('Modify'), findsOneWidget);
    expect(find.textContaining('Mortgage settled'), findsOneWidget,
        reason: 'shown as a quiet line, not taking over the block');
  });

  testWidgets('a year before settlement behaves normally', (tester) async {
    await _pumpScreenWithLoanEntries(
      tester, 2026, _summaryWithProperty(2026, complete: true),
      _fakeProperty(hasMortgage: true, mortgageSettledOn: '2027-03'),
      [{'interest_paid': 8200.0, 'principal_paid': 0.0, 'month': null, 'unit_id': null}],
    );

    expect(find.text('Loan figures · 2026'), findsOneWidget);
    expect(find.text('RM 8,200.00'), findsWidgets);
  });

  testWidgets('the completeness sub-line counts elapsed months, not 12',
      (tester) async {
    // The backend requires only elapsed months (finance_engine.py:98-104);
    // a hardcoded 12 told a landlord in March they were 3 of 12 done when
    // they were in fact complete.
    final now = DateTime.now();
    final entries = [
      for (var m = 1; m <= now.month; m++)
        {'interest_paid': 100.0, 'principal_paid': 0.0, 'month': m, 'unit_id': null},
    ];
    await _pumpScreenWithLoanEntries(
      tester, now.year,
      _summaryWithProperty(now.year, complete: false, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true, loanInputCadence: 'monthly'), entries,
    );

    expect(find.textContaining('of ${now.month} months recorded'), findsOneWidget);
    expect(find.textContaining('of 12 months'), findsNothing);
  });

  testWidgets('the completeness denominator stops at the settled month',
      (tester) async {
    await _pumpScreenWithLoanEntries(
      tester, 2027,
      _summaryWithProperty(2027, complete: false, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true, loanInputCadence: 'monthly',
          mortgageSettledOn: '2027-03'),
      [{'interest_paid': 100.0, 'principal_paid': 0.0, 'month': 1, 'unit_id': null}],
    );

    expect(find.textContaining('1 of 3 months recorded'), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd residex_app && flutter test test/features/landlord/finance_screen_test.dart
```

Expected: FAIL — no "Mortgage paid off?" control, no settled state, denominator reads 12.

- [ ] **Step 3: Implement the settled state and control**

In `finance_screen.dart`, add a helper pair above `_buildLoanFiguresRow`:

```dart
  /// 'YYYY-MM' -> ('March 2027'). Returns null for anything unparseable, so a
  /// bad stored value degrades to "not settled" rather than rendering garbage
  /// — matching the backend's _loan_expected_for, which treats a malformed
  /// value as unset.
  static ({int year, int month})? _parseSettled(String? value) {
    if (value == null || value.length < 7) return null;
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(5, 7));
    if (year == null || month == null || month < 1 || month > 12) return null;
    return (year: year, month: month);
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
```

In `_buildLoanFiguresRow`, after the `entries`/`hasFigures` computation and before the `if (!hasFigures)` branch:

```dart
    final settled = _parseSettled(property?.mortgageSettledOn);
    // The settled *state* replaces the block only for years after the
    // settlement year. The settlement year and every year before it still
    // expect figures, so they keep the normal block with the settled date as
    // a quiet line beneath.
    if (settled != null && year > settled.year) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 20, color: AppColors.hairline),
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mortgage settled · ${_monthNames[settled.month - 1]} ${settled.year}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => _openSettlementSheet(context, ref, property),
                child: Text('Change', style: AppTextStyles.labelLarge),
              ),
            ],
          ),
        ],
      );
    }
```

In the empty branch (`if (!hasFigures)`), wrap the existing `TextButton.icon` in a `Row` and add the control beside it:

```dart
    if (!hasFigures) {
      return Row(
        children: [
          Opacity(
            opacity: isUnusable ? 0.5 : 1.0,
            child: TextButton.icon(
              onPressed: isUnusable
                  ? null
                  : () => _openManualLoanSheet(context, block, property, year),
              icon: const Icon(Icons.add, size: 18, color: AppColors.registry),
              label: Text('Add loan figures', style: AppTextStyles.labelLarge),
            ),
          ),
          const Spacer(),
          if (property != null)
            TextButton(
              onPressed: () => _openSettlementSheet(context, ref, property),
              child: Text(
                _settlementLabel(settled),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
        ],
      );
    }
```

Both the empty and populated states use the same label helper, so the control never reads "Mortgage paid off?" on a property that already has a date (which happens in the *settlement year and earlier*, where the block still behaves normally):

```dart
  static String _settlementLabel(({int year, int month})? settled) =>
      settled == null
          ? 'Mortgage paid off?'
          : 'Mortgage settled · ${_monthNames[settled.month - 1]} ${settled.year}';
```

In the populated branch, append the control **below** the figures — the title row keeps Modify as its only action:

```dart
        _loanFigureLine('Interest', interest),
        _loanFigureLine('Principal', principal),
        if (completenessLine != null) completenessLine,
        if (property != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openSettlementSheet(context, ref, property),
              child: Text(
                _settlementLabel(settled),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
```

- [ ] **Step 4: Implement the month/year picker**

Reuses the modal-list pattern `_pickTrackFromYear` uses in `add_property_dialog.dart:794-849` — `showModalBottomSheet` over a `ConstrainedBox(maxHeight: 360)` + `shrinkWrap: true` `ListView`, with a sentinel row for clearing. Two sheets: year, then month.

```dart
  /// Records (or corrects, or clears) the month the mortgage was repaid.
  ///
  /// Two sheets rather than one 12×N list: a flat month-year list would be
  /// hundreds of rows. Mirrors _pickTrackFromYear's modal-list pattern so a
  /// landlord meets the same interaction twice, not two inventions.
  Future<void> _openSettlementSheet(
      BuildContext context, WidgetRef ref, Property property) async {
    final currentYear = DateTime.now().year;
    final earliest = property.trackFromYear ?? 2000;
    final existing = _parseSettled(property.mortgageSettledOn);
    const clear = -1; // sentinel: distinguishes "clear it" from a dismissed sheet

    final year = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('When was the mortgage repaid?',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Past years keep their loan figures — you just stop being '
                'asked from this point on.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (existing != null)
                      ListTile(
                        leading: const Icon(Icons.undo,
                            color: AppColors.textMuted),
                        title: Text('Still paying it off',
                            style: AppTextStyles.bodyLarge),
                        onTap: () => Navigator.of(sheetContext).pop(clear),
                      ),
                    for (var y = currentYear; y >= earliest; y--)
                      ListTile(
                        title: Text('$y', style: AppTextStyles.bodyLarge),
                        trailing: existing?.year == y
                            ? const Icon(Icons.check, color: AppColors.registry)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(y),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (year == null) return; // dismissed
    if (year == clear) {
      // withMortgageSettledOn, never copyWith: copyWith coalesces `?? this`,
      // so copyWith(mortgageSettledOn: null) would silently keep the old date.
      await ref.read(propertyControllerProvider)
          .updateProperty(property.withMortgageSettledOn(null));
      return;
    }

    if (!context.mounted) return;
    final month = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Which month in $year?', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      ListTile(
                        title: Text(_monthNames[m - 1],
                            style: AppTextStyles.bodyLarge),
                        trailing:
                            existing?.year == year && existing?.month == m
                                ? const Icon(Icons.check,
                                    color: AppColors.registry)
                                : null,
                        onTap: () => Navigator.of(sheetContext).pop(m),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (month == null) return; // dismissed at the second step — nothing written
    await ref.read(propertyControllerProvider).updateProperty(
          property.withMortgageSettledOn(
            '$year-${month.toString().padLeft(2, '0')}',
          ),
        );
  }
```

Import `property_providers.dart` for `propertyControllerProvider` if `finance_screen.dart` does not already. Icons, not emoji — project convention.

- [ ] **Step 5: Fix the completeness denominator**

Replace `_buildLoanCompletenessLine`'s hardcoded `12` (line 635) with the same bound the backend uses — elapsed months, further bounded by the settled month in the settlement year:

```dart
      final now = DateTime.now();
      // The backend requires only *elapsed* months (finance_engine.py's
      // _months_in_scope), and settlement adds a third bound. A hardcoded 12
      // told a landlord in March they were 3 of 12 done when the backend
      // considered them complete.
      var monthsInScope = year < now.year ? 12 : (year > now.year ? 0 : now.month);
      final settled = _parseSettled(property?.mortgageSettledOn);
      if (settled != null && year == settled.year) {
        monthsInScope = monthsInScope < settled.month ? monthsInScope : settled.month;
      }
      message = '$recordedMonths of $monthsInScope months recorded for $year';
```

- [ ] **Step 6: Run the tests**

```bash
cd residex_app && flutter analyze && flutter test
```

Expected: green except the known `widget_test.dart` failure.

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart \
        residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat(loans): record when a mortgage was settled

The control is reachable from both the empty and populated states of the
loan figures block — a settled mortgage produces the empty state in
every later year, which is exactly when a landlord needs it. The settled
state replaces the block only after the settlement year; the settlement
year itself still expects figures.

Also replaces the completeness sub-line's hardcoded 12 with the bound
the backend actually uses (elapsed months, capped at the settled month)."
```

---

## Manual verification

Run once, at the end, against the real app. See the "Documind run setup" memory for launching the backend and the Android emulator.

1. **Fork removal.** Open Documents on any property — Loans & Financing is present. Open property settings — no "How will loan figures arrive?" question. Open Finance on a mortgaged property that predates this work (`loanInputMethod` was null) — the loan figures row is there.
2. **New output on existing data.** A mortgaged upload-mode property now shows the incomplete-statutory caveat and the completeness sub-line for the first time. This is intended, not a regression.
3. **Ownership share.** On a property at less than 100%, check that the Direct Expenses figure equals the sum of the deductible lines shown beneath it, and that the loan interest line reads its face value while other lines read the scaled value with "your N% of RM X".
4. **"Not sure".** Edit a commercial property, tap "Not sure" for structure type, save, reopen — it stays "Not sure".
5. **Yes → No.** On a property with booked figures, flip to No and save — the confirmation names the amount and points at settlement. Cancel; the chip returns to Yes. Confirm; the figures are still in the finance totals.
6. **Settlement.** Mark a mortgage settled in a past month. Check the settlement year still shows the figures block, the following year collapses to "Mortgage settled · …", and the nudge stops mentioning loans for that later year. Clear the date; nudging returns.

## Deferred / out of scope

- `excluded` (`finance_engine.py:1222`) sums non-deductible amounts unscaled while every other displayed figure is scaled. Pre-existing, deliberately left alone (spec §2).
- `loanInputCadence` is untouched.
- `Property.copyWith`'s null-coalescing is untouched; `withMortgageSettledOn` is the escape hatch for the one field that needs clearing.
- The manual-entry sheet's layout and the loan figures block's layout are kept as built in the previous workstream, except where named above.
- The Save/prefill invariant from the previous workstream still holds: on `manual_loan_entry_sheet.dart`, any gate deciding whether Save is live and any gate deciding whether prefill runs **must be the same expression** (`entriesAsync.hasValue`). They diverged twice before and both times it was silent data corruption. No task here touches that file's gates; if one appears to need to, stop and escalate.
