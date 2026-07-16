import 'dart:io';
import '../entities/documind_document.dart';
import '../entities/finance_summary.dart';

/// Abstract interface for DocuMind operations
/// 
/// Defines WHAT operations exist (not HOW they're implemented)
abstract class DocuMindRepository {
  /// Upload a PDF document to backend.
  /// unitId/unitLabel scope the document to a unit; omit for property-wide.
  Future<DocuMindDocument> uploadDocument({
    required String landlordId,
    required String propertyId,
    required String category,
    required File file,
    String? unitId,
    String? unitLabel,
  });

  /// Ask a question about documents.
  /// unitId filters retrieval to that unit's docs plus property-wide docs.
  Future<DocuMindAnswer> askQuestion({
    required String landlordId,
    required String propertyId,
    required String question,
    int topK = 4,
    List<String>? categories,
    String? unitId,
    String? sessionId,
    int conversationTurn = 1,
    String? userAction,
  });

  /// List documents for a property.
  /// unitId filters to that unit's docs plus property-wide docs.
  Future<List<DocuMindDocument>> listDocuments({
    required String landlordId,
    String? propertyId,
    String? unitId,
  });

  /// Delete a document
  Future<void> deleteDocument({
    required String landlordId,
    required String propertyId,
    required String docId,
  });

  /// Delete ALL documents for a property (part of the property-delete cascade)
  Future<void> deleteDocumentsForProperty({
    required String landlordId,
    required String propertyId,
  });

  /// Convert one unit's documents to property-wide (before unit deletion)
  Future<void> unassignUnitDocuments({
    required String landlordId,
    required String propertyId,
    required String unitId,
  });

  /// Get a short-lived signed URL to view a document's original PDF
  Future<String> getDocumentViewUrl({
    required String landlordId,
    required String propertyId,
    required String docId,
  });

  /// Deterministic finance summary for one landlord and calendar year.
  Future<FinanceSummary> getFinanceSummary({
    required String landlordId,
    required int year,
  });
}