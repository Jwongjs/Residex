import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/documind_models.dart';

void main() {
  test('fromJson parses extracted facts and confidence', () {
    final model = DocuMindDocumentModel.fromJson(const {
      'doc_id': 'd1',
      'landlord_id': 'l1',
      'property_id': 'p1',
      'category': 'tax',
      'filename': 'quitrent.pdf',
      'chunks_indexed': 1,
      'uploaded_at': '2026-07-16T10:00:00Z',
      'extracted_facts': {'amount': 460.63, 'period_year': 2026},
      'facts_confidence': 0.9,
    });
    expect(model.extractedFacts!['amount'], 460.63);
    expect(model.factsConfidence, 0.9);
    expect(model.toEntity().extractedFacts!['period_year'], 2026);
  });

  test('fromJson without extraction fields yields nulls', () {
    final model = DocuMindDocumentModel.fromJson(const {
      'doc_id': 'd2',
      'landlord_id': 'l1',
      'property_id': 'p1',
      'category': 'lease',
      'filename': 'lease.pdf',
      'chunks_indexed': 3,
      'uploaded_at': '2026-07-16T10:00:00Z',
    });
    expect(model.extractedFacts, isNull);
    expect(model.factsConfidence, isNull);
  });
}
