import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when a request is attempted with no signed-in user.
class NotSignedInException implements Exception {
  @override
  String toString() => 'NotSignedInException: no authenticated user';
}

/// An [http.Client] that attaches a Firebase ID token to every outgoing
/// request. `send` is the single chokepoint for all verbs, multipart uploads,
/// and streamed responses, so no call site can forget the header.
///
/// It also reacts to the backend's machine-readable 401 body
/// (`{"detail": {"code": ...}}`):
///   - `token_expired` on a replayable request: force-refresh the token and
///     retry once, transparently, so the user stays signed in.
///   - `token_expired` on a non-replayable request (e.g. multipart uploads,
///     whose body stream can't be re-sent): refresh the cached token for the
///     user's *next* attempt, but don't sign out — the session is still
///     valid, the caller just needs to retry.
///   - `token_missing` / `token_invalid` / `forbidden` / unparseable body:
///     the session is terminally invalid — invoke [_onAuthFailure] (sign out).
class AuthedClient extends http.BaseClient {
  final http.Client _inner;
  final Future<String?> Function({bool forceRefresh}) _getToken;
  final Future<void> Function()? _onAuthFailure;

  AuthedClient(this._inner, this._getToken, {Future<void> Function()? onAuthFailure})
      : _onAuthFailure = onAuthFailure;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _getToken();
    if (token == null) {
      await _onAuthFailure?.call();
      throw NotSignedInException();
    }
    request.headers['Authorization'] = 'Bearer $token';
    final response = await _inner.send(request);

    if (response.statusCode != 401) return response;

    final bytes = await response.stream.toBytes();
    final code = _codeFrom(bytes);

    if (code == 'token_expired' && request is http.Request) {
      final fresh = await _getToken(forceRefresh: true);
      if (fresh == null) {
        await _onAuthFailure?.call();
        return _rebuild(response, bytes);
      }
      final clone = _cloneRequest(request, fresh);
      final retry = await _inner.send(clone);
      if (retry.statusCode != 401) return retry;
      await _onAuthFailure?.call();
      return _rebuild(response, bytes);
    }

    if (code == 'token_expired') {
      // Non-replayable request (e.g. multipart upload): refresh the cached
      // token for next time, but the session itself is still valid.
      await _getToken(forceRefresh: true);
      return _rebuild(response, bytes);
    }

    // token_missing / token_invalid / forbidden / unparseable: terminal.
    await _onAuthFailure?.call();
    return _rebuild(response, bytes);
  }

  String? _codeFrom(List<int> bytes) {
    try {
      final decoded = json.decode(utf8.decode(bytes));
      final detail = decoded['detail'];
      return detail['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  http.Request _cloneRequest(http.Request original, String token) {
    final clone = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..bodyBytes = original.bodyBytes
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..encoding = original.encoding;
    clone.headers['Authorization'] = 'Bearer $token';
    return clone;
  }

  http.StreamedResponse _rebuild(http.StreamedResponse original, List<int> bytes) {
    return http.StreamedResponse(
      Stream.value(bytes),
      original.statusCode,
      contentLength: bytes.length,
      request: original.request,
      headers: original.headers,
      isRedirect: original.isRedirect,
      persistentConnection: original.persistentConnection,
      reasonPhrase: original.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
