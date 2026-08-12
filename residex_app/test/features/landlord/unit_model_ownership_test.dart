import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/unit_model.dart';

void main() {
  group('UnitModel ownership share', () {
    test('parses a stored ownership_share', () {
      final unit = UnitModel.fromJson({
        'label': 'A-1',
        'monthlyRent': 1200,
        'isOccupied': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'ownership_share': 0.5,
      }, 'u1', 'p1');

      expect(unit.ownershipShare, 0.5);
    });

    test('an absent ownership_share stays null, meaning inherit', () {
      final unit = UnitModel.fromJson({
        'label': 'A-2',
        'monthlyRent': 1200,
        'isOccupied': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }, 'u2', 'p1');

      expect(unit.ownershipShare, isNull);
    });

    test('an int ownership_share parses as a double', () {
      final unit = UnitModel.fromJson({
        'label': 'A-3',
        'monthlyRent': 1200,
        'isOccupied': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'ownership_share': 1,
      }, 'u3', 'p1');

      expect(unit.ownershipShare, 1.0);
    });

    test('toJson writes ownership_share only when set', () {
      final withShare = UnitModel(
        id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
        isOccupied: true, createdAt: DateTime(2026, 1, 1), ownershipShare: 0.5,
      );
      final without = UnitModel(
        id: 'u2', propertyId: 'p1', label: 'A-2', monthlyRent: 1200,
        isOccupied: true, createdAt: DateTime(2026, 1, 1),
      );

      expect(withShare.toJson()['ownership_share'], 0.5);
      expect(without.toJson().containsKey('ownership_share'), isFalse);
    });

    test('copyWith carries the share and can set one', () {
      final unit = UnitModel(
        id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
        isOccupied: true, createdAt: DateTime(2026, 1, 1),
      );

      expect(unit.copyWith(label: 'A-9').ownershipShare, isNull);
      expect(unit.copyWith(ownershipShare: 0.5).ownershipShare, 0.5);
    });
  });
}
