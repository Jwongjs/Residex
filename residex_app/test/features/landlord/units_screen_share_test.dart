import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/domain/repositories/unit_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/4-Portfolio/units_screen.dart';

/// Captures what the edit dialog saves, through the real controller and use
/// case rather than a stubbed provider, so the write path is exercised.
class _FakeUnitRepository implements UnitRepository {
  _FakeUnitRepository(this._units);

  final List<Unit> _units;
  Unit? lastUpdated;

  @override
  Future<void> updateUnit(Unit unit) async {
    lastUpdated = unit;
  }

  @override
  Future<List<Unit>> getUnitsForProperty(String propertyId) async => _units;
  @override
  Stream<List<Unit>> streamUnitsForProperty(String propertyId) =>
      Stream.value(_units);
  @override
  Future<String> createUnit(Unit unit) async => 'u9';
  @override
  Future<void> deleteUnit(String propertyId, String unitId) async {}
  @override
  Future<void> deleteAllUnitsForProperty(String propertyId) async {}
}

// Mirrors the fixture in add_property_dialog_loan_prefs_test.dart:7-20.
Property _property({
  required double ownershipShare,
  PropertyStructureType? structureType,
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
      structureType: structureType,
      purchasePrice: 500000,
      currentValue: 550000,
      ownershipShare: ownershipShare,
      createdAt: DateTime(2026, 1, 1),
    );

Unit _unit({double? ownershipShare}) => Unit(
      id: 'u1',
      propertyId: 'p1',
      label: 'A-1',
      monthlyRent: 1200,
      isOccupied: true,
      ownershipShare: ownershipShare,
      createdAt: DateTime(2026, 1, 1),
    );

Future<_FakeUnitRepository> _pumpUnits(
  WidgetTester tester, {
  required Property property,
  required Unit unit,
}) async {
  final repository = _FakeUnitRepository([unit]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unitRepositoryProvider.overrideWithValue(repository),
        propertyByIdProvider.overrideWith((ref, id) async => property),
      ],
      child: const MaterialApp(
        home: UnitsScreen(propertyId: 'p1', propertyName: 'Ayer 8'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('a co-owned property shows the share field straight away',
      (tester) async {
    await _pumpUnits(tester,
        property: _property(ownershipShare: 0.5), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();

    expect(find.text('My share of this unit (%)'), findsOneWidget);
  });

  testWidgets('a wholly-owned property hides it behind an affordance',
      (tester) async {
    await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    expect(find.text('My share of this unit (%)'), findsNothing);

    await tester.tap(find.text('Set a different share for this unit'));
    await tester.pumpAndSettle();
    expect(find.text('My share of this unit (%)'), findsOneWidget);
  });

  testWidgets('saving writes the share the landlord typed', (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set a different share for this unit'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'My share of this unit (%)'), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdated?.ownershipShare, 0.5);
  });

  testWidgets('a unit already carrying a share prefills and keeps it',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0),
        unit: _unit(ownershipShare: 0.5));

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.lastUpdated?.ownershipShare, 0.5);
  });

  testWidgets('an untouched unit on a full property saves no share',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 1.0), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdated?.ownershipShare, isNull);
  });

  // The three tests below gate the "only write a share the landlord actually
  // engaged with" rule. On a co-owned property the field is shown up front and
  // prefilled with the property's share, so without this rule any Save — a
  // rename, a rent correction — would pin an inheriting unit to the property's
  // *current* share. That is invisible at the time and wrong later: when the
  // property's share moves, the pinned unit stops following it, and copyWith
  // cannot restore null from any screen in the app.
  //
  // The rule needs two clauses, and there is one test per clause below.

  testWidgets('an untouched unit on a co-owned property stays inheriting',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 0.5), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    // Shown and prefilled to the property's 50 — the landlord never touches it.
    expect(find.text('My share of this unit (%)'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Null, not 0.5: the unit keeps inheriting, so it still follows the
    // property if that share later changes.
    expect(repository.lastUpdated?.ownershipShare, isNull);
  });

  testWidgets('editing the field on a co-owned property still writes it',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 0.5), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'My share of this unit (%)'), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The other half of the rule: not writing an untouched field must not
    // become not writing at all.
    expect(repository.lastUpdated?.ownershipShare, 0.6);
  });

  testWidgets('an untouched save does not re-round a stored share',
      (tester) async {
    // 0.333 prefills as "33" — the field cannot represent it. Re-parsing an
    // untouched field would write 0.33 and silently lose precision on an edit
    // the landlord never made. Passing the stored value through avoids it.
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 0.5),
        unit: _unit(ownershipShare: 0.333));

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    expect(find.text('33'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdated?.ownershipShare, 0.333);
  });

  testWidgets(
      'an inherited share on a co-owned strata property explains itself',
      (tester) async {
    await _pumpUnits(tester,
        property: _property(
            ownershipShare: 0.5, structureType: PropertyStructureType.strata),
        unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();

    expect(
      find.text("Inherited from the property's 50% share. "
          "Change only if this unit's ownership differs."),
      findsOneWidget,
    );
  });

  testWidgets('a landed property never offers a per-unit share',
      (tester) async {
    await _pumpUnits(tester,
        property: _property(
            ownershipShare: 0.5, structureType: PropertyStructureType.landed),
        unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();

    expect(find.text('My share of this unit (%)'), findsNothing);
    expect(find.text('Set a different share for this unit'), findsNothing);
  });

  testWidgets(
      'a landed property still saves a rename without touching share',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(
            ownershipShare: 0.5, structureType: PropertyStructureType.landed),
        unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Label'), 'Room 1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdated?.label, 'Room 1');
    expect(repository.lastUpdated?.ownershipShare, isNull);
  });

  testWidgets("a landed property's unit row shows no share subtitle",
      (tester) async {
    await _pumpUnits(tester,
        property: _property(
            ownershipShare: 0.5, structureType: PropertyStructureType.landed),
        unit: _unit());

    expect(find.textContaining('% share'), findsNothing);
  });

  testWidgets("a strata property's unit row still shows its share subtitle",
      (tester) async {
    await _pumpUnits(tester,
        property: _property(
            ownershipShare: 0.5, structureType: PropertyStructureType.strata),
        unit: _unit());

    expect(find.textContaining('% share'), findsOneWidget);
  });
}
