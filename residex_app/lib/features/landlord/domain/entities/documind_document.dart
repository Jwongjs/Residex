/// One derived sub-category tag (design spec §9). Computed by the backend
/// at read time from extracted_facts — never hand-entered, never stored.
class DocumentTag {
  final String tag;

  /// 'periodic' | 'one_off' | 'ad_hoc' — drives folder clustering
  /// (see document_folders.dart). Periodic tags define a folder's identity;
  /// one_off and ad_hoc tags ride along and never split one.
  final String rhythm;

  const DocumentTag({required this.tag, required this.rhythm});
}

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

  /// Structured facts captured by backend fact extraction at ingest;
  /// null when extraction produced nothing.
  final Map<String, dynamic>? extractedFacts;

  /// Maps an extractedFacts key to the 0-based PDF page it was read from;
  /// null/missing for documents ingested before pages were located.
  final Map<String, dynamic>? factPages;

  /// Extractor's self-reported confidence (0.0-1.0).
  final double? factsConfidence;

  /// Derived sub-category tags (design spec §9); empty when the document's
  /// category/extracted facts carry no tag vocabulary.
  final List<DocumentTag> tags;

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
    this.extractedFacts,
    this.factPages,
    this.factsConfidence,
    this.tags = const [],
  });

  /// True when ingest extraction captured nothing for this document — a
  /// silent miss (weak local model / unreadable layout) the user should be
  /// able to re-check, rather than mistaking it for a document that simply
  /// has no facts. Mirrors the backend's derived facts_status.
  bool get needsFactsReview =>
      extractedFacts == null || extractedFacts!.isEmpty;
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

  /// Unit the cited chunk belongs to; null = property-wide source.
  final String? unitId;

  /// Denormalized unit label captured at ingest (display fallback).
  final String? unitLabel;

  /// 'excerpt' (a retrieved page) | 'extracted_facts' (values parsed at
  /// upload). Facts answer questions no retrieved page states, so citing a
  /// page for them would send the landlord somewhere the value is not.
  final String source;

  /// True when this citation stands for the document's parsed details rather
  /// than one of its pages.
  bool get isExtractedFacts => source == 'extracted_facts';

  Citation({
    required this.docId,
    required this.filename,
    required this.category,
    this.page,
    required this.snippet,
    required this.score,
    this.unitId,
    this.unitLabel,
    this.source = 'excerpt',
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
  final String? sessionId;
  final int conversationTurn;
  final List<String> predictedCategories;
  final String? actionReason;

  DocuMindAnswer({
    required this.answer,
    required this.confidence,
    required this.citations,
    required this.propertyName,
    this.searchedCategories = const [],
    this.categoryFilterMode = 'all',
    this.sessionId,
    this.conversationTurn = 1,
    this.predictedCategories = const [],
    this.actionReason,
  });
}