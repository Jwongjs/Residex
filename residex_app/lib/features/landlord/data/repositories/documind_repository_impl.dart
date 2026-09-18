import 'dart:io';
import '../../domain/entities/documind_document.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/repositories/documind_repository.dart';
import '../datasources/documind_remote_datasource.dart';

/// Implementation of DocuMind repository
class DocuMindRepositoryImpl implements DocuMindRepository {
  final DocuMindRemoteDataSource remoteDataSource;

  DocuMindRepositoryImpl({required this.remoteDataSource});

  @override
  Future<DocuMindDocument> uploadDocument({
    required String propertyId,
    required String category,
    required File file,
    String? unitId,
    String? unitLabel,
    void Function(String stage)? onProgress,
  }) async {
    print('🔵 Repository: Upload document');
    print('   - Property: $propertyId');
    print('   - Category: $category');

    try {
      final model = await remoteDataSource.uploadDocument(
        propertyId: propertyId,
        category: category,
        file: file,
        unitId: unitId,
        unitLabel: unitLabel,
        onProgress: onProgress,
      );
      print('✅ Repository: Upload successful');
      return model.toEntity();
    } catch (e) {
      print('❌ Repository: Upload failed: $e');
      rethrow;
    }
  }

  @override
  Future<DocuMindAnswer> askQuestion({
    required String propertyId,
    required String question,
    int topK = 4,
    List<String>? categories,
    String? unitId,
    String? sessionId,
    int conversationTurn = 1,
  }) async {
    print('🔵 Repository: Ask question');
    print('   - Property: $propertyId');
    print('   - Question: $question');

    try {
      final model = await remoteDataSource.askQuestion(
        propertyId: propertyId,
        question: question,
        topK: topK,
        categories: categories,
        unitId: unitId,
        sessionId: sessionId,
        conversationTurn: conversationTurn,
      );
      print('✅ Repository: Ask successful');
      return model.toEntity();
    } catch (e) {
      print('❌ Repository: Ask failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<DocuMindDocument>> listDocuments({
    String? propertyId,
    String? unitId,
  }) async {
    print('🔵 Repository: List documents');
    print('   - Property: ${propertyId ?? "ALL"}');

    try {
      final models = await remoteDataSource.listDocuments(
        propertyId: propertyId,
        unitId: unitId,
      );
      print('✅ Repository: List successful (${models.length} documents)');
      return models.map((model) => model.toEntity()).toList();
    } catch (e) {
      print('❌ Repository: List failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDocument({
    required String propertyId,
    required String docId,
  }) async {
    print('🔵 Repository: Delete document');
    print('   - Property: $propertyId');
    print('   - Doc ID: $docId');

    try {
      await remoteDataSource.deleteDocument(
        propertyId: propertyId,
        docId: docId,
      );
      print('✅ Repository: Document deleted successfully');
    } catch (e) {
      print('❌ Repository: Delete failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDocumentsForProperty({
    required String propertyId,
  }) async {
    print('🔵 Repository: Delete all documents for property $propertyId');

    try {
      await remoteDataSource.deleteDocumentsForProperty(
        propertyId: propertyId,
      );
      print('✅ Repository: Property documents deleted');
    } catch (e) {
      print('❌ Repository: Bulk delete failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> unassignUnitDocuments({
    required String propertyId,
    required String unitId,
  }) async {
    print('🔵 Repository: Unassign unit documents for unit $unitId');

    try {
      await remoteDataSource.unassignUnitDocuments(
        propertyId: propertyId,
        unitId: unitId,
      );
      print('✅ Repository: Unit documents unassigned');
    } catch (e) {
      print('❌ Repository: Unassign failed: $e');
      rethrow;
    }
  }

  @override
  Future<String> getDocumentViewUrl({
    required String propertyId,
    required String docId,
  }) async {
    return await remoteDataSource.getDocumentViewUrl(
      propertyId: propertyId,
      docId: docId,
    );
  }

  @override
  Future<FinanceSummary> getFinanceSummary({
    required int year,
  }) {
    return remoteDataSource.getFinanceSummary(year: year);
  }
}
