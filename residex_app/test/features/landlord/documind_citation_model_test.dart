import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/documind_models.dart';

void main() {
  test('CitationModel.fromJson parses unit fields', () {
    final model = CitationModel.fromJson({
      'doc_id': 'doc-1',
      'filename': 'leaseA.pdf',
      'category': 'lease',
      'page': 3,
      'snippet': 'Tenancy ends 31 December 2026.',
      'score': 0.95,
      'unit_id': 'unit-a',
      'unit_label': 'Unit A',
    });

    expect(model.unitId, 'unit-a');
    expect(model.unitLabel, 'Unit A');
  });

  test('CitationModel.fromJson defaults unit fields to null (pre-units responses)', () {
    final model = CitationModel.fromJson({
      'doc_id': 'doc-1',
      'filename': 'old.pdf',
      'category': 'utility',
      'snippet': 'water bill',
      'score': 0.5,
    });

    expect(model.unitId, isNull);
    expect(model.unitLabel, isNull);
  });
}
