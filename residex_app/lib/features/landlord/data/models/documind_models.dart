import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/documind_document.dart';

/// Data Transfer Object for DocuMind documents
class DocuMindDocumentModel extends DocuMindDocument {
  DocuMindDocumentModel({
    required super.docId,
    required super.landlordId,
    required super.propertyId,
    required super.category,
    required super.filename,
    required super.chunksIndexed,
    required super.uploadedAt,
    super.unitId,
    super.unitLabel,
  });

  /// Create from Firestore document
  factory DocuMindDocumentModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DocuMindDocumentModel(
      docId: doc.id,
      landlordId: data['landlord_id'] as String? ?? '',
      propertyId: data['property_id'] as String? ?? '',
      category: data['category'] as String? ?? 'other',
      filename: data['filename'] as String? ?? 'Unknown',
      chunksIndexed: _parseInt(data['chunks_indexed']),
      uploadedAt: _parseTimestamp(data['uploaded_at']),
      unitId: data['unit_id'] as String?,
      unitLabel: data['unit_label'] as String?,
    );
  }

  /// Create from JSON (backend response)
  factory DocuMindDocumentModel.fromJson(Map<String, dynamic> json) {
    return DocuMindDocumentModel(
      docId: json['doc_id'] as String? ?? '',
      landlordId: json['landlord_id'] as String? ?? '',
      propertyId: json['property_id'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      filename: json['filename'] as String? ?? 'Unknown',
      chunksIndexed: _parseInt(json['chunks_indexed']),
      uploadedAt: _parseTimestamp(json['uploaded_at']),
      unitId: json['unit_id'] as String?,
      unitLabel: json['unit_label'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'doc_id': docId,
      'landlord_id': landlordId,
      'property_id': propertyId,
      'category': category,
      'filename': filename,
      'chunks_indexed': chunksIndexed,
      'uploaded_at': Timestamp.fromDate(uploadedAt),
      'unit_id': unitId,
      'unit_label': unitLabel,
    };
  }

  /// ✅ ADDED: Convert model to domain entity
  DocuMindDocument toEntity() {
    return DocuMindDocument(
      docId: docId,
      landlordId: landlordId,
      propertyId: propertyId,
      category: category,
      filename: filename,
      chunksIndexed: chunksIndexed,
      uploadedAt: uploadedAt,
      unitId: unitId,
      unitLabel: unitLabel,
    );
  }

  // ========== HELPER METHODS FOR SAFE PARSING ==========

  /// Safely parse int from dynamic value
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Safely parse Firestore Timestamp
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

// ========== ANSWER MODEL ==========

/// ✅ ADDED: Citation model for Q&A responses
class CitationModel {
  final String docId;
  final String filename;
  final String category;
  final int? page;
  final String snippet;
  final double score;

  CitationModel({
    required this.docId,
    required this.filename,
    required this.category,
    this.page,
    required this.snippet,
    required this.score,
  });

  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      docId: json['doc_id'] as String? ?? '',
      filename: json['filename'] as String? ?? 'Unknown',
      category: json['category'] as String? ?? 'other',
      page: json['page'] as int?,
      snippet: json['snippet'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doc_id': docId,
      'filename': filename,
      'category': category,
      'page': page,
      'snippet': snippet,
      'score': score,
    };
  }
}

/// ✅ ADDED: Answer model for Q&A responses
class DocuMindAnswerModel {
  final String answer;
  final double confidence;
  final List<CitationModel> citations;
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

  DocuMindAnswerModel({
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

  factory DocuMindAnswerModel.fromJson(Map<String, dynamic> json) {
    final citationsJson = json['citations'] as List<dynamic>? ?? [];
    final citations = citationsJson
        .map((c) => CitationModel.fromJson(c as Map<String, dynamic>))
        .toList();

    return DocuMindAnswerModel(
      answer: json['answer'] as String? ?? 'No answer available',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      citations: citations,
      propertyName: json['property_name'] as String? ?? 'Unknown Property',
      searchedCategories: (json['searched_categories'] as List<dynamic>? ?? [])
          .map((category) => category.toString())
          .toList(),
      categoryFilterMode: json['category_filter_mode'] as String? ?? 'all',
        needsCategoryClarification: json['needs_category_clarification'] as bool? ?? false,
        clarificationPrompt: json['clarification_prompt'] as String?,
        clarificationOptions: (json['clarification_options'] as List<dynamic>? ?? [])
          .map((option) => option.toString())
          .toList(),
        sessionId: json['session_id'] as String?,
        conversationTurn: json['conversation_turn'] as int? ?? 1,
        userActionRequired: json['user_action_required'] as bool? ?? false,
        predictedCategories: (json['predicted_categories'] as List<dynamic>? ?? [])
          .map((category) => category.toString())
          .toList(),
        actionReason: json['action_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'confidence': confidence,
      'citations': citations.map((c) => c.toJson()).toList(),
      'property_name': propertyName,
      'searched_categories': searchedCategories,
      'category_filter_mode': categoryFilterMode,
      'needs_category_clarification': needsCategoryClarification,
      'clarification_prompt': clarificationPrompt,
      'clarification_options': clarificationOptions,
      'session_id': sessionId,
      'conversation_turn': conversationTurn,
      'user_action_required': userActionRequired,
      'predicted_categories': predictedCategories,
      'action_reason': actionReason,
    };
  }

  /// Convert to domain entity
  DocuMindAnswer toEntity() {
    return DocuMindAnswer(
      answer: answer,
      confidence: confidence,
      citations: citations.map((c) => Citation(
        docId: c.docId,
        filename: c.filename,
        category: c.category,
        page: c.page,
        snippet: c.snippet,
        score: c.score,
      )).toList(),
      propertyName: propertyName,
      searchedCategories: searchedCategories,
      categoryFilterMode: categoryFilterMode,
      needsCategoryClarification: needsCategoryClarification,
      clarificationPrompt: clarificationPrompt,
      clarificationOptions: clarificationOptions,
      sessionId: sessionId,
      conversationTurn: conversationTurn,
      userActionRequired: userActionRequired,
      predictedCategories: predictedCategories,
      actionReason: actionReason,
    );
  }
}