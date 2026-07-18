import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../../../core/constants/api_constants.dart';
import '../../domain/entities/finance_summary.dart';
import '../models/documind_models.dart';
import '../models/finance_summary_model.dart';

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
    String? unitId,
    String? unitLabel,
  }) async {
    print('🔵 DataSource: Upload document');
    print('   - Landlord: $landlordId');
    print('   - Property: $propertyId');
    print('   - Category: $category');
    print('   - Unit: ${unitLabel ?? "whole property"}');

    ///'http://10.0.2.2:8000/api/rex/documind';
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUpload}');
    final request = http.MultipartRequest('POST', uri);

    request.fields['landlord_id'] = landlordId;
    request.fields['property_id'] = propertyId;
    request.fields['category'] = category;
    if (unitId != null) request.fields['unit_id'] = unitId;
    if (unitLabel != null) request.fields['unit_label'] = unitLabel;
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
    String? unitId,
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
          if (unitId != null && unitId.isNotEmpty) 'unit_id': unitId,
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
    String? unitId,
  }) async {
    print('🔵 DataSource: List documents');
    print('   - Landlord: $landlordId');
    print('   - Property: ${propertyId ?? "ALL"}');
    print('   - Unit: ${unitId ?? "ALL"}');

    final queryParams = <String, String>{
      'landlord_id': landlordId,
    };

    if (propertyId != null) {
      queryParams['property_id'] = propertyId;
    }

    if (unitId != null) {
      queryParams['unit_id'] = unitId;
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

  /// Delete ALL documents for a property (part of the property-delete cascade)
  Future<void> deleteDocumentsForProperty({
    required String landlordId,
    required String propertyId,
  }) async {
    print('🔵 DataSource: Delete all documents for property $propertyId');

    final uri = Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.documindPropertyDocs(propertyId)}')
        .replace(queryParameters: {'landlord_id': landlordId});

    try {
      final response = await httpClient.delete(uri);

      print('✅ DataSource: Bulk delete response status ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ DataSource: Bulk delete failed: ${response.body}');
        throw Exception('Bulk delete failed: ${response.body}');
      }
    } catch (e) {
      print('❌ DataSource: Bulk delete error: $e');
      rethrow;
    }
  }

  /// Convert one unit's documents to property-wide (called before deleting
  /// the unit, so its documents don't keep a stale unit_id)
  Future<void> unassignUnitDocuments({
    required String landlordId,
    required String propertyId,
    required String unitId,
  }) async {
    print('🔵 DataSource: Unassign unit documents');
    print('   - Unit: $unitId');

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUnassignUnit}');

    try {
      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'landlord_id': landlordId,
          'property_id': propertyId,
          'unit_id': unitId,
        }),
      );

      print('✅ DataSource: Unassign response status ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ DataSource: Unassign failed: ${response.body}');
        throw Exception('Unassign failed: ${response.body}');
      }
    } catch (e) {
      print('❌ DataSource: Unassign error: $e');
      rethrow;
    }
  }

  /// Deterministic finance summary for one landlord and calendar year.
  Future<FinanceSummary> getFinanceSummary({
    required String landlordId,
    required int year,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindFinanceSummary}')
        .replace(queryParameters: {
      'landlord_id': landlordId,
      'year': '$year',
    });

    final response = await httpClient.get(uri);

    if (response.statusCode == 200) {
      return FinanceSummaryModel.fromJson(
          json.decode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Finance summary failed: ${response.body}');
  }

  /// Get a short-lived signed URL to view a document's original PDF
  Future<String> getDocumentViewUrl({
    required String landlordId,
    required String propertyId,
    required String docId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindViewUrl(docId)}')
        .replace(queryParameters: {
      'landlord_id': landlordId,
      'property_id': propertyId,
    });

    final response = await httpClient.get(uri);

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      return jsonResponse['view_url'] as String;
    } else if (response.statusCode == 404) {
      throw DocumentNotFoundException(docId);
    } else {
      throw Exception('Failed to get view URL: ${response.body}');
    }
  }

  /// Replace a document's reviewed expense lines.
  Future<void> updateExpenseLines({
    required String landlordId,
    required String docId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.documindUpdateFacts(docId)}');
    final response = await httpClient.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'landlord_id': landlordId, 'expense_lines': lines}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update expense lines: ${response.body}');
    }
  }
}

/// Thrown when a cited document no longer exists (e.g. deleted, or predates
/// Storage-backed viewing).
class DocumentNotFoundException implements Exception {
  final String docId;
  const DocumentNotFoundException(this.docId);

  @override
  String toString() => 'Document $docId not found';
}