import '../../../domain/entities/documind_document.dart';

String? mapDocuMindUserAction({
  required bool awaitingUserAction,
  required String messageText,
  required List<String> categories,
  List<UnitOption> unitOptions = const [],
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

  // A pending unit checkpoint takes over interpretation: match unit labels
  // (returning ids with original casing), then the "all" sentinel. Category
  // overrides are suspended so "lease" can't hijack a unit question.
  if (unitOptions.isNotEmpty) {
    // First pass: exact label match, so "Unit A" can't shadow "Unit A1".
    for (final option in unitOptions) {
      if (option.unitId == 'all') continue;
      if (normalized == option.unitLabel.toLowerCase()) {
        return 'unit:${option.unitId}';
      }
    }
    // Second pass: substring match as a fallback for looser phrasing.
    for (final option in unitOptions) {
      if (option.unitId == 'all') continue;
      if (normalized.contains(option.unitLabel.toLowerCase())) {
        return 'unit:${option.unitId}';
      }
    }
    if (normalized.contains('all')) {
      return 'unit:all';
    }
    return null;
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
    if (answer.needsUnitClarification && answer.unitOptions.isNotEmpty) {
      responseText += '\n\nReply with a unit, or `all units`:';
      responseText +=
          '\n${answer.unitOptions.map((option) => '• ${option.unitLabel}').join('\n')}';
    } else {
      final options = answer.clarificationOptions.isNotEmpty
          ? answer.clarificationOptions
          : answer.predictedCategories;
      if (options.isNotEmpty) {
        responseText += '\n\nReply with `confirm` or `cancel`, or type a category:';
        responseText += '\n${options.map((option) => '• $option').join('\n')}';
      }
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

    responseText += '\n\nCategories: $displayCategories ($modeLabel)';
  }

  return responseText;
}