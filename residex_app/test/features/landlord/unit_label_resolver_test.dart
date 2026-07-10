import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/unit_label_resolver.dart';

void main() {
  final liveUnits = [
    Unit(
      id: 'unit-A',
      propertyId: 'p1',
      label: 'Studio A (renamed)',
      monthlyRent: 1000,
      isOccupied: true,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  test('resolves live label for an existing unit (rename-safe)', () {
    final label = resolveUnitLabel(
      unitId: 'unit-A',
      storedLabel: 'Unit A',
      liveUnits: liveUnits,
    );

    expect(label, 'Studio A (renamed)');
  });

  test('falls back to stored label when unit no longer resolves', () {
    final label = resolveUnitLabel(
      unitId: 'unit-gone',
      storedLabel: 'Unit B',
      liveUnits: liveUnits,
    );

    expect(label, 'Unit B');
  });

  test('returns null for property-wide records', () {
    final label = resolveUnitLabel(
      unitId: null,
      storedLabel: null,
      liveUnits: liveUnits,
    );

    expect(label, isNull);
  });
}
