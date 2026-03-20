import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../data/datasources/documind_remote_datasource.dart';
import '../../data/repositories/documind_repository_impl.dart';
import '../../domain/entities/documind_document.dart';
import '../../domain/repositories/documind_repository.dart';
import '../../domain/usecases/upload_document.dart';
import '../../domain/usecases/ask_documind_question.dart';
import '../../domain/usecases/list_documents.dart';
import '../../../shared/presentation/providers/auth_providers.dart';

// ========== DEPENDENCY INJECTION ==========

/// Data source provider
final documindRemoteDataSourceProvider = Provider<DocuMindRemoteDataSource>((ref) {
  return DocuMindRemoteDataSource();
});

/// Repository provider
final documindRepositoryProvider = Provider<DocuMindRepository>((ref) {
  final dataSource = ref.watch(documindRemoteDataSourceProvider);
  return DocuMindRepositoryImpl(remoteDataSource: dataSource);
});

/// Use case providers
final uploadDocumentUseCaseProvider = Provider<UploadDocument>((ref) {
  final repository = ref.watch(documindRepositoryProvider);
  return UploadDocument(repository);
});

final askDocuMindQuestionUseCaseProvider = Provider<AskDocuMindQuestion>((ref) {
  final repository = ref.watch(documindRepositoryProvider);
  return AskDocuMindQuestion(repository);
});

final listDocumentsUseCaseProvider = Provider<ListDocuments>((ref) {
  final repository = ref.watch(documindRepositoryProvider);
  return ListDocuments(repository);
});

// ========== STATE PROVIDERS ==========

/// Current landlord ID (from auth)
final currentLandlordIdProvider = Provider<String>((ref) {
  final currentUser = ref.watch(firebaseAuthStateProvider).value;
  return currentUser?.uid ?? 'guest';
});

/// Document list provider (auto-refresh on property change)
final documindDocumentsProvider = FutureProvider.family<List<DocuMindDocument>, String>(
  (ref, propertyId) async {
    final landlordId = ref.watch(currentLandlordIdProvider);
    final useCase = ref.watch(listDocumentsUseCaseProvider);

    return await useCase(
      landlordId: landlordId,
      propertyId: propertyId,
    );
  },
);

/// Upload document action (manual trigger)
final uploadDocumentActionProvider = Provider<Future<DocuMindDocument> Function({
  required String propertyId,
  required String category,
  required File file,
})>((ref) {
  return ({
    required String propertyId,
    required String category,
    required File file,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final useCase = ref.read(uploadDocumentUseCaseProvider);

    final result = await useCase(
      landlordId: landlordId,
      propertyId: propertyId,
      category: category,
      file: file,
    );

    // Invalidate document list to trigger refresh
    ref.invalidate(documindDocumentsProvider(propertyId));

    return result;
  };
});

/// Ask question action (manual trigger)
final askDocuMindQuestionActionProvider = Provider<Future<DocuMindAnswer> Function({
  required String propertyId,
  required String question,
  int topK,
  List<String>? categories,
  String? sessionId,
  int conversationTurn,
  String? userAction,
})>((ref) {
  return ({
    required String propertyId,
    required String question,
    int topK = 4,
    List<String>? categories,
    String? sessionId,
    int conversationTurn = 1,
    String? userAction,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final useCase = ref.read(askDocuMindQuestionUseCaseProvider);

    return await useCase(
      landlordId: landlordId,
      propertyId: propertyId,
      question: question,
      topK: topK,
      categories: categories,
      sessionId: sessionId,
      conversationTurn: conversationTurn,
      userAction: userAction,
    );
  };
});

final deleteDocumentActionProvider = Provider<
  Future<void> Function({
    required String propertyId,
    required String docId,
  })
>((ref) {
  return ({
    required String propertyId,
    required String docId,
  }) async {
    print('🔵 Action: Delete document');
    print('   - Property: $propertyId');
    print('   - Doc ID: $docId');

    final landlordId = ref.read(currentLandlordIdProvider);
    final repository = ref.read(documindRepositoryProvider);
    
    await repository.deleteDocument(
      landlordId: landlordId,
      propertyId: propertyId,
      docId: docId,
    );

    print('✅ Action: Document deleted successfully');
    
    // ✅ Invalidate provider to refresh document list
    ref.invalidate(documindDocumentsProvider(propertyId));
  };
});