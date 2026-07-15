# Plan C — Finance Tab, Onboarding & Expiry Intelligence (Flutter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [`docs/superpowers/specs/2026-07-15-documind-financial-intelligence-design.md`](../specs/2026-07-15-documind-financial-intelligence-design.md) (Plan C of three). **Requires Plans A and B** deployed on the backend: `extracted_facts` on documents, the 7-category taxonomy, and `GET /api/rex/documind/finance/summary`.

**Goal:** A 4th "Finance" bottom tab rendering the engine's summary (year selector, headline panel, per-property blocks, unit drill-down, completeness indicator), an ownership-share field on the property form, a skippable guided document checklist after property creation, and the dashboard expiry tile (lease + insurance) tapping through to DocuMind — completing the spec's full demo beat.

**Architecture:** Follows the repo's clean-architecture chain exactly: entity (`domain/entities`) ← model parse (`data/models`) ← datasource (HTTP) ← repository ← Riverpod providers ← screens. All money figures come from the backend engine — the app formats, never computes. Pure logic (year options, money formatting, expiry fold) lives in plain-Dart files with unit tests, mirroring the `documind_chat_logic.dart` precedent.

**Tech Stack:** Flutter + Riverpod (`FutureProvider.family`, `StateProvider`), `http` datasource, existing `DocumentViewerScreen` for source PDFs, `file_picker` for uploads. No new packages.

## Global Constraints

- Flutter commands run from `residex_app/`: `flutter test` (baseline after Plan A: 36 passing) and `flutter analyze` (must stay at 0 errors).
- **No emoji anywhere in user-facing UI** — icon glyphs + `AppColors` tokens only. This plan also removes the two pre-existing `✅` snackbars it touches in `add_property_dialog.dart` (retroactive cleanup per app convention).
- The app never computes money: every figure rendered comes from `FinanceSummary`; the only client-side "math" is date/count formatting.
- The statutory figure is never rendered without its estimate label and an affordance to the caveats.
- Currency renders as `RM 60,106.58` via the shared `formatRM` helper.
- `ownership_share` is stored on `properties/{pid}` as a double 0–1 (absent = 1.0); the form shows it as a percentage.
- Commit after every task with the exact message given in the task's final step.

---

### Task 1: Finance data layer — entity, model, datasource, repository, providers

**Files:**
- Modify: `residex_app/lib/core/constants/api_constants.dart`
- Create: `residex_app/lib/features/landlord/domain/entities/finance_summary.dart`
- Create: `residex_app/lib/features/landlord/data/models/finance_summary_model.dart`
- Modify: `residex_app/lib/features/landlord/data/datasources/documind_remote_datasource.dart`
- Modify: `residex_app/lib/features/landlord/domain/repositories/documind_repository.dart`
- Modify: `residex_app/lib/features/landlord/data/repositories/documind_repository_impl.dart`
- Create: `residex_app/lib/features/landlord/presentation/providers/finance_logic.dart`
- Create: `residex_app/lib/features/landlord/presentation/providers/finance_providers.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (invalidations)
- Create: `residex_app/test/features/landlord/finance_summary_model_test.dart`
- Create: `residex_app/test/features/landlord/finance_logic_test.dart`

**Interfaces:**
- Consumes: Plan B's endpoint `GET /api/rex/documind/finance/summary?landlord_id=&year=`; Plan A's `DocuMindDocument.extractedFacts`.
- Produces: entities `FinanceSummary`, `FinanceTotals`, `PropertyFinance`, `UnitFinance`, `MonthIncome`, `ExpenseLine`; `FinanceSummaryModel.fromJson(Map) -> FinanceSummary`; repository method `getFinanceSummary({required String landlordId, required int year})`; providers `financeYearProvider: StateProvider<int>`, `financeYearsProvider: FutureProvider<List<int>>`, `financeSummaryProvider: FutureProvider.family<FinanceSummary, int>`; pure helpers `formatRM(double) -> String` and `financeYearOptions(List<DocuMindDocument>, int) -> List<int>`. Tasks 2/3/6 consume all of these.

- [ ] **Step 1: Write the failing tests**

Create `residex_app/test/features/landlord/finance_summary_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/finance_summary_model.dart';

void main() {
  final json = {
    'year': 2025,
    'totals': {
      'received_rent': 84000.0,
      'derived_rent': 11000.0,
      'direct_expenses': 59516.87,
      'net_pl': 24483.13,
      'statutory_rental_income': 24483.13,
      'statutory_note': 'Estimate — for your tax agent',
    },
    'expense_breakdown': {'loan': 32000.0, 'tax': 1816.87},
    'properties': [
      {
        'property_id': 'p1',
        'name': 'Ayer 8',
        'ownership_share': 0.5,
        'received_rent': 84000.0,
        'derived_rent': 11000.0,
        'direct_expenses': 59516.87,
        'rental_income_or_loss': 24483.13,
        'units': [
          {
            'unit_id': 'u1',
            'label': 'Unit A',
            'rented_months': 11,
            'contribution': 83500.0,
            'months': [
              {'month': 1, 'source': 'actual', 'amount': 7000.0},
              {'month': 2, 'source': 'derived', 'amount': 7000.0},
              {'month': 3, 'source': 'vacant', 'amount': 0.0},
            ],
            'missing_invoice_months': [3],
            'expense_lines': [
              {
                'doc_id': 'd9',
                'category': 'upkeep',
                'subtype': null,
                'description': 'Aircon servicing',
                'amount': 500.0,
                'date': '2025-03-12',
                'unit_id': 'u1',
              }
            ],
          }
        ],
        'expense_lines': [
          {
            'doc_id': 'd1',
            'category': 'loan',
            'subtype': 'interest_statement',
            'description': 'Loan interest',
            'amount': 32000.0,
            'date': '2025',
            'unit_id': null,
          }
        ],
        'property_expense_lines': [
          {
            'doc_id': 'd1',
            'category': 'loan',
            'subtype': 'interest_statement',
            'description': 'Loan interest',
            'amount': 32000.0,
            'date': '2025',
            'unit_id': null,
          }
        ],
      }
    ],
    'caveats': ['Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed.'],
    'missing_categories': {
      'p1': ['insurance', 'maintenance']
    },
  };

  test('fromJson parses the full summary shape', () {
    final summary = FinanceSummaryModel.fromJson(json);
    expect(summary.year, 2025);
    expect(summary.totals.statutoryRentalIncome, 24483.13);
    expect(summary.totals.statutoryNote, contains('Estimate'));
    expect(summary.expenseBreakdown['loan'], 32000.0);
    final block = summary.properties.single;
    expect(block.name, 'Ayer 8');
    expect(block.ownershipShare, 0.5);
    final unit = block.units.single;
    expect(unit.rentedMonths, 11);
    expect(unit.months[1].source, 'derived');
    expect(unit.missingInvoiceMonths, [3]);
    expect(unit.expenseLines.single.description, 'Aircon servicing');
    expect(block.propertyExpenseLines.single.docId, 'd1');
    expect(summary.missingCategories['p1'], ['insurance', 'maintenance']);
  });

  test('fromJson tolerates missing optional fields', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2026,
      'totals': {
        'received_rent': 0,
        'derived_rent': 0,
        'direct_expenses': 0,
        'net_pl': 0,
        'statutory_rental_income': 0,
        'statutory_note': 'Estimate — for your tax agent',
      },
    });
    expect(summary.properties, isEmpty);
    expect(summary.caveats, isEmpty);
    expect(summary.expenseBreakdown, isEmpty);
  });
}
```

Create `residex_app/test/features/landlord/finance_logic_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_logic.dart';

DocuMindDocument _doc(String category, Map<String, dynamic>? facts) {
  return DocuMindDocument(
    docId: 'd', landlordId: 'l1', propertyId: 'p1', category: category,
    filename: 'f.pdf', chunksIndexed: 1, uploadedAt: DateTime(2026, 1, 1),
    extractedFacts: facts,
  );
}

void main() {
  test('formatRM adds thousand separators and two decimals', () {
    expect(formatRM(60106.58), 'RM 60,106.58');
    expect(formatRM(1500), 'RM 1,500.00');
    expect(formatRM(0), 'RM 0.00');
    expect(formatRM(-500.5), '-RM 500.50');
  });

  test('financeYearOptions derives years from facts plus current year', () {
    final docs = [
      _doc('rental_invoice', {'amount': 1000.0, 'period_month': '2024-05'}),
      _doc('tax', {'amount': 460.0, 'period_year': 2023}),
      _doc('lease', {'monthly_rent': 900.0, 'lease_start': '2025-01-01', 'lease_end': '2025-12-31'}),
      _doc('lease', null),
    ];
    expect(financeYearOptions(docs, 2026), [2026, 2025, 2024, 2023]);
  });

  test('financeYearOptions with no docs is just the current year', () {
    expect(financeYearOptions(const [], 2026), [2026]);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `residex_app/`: `flutter test test/features/landlord/finance_summary_model_test.dart test/features/landlord/finance_logic_test.dart`
Expected: compile errors — the files don't exist.

- [ ] **Step 3: Implement the entity**

Create `residex_app/lib/features/landlord/domain/entities/finance_summary.dart`:

```dart
/// Deterministic finance summary computed by the backend engine
/// (GET /api/rex/documind/finance/summary). Pure display data — the app
/// never recomputes any figure.
class FinanceSummary {
  final int year;
  final FinanceTotals totals;
  final Map<String, double> expenseBreakdown;
  final List<PropertyFinance> properties;
  final List<String> caveats;
  final Map<String, List<String>> missingCategories;

  FinanceSummary({
    required this.year,
    required this.totals,
    this.expenseBreakdown = const {},
    this.properties = const [],
    this.caveats = const [],
    this.missingCategories = const {},
  });
}

class FinanceTotals {
  final double receivedRent;
  final double derivedRent;
  final double directExpenses;
  final double netPl;
  final double statutoryRentalIncome;
  final String statutoryNote;

  FinanceTotals({
    required this.receivedRent,
    required this.derivedRent,
    required this.directExpenses,
    required this.netPl,
    required this.statutoryRentalIncome,
    required this.statutoryNote,
  });
}

class PropertyFinance {
  final String propertyId;
  final String name;
  final double ownershipShare;
  final double receivedRent;
  final double derivedRent;
  final double directExpenses;
  final double rentalIncomeOrLoss;
  final List<UnitFinance> units;
  final List<ExpenseLine> expenseLines;
  final List<ExpenseLine> propertyExpenseLines;

  PropertyFinance({
    required this.propertyId,
    required this.name,
    this.ownershipShare = 1.0,
    required this.receivedRent,
    required this.derivedRent,
    required this.directExpenses,
    required this.rentalIncomeOrLoss,
    this.units = const [],
    this.expenseLines = const [],
    this.propertyExpenseLines = const [],
  });
}

class UnitFinance {
  /// Null = the synthetic "Whole property" income line.
  final String? unitId;
  final String label;
  final int rentedMonths;
  final double contribution;
  final List<MonthIncome> months;
  final List<int> missingInvoiceMonths;
  final List<ExpenseLine> expenseLines;

  UnitFinance({
    this.unitId,
    required this.label,
    required this.rentedMonths,
    required this.contribution,
    this.months = const [],
    this.missingInvoiceMonths = const [],
    this.expenseLines = const [],
  });
}

class MonthIncome {
  final int month; // 1-12
  final String source; // actual | derived | vacant
  final double amount;

  MonthIncome({required this.month, required this.source, required this.amount});
}

class ExpenseLine {
  final String docId;
  final String category;
  final String? subtype;
  final String? description;
  final double amount;
  final String? date;
  final String? unitId; // null = property-level expense

  ExpenseLine({
    required this.docId,
    required this.category,
    this.subtype,
    this.description,
    required this.amount,
    this.date,
    this.unitId,
  });
}
```

- [ ] **Step 4: Implement the model parser**

Create `residex_app/lib/features/landlord/data/models/finance_summary_model.dart`:

```dart
import '../../domain/entities/finance_summary.dart';

/// JSON -> FinanceSummary parsing for the finance summary endpoint.
/// Defensive: absent/oddly-typed fields fall back to zeros/empties so a
/// malformed field can never crash the Finance tab.
class FinanceSummaryModel {
  static FinanceSummary fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      totals: _totals(json['totals'] as Map<String, dynamic>? ?? const {}),
      expenseBreakdown: _doubleMap(json['expense_breakdown']),
      properties: (json['properties'] as List<dynamic>? ?? const [])
          .map((p) => _property(p as Map<String, dynamic>))
          .toList(),
      caveats: (json['caveats'] as List<dynamic>? ?? const [])
          .map((c) => c.toString())
          .toList(),
      missingCategories: (json['missing_categories'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(
                key,
                (value as List<dynamic>? ?? const []).map((v) => v.toString()).toList(),
              )),
    );
  }

  static FinanceTotals _totals(Map<String, dynamic> json) {
    return FinanceTotals(
      receivedRent: _d(json['received_rent']),
      derivedRent: _d(json['derived_rent']),
      directExpenses: _d(json['direct_expenses']),
      netPl: _d(json['net_pl']),
      statutoryRentalIncome: _d(json['statutory_rental_income']),
      statutoryNote: json['statutory_note'] as String? ?? 'Estimate — for your tax agent',
    );
  }

  static PropertyFinance _property(Map<String, dynamic> json) {
    return PropertyFinance(
      propertyId: json['property_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Property',
      ownershipShare: json['ownership_share'] == null ? 1.0 : _d(json['ownership_share']),
      receivedRent: _d(json['received_rent']),
      derivedRent: _d(json['derived_rent']),
      directExpenses: _d(json['direct_expenses']),
      rentalIncomeOrLoss: _d(json['rental_income_or_loss']),
      units: (json['units'] as List<dynamic>? ?? const [])
          .map((u) => _unit(u as Map<String, dynamic>))
          .toList(),
      expenseLines: _lines(json['expense_lines']),
      propertyExpenseLines: _lines(json['property_expense_lines']),
    );
  }

  static UnitFinance _unit(Map<String, dynamic> json) {
    return UnitFinance(
      unitId: json['unit_id'] as String?,
      label: json['label'] as String? ?? 'Unit',
      rentedMonths: (json['rented_months'] as num?)?.toInt() ?? 0,
      contribution: _d(json['contribution']),
      months: (json['months'] as List<dynamic>? ?? const [])
          .map((m) => m as Map<String, dynamic>)
          .map((m) => MonthIncome(
                month: (m['month'] as num?)?.toInt() ?? 0,
                source: m['source'] as String? ?? 'vacant',
                amount: _d(m['amount']),
              ))
          .toList(),
      missingInvoiceMonths: (json['missing_invoice_months'] as List<dynamic>? ?? const [])
          .map((m) => (m as num).toInt())
          .toList(),
      expenseLines: _lines(json['expense_lines']),
    );
  }

  static List<ExpenseLine> _lines(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((l) => l as Map<String, dynamic>)
        .map((l) => ExpenseLine(
              docId: l['doc_id'] as String? ?? '',
              category: l['category'] as String? ?? 'other',
              subtype: l['subtype'] as String?,
              description: l['description'] as String?,
              amount: _d(l['amount']),
              date: l['date'] as String?,
              unitId: l['unit_id'] as String?,
            ))
        .toList();
  }

  static Map<String, double> _doubleMap(dynamic value) {
    return (value as Map<String, dynamic>? ?? const {})
        .map((key, v) => MapEntry(key, _d(v)));
  }

  static double _d(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
```

- [ ] **Step 5: Implement the pure logic helpers**

Create `residex_app/lib/features/landlord/presentation/providers/finance_logic.dart`:

```dart
import '../../domain/entities/documind_document.dart';

/// Currency display: the app formats, never computes.
String formatRM(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}RM $buffer.${parts[1]}';
}

/// Display labels for the 7-category taxonomy (Finance-tab surfaces).
const Map<String, String> financeCategoryLabels = {
  'lease': 'Tenancy agreement',
  'insurance': 'Insurance policy',
  'loan': 'Loan interest statement',
  'tax': 'Assessment tax / quit rent',
  'upkeep': 'Upkeep receipt',
  'maintenance': 'Maintenance statement',
  'rental_invoice': 'Rent invoice',
};

const List<String> monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Year-selector options: every year an extracted fact mentions, plus the
/// current year, newest first.
List<int> financeYearOptions(List<DocuMindDocument> docs, int currentYear) {
  final years = <int>{currentYear};

  void addFromDateString(dynamic value) {
    if (value is String && value.length >= 4) {
      final year = int.tryParse(value.substring(0, 4));
      if (year != null && year > 1990 && year < 2200) years.add(year);
    }
  }

  for (final doc in docs) {
    final facts = doc.extractedFacts;
    if (facts == null) continue;
    addFromDateString(facts['period_month']);
    addFromDateString(facts['lease_start']);
    addFromDateString(facts['lease_end']);
    addFromDateString(facts['service_date']);
    addFromDateString(facts['period_start']);
    addFromDateString(facts['policy_start']);
    final periodYear = facts['period_year'];
    if (periodYear is int && periodYear > 1990 && periodYear < 2200) {
      years.add(periodYear);
    }
  }

  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}
```

- [ ] **Step 6: Run the two test files — expect PASS**

Run: `flutter test test/features/landlord/finance_summary_model_test.dart test/features/landlord/finance_logic_test.dart`
Expected: 5 PASS.

- [ ] **Step 7: Wire datasource, repository, providers**

`residex_app/lib/core/constants/api_constants.dart` — add:

```dart
  static const String documindFinanceSummary = '/api/rex/documind/finance/summary';
```

`documind_remote_datasource.dart` — add imports `'../../domain/entities/finance_summary.dart'` and `'../models/finance_summary_model.dart'`, then append the method before `getDocumentViewUrl`:

```dart
  /// Deterministic finance summary for one landlord and calendar year.
  Future<FinanceSummary> getFinanceSummary({
    required String landlordId,
    required int year,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindFinanceSummary}')
        .replace(queryParameters: {
      'landlord_id': landlordId,
      'year': '$year',
    });

    final response = await httpClient.get(uri);

    if (response.statusCode == 200) {
      return FinanceSummaryModel.fromJson(
          json.decode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Finance summary failed: ${response.body}');
  }
```

`documind_repository.dart` — add import `'../entities/finance_summary.dart'` and the abstract method:

```dart
  /// Deterministic finance summary for one landlord and calendar year.
  Future<FinanceSummary> getFinanceSummary({
    required String landlordId,
    required int year,
  });
```

`documind_repository_impl.dart` — add import `'../../domain/entities/finance_summary.dart'` and:

```dart
  @override
  Future<FinanceSummary> getFinanceSummary({
    required String landlordId,
    required int year,
  }) {
    return remoteDataSource.getFinanceSummary(landlordId: landlordId, year: year);
  }
```

Create `residex_app/lib/features/landlord/presentation/providers/finance_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/finance_summary.dart';
import 'documind_provider.dart';
import 'finance_logic.dart';

/// Selected Finance-tab year (defaults to the current year).
final financeYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// Year-selector options, derived from the extracted facts on the
/// landlord's documents plus the current year.
final financeYearsProvider = FutureProvider<List<int>>((ref) async {
  final landlordId = ref.watch(currentLandlordIdProvider);
  final useCase = ref.watch(listDocumentsUseCaseProvider);
  final docs = await useCase(landlordId: landlordId);
  return financeYearOptions(docs, DateTime.now().year);
});

/// Finance summary for one calendar year. Compute-on-read: the backend
/// folds extracted facts fresh on every request — no schedule, zero LLM.
final financeSummaryProvider =
    FutureProvider.family<FinanceSummary, int>((ref, year) async {
  final landlordId = ref.watch(currentLandlordIdProvider);
  final repository = ref.watch(documindRepositoryProvider);
  return repository.getFinanceSummary(landlordId: landlordId, year: year);
});
```

`documind_provider.dart` — add `import 'finance_providers.dart';` and, in **both** `uploadDocumentActionProvider` and `deleteDocumentActionProvider`, after the existing `ref.invalidate(documindDocumentsProvider(propertyId));` line:

```dart
    // Finance figures and year options are folds over the documents.
    ref.invalidate(financeSummaryProvider);
    ref.invalidate(financeYearsProvider);
```

- [ ] **Step 8: Run the full Flutter suite + analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all PASS (36 + 5 = 41); 0 analyzer errors.

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib residex_app/test
git commit -m "feat: finance summary data layer (entity, parser, datasource, providers)"
```

---

### Task 2: The Finance tab — screen shell, year chips, headline, property blocks, completeness

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/landlord_home_screen.dart`
- Create: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart`
- Create: `residex_app/test/features/landlord/finance_screen_smoke_test.dart`

**Interfaces:**
- Consumes: Task 1's providers/entities/`formatRM`; Plan A's `uploadFactSummary` + `isAllowedUploadFilename` (exported by `documind_screen.dart`); `uploadDocumentActionProvider`.
- Produces: `FinanceScreen` (4th tab); `Future<void> uploadDocumentForCategory(BuildContext, WidgetRef, {required String propertyId, required String category})` — a top-level helper in `finance_screen.dart` that Task 3's drill-down and Task 5's checklist reuse. Navigation contract: tapping a unit row pushes Task 3's `UnitFinanceDetailScreen(propertyId:, propertyName:, unit:, year:)` — Task 2 ships with that navigation commented out and Task 3 uncomments it.

- [ ] **Step 1: Write the failing widget smoke test**

Create `residex_app/test/features/landlord/finance_screen_smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/3-Finance/finance_screen.dart';

FinanceSummary _fakeSummary(int year) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: 84000.0,
      derivedRent: 0.0,
      directExpenses: 59516.87,
      netPl: 24483.13,
      statutoryRentalIncome: 24483.13,
      statutoryNote: 'Estimate — for your tax agent',
    ),
    expenseBreakdown: const {'loan': 32000.0},
    properties: [
      PropertyFinance(
        propertyId: 'p1',
        name: 'Ayer 8',
        ownershipShare: 0.5,
        receivedRent: 84000.0,
        derivedRent: 0.0,
        directExpenses: 59516.87,
        rentalIncomeOrLoss: 24483.13,
        units: [
          UnitFinance(
            unitId: 'u1',
            label: 'Unit A',
            rentedMonths: 12,
            contribution: 84000.0,
            months: const [],
          ),
        ],
      ),
    ],
    caveats: const ['Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed.'],
    missingCategories: const {
      'p1': ['insurance']
    },
  );
}

void main() {
  testWidgets('Finance tab renders headline, property block and completeness',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith(
              (ref) async => [DateTime.now().year, DateTime.now().year - 1]),
          financeSummaryProvider.overrideWith(
              (ref, year) async => _fakeSummary(year)),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Statutory Rental Income'), findsOneWidget);
    expect(find.text('RM 24,483.13'), findsWidgets); // statutory + P/L rows
    expect(find.text('Ayer 8'), findsOneWidget);
    expect(find.textContaining('Estimate'), findsWidgets);
    expect(find.text('Unit A'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget); // ownership badge
    expect(find.textContaining('Insurance policy'), findsOneWidget); // missing category
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/landlord/finance_screen_smoke_test.dart`
Expected: compile error — `finance_screen.dart` does not exist.

- [ ] **Step 3: Implement the screen**

Create `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart`:

```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
import '../2-Documind/documind_screen.dart' show isAllowedUploadFilename;
import '../2-Documind/documind_upload_summary.dart';

/// Shared upload affordance: pick a PDF and file it under [category] for
/// [propertyId], property-wide. Reused by the drill-down screen and the
/// guided checklist.
Future<void> uploadDocumentForCategory(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String category,
}) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  if (result == null) return;
  final picked = result.files.single;
  if (!isAllowedUploadFilename(picked.name) || picked.path == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF files are supported.')),
      );
    }
    return;
  }
  try {
    final uploadAction = ref.read(uploadDocumentActionProvider);
    final uploaded = await uploadAction(
      propertyId: propertyId,
      category: category,
      file: File(picked.path!),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uploadFactSummary(category, uploaded.extractedFacts) ??
            'Document uploaded.'),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }
}

/// Finance tab: the engine's numbers rendered per year — headline panel,
/// per-property blocks (mirroring the landlord's reference sheet), unit
/// contribution rows, and the data-completeness indicator. Zero client math.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(financeYearProvider);
    final summaryAsync = ref.watch(financeSummaryProvider(year));
    final yearsAsync = ref.watch(financeYearsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Finance', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.paper,
      ),
      body: RefreshIndicator(
        color: AppColors.registry,
        onRefresh: () async {
          ref.invalidate(financeSummaryProvider(year));
          ref.invalidate(financeYearsProvider);
          await ref.read(financeSummaryProvider(year).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _buildYearChips(ref, year, yearsAsync.value ?? [year]),
            const SizedBox(height: 16),
            ...summaryAsync.when(
              data: (summary) => _buildSummary(context, ref, summary),
              loading: () => const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.registry)),
                ),
              ],
              error: (error, _) => [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Text(
                    "Couldn't load your finances. Check your connection and pull to retry.",
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearChips(WidgetRef ref, int selected, List<int> years) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = years[index];
          final isSelected = year == selected;
          return ChoiceChip(
            label: Text('$year'),
            selected: isSelected,
            selectedColor: AppColors.registry,
            labelStyle: AppTextStyles.labelLarge.copyWith(
              color: isSelected ? Colors.white : AppColors.ink,
            ),
            onSelected: (_) =>
                ref.read(financeYearProvider.notifier).state = year,
          );
        },
      ),
    );
  }

  List<Widget> _buildSummary(
      BuildContext context, WidgetRef ref, FinanceSummary summary) {
    final isEmpty = summary.properties.isEmpty ||
        (summary.totals.receivedRent == 0 &&
            summary.totals.directExpenses == 0);
    if (isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('No financial documents for ${summary.year}',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Upload rent invoices, tax bills, loan statements and receipts — the numbers compute themselves.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      _buildHeadlinePanel(context, summary),
      const SizedBox(height: 20),
      ...summary.properties.map(
        (block) => _buildPropertyBlock(context, ref, summary, block),
      ),
    ];
  }

  Widget _buildHeadlinePanel(BuildContext context, FinanceSummary summary) {
    final totals = summary.totals;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headlineRow('Received Rent', totals.receivedRent),
          if (totals.derivedRent > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'includes ${formatRM(totals.derivedRent)} backfilled from lease terms',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          _headlineRow('Direct Expenses', totals.directExpenses),
          const Divider(height: 20, color: AppColors.hairline),
          _headlineRow('Net P/L', totals.netPl, emphasized: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statutory Rental Income',
                        style: AppTextStyles.labelLarge),
                    Text(
                      totals.statutoryNote,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(formatRM(totals.statutoryRentalIncome),
                  style: AppTextStyles.titleLarge),
              IconButton(
                icon: const Icon(Icons.info_outline,
                    size: 20, color: AppColors.textMuted),
                tooltip: 'Assumptions and caveats',
                onPressed: () => _showCaveats(context, summary.caveats),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headlineRow(String label, double value, {bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.labelLarge)),
          Text(
            formatRM(value),
            style: emphasized
                ? AppTextStyles.displayMedium
                : AppTextStyles.titleMedium,
          ),
        ],
      ),
    );
  }

  void _showCaveats(BuildContext context, List<String> caveats) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assumptions & caveats', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: caveats
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(Icons.circle,
                                      size: 6, color: AppColors.textMuted),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(c,
                                        style: AppTextStyles.bodyMedium)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyBlock(BuildContext context, WidgetRef ref,
      FinanceSummary summary, PropertyFinance block) {
    final missing = summary.missingCategories[block.propertyId] ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(block.name, style: AppTextStyles.titleLarge)),
              if (block.ownershipShare < 1.0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Text(
                    '${(block.ownershipShare * 100).toStringAsFixed(0)}% share',
                    style: AppTextStyles.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _headlineRow('Received Rent', block.receivedRent),
          _headlineRow('Direct Expenses', block.directExpenses),
          _headlineRow('Rental Income/Loss', block.rentalIncomeOrLoss,
              emphasized: true),
          if (block.units.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.hairline),
            ...block.units.map((unit) => InkWell(
                  onTap: () {
                    // Task 3 wires this to UnitFinanceDetailScreen:
                    // Navigator.of(context).push(MaterialPageRoute(
                    //   builder: (_) => UnitFinanceDetailScreen(
                    //     propertyId: block.propertyId,
                    //     propertyName: block.name,
                    //     unit: unit,
                    //     year: summary.year,
                    //   ),
                    // ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined,
                            size: 18, color: AppColors.registry),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(unit.label,
                                style: AppTextStyles.titleMedium)),
                        Text(
                          '${unit.rentedMonths} mo rented',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 10),
                        Text(formatRM(unit.contribution),
                            style: AppTextStyles.titleMedium),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                )),
          ],
          if (missing.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.hairline),
            Text(
              'Missing for ${summary.year} — figures may be incomplete',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missing
                  .map((category) => ActionChip(
                        avatar: const Icon(Icons.upload_file_outlined,
                            size: 16, color: AppColors.registry),
                        label: Text(
                          financeCategoryLabels[category] ?? category,
                          style: AppTextStyles.labelSmall,
                        ),
                        onPressed: () => uploadDocumentForCategory(
                          context,
                          ref,
                          propertyId: block.propertyId,
                          category: category,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add the 4th tab**

`landlord_home_screen.dart` — add import `'3-Finance/finance_screen.dart'`, update the doc comment to describe 4 tabs, insert the tab between Documind and Portfolio:

```dart
  final List<NavTab> _navTabs = const [
    NavTab(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      color: AppColors.registry,
    ),
    NavTab(
      icon: Icons.auto_awesome_outlined,
      label: 'Documind',
      color: AppColors.registry,
    ),
    NavTab(
      icon: Icons.payments_outlined,
      label: 'Finance',
      color: AppColors.registry,
    ),
    NavTab(
      icon: Icons.business_outlined,
      label: 'Portfolio',
      color: AppColors.registry,
    ),
  ];
```

and the screens list (Portfolio's callback index shifts to 3):

```dart
    _screens = [
      LandlordDashboardScreen(
        onOpenDocumind: () => setState(() => _currentIndex = 1),
        onOpenPortfolio: () => setState(() => _currentIndex = 3),
      ),
      const DocuMindScreen(),
      const FinanceScreen(),
      const LandlordPortfolioScreen(),
    ];
```

- [ ] **Step 5: Run the suite + analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all PASS (41 + 1 = 42); 0 analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib residex_app/test
git commit -m "feat: Finance tab with year selector, headline panel, property blocks and completeness chips"
```

---

### Task 3: Unit drill-down screen — month strip, expense lines, missing-invoice affordance

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/3-Finance/finance_screen.dart` (uncomment + wire the unit-row navigation)

**Interfaces:**
- Consumes: Task 1's entities + `formatRM`/`monthAbbrev`; Task 2's `uploadDocumentForCategory`; existing `DocumentViewerScreen(propertyId:, docId:, filename:, page:)` from `2-Documind/document_viewer_screen.dart`.
- Produces: `UnitFinanceDetailScreen({required String propertyId, required String propertyName, required UnitFinance unit, required int year})`.

- [ ] **Step 1: Implement the screen**

Create `residex_app/lib/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/finance_logic.dart';
import '../2-Documind/document_viewer_screen.dart';
import 'finance_screen.dart' show uploadDocumentForCategory;

/// Month-by-month drill-down for one unit (or the whole-property line):
/// income strip, its expense lines (tappable to the source PDF), and a
/// one-tap invoice upload for months with no record.
class UnitFinanceDetailScreen extends ConsumerWidget {
  final String propertyId;
  final String propertyName;
  final UnitFinance unit;
  final int year;

  const UnitFinanceDetailScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
    required this.unit,
    required this.year,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Text('${unit.label} — $year', style: AppTextStyles.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(propertyName, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text('Net contribution',
                        style: AppTextStyles.labelLarge)),
                Text(formatRM(unit.contribution),
                    style: AppTextStyles.displayMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Monthly income', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          _buildMonthStrip(),
          const SizedBox(height: 8),
          _buildLegend(),
          if (unit.missingInvoiceMonths.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMissingInvoices(context, ref),
          ],
          if (unit.expenseLines.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Expenses', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            ...unit.expenseLines.map((line) => _buildExpenseLine(context, line)),
          ],
        ],
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'actual':
        return AppColors.registry;
      case 'derived':
        return AppColors.catUpkeep;
      default:
        return AppColors.hairline;
    }
  }

  Widget _buildMonthStrip() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: unit.months.map((month) {
        final color = _sourceColor(month.source);
        return Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(monthAbbrev[month.month - 1],
                      style: AppTextStyles.labelSmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                month.source == 'vacant' ? '—' : formatRM(month.amount),
                style: AppTextStyles.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        );
    return Wrap(
      spacing: 16,
      children: [
        item(AppColors.registry, 'Invoiced'),
        item(AppColors.catUpkeep, 'From lease terms'),
        item(AppColors.hairline, 'No record'),
      ],
    );
  }

  Widget _buildMissingInvoices(BuildContext context, WidgetRef ref) {
    final names =
        unit.missingInvoiceMonths.map((m) => monthAbbrev[m - 1]).join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('No invoice recorded for $names',
                style: AppTextStyles.bodyMedium),
          ),
          TextButton(
            onPressed: () => uploadDocumentForCategory(
              context,
              ref,
              propertyId: propertyId,
              category: 'rental_invoice',
            ),
            child: const Text('Add invoice'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseLine(BuildContext context, ExpenseLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.description_outlined,
            size: 20, color: AppColors.registry),
        title: Text(
            line.description ??
                (financeCategoryLabels[line.category] ?? line.category),
            style: AppTextStyles.titleMedium),
        subtitle: line.date != null
            ? Text(line.date!, style: AppTextStyles.bodySmall)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatRM(line.amount), style: AppTextStyles.titleMedium),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              propertyId: propertyId,
              docId: line.docId,
              filename: line.description ??
                  (financeCategoryLabels[line.category] ?? line.category),
              page: null,
            ),
          ));
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the navigation in `finance_screen.dart`**

Add `import 'unit_finance_detail_screen.dart';` and replace the commented-out `onTap` body from Task 2 with the live navigation:

```dart
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => UnitFinanceDetailScreen(
                        propertyId: block.propertyId,
                        propertyName: block.name,
                        unit: unit,
                        year: summary.year,
                      ),
                    ));
                  },
```

- [ ] **Step 3: Run the suite + analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all PASS (42); 0 analyzer errors.

- [ ] **Step 4: Manual acceptance (emulator)**

With Plans A+B backend running and demo docs uploaded: Finance tab → tap a unit → month strip shows invoiced/derived/vacant colors, tapping an expense line opens the source PDF, a missing month offers "Add invoice".

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib
git commit -m "feat: unit finance drill-down with month strip and source-document links"
```

---

### Task 4: Ownership share on the property form (+ emoji snackbar cleanup)

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/property.dart`
- Modify: `residex_app/lib/features/landlord/data/models/property_model.dart`
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`
- Create: `residex_app/test/features/landlord/property_model_ownership_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Property.ownershipShare: double` (default 1.0, in `copyWith`); Firestore field `properties/{pid}.ownership_share` (double 0–1, written on create/update, absent treated as 1.0) — the exact field Plan B's `_list_landlord_properties` reads.

- [ ] **Step 1: Write the failing test**

Create `residex_app/test/features/landlord/property_model_ownership_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';

Map<String, dynamic> _propertyJson({double? ownershipShare}) {
  return {
    'landlordId': 'l1',
    'name': 'Kiara Court',
    'address': {
      'street': '1 Jalan Kiara',
      'city': 'Kuala Lumpur',
      'state': 'WP',
      'zipCode': '50480',
      'country': 'Malaysia',
    },
    'type': 'condo',
    'purchasePrice': 500000,
    'currentValue': 550000,
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    if (ownershipShare != null) 'ownership_share': ownershipShare,
  };
}

void main() {
  test('ownership_share parses and round-trips', () {
    final model = PropertyModel.fromJson(_propertyJson(ownershipShare: 0.5), 'p1');
    expect(model.ownershipShare, 0.5);
    expect(model.toJson()['ownership_share'], 0.5);
  });

  test('absent ownership_share defaults to 1.0', () {
    final model = PropertyModel.fromJson(_propertyJson(), 'p1');
    expect(model.ownershipShare, 1.0);
    expect(model.toJson()['ownership_share'], 1.0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/landlord/property_model_ownership_test.dart`
Expected: compile error — `ownershipShare` undefined.

- [ ] **Step 3: Implement entity + model**

`property.dart` — add to the `Property` class after `currentValue`:

```dart
  /// The landlord's share of this property (0-1). Co-ownership is the norm
  /// in the reference data; the finance engine scales the statutory figure
  /// by this. 1.0 = solely owned.
  final double ownershipShare;
```

constructor: `this.ownershipShare = 1.0,` (after `currentValue`); `copyWith` gains `double? ownershipShare` and `ownershipShare: ownershipShare ?? this.ownershipShare,`.

`property_model.dart`:
- constructor: add `super.ownershipShare = 1.0,`
- `fromEntity`: add `ownershipShare: property.ownershipShare,`
- `toEntity`: add `ownershipShare: ownershipShare,`
- `fromJson`: add

```dart
      ownershipShare: json['ownership_share'] != null
          ? _parseDouble(json['ownership_share'])
          : 1.0,
```

- `toJson`: add `'ownership_share': ownershipShare,`

- [ ] **Step 4: Add the form field**

`add_property_dialog.dart`:

**(a)** add a controller beside the others: `final _ownershipShareController = TextEditingController(text: '100');` and dispose it with the rest.

**(b)** in `initState`'s edit-mode prefill block:

```dart
      _ownershipShareController.text =
          (property.ownershipShare * 100).toStringAsFixed(0);
```

**(c)** in `_handleSubmit`, compute once before the create/update branch (after the `address` construction):

```dart
      final ownershipShare =
          double.parse(_ownershipShareController.text) / 100.0;
```

then add `ownershipShare: ownershipShare,` to **both** the `existing.copyWith(...)` call and the new `Property(...)` construction.

**(d)** in the form, inside the "Financial Details" section after the purchase/current value `Row`:

```dart
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _ownershipShareController,
                        label: 'My share of this property (%)',
                        hint: '100 if solely owned',
                        keyboardType: TextInputType.number,
                        validator: _validateSharePercent,
                      ),
```

**(e)** add the validator beside `_validatePositiveInt`:

```dart
  String? _validateSharePercent(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final number = double.tryParse(value);
    if (number == null) return 'Must be a number';
    if (number <= 0 || number > 100) return 'Between 1 and 100';
    return null;
  }
```

**(f)** emoji cleanup (app convention — no emoji in UI): change the success snackbar strings to `'Property updated successfully'` and `'Property added successfully'` (no `✅`).

- [ ] **Step 5: Run the suite + analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all PASS (42 + 2 = 44); 0 analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib residex_app/test
git commit -m "feat: ownership share on property form, stored 0-1 on the property document"
```

---

### Task 5: Guided document checklist after property creation (skippable)

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/widgets/common/guided_document_checklist_sheet.dart`
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart` (show after creation)

**Interfaces:**
- Consumes: Task 2's `uploadDocumentForCategory`.
- Produces: `Future<void> showGuidedDocumentChecklist(BuildContext, {required String propertyId, required String propertyName})`. Nothing blocks property creation — the sheet is dismissible and every item is optional; the Finance tab's completeness indicator (Task 2) is the persistent follow-up.

- [ ] **Step 1: Implement the sheet**

Create `residex_app/lib/features/landlord/presentation/widgets/common/guided_document_checklist_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../screens/3-Finance/finance_screen.dart'
    show uploadDocumentForCategory;

class _ChecklistItem {
  final String category;
  final String title;
  final String hint;
  const _ChecklistItem(this.category, this.title, this.hint);
}

const List<_ChecklistItem> _items = [
  _ChecklistItem('lease', 'Tenancy agreement', 'Rent, deposit and tenancy period'),
  _ChecklistItem('rental_invoice', 'Rent invoice', 'One per month — your income ledger'),
  _ChecklistItem('loan', 'Loan interest statement', "The bank's year-end statement"),
  _ChecklistItem('tax', 'Assessment tax / quit rent bill', 'Cukai pintu, cukai tanah, parcel rent'),
  _ChecklistItem('maintenance', 'Maintenance statement', 'Management fees incl. sinking fund'),
  _ChecklistItem('insurance', 'Insurance policy', 'Fire / houseowner policy schedule'),
];

/// Guided "Add key documents" step after property creation. Fully skippable;
/// uploads are property-wide here (unit scoping stays available later via
/// the Documind tab). The Finance tab's completeness indicator is the
/// persistent follow-up for anything skipped.
Future<void> showGuidedDocumentChecklist(
  BuildContext context, {
  required String propertyId,
  required String propertyName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => GuidedDocumentChecklistSheet(
      propertyId: propertyId,
      propertyName: propertyName,
    ),
  );
}

class GuidedDocumentChecklistSheet extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;

  const GuidedDocumentChecklistSheet({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  ConsumerState<GuidedDocumentChecklistSheet> createState() =>
      _GuidedDocumentChecklistSheetState();
}

class _GuidedDocumentChecklistSheetState
    extends ConsumerState<GuidedDocumentChecklistSheet> {
  final Set<String> _uploaded = {};
  String? _uploading;

  Future<void> _upload(String category) async {
    setState(() => _uploading = category);
    await uploadDocumentForCategory(
      context,
      ref,
      propertyId: widget.propertyId,
      category: category,
    );
    if (mounted) {
      setState(() {
        _uploading = null;
        _uploaded.add(category);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add key documents', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text(
              '${widget.propertyName} — these power the Finance tab and DocuMind. All optional; add them anytime.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.hairline),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final done = _uploaded.contains(item.category);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(item.title, style: AppTextStyles.titleMedium),
                    subtitle: Text(item.hint, style: AppTextStyles.bodySmall),
                    trailing: done
                        ? const Icon(Icons.check_circle_outline,
                            color: AppColors.registry)
                        : _uploading == item.category
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.registry),
                              )
                            : TextButton(
                                onPressed: _uploading != null
                                    ? null
                                    : () => _upload(item.category),
                                child: const Text('Upload'),
                              ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _uploaded.isEmpty ? 'Do this later' : 'Done',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.slate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Show it after creation**

In `add_property_dialog.dart`, add the import:

```dart
import 'guided_document_checklist_sheet.dart';
```

and in `_handleSubmit`, directly after the unit-creation `for` loop (still inside the `else` create branch):

```dart
        if (mounted) {
          // Guided, skippable document checklist (spec): offer the key
          // finance documents right after creation; nothing blocks.
          await showGuidedDocumentChecklist(
            context,
            propertyId: propertyId,
            propertyName: property.name,
          );
        }
```

(The dialog then pops with success exactly as before once the sheet closes.)

- [ ] **Step 3: Run the suite + analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all PASS (44); 0 analyzer errors.

- [ ] **Step 4: Manual acceptance (emulator)**

Create a property → the checklist sheet appears over the dialog → "Do this later" dismisses with nothing blocked; uploading an item shows the fact-confirming snackbar and marks the row.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib
git commit -m "feat: skippable guided document checklist after property creation"
```

---

### Task 6: Dashboard expiry tile (lease + insurance) with tap-through to DocuMind

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/providers/upcoming_expiries.dart`
- Modify: `residex_app/lib/features/landlord/presentation/providers/documind_provider.dart` (nav-target provider)
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (consume nav target; extract `_switchToProperty`)
- Modify: `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart` (tile)
- Create: `residex_app/test/features/landlord/upcoming_expiries_test.dart`

**Interfaces:**
- Consumes: Plan A's `extractedFacts` (`lease_end`, `policy_end`), `listDocumentsUseCaseProvider` (landlord-wide fetch — `propertyId` omitted).
- Produces: `ExpiryEntry` + `foldUpcomingExpiries(List<DocuMindDocument>, DateTime, {int windowDays = 90}) -> List<ExpiryEntry>` + `daysUntil`/`formatExpiryDate`; `upcomingExpiriesProvider: FutureProvider<List<ExpiryEntry>>`; `documindNavTargetProvider: StateProvider<String?>` — setting it to a propertyId and switching to the Documind tab opens DocuMind on that property (no unit filter — the router scopes by phrasing, per spec).

- [ ] **Step 1: Write the failing fold tests**

Create `residex_app/test/features/landlord/upcoming_expiries_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/providers/upcoming_expiries.dart';

DocuMindDocument _doc({
  required String docId,
  required String category,
  Map<String, dynamic>? facts,
  String propertyId = 'p1',
  String? unitId,
  DateTime? uploadedAt,
}) {
  return DocuMindDocument(
    docId: docId, landlordId: 'l1', propertyId: propertyId,
    category: category, filename: '$docId.pdf', chunksIndexed: 1,
    uploadedAt: uploadedAt ?? DateTime(2026, 1, 1),
    unitId: unitId, extractedFacts: facts,
  );
}

void main() {
  final today = DateTime(2026, 7, 16);

  test('folds lease and policy end dates within 90 days, soonest first', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'a', category: 'lease', unitId: 'u1',
          facts: {'lease_end': '2026-09-01'}),
      _doc(docId: 'b', category: 'insurance',
          facts: {'policy_end': '2026-08-01'}),
      _doc(docId: 'c', category: 'tax', facts: {'amount': 100.0}),
    ], today);
    expect(entries.map((e) => e.docId), ['b', 'a']);
    expect(entries.first.kind, 'Policy expires');
    expect(daysUntil(entries.first.date, today), 16);
  });

  test('window boundaries: today counts, day 90 counts, 91 and past excluded', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'today', category: 'lease', propertyId: 'pa',
          facts: {'lease_end': '2026-07-16'}),
      _doc(docId: 'day90', category: 'lease', propertyId: 'pb',
          facts: {'lease_end': '2026-10-14'}),
      _doc(docId: 'day91', category: 'lease', propertyId: 'pc',
          facts: {'lease_end': '2026-10-15'}),
      _doc(docId: 'past', category: 'lease', propertyId: 'pd',
          facts: {'lease_end': '2026-07-15'}),
    ], today);
    expect(entries.map((e) => e.docId), ['today', 'day90']);
  });

  test('most recently uploaded doc wins per (property, unit, category)', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'old', category: 'lease', unitId: 'u1',
          facts: {'lease_end': '2026-08-01'}, uploadedAt: DateTime(2026, 1, 1)),
      _doc(docId: 'new', category: 'lease', unitId: 'u1',
          facts: {'lease_end': '2026-09-01'}, uploadedAt: DateTime(2026, 6, 1)),
    ], today);
    expect(entries.single.docId, 'new');
  });

  test('malformed or missing dates are skipped, never crash', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'bad', category: 'lease', facts: {'lease_end': 'soon'}),
      _doc(docId: 'none', category: 'insurance', facts: {'premium': 640.0}),
      _doc(docId: 'null', category: 'lease', facts: null),
    ], today);
    expect(entries, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/landlord/upcoming_expiries_test.dart`
Expected: compile error — `upcoming_expiries.dart` does not exist.

- [ ] **Step 3: Implement the fold + provider**

Create `residex_app/lib/features/landlord/presentation/providers/upcoming_expiries.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/documind_document.dart';
import 'documind_provider.dart';
import 'finance_logic.dart' show monthAbbrev;

/// One upcoming lease/policy end date for the dashboard tile.
class ExpiryEntry {
  final String docId;
  final String propertyId;
  final String? unitId;
  final String? unitLabel;
  final String category; // lease | insurance
  final String filename;
  final String kind; // 'Lease ends' | 'Policy expires'
  final DateTime date;

  ExpiryEntry({
    required this.docId,
    required this.propertyId,
    this.unitId,
    this.unitLabel,
    required this.category,
    required this.filename,
    required this.kind,
    required this.date,
  });
}

const Map<String, String> _dateKeyByCategory = {
  'lease': 'lease_end',
  'insurance': 'policy_end',
};

const Map<String, String> _kindByCategory = {
  'lease': 'Lease ends',
  'insurance': 'Policy expires',
};

/// Pure fold: every lease/policy end within the next [windowDays], soonest
/// first. Most recently uploaded document wins per (property, unit,
/// category) — a re-uploaded lease supersedes the old one's dates.
/// Malformed dates are skipped, never thrown.
List<ExpiryEntry> foldUpcomingExpiries(
  List<DocuMindDocument> docs,
  DateTime today, {
  int windowDays = 90,
}) {
  final newestByScope = <String, DocuMindDocument>{};
  for (final doc in docs) {
    if (!_dateKeyByCategory.containsKey(doc.category)) continue;
    final key = '${doc.propertyId}|${doc.unitId ?? ''}|${doc.category}';
    final existing = newestByScope[key];
    if (existing == null || doc.uploadedAt.isAfter(existing.uploadedAt)) {
      newestByScope[key] = doc;
    }
  }

  final startOfToday = DateTime(today.year, today.month, today.day);
  final horizon = startOfToday.add(Duration(days: windowDays));
  final entries = <ExpiryEntry>[];
  for (final doc in newestByScope.values) {
    final raw = doc.extractedFacts?[_dateKeyByCategory[doc.category]];
    if (raw is! String) continue;
    final date = DateTime.tryParse(raw);
    if (date == null) continue;
    if (date.isBefore(startOfToday) || date.isAfter(horizon)) continue;
    entries.add(ExpiryEntry(
      docId: doc.docId,
      propertyId: doc.propertyId,
      unitId: doc.unitId,
      unitLabel: doc.unitLabel,
      category: doc.category,
      filename: doc.filename,
      kind: _kindByCategory[doc.category]!,
      date: date,
    ));
  }
  entries.sort((a, b) => a.date.compareTo(b.date));
  return entries;
}

int daysUntil(DateTime date, DateTime today) =>
    DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

String formatExpiryDate(DateTime date) =>
    '${date.day} ${monthAbbrev[date.month - 1]} ${date.year}';

/// Landlord-wide upcoming expiries (lease + insurance), next 90 days.
final upcomingExpiriesProvider = FutureProvider<List<ExpiryEntry>>((ref) async {
  final landlordId = ref.watch(currentLandlordIdProvider);
  final useCase = ref.watch(listDocumentsUseCaseProvider);
  final docs = await useCase(landlordId: landlordId);
  return foldUpcomingExpiries(docs, DateTime.now());
});
```

Add to `documind_provider.dart` (state providers section):

```dart
/// Cross-tab navigation target: set a propertyId here before switching to
/// the Documind tab and the chat opens on that property (expiry-tile
/// tap-through). Consumed and cleared by DocuMindScreen.
final documindNavTargetProvider = StateProvider<String?>((ref) => null);
```

- [ ] **Step 4: Run the fold tests — expect PASS**

Run: `flutter test test/features/landlord/upcoming_expiries_test.dart`
Expected: 4 PASS.

- [ ] **Step 5: Consume the nav target in `documind_screen.dart`**

**(a)** Extract the property-switch reset. The `PopupMenuButton<String>`'s `onSelected` (currently `documind_screen.dart:178-196`) becomes:

```dart
                  onSelected: (propertyId) =>
                      _switchToProperty(propertyId, properties),
```

and the new method (place it after `build`):

```dart
  /// Property switch: reset the conversation and greet on the new property.
  /// Used by the header dropdown and the dashboard expiry-tile tap-through.
  void _switchToProperty(String propertyId, List<Property> properties) {
    setState(() {
      _selectedPropertyId = propertyId;
      _selectedCategory = null;
      _showChatInterface = true;
      _messages.clear();
      _docuMindSessionId = null;
      _docuMindConversationTurn = 1;
      _awaitingUserAction = false;
      _messages.add(
        ChatMessage(
          user: _aiUser,
          createdAt: DateTime.now(),
          text:
              'Switched to ${_getPropertyName(properties, propertyId)}. How can I help?',
        ),
      );
    });
  }
```

**(b)** In `build`'s `data:` branch (currently `:86-100`), consume the target:

```dart
      data: (properties) {
        if (properties.isEmpty) {
          return _buildNoPropertiesState();
        }

        final navTarget = ref.watch(documindNavTargetProvider);

        if (_selectedPropertyId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(documindNavTargetProvider.notifier).state = null;
            setState(() {
              _selectedPropertyId =
                  (navTarget != null && properties.any((p) => p.id == navTarget))
                      ? navTarget
                      : properties.first.id;
            });
          });
          return _buildLoadingState();
        }

        if (navTarget != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(documindNavTargetProvider.notifier).state = null;
            if (navTarget != _selectedPropertyId &&
                properties.any((p) => p.id == navTarget)) {
              _switchToProperty(navTarget, properties);
            }
          });
        }

        return _buildMainUI(properties);
      },
```

- [ ] **Step 6: Add the dashboard tile**

In `landlord_dashboard_screen.dart`, add imports:

```dart
import '../../providers/documind_provider.dart';
import '../../providers/upcoming_expiries.dart';
```

In `_buildContent`, insert directly after the `_buildStatTileRow(stats),` line:

```dart
            _buildExpiryTile(context, ref),
```

and add the builder (after `_buildStatTile`). Hidden entirely when empty — no "nothing expiring" noise:

```dart
  Widget _buildExpiryTile(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(upcomingExpiriesProvider).value ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPCOMING EXPIRIES',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          ...entries.take(3).map((entry) {
            final days = daysUntil(entry.date, today);
            final urgency = days <= 30
                ? AppColors.error
                : days <= 60
                    ? AppColors.catUpkeep
                    : AppColors.ink;
            final scope = entry.unitLabel ?? 'Property-wide';
            return InkWell(
              onTap: () {
                ref.read(documindNavTargetProvider.notifier).state =
                    entry.propertyId;
                onOpenDocumind();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      entry.category == 'lease'
                          ? Icons.description_outlined
                          : Icons.security_outlined,
                      size: 18,
                      color: urgency,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$scope · ${entry.kind} ${formatExpiryDate(entry.date)}',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      days == 0 ? 'today' : 'in $days days',
                      style:
                          AppTextStyles.labelSmall.copyWith(color: urgency),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
```

- [ ] **Step 7: Run the full suite + analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all PASS (44 + 4 = 48); 0 analyzer errors.

- [ ] **Step 8: Manual acceptance — the demo beat**

Create property (guided checklist) → upload lease + invoices + tax bills (some scanned) → Finance tab shows the computed numbers → tap a unit → tap an expense line → source PDF. Dashboard shows "Unit A · Lease ends 1 Sep 2026 (in 47 days)" → tap → DocuMind opens on that property → ask "how much tax did I pay?" → narrated, cited answer.

- [ ] **Step 9: Commit**

```bash
git add residex_app/lib residex_app/test
git commit -m "feat: dashboard expiry tile (lease + insurance) with tap-through to DocuMind"
```

---

## Deliverable check (spec Plan C)

After Task 6 the full demo beat works: 4-tab shell with the Finance tab rendering the engine's figures (year chips, headline with estimate-labeled statutory income and caveats sheet, reference-sheet property blocks with ownership badges, unit drill-down with month strip and source-document links, completeness chips with one-tap category uploads), ownership share editable on the property form, a skippable guided checklist after creation, and the dashboard expiry tile tapping through to DocuMind on the right property.
