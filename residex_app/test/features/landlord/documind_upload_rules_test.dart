import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_screen.dart';

void main() {
  final units = [
    Unit(
      id: 'u1',
      propertyId: 'p1',
      label: 'Unit 1',
      monthlyRent: 1000,
      isOccupied: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    Unit(
      id: 'u2',
      propertyId: 'p1',
      label: 'Unit 2',
      monthlyRent: 1100,
      isOccupied: false,
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  group('uploadUnitDialogOptions', () {
    test('lease uploads list units first and demote whole property to last', () {
      final options = uploadUnitDialogOptions(category: 'lease', units: units);

      expect(options.first?.id, 'u1');
      expect(options.last, isNull);
      expect(options.length, 3);
    });

    test('non-lease categories keep whole property first', () {
      final options = uploadUnitDialogOptions(category: 'insurance', units: units);

      expect(options.first, isNull);
      expect(options.sublist(1).map((unit) => unit!.id), ['u1', 'u2']);
    });
  });
}
