import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:residex_app/features/landlord/data/datasources/documind_remote_datasource.dart';

void main() {
  test('recordManualLoanEntry PUTs the entry', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{}', 200);
    });
    final ds = DocuMindRemoteDataSource(httpClient: client);

    await ds.recordManualLoanEntry(
      landlordId: 'l1',
      propertyId: 'p1',
      year: 2025,
      cadence: 'annual',
      interestPaid: 5000,
      principalPaid: 3000,
    );

    expect(captured.method, 'PUT');
    expect(captured.url.path, contains('/documind/finance/manual-loan-entry'));
    final body = json.decode(captured.body) as Map<String, dynamic>;
    expect(body['landlord_id'], 'l1');
    expect(body['property_id'], 'p1');
    expect(body['year'], 2025);
    expect(body['cadence'], 'annual');
    expect(body['interest_paid'], 5000);
    expect(body['principal_paid'], 3000);
    expect(body.containsKey('month'), isFalse);
  });

  test('recordManualLoanEntry includes month for monthly cadence', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{}', 200);
    });
    final ds = DocuMindRemoteDataSource(httpClient: client);

    await ds.recordManualLoanEntry(
      landlordId: 'l1',
      propertyId: 'p1',
      year: 2025,
      cadence: 'monthly',
      interestPaid: 500,
      principalPaid: 300,
      month: 3,
    );

    final body = json.decode(captured.body) as Map<String, dynamic>;
    expect(body['month'], 3);
  });

  test('recordManualLoanEntry throws on non-200', () async {
    final client = MockClient((req) async => http.Response('boom', 500));
    final ds = DocuMindRemoteDataSource(httpClient: client);

    expect(
      () => ds.recordManualLoanEntry(
        landlordId: 'l1',
        propertyId: 'p1',
        year: 2025,
        cadence: 'annual',
        interestPaid: 5000,
        principalPaid: 3000,
      ),
      throwsException,
    );
  });

  test('deleteManualLoanEntry DELETEs with query params', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{}', 200);
    });
    final ds = DocuMindRemoteDataSource(httpClient: client);

    await ds.deleteManualLoanEntry(
      landlordId: 'l1',
      propertyId: 'p1',
      year: 2025,
      month: 3,
    );

    expect(captured.method, 'DELETE');
    expect(captured.url.path, contains('/documind/finance/manual-loan-entry'));
    expect(captured.url.queryParameters['landlord_id'], 'l1');
    expect(captured.url.queryParameters['property_id'], 'p1');
    expect(captured.url.queryParameters['year'], '2025');
    expect(captured.url.queryParameters['month'], '3');
  });

  test('recordManualLoanEntry includes unit_id when provided', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{}', 200);
    });
    final ds = DocuMindRemoteDataSource(httpClient: client);

    await ds.recordManualLoanEntry(
      landlordId: 'l1',
      propertyId: 'p1',
      year: 2025,
      cadence: 'annual',
      interestPaid: 5000,
      principalPaid: 3000,
      unitId: 'u1',
    );

    final body = json.decode(captured.body) as Map<String, dynamic>;
    expect(body['unit_id'], 'u1');
  });

  test('setUnitLoanExemption PUTs to unit-loan-exemption', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{}', 200);
    });
    final ds = DocuMindRemoteDataSource(httpClient: client);

    await ds.setUnitLoanExemption(
      landlordId: 'l1',
      propertyId: 'p1',
      unitId: 'u1',
    );

    expect(captured.method, 'PUT');
    expect(captured.url.path, contains('/documind/finance/unit-loan-exemption'));
    final body = json.decode(captured.body) as Map<String, dynamic>;
    expect(body['landlord_id'], 'l1');
    expect(body['property_id'], 'p1');
    expect(body['unit_id'], 'u1');
  });

  test('listManualLoanEntries GETs and returns entries', () async {
    final client = MockClient((req) async {
      return http.Response(
        json.encode({
          'entries': [
            {'year': 2025, 'cadence': 'annual', 'interest_paid': 5000},
          ],
        }),
        200,
      );
    });
    final ds = DocuMindRemoteDataSource(httpClient: client);

    final entries = await ds.listManualLoanEntries(
      landlordId: 'l1',
      propertyId: 'p1',
      year: 2025,
    );

    expect(entries, hasLength(1));
    expect(entries.first['cadence'], 'annual');
  });
}
