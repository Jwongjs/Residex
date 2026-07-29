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
    void Function(String stage)? onProgress,
  }) async {
    print('🔵 DataSource: Upload document (streaming)');

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUploadStream}');
    final request = http.MultipartRequest('POST', uri);

    request.fields['landlord_id'] = landlordId;
    request.fields['property_id'] = propertyId;
    request.fields['category'] = category;
    if (unitId != null) request.fields['unit_id'] = unitId;
    if (unitLabel != null) request.fields['unit_label'] = unitLabel;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      // httpClient.send (not request.send) so the injected client is used.
      final response = await httpClient.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        print('❌ DataSource: Upload failed: $errorBody');
        throw Exception('Upload failed: $errorBody');
      }

      DocuMindDocumentModel? result;
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final event = json.decode(line) as Map<String, dynamic>;
        switch (event['type']) {
          case 'stage':
            onProgress?.call(event['stage'] as String);
            break;
          case 'result':
            onProgress?.call('done');
            result = DocuMindDocumentModel.fromJson(
                event['result'] as Map<String, dynamic>);
            break;
          case 'error':
            throw Exception('Upload failed: ${event['message']}');
        }
      }

      if (result == null) {
        throw Exception('Upload ended without a result');
      }
      return result;
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

  /// Mark one month as "no payment received". Excludes that month from
  /// Received Rent, Net P/L, and Statutory Rental Income. [state] is
  /// 'outstanding' (still being chased, default) or 'written_off' (given
  /// up on, irrecoverable).
  Future<void> setPaymentException({
    required String landlordId,
    required String propertyId,
    required String month,
    String? unitId,
    String? reason,
    String state = 'outstanding',
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindPaymentException}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'landlord_id': landlordId,
        'property_id': propertyId,
        'unit_id': unitId,
        'month': month,
        'reason': reason,
        'state': state,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark month unpaid: ${response.body}');
    }
  }

  /// Clear a "no payment received" mark. Idempotent.
  Future<void> clearPaymentException({
    required String landlordId,
    required String propertyId,
    required String month,
    String? unitId,
  }) async {
    final queryParameters = {
      'landlord_id': landlordId,
      'property_id': propertyId,
      'month': month,
      if (unitId != null) 'unit_id': unitId,
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindPaymentException}')
        .replace(queryParameters: queryParameters);
    final response = await httpClient.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to clear payment mark: ${response.body}');
    }
  }

  /// Acknowledge that a coverage gap cannot be filled for one (year,
  /// category). The year then settles as complete-with-gaps.
  Future<void> setDocumentUnavailable({
    required String landlordId,
    required String propertyId,
    required int year,
    required String category,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindDocumentException}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'landlord_id': landlordId,
        'property_id': propertyId,
        'year': year,
        'category': category,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark document unavailable: ${response.body}');
    }
  }

  /// Clear an 'unavailable' mark. Idempotent.
  Future<void> clearDocumentUnavailable({
    required String landlordId,
    required String propertyId,
    required int year,
    required String category,
  }) async {
    final queryParameters = {
      'landlord_id': landlordId,
      'property_id': propertyId,
      'year': '$year',
      'category': category,
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindDocumentException}')
        .replace(queryParameters: queryParameters);
    final response = await httpClient.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to clear unavailable mark: ${response.body}');
    }
  }

  /// Book a written-off month's rent as income in the year it actually
  /// arrived. Requires the month to already be on file as written_off.
  Future<void> recordRentRecovery({
    required String landlordId,
    required String propertyId,
    required String originalMonth,
    required double amount,
    required int receivedYear,
    String? unitId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindRentRecovery}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'landlord_id': landlordId,
        'property_id': propertyId,
        'unit_id': unitId,
        'original_month': originalMonth,
        'amount': amount,
        'received_year': receivedYear,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to record rent recovery: ${response.body}');
    }
  }

  /// Remove a recorded rent recovery. Idempotent.
  Future<void> clearRentRecovery({
    required String landlordId,
    required String propertyId,
    required String originalMonth,
    String? unitId,
  }) async {
    final queryParameters = {
      'landlord_id': landlordId,
      'property_id': propertyId,
      'original_month': originalMonth,
      if (unitId != null) 'unit_id': unitId,
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindRentRecovery}')
        .replace(queryParameters: queryParameters);
    final response = await httpClient.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to clear rent recovery: ${response.body}');
    }
  }

  /// Book manually-entered loan interest/principal for a period. Idempotent
  /// per (property, year, month). [month] is required only for monthly cadence.
  Future<void> recordManualLoanEntry({
    required String landlordId,
    required String propertyId,
    required int year,
    required String cadence,
    required double interestPaid,
    required double principalPaid,
    int? month,
    String? unitId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindManualLoanEntry}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'landlord_id': landlordId,
        'property_id': propertyId,
        'year': year,
        'cadence': cadence,
        'interest_paid': interestPaid,
        'principal_paid': principalPaid,
        if (month != null) 'month': month,
        if (unitId != null) 'unit_id': unitId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to record manual loan entry: ${response.body}');
    }
  }

  /// Remove a manual loan entry. Idempotent.
  Future<void> deleteManualLoanEntry({
    required String landlordId,
    required String propertyId,
    required int year,
    int? month,
    String? unitId,
  }) async {
    final queryParameters = {
      'landlord_id': landlordId,
      'property_id': propertyId,
      'year': '$year',
      if (month != null) 'month': '$month',
      if (unitId != null) 'unit_id': unitId,
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindManualLoanEntry}')
        .replace(queryParameters: queryParameters);
    final response = await httpClient.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete manual loan entry: ${response.body}');
    }
  }

  /// Mark a unit as having no loan (excludes it from loan-figure completeness).
  Future<void> setUnitLoanExemption({
    required String landlordId,
    required String propertyId,
    required String unitId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUnitLoanExemption}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'landlord_id': landlordId, 'property_id': propertyId, 'unit_id': unitId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark unit no-loan: ${response.body}');
    }
  }

  /// Remove a unit's no-loan mark. Idempotent.
  Future<void> clearUnitLoanExemption({
    required String landlordId,
    required String propertyId,
    required String unitId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindUnitLoanExemption}')
        .replace(queryParameters: {
      'landlord_id': landlordId, 'property_id': propertyId, 'unit_id': unitId,
    });
    final response = await httpClient.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to clear unit no-loan mark: ${response.body}');
    }
  }

  /// All manual loan entries for one property and year.
  Future<List<Map<String, dynamic>>> listManualLoanEntries({
    required String landlordId,
    required String propertyId,
    required int year,
  }) async {
    final queryParameters = {
      'landlord_id': landlordId,
      'property_id': propertyId,
      'year': '$year',
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.documindManualLoanEntry}')
        .replace(queryParameters: queryParameters);
    final response = await httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to list manual loan entries: ${response.body}');
    }
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    return ((decoded['entries'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map<String, dynamic>))
        .toList();
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