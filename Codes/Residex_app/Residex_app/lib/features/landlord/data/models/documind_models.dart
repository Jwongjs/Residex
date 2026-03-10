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

  DocuMindAnswerModel({
    required this.answer,
    required this.confidence,
    required this.citations,
    required this.propertyName,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'confidence': confidence,
      'citations': citations.map((c) => c.toJson()).toList(),
      'property_name': propertyName,
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
    );
  }
}