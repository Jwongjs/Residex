import '../repositories/documind_repository.dart';

/// Use case: get a short-lived signed URL to view a document's original PDF
class GetDocumentViewUrl {
  final DocuMindRepository repository;

  const GetDocumentViewUrl(this.repository);

  Future<String> call({
    required String landlordId,
    required String propertyId,
    required String docId,
  }) async {
    return await repository.getDocumentViewUrl(
      landlordId: landlordId,
      propertyId: propertyId,
      docId: docId,
    );
  }
}
