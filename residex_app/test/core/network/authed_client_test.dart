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
    final client = AuthedClient(inner, () async => 'tok123');

    await client.get(Uri.parse('http://x/y'));

    expect(seen, 'Bearer tok123');
  });

  test('throws NotSignedInException when token is null', () async {
    final inner = MockClient((req) async => http.Response('', 200));
    final client = AuthedClient(inner, () async => null);

    expect(() => client.get(Uri.parse('http://x/y')),
        throwsA(isA<NotSignedInException>()));
  });
}
