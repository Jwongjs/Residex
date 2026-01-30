/// App-wide constants
class AppConstants {
  // API
  static const String baseUrl = 'https://api.residex.com';
  static const Duration timeout = Duration(seconds: 30);
  
  // Storage keys
  static const String userTokenKey = 'user_token';
  static const String userRoleKey = 'user_role';
  
  // Pagination
  static const int itemsPerPage = 20;
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxPropertyNameLength = 100;
}