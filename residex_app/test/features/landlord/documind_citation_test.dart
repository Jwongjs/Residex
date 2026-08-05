// A citation whose value came from extracted facts must not claim a page.
// Showing "p.—" beside a filename reads as a missing page number; the point
// is to say the value came from the document's parsed details instead.
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/documind_models.dart';

void main() {
  group('CitationModel.source', () {
    test('defaults to excerpt when the server omits it', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1',
        'filename': 'lease.pdf',
        'category': 'lease',
        'page': 3,
        'snippet': 'text',
        'score': 0.9,
      });
      expect(c.source, 'excerpt');
      expect(c.isExtractedFacts, isFalse);
    });

    test('parses extracted_facts and exposes it as a flag', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1',
        'filename': 'lease.pdf',
        'category': 'lease',
        'page': null,
        'snippet': 'Lease end: 2026-10-31',
        'score': 1.0,
        'source': 'extracted_facts',
      });
      expect(c.source, 'extracted_facts');
      expect(c.isExtractedFacts, isTrue);
      expect(c.page, isNull);
    });

    test('round-trips source through toJson', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1',
        'filename': 'lease.pdf',
        'category': 'lease',
        'snippet': 's',
        'score': 1.0,
        'source': 'extracted_facts',
      });
      expect(c.toJson()['source'], 'extracted_facts');
    });

    test('converting to the entity preserves source', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1',
        'filename': 'lease.pdf',
        'category': 'lease',
        'snippet': 'Lease end: 2026-10-31',
        'score': 1.0,
        'source': 'extracted_facts',
      });
      expect(c.toEntity().isExtractedFacts, isTrue);
    });
  });
}
