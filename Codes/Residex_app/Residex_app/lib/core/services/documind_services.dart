import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DocuMindService {
  static const String baseUrl = 'http://localhost:8000/api/rex/documind';
  
  /// Upload document to backend
  static Future<Map<String, dynamic>> uploadDocument({
    required String landlordId,
    required String propertyId,
    required String category,
    required File file,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    
    request.fields['landlord_id'] = landlordId;
    request.fields['property_id'] = propertyId;
    request.fields['category'] = category;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return json.decode(responseBody);
    } else {
      throw Exception('Upload failed: $responseBody');
    }
  }
  
  /// Ask question to DocuMind
  static Future<Map<String, dynamic>> askQuestion({
    required String landlordId,
    required String propertyId,
    required String question,
    int topK = 4,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ask'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'landlord_id': landlordId,
        'property_id': propertyId,
        'question': question,
        'top_k': topK,
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Question failed: ${response.body}');
    }
  }
  
  /// List documents for property
  static Future<List<dynamic>> listDocuments({
    required String landlordId,
    String? propertyId,
  }) async {
    final uri = Uri.parse('$baseUrl/documents').replace(queryParameters: {
      'landlord_id': landlordId,
      if (propertyId != null) 'property_id': propertyId,
    });
    
    final response = await http.get(uri);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['documents'] as List<dynamic>;
    } else {
      throw Exception('List failed: ${response.body}');
    }
  }
}