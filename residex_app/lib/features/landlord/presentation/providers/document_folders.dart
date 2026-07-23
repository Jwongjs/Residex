import '../../domain/entities/documind_document.dart';
import '../widgets/common/document_categories.dart';

/// Sentinel folder key for documents with no tags at all — the "plain
/// Expenses folder" spec §9 promises for anything the tag vocabulary can't
/// place. Never produced by a real tag combination (a real key is always a
/// non-empty comma-joined tag list).
const String untaggedFolderKey = '';

/// A document's folder identity (spec §9): the periodic tag subset when
/// non-empty (one-off and ad-hoc tags ride along, never appearing in the
/// key); otherwise the full tag set; otherwise the untagged sentinel.
/// Ignores [DocuMindDocument.docId] entirely — manual moves are applied by
/// the caller ([clusterIntoFolders]), not here.
String naturalFolderKey(DocuMindDocument doc) {
  final periodic = doc.tags.where((t) => t.rhythm == 'periodic').map((t) => t.tag).toSet();
  if (periodic.isNotEmpty) {
    return (periodic.toList()..sort()).join(',');
  }
  final all = doc.tags.map((t) => t.tag).toSet();
  if (all.isNotEmpty) {
    return (all.toList()..sort()).join(',');
  }
  return untaggedFolderKey;
}

/// Groups documents into folders. [manualMoves] (docId -> folderKey) is the
/// sticky escape hatch (spec §9) and takes precedence over the natural key.
/// Recomputed over the whole set every call — upload order never changes
/// the outcome, and re-clustering never moves a manually-placed document
/// back on its own.
Map<String, List<DocuMindDocument>> clusterIntoFolders(
  List<DocuMindDocument> docs, {
  Map<String, String> manualMoves = const {},
}) {
  final result = <String, List<DocuMindDocument>>{};
  for (final doc in docs) {
    final key = manualMoves[doc.docId] ?? naturalFolderKey(doc);
    result.putIfAbsent(key, () => []).add(doc);
  }
  return result;
}

/// App-proposed folder name from its repeating tags (spec §9's "Rename" —
/// this is only ever the default; [folderDisplayName] applies the
/// landlord's override when one exists).
String proposedFolderName(String folderKey) {
  if (folderKey == untaggedFolderKey) return 'Expenses';
  return folderKey.split(',').map(tagLabel).join(' + ');
}

/// Display name for a folder: the landlord's override if set, else the
/// proposed name.
String folderDisplayName(String folderKey, Map<String, String> folderNames) {
  return folderNames[folderKey] ?? proposedFolderName(folderKey);
}

({int year, int? month})? _parsePeriod(dynamic dateLike, dynamic periodYear) {
  if (dateLike is String && dateLike.length >= 7) {
    final year = int.tryParse(dateLike.substring(0, 4));
    final month = int.tryParse(dateLike.substring(5, 7));
    if (year != null && year > 1990 && year < 2200) {
      return (year: year, month: (month != null && month >= 1 && month <= 12) ? month : null);
    }
  }
  if (periodYear is int && periodYear > 1990 && periodYear < 2200) {
    return (year: periodYear, month: null);
  }
  return null;
}

int _periodOrdinal(({int year, int? month}) p) => p.year * 12 + (p.month ?? 0);

/// The period a document covers, for the folder view's reverse-chronological
/// ordering and year/month separators (spec §9) — never the upload date. A
/// bundled 'expenses' document takes its latest line's period (it may cover
/// several). Falls back to [DocuMindDocument.uploadedAt] when nothing
/// parses, consistent with the rest of the app's defensive-fallback pattern.
({int year, int? month}) documentPeriod(DocuMindDocument doc) {
  final facts = doc.extractedFacts;
  if (facts != null) {
    final lines = facts['expense_lines'];
    if (lines is List) {
      ({int year, int? month})? latest;
      for (final line in lines) {
        if (line is! Map) continue;
        final p = _parsePeriod(line['date'], line['period_year']);
        if (p != null && (latest == null || _periodOrdinal(p) > _periodOrdinal(latest))) {
          latest = p;
        }
      }
      if (latest != null) return latest;
    }
    final direct = _parsePeriod(
      facts['period_month'] ?? facts['lease_start'] ?? facts['service_date'] ??
          facts['period_start'] ?? facts['policy_start'] ?? facts['invoice_date'],
      facts['period_year'],
    );
    if (direct != null) return direct;
  }
  return (year: doc.uploadedAt.year, month: doc.uploadedAt.month);
}
