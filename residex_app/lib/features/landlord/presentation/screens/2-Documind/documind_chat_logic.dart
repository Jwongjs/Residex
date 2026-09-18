import '../../../domain/entities/documind_document.dart';
import '../../../domain/entities/unit.dart';

String buildDocuMindAssistantText({
  required DocuMindAnswer answer,
  required String Function(String category) categoryLabelResolver,
}) {
  return _appendSearchedCategories(answer.answer, answer, categoryLabelResolver);
}

/// The page/source suffix shown beside a citation's filename.
///
/// A fact citation now carries the page that states its value, located at
/// upload, so it says both: where to look, and that the value came from the
/// document's parsed details rather than the page's prose. A fact the locator
/// could not place keeps the bare label — "p.—" reads as a missing page
/// number, not as "we don't know".
String citationSourceSuffix(Citation citation) {
  final page = citation.page;
  if (citation.isExtractedFacts) {
    return page == null ? ' · extracted' : ' · p.$page · extracted';
  }
  return ' · p.${page ?? '—'}';
}

/// Quick-reply labels for the "which unit is this chat about" picker shown
/// before the first question on a multi-unit property.
List<String> buildUnitScopeQuickReplies(List<Unit> units) {
  return [
    for (final unit in units) unit.label,
    'Whole property',
  ];
}

/// Resolves a tapped unit-scope quick-reply back to a unit id, or null for
/// "Whole property" (and any unrecognised label, as a safe fallback).
String? resolveUnitScopeSelection(String label, List<Unit> units) {
  for (final unit in units) {
    if (unit.label == label) return unit.id;
  }
  return null;
}

String _appendSearchedCategories(
  String responseText,
  DocuMindAnswer answer,
  String Function(String category) categoryLabelResolver,
) {
  if (answer.searchedCategories.isNotEmpty) {
    final displayCategories = answer.searchedCategories
        .map((category) => categoryLabelResolver(category))
        .join(', ');

    String modeLabel;
    switch (answer.categoryFilterMode) {
      case 'explicit':
        modeLabel = 'explicit';
        break;
      case 'auto':
        modeLabel = 'auto-detected';
        break;
      default:
        modeLabel = 'all-categories';
    }

    responseText += '\n\nCategories: $displayCategories ($modeLabel)';
  }

  return responseText;
}