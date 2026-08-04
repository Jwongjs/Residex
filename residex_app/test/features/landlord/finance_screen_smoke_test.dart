import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
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
        coverage: [
          YearCoverage(year: 2025, missing: const ['insurance']),
          YearCoverage(year: 2026, missing: const []),
        ],
      ),
    ],
    caveats: const ['Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed.'],
    missingCategories: const {
      'p1': ['insurance']
    },
  );
}

FinanceSummary _incompleteSummaryWithUnavailableGap(int year) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: 5000.0, derivedRent: 0.0, directExpenses: 0.0,
      netPl: 5000.0, statutoryRentalIncome: 0.0,
      statutoryNote: 'Estimate — for your tax agent',
    ),
    properties: [
      PropertyFinance(
        propertyId: 'p1', name: 'Ayer 8',
        receivedRent: 5000.0, derivedRent: 0.0, directExpenses: 0.0, rentalIncomeOrLoss: 5000.0,
        complete: false,
        coverage: [
          YearCoverage(year: year, missing: const ['loan'], unavailable: const ['insurance']),
        ],
      ),
    ],
    missingCategories: const {
      'p1': ['loan']
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

    expect(find.text('Overall Statutory Income'), findsOneWidget);
    expect(find.text('RM 24,483.13'), findsWidgets); // statutory + P/L rows
    expect(find.text('Ayer 8'), findsOneWidget);
    expect(find.textContaining('OVERALL NET PROFIT/LOSS'), findsOneWidget);
    expect(find.text('OVERALL RENTAL INCOME'), findsOneWidget);
    expect(find.text('OVERALL EXPENSES'), findsOneWidget);
    expect(find.textContaining('backfilled'), findsNothing);
    expect(find.textContaining('Records missing for'), findsOneWidget);
    expect(find.text('Unit A'), findsOneWidget);
    expect(find.text('50% share'), findsOneWidget); // ownership badge (exact; the co-ownership caption also says "50%")
    expect(find.textContaining('1 document needed for'), findsOneWidget); // nudge banner
    expect(find.textContaining('1 missing'), findsOneWidget); // coverage chip for 2025
  });

  testWidgets('incomplete year shows the incomplete-records note and an unavailable gap offers Undo', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final year = DateTime.now().year;
    Map<String, dynamic>? markedUnavailable;
    Map<String, dynamic>? clearedUnavailable;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [year]),
          financeSummaryProvider.overrideWith((ref, y) async => _incompleteSummaryWithUnavailableGap(y)),
          setDocumentUnavailableActionProvider.overrideWithValue(({
            required String propertyId,
            required int year,
            required String category,
          }) async {
            markedUnavailable = {'propertyId': propertyId, 'year': year, 'category': category};
          }),
          clearDocumentUnavailableActionProvider.overrideWithValue(({
            required String propertyId,
            required int year,
            required String category,
          }) async {
            clearedUnavailable = {'propertyId': propertyId, 'year': year, 'category': category};
          }),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('records are incomplete'), findsOneWidget);
    expect(find.textContaining('acknowledged unavailable'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Mark unavailable'), findsOneWidget); // nudge banner button

    await tester.ensureVisible(find.text('Mark unavailable'));
    await tester.tap(find.text('Mark unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loan interest statement'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Mark unavailable'));
    await tester.pumpAndSettle();

    expect(markedUnavailable, isNotNull);
    expect(markedUnavailable!['propertyId'], 'p1');
    expect(markedUnavailable!['year'], year);
    expect(markedUnavailable!['category'], 'loan');

    await tester.ensureVisible(find.text('Undo'));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(clearedUnavailable, isNotNull);
    expect(clearedUnavailable!['propertyId'], 'p1');
    expect(clearedUnavailable!['year'], year);
    expect(clearedUnavailable!['category'], 'insurance');
  });

  testWidgets('rent payment issues are reachable from the property block, not just the unit screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var manageOpened = false;
    final year = DateTime.now().year;
    final summary = FinanceSummary(
      year: year,
      // receivedRent/directExpenses non-zero: FinanceScreen's isEmpty check
      // treats an all-zero summary as "no financial documents" and never
      // renders the property block (see _incompleteSummaryWithUnavailableGap
      // above, which sidesteps the same gate).
      totals: FinanceTotals(
        receivedRent: 7700.0, derivedRent: 0.0, directExpenses: 0.0,
        netPl: 7700.0, statutoryRentalIncome: 7700.0,
        statutoryNote: 'Estimate — for your tax agent',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 7700.0, derivedRent: 0.0, directExpenses: 0.0, rentalIncomeOrLoss: 7700.0,
          units: [
            UnitFinance(
              unitId: 'u1', label: 'Unit A', rentedMonths: 11, contribution: 7700.0,
              months: [
                MonthIncome(month: 3, source: 'unpaid', amount: 0.0, paymentState: 'outstanding'),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [year]),
          financeSummaryProvider.overrideWith((ref, y) async => summary),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Rent payment issues'), findsOneWidget);
    expect(find.textContaining('Unit A — Mar'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Unit A — Mar'));
    await tester.tap(find.textContaining('Unit A — Mar'));
    await tester.pumpAndSettle();
    manageOpened = find.textContaining('is marked outstanding').evaluate().isNotEmpty;
    expect(manageOpened, isTrue);
  });

  testWidgets('finance tab headline uses the Overall glossary', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith((ref, year) async => _fakeSummary(year)),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OVERALL NET PROFIT/LOSS · 2026'), findsOneWidget);
    expect(find.text('OVERALL RENTAL INCOME'), findsOneWidget);
    expect(find.text('OVERALL EXPENSES'), findsOneWidget);
    expect(find.textContaining('Overall Statutory Income'), findsOneWidget);
    expect(find.text('TOTAL NET P/L · 2026'), findsNothing);
    expect(find.text('TOTAL RECEIVED'), findsNothing);
    expect(find.text('TOTAL EXPENSES'), findsNothing);
  });
}
