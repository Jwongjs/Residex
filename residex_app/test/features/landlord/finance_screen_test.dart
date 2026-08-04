import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/3-Finance/finance_screen.dart';

FinanceSummary _summaryWithProperty(int year,
    {required bool complete, bool manualLoanIncomplete = false}) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: 3200.0,
      derivedRent: 0.0,
      directExpenses: 200.0,
      netPl: 3000.0,
      statutoryRentalIncome: 3100.0,
      statutoryNote: '',
    ),
    properties: [
      PropertyFinance(
        propertyId: 'p1',
        name: 'Ayer 8',
        complete: complete,
        receivedRent: 3200.0,
        derivedRent: 0.0,
        directExpenses: 200.0,
        rentalIncomeOrLoss: 3000.0,
        netPl: 2800.0,
        statutoryContribution: 3100.0,
        manualLoanIncomplete: manualLoanIncomplete,
      ),
    ],
  );
}

Future<void> _pumpScreen(WidgetTester tester, int year, FinanceSummary summary) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeYearsProvider.overrideWith((ref) async => [year]),
        financeSummaryProvider.overrideWith((ref, y) async => summary),
      ],
      child: const MaterialApp(
        home: FinanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpScreenWithProperty(
  WidgetTester tester,
  int year,
  FinanceSummary summary,
  Property property,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeYearsProvider.overrideWith((ref) async => [year]),
        financeSummaryProvider.overrideWith((ref, y) async => summary),
        propertyByIdProvider.overrideWith((ref, id) async => property),
      ],
      child: const MaterialApp(
        home: FinanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Property _fakeProperty({required bool hasMortgage, required String? loanInputMethod}) {
  return Property(
    id: 'p1',
    landlordId: 'landlord1',
    name: 'Ayer 8',
    address: const PropertyAddress(
      street: '8 Ayer St',
      city: 'Kuala Lumpur',
      state: 'WP',
      zipCode: '50000',
      country: 'Malaysia',
    ),
    type: PropertyType.apartment,
    purchasePrice: 500000,
    currentValue: 550000,
    hasMortgage: hasMortgage,
    loanInputMethod: loanInputMethod,
    loanInputCadence: loanInputMethod == 'manual' ? 'annual' : null,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  testWidgets('an incomplete property shows the "Current" statutory label',
      (tester) async {
    final year = DateTime.now().year;
    await _pumpScreen(tester, year, _summaryWithProperty(year, complete: false));

    expect(find.textContaining('Current Overall Statutory Income'), findsOneWidget);
  });

  testWidgets('a fully complete year shows the settled statutory label',
      (tester) async {
    final year = DateTime.now().year;
    await _pumpScreen(tester, year, _summaryWithProperty(year, complete: true));

    expect(find.textContaining('Current Overall Statutory Income'), findsNothing);
    // Exact match: the portfolio panel's label. The per-property block's
    // "Statutory Rental Income/Loss" row is a distinct (longer) string.
    expect(find.text('Overall Statutory Income'), findsOneWidget);
  });

  testWidgets('a property shows the Net P/L headline sourced from block.netPl',
      (tester) async {
    final year = DateTime.now().year;
    await _pumpScreen(tester, year, _summaryWithProperty(year, complete: true));

    // NET P/L is now the big headline figure; statutory is a subtle line.
    expect(find.text('Net Profit/Loss · $year'), findsOneWidget);
    expect(find.text('RM 2,800.00'), findsOneWidget); // block.netPl
    expect(find.text('Statutory Income'), findsOneWidget);
    // RM 3,100.00 shows twice: the portfolio panel's total and this single
    // property's statutory line (they coincide with one property).
    expect(find.text('RM 3,100.00'), findsNWidgets(2));
  });

  testWidgets(
      '"Add loan figures" is hidden when loanInputMethod is manual but hasMortgage is not true',
      (tester) async {
    final year = DateTime.now().year;
    await _pumpScreenWithProperty(
      tester,
      year,
      _summaryWithProperty(year, complete: true),
      _fakeProperty(hasMortgage: false, loanInputMethod: 'manual'),
    );

    expect(find.text('Add loan figures'), findsNothing);
  });

  testWidgets(
      '"Add loan figures" is hidden when manualLoanIncomplete is false even with mortgage=Yes + method=manual',
      (tester) async {
    final year = DateTime.now().year;
    await _pumpScreenWithProperty(
      tester,
      year,
      _summaryWithProperty(year, complete: true, manualLoanIncomplete: false),
      _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'),
    );

    expect(find.text('Add loan figures'), findsNothing);
  });

  testWidgets(
      '"Add loan figures" shows when hasMortgage is true, loanInputMethod is manual, and manualLoanIncomplete is true',
      (tester) async {
    final year = DateTime.now().year;
    await _pumpScreenWithProperty(
      tester,
      year,
      _summaryWithProperty(year, complete: true, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'),
    );

    expect(find.text('Add loan figures'), findsOneWidget);
  });

  testWidgets('property panel uses the bare glossary and shows cash out', (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 3200.0, derivedRent: 0.0, directExpenses: 200.0,
        netPl: 2800.0, landlordExpenses: 400.0,
        statutoryRentalIncome: 3000.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 3200.0, derivedRent: 0.0,
          directExpenses: 200.0, landlordExpenses: 400.0,
          rentalIncomeOrLoss: 3000.0, netPl: 2800.0,
          statutoryContribution: 3000.0,
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('RENTAL INCOME'), findsOneWidget);
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.text('Net Profit/Loss · 2026'), findsOneWidget);
    expect(find.text('Statutory Income'), findsOneWidget);
    expect(find.text('RECEIVED'), findsNothing);
    expect(find.text('Net P/L · 2026'), findsNothing);
    // EXPENSES renders landlordExpenses (400), not directExpenses (200).
    // RM 400.00 appears twice: portfolio panel's overall + property panel's property-level.
    expect(find.text('RM 400.00'), findsNWidgets(2));
  });

  testWidgets('coverage bubble is gone but the document nudge remains',
      (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 3200.0, derivedRent: 0.0, directExpenses: 200.0,
        netPl: 2800.0, landlordExpenses: 400.0,
        statutoryRentalIncome: 3000.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 3200.0, derivedRent: 0.0,
          directExpenses: 200.0, landlordExpenses: 400.0,
          rentalIncomeOrLoss: 3000.0, netPl: 2800.0,
          statutoryContribution: 3000.0,
          coverage: [
            YearCoverage(year: 2025, missing: ['tax', 'insurance']),
            YearCoverage(year: 2026, missing: const []),
          ],
        ),
      ],
      missingCategories: {'p1': ['tax', 'insurance']},
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('2025 · 2 missing'), findsNothing);
    expect(find.text('2025'), findsNothing);
    // The bottom panel still asks for the same documents.
    expect(find.textContaining('documents needed for 2026'), findsOneWidget);
  });

  testWidgets('co-owned property states the share basis plainly', (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 1600.0, derivedRent: 0.0, directExpenses: 100.0,
        netPl: 1400.0, landlordExpenses: 200.0,
        statutoryRentalIncome: 1500.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8', ownershipShare: 0.5,
          receivedRent: 1600.0, derivedRent: 0.0,
          directExpenses: 100.0, landlordExpenses: 200.0,
          rentalIncomeOrLoss: 1500.0, netPl: 1400.0,
          statutoryContribution: 1500.0,
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('Shown at your 50% share'), findsOneWidget);
    expect(find.textContaining("property's full figures"), findsNothing);
  });

  testWidgets('property-level expenses are listed on the property panel',
      (tester) async {
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 3200.0, derivedRent: 0.0, directExpenses: 200.0,
        netPl: 2800.0, landlordExpenses: 400.0,
        statutoryRentalIncome: 3000.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 3200.0, derivedRent: 0.0,
          directExpenses: 200.0, landlordExpenses: 400.0,
          rentalIncomeOrLoss: 3000.0, netPl: 2800.0,
          statutoryContribution: 3000.0,
          propertyExpenseLines: [
            ExpenseLine(
              docId: 'd1', category: 'tax', description: 'Quit rent',
              amount: 120.0, date: '2026',
            ),
          ],
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);
    expect(find.text('Property-level expenses'), findsOneWidget);
    expect(find.text('Quit rent'), findsOneWidget);
  });
}
