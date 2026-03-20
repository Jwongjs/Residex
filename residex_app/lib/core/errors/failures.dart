  /// Base class for all failures
  abstract class Failure {
    final String message;
    const Failure(this.message);

    @override
    String toString() => message;
  }

  /// Failure when local cache/database has issues
  class CacheFailure extends Failure {
    const CacheFailure([super.message = 'Cache error occurred']);
  }

  /// Failure when server/remote data source has issues
  class ServerFailure extends Failure {
    const ServerFailure([super.message = 'Server error occurred']);
  }

  /// Failure when validation fails
  class ValidationFailure extends Failure {
    const ValidationFailure([super.message = 'Validation failed']);
  }

  /// Failure when network is unavailable
  class NetworkFailure extends Failure {
    const NetworkFailure([super.message = 'No internet connection']);
  }

  /// Failure when database operations fail
  class DatabaseFailure extends Failure {
    const DatabaseFailure({required String message}) : super(message);
  }
