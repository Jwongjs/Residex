import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/datasources/documind_remote_datasource.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/repositories/property_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/3-Finance/finance_screen.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart';

/// A minimal fake datasource that keeps manual loan entries in memory,
/// letting a test drive the real `recordManualLoanEntryActionProvider` /
/// `manualLoanEntriesProvider` wiring (including their `ref.invalidate`
/// calls) end-to-end, without touching Firebase or the network. Every other
/// method is inherited unused — this fake exists solely to prove a save
/// actually refreshes what the loan-figures row displays.
class _FakeLoanDataSource extends DocuMindRemoteDataSource {
  _FakeLoanDataSource(this._entries);

  List<Map<String, dynamic>> _entries;

  @override
  Future<List<Map<String, dynamic>>> listManualLoanEntries({
    required String propertyId,
    int? year,
  }) async => _entries;

  @override
  Future<void> recordManualLoanEntry({
    required String propertyId,
    required int year,
    required String cadence,
    required double interestPaid,
    required double principalPaid,
    int? month,
    String? unitId,
  }) async {
    _entries = [
      {
        'interest_paid': interestPaid,
        'principal_paid': principalPaid,
        'month': month,
        'unit_id': unitId,
        'cadence': cadence,
      },
    ];
  }
}

/// Records what the settlement sheet writes, so a test can assert both halves
/// of that save: the property reaching the repository *and* the finance
/// summary being rebuilt afterwards.
class _FakePropertyRepository implements PropertyRepository {
  _FakePropertyRepository(this.property);

  final Property property;
  Property? lastUpdated;

  @override
  Future<void> updateProperty(Property property) async {
    lastUpdated = property;
  }

  @override
  Future<String> createProperty(Property property) async => 'p1';
  @override
  Future<void> deleteProperty(String propertyId) async {}
  @override
  Future<Property?> getPropertyById(String propertyId) async => property;
  @override
  Future<List<Property>> getPropertiesByLandlord(String landlordId) async =>
      [property];
  @override
  Future<List<Property>> searchProperties(String landlordId, String query) async => [];
  @override
  Stream<List<Property>> streamPropertiesByLandlord(String landlordId) =>
      const Stream.empty();
}

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
        // Overridden even though this helper is for tests that don't care
        // about loan entries: the loan figures row is now gated on
        // hasMortgage alone, so any mortgaged property renders it and reads
        // this provider. Left un-overridden it reaches the real data source,
        // and only passes because the emulator host is unroutable from a
        // desktop test runner — not because it resolves deterministically.
        manualLoanEntriesProvider.overrideWith((ref, args) async => const []),
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

/// Like [_pumpScreenWithLoanEntries], but wires `manualLoanEntriesProvider`
/// and `recordManualLoanEntryActionProvider` to their *real* implementations
/// backed by [dataSource] instead of overriding either provider directly —
/// so a save routed through the sheet exercises the actual
/// `ref.invalidate(manualLoanEntriesProvider)` call in
/// documind_provider.dart, not a test double standing in for it.
Future<void> _pumpScreenWithFakeDataSource(
  WidgetTester tester,
  int year,
  FinanceSummary summary,
  Property property,
  DocuMindRemoteDataSource dataSource,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeYearsProvider.overrideWith((ref) async => [year]),
        financeSummaryProvider.overrideWith((ref, y) async => summary),
        propertyByIdProvider.overrideWith((ref, id) async => property),
        documindRemoteDataSourceProvider.overrideWithValue(dataSource),
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

/// Task 2: `loanInputMethod` no longer exists — both loan routes (upload to
/// the Loans & Financing folder, or type at this panel) are permanently
/// available, so `loanInputCadence` defaults to 'annual' unconditionally
/// rather than only when the (now-removed) method was 'manual'.
Property _fakeProperty({
  // Nullable, and still required: null is the state every property created
  // before the mortgage question existed is in, so it has to be expressible.
  required bool? hasMortgage,
  String? loanInputCadence,
  String? mortgageSettledOn,
}) {
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
    loanInputCadence: loanInputCadence ?? 'annual',
    mortgageSettledOn: mortgageSettledOn,
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
      '"Add loan figures" is hidden when hasMortgage is not true',
      (tester) async {
    final year = DateTime.now().year;
    await _pumpScreenWithProperty(
      tester,
      year,
      _summaryWithProperty(year, complete: true),
      _fakeProperty(hasMortgage: false),
    );

    expect(find.text('Add loan figures'), findsNothing);
  });

  testWidgets(
      '"Add loan figures" is hidden when the mortgage question is unanswered',
      (tester) async {
    // `hasMortgage == true` and not `!= false`: an unanswered mortgage is not
    // a yes. Offering loan entry to a landlord who never said they have a
    // mortgage would invent an expectation they never agreed to.
    final year = DateTime.now().year;
    await _pumpScreenWithProperty(
      tester,
      year,
      _summaryWithProperty(year, complete: true),
      _fakeProperty(hasMortgage: null),
    );

    expect(find.text('Add loan figures'), findsNothing);
  });

  testWidgets(
      'the loan figures control survives manualLoanIncomplete going false — the regression this task fixes',
      (tester) async {
    // Previously the button was gated on `block.manualLoanIncomplete`, which
    // flips false the instant figures are booked — vanishing the only route
    // back in exactly when a typo needed correcting. It is now gated on
    // hasMortgage alone, so it must stay put here.
    //
    // Uses _pumpScreenWithLoanEntries (not _pumpScreenWithProperty) so
    // manualLoanEntriesProvider resolves deterministically to "no entries
    // yet": the row's loading branch now returns nothing while the provider
    // is unresolved, so an un-overridden provider would hang forever inside
    // the fake-async test zone rather than degrading to the Add affordance.
    final year = DateTime.now().year;
    await _pumpScreenWithLoanEntries(
      tester,
      year,
      _summaryWithProperty(year, complete: true, manualLoanIncomplete: false),
      _fakeProperty(hasMortgage: true),
      const [],
    );

    expect(find.text('Add loan figures'), findsOneWidget);
  });

  testWidgets(
      '"Add loan figures" shows for a mortgaged property',
      (tester) async {
    // Brackets the previous test: together the pair pins that the control
    // shows regardless of manualLoanIncomplete's value, rather than the two
    // tests duplicating each other at the same (false) value.
    final year = DateTime.now().year;
    await _pumpScreenWithLoanEntries(
      tester,
      year,
      _summaryWithProperty(year, complete: true, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true),
      const [],
    );

    expect(find.text('Add loan figures'), findsOneWidget);
  });

  testWidgets('the nudge still counts a missing loan document',
      (tester) async {
    // 'loan' nudges like any other missing category now — there is no
    // per-property routing preference left to gate it on.
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryMissing(const ['loan']),
      _fakeProperty(hasMortgage: true),
    );
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
      _fakeProperty(hasMortgage: true),
    );
    expect(find.text('Enter figures manually'), findsNothing);
  });

  testWidgets(
      '"Add loan figures" shows for a mortgaged property regardless of manualLoanIncomplete — '
      'the dead end this rework closes',
      (tester) async {
    // Before this rework, a mortgaged property that never answered "upload
    // or type it myself" (loanInputMethod null) had no route to manual entry
    // at all: the Loans folder stayed visible (so it wasn't "upload"), but
    // the panel row was gated on loanInputMethod == 'manual', which was also
    // never true. Every existing property was in exactly this state. The row
    // is now gated on hasMortgage alone, so it shows unconditionally here.
    await _pumpScreenWithProperty(
      tester, 2026,
      _summaryWithProperty(2026, complete: true, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true),
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
    expect(find.text('50% share'), findsOneWidget);
    expect(
      find.textContaining('Loan interest and principal are shown in full'),
      findsNothing,
    );
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

  testWidgets('a property with booked figures shows them with Modify',
      (tester) async {
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true), [
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

  testWidgets('a mortgaged property with no figures yet offers Add',
      (tester) async {
    // Both loan routes (upload, or type here) are always available now, so a
    // mortgaged property with nothing booked always offers Add — there is no
    // property-level preference left that could hide this row instead.
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true), const []);

    expect(find.text('Add loan figures'), findsOneWidget);
    expect(find.text('Modify'), findsNothing);
  });

  testWidgets('figures sum across property-level and per-unit entries',
      (tester) async {
    // Amounts chosen to not collide with the fixture's other displayed
    // totals (3200, 200, 2800, 3000, 3100), which would make textContaining
    // over-match.
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true), [
      {'interest_paid': 700.0, 'principal_paid': 1800.0,
       'month': null, 'unit_id': null, 'cadence': 'annual'},
      {'interest_paid': 300.0, 'principal_paid': 700.0,
       'month': null, 'unit_id': 'u1', 'cadence': 'annual'},
    ]);

    expect(find.textContaining('1,000'), findsOneWidget);
    expect(find.textContaining('2,500'), findsOneWidget);
  });

  testWidgets(
      'shows a completeness sub-line naming what is missing when manualLoanIncomplete is true',
      (tester) async {
    // manualLoanIncomplete goes true the moment a booked entry stops
    // covering the cadence — here, only January is booked out of twelve
    // monthly instalments. The figures block above this line would
    // otherwise look clean and complete on its own.
    //
    // Year is a past one (not the current year) so the denominator is the
    // full 12 rather than elapsed-so-far — see the dedicated
    // "counts elapsed months, not 12" test for the current-year case.
    await _pumpScreenWithLoanEntries(
      tester,
      2020,
      _summaryWithProperty(2020, complete: true, manualLoanIncomplete: true),
      _fakeProperty(
        hasMortgage: true,
        loanInputCadence: 'monthly',
      ),
      [
        {
          'interest_paid': 500.0, 'principal_paid': 600.0,
          'month': 1, 'unit_id': null, 'cadence': 'monthly',
        },
      ],
    );

    expect(find.text('1 of 12 months recorded for 2020'), findsOneWidget);
  });

  testWidgets(
      'shows no completeness sub-line when manualLoanIncomplete is false',
      (tester) async {
    await _pumpScreenWithLoanEntries(
      tester,
      2026,
      _summaryWithProperty(2026, complete: true, manualLoanIncomplete: false),
      _fakeProperty(
        hasMortgage: true,
        loanInputCadence: 'monthly',
      ),
      [
        {
          'interest_paid': 500.0, 'principal_paid': 600.0,
          'month': 1, 'unit_id': null, 'cadence': 'monthly',
        },
      ],
    );

    expect(find.textContaining('recorded for 2026'), findsNothing);
  });

  testWidgets(
      'a booked entry of 0/0 still renders the figures block with Modify, not Add',
      (tester) async {
    // interest>0||principal>0 would have read this as "nothing booked" —
    // wrong, since the entry sheet has no min-value guard and a 0/0 save is
    // reachable. Presence of a booked entry is what should decide this, not
    // whether its amounts happen to be nonzero.
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true), [
      {'interest_paid': 0.0, 'principal_paid': 0.0,
       'month': null, 'unit_id': null, 'cadence': 'annual'},
    ]);

    expect(find.text('Loan figures · 2026'), findsOneWidget);
    expect(find.text('Modify'), findsOneWidget);
    expect(find.text('Add loan figures'), findsNothing);
  });

  testWidgets('only the Modify control opens the loan entry sheet, not the row itself',
      (tester) async {
    // The spec is explicit that only Modify opens the sheet: an invisible
    // full-width target beside real figures invites accidental opens while
    // scrolling.
    await _pumpScreenWithLoanEntries(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true), [
      {'interest_paid': 8200.0, 'principal_paid': 14000.0,
       'month': null, 'unit_id': null, 'cadence': 'annual'},
    ]);

    await tester.tap(find.text('Loan figures · 2026'));
    await tester.pumpAndSettle();
    expect(find.byType(ManualLoanEntrySheet), findsNothing);

    await tester.tap(find.text('Modify'));
    await tester.pumpAndSettle();
    expect(find.byType(ManualLoanEntrySheet), findsOneWidget);
  });

  testWidgets(
      'the row shows a disabled Add affordance while entries are still loading, not a blank gap',
      (tester) async {
    // listManualLoanEntries has no client-side timeout and this provider
    // isn't autoDispose, so a stalled request must not leave the landlord's
    // only route to their loan figures blank for the rest of the session —
    // and it must not be tappable against not-yet-known state either.
    final neverResolves = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith(
              (ref, y) async => _summaryWithProperty(2026, complete: true)),
          propertyByIdProvider.overrideWith((ref, id) async =>
              _fakeProperty(hasMortgage: true)),
          manualLoanEntriesProvider.overrideWith((ref, args) => neverResolves.future),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    // Can't pumpAndSettle — the entries future deliberately never resolves.
    // A couple of explicit pumps let the other (immediately-resolving)
    // providers settle and the row build once against the still-pending one.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Add loan figures'), findsOneWidget);

    final button = tester.widget<TextButton>(find.ancestor(
      of: find.text('Add loan figures'),
      matching: find.byType(TextButton),
    ));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Add loan figures'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(ManualLoanEntrySheet), findsNothing);
  });

  testWidgets(
      'the row shows a disabled Add affordance when entries fail to load, not a tappable dead end',
      (tester) async {
    // A load that never succeeds even once (Riverpod's automatic retries
    // exhaust in roughly a minute) leaves manualLoanEntriesProvider in
    // AsyncError with no previous value. The sheet this row opens gates its
    // own Save on that same provider having resolved, so an enabled "Add
    // loan figures" here would walk the landlord into a form they cannot
    // submit — a tappable dead end. Treated the same as still-loading:
    // visible, disabled, not silently gone.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith(
              (ref, y) async => _summaryWithProperty(2026, complete: true)),
          propertyByIdProvider.overrideWith((ref, id) async =>
              _fakeProperty(hasMortgage: true)),
          manualLoanEntriesProvider.overrideWith(
              (ref, args) async => throw Exception('network down')),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add loan figures'), findsOneWidget);

    final button = tester.widget<TextButton>(find.ancestor(
      of: find.text('Add loan figures'),
      matching: find.byType(TextButton),
    ));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Add loan figures'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(ManualLoanEntrySheet), findsNothing);
  });

  testWidgets(
      'the Add affordance stays enabled after a refresh fails over an already-resolved empty list',
      (tester) async {
    // isUnusable is `isInitialLoading || (hasError && !hasValue)`. A first
    // load that resolves to an empty list (no entries booked yet, but a
    // real value) then a failed refresh must land in the second disjunct as
    // false: hasValue survives the failed refresh (Riverpod carries the
    // last resolved value forward), so Add must stay tappable — matching
    // the sheet's own Save gating on the same signal.
    var callCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith(
              (ref, y) async => _summaryWithProperty(2026, complete: true)),
          propertyByIdProvider.overrideWith((ref, id) async =>
              _fakeProperty(hasMortgage: true)),
          manualLoanEntriesProvider.overrideWith((ref, args) async {
            callCount++;
            if (callCount == 1) return <Map<String, dynamic>>[];
            throw Exception('network down');
          }),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add loan figures'), findsOneWidget);
    var button = tester.widget<TextButton>(find.ancestor(
      of: find.text('Add loan figures'),
      matching: find.byType(TextButton),
    ));
    expect(button.onPressed, isNotNull);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(FinanceScreen)));
    container.invalidate(
        manualLoanEntriesProvider((propertyId: 'p1', year: 2026)));
    await tester.pumpAndSettle();

    expect(find.text('Add loan figures'), findsOneWidget);
    button = tester.widget<TextButton>(find.ancestor(
      of: find.text('Add loan figures'),
      matching: find.byType(TextButton),
    ));
    expect(button.onPressed, isNotNull,
        reason: 'a refresh failure over a known (even empty) value must '
            'not disable Add');
  });

  testWidgets('saving through Modify updates the amounts the row displays',
      (tester) async {
    // Exercises the real recordManualLoanEntryActionProvider ->
    // manualLoanEntriesProvider invalidation wiring end-to-end (the fix for
    // the pre-existing bug where a save left the row showing stale figures
    // for the rest of the session), rather than stubbing either provider out.
    final dataSource = _FakeLoanDataSource([
      {'interest_paid': 8200.0, 'principal_paid': 14000.0,
       'month': null, 'unit_id': null, 'cadence': 'annual'},
    ]);
    await _pumpScreenWithFakeDataSource(tester, 2026, _summaryWithProperty(2026, complete: true),
        _fakeProperty(hasMortgage: true), dataSource);

    expect(find.textContaining('8,200'), findsOneWidget);

    await tester.tap(find.text('Modify'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('manual-loan-interest')), '9500');
    await tester.enterText(find.byKey(const Key('manual-loan-principal')), '15200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualLoanEntrySheet), findsNothing);
    expect(find.textContaining('9,500'), findsOneWidget);
    expect(find.textContaining('15,200'), findsOneWidget);
    expect(find.textContaining('8,200'), findsNothing);
    expect(find.textContaining('14,000'), findsNothing);
  });

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
    // A *past* settlement year, because that is the only kind the picker can
    // produce (its year list runs down from the current year). The plan wrote
    // this against 2027, which was then in the future and made the elapsed
    // bound 0 — a state no landlord can reach, and one that would push the
    // implementation into overriding the elapsed bound rather than capping it.
    final year = DateTime.now().year - 1;
    await _pumpScreenWithLoanEntries(
      tester, year,
      _summaryWithProperty(year, complete: false, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true, loanInputCadence: 'monthly',
          mortgageSettledOn: '$year-03'),
      [{'interest_paid': 100.0, 'principal_paid': 0.0, 'month': 1, 'unit_id': null}],
    );

    expect(find.textContaining('1 of 3 months recorded'), findsOneWidget);
  });

  testWidgets('the denominator never exceeds the elapsed months', (tester) async {
    // The settlement picker offers all 12 months of the current year, so a
    // settled month still in the future is reachable. The backend intersects
    // both bounds (_months_in_scope, then _loan_expected_for), so the line
    // must show the elapsed count, not the later settled month.
    final now = DateTime.now();
    if (now.month == 12) return; // no future month to pick this month
    await _pumpScreenWithLoanEntries(
      tester, now.year,
      _summaryWithProperty(now.year, complete: false, manualLoanIncomplete: true),
      _fakeProperty(hasMortgage: true, loanInputCadence: 'monthly',
          mortgageSettledOn: '${now.year}-12'),
      [{'interest_paid': 100.0, 'principal_paid': 0.0, 'month': 1, 'unit_id': null}],
    );

    expect(find.textContaining('1 of ${now.month} months recorded'), findsOneWidget);
    expect(find.textContaining('of 12 months'), findsNothing);
  });

  /// Drives the settlement sheet for real — tapping through both steps and
  /// saving via `propertyControllerProvider` — with a `financeSummaryProvider`
  /// that answers differently on its second build. The nudge count is
  /// therefore a direct read of whether the summary was invalidated: it can
  /// only change if the provider rebuilt.
  ///
  /// The settlement date is an engine input (it decides whether `loan` is
  /// still expected), but `updateProperty` refreshes only the property
  /// providers. That left the loan block — which reads the property object —
  /// updating instantly while the nudge above it kept counting the loan
  /// document as outstanding, so the screen stated two contradictory things
  /// until a pull-to-refresh.
  Future<_FakePropertyRepository> pumpForSettlement(
    WidgetTester tester, {
    required String? settledOn,
    required List<String> before,
    required List<String> after,
  }) async {
    final property =
        _fakeProperty(hasMortgage: true, mortgageSettledOn: settledOn);
    final repo = _FakePropertyRepository(property);
    var builds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith((ref, y) async {
            builds++;
            return _summaryMissing(builds == 1 ? before : after);
          }),
          propertyByIdProvider.overrideWith((ref, id) async => property),
          manualLoanEntriesProvider.overrideWith((ref, args) async => const []),
          propertyRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('marking the mortgage settled refreshes the finance summary',
      (tester) async {
    // The loan-figures panel box adds height to the property card, pushing
    // this control past the default 600px test surface with nothing left to
    // scroll — grow the surface instead of fighting scroll physics.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = await pumpForSettlement(
      tester,
      settledOn: null,
      before: ['tax', 'insurance', 'loan'],
      after: ['tax', 'insurance'],
    );
    expect(find.textContaining('3 documents needed for 2026'), findsOneWidget);

    await tester.tap(find.text('Mortgage paid off?'));
    await tester.pumpAndSettle();
    // Scoped to the sheet's ListTile: the year selector behind it also
    // renders a bare "2026".
    await tester.tap(find.widgetWithText(ListTile, '2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'June'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated!.mortgageSettledOn, '2026-06');
    expect(find.textContaining('2 documents needed for 2026'), findsOneWidget,
        reason: 'the nudge must not keep counting a loan document the engine '
            'has already stopped expecting');
  });

  testWidgets('clearing the settlement refreshes the finance summary',
      (tester) async {
    // See the surface-size note above.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The same gap in the other direction: the engine starts expecting the
    // loan document again, so a stale nudge under-counts instead.
    final repo = await pumpForSettlement(
      tester,
      settledOn: '2026-06',
      before: ['tax', 'insurance'],
      after: ['tax', 'insurance', 'loan'],
    );
    expect(find.textContaining('2 documents needed for 2026'), findsOneWidget);

    await tester.tap(find.text('Mortgage settled · June 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Still paying it off'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated!.mortgageSettledOn, isNull);
    expect(find.textContaining('3 documents needed for 2026'), findsOneWidget);
  });

  testWidgets(
      'the year-level rent issues entry point also asks for the landlord '
      'share', (tester) async {
    // Task 8's recovery-sheet tests only ever mounted UnitFinanceDetailScreen,
    // so a regression that dropped the grossIncome/fullGrossIncome (or
    // billedAmount/fullBilledAmount) threading at this call site — the
    // property panel's "Rent payment issues" list, a second and separate
    // entry point into the same sheet — would have shipped with the full
    // suite green. This test drives the sheet from here instead.
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 1600.0, derivedRent: 0.0, directExpenses: 0.0,
        netPl: 1600.0, statutoryRentalIncome: 1600.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 1600.0, derivedRent: 0.0, directExpenses: 0.0,
          rentalIncomeOrLoss: 1600.0,
          units: [
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
                  billedAmount: 1600.0,
                  fullBilledAmount: 3200.0,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);

    expect(find.text('Rent payment issues · 2026'), findsOneWidget);

    await tester.ensureVisible(find.text('B-08-11 · Sep 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B-08-11 · Sep 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Record a recovery'), findsOneWidget);

    await tester.tap(find.text('Record a recovery'));
    await tester.pumpAndSettle();

    expect(find.text('Your share of the amount received (RM)'), findsOneWidget);
    expect(
      find.text(
        'Enter your 50% share, not the full RM 3,200.00 the tenant paid.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'the year-level rent issues entry point falls back to the unit-level '
      'share when the month has no invoice', (tester) async {
    // Companion to the test above: that one's month carries its own
    // billed/full-billed pair, which alone is enough to drive the
    // share-aware label — so it does not, by itself, prove this call site
    // also threads unit.grossIncome/unit.fullGrossIncome (the Medium fix's
    // fallback signal). This fixture omits the month's billed pair entirely,
    // so only that unit-level threading can produce the share-aware label.
    final summary = FinanceSummary(
      year: 2026,
      totals: FinanceTotals(
        receivedRent: 1600.0, derivedRent: 0.0, directExpenses: 0.0,
        netPl: 1600.0, statutoryRentalIncome: 1600.0, statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1', name: 'Ayer 8',
          receivedRent: 1600.0, derivedRent: 0.0, directExpenses: 0.0,
          rentalIncomeOrLoss: 1600.0,
          units: [
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
          ],
        ),
      ],
    );
    await _pumpScreen(tester, 2026, summary);

    await tester.ensureVisible(find.text('B-08-11 · Sep 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B-08-11 · Sep 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record a recovery'));
    await tester.pumpAndSettle();

    expect(find.text('Your share of the amount received (RM)'), findsOneWidget);
    expect(
      find.text(
        'Enter your 50% share of what the tenant paid. This unit is '
        'co-owned and this month has no separate invoice on file.',
      ),
      findsOneWidget,
    );
  });

  // Guards finance_summary.dart:167. The wire path always passes
  // ownershipShare explicitly (finance_summary_model.dart defaults it to 1.0
  // itself before construction), so nothing on that path exercises the
  // constructor's own default — only fixtures built directly in code, like
  // the ones below, would silently render a "0% share" badge if this default
  // were ever changed. A previous review changed it to 0.0 and the entire
  // 328-test suite stayed green.
  test('UnitFinance built without ownershipShare defaults to full ownership',
      () {
    final unit = UnitFinance(
      unitId: 'u1',
      label: 'A-1',
      rentedMonths: 12,
      contribution: 6000.0,
    );
    expect(unit.ownershipShare, 1.0);
  });

  Future<void> pumpShares(WidgetTester tester, FinanceSummary summary) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [2026]),
          financeSummaryProvider.overrideWith((ref, y) async => summary),
          // Returns null: no property means no mortgage, so the loan figures
          // row stays out of the way of these assertions. Overridden rather
          // than left alone so the test never touches Firebase.
          propertyByIdProvider.overrideWith((ref, id) async => null),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  FinanceSummary summaryWithUnitShares(
    int year, {
    required double propertyShare,
    required List<UnitFinance> units,
  }) {
    return FinanceSummary(
      year: year,
      totals: FinanceTotals(
        receivedRent: 18000.0,
        derivedRent: 0.0,
        directExpenses: 0.0,
        netPl: 18000.0,
        statutoryRentalIncome: 18000.0,
        statutoryNote: '',
      ),
      properties: [
        PropertyFinance(
          propertyId: 'p1',
          name: 'Ayer 8',
          ownershipShare: propertyShare,
          receivedRent: 18000.0,
          derivedRent: 0.0,
          directExpenses: 0.0,
          rentalIncomeOrLoss: 18000.0,
          netPl: 18000.0,
          statutoryContribution: 18000.0,
          units: units,
        ),
      ],
    );
  }

  testWidgets('uniform partial shares keep the single-percentage badge',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 0.5,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
          UnitFinance(unitId: 'u2', label: 'A-2', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
        ]));

    expect(find.text('50% share'), findsWidgets);
    expect(find.textContaining('share of each unit'), findsNothing);
  });

  testWidgets('mixed shares render a range badge',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 1.0,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
          UnitFinance(unitId: 'u2', label: 'A-2', rentedMonths: 12,
              contribution: 12000.0, ownershipShare: 1.0),
        ]));

    expect(find.text('50–100% share'), findsOneWidget);
  });

  testWidgets('a co-owned unit row is badged and a wholly-owned one is not',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 1.0,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 0.5),
          UnitFinance(unitId: 'u2', label: 'A-2', rentedMonths: 12,
              contribution: 12000.0, ownershipShare: 1.0),
        ]));

    // One on the A-1 row; the property badge above reads '50–100% share'.
    expect(find.text('50% share'), findsOneWidget);
    expect(find.text('100% share'), findsNothing);
  });

  testWidgets('full ownership throughout renders no badge at all',
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 1.0,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 12000.0, ownershipShare: 1.0),
        ]));

    expect(find.textContaining('% share'), findsNothing);
  });

  // A co-owned building let as whole units the landlord holds outright: the
  // property's own share (0.5) is the only thing below 1.0 anywhere in the
  // fixture. None of the other share tests can catch a bug that drops
  // block.ownershipShare from the range set — every one of them has
  // propertyShare either equal to a unit share or already 1.0 — so this is
  // the only fixture where the property's own share is observed
  // independently of any unit's.
  testWidgets(
      "a property share below 1.0 still ranges even when every unit is owned outright",
      (tester) async {
    await pumpShares(tester, summaryWithUnitShares(2026,
        propertyShare: 0.5,
        units: [
          UnitFinance(unitId: 'u1', label: 'A-1', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 1.0),
          UnitFinance(unitId: 'u2', label: 'A-2', rentedMonths: 12,
              contribution: 6000.0, ownershipShare: 1.0),
        ]));

    expect(find.text('50–100% share'), findsOneWidget);
  });
}
