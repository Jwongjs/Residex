import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';

Map<String, dynamic> _json(Map<String, dynamic> extra) => <String, dynamic>{
      'landlordId': 'l1',
      'name': 'Ayer 8',
      'address': <String, dynamic>{
        'street': '1 Jalan Kiara',
        'city': 'KL',
        'state': 'WP',
        'zipCode': '50480',
        'country': 'Malaysia',
      },
      'type': 'condo',
      'purchasePrice': 500000,
      'currentValue': 550000,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      ...extra,
    };

PropertyModel _model({
  String shareBasisDefault = 'full',
  Map<String, String> shareBasisExceptions = const {},
}) =>
    PropertyModel(
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
      shareBasisDefault: shareBasisDefault,
      shareBasisExceptions: shareBasisExceptions,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Property share basis round-trip', () {
    test('parses a stored default and exception map', () {
      final property = PropertyModel.fromJson(
        _json({
          'share_basis_default': 'mine',
          'share_basis_exceptions': <String, dynamic>{'tax': 'full'},
        }),
        'p1',
      );

      expect(property.shareBasisDefault, 'mine');
      expect(property.shareBasisExceptions, {'tax': 'full'});
    });

    test('absent fields default to full with no exceptions', () {
      final property = PropertyModel.fromJson(_json({}), 'p1');

      expect(property.shareBasisDefault, 'full');
      expect(property.shareBasisExceptions, isEmpty);
    });

    test('an unrecognised stored default reads as full', () {
      final property = PropertyModel.fromJson(
        _json({'share_basis_default': 'sometimes'}),
        'p1',
      );

      expect(property.shareBasisDefault, 'full');
    });

    test('toJson writes both fields', () {
      final json = _model(
        shareBasisDefault: 'mine',
        shareBasisExceptions: const {'tax': 'full'},
      ).toJson();

      expect(json['share_basis_default'], 'mine');
      expect(json['share_basis_exceptions'], {'tax': 'full'});
    });

    test('copyWith carries and can replace both fields', () {
      final property = _model(shareBasisDefault: 'mine');

      expect(property.copyWith(name: 'Other').shareBasisDefault, 'mine');
      expect(property.copyWith(shareBasisDefault: 'full').shareBasisDefault, 'full');
      expect(
        property.copyWith(shareBasisExceptions: const {'upkeep': 'full'})
            .shareBasisExceptions,
        {'upkeep': 'full'},
      );
    });

    test('withMortgageSettledOn preserves both fields', () {
      // It rebuilds Property field by field, so a field missing from it is
      // silently reset the next time a mortgage is marked settled.
      final property = _model(
        shareBasisDefault: 'mine',
        shareBasisExceptions: const {'tax': 'full'},
      ).withMortgageSettledOn('2026-03');

      expect(property.shareBasisDefault, 'mine');
      expect(property.shareBasisExceptions, {'tax': 'full'});
    });
  });
}
