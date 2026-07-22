import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';

Map<String, dynamic> _propertyJson({
  String? propertyType,
  bool? hasMortgage,
  int? trackFromYear,
  String? utilitiesPaidBy,
}) {
  return {
    'landlordId': 'l1',
    'name': 'Kiara Court',
    'address': {
      'street': '1 Jalan Kiara',
      'city': 'Kuala Lumpur',
      'state': 'WP',
      'zipCode': '50480',
      'country': 'Malaysia',
    },
    'type': 'condo',
    'purchasePrice': 500000,
    'currentValue': 550000,
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    if (propertyType != null) 'property_type': propertyType,
    if (hasMortgage != null) 'has_mortgage': hasMortgage,
    if (trackFromYear != null) 'track_from_year': trackFromYear,
    if (utilitiesPaidBy != null) 'utilities_paid_by': utilitiesPaidBy,
  };
}

void main() {
  test('profile fields parse and round-trip', () {
    final model = PropertyModel.fromJson(
      _propertyJson(
        propertyType: 'strata',
        hasMortgage: true,
        trackFromYear: 2023,
        utilitiesPaidBy: 'landlord',
      ),
      'p1',
    );
    expect(model.structureType, PropertyStructureType.strata);
    expect(model.hasMortgage, isTrue);
    expect(model.trackFromYear, 2023);
    expect(model.utilitiesPaidBy, 'landlord');

    final json = model.toJson();
    expect(json['property_type'], 'strata');
    expect(json['has_mortgage'], isTrue);
    expect(json['track_from_year'], 2023);
    expect(json['utilities_paid_by'], 'landlord');
  });

  test('absent profile fields fall back to "not sure" and tenant default', () {
    final model = PropertyModel.fromJson(_propertyJson(), 'p1');
    expect(model.structureType, isNull);
    expect(model.hasMortgage, isNull);
    expect(model.trackFromYear, isNull);
    expect(model.utilitiesPaidBy, 'tenant');

    final json = model.toJson();
    expect(json['property_type'], isNull);
    expect(json['has_mortgage'], isNull);
    expect(json['track_from_year'], isNull);
    expect(json['utilities_paid_by'], 'tenant');
  });
}
