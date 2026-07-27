import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';

Map<String, dynamic> _propertyJson({
  String? propertyType,
  bool? hasMortgage,
  int? trackFromYear,
  String? utilitiesPaidBy,
  String? loanInputCadence,
  String? loanInputMethod,
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
    if (loanInputCadence != null) 'loan_input_cadence': loanInputCadence,
    if (loanInputMethod != null) 'loan_input_method': loanInputMethod,
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
        loanInputCadence: 'monthly',
        loanInputMethod: 'manual',
      ),
      'p1',
    );
    expect(model.structureType, PropertyStructureType.strata);
    expect(model.hasMortgage, isTrue);
    expect(model.trackFromYear, 2023);
    expect(model.utilitiesPaidBy, 'landlord');
    expect(model.loanInputCadence, 'monthly');
    expect(model.loanInputMethod, 'manual');

    final json = model.toJson();
    expect(json['property_type'], 'strata');
    expect(json['has_mortgage'], isTrue);
    expect(json['track_from_year'], 2023);
    expect(json['utilities_paid_by'], 'landlord');
    expect(json['loan_input_cadence'], 'monthly');
    expect(json['loan_input_method'], 'manual');
  });

  test('absent profile fields fall back to "not sure" and tenant default', () {
    final model = PropertyModel.fromJson(_propertyJson(), 'p1');
    expect(model.structureType, isNull);
    expect(model.hasMortgage, isNull);
    expect(model.trackFromYear, isNull);
    expect(model.utilitiesPaidBy, 'tenant');
    expect(model.loanInputCadence, isNull);
    expect(model.loanInputMethod, isNull);

    final json = model.toJson();
    expect(json['property_type'], isNull);
    expect(json['has_mortgage'], isNull);
    expect(json['track_from_year'], isNull);
    expect(json['utilities_paid_by'], 'tenant');
    expect(json['loan_input_cadence'], isNull);
    expect(json['loan_input_method'], isNull);
  });
}
