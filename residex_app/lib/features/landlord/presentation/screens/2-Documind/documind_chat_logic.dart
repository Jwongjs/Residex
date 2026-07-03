import '../../../domain/entities/documind_document.dart';

bool _hasSourcesSection(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return false;
  }

  return RegExp(r'(^|\n)\s*(📚\s*)?sources\s*:', caseSensitive: false)
      .hasMatch(normalized);
}

String? mapDocuMindUserAction({
  required bool awaitingUserAction,
  required String messageText,
  required List<String> categories,
}) {
  if (!awaitingUserAction) {
    return null;
  }

  final normalized = messageText.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized == 'confirm' || normalized.contains('confirm')) {
    return 'confirm';
  }

  if (normalized == 'cancel' || normalized.contains('cancel')) {
    return 'cancel';
  }

  for (final category in categories) {
    if (normalized == category || normalized.contains(category)) {
      return 'override:$category';
    }
  }

  return null;
}

String buildDocuMindAssistantText({
  required DocuMindAnswer answer,
  required String Function(String category) categoryLabelResolver,
}) {
  var responseText = answer.answer;

  if (answer.userActionRequired) {
    final options = answer.clarificationOptions.isNotEmpty
        ? answer.clarificationOptions
        : answer.predictedCategories;
    if (options.isNotEmpty) {
      responseText += '\n\n✅ Reply with `confirm` or `cancel`, or type a category:';
      responseText += '\n${options.map((option) => '• $option').join('\n')}';
    }
  }

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
      case 'clarification_selected':
        modeLabel = 'clarified';
        break;
      default:
        modeLabel = 'all-categories';
    }

    responseText += '\n\n🏷️ Categories: $displayCategories ($modeLabel)';
  }

  if (answer.citations.isNotEmpty && !_hasSourcesSection(responseText)) {
    responseText += '\n\n📚 Sources:\n';
    for (final cite in answer.citations.take(3)) {
      responseText += '• [${cite.category.toUpperCase()}] ${cite.filename} (page ${cite.page ?? 'N/A'})\n';
    }
  }

  return responseText;
}