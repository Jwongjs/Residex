import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider is legacy in Riverpod 3.x
import 'dart:io';
import '../../data/datasources/documind_remote_datasource.dart';
import '../../data/repositories/documind_repository_impl.dart';
import '../../domain/entities/documind_document.dart';
import '../../domain/repositories/documind_repository.dart';
import '../../domain/usecases/upload_document.dart';
import '../../domain/usecases/ask_documind_question.dart';
import '../../domain/usecases/list_documents.dart';
import '../../domain/usecases/get_document_view_url.dart';
import '../../../shared/presentation/providers/auth_providers.dart';
import 'finance_providers.dart';

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

final getDocumentViewUrlUseCaseProvider = Provider<GetDocumentViewUrl>((ref) {
  final repository = ref.watch(documindRepositoryProvider);
  return GetDocumentViewUrl(repository);
});

// ========== STATE PROVIDERS ==========

/// Current landlord ID (from auth)
final currentLandlordIdProvider = Provider<String>((ref) {
  final currentUser = ref.watch(firebaseAuthStateProvider).value;
  return currentUser?.uid ?? 'guest';
});

/// Cross-tab navigation target: set a propertyId here before switching to
/// the Documind tab and the chat opens on that property (expiry-tile
/// tap-through). Consumed and cleared by DocuMindScreen.
final documindNavTargetProvider = StateProvider<String?>((ref) => null);

/// Document list provider (auto-refresh on property change). The Docs tab
/// is a category file manager and always shows the whole property.
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

/// Upload document action (manual trigger).
/// unitId/unitLabel scope the document to a unit; omit for property-wide.
final uploadDocumentActionProvider = Provider<Future<DocuMindDocument> Function({
  required String propertyId,
  required String category,
  required File file,
  String? unitId,
  String? unitLabel,
})>((ref) {
  return ({
    required String propertyId,
    required String category,
    required File file,
    String? unitId,
    String? unitLabel,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final useCase = ref.read(uploadDocumentUseCaseProvider);

    final result = await useCase(
      landlordId: landlordId,
      propertyId: propertyId,
      category: category,
      file: file,
      unitId: unitId,
      unitLabel: unitLabel,
    );

    // Invalidate document list to trigger refresh
    ref.invalidate(documindDocumentsProvider(propertyId));

    // Finance figures and year options are folds over the documents.
    ref.invalidate(financeSummaryProvider);
    ref.invalidate(financeYearsProvider);

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

    // No client-side unit scoping: the backend's search router infers the
    // unit from the question and the recent conversation.
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

    // Finance figures and year options are folds over the documents.
    ref.invalidate(financeSummaryProvider);
    ref.invalidate(financeYearsProvider);
  };
});

/// Convert a unit's documents to property-wide before the unit is deleted.
final unassignUnitDocumentsActionProvider = Provider<
    Future<void> Function({
      required String propertyId,
      required String unitId,
    })>((ref) {
  return ({
    required String propertyId,
    required String unitId,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final repository = ref.read(documindRepositoryProvider);

    await repository.unassignUnitDocuments(
      landlordId: landlordId,
      propertyId: propertyId,
      unitId: unitId,
    );

    // Unassigned docs are now property-wide; refresh any doc list.
    ref.invalidate(documindDocumentsProvider(propertyId));
  };
});

final documindGetViewUrlActionProvider = Provider<
  Future<String> Function({
    required String propertyId,
    required String docId,
  })
>((ref) {
  return ({
    required String propertyId,
    required String docId,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final useCase = ref.read(getDocumentViewUrlUseCaseProvider);

    return await useCase(
      landlordId: landlordId,
      propertyId: propertyId,
      docId: docId,
    );
  };
});

/// Save user-reviewed expense lines for an uploaded Expenses document.
final updateExpenseLinesActionProvider = Provider<Future<void> Function({
  required String docId,
  required List<Map<String, dynamic>> lines,
})>((ref) {
  return ({
    required String docId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.updateExpenseLines(
      landlordId: landlordId,
      docId: docId,
      lines: lines,
    );
    // Facts changed: documents, figures and year options are folds over them.
    ref.invalidate(documindDocumentsProvider);
    ref.invalidate(financeSummaryProvider);
    ref.invalidate(financeYearsProvider);
  };
});

/// Mark one month as "no payment received" for a property or unit scope.
final setPaymentExceptionActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required String month,
  String? unitId,
  String? reason,
  String? state,
})>((ref) {
  return ({
    required String propertyId,
    required String month,
    String? unitId,
    String? reason,
    String? state,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.setPaymentException(
      landlordId: landlordId,
      propertyId: propertyId,
      unitId: unitId,
      month: month,
      reason: reason,
      state: state ?? 'outstanding',
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Clear a "no payment received" mark.
final clearPaymentExceptionActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required String month,
  String? unitId,
})>((ref) {
  return ({
    required String propertyId,
    required String month,
    String? unitId,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.clearPaymentException(
      landlordId: landlordId,
      propertyId: propertyId,
      unitId: unitId,
      month: month,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Acknowledge a coverage gap cannot be filled for one (year, category).
final setDocumentUnavailableActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required int year,
  required String category,
})>((ref) {
  return ({
    required String propertyId,
    required int year,
    required String category,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.setDocumentUnavailable(
      landlordId: landlordId, propertyId: propertyId, year: year, category: category,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Clear an 'unavailable' mark.
final clearDocumentUnavailableActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required int year,
  required String category,
})>((ref) {
  return ({
    required String propertyId,
    required int year,
    required String category,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.clearDocumentUnavailable(
      landlordId: landlordId, propertyId: propertyId, year: year, category: category,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Book a written-off month's rent as income in the year it arrived.
final recordRentRecoveryActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required String originalMonth,
  required double amount,
  required int receivedYear,
  String? unitId,
})>((ref) {
  return ({
    required String propertyId,
    required String originalMonth,
    required double amount,
    required int receivedYear,
    String? unitId,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.recordRentRecovery(
      landlordId: landlordId, propertyId: propertyId, unitId: unitId,
      originalMonth: originalMonth, amount: amount, receivedYear: receivedYear,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Remove a recorded rent recovery.
final clearRentRecoveryActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required String originalMonth,
  String? unitId,
})>((ref) {
  return ({
    required String propertyId,
    required String originalMonth,
    String? unitId,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.clearRentRecovery(
      landlordId: landlordId, propertyId: propertyId, unitId: unitId, originalMonth: originalMonth,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Book manually-entered loan figures for a period.
final recordManualLoanEntryActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required int year,
  required String cadence,
  required double interestPaid,
  required double principalPaid,
  int? month,
})>((ref) {
  return ({
    required String propertyId,
    required int year,
    required String cadence,
    required double interestPaid,
    required double principalPaid,
    int? month,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.recordManualLoanEntry(
      landlordId: landlordId, propertyId: propertyId, year: year, cadence: cadence,
      interestPaid: interestPaid, principalPaid: principalPaid, month: month,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// Remove a manual loan entry.
final deleteManualLoanEntryActionProvider = Provider<Future<void> Function({
  required String propertyId,
  required int year,
  int? month,
})>((ref) {
  return ({
    required String propertyId,
    required int year,
    int? month,
  }) async {
    final landlordId = ref.read(currentLandlordIdProvider);
    final dataSource = ref.read(documindRemoteDataSourceProvider);
    await dataSource.deleteManualLoanEntry(
      landlordId: landlordId, propertyId: propertyId, year: year, month: month,
    );
    ref.invalidate(financeSummaryProvider);
  };
});

/// All manual loan entries for one property and year.
final manualLoanEntriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ({String propertyId, int year})>((ref, arg) async {
  final landlordId = ref.read(currentLandlordIdProvider);
  final dataSource = ref.read(documindRemoteDataSourceProvider);
  return dataSource.listManualLoanEntries(
    landlordId: landlordId, propertyId: arg.propertyId, year: arg.year,
  );
});