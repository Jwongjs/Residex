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
Property _property({required double ownershipShare}) => Property(
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

  // Not part of the brief's own test list. This documents a hazard the task
  // spec flagged but explicitly said not to fix: on a co-owned property the
  // share field is shown up front (propertyShare < 1.0) and prefilled to the
  // property's own share, even for a unit that has never had a share set.
  // Hitting Save without touching that field pins the unit at the property's
  // *current* share explicitly — converting a unit that was inheriting into
  // one that is pinned. If the property's share later changes, this unit
  // will no longer follow. This test asserts the actual behaviour so the
  // hazard is visible in the suite rather than silently unexercised.
  testWidgets(
      'an untouched unit on a co-owned property pins the property\'s '
      'current share instead of staying unset (documents a known hazard)',
      (tester) async {
    final repository = await _pumpUnits(tester,
        property: _property(ownershipShare: 0.5), unit: _unit());

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();
    // The field is already shown (co-owned property) and prefilled to 50,
    // matching the property's share — the landlord never touches it.
    expect(find.text('My share of this unit (%)'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Documented hazard: this writes an explicit 0.5, not null. The unit is
    // now pinned to the property's share at the moment of this save, and
    // will not follow the property's share if it changes later.
    expect(repository.lastUpdated?.ownershipShare, 0.5);
  });
}
