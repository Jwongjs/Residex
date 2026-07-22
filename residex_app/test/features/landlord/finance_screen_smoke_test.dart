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

    expect(find.text('Statutory rental income'), findsOneWidget);
    expect(find.text('RM 24,483.13'), findsWidgets); // statutory + P/L rows
    expect(find.text('Ayer 8'), findsOneWidget);
    expect(find.textContaining('Estimate'), findsWidgets);
    expect(find.text('Unit A'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget); // ownership badge
    expect(find.textContaining('Insurance policy'), findsWidgets); // missing category + banner
    expect(find.textContaining('missing your Insurance policy'), findsOneWidget); // banner
    expect(find.textContaining('1 missing'), findsOneWidget); // coverage chip for 2025
  });

  testWidgets('incomplete year shows "so far" and an unavailable gap offers Undo', (tester) async {
    final year = DateTime.now().year;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [year]),
          financeSummaryProvider.overrideWith((ref, y) async => _incompleteSummaryWithUnavailableGap(y)),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('so far'), findsOneWidget);
    expect(find.textContaining('acknowledged unavailable'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Mark unavailable'), findsWidgets);
  });
}
