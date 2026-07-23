import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/document_categories.dart';

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

  group('isAllowedUploadFilename', () {
    test('accepts pdf regardless of case', () {
      expect(isAllowedUploadFilename('Lease.PDF'), isTrue);
      expect(isAllowedUploadFilename('lease.pdf'), isTrue);
    });

    test('rejects docx now that ingestion is PDF-only', () {
      expect(isAllowedUploadFilename('lease.docx'), isFalse);
    });

    test('rejects other extensions', () {
      expect(isAllowedUploadFilename('lease.txt'), isFalse);
    });
  });

  test('image filenames are allowed for upload', () {
    expect(isAllowedUploadFilename('receipt.JPG'), isTrue);
    expect(isAllowedUploadFilename('scan.jpeg'), isTrue);
    expect(isAllowedUploadFilename('bill.png'), isTrue);
    expect(isAllowedUploadFilename('doc.docx'), isFalse);
    expect(isAllowedUploadFilename('lease.pdf'), isTrue);
  });

  test('stored categories collapse into three display folders', () {
    expect(displayCategoryFor('lease'), 'lease');
    expect(displayCategoryFor('rental_invoice'), 'rental_invoice');
    expect(displayCategoryFor('receipt'), 'rental_invoice'); // legacy alias
    for (final stored in [
      'insurance', 'loan', 'tax', 'upkeep', 'maintenance',
      'utility', 'warranty', 'expenses',
    ]) {
      expect(displayCategoryFor(stored), 'expenses', reason: stored);
    }
  });

  test('tagLabel returns the display label for a known tag', () {
    expect(tagLabel('maintenance'), 'Maintenance fees');
    expect(tagLabel('sinking_fund'), 'Sinking fund');
    expect(tagLabel('assessment_tax'), 'Assessment tax');
    expect(tagLabel('insurance_premium'), 'Insurance premium');
  });

  test('tagLabel falls back to the raw tag for an unknown value', () {
    expect(tagLabel('future_subtype'), 'future_subtype');
  });
}
