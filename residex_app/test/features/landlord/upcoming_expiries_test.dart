import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/presentation/providers/upcoming_expiries.dart';

DocuMindDocument _doc({
  required String docId,
  required String category,
  Map<String, dynamic>? facts,
  Map<String, dynamic>? factPages,
  String propertyId = 'p1',
  String? unitId,
  DateTime? uploadedAt,
}) {
  return DocuMindDocument(
    docId: docId, landlordId: 'l1', propertyId: propertyId,
    category: category, filename: '$docId.pdf', chunksIndexed: 1,
    uploadedAt: uploadedAt ?? DateTime(2026, 1, 1),
    unitId: unitId, extractedFacts: facts, factPages: factPages,
  );
}

void main() {
  final today = DateTime(2026, 7, 16);

  test('folds lease and policy end dates within 90 days, soonest first', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'a', category: 'lease', unitId: 'u1',
          facts: {'lease_end': '2026-09-01'}),
      _doc(docId: 'b', category: 'insurance',
          facts: {'policy_end': '2026-08-01'}),
      _doc(docId: 'c', category: 'tax', facts: {'amount': 100.0}),
    ], today);
    expect(entries.map((e) => e.docId), ['b', 'a']);
    expect(entries.first.kind, 'Policy expires');
    expect(daysUntil(entries.first.date, today), 16);
  });

  test('window boundaries: today counts, day 90 counts, 91 and past excluded', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'today', category: 'lease', propertyId: 'pa',
          facts: {'lease_end': '2026-07-16'}),
      _doc(docId: 'day90', category: 'lease', propertyId: 'pb',
          facts: {'lease_end': '2026-10-14'}),
      _doc(docId: 'day91', category: 'lease', propertyId: 'pc',
          facts: {'lease_end': '2026-10-15'}),
      _doc(docId: 'past', category: 'lease', propertyId: 'pd',
          facts: {'lease_end': '2026-07-15'}),
    ], today);
    expect(entries.map((e) => e.docId), ['today', 'day90']);
  });

  test('most recently uploaded doc wins per (property, unit, category)', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'old', category: 'lease', unitId: 'u1',
          facts: {'lease_end': '2026-08-01'}, uploadedAt: DateTime(2026, 1, 1)),
      _doc(docId: 'new', category: 'lease', unitId: 'u1',
          facts: {'lease_end': '2026-09-01'}, uploadedAt: DateTime(2026, 6, 1)),
    ], today);
    expect(entries.single.docId, 'new');
  });

  test('malformed or missing dates are skipped, never crash', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'bad', category: 'lease', facts: {'lease_end': 'soon'}),
      _doc(docId: 'none', category: 'insurance', facts: {'premium': 640.0}),
      _doc(docId: 'null', category: 'lease', facts: null),
    ], today);
    expect(entries, isEmpty);
  });

  test('expenses documents with a policy_end feed the expiry tile', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'exp1', category: 'expenses', facts: {
        'expense_lines': [
          {'subtype': 'insurance_premium', 'amount': 1800.0},
        ],
        'policy_end': '2026-08-15',
      }),
    ], DateTime(2026, 7, 18));
    expect(entries, hasLength(1));
    expect(entries.single.kind, 'Policy expires');
    expect(entries.single.date, DateTime(2026, 8, 15));
  });

  test('a located fact page converts to a 1-based display page', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'a', category: 'lease',
          facts: {'lease_end': '2026-08-01'},
          factPages: {'lease_end': 2}),
    ], today);
    expect(entries.single.page, 3);
  });

  test('an unlocated fact page falls back to null, not a wrong page', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'a', category: 'lease',
          facts: {'lease_end': '2026-08-01'},
          factPages: {'other_key': 0}),
      _doc(docId: 'b', category: 'insurance',
          facts: {'policy_end': '2026-08-01'}),
    ], today);
    expect(entries.every((e) => e.page == null), isTrue);
  });

  test('expenses documents without policy_end are ignored', () {
    final entries = foldUpcomingExpiries([
      _doc(docId: 'exp2', category: 'expenses', facts: {
        'expense_lines': [
          {'subtype': 'maintenance', 'amount': 100.0},
        ],
      }),
    ], DateTime(2026, 7, 18));
    expect(entries, isEmpty);
  });
}
