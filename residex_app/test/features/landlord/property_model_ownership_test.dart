import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';

Map<String, dynamic> _propertyJson({double? ownershipShare}) {
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
    if (ownershipShare != null) 'ownership_share': ownershipShare,
  };
}

void main() {
  test('ownership_share parses and round-trips', () {
    final model = PropertyModel.fromJson(_propertyJson(ownershipShare: 0.5), 'p1');
    expect(model.ownershipShare, 0.5);
    expect(model.toJson()['ownership_share'], 0.5);
  });

  test('absent ownership_share defaults to 1.0', () {
    final model = PropertyModel.fromJson(_propertyJson(), 'p1');
    expect(model.ownershipShare, 1.0);
    expect(model.toJson()['ownership_share'], 1.0);
  });
}
