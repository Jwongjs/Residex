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
    // The options themselves render as tappable quick-reply chips under the
    // bubble (buildDocuMindQuickReplies) — the text only points at them.
    if (answer.needsUnitClarification && answer.unitOptions.isNotEmpty) {
      responseText += '\n\nTap a unit below, or All units to search across all of them.';
    } else {
      final options = answer.clarificationOptions.isNotEmpty
          ? answer.clarificationOptions
          : answer.predictedCategories;
      if (options.isNotEmpty) {
        responseText +=
            '\n\nTap Confirm to proceed, Cancel to dismiss, or pick a category below.';
      }
    }
  }

  return _appendSearchedCategories(responseText, answer, categoryLabelResolver);
}

/// Tappable quick-reply texts for a checkpoint answer. Each entry is sent
/// verbatim as a user message, so every label must round-trip through
/// [mapDocuMindUserAction]: unit labels match exactly, "All units" hits the
/// `all` sentinel, and Confirm/Cancel/category names match case-insensitively.
List<String> buildDocuMindQuickReplies(DocuMindAnswer answer) {
  if (!answer.userActionRequired) return const [];

  if (answer.needsUnitClarification && answer.unitOptions.isNotEmpty) {
    return [
      for (final option in answer.unitOptions)
        if (option.unitId != 'all') option.unitLabel,
      'All units',
    ];
  }

  final options = answer.clarificationOptions.isNotEmpty
      ? answer.clarificationOptions
      : answer.predictedCategories;
  if (options.isEmpty) return const [];
  return [
    'Confirm',
    ...options.map(_capitalize),
    'Cancel',
  ];
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

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