import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/documind_document.dart';
import 'documind_provider.dart';
import 'finance_logic.dart' show monthAbbrev;

/// One upcoming lease/policy end date for the dashboard tile.
class ExpiryEntry {
  final String docId;
  final String propertyId;
  final String? unitId;
  final String? unitLabel;
  final String category; // lease | insurance | expenses
  final String filename;
  final String kind; // 'Tenancy ends' | 'Policy expires'
  final DateTime date;

  ExpiryEntry({
    required this.docId,
    required this.propertyId,
    this.unitId,
    this.unitLabel,
    required this.category,
    required this.filename,
    required this.kind,
    required this.date,
  });
}

const Map<String, String> _dateKeyByCategory = {
  'lease': 'lease_end',
  'insurance': 'policy_end',
  // Combined expense statements carry the insurance policy period when the
  // extractor found a premium line; docs without policy_end fold to nothing.
  'expenses': 'policy_end',
};

const Map<String, String> _kindByCategory = {
  'lease': 'Tenancy ends',
  'insurance': 'Policy expires',
  'expenses': 'Policy expires',
};

/// Pure fold: every lease/policy end within the next [windowDays], soonest
/// first. Most recently uploaded document wins per (property, unit,
/// category) — a re-uploaded lease supersedes the old one's dates.
/// Malformed dates are skipped, never thrown.
List<ExpiryEntry> foldUpcomingExpiries(
  List<DocuMindDocument> docs,
  DateTime today, {
  int windowDays = 90,
}) {
  final newestByScope = <String, DocuMindDocument>{};
  for (final doc in docs) {
    if (!_dateKeyByCategory.containsKey(doc.category)) continue;
    final key = '${doc.propertyId}|${doc.unitId ?? ''}|${doc.category}';
    final existing = newestByScope[key];
    if (existing == null || doc.uploadedAt.isAfter(existing.uploadedAt)) {
      newestByScope[key] = doc;
    }
  }

  final startOfToday = DateTime(today.year, today.month, today.day);
  final horizon = startOfToday.add(Duration(days: windowDays));
  final entries = <ExpiryEntry>[];
  for (final doc in newestByScope.values) {
    final raw = doc.extractedFacts?[_dateKeyByCategory[doc.category]];
    if (raw is! String) continue;
    final date = DateTime.tryParse(raw);
    if (date == null) continue;
    if (date.isBefore(startOfToday) || date.isAfter(horizon)) continue;
    entries.add(ExpiryEntry(
      docId: doc.docId,
      propertyId: doc.propertyId,
      unitId: doc.unitId,
      unitLabel: doc.unitLabel,
      category: doc.category,
      filename: doc.filename,
      kind: _kindByCategory[doc.category]!,
      date: date,
    ));
  }
  entries.sort((a, b) => a.date.compareTo(b.date));
  return entries;
}

int daysUntil(DateTime date, DateTime today) =>
    DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

String formatExpiryDate(DateTime date) =>
    '${date.day} ${monthAbbrev[date.month - 1]} ${date.year}';

/// Landlord-wide upcoming expiries (lease + insurance), next 90 days.
final upcomingExpiriesProvider = FutureProvider<List<ExpiryEntry>>((ref) async {
  final landlordId = ref.watch(currentLandlordIdProvider);
  final useCase = ref.watch(listDocumentsUseCaseProvider);
  final docs = await useCase(landlordId: landlordId);
  return foldUpcomingExpiries(docs, DateTime.now());
});
