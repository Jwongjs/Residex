import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/app_choice_chip.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart';

Property _property({
  double ownershipShare = 1.0,
  String shareBasisDefault = 'full',
}) =>
    Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Ayer 8',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      ownershipShare: ownershipShare,
      shareBasisDefault: shareBasisDefault,
      createdAt: DateTime(2026, 1, 1),
    );

/// Records what the chip wrote, in place of the real HTTP action.
class _BasisRecorder {
  String? docId;
  String? basis;
}

Future<void> _pumpSheet(
  WidgetTester tester,
  List<Map<String, dynamic>> lines, {
  Property? property,
  List<Unit> units = const [],
  _BasisRecorder? recorder,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Overridden even when null so the sheet never reaches the real data
        // source from a desktop test runner.
        propertyByIdProvider.overrideWith((ref, id) async => property),
        unitsForPropertyStreamProvider
            .overrideWith((ref, id) => Stream.value(units)),
        if (recorder != null)
          setDocumentShareBasisActionProvider.overrideWithValue(
            ({required String docId, required String shareBasis}) async {
              recorder.docId = docId;
              recorder.basis = shareBasis;
            },
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ExpenseLinesReviewSheet(
            docId: 'doc-1', propertyId: 'p1', initialLines: lines,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening the edit dialog on a late_penalty line does not crash the dropdown',
      (tester) async {
    await _pumpSheet(tester, [
      {'subtype': 'late_penalty', 'amount': 50.0, 'period_year': 2025},
    ]);

    // Tapping the row opens the edit dialog, whose type dropdown must contain
    // an item for every stored subtype — including late_penalty.
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit expense line'), findsOneWidget);
  });

  testWidgets('every backend expense subtype has a dropdown label', (tester) async {
    // Guards against any stored subtype crashing the edit dialog.
    const backendSubtypes = {
      'loan_interest', 'assessment_tax', 'quit_rent', 'parcel_rent',
      'maintenance', 'sinking_fund', 'insurance_premium', 'upkeep',
      'management_fee', 'rent_collection', 'security_fee', 'pest_control',
      'agent_commission', 'legal_fee', 'stamp_duty', 'advertising', 'sst',
      'utilities', 'late_penalty', 'renovation', 'loan_principal',
    };
    for (final subtype in backendSubtypes) {
      expect(expenseSubtypeLabels.containsKey(subtype), isTrue,
          reason: 'missing dropdown label for "$subtype"');
    }
  });

  testWidgets('deleting a line removes it from the list and enables save', (tester) async {
    await _pumpSheet(tester, [
      {'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025},
      {'subtype': 'late_penalty', 'amount': 50.0, 'period_year': 2025},
    ]);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    // Confirm dialog
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNWidgets(1)); // one line left
    expect(find.text('Save changes'), findsOneWidget);           // dirty
  });

  testWidgets('no chip when no share applies', (tester) async {
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 1.0),
    );

    expect(find.text('At the full property amount'), findsNothing);
  });

  testWidgets('the chip is pre-set to the resolved default', (tester) async {
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 0.5, shareBasisDefault: 'mine'),
    );

    final mine = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'Already split to my share'),
    );
    expect(mine.selected, isTrue,
        reason: 'the landlord confirms rather than answers');
  });

  testWidgets('a property at 100% with one co-owned unit still shows the chip',
      (tester) async {
    // THE §3a GATE, on this surface. Keyed on the property's own share this
    // passes silently and the feature is simply absent for that unit.
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 1.0),
      units: [
        Unit(
          id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
          isOccupied: true, ownershipShare: 0.5, createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.text('At the full property amount'), findsOneWidget);
  });

  testWidgets('changing the chip writes the basis for that document',
      (tester) async {
    final recorder = _BasisRecorder();
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 0.5),
      recorder: recorder,
    );

    await tester.tap(find.text('Already split to my share'));
    await tester.pumpAndSettle();

    expect(recorder.docId, 'doc-1');
    expect(recorder.basis, 'mine');
  });

  testWidgets('confirming the pre-set answer writes nothing', (tester) async {
    // "Looks right" is the common path and must not put a redundant override
    // on every expenses document a co-owner ever uploads.
    final recorder = _BasisRecorder();
    await _pumpSheet(
      tester,
      [{'subtype': 'maintenance', 'amount': 300.0, 'period_year': 2025}],
      property: _property(ownershipShare: 0.5),
      recorder: recorder,
    );

    await tester.tap(find.text('At the full property amount'));
    await tester.pumpAndSettle();

    expect(recorder.basis, isNull);
  });
}
