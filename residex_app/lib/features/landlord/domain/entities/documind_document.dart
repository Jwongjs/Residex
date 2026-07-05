/// Domain entity for DocuMind document metadata
class DocuMindDocument {
  final String docId;
  final String landlordId;
  final String propertyId;
  final String category;
  final String filename;
  final int chunksIndexed;
  final DateTime uploadedAt;

  /// Unit this document is scoped to; null means property-wide.
  final String? unitId;

  /// Denormalized unit label for display (may go stale if the unit is
  /// renamed/deleted — accepted trade-off).
  final String? unitLabel;

  DocuMindDocument({
    required this.docId,
    required this.landlordId,
    required this.propertyId,
    required this.category,
    required this.filename,
    required this.chunksIndexed,
    required this.uploadedAt,
    this.unitId,
    this.unitLabel,
  });
}

// ========== Q&A ENTITIES ==========

///Citation entity for Q&A responses
class Citation {
  final String docId;
  final String filename;
  final String category;
  final int? page;
  final String snippet;
  final double score;

  Citation({
    required this.docId,
    required this.filename,
    required this.category,
    this.page,
    required this.snippet,
    required this.score,
  });
}

///Answer entity for Q&A responses
class DocuMindAnswer {
  final String answer;
  final double confidence;
  final List<Citation> citations;
  final String propertyName;
  final List<String> searchedCategories;
  final String categoryFilterMode;
  final bool needsCategoryClarification;
  final String? clarificationPrompt;
  final List<String> clarificationOptions;
  final String? sessionId;
  final int conversationTurn;
  final bool userActionRequired;
  final List<String> predictedCategories;
  final String? actionReason;

  DocuMindAnswer({
    required this.answer,
    required this.confidence,
    required this.citations,
    required this.propertyName,
    this.searchedCategories = const [],
    this.categoryFilterMode = 'all',
    this.needsCategoryClarification = false,
    this.clarificationPrompt,
    this.clarificationOptions = const [],
    this.sessionId,
    this.conversationTurn = 1,
    this.userActionRequired = false,
    this.predictedCategories = const [],
    this.actionReason,
  });
}