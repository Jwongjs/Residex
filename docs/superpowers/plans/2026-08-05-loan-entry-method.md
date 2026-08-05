# Loan Entry Method Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the landlord choose once, at registration, whether loan figures arrive by uploaded statement or by hand — and have every downstream surface honour that instead of re-asking.

**Architecture:** `Property.loanInputMethod` already exists and the finance engine already branches on it; no UI has ever written it. This plan writes it from the property dialog, then reads it in three places: the Loans folder tile, the finance-tab nudge, and a new permanent loan-figures row on the property panel. Frontend only.

**Tech Stack:** Flutter, Riverpod (legacy `StateProvider` import where needed), flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-05-loan-entry-method-design.md`

## Global Constraints

- Run from `residex_app/` with `flutter test`. **Baseline: 239 passed, 1 failed.** The one failure is `test/widget_test.dart` "Counter increments smoke test", pre-existing boilerplate. It must stay at exactly 1 failure — never "fix" it as part of this work.
- **Icons, not emoji**, everywhere in the UI. Project convention.
- `loanInputMethod` is `'upload' | 'manual' | null`. **Only `'manual'` changes behaviour.** `'upload'`, `null`, and a property that fails to load all behave exactly as today — this is what keeps the change inert for existing data.
- Riverpod 3.x: `StateProvider` is legacy and needs `import 'package:flutter_riverpod/legacy.dart';` if you add one. Prefer not to.
- Never `git add -A`. Commit the explicit paths each task names.
- Do not modify anything under `backend/`, `demo_documents/`, or `backend/scripts/`.

## Known gap in this plan — read before routing

Tasks 2 and 5 create **new** test files against harnesses this plan's author did not read (`documents_screen`'s provider setup, and whatever fixtures a manual-loan-sheet test would need). Their Step 1 therefore states the cases to assert and the fixture shapes, but does not supply complete runnable test code the way Tasks 1, 3 and 4 do.

That is a real deficiency, not a style choice. Whoever implements those two tasks **must read the existing test file in that directory first** and copy its `ProviderScope` override setup rather than inventing one. Do not guess at provider names or fixture constructors.

Tasks 3 and 4 append to `finance_screen_test.dart`, whose helpers were read and are named exactly.

## Deviation from the spec, and why

The spec's "Where the figures come from" says the panel row sums `ExpenseLine`s with subtype `loan_interest` / `loan_principal`. **Do not do that.** Expense-line amounts are scaled by ownership share at the finance engine's per-property choke point, so a 50%-owned property would display half of what the landlord typed — in a row whose entire purpose is letting them verify and correct their own entry.

Use `manualLoanEntriesProvider((propertyId:, year:))` instead. It already exists (`documind_provider.dart:479`), returns the raw booked entries, and the entry sheet already watches it. Entry maps carry `interest_paid`, `principal_paid`, `month`, `unit_id`, `cadence` (all snake_case, from `finance_overrides_repository.py:175-181`).

---

### Task 1: Ask for the entry method at registration

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`
- Test: `residex_app/test/features/landlord/loan_input_method_dialog_test.dart` (create)

**Interfaces:**
- Produces: the dialog writes `Property.loanInputMethod` as `'upload'`, `'manual'` or `null` on both create and edit. Every later task reads that field.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/loan_input_method_dialog_test.dart`:

```dart
// The loan-method question is the whole point of this workstream: it is the
// one place the choice is made, so every downstream surface can stop asking.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/add_property_dialog.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: AddPropertyDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the loan method cards are hidden until mortgage is Yes',
      (tester) async {
    await _pump(tester);
    expect(find.text('How will loan figures arrive?'), findsNothing);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('How will loan figures arrive?'), findsOneWidget);
    expect(find.text('Upload statements'), findsOneWidget);
    expect(find.text('Enter figures myself'), findsOneWidget);
  });

  testWidgets('answering No hides the cards again', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Upload statements'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Upload statements'), findsNothing);
  });

  testWidgets('neither card is selected until one is tapped', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    // Unanswered means null, which behaves as 'upload' downstream — this is
    // what keeps every existing property behaving as it does today.
    expect(
      find.byKey(const Key('loan-method-upload-selected')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('loan-method-manual-selected')),
      findsNothing,
    );
  });

  testWidgets('tapping a card selects it and deselects the other',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter figures myself'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loan-method-manual-selected')), findsOneWidget);
    expect(find.byKey(const Key('loan-method-upload-selected')), findsNothing);

    await tester.tap(find.text('Upload statements'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loan-method-upload-selected')), findsOneWidget);
    expect(find.byKey(const Key('loan-method-manual-selected')), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/landlord/loan_input_method_dialog_test.dart`
Expected: FAIL — no "How will loan figures arrive?" text exists.

- [ ] **Step 3: Add the state field**

In `add_property_dialog.dart`, beside `bool? _hasMortgage;` (line 44):

```dart
  /// 'upload' | 'manual' | null. Null means unanswered, which behaves as
  /// 'upload' everywhere downstream — so an existing property, or a landlord
  /// who skips the question, sees exactly today's behaviour.
  String? _loanInputMethod;
```

In `initState`, alongside the other `property.` reads, add:

```dart
      _loanInputMethod = property.loanInputMethod;
```

- [ ] **Step 4: Build the two cards**

Add this method next to `_buildMortgageSelector`:

```dart
  /// Two equally-weighted options, each saying what it does and what the
  /// landlord gets back. Deliberately not a button plus a text link: these
  /// are different paths with different downstream behaviour, and rendering
  /// one as an afterthought is what made the old three surfaces unreadable.
  Widget _buildLoanMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How will loan figures arrive?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _loanMethodCard(
                value: 'upload',
                icon: Icons.description_outlined,
                title: 'Upload statements',
                blurb: 'We read the interest and principal out of your bank statement.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _loanMethodCard(
                value: 'manual',
                icon: Icons.edit_outlined,
                title: 'Enter figures myself',
                blurb: 'Type the interest and principal for each period yourself.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _loanMethodCard({
    required String value,
    required IconData icon,
    required String title,
    required String blurb,
  }) {
    final selected = _loanInputMethod == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _loanInputMethod = value),
      child: Container(
        key: selected ? Key('loan-method-$value-selected') : null,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.registry.withOpacity(0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.registry : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.registry : AppColors.textMuted),
            const SizedBox(height: 8),
            Text(title,
                style: AppTextStyles.labelLarge.copyWith(
                  color: selected ? AppColors.registry : AppColors.textPrimary,
                )),
            const SizedBox(height: 4),
            Text(blurb,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 5: Show it only when mortgage is Yes**

In the "Property profile" section, replace:

```dart
                      _buildMortgageSelector(),
                      const SizedBox(height: 16),
                      _buildYearPicker(),
```

with:

```dart
                      _buildMortgageSelector(),
                      if (_hasMortgage == true) ...[
                        const SizedBox(height: 16),
                        _buildLoanMethodSelector(),
                      ],
                      const SizedBox(height: 16),
                      _buildYearPicker(),
```

- [ ] **Step 6: Persist it on create and edit**

In the edit branch, replace `loanInputMethod: existing.loanInputMethod,` with:

```dart
          loanInputMethod: _hasMortgage == true ? _loanInputMethod : null,
```

In the create branch, replace `loanInputMethod: null,` with:

```dart
          loanInputMethod: _hasMortgage == true ? _loanInputMethod : null,
```

Answering "No" or "Not sure" clears the method, so a stale `'manual'` cannot survive a landlord saying they have no mortgage.

- [ ] **Step 7: Run the task's test**

Run: `flutter test test/features/landlord/loan_input_method_dialog_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 8: Run the full Flutter suite**

Run: `flutter test`
Expected: 243 passed, **1 failed** (the pre-existing boilerplate failure only)

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart residex_app/test/features/landlord/loan_input_method_dialog_test.dart
git commit -m "feat(loans): ask how loan figures arrive when the property has a mortgage"
```

---

### Task 2: Gate the Loans folder and drop manual entry from it

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/5-Documents/documents_screen.dart`
- Test: `residex_app/test/features/landlord/documents_loan_folder_test.dart` (create)

**Interfaces:**
- Consumes: `Property.loanInputMethod` written in Task 1
- Produces: nothing downstream

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/documents_loan_folder_test.dart`. Model the provider overrides on an existing documents-screen test in the same directory — read one first and copy its `ProviderScope` setup, because the screen needs properties, documents and units providers stubbed.

The four cases to assert:

```dart
  // 'manual' is the ONLY value that hides the folder. Everything else keeps
  // it, which is what makes this change inert for existing properties.
  testWidgets('manual hides the Loans & Financing tile', ...);
  testWidgets('upload keeps the tile', ...);
  testWidgets('null keeps the tile', ...);
  testWidgets('neither folder state offers manual entry', ...);
```

For the first three, pump the screen with a property whose `loanInputMethod` is the value under test and assert on `find.text('Loans & Financing')` — `findsNothing` for manual, `findsOneWidget` otherwise.

For the fourth, select the loan category on an `'upload'` property and assert `find.text('Enter figures manually')` is `findsNothing` in both the empty and populated folder states.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/landlord/documents_loan_folder_test.dart`
Expected: FAIL — the tile shows for manual, and "Enter figures manually" is present.

- [ ] **Step 3: Derive the folder list from the property**

`_categories` is currently a `final` field (line 51). Replace it with a method that takes the property:

```dart
  // Display folders (stored categories collapse via displayCategoryFor;
  // uploads from the Expenses folder send category 'expenses' so the
  // backend runs line-item extraction).
  //
  // Loans is dropped only for 'manual': those landlords type figures on the
  // finance tab and have no loan documents to file. 'upload', null and a
  // property that failed to load all keep it.
  List<String> _categoriesFor(Property? property) {
    final base = ['lease', 'rental_invoice', 'loan', 'expenses'];
    if (property?.loanInputMethod == 'manual') {
      base.remove('loan');
    }
    return base;
  }
```

Update the grid to use it. At the `GridView.builder` (line ~385), the enclosing builder already has the selected property in scope — if it does not, read it with `ref.watch(propertyByIdProvider(_selectedPropertyId!)).value`. Then:

```dart
        final categories = _categoriesFor(property);
        ...
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(category);
        },
```

- [ ] **Step 4: Fall back when the selected folder disappears**

Where `_selectedCategory` is read to decide what to render, add a guard so a property switched to manual while sitting inside the Loans folder returns to the grid instead of rendering a folder that no longer exists:

```dart
    // The landlord can switch to manual from property settings while this
    // screen is open on the Loans folder; fall back rather than stranding
    // them in a folder the grid no longer offers.
    if (_selectedCategory != null &&
        !_categoriesFor(property).contains(_selectedCategory)) {
      return _buildCategoryGrid(property);
    }
```

- [ ] **Step 5: Delete manual entry from both folder states**

Remove the `if (category == 'loan') ...[ ... ]` block containing the "Enter figures manually" `TextButton.icon` in **both** places (the empty state around line 767 and the populated state around line 1168, including the comment above the latter about it being "the only way back in to correct a typo" — Task 4 makes that comment obsolete by putting a permanent control on the finance tab).

Then delete `_openManualLoanEntry()` (around line 1267), now unreachable, and remove the now-unused `manual_loan_entry_sheet.dart` import if nothing else in the file uses it.

- [ ] **Step 6: Run the task's test**

Run: `flutter test test/features/landlord/documents_loan_folder_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 7: Run the full Flutter suite**

Run: `flutter test`
Expected: 247 passed, **1 failed**. If an existing documents-screen test asserted on "Enter figures manually", update that test — the button is gone by design.

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/5-Documents/documents_screen.dart residex_app/test/features/landlord/documents_loan_folder_test.dart
git commit -m "feat(loans): hide the Loans folder in manual mode, drop its manual entry"
```

---

### Task 3: The nudge stops mentioning loans in manual mode

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart`
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`

**Interfaces:**
- Consumes: `Property.loanInputMethod`
- Produces: nothing downstream

- [ ] **Step 1: Write the failing test**

The file already has `_pumpScreenWithProperty(tester, year, summary, property)` (line 54) and `_fakeProperty({required bool hasMortgage, required String? loanInputMethod})` (line 75). **Use those — do not invent new ones.**

Add one fixture helper beside them, building a summary whose property block has missing categories. Copy the `FinanceSummary` / `FinanceTotals` / `PropertyFinance` construction from an existing test in the same file and set `missingCategories: {'p1': categories}`:

```dart
FinanceSummary _summaryMissing(List<String> categories) {
  // ... same shape as the file's other fixtures, plus:
  //   missingCategories: {'p1': categories},
}
```

Then append:

```dart
  testWidgets('a manual property drops loans from the missing-docs nudge',
      (tester) async {
    // The panel row (Task 4) owns loan entry in manual mode. A nudge offering
    // the same action would put two affordances for one job on one screen.
    await _pumpScreenWithProperty(tester, 2026, _summaryMissing(['loan']),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'));

    expect(find.text('Enter figures manually'), findsNothing);
    expect(find.textContaining('Loans'), findsNothing);
  });

  testWidgets('an upload property still nudges about loan documents',
      (tester) async {
    await _pumpScreenWithProperty(tester, 2026, _summaryMissing(['loan']),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'upload'));

    expect(find.text('Enter figures manually'), findsNothing);
    expect(find.textContaining('document'), findsWidgets);
  });

  testWidgets('other missing categories still nudge for a manual property',
      (tester) async {
    await _pumpScreenWithProperty(tester, 2026, _summaryMissing(['loan', 'tax']),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'));

    expect(find.textContaining('document'), findsWidgets);
  });
```

Match the exact nudge copy when asserting — read `document_nudge_banner.dart` for the strings it renders rather than guessing at them.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/landlord/finance_screen_test.dart`
Expected: FAIL — the nudge still renders for a manual property and still passes `onEnterManually`.

- [ ] **Step 3: Filter loans out of the missing list**

In `_buildPropertyBlock`, replace:

```dart
    final missing = summary.missingCategories[block.propertyId] ?? const [];
```

with:

```dart
    final rawMissing = summary.missingCategories[block.propertyId] ?? const [];
    // A manual-mode landlord has no loan documents to upload and a permanent
    // figures row below, so nudging about loans is either wrong or duplicate.
    final missing = property?.loanInputMethod == 'manual'
        ? rawMissing.where((c) => c != 'loan').toList()
        : rawMissing;
```

`property` is already read on the next line — move that read above this block.

- [ ] **Step 4: Stop passing onEnterManually**

In the `DocumentNudgeBanner(...)` call, delete the whole `onEnterManually:` argument:

```dart
              onEnterManually: missing.contains('loan')
                  ? () => _openManualLoanSheet(
                      context, block, property, summary.year)
                  : null,
```

Leave `document_nudge_banner.dart` itself untouched — the parameter stays supported for other callers; nothing passes it now.

- [ ] **Step 5: Run the task's test**

Run: `flutter test test/features/landlord/finance_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Run the full Flutter suite**

Run: `flutter test`
Expected: 250 passed, **1 failed**

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat(loans): the nudge stops mentioning loans in manual mode"
```

---

### Task 4: A permanent loan figures row with a Modify control

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart`
- Test: `residex_app/test/features/landlord/finance_screen_test.dart`

**Interfaces:**
- Consumes: `Property.loanInputMethod`; `manualLoanEntriesProvider((propertyId:, year:))` from `documind_provider.dart:479`
- Produces: nothing downstream

- [ ] **Step 1: Write the failing test**

`_pumpScreenWithProperty` does not override `manualLoanEntriesProvider`, so add a third pump helper beside it (copy its body and add the one override — do not modify the existing two, other tests depend on them):

```dart
Future<void> _pumpScreenWithLoanEntries(
  WidgetTester tester,
  int year,
  FinanceSummary summary,
  Property property,
  List<Map<String, dynamic>> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeYearsProvider.overrideWith((ref) async => [year]),
        financeSummaryProvider.overrideWith((ref, y) async => summary),
        propertyByIdProvider.overrideWith((ref, id) async => property),
        manualLoanEntriesProvider.overrideWith((ref, args) async => entries),
      ],
      child: const MaterialApp(home: FinanceScreen()),
    ),
  );
  await tester.pumpAndSettle();
}
```

Import `manualLoanEntriesProvider` from `documind_provider.dart`. Reuse whichever plain summary fixture the file already has for the non-missing cases — the tests below call it `_summary()`; substitute the real name.

```dart
  testWidgets('a manual property with booked figures shows them with Modify',
      (tester) async {
    await _pumpScreenWithLoanEntries(tester, 2026, _summary(),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'), [
      {'interest_paid': 8200.0, 'principal_paid': 14000.0,
       'month': null, 'unit_id': null, 'cadence': 'annual'},
    ]);

    expect(find.text('Loan figures · 2026'), findsOneWidget);
    expect(find.text('Modify'), findsOneWidget);
    expect(find.textContaining('8,200'), findsOneWidget);
    expect(find.textContaining('14,000'), findsOneWidget);
    // The old button vanished once figures existed; this must not.
    expect(find.text('Add loan figures'), findsNothing);
  });

  testWidgets('a manual property with no figures still offers Add',
      (tester) async {
    await _pumpScreenWithLoanEntries(tester, 2026, _summary(),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'), const []);

    expect(find.text('Add loan figures'), findsOneWidget);
    expect(find.text('Modify'), findsNothing);
  });

  testWidgets('an upload property shows no loan figures row', (tester) async {
    await _pumpScreenWithLoanEntries(tester, 2026, _summary(),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'upload'), const []);

    expect(find.text('Add loan figures'), findsNothing);
    expect(find.text('Modify'), findsNothing);
  });

  testWidgets('figures sum across property-level and per-unit entries',
      (tester) async {
    await _pumpScreenWithLoanEntries(tester, 2026, _summary(),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'), [
      {'interest_paid': 1000.0, 'principal_paid': 2000.0,
       'month': null, 'unit_id': null, 'cadence': 'annual'},
      {'interest_paid': 500.0, 'principal_paid': 1000.0,
       'month': null, 'unit_id': 'u1', 'cadence': 'annual'},
    ]);

    expect(find.textContaining('1,500'), findsOneWidget);
    expect(find.textContaining('3,000'), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/landlord/finance_screen_test.dart`
Expected: FAIL — no "Loan figures · 2026" row exists.

- [ ] **Step 3: Change the gate**

Replace:

```dart
    final showManualLoan =
        block.manualLoanIncomplete && property?.hasMortgage == true;
```

with:

```dart
    // Gated on the method, not on completeness. manualLoanIncomplete goes
    // false the moment figures are booked, which hid the control exactly when
    // a typo needed correcting — and the Loans-folder route that used to cover
    // that gap is gone.
    final showManualLoan =
        property?.loanInputMethod == 'manual' && property?.hasMortgage == true;
```

- [ ] **Step 4: Replace the button block with the row**

Replace the whole `if (showManualLoan) ...[ ... ]` block with:

```dart
          if (showManualLoan) ...[
            const SizedBox(height: 8),
            _buildLoanFiguresRow(context, ref, block, property, summary.year),
          ],
```

- [ ] **Step 5: Build the row**

Add this method to the same state class:

```dart
  /// Reads the raw booked entries rather than the loan expense lines: expense
  /// amounts are scaled by ownership share at the engine's choke point, and a
  /// row whose job is letting the landlord verify what they typed must show
  /// what they typed.
  Widget _buildLoanFiguresRow(BuildContext context, WidgetRef ref,
      PropertyFinance block, Property? property, int year) {
    final entriesAsync = ref.watch(manualLoanEntriesProvider(
        (propertyId: block.propertyId, year: year)));

    final entries = entriesAsync.asData?.value ?? const <Map<String, dynamic>>[];
    double sum(String key) => entries.fold<double>(
        0, (total, e) => total + ((e[key] as num?)?.toDouble() ?? 0));
    final interest = sum('interest_paid');
    final principal = sum('principal_paid');
    final hasFigures = interest > 0 || principal > 0;

    if (!hasFigures) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () =>
              _openManualLoanSheet(context, block, property, year),
          icon: const Icon(Icons.add, size: 18, color: AppColors.registry),
          label: Text('Add loan figures', style: AppTextStyles.labelLarge),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20, color: AppColors.hairline),
        Row(
          children: [
            Expanded(
              child: Text('Loan figures · $year',
                  style: AppTextStyles.titleMedium),
            ),
            // Trailing edge of the title row: read together with the label it
            // modifies, clear of the amounts, and where the panel already puts
            // row-level actions.
            TextButton.icon(
              onPressed: () =>
                  _openManualLoanSheet(context, block, property, year),
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.registry),
              label: Text('Modify', style: AppTextStyles.labelLarge),
            ),
          ],
        ),
        _loanFigureLine('Interest', interest),
        _loanFigureLine('Principal', principal),
      ],
    );
  }

  Widget _loanFigureLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted)),
          ),
          Text(formatRM(amount), style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
```

Add the import if absent:

```dart
import '../../providers/documind_provider.dart';
```

- [ ] **Step 6: Run the task's test**

Run: `flutter test test/features/landlord/finance_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Run the full Flutter suite**

Run: `flutter test`
Expected: 254 passed, **1 failed**

- [ ] **Step 8: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart residex_app/test/features/landlord/finance_screen_test.dart
git commit -m "feat(loans): permanent loan figures row with a Modify control"
```

---

### Task 5: Prefill the entry sheet so Modify cannot destroy data

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart`
- Test: `residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart` (create, or extend if one exists)

**Interfaces:**
- Consumes: `manualLoanEntriesProvider`, already watched by the sheet at line 166
- Produces: nothing downstream

**Why this is not optional:** `_save` reads `double.tryParse(text) ?? 0`. On a blank field that writes **0**. A landlord opening Modify to fix interest, typing it, and saving would zero their principal. Task 4 ships the Modify button; without this task it is a data-loss bug.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart`, overriding `manualLoanEntriesProvider` and `financeSummaryProvider`. Assert:

```dart
  testWidgets('opens prefilled with the booked figures for the scope', ...);
  testWidgets('a scope with no booked entry opens empty', ...);
  testWidgets('changing the selected unit re-prefills from that unit', ...);
  testWidgets('changing the month re-prefills when cadence is monthly', ...);
```

For the first: seed one entry `{'interest_paid': 8200.0, 'principal_paid': 14000.0, 'month': null, 'unit_id': null, 'cadence': 'annual'}` and assert the two `TextField`s hold `'8200.0'` and `'14000.0'` via `tester.widget<TextField>(...).controller!.text`.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/landlord/manual_loan_entry_sheet_test.dart`
Expected: FAIL — both fields are empty.

- [ ] **Step 3: Add the prefill**

An entry is keyed by `(unit_id, month)` — `_save` writes `month: _cadence == 'monthly' ? _month : null`. Prefill must match on the same key, so add:

```dart
  /// The booked entry for the scope currently selected in the sheet. An entry
  /// is keyed by (unit_id, month), exactly as _save writes it.
  Map<String, dynamic>? _entryForCurrentScope(List<Map<String, dynamic>> entries) {
    final month = _cadence == 'monthly' ? _month : null;
    for (final entry in entries) {
      final entryMonth = (entry['month'] as num?)?.toInt();
      if (entry['unit_id'] == _selectedUnitId && entryMonth == month) {
        return entry;
      }
    }
    return null;
  }

  /// Load the booked figures into the fields so Modify opens ready to correct.
  /// Without this, _save's `?? 0` writes zero over whichever field the
  /// landlord did not retype.
  void _prefillFor(List<Map<String, dynamic>> entries) {
    final entry = _entryForCurrentScope(entries);
    final interest = (entry?['interest_paid'] as num?)?.toDouble();
    final principal = (entry?['principal_paid'] as num?)?.toDouble();
    final nextInterest = interest == null ? '' : '$interest';
    final nextPrincipal = principal == null ? '' : '$principal';
    if (_interestController.text != nextInterest) {
      _interestController.text = nextInterest;
    }
    if (_principalController.text != nextPrincipal) {
      _principalController.text = nextPrincipal;
    }
  }
```

The equality guards matter: this runs from `build`, and assigning `.text` unconditionally would fight the landlord's typing on every rebuild.

- [ ] **Step 4: Call it when entries resolve and when scope changes**

In `build`, after `entriesAsync` is read, prefill from the loaded data:

```dart
    final entries = entriesAsync.asData?.value ?? const <Map<String, dynamic>>[];
    // Scope-keyed, so switching unit or month reloads that scope's figures.
    _prefillFor(entries);
```

Track the last scope prefilled so a landlord's in-progress edit is not overwritten by an unrelated rebuild:

```dart
  ({String? unitId, int? month})? _prefilledScope;
```

and guard `_prefillFor` so it only writes when the scope differs from `_prefilledScope`, updating it after each write.

- [ ] **Step 5: Run the task's test**

Run: `flutter test test/features/landlord/manual_loan_entry_sheet_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Run the full Flutter suite**

Run: `flutter test`
Expected: 258 passed, **1 failed**

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart residex_app/test/features/landlord/manual_loan_entry_sheet_test.dart
git commit -m "fix(loans): prefill the entry sheet so Modify cannot zero a figure"
```

---

## Manual verification (after all tasks)

Run the app and, on a property with a mortgage:

1. Edit the property → the two cards appear under the mortgage question; pick **Enter figures myself**.
2. Documents tab → the **Loans & Financing** folder is gone.
3. Finance tab → the property panel offers **Add loan figures**; add interest and principal.
4. The panel now shows **Loan figures · <year>** with both amounts and a **Modify** control, and it stays there.
5. Tap **Modify** → both fields open **prefilled**. Change only interest, save.
6. The panel shows the new interest and the **unchanged** principal. This is the data-loss guard; if principal became 0, Task 5 regressed.
7. Edit the property → pick **Upload statements**. The Loans folder reappears with any previously uploaded documents intact, and the figures row disappears.
