import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart';

/// Captures the [Property] passed to `updateProperty` instead of hitting
/// Firestore, so tests can verify `_chooseCadence`'s persistence call
/// without faking the full repository/use-case chain.
class _CapturingPropertyController extends PropertyController {
  _CapturingPropertyController(Ref ref, this.onUpdate) : super(ref);

  final void Function(Property) onUpdate;

  @override
  Future<void> updateProperty(Property property) async {
    onUpdate(property);
  }
}

Property _fakeProperty({String? loanInputCadence}) {
  return Property(
    id: 'p1',
    landlordId: 'landlord1',
    name: 'Test Property',
    address: const PropertyAddress(
      street: '1 Test St',
      city: 'Kuala Lumpur',
      state: 'WP',
      zipCode: '50000',
      country: 'Malaysia',
    ),
    type: PropertyType.apartment,
    purchasePrice: 100000,
    currentValue: 100000,
    loanInputCadence: loanInputCadence,
    createdAt: DateTime(2025, 1, 1),
  );
}

/// Pumps the sheet standalone, modelled on finance_screen_test.dart's
/// `_pumpScreenWithProperty` — overrides the two providers the sheet reads
/// directly (financeSummaryProvider for the live unit list,
/// manualLoanEntriesProvider for the recorded-entries list).
Future<void> _pumpSheet(
  WidgetTester tester, {
  required PropertyStructureType? structureType,
  required List<UnitFinance> units,
  required String? cadence,
}) async {
  const year = 2025;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      financeSummaryProvider.overrideWith((ref, y) async => FinanceSummary(
            year: y,
            totals: FinanceTotals(
              receivedRent: 0,
              derivedRent: 0,
              directExpenses: 0,
              netPl: 0,
              statutoryRentalIncome: 0,
              statutoryNote: '',
            ),
            properties: [
              PropertyFinance(
                propertyId: 'p1',
                name: 'Test Property',
                receivedRent: 0,
                derivedRent: 0,
                directExpenses: 0,
                rentalIncomeOrLoss: 0,
                units: units,
              ),
            ],
          )),
      manualLoanEntriesProvider((propertyId: 'p1', year: year))
          .overrideWith((ref) async => <Map<String, dynamic>>[]),
    ],
    child: MaterialApp(
      home: ManualLoanEntrySheet(
        propertyId: 'p1',
        year: year,
        cadence: cadence,
        structureType: structureType,
        units: units,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

FinanceSummary _summaryWithUnitLoanStatus(int year, String? loanStatus) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: 0.0,
      derivedRent: 0.0,
      directExpenses: 0.0,
      netPl: 0.0,
      statutoryRentalIncome: 0.0,
      statutoryNote: '',
    ),
    properties: [
      PropertyFinance(
        propertyId: 'p1',
        name: 'Ayer 8',
        receivedRent: 0.0,
        derivedRent: 0.0,
        directExpenses: 0.0,
        rentalIncomeOrLoss: 0.0,
        units: [
          UnitFinance(
            unitId: 'u1',
            label: 'A-1',
            rentedMonths: 0,
            contribution: 0,
            loanStatus: loanStatus,
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('save calls the record action with entered amounts', (tester) async {
    double? capturedInterest;
    double? capturedPrincipal;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recordManualLoanEntryActionProvider.overrideWithValue(({
          required String propertyId,
          required int year,
          required String cadence,
          required double interestPaid,
          required double principalPaid,
          int? month,
          String? unitId,
        }) async {
          capturedInterest = interestPaid;
          capturedPrincipal = principalPaid;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: const MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          structureType: null,
          units: [],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('manual-loan-interest')), '5000');
    await tester.enterText(find.byKey(const Key('manual-loan-principal')), '3000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedInterest, 5000);
    expect(capturedPrincipal, 3000);
  });

  testWidgets('selecting a unit forwards its unitId when saving', (tester) async {
    String? capturedUnitId;
    var capturedUnitIdSet = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recordManualLoanEntryActionProvider.overrideWithValue(({
          required String propertyId,
          required int year,
          required String cadence,
          required double interestPaid,
          required double principalPaid,
          int? month,
          String? unitId,
        }) async {
          capturedUnitId = unitId;
          capturedUnitIdSet = true;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          structureType: null,
          units: [
            UnitFinance(
              unitId: 'u1', label: 'A-1', rentedMonths: 0, contribution: 0,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-1').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('manual-loan-interest')), '100');
    await tester.enterText(find.byKey(const Key('manual-loan-principal')), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedUnitIdSet, isTrue);
    expect(capturedUnitId, 'u1');
  });

  testWidgets('tapping "No loan here" calls the exemption action with the selected unitId',
      (tester) async {
    String? capturedPropertyId;
    String? capturedUnitId;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        setUnitLoanExemptionActionProvider.overrideWithValue(
            ({required String propertyId, required String unitId}) async {
          capturedPropertyId = propertyId;
          capturedUnitId = unitId;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          structureType: null,
          units: [
            UnitFinance(
              unitId: 'u1', label: 'A-1', rentedMonths: 0, contribution: 0,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-1').last);
    await tester.pumpAndSettle();

    expect(find.text('No loan here'), findsOneWidget);
    await tester.tap(find.text('No loan here'));
    await tester.pumpAndSettle();

    expect(capturedPropertyId, 'p1');
    expect(capturedUnitId, 'u1');
  });

  testWidgets(
      'shows "No loan on this unit" from the watched summary even when the frozen widget.units param says otherwise',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        financeSummaryProvider
            .overrideWith((ref, y) async => _summaryWithUnitLoanStatus(y, 'no_loan')),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          structureType: null,
          // Stale frozen snapshot: no loanStatus at all. If the sheet read
          // this instead of the watched provider, it would show
          // "No loan here" rather than the exemption chip + Undo.
          units: [
            UnitFinance(
              unitId: 'u1', label: 'A-1', rentedMonths: 0, contribution: 0,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-1').last);
    await tester.pumpAndSettle();

    expect(find.text('No loan on this unit'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('No loan here'), findsNothing);
  });

  testWidgets(
      'shows "No loan here" from the watched summary even when the frozen widget.units param says otherwise',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        financeSummaryProvider
            .overrideWith((ref, y) async => _summaryWithUnitLoanStatus(y, null)),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          structureType: null,
          // Stale frozen snapshot: marked no_loan. If the sheet read this
          // instead of the watched provider, it would show the exemption
          // chip + Undo rather than "No loan here".
          units: [
            UnitFinance(
              unitId: 'u1',
              label: 'A-1',
              rentedMonths: 0,
              contribution: 0,
              loanStatus: 'no_loan',
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-1').last);
    await tester.pumpAndSettle();

    expect(find.text('No loan here'), findsOneWidget);
    expect(find.text('No loan on this unit'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('landed property offers no scope dropdown', (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.landed,
        units: [UnitFinance(unitId: 'u1', label: 'Room A', rentedMonths: 12, contribution: 0)],
        cadence: 'annual');
    expect(find.text('SCOPE'), findsNothing);
  });

  testWidgets('strata property with units offers units but not Whole property',
      (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.strata,
        units: [UnitFinance(unitId: 'u1', label: 'Unit 1', rentedMonths: 12, contribution: 0)],
        cadence: 'annual');
    expect(find.text('SCOPE'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String?>).first);
    await tester.pumpAndSettle();
    expect(find.text('Whole property'), findsNothing);
    expect(find.text('Unit 1'), findsWidgets);
  });

  testWidgets('strata property with no units offers no scope dropdown',
      (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.strata, units: const [], cadence: 'annual');
    expect(find.text('SCOPE'), findsNothing);
  });

  testWidgets('unknown structure type keeps both options', (tester) async {
    await _pumpSheet(tester,
        structureType: null,
        units: [UnitFinance(unitId: 'u1', label: 'Unit 1', rentedMonths: 12, contribution: 0)],
        cadence: 'annual');
    await tester.tap(find.byType(DropdownButton<String?>).first);
    await tester.pumpAndSettle();
    expect(find.text('Whole property'), findsWidgets);
  });

  testWidgets('cadence is asked when the property has none yet', (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.landed, units: const [], cadence: null);
    expect(find.text('One annual figure, or monthly instalments?'), findsOneWidget);
  });

  testWidgets('cadence is not re-asked once the property has one', (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.landed, units: const [], cadence: 'annual');
    expect(find.text('One annual figure, or monthly instalments?'), findsNothing);
  });

  testWidgets('tapping a cadence chip persists the choice via propertyControllerProvider',
      (tester) async {
    Property? capturedProperty;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        financeSummaryProvider.overrideWith((ref, y) async => FinanceSummary(
              year: y,
              totals: FinanceTotals(
                receivedRent: 0,
                derivedRent: 0,
                directExpenses: 0,
                netPl: 0,
                statutoryRentalIncome: 0,
                statutoryNote: '',
              ),
            )),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
        propertyByIdProvider
            .overrideWith((ref, id) async => _fakeProperty()),
        propertyControllerProvider.overrideWith(
          (ref) => _CapturingPropertyController(
              ref, (p) => capturedProperty = p),
        ),
      ],
      child: const MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: null,
          structureType: PropertyStructureType.landed,
          units: [],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('One annual figure, or monthly instalments?'), findsOneWidget);
    await tester.tap(find.text('One annual figure'));
    await tester.pumpAndSettle();

    // The question disappears once answered, and the choice was persisted.
    expect(find.text('One annual figure, or monthly instalments?'), findsNothing);
    expect(capturedProperty?.id, 'p1');
    expect(capturedProperty?.loanInputCadence, 'annual');
  });

  testWidgets(
      'strata property with units pre-selects the first live unit as the visible closed-dropdown value',
      (tester) async {
    await _pumpSheet(tester,
        structureType: PropertyStructureType.strata,
        units: [UnitFinance(unitId: 'u1', label: 'Unit 1', rentedMonths: 12, contribution: 0)],
        cadence: 'annual');

    // Asserted BEFORE opening the dropdown: this is the closed button's
    // displayed value, proving `_selectedUnitId` was actually defaulted to
    // 'u1' rather than staying null (which would show nothing here, since
    // strata hides the "Whole property" item entirely).
    expect(find.text('Unit 1'), findsOneWidget);
  });

  testWidgets(
      'default selection derives from the live units list, not a stale widget.units param',
      (tester) async {
    // widget.units (what a caller passes) deliberately disagrees with what
    // financeSummaryProvider (the live source build() actually uses)
    // returns — modelling Task 13's documents_screen.dart caller, which can
    // pass a stale/empty block relative to the watched summary.
    final staleUnits = [
      UnitFinance(unitId: 'stale', label: 'Stale Unit', rentedMonths: 0, contribution: 0),
    ];
    final liveUnits = [
      UnitFinance(unitId: 'u1', label: 'Live Unit', rentedMonths: 12, contribution: 0),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        financeSummaryProvider.overrideWith((ref, y) async => FinanceSummary(
              year: y,
              totals: FinanceTotals(
                receivedRent: 0,
                derivedRent: 0,
                directExpenses: 0,
                netPl: 0,
                statutoryRentalIncome: 0,
                statutoryNote: '',
              ),
              properties: [
                PropertyFinance(
                  propertyId: 'p1',
                  name: 'Test Property',
                  receivedRent: 0,
                  derivedRent: 0,
                  directExpenses: 0,
                  rentalIncomeOrLoss: 0,
                  units: liveUnits,
                ),
              ],
            )),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          structureType: PropertyStructureType.strata,
          units: staleUnits,
        ),
      ),
    ));
    // If the selection were still seeded from widget.units (the bug), the
    // default would be 'stale' — which has no matching item in the live
    // list once "Whole property" is hidden for strata, and DropdownButton
    // asserts on that mismatch. So this pump itself would throw if the
    // regression came back.
    await tester.pumpAndSettle();

    expect(find.text('Live Unit'), findsOneWidget);
    expect(find.text('Stale Unit'), findsNothing);
    expect(find.text('Whole property'), findsNothing);
  });
}
