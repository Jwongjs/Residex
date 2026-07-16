import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/presentation/screens/2-Documind/documind_upload_summary.dart';

void main() {
  test('tax facts produce subtype + amount + year line', () {
    expect(
      uploadFactSummary('tax', {'subtype': 'quit_rent', 'amount': 460.63, 'period_year': 2026}),
      'Quit rent recorded — RM 460.63, 2026',
    );
  });

  test('lease facts produce rent + end date line', () {
    expect(
      uploadFactSummary('lease', {'monthly_rent': 1500.0, 'lease_end': '2026-09-01'}),
      'Lease recorded — RM 1500.00/mo, ends 2026-09-01',
    );
  });

  test('rental invoice facts produce amount + month line', () {
    expect(
      uploadFactSummary('rental_invoice', {'amount': 1200.0, 'period_month': '2026-07'}),
      'Rent invoice recorded — RM 1200.00 for 2026-07',
    );
  });

  test('null or empty facts return null so caller falls back', () {
    expect(uploadFactSummary('lease', null), isNull);
    expect(uploadFactSummary('lease', const {}), isNull);
  });

  test('facts without a summarizable field return null', () {
    expect(uploadFactSummary('upkeep', const {'description': 'aircon'}), isNull);
  });
}
