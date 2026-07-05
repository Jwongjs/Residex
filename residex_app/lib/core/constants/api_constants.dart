class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  // For iOS simulator, use:
  // static const String baseUrl = 'http://localhost:8000';
  
  // For physical device, use your PC's IP address:
  // static const String baseUrl = 'http://192.168.1.100:8000';
  
  // REX AI endpoints
  static const String documindUpload = '/api/rex/documind/upload';
  static const String documindAsk = '/api/rex/documind/ask';
  static const String documindList = '/api/rex/documind/documents';
  static String documindViewUrl(String docId) => '/api/rex/documind/documents/$docId/view-url';
}