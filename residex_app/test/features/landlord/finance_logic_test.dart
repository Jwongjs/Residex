import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_logic.dart';

DocuMindDocument _doc(String category, Map<String, dynamic>? facts) {
  return DocuMindDocument(
    docId: 'd', landlordId: 'l1', propertyId: 'p1', category: category,
    filename: 'f.pdf', chunksIndexed: 1, uploadedAt: DateTime(2026, 1, 1),
    extractedFacts: facts,
  );
}

void main() {
  test('formatRM adds thousand separators and two decimals', () {
    expect(formatRM(60106.58), 'RM 60,106.58');
    expect(formatRM(1500), 'RM 1,500.00');
    expect(formatRM(0), 'RM 0.00');
    expect(formatRM(-500.5), '-RM 500.50');
  });

  test('financeYearOptions derives years from facts plus current year', () {
    final docs = [
      _doc('rental_invoice', {'amount': 1000.0, 'period_month': '2024-05'}),
      _doc('tax', {'amount': 460.0, 'period_year': 2023}),
      _doc('lease', {'monthly_rent': 900.0, 'lease_start': '2025-01-01', 'lease_end': '2025-12-31'}),
      _doc('lease', null),
    ];
    expect(financeYearOptions(docs, 2026), [2026, 2025, 2024, 2023]);
  });

  test('financeYearOptions with no docs is just the current year', () {
    expect(financeYearOptions(const [], 2026), [2026]);
  });

  test('rankMissingDocuments orders by landlord impact, not alphabetically', () {
    final ranked = rankMissingDocuments(['insurance', 'lease', 'loan', 'maintenance']);
    expect(ranked, ['lease', 'maintenance', 'loan', 'insurance']);
  });

  test('rankMissingDocuments keeps unranked labels after ranked ones, alphabetically', () {
    final ranked = rankMissingDocuments(['zzz_future_subtype', 'loan', 'aaa_future_subtype']);
    expect(ranked, ['loan', 'aaa_future_subtype', 'zzz_future_subtype']);
  });

  test('topMissingDocumentBanner names the single most damaging gap with its cost note', () {
    final banner = topMissingDocumentBanner(2025, ['insurance', 'loan']);
    expect(banner, '2025 is missing your Loan interest statement — usually the largest single deduction');
  });

  test('topMissingDocumentBanner is null when nothing is missing', () {
    expect(topMissingDocumentBanner(2025, []), isNull);
  });

  test('yearCompleteness counts maintenance months and installments as separate slots', () {
    final coverage = YearCoverage(
      year: 2025,
      missing: const ['loan'],
      partialCategories: [PartialCategory(category: 'maintenance', have: 4, expect: 12)],
      partialInstallments: [InstallmentGap(label: 'Assessment tax', have: 1, expect: 2)],
    );
    final result = yearCompleteness(coverage, ['loan', 'maintenance', 'assessment']);
    // loan: 0/1, maintenance: 4/12, assessment: 1/2 -> 5 of 15
    expect(result.have, 5);
    expect(result.expect, 15);
  });

  test('yearCompleteness treats an acknowledged gap as settled, not missing', () {
    final coverage = YearCoverage(year: 2025, unavailable: const ['insurance']);
    final result = yearCompleteness(coverage, ['insurance']);
    expect(result, (have: 1, expect: 1));
  });

  test('yearCompleteness counts a strata land_office_tax installment gap correctly', () {
    // The backend only ever labels a gap 'Quit rent'/'Parcel rent' — never
    // the composite 'land_office_tax' display text. A landed-only match
    // would silently read this as 1/1 (fully present) instead of 1/2.
    final coverage = YearCoverage(
      year: 2025,
      partialInstallments: [InstallmentGap(label: 'Quit rent', have: 1, expect: 2)],
    );
    final result = yearCompleteness(coverage, ['land_office_tax']);
    expect(result, (have: 1, expect: 2));
  });

  test('yearCompleteness counts the generic tax fallback installment gap correctly', () {
    final coverage = YearCoverage(
      year: 2025,
      partialInstallments: [InstallmentGap(label: 'Property tax', have: 1, expect: 2)],
    );
    final result = yearCompleteness(coverage, ['tax']);
    expect(result, (have: 1, expect: 2));
  });
}
