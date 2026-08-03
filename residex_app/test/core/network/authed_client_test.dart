import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:residex_app/core/network/authed_client.dart';

void main() {
  test('attaches bearer token to every request', () async {
    String? seen;
    final inner = MockClient((req) async {
      seen = req.headers['Authorization'];
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final client = AuthedClient(inner, ({bool forceRefresh = false}) async => 'tok123');

    await client.get(Uri.parse('http://x/y'));

    expect(seen, 'Bearer tok123');
  });

  test('throws NotSignedInException when token is null, and calls onAuthFailure', () async {
    bool authFailureCalled = false;
    final inner = MockClient((req) async => http.Response('', 200));
    final client = AuthedClient(
      inner,
      ({bool forceRefresh = false}) async => null,
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    );

    await expectLater(
      () => client.get(Uri.parse('http://x/y')),
      throwsA(isA<NotSignedInException>()),
    );
    expect(authFailureCalled, isTrue);
  });

  test('200 response passes through and body is fully readable', () async {
    final inner = MockClient((req) async {
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final client = AuthedClient(inner, ({bool forceRefresh = false}) async => 'tok123');

    final response = await client.get(Uri.parse('http://x/y'));

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'ok': true});
  });

  test('401 token_expired on replayable GET: force-refreshes and retries successfully', () async {
    final forceRefreshFlagsSeen = <bool>[];
    bool authFailureCalled = false;
    int callCount = 0;

    final inner = MockClient((req) async {
      callCount++;
      if (callCount == 1) {
        return http.Response(
          jsonEncode({
            'detail': {'code': 'token_expired'}
          }),
          401,
        );
      }
      // Second call: expect fresh token attached.
      expect(req.headers['Authorization'], 'Bearer fresh-token');
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    final client = AuthedClient(
      inner,
      ({bool forceRefresh = false}) async {
        forceRefreshFlagsSeen.add(forceRefresh);
        return forceRefresh ? 'fresh-token' : 'stale-token';
      },
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    );

    final response = await client.get(Uri.parse('http://x/y'));

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'ok': true});
    expect(forceRefreshFlagsSeen, contains(true));
    expect(authFailureCalled, isFalse);
    expect(callCount, 2);
  });

  test('401 token_expired that stays 401 on retry calls onAuthFailure and returns 401', () async {
    bool authFailureCalled = false;
    int callCount = 0;

    final inner = MockClient((req) async {
      callCount++;
      return http.Response(
        jsonEncode({
          'detail': {'code': 'token_expired'}
        }),
        401,
      );
    });

    final client = AuthedClient(
      inner,
      ({bool forceRefresh = false}) async => forceRefresh ? 'fresh-token' : 'stale-token',
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    );

    final response = await client.get(Uri.parse('http://x/y'));

    expect(response.statusCode, 401);
    expect(authFailureCalled, isTrue);
    expect(callCount, 2);
  });

  test('401 token_invalid: no retry, onAuthFailure called, returns 401', () async {
    bool authFailureCalled = false;
    int callCount = 0;

    final inner = MockClient((req) async {
      callCount++;
      return http.Response(
        jsonEncode({
          'detail': {'code': 'token_invalid'}
        }),
        401,
      );
    });

    final client = AuthedClient(
      inner,
      ({bool forceRefresh = false}) async => 'tok',
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    );

    final response = await client.get(Uri.parse('http://x/y'));

    expect(response.statusCode, 401);
    expect(authFailureCalled, isTrue);
    expect(callCount, 1);
  });

  test('401 forbidden: onAuthFailure called, returns 401', () async {
    bool authFailureCalled = false;
    int callCount = 0;

    final inner = MockClient((req) async {
      callCount++;
      return http.Response(
        jsonEncode({
          'detail': {'code': 'forbidden'}
        }),
        401,
      );
    });

    final client = AuthedClient(
      inner,
      ({bool forceRefresh = false}) async => 'tok',
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    );

    final response = await client.get(Uri.parse('http://x/y'));

    expect(response.statusCode, 401);
    expect(authFailureCalled, isTrue);
    expect(callCount, 1);
  });

  test('401 token_expired on non-replayable MultipartRequest: refreshes cached token, stays signed in', () async {
    final forceRefreshFlagsSeen = <bool>[];
    bool authFailureCalled = false;
    int callCount = 0;

    final inner = MockClient((req) async {
      callCount++;
      return http.Response(
        jsonEncode({
          'detail': {'code': 'token_expired'}
        }),
        401,
      );
    });

    final client = AuthedClient(
      inner,
      ({bool forceRefresh = false}) async {
        forceRefreshFlagsSeen.add(forceRefresh);
        return forceRefresh ? 'fresh-token' : 'stale-token';
      },
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    );

    final request = http.MultipartRequest('POST', Uri.parse('http://x/y'));
    final streamedResponse = await client.send(request);

    expect(streamedResponse.statusCode, 401);
    expect(forceRefreshFlagsSeen, contains(true));
    expect(authFailureCalled, isFalse);
    // Only one inner call: body stream can't be replayed, so no retry attempt.
    expect(callCount, 1);
  });

  test('unparseable/empty 401 body is treated as terminal: onAuthFailure called, returns 401', () async {
    bool authFailureCalled = false;
    int callCount = 0;

    final inner = MockClient((req) async {
      callCount++;
      return http.Response('', 401);
    });

    final client = AuthedClient(
      inner,
      ({bool forceRefresh = false}) async => 'tok',
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    );

    final response = await client.get(Uri.parse('http://x/y'));

    expect(response.statusCode, 401);
    expect(authFailureCalled, isTrue);
    expect(callCount, 1);
  });
}
