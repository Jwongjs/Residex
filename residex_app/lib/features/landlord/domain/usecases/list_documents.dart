import '../entities/documind_document.dart';
import '../repositories/documind_repository.dart';

/// Use case: List documents from DocuMind
class ListDocuments {
  final DocuMindRepository repository;

  const ListDocuments(this.repository);

  Future<List<DocuMindDocument>> call({
    required String landlordId,
    String? propertyId,
    String? unitId,
  }) async {
    print('✅ UseCase: List documents');
    print('   - Landlord: $landlordId');
    print('   - Property: ${propertyId ?? "All"}');

    final documents = await repository.listDocuments(
      landlordId: landlordId,
      propertyId: propertyId,
      unitId: unitId,
    );

    // ✅ Business logic: Sort by upload date (newest first)
    documents.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return documents;
  }
}