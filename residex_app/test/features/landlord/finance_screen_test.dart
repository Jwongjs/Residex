import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
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

/// A 2026 summary whose single property is missing [categories]. The nudge
/// renders a count, not category names, so the count is what these tests read.
FinanceSummary _summaryMissing(List<String> categories) {
  final base = _summaryWithProperty(2026, complete: false);
  return FinanceSummary(
    year: base.year,
    totals: base.totals,
    properties: base.properties,
    missingCategories: {'p1': categories},
  );
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
      'the loan figures control survives manualLoanIncomplete going false — the regression this task fixes',
      (tester) async {
    // Previously the button was gated on `block.manualLoanIncomplete`, which
    // flips false the instant figures are booked — vanishing the only route
    // back in exactly when a typo needed correcting. It is now gated on
    // loanInputMethod alone, so it must stay put here.
    final year = DateTime.now().year;
    await _pumpScreenWithProperty(
      tester,
      year,
      _summaryWithProperty(year, complete: true, manualLoanIncomplete: false),
      _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'),
    );

    // manualLoanEntriesProvider isn't overridden here, so it degrades to "no
    // figures" — the row renders as the Add affordance rather than throwing.
    expect(find.text('Add loan figures'), findsOneWidget);
  });

  testWidgets(
      '"Add loan figures" shows when hasMortgage is true and loanInputMethod is manual',
      (tester) async {
    // manualLoanIncomplete no longer drives this control at all.
    final year = DateTime.now().year;
    await _pumpScreenWithProperty(
      tester,
      year,
      _summaryWithProperty(year, complete: true),
      _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'),
    );

    expect(find.text('Add loan figures'), findsOneWidget);
  });

  testWidgets('the nudge no longer offers manual entry, even for a null method',
      (tester) async {
    // The fork moved to the property dialog. Offering "enter figures manually"
    // here re-asked a question the landlord already answered at registration,
    // which is the duplication this workstream exists to remove.
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryMissing(const ['loan']),
      _fakeProperty(hasMortgage: true, loanInputMethod: null),
    );
    expect(find.text('Enter figures manually'), findsNothing);
    // ...but a null-method property is still nudged to upload the document.
    expect(find.text('1 document needed for 2026'), findsOneWidget);
  });

  testWidgets('a manual property drops loans from the missing-docs nudge',
      (tester) async {
    // The panel row owns loan entry in manual mode. A nudge about a loan
    // document the landlord will never upload is simply wrong.
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryMissing(const ['loan']),
      _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'),
    );
    // Loans was the only missing category, so the nudge vanishes entirely
    // rather than counting down to a document that is never coming.
    expect(find.text('Enter figures manually'), findsNothing);
    expect(find.textContaining('needed for 2026'), findsNothing);
  });

  testWidgets('an upload property still nudges about the loan document',
      (tester) async {
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryMissing(const ['loan']),
      _fakeProperty(hasMortgage: true, loanInputMethod: 'upload'),
    );
    expect(find.text('1 document needed for 2026'), findsOneWidget);
    expect(find.text('Enter figures manually'), findsNothing);
  });

  testWidgets('a manual property still nudges for its other missing categories',
      (tester) async {
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryMissing(const ['loan', 'insurance']),
      _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'),
    );
    // Two missing, one filtered out: the count must drop to 1, not stay at 2.
    // Asserting on the count is what pins the filtering — the banner never
    // renders category names, so asserting on those would prove nothing.
    expect(find.text('1 document needed for 2026'), findsOneWidget);
  });

  testWidgets('nudge omits manual entry when no loan document is missing',
      (tester) async {
    final summary = _summaryWithProperty(2026, complete: false);
    await _pumpScreenWithProperty(
      tester, 2026,
      FinanceSummary(
        year: summary.year, totals: summary.totals,
        properties: summary.properties,
        missingCategories: const {'p1': ['insurance']},
      ),
      _fakeProperty(hasMortgage: true, loanInputMethod: null),
    );
    expect(find.text('Enter figures manually'), findsNothing);
  });

  testWidgets('loan button depends only on loanInputMethod, not on manualLoanIncomplete',
      (tester) async {
    // The button is gated on loanInputMethod == 'manual' alone. A null
    // method — even with manualLoanIncomplete true — must not show it.
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryWithProperty(2026, complete: true, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true, loanInputMethod: null),
    );
    expect(find.text('Add loan figures'), findsNothing);
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

  // Property-scope costs are already inside the panel's EXPENSES figure;
  // itemising them again underneath read as a second, separate charge. The
  // lines stay on the entity (the backend still sends them) — only the
  // property panel stops rendering them.
  testWidgets('property-level expenses are not listed on the property panel',
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
    expect(find.text('Property-level expenses'), findsNothing);
    expect(find.text('Quit rent'), findsNothing);
  });

  testWidgets('a manual property with booked figures shows them with Modify',
      (tester) async {
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
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
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'), const []);

    expect(find.text('Add loan figures'), findsOneWidget);
    expect(find.text('Modify'), findsNothing);
  });

  testWidgets('an upload property shows no loan figures row', (tester) async {
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'upload'), const []);

    expect(find.text('Add loan figures'), findsNothing);
    expect(find.text('Modify'), findsNothing);
  });

  testWidgets('figures sum across property-level and per-unit entries',
      (tester) async {
    // Amounts chosen to not collide with the fixture's other displayed
    // totals (3200, 200, 2800, 3000, 3100), which would make textContaining
    // over-match.
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true, loanInputMethod: 'manual'), [
      {'interest_paid': 700.0, 'principal_paid': 1800.0,
       'month': null, 'unit_id': null, 'cadence': 'annual'},
      {'interest_paid': 300.0, 'principal_paid': 700.0,
       'month': null, 'unit_id': 'u1', 'cadence': 'annual'},
    ]);

    expect(find.textContaining('1,000'), findsOneWidget);
    expect(find.textContaining('2,500'), findsOneWidget);
  });
}
