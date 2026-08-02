import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:residex_app/features/landlord/data/datasources/documind_remote_datasource.dart';

/// Fake client that returns a canned NDJSON stream for any request.
class _FakeStreamingClient extends http.BaseClient {
  _FakeStreamingClient(this.body);
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(body);
    return http.StreamedResponse(Stream.value(bytes), 200);
  }
}

void main() {
  late File tempFile;

  setUp(() async {
    tempFile = File('${Directory.systemTemp.path}/rx_upload_test.pdf');
    await tempFile.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    if (await tempFile.exists()) await tempFile.delete();
  });

  test('reports each stage in order and returns the result model', () async {
    const ndjson =
        '{"type":"stage","stage":"received"}\n'
        '{"type":"stage","stage":"reading"}\n'
        '{"type":"stage","stage":"organising"}\n'
        '{"type":"stage","stage":"indexing"}\n'
        '{"type":"stage","stage":"details"}\n'
        '{"type":"result","result":{"doc_id":"doc-1","landlord_id":"l1","property_id":"p1","category":"lease","filename":"lease.pdf","status":"indexed","chunks_indexed":3}}\n';
    final ds = DocuMindRemoteDataSource(httpClient: _FakeStreamingClient(ndjson));
    final stages = <String>[];

    final model = await ds.uploadDocument(
      propertyId: 'p1',
      category: 'lease',
      file: tempFile,
      onProgress: stages.add,
    );

    expect(stages, ['received', 'reading', 'organising', 'indexing', 'details', 'done']);
    expect(model.docId, 'doc-1');
    expect(model.chunksIndexed, 3);
  });

  test('throws when the stream ends with an error event', () async {
    const ndjson =
        '{"type":"stage","stage":"received"}\n'
        '{"type":"error","message":"bad category"}\n';
    final ds = DocuMindRemoteDataSource(httpClient: _FakeStreamingClient(ndjson));

    expect(
      () => ds.uploadDocument(
        propertyId: 'p1', category: 'nope', file: tempFile),
      throwsA(isA<Exception>()),
    );
  });

  test('throws when the stream ends with no result event', () async {
    const ndjson = '{"type":"stage","stage":"received"}\n';
    final ds = DocuMindRemoteDataSource(httpClient: _FakeStreamingClient(ndjson));

    expect(
      () => ds.uploadDocument(
        propertyId: 'p1', category: 'lease', file: tempFile),
      throwsA(isA<Exception>()),
    );
  });
}
