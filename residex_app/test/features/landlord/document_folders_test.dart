import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/providers/document_folders.dart';

DocuMindDocument _doc(String id, List<DocumentTag> tags, {String category = 'expenses'}) {
  return DocuMindDocument(
    docId: id, landlordId: 'l1', propertyId: 'p1', category: category,
    filename: '$id.pdf', chunksIndexed: 1, uploadedAt: DateTime(2026, 1, 1),
    tags: tags,
  );
}

DocuMindDocument _docWithFacts(String id, Map<String, dynamic>? facts) {
  return DocuMindDocument(
    docId: id, landlordId: 'l1', propertyId: 'p1', category: 'expenses',
    filename: '$id.pdf', chunksIndexed: 1, uploadedAt: DateTime(2026, 6, 15),
    extractedFacts: facts,
  );
}

const _periodic = 'periodic';
const _oneOff = 'one_off';
const _adHoc = 'ad_hoc';

void main() {
  group('naturalFolderKey', () {
    test('periodic tags define the key; one-off tags ride along', () {
      final doc = _doc('feb', [
        const DocumentTag(tag: 'maintenance', rhythm: _periodic),
        const DocumentTag(tag: 'sinking_fund', rhythm: _periodic),
        const DocumentTag(tag: 'utilities', rhythm: _periodic),
        const DocumentTag(tag: 'insurance_premium', rhythm: _oneOff),
        const DocumentTag(tag: 'quit_rent', rhythm: _oneOff),
      ]);
      expect(naturalFolderKey(doc), 'maintenance,sinking_fund,utilities');
    });

    test('same periodic core, different one-off riders -> same key', () {
      final feb = _doc('feb', [
        const DocumentTag(tag: 'maintenance', rhythm: _periodic),
        const DocumentTag(tag: 'sinking_fund', rhythm: _periodic),
        const DocumentTag(tag: 'utilities', rhythm: _periodic),
        const DocumentTag(tag: 'insurance_premium', rhythm: _oneOff),
      ]);
      final march = _doc('march', [
        const DocumentTag(tag: 'maintenance', rhythm: _periodic),
        const DocumentTag(tag: 'sinking_fund', rhythm: _periodic),
        const DocumentTag(tag: 'utilities', rhythm: _periodic),
      ]);
      expect(naturalFolderKey(feb), naturalFolderKey(march));
    });

    test('ad hoc rider does not change the key', () {
      final withPest = _doc('bundle', [
        const DocumentTag(tag: 'maintenance', rhythm: _periodic),
        const DocumentTag(tag: 'sinking_fund', rhythm: _periodic),
        const DocumentTag(tag: 'utilities', rhythm: _periodic),
        const DocumentTag(tag: 'pest_control', rhythm: _adHoc),
      ]);
      expect(naturalFolderKey(withPest), 'maintenance,sinking_fund,utilities');
    });

    test('two periodic tags with no one-off rider forms their own folder', () {
      final doc = _doc('guard', [
        const DocumentTag(tag: 'security_fee', rhythm: _periodic),
        const DocumentTag(tag: 'rent_collection', rhythm: _periodic),
      ]);
      expect(naturalFolderKey(doc), 'rent_collection,security_fee');
    });

    test('no periodic tags -> filed by the full one-off tag set', () {
      final doc = _doc('fire', [const DocumentTag(tag: 'insurance_premium', rhythm: _oneOff)]);
      expect(naturalFolderKey(doc), 'insurance_premium');
    });

    test('a lone ad hoc tag forms its own folder', () {
      final doc = _doc('plumbing', [const DocumentTag(tag: 'upkeep', rhythm: _adHoc)]);
      expect(naturalFolderKey(doc), 'upkeep');
    });

    test('no tags at all -> the untagged sentinel', () {
      expect(naturalFolderKey(_doc('unknown', const [])), untaggedFolderKey);
    });

    test('a loan document gets its own Loan folder, not Expenses', () {
      final loanDoc = _doc('loan1', const [], category: 'loan');
      expect(naturalFolderKey(loanDoc), loanFolderKey);
      expect(proposedFolderName(loanFolderKey), 'Loan');
    });
  });

  group('clusterIntoFolders', () {
    test('groups by natural key and is independent of input order', () {
      final feb = _doc('feb', [const DocumentTag(tag: 'maintenance', rhythm: _periodic)]);
      final march = _doc('march', [const DocumentTag(tag: 'maintenance', rhythm: _periodic)]);
      final fire = _doc('fire', [const DocumentTag(tag: 'insurance_premium', rhythm: _oneOff)]);

      final forward = clusterIntoFolders([feb, march, fire]);
      final shuffled = clusterIntoFolders([fire, march, feb]);

      expect(forward.keys.toSet(), {'maintenance', 'insurance_premium'});
      expect(forward['maintenance']!.map((d) => d.docId).toSet(), {'feb', 'march'});
      expect(shuffled.keys.toSet(), forward.keys.toSet());
      expect(shuffled['maintenance']!.map((d) => d.docId).toSet(),
          forward['maintenance']!.map((d) => d.docId).toSet());
    });

    test('a manual move overrides the natural key', () {
      final doc = _doc('feb', [const DocumentTag(tag: 'maintenance', rhythm: _periodic)]);
      final clusters = clusterIntoFolders([doc], manualMoves: {'feb': 'insurance_premium'});
      expect(clusters.keys, ['insurance_premium']);
      expect(clusters['insurance_premium']!.single.docId, 'feb');
    });
  });

  group('folder naming', () {
    test('proposedFolderName joins the periodic tag labels', () {
      expect(proposedFolderName('maintenance,sinking_fund,utilities'),
          'Maintenance fees + Sinking fund + Utilities');
    });

    test('proposedFolderName for the untagged sentinel is "Expenses"', () {
      expect(proposedFolderName(untaggedFolderKey), 'Expenses');
    });

    test('folderDisplayName prefers the landlord override', () {
      expect(
        folderDisplayName('maintenance', {'maintenance': 'Strata bills'}),
        'Strata bills',
      );
      expect(folderDisplayName('maintenance', const {}), 'Maintenance fees');
    });
  });

  group('documentPeriod', () {
    test('bundled expenses document uses the latest line period', () {
      final doc = _docWithFacts('bundle', {
        'expense_lines': [
          {'subtype': 'maintenance', 'period_year': 2025, 'date': '2025-01-15'},
          {'subtype': 'quit_rent', 'period_year': 2025, 'date': '2025-06-01'},
        ],
      });
      expect(documentPeriod(doc), (year: 2025, month: 6));
    });

    test('typed tax document with only period_year has no month', () {
      final doc = _docWithFacts('tax', {'subtype': 'quit_rent', 'period_year': 2025});
      expect(documentPeriod(doc), (year: 2025, month: null));
    });

    test('typed lease document reads lease_start', () {
      final doc = _docWithFacts('lease', {'lease_start': '2025-09-01'});
      expect(documentPeriod(doc), (year: 2025, month: 9));
    });

    test('falls back to uploadedAt when no period field parses', () {
      final doc = _docWithFacts('none', null);
      expect(documentPeriod(doc), (year: 2026, month: 6));
    });
  });
}
