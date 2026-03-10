import 'dart:io';
import '../../domain/entities/documind_document.dart';
import '../../domain/repositories/documind_repository.dart';
import '../datasources/documind_remote_datasource.dart';

/// Implementation of DocuMind repository
class DocuMindRepositoryImpl implements DocuMindRepository {
  final DocuMindRemoteDataSource remoteDataSource;

  DocuMindRepositoryImpl({required this.remoteDataSource});

  @override
  Future<DocuMindDocument> uploadDocument({
    required String landlordId,
    required String propertyId,
    required String category,
    required File file,
  }) async {
    print('🔵 Repository: Upload document');
    print('   - Landlord: $landlordId');
    print('   - Property: $propertyId');
    print('   - Category: $category');

    try {
      final model = await remoteDataSource.uploadDocument(
        landlordId: landlordId,
        propertyId: propertyId,
        category: category,
        file: file,
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
    required String landlordId,
    required String propertyId,
    required String question,
    int topK = 4,
  }) async {
    print('🔵 Repository: Ask question');
    print('   - Landlord: $landlordId');
    print('   - Property: $propertyId');
    print('   - Question: $question');

    try {
      final model = await remoteDataSource.askQuestion(
        landlordId: landlordId,
        propertyId: propertyId,
        question: question,
        topK: topK,
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
    required String landlordId,
    String? propertyId,
  }) async {
    print('🔵 Repository: List documents');
    print('   - Landlord: $landlordId');
    print('   - Property: ${propertyId ?? "ALL"}');

    try {
      final models = await remoteDataSource.listDocuments(
        landlordId: landlordId,
        propertyId: propertyId,
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
    required String landlordId,
    required String propertyId,
    required String docId,
  }) async {
    print('🔵 Repository: Delete document');
    print('   - Landlord: $landlordId');
    print('   - Property: $propertyId');
    print('   - Doc ID: $docId');

    try {
      await remoteDataSource.deleteDocument(
        landlordId: landlordId,
        propertyId: propertyId,
        docId: docId,
      );
      print('✅ Repository: Document deleted successfully');
    } catch (e) {
      print('❌ Repository: Delete failed: $e');
      rethrow;
    }
  }
}