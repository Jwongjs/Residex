import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../../../core/constants/api_constants.dart';
import '../models/documind_models.dart';

/// Remote data source for DocuMind API
class DocuMindRemoteDataSource {
  final http.Client httpClient;

  DocuMindRemoteDataSource({http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  /// Upload document to backend
  Future<DocuMindDocumentModel> uploadDocument({
    required String landlordId,
    required String propertyId,
    required String category,
    required File file,
  }) async {
    print('🔵 DataSource: Upload document');
    print('   - Landlord: $landlordId');
    print('   - Property: $propertyId');
    print('   - Category: $category');

    ///'http://10.0.2.2:8000/api/rex/documind';
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUpload}');
    final request = http.MultipartRequest('POST', uri);

    request.fields['landlord_id'] = landlordId;
    request.fields['property_id'] = propertyId;
    request.fields['category'] = category;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('✅ DataSource: Upload response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody) as Map<String, dynamic>;
        return DocuMindDocumentModel.fromJson(jsonResponse);
      } else {
        print('❌ DataSource: Upload failed: $responseBody');
        throw Exception('Upload failed: $responseBody');
      }
    } catch (e) {
      print('❌ DataSource: Upload error: $e');
      rethrow;
    }
  }

  /// Ask question to DocuMind
  Future<DocuMindAnswerModel> askQuestion({
    required String landlordId,
    required String propertyId,
    required String question,
    int topK = 4,
    List<String>? categories,
    String? sessionId,
    int conversationTurn = 1,
    String? userAction,
  }) async {
    print('🔵 DataSource: Ask question');
    print('   - Landlord: $landlordId');
    print('   - Property: $propertyId');
    print('   - Question: $question');

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindAsk}');

    try {
      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'landlord_id': landlordId,
          'property_id': propertyId,
          'question': question,
          'top_k': topK,
          if (categories != null && categories.isNotEmpty) 'categories': categories,
          if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
          'conversation_turn': conversationTurn,
          if (userAction != null && userAction.isNotEmpty) 'user_action': userAction,
        }),
      );

      print('✅ DataSource: Ask response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
        return DocuMindAnswerModel.fromJson(jsonResponse);
      } else {
        print('❌ DataSource: Ask failed: ${response.body}');
        throw Exception('Ask failed: ${response.body}');
      }
    } catch (e) {
      print('❌ DataSource: Ask error: $e');
      rethrow;
    }
  }

  /// List documents for a property
  Future<List<DocuMindDocumentModel>> listDocuments({
    required String landlordId,
    String? propertyId,
  }) async {
    print('🔵 DataSource: List documents');
    print('   - Landlord: $landlordId');
    print('   - Property: ${propertyId ?? "ALL"}');

    final queryParams = <String, String>{
      'landlord_id': landlordId,
    };
    
    if (propertyId != null) {
      queryParams['property_id'] = propertyId;
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindList}')
        .replace(queryParameters: queryParams);

    try {
      final response = await httpClient.get(uri);

      print('✅ DataSource: List response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
        final documentsJson = jsonResponse['documents'] as List<dynamic>? ?? [];

        return documentsJson
            .map((doc) => DocuMindDocumentModel.fromJson(doc as Map<String, dynamic>))
            .toList();
      } else {
        print('❌ DataSource: List failed: ${response.body}');
        throw Exception('List failed: ${response.body}');
      }
    } catch (e) {
      print('❌ DataSource: List error: $e');
      rethrow;
    }
  }

  // ✅ ADDED: Delete document method
  /// Delete a document from backend
  Future<void> deleteDocument({
    required String landlordId,
    required String propertyId,
    required String docId,
  }) async {
    print('🔵 DataSource: Delete document');
    print('   - Landlord: $landlordId');
    print('   - Property: $propertyId');
    print('   - Doc ID: $docId');

    final uri = Uri.parse('${ApiConstants.baseUrl}/api/rex/documind/documents/$docId')
        .replace(queryParameters: {
      'landlord_id': landlordId,
      'property_id': propertyId,
    });

    try {
      final response = await httpClient.delete(uri);

      print('✅ DataSource: Delete response status ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ DataSource: Delete failed: ${response.body}');
        throw Exception('Delete failed: ${response.body}');
      }
    } catch (e) {
      print('❌ DataSource: Delete error: $e');
      rethrow;
    }
  }
}