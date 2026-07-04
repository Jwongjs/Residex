import '../../../domain/entities/documind_document.dart';

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
      responseText += '\n\nReply with `confirm` or `cancel`, or type a category:';
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

    responseText += '\n\nCategories: $displayCategories ($modeLabel)';
  }

  return responseText;
}