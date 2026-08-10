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
            String? state,
          }) async {
            captured = {
              'propertyId': propertyId,
              'month': month,
              'unitId': unitId,
              'reason': reason,
              'state': state,
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

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['propertyId'], 'p1');
    expect(captured!['unitId'], 'u1');
    expect(captured!['month'], '2026-01');
    expect(captured!['state'], 'outstanding');
  });

  testWidgets('an outstanding month shows OUTSTANDING and offers write-off or clear',
      (tester) async {
    var wroteOff = false;
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
                MonthIncome(month: 1, source: 'unpaid', amount: 0.0,
                    reason: 'tenant requested deferral', paymentState: 'outstanding', billedAmount: 700.0),
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
          setPaymentExceptionActionProvider.overrideWithValue(({
            required String propertyId,
            required String month,
            String? unitId,
            String? reason,
            String? state,
          }) async {
            wroteOff = state == 'written_off';
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1', propertyName: 'Ayer 8',
            unit: UnitFinance(unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 0.0),
            year: 2026,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OUTSTANDING'), findsOneWidget);

    await tester.tap(find.text('OUTSTANDING'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is marked outstanding'), findsOneWidget);
    expect(find.text('Mark as written off'), findsOneWidget);

    await tester.tap(find.text('Mark as written off'));
    await tester.pumpAndSettle();
    expect(wroteOff, isTrue);
  });

  testWidgets('an outstanding month can also be cleared back to received',
      (tester) async {
    Map<String, dynamic>? cleared;
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
                MonthIncome(month: 1, source: 'unpaid', amount: 0.0,
                    paymentState: 'outstanding', billedAmount: 700.0),
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
            cleared = {'propertyId': propertyId, 'month': month, 'unitId': unitId};
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1', propertyName: 'Ayer 8',
            unit: UnitFinance(unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 0.0),
            year: 2026,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OUTSTANDING'));
    await tester.pumpAndSettle();
    expect(find.text('Clear mark'), findsOneWidget);

    await tester.tap(find.text('Clear mark'));
    await tester.pumpAndSettle();

    expect(cleared, isNotNull);
    expect(cleared!['propertyId'], 'p1');
    expect(cleared!['unitId'], 'u1');
    expect(cleared!['month'], '2026-01');
  });

  testWidgets('a written-off month shows WRITTEN OFF and offers a recovery flow',
      (tester) async {
    ({double amount, int receivedYear})? recorded;
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
                MonthIncome(month: 8, source: 'unpaid', amount: 0.0,
                    paymentState: 'written_off', billedAmount: 3000.0),
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
          recordRentRecoveryActionProvider.overrideWithValue(({
            required String propertyId,
            required String originalMonth,
            required double amount,
            required int receivedYear,
            String? unitId,
          }) async {
            recorded = (amount: amount, receivedYear: receivedYear);
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1', propertyName: 'Ayer 8',
            unit: UnitFinance(unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 0.0),
            year: 2026,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WRITTEN OFF'), findsOneWidget);

    await tester.tap(find.text('WRITTEN OFF'));
    await tester.pumpAndSettle();
    expect(find.text('Record a recovery'), findsOneWidget);

    await tester.tap(find.text('Record a recovery'));
    await tester.pumpAndSettle();
    expect(find.text('Amount received from tenant (RM)'), findsOneWidget);

    await tester.tap(find.text('Record recovery'));
    await tester.pumpAndSettle();

    expect(recorded?.amount, 3000.0);
    expect(recorded?.receivedYear, DateTime.now().year);
  });

  group('recovery sheet asks for the figure the engine will book', () {
    // This file mounts the screen inline rather than through a helper
    // (see the year-switching test at the top), so this group brings its own.
    Future<void> pumpWithUnit(WidgetTester tester, UnitFinance unit) async {
      final summary = FinanceSummary(
        year: 2026,
        totals: FinanceTotals(
          receivedRent: 0.0, derivedRent: 0.0, directExpenses: 0.0,
          netPl: 0.0, statutoryRentalIncome: 0.0, statutoryNote: '',
        ),
        properties: [
          PropertyFinance(
            propertyId: 'p1', name: 'Ayer 8',
            receivedRent: 0.0, derivedRent: 0.0, directExpenses: 0.0,
            rentalIncomeOrLoss: 0.0,
            units: [unit],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeYearsProvider.overrideWith((ref) async => [2026]),
            financeSummaryProvider.overrideWith((ref, y) async => summary),
          ],
          child: MaterialApp(
            home: UnitFinanceDetailScreen(
              propertyId: 'p1',
              propertyName: 'Ayer 8',
              unit: unit,
              year: 2026,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('partial share asks for the landlord share', (tester) async {
      await pumpWithUnit(
        tester,
        UnitFinance(
          unitId: 'u1',
          label: 'B-08-11',
          rentedMonths: 1,
          contribution: 0,
          grossIncome: 0,
          fullGrossIncome: 0,
          months: [
            MonthIncome(
              month: 9,
              source: 'unpaid',
              amount: 0,
              paymentState: 'written_off',
              billedAmount: 1600.0,
              fullBilledAmount: 3200.0,
            ),
          ],
        ),
      );

      await tester.tap(find.text('WRITTEN OFF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a recovery'));
      await tester.pumpAndSettle();

      expect(find.text('Your share of the amount received (RM)'), findsOneWidget);
      expect(
        find.text('Enter your 50% share, not the full RM 3,200.00 the tenant paid.'),
        findsOneWidget,
      );
      expect(find.text('1600.00'), findsOneWidget);
    });

    testWidgets('full ownership asks for the whole invoiced amount',
        (tester) async {
      await pumpWithUnit(
        tester,
        UnitFinance(
          unitId: 'u1',
          label: 'B-08-11',
          rentedMonths: 1,
          contribution: 0,
          grossIncome: 0,
          months: [
            MonthIncome(
              month: 9,
              source: 'unpaid',
              amount: 0,
              paymentState: 'written_off',
              billedAmount: 3200.0,
            ),
          ],
        ),
      );

      await tester.tap(find.text('WRITTEN OFF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a recovery'));
      await tester.pumpAndSettle();

      expect(find.text('Amount received from tenant (RM)'), findsOneWidget);
      expect(find.textContaining('Enter your'), findsNothing);
      expect(find.text('3200.00'), findsOneWidget);
    });

    testWidgets(
        'a co-owned unit falls back to the unit-level share when the month '
        'has no invoice on file', (tester) async {
      // The engine only emits billed_amount/full_billed_amount when the
      // month has a billed figure at all (`if row.get("billed_amount")`), so
      // a written-off month with no invoice and no lease-derived rent
      // carries neither field even at a share below 1.0 — the exact case
      // that let a co-owner see the full-ownership label and type the whole
      // property's rent as their own income. The unit-level grossIncome /
      // fullGrossIncome pair is present regardless of this month's invoice
      // status, so it must drive the same share-aware label.
      await pumpWithUnit(
        tester,
        UnitFinance(
          unitId: 'u1',
          label: 'B-08-11',
          rentedMonths: 1,
          contribution: 0,
          grossIncome: 1600.0,
          fullGrossIncome: 3200.0,
          months: [
            MonthIncome(
              month: 9,
              source: 'unpaid',
              amount: 0,
              paymentState: 'written_off',
              // Deliberately no billedAmount/fullBilledAmount.
            ),
          ],
        ),
      );

      await tester.tap(find.text('WRITTEN OFF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a recovery'));
      await tester.pumpAndSettle();

      expect(find.text('Your share of the amount received (RM)'), findsOneWidget);
      expect(
        find.text(
          'Enter your 50% share of what the tenant paid — this unit is '
          'co-owned and this month has no separate invoice on file.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('full RM'), findsNothing);
    });
  });
}
