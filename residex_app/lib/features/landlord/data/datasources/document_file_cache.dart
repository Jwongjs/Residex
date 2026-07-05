import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Caches downloaded citation PDFs on-device, keyed by doc_id, so repeat
/// views of the same document don't re-download from Storage.
class DocumentFileCache {
  final http.Client httpClient;

  DocumentFileCache({http.Client? httpClient}) : httpClient = httpClient ?? http.Client();

  Future<File> _cacheFileFor(String docId) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/documind_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/$docId.pdf');
  }

  /// Returns a cached local file for [docId] if one exists, otherwise calls
  /// [fetchViewUrl] to get a fresh signed URL, downloads it, caches it, and
  /// returns the resulting file.
  Future<File> getOrDownload({
    required String docId,
    required Future<String> Function() fetchViewUrl,
  }) async {
    final cacheFile = await _cacheFileFor(docId);

    if (await cacheFile.exists()) {
      return cacheFile;
    }

    final viewUrl = await fetchViewUrl();
    final response = await httpClient.get(Uri.parse(viewUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to download document: ${response.statusCode}');
    }

    await cacheFile.writeAsBytes(response.bodyBytes);
    return cacheFile;
  }
}
