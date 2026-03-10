import 'dart:io';
import '../entities/documind_document.dart';
import '../repositories/documind_repository.dart';

/// Use case: Upload document to DocuMind
/// 
/// Business rules:
/// - File must be PDF
/// - Category must be valid (lease, warranty, insurance, utility, receipt, other)
/// - File size must be < 10 MB
class UploadDocument {
  final DocuMindRepository repository;

  const UploadDocument(this.repository);

  Future<DocuMindDocument> call({
    required String landlordId,
    required String propertyId,
    required String category,
    required File file,
  }) async {
    // ✅ Business validation (domain layer)
    final validCategories = ['lease', 'warranty', 'insurance', 'utility', 'receipt', 'other'];
    if (!validCategories.contains(category)) {
      throw ArgumentError('Invalid category: $category');
    }

    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) { // 10 MB
      throw ArgumentError('File too large (max 10 MB)');
    }

    if (!file.path.toLowerCase().endsWith('.pdf')) {
      throw ArgumentError('Only PDF files are supported');
    }

    print('✅ UseCase: Upload validation passed');
    print('   - File: ${file.path}');
    print('   - Size: ${(fileSize / 1024).toStringAsFixed(1)} KB');
    print('   - Category: $category');

    return await repository.uploadDocument(
      landlordId: landlordId,
      propertyId: propertyId,
      category: category,
      file: file,
    );
  }
}