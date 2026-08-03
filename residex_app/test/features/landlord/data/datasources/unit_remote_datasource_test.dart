import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/datasources/unit_remote_datasource.dart';

void main() {
  group('isBenignUnitsPermissionDenied', () {
    test('true for a permission-denied FirebaseException '
        '(parent property not yet visible to the rules)', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(isBenignUnitsPermissionDenied(error), isTrue);
    });

    test('false for other FirebaseException codes', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      expect(isBenignUnitsPermissionDenied(error), isFalse);
    });

    test('false for non-Firebase errors', () {
      expect(isBenignUnitsPermissionDenied(Exception('boom')), isFalse);
      expect(isBenignUnitsPermissionDenied(StateError('nope')), isFalse);
    });
  });
}
