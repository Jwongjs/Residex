import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_logic.dart';

DocuMindDocument _doc(String category, Map<String, dynamic>? facts) =>
    _docFor('p1', category, facts);

DocuMindDocument _docFor(String propertyId, String category, Map<String, dynamic>? facts) {
  return DocuMindDocument(
    docId: 'd', landlordId: 'l1', propertyId: propertyId, category: category,
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

  test('financeYearOptions hides a property years below its trackFromYear', () {
    // A 2023 lease on a property the landlord tracks only from 2025 must not
    // resurface 2023 in the selector.
    final docs = [
      _doc('lease', {'monthly_rent': 8000.0, 'lease_start': '2023-10-25'}),
      _doc('expenses', {'expense_lines': [
        {'subtype': 'maintenance', 'amount': 764.0, 'period_year': 2025},
      ]}),
    ];
    final years = financeYearOptions(docs, 2026, trackFromByProperty: {'p1': 2025});
    expect(years, [2026, 2025]);
    expect(years.contains(2023), isFalse);
  });

  test('financeYearOptions floor is per-property, not global', () {
    final docs = [
      _docFor('pA', 'lease', {'lease_start': '2023-01-01'}), // tracked from 2025 -> hidden
      _docFor('pB', 'tax', {'amount': 100.0, 'period_year': 2023}), // no floor -> kept
    ];
    final years = financeYearOptions(docs, 2026,
        trackFromByProperty: {'pA': 2025});
    expect(years, [2026, 2023]);
  });

  test('financeYearOptions with a null floor keeps all years', () {
    final docs = [_doc('lease', {'lease_start': '2023-10-25'})];
    final years = financeYearOptions(docs, 2026, trackFromByProperty: {'p1': null});
    expect(years, [2026, 2023]);
  });

  ExpenseLine makeLine(String subtype, {String category = 'expenses', String? date, double amount = 100.0, String? description, bool deductible = true}) {
    return ExpenseLine(
      docId: 'd', category: category, subtype: subtype,
      description: description, amount: amount, date: date, deductible: deductible,
    );
  }

  group('expenseCadence', () {
    test('classifies strata monthly charges as monthly', () {
      expect(expenseCadence(makeLine('maintenance')), ExpenseCadence.monthly);
      expect(expenseCadence(makeLine('sinking_fund')), ExpenseCadence.monthly);
    });
    test('classifies assessment tax as semi-annual', () {
      expect(expenseCadence(makeLine('assessment_tax')), ExpenseCadence.semiAnnual);
      expect(expenseCadence(makeLine('assessment')), ExpenseCadence.semiAnnual);
    });
    test('classifies land-office and insurance charges as annual', () {
      expect(expenseCadence(makeLine('quit_rent')), ExpenseCadence.annual);
      expect(expenseCadence(makeLine('parcel_rent')), ExpenseCadence.annual);
      expect(expenseCadence(makeLine('insurance_premium')), ExpenseCadence.annual);
    });
    test('falls back to category then other', () {
      expect(expenseCadence(makeLine('anything', category: 'insurance')), ExpenseCadence.annual);
      expect(expenseCadence(makeLine('upkeep', category: 'upkeep')), ExpenseCadence.other);
      expect(expenseCadence(makeLine('mystery', category: 'mystery')), ExpenseCadence.other);
    });
  });

  group('groupDirectExpenses', () {
    test('groups monthly charges by month in calendar order', () {
      final grouped = groupDirectExpenses([
        makeLine('maintenance', date: '2025-03-01'),
        makeLine('sinking_fund', date: '2025-01-15'),
        makeLine('maintenance', date: '2025-01-05'),
      ]);
      expect(grouped.monthly.map((g) => g.month), [1, 3]);
      expect(grouped.monthly.first.lines.length, 2); // Jan: maintenance + sinking
      expect(grouped.monthly.last.lines.single.subtype, 'maintenance'); // Mar
    });

    test('separates semi-annual and annual charges from monthly', () {
      final grouped = groupDirectExpenses([
        makeLine('maintenance', date: '2025-02-01'),
        makeLine('assessment_tax', date: '2025-02-15'),
        makeLine('quit_rent', date: '2025'),
        makeLine('upkeep', category: 'upkeep', date: '2025-06-01'),
      ]);
      expect(grouped.monthly.single.month, 2);
      expect(grouped.semiAnnual.single.subtype, 'assessment_tax');
      expect(grouped.annual.single.subtype, 'quit_rent');
      expect(grouped.other.single.subtype, 'upkeep');
    });

    test('undated monthly charges sort into a trailing null-month group', () {
      final grouped = groupDirectExpenses([
        makeLine('maintenance', date: '2025-04-01'),
        makeLine('maintenance', date: null),
      ]);
      expect(grouped.monthly.map((g) => g.month), [4, null]);
    });
  });

  group('deductibleExpenseTotal', () {
    test('sums only deductible lines — the backend excludes the rest from net contribution', () {
      final total = deductibleExpenseTotal([
        makeLine('maintenance', amount: 250.0),
        makeLine('sinking_fund', amount: 50.0),
        makeLine('utilities', amount: 80.0, deductible: false), // tenant pays
        makeLine('late_penalty', amount: 20.0, deductible: false),
      ]);
      expect(total, 300.0);
    });

    test('all-deductible sums everything', () {
      expect(
        deductibleExpenseTotal([makeLine('maintenance', amount: 100.0), makeLine('quit_rent', amount: 50.0)]),
        150.0,
      );
    });
  });

  group('expenseExclusionNote', () {
    test('returns null for a deductible line', () {
      expect(expenseExclusionNote(makeLine('maintenance')), isNull);
    });

    test('flags tenant-paid utilities distinctly', () {
      expect(expenseExclusionNote(makeLine('utilities', deductible: false)), 'Tenant pays — excluded');
    });

    test('flags penalties and capital as not deductible', () {
      expect(expenseExclusionNote(makeLine('late_penalty', deductible: false)), 'Penalty — not deductible');
      expect(expenseExclusionNote(makeLine('renovation', deductible: false)), 'Capital cost — not deductible');
    });

    test('flags first-letting costs as excluded', () {
      expect(expenseExclusionNote(makeLine('agent_commission', deductible: false)), 'First-letting cost — excluded');
    });

    test('falls back to a generic note for any other non-deductible line', () {
      expect(expenseExclusionNote(makeLine('mystery', category: 'mystery', deductible: false)), 'Not deductible');
    });
  });

  group('formatExpenseDate', () {
    test('formats a full ISO date as day-month-year without leading zeros', () {
      expect(formatExpenseDate('2025-03-01'), '1 Mar 2025');
      expect(formatExpenseDate('2025-12-25'), '25 Dec 2025');
    });
    test('formats a year-month as month-year', () {
      expect(formatExpenseDate('2025-06'), 'Jun 2025');
    });
    test('leaves a bare year unchanged', () {
      expect(formatExpenseDate('2025'), '2025');
    });
    test('returns unparseable input unchanged', () {
      expect(formatExpenseDate('sometime'), 'sometime');
    });
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
