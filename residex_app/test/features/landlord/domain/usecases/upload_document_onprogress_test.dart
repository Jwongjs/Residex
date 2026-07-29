import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/repositories/documind_repository.dart';
import 'package:residex_app/features/landlord/domain/usecases/upload_document.dart';

class _FakeRepo implements DocuMindRepository {
  void Function(String stage)? capturedOnProgress;

  @override
  Future<DocuMindDocument> uploadDocument({
    required String landlordId,
    required String propertyId,
    required String category,
    required File file,
    String? unitId,
    String? unitLabel,
    void Function(String stage)? onProgress,
  }) async {
    capturedOnProgress = onProgress;
    onProgress?.call('received');
    return DocuMindDocument(
      docId: 'doc-1',
      landlordId: 'l1',
      propertyId: 'p1',
      category: 'lease',
      filename: 'lease.pdf',
      chunksIndexed: 1,
      uploadedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('UploadDocument forwards onProgress to the repository', () async {
    final repo = _FakeRepo();
    final usecase = UploadDocument(repo);
    final tempFile = File('${Directory.systemTemp.path}/rx_uc_test.pdf');
    await tempFile.writeAsBytes([1, 2, 3]);
    addTearDown(() async {
      if (await tempFile.exists()) await tempFile.delete();
    });

    final stages = <String>[];
    await usecase(
      landlordId: 'l1',
      propertyId: 'p1',
      category: 'lease',
      file: tempFile,
      onProgress: stages.add,
    );

    expect(repo.capturedOnProgress, isNotNull);
    expect(stages, ['received']);
  });
}
