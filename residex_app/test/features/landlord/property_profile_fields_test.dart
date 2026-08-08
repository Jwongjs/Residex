import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';

Map<String, dynamic> _propertyJson({
  String? propertyType,
  bool? hasMortgage,
  int? trackFromYear,
  String? utilitiesPaidBy,
  String? loanInputCadence,
  String? mortgageSettledOn,
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
    if (mortgageSettledOn != null) 'mortgage_settled_on': mortgageSettledOn,
  };
}

/// Every optional field set to something that is NOT its `fromJson` default.
///
/// This exists for the `withMortgageSettledOn preserves every other field`
/// test, and the distinction is the whole point of that test. Built from
/// `_propertyJson`, twelve of the twenty fields land on their defaults
/// (ownershipShare 1.0, nextSetupStep 0, foldersEnabled false, folderNames
/// {}, photos [], the nullables null...). A field dropped from
/// `withMortgageSettledOn`'s constructor call then takes that *same* default,
/// so `expect(after.x, before.x)` compares a default to a default and passes.
/// The guard reads as if it covers twenty fields while actually covering the
/// eight `required` ones the compiler already protects.
Map<String, dynamic> _saturatedPropertyJson() => {
      ..._propertyJson(
        propertyType: 'strata',
        hasMortgage: true,
        trackFromYear: 2023,
        utilitiesPaidBy: 'landlord',
        loanInputCadence: 'monthly',
        mortgageSettledOn: '2027-03',
      ),
      'ownership_share': 0.5,
      'next_setup_step': 3,
      'folders_enabled': true,
      'folder_names': {'lease': 'Leases'},
      'folder_moves': {'doc1': 'lease'},
      'photos': ['front.jpg'],
      'updatedAt': DateTime(2026, 6, 1).toIso8601String(),
    };

void main() {
  test('profile fields parse and round-trip', () {
    final model = PropertyModel.fromJson(
      _propertyJson(
        propertyType: 'strata',
        hasMortgage: true,
        trackFromYear: 2023,
        utilitiesPaidBy: 'landlord',
        loanInputCadence: 'monthly',
      ),
      'p1',
    );
    expect(model.structureType, PropertyStructureType.strata);
    expect(model.hasMortgage, isTrue);
    expect(model.trackFromYear, 2023);
    expect(model.utilitiesPaidBy, 'landlord');
    expect(model.loanInputCadence, 'monthly');

    final json = model.toJson();
    expect(json['property_type'], 'strata');
    expect(json['has_mortgage'], isTrue);
    expect(json['track_from_year'], 2023);
    expect(json['utilities_paid_by'], 'landlord');
    expect(json['loan_input_cadence'], 'monthly');
  });

  test('absent profile fields fall back to "not sure" and tenant default', () {
    final model = PropertyModel.fromJson(_propertyJson(), 'p1');
    expect(model.structureType, isNull);
    expect(model.hasMortgage, isNull);
    expect(model.trackFromYear, isNull);
    expect(model.utilitiesPaidBy, 'tenant');
    expect(model.loanInputCadence, isNull);

    final json = model.toJson();
    expect(json['property_type'], isNull);
    expect(json['has_mortgage'], isNull);
    expect(json['track_from_year'], isNull);
    expect(json['utilities_paid_by'], 'tenant');
    expect(json['loan_input_cadence'], isNull);
  });

  test('mortgage_settled_on round-trips through the model', () {
    final model = PropertyModel.fromJson(
      _propertyJson(mortgageSettledOn: '2027-03'), 'p1',
    );
    expect(model.mortgageSettledOn, '2027-03');
    expect(model.toJson()['mortgage_settled_on'], '2027-03');
  });

  test('an absent mortgage_settled_on parses as null', () {
    final model = PropertyModel.fromJson(_propertyJson(), 'p1');
    expect(model.mortgageSettledOn, isNull);
    expect(model.toJson()['mortgage_settled_on'], isNull);
  });

  test('withMortgageSettledOn can clear the date, which copyWith cannot', () {
    final settled = PropertyModel.fromJson(
      _propertyJson(mortgageSettledOn: '2027-03'), 'p1',
    ).toEntity();

    expect(settled.copyWith(mortgageSettledOn: null).mortgageSettledOn, '2027-03',
        reason: 'copyWith coalesces — this is why withMortgageSettledOn exists');
    expect(settled.withMortgageSettledOn(null).mortgageSettledOn, isNull);
    expect(settled.withMortgageSettledOn('2028-01').mortgageSettledOn, '2028-01');
  });

  test('fromEntity carries mortgage_settled_on out to Firestore', () {
    // fromEntity is the ONLY entity -> Firestore path (the repository calls it
    // on every updateProperty). Every other test here starts from fromJson, so
    // without this one, omitting the field from fromEntity would leave the
    // suite green while the date never persisted: the landlord marks the
    // mortgage settled, sees the UI update, and it is gone on next load.
    final settled = PropertyModel.fromJson(_propertyJson(), 'p1')
        .toEntity()
        .withMortgageSettledOn('2027-03');

    expect(
      PropertyModel.fromEntity(settled).toJson()['mortgage_settled_on'],
      '2027-03',
    );
  });

  test('withMortgageSettledOn preserves every other field', () {
    // Saturated fixture, not _propertyJson: see _saturatedPropertyJson's
    // comment. With defaults, a field dropped from withMortgageSettledOn's
    // constructor call re-derives the same default and this test still passes.
    final before =
        PropertyModel.fromJson(_saturatedPropertyJson(), 'p1').toEntity();
    final after = before.withMortgageSettledOn(null);

    // Guard the guard: if a later refactor reverts the fixture to defaults,
    // these fail loudly instead of quietly hollowing out the 20 assertions.
    expect(before.ownershipShare, isNot(1.0));
    expect(before.nextSetupStep, isNot(0));
    expect(before.foldersEnabled, isTrue);
    expect(before.folderNames, isNotEmpty);
    expect(before.folderMoves, isNotEmpty);
    expect(before.photos, isNotEmpty);
    expect(before.updatedAt, isNotNull);

    expect(after.id, before.id);
    expect(after.landlordId, before.landlordId);
    expect(after.name, before.name);
    expect(after.address, before.address);
    expect(after.type, before.type);
    expect(after.purchasePrice, before.purchasePrice);
    expect(after.currentValue, before.currentValue);
    expect(after.ownershipShare, before.ownershipShare);
    expect(after.structureType, before.structureType);
    expect(after.hasMortgage, before.hasMortgage);
    expect(after.trackFromYear, before.trackFromYear);
    expect(after.utilitiesPaidBy, before.utilitiesPaidBy);
    expect(after.loanInputCadence, before.loanInputCadence);
    expect(after.nextSetupStep, before.nextSetupStep);
    expect(after.foldersEnabled, before.foldersEnabled);
    expect(after.folderNames, before.folderNames);
    expect(after.folderMoves, before.folderMoves);
    expect(after.photos, before.photos);
    expect(after.createdAt, before.createdAt);
    expect(after.updatedAt, before.updatedAt);
  });
}
