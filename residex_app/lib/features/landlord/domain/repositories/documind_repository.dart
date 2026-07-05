import 'dart:io';
import '../entities/documind_document.dart';

/// Abstract interface for DocuMind operations
/// 
/// Defines WHAT operations exist (not HOW they're implemented)
abstract class DocuMindRepository {
  /// Upload a PDF document to backend
  Future<DocuMindDocument> uploadDocument({
    required String landlordId,
    required String propertyId,
    required String category,
    required File file,
  });

  /// Ask a question about documents
  Future<DocuMindAnswer> askQuestion({
    required String landlordId,
    required String propertyId,
    required String question,
    int topK = 4,
    List<String>? categories,
    String? sessionId,
    int conversationTurn = 1,
    String? userAction,
  });

  /// List documents for a property
  Future<List<DocuMindDocument>> listDocuments({
    required String landlordId,
    String? propertyId,
  });

  /// Delete a document
  Future<void> deleteDocument({
    required String landlordId,
    required String propertyId,
    required String docId,
  });

  /// Get a short-lived signed URL to view a document's original PDF
  Future<String> getDocumentViewUrl({
    required String landlordId,
    required String propertyId,
    required String docId,
  });
}