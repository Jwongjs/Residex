import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart';

FinanceSummary _summaryFor(int year, {double amount = 700.0}) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: amount * 12, derivedRent: 0.0, directExpenses: 0.0,
      netPl: amount * 12, statutoryRentalIncome: amount * 12,
      statutoryNote: 'Estimate — for your tax agent',
    ),
    properties: [
      PropertyFinance(
        propertyId: 'p1', name: 'Ayer 8',
        receivedRent: amount * 12, derivedRent: 0.0, directExpenses: 0.0,
        rentalIncomeOrLoss: amount * 12,
        units: [
          UnitFinance(
            unitId: 'u1', label: 'Unit A', rentedMonths: 12, contribution: amount * 12,
            months: [
              for (var m = 1; m <= 12; m++)
                MonthIncome(month: m, source: 'actual', amount: amount),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('year button switches the displayed month figures',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2025, 2026]),
          financeSummaryProvider.overrideWith((ref, year) async => _summaryFor(year)),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1',
            propertyName: 'Ayer 8',
            unit: UnitFinance(unitId: 'u1', label: 'Unit A', rentedMonths: 12, contribution: 8400.0),
            year: 2026,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unit A — 2026'), findsOneWidget);
    expect(find.text('RM 700.00'), findsWidgets);

    await tester.tap(find.text('2026').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();

    expect(find.text('Unit A — 2025'), findsOneWidget);
  });

  testWidgets('tapping an actual month opens the mark-unpaid sheet and calls the action',
      (tester) async {
    Map<String, dynamic>? captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith((ref, year) async => _summaryFor(year)),
          setPaymentExceptionActionProvider.overrideWithValue(({
            required String propertyId,
            required String month,
            String? unitId,
            String? reason,
          }) async {
            captured = {
              'propertyId': propertyId,
              'month': month,
              'unitId': unitId,
              'reason': reason,
            };
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1',
            propertyName: 'Ayer 8',
            unit: UnitFinance(unitId: 'u1', label: 'Unit A', rentedMonths: 12, contribution: 8400.0),
            year: 2026,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jan'));
    await tester.pumpAndSettle();
    expect(find.text('Mark Jan 2026 as no payment received'), findsOneWidget);

    await tester.tap(find.text('Mark as unpaid'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['propertyId'], 'p1');
    expect(captured!['unitId'], 'u1');
    expect(captured!['month'], '2026-01');
  });

  testWidgets('tapping an unpaid month offers to clear the mark',
      (tester) async {
    var cleared = false;
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 0.0, derivedRent: 0.0, directExpenses: 0.0,
        netPl: 0.0, statutoryRentalIncome: 0.0,
        statutoryNote: 'Estimate — for your tax agent',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 0.0, derivedRent: 0.0, directExpenses: 0.0, rentalIncomeOrLoss: 0.0,
          units: [
            UnitFinance(
              unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 0.0,
              months: [
                MonthIncome(month: 1, source: 'unpaid', amount: 0.0, reason: 'tenant requested deferral'),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith((ref, year) async => summary),
          clearPaymentExceptionActionProvider.overrideWithValue(({
            required String propertyId,
            required String month,
            String? unitId,
          }) async {
            cleared = true;
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1',
            propertyName: 'Ayer 8',
            unit: UnitFinance(unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 0.0),
            year: 2026,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('UNPAID'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is marked as no payment received'), findsOneWidget);
    expect(find.text('tenant requested deferral'), findsOneWidget);

    await tester.tap(find.text('Clear mark'));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });
}
