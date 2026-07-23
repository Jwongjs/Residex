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
