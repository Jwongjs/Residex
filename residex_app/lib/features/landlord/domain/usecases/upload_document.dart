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
    required String propertyId,
    required String category,
    required File file,
    String? unitId,
    String? unitLabel,
    void Function(String stage)? onProgress,
  }) async {
    // ✅ Business validation (domain layer)
    final validCategories = ['lease', 'insurance', 'loan', 'tax', 'upkeep', 'maintenance', 'rental_invoice', 'expenses'];
    if (!validCategories.contains(category)) {
      throw ArgumentError('Invalid category: $category');
    }

    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) { // 10 MB
      throw ArgumentError('File too large (max 10 MB)');
    }

    // Backend ingests PDFs plus JPG/PNG photos (Gemini transcription); keep
    // this domain guard in sync with the picker's allowedUploadExtensions.
    const allowedExtensions = ['.pdf', '.jpg', '.jpeg', '.png'];
    final lowerPath = file.path.toLowerCase();
    if (!allowedExtensions.any(lowerPath.endsWith)) {
      throw ArgumentError('Only PDF, JPG or PNG files are supported');
    }

    print('✅ UseCase: Upload validation passed');
    print('   - File: ${file.path}');
    print('   - Size: ${(fileSize / 1024).toStringAsFixed(1)} KB');
    print('   - Category: $category');

    return await repository.uploadDocument(
      propertyId: propertyId,
      category: category,
      file: file,
      unitId: unitId,
      unitLabel: unitLabel,
      onProgress: onProgress,
    );
  }
}