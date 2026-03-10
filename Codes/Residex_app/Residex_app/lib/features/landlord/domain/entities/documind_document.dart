/// Domain entity for DocuMind document metadata
class DocuMindDocument {
  final String docId;
  final String landlordId;
  final String propertyId;
  final String category;
  final String filename;
  final int chunksIndexed;
  final DateTime uploadedAt;

  DocuMindDocument({
    required this.docId,
    required this.landlordId,
    required this.propertyId,
    required this.category,
    required this.filename,
    required this.chunksIndexed,
    required this.uploadedAt,
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

  DocuMindAnswer({
    required this.answer,
    required this.confidence,
    required this.citations,
    required this.propertyName,
  });
}