import 'package:http/http.dart' as http;

/// Thrown when a request is attempted with no signed-in user.
class NotSignedInException implements Exception {
  @override
  String toString() => 'NotSignedInException: no authenticated user';
}

/// An [http.Client] that attaches a Firebase ID token to every outgoing
/// request. `send` is the single chokepoint for all verbs, multipart uploads,
/// and streamed responses, so no call site can forget the header.
class AuthedClient extends http.BaseClient {
  final http.Client _inner;
  final Future<String?> Function() _getToken;

  AuthedClient(this._inner, this._getToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _getToken();
    if (token == null) throw NotSignedInException();
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
