  /// Base exception class
  class AppException implements Exception {
    final String message;
    const AppException([this.message = 'An error occurred']);

    @override
    String toString() => message;
  }

  /// Exception for cache/database errors
  class CacheException extends AppException {
    const CacheException([super.message = 'Cache exception']);
  }

  /// Exception for server errors
  class ServerException extends AppException {
    const ServerException([super.message = 'Server exception']);
  }

  /// Exception for validation errors
  class ValidationException extends AppException {
    const ValidationException([super.message = 'Validation exception']);
  }