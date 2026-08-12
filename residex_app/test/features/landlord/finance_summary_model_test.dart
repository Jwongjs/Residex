import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/data/models/finance_summary_model.dart';

void main() {
  final json = {
    'year': 2025,
    'totals': {
      'received_rent': 84000.0,
      'derived_rent': 11000.0,
      'direct_expenses': 59516.87,
      'net_pl': 24483.13,
      'landlord_expenses': 70516.87,
      'statutory_rental_income': 24483.13,
      'statutory_note': 'Estimate — for your tax agent',
    },
    'expense_breakdown': {'loan': 32000.0, 'tax': 1816.87},
    'properties': [
      {
        'property_id': 'p1',
        'name': 'Ayer 8',
        'ownership_share': 0.5,
        'received_rent': 84000.0,
        'derived_rent': 11000.0,
        'direct_expenses': 59516.87,
        'rental_income_or_loss': 24483.13,
        'units': [
          {
            'unit_id': 'u1',
            'label': 'Unit A',
            'rented_months': 11,
            'contribution': 83500.0,
            'months': [
              {'month': 1, 'source': 'actual', 'amount': 7000.0},
              {'month': 2, 'source': 'derived', 'amount': 7000.0},
              {'month': 3, 'source': 'vacant', 'amount': 0.0},
            ],
            'missing_invoice_months': [3],
            'expense_lines': [
              {
                'doc_id': 'd9',
                'category': 'upkeep',
                'subtype': null,
                'description': 'Aircon servicing',
                'amount': 500.0,
                'date': '2025-03-12',
                'unit_id': 'u1',
              }
            ],
          }
        ],
        'expense_lines': [
          {
            'doc_id': 'd1',
            'category': 'loan',
            'subtype': 'interest_statement',
            'description': 'Loan interest',
            'amount': 32000.0,
            'date': '2025',
            'unit_id': null,
          }
        ],
        'property_expense_lines': [
          {
            'doc_id': 'd1',
            'category': 'loan',
            'subtype': 'interest_statement',
            'description': 'Loan interest',
            'amount': 32000.0,
            'date': '2025',
            'unit_id': null,
          }
        ],
      }
    ],
    'caveats': ['Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed.'],
    'missing_categories': {
      'p1': ['insurance', 'maintenance']
    },
  };

  test('fromJson parses the full summary shape', () {
    final summary = FinanceSummaryModel.fromJson(json);
    expect(summary.year, 2025);
    expect(summary.totals.statutoryRentalIncome, 24483.13);
    expect(summary.totals.landlordExpenses, 70516.87);
    expect(summary.totals.statutoryNote, contains('Estimate'));
    expect(summary.expenseBreakdown['loan'], 32000.0);
    final block = summary.properties.single;
    expect(block.name, 'Ayer 8');
    expect(block.ownershipShare, 0.5);
    final unit = block.units.single;
    expect(unit.rentedMonths, 11);
    expect(unit.months[1].source, 'derived');
    expect(unit.missingInvoiceMonths, [3]);
    expect(unit.expenseLines.single.description, 'Aircon servicing');
    expect(block.propertyExpenseLines.single.docId, 'd1');
    expect(summary.missingCategories['p1'], ['insurance', 'maintenance']);
  });

  test('fromJson tolerates missing optional fields', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2026,
      'totals': {
        'received_rent': 0,
        'derived_rent': 0,
        'direct_expenses': 0,
        'net_pl': 0,
        'statutory_rental_income': 0,
        'statutory_note': 'Estimate — for your tax agent',
      },
    });
    expect(summary.properties, isEmpty);
    expect(summary.caveats, isEmpty);
    expect(summary.expenseBreakdown, isEmpty);
  });

  test('fromJson parses coverage and unpaid-month reason', () {
    final summary = FinanceSummaryModel.fromJson({
      ...json,
      'properties': [
        {
          ...((json['properties'] as List<dynamic>)[0] as Map<String, dynamic>),
          'coverage': [
            {'year': 2023, 'missing': ['tax', 'maintenance']},
            {'year': 2024, 'missing': <String>[]},
          ],
          'units': [
            {
              ...((((json['properties'] as List<dynamic>)[0] as Map<String, dynamic>)['units'] as List<dynamic>)[0] as Map<String, dynamic>),
              'months': [
                {'month': 4, 'source': 'unpaid', 'amount': 0.0, 'reason': 'tenant requested deferral'},
              ],
            }
          ],
        }
      ],
    });
    final block = summary.properties.single;
    expect(block.coverage.length, 2);
    expect(block.coverage[0].year, 2023);
    expect(block.coverage[0].missing, ['tax', 'maintenance']);
    expect(block.coverage[1].missing, isEmpty);
    final month = block.units.single.months.single;
    expect(month.source, 'unpaid');
    expect(month.reason, 'tenant requested deferral');
  });

  test('fromJson parses Stage B coverage, completeness, recovery and payment-state fields', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2025,
      'totals': {
        'received_rent': 10000.0,
        'derived_rent': 0.0,
        'outstanding_rent': 3000.0,
        'direct_expenses': 4000.0,
        'net_pl': 6000.0,
        'statutory_rental_income': 6000.0,
        'statutory_note': 'Estimate — for your tax agent',
      },
      'properties': [
        {
          'property_id': 'p1',
          'name': 'Ayer 8',
          'received_rent': 10000.0,
          'derived_rent': 0.0,
          'outstanding_rent': 3000.0,
          'direct_expenses': 4000.0,
          'rental_income_or_loss': 6000.0,
          'complete': false,
          'recovered_rent': [
            {'unit_id': 'u1', 'original_month': '2025-08', 'amount': 3000.0, 'label': 'Recovered rent — Aug 2025'},
          ],
          'coverage': [
            {
              'year': 2025,
              'missing': ['loan'],
              'partial_installments': [
                {'label': 'Assessment tax', 'have': 1, 'expect': 2},
              ],
              'partial_categories': [
                {'category': 'maintenance', 'have': 4, 'expect': 12},
              ],
              'unavailable': ['insurance'],
            },
          ],
          'units': [
            {
              'unit_id': 'u1',
              'label': 'Unit A',
              'rented_months': 12,
              'contribution': 10000.0,
              'months': [
                {
                  'month': 8, 'source': 'unpaid', 'amount': 0.0,
                  'payment_state': 'written_off', 'billed_amount': 3000.0,
                },
              ],
            },
          ],
          'expense_lines': [
            {'doc_id': 'd1', 'category': 'upkeep', 'amount': 137.92, 'deductible': false},
          ],
        }
      ],
    });

    expect(summary.totals.outstandingRent, 3000.0);
    final block = summary.properties.single;
    expect(block.complete, isFalse);
    expect(block.outstandingRent, 3000.0);
    expect(block.recoveredRent.single.label, 'Recovered rent — Aug 2025');
    expect(block.recoveredRent.single.amount, 3000.0);
    final coverage = block.coverage.single;
    expect(coverage.partialInstallments.single.label, 'Assessment tax');
    expect(coverage.partialInstallments.single.have, 1);
    expect(coverage.partialCategories.single.category, 'maintenance');
    expect(coverage.partialCategories.single.expect, 12);
    expect(coverage.unavailable, ['insurance']);
    final month = block.units.single.months.single;
    expect(month.paymentState, 'written_off');
    expect(month.billedAmount, 3000.0);
    expect(block.expenseLines.single.deductible, isFalse);
  });

  test('fromJson defaults complete/deductible to true and outstanding/recovered to empty when absent', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2025,
      'totals': {
        'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
        'net_pl': 0, 'statutory_rental_income': 0,
        'statutory_note': 'Estimate — for your tax agent',
      },
      'properties': [
        {
          'property_id': 'p1', 'name': 'Ayer 8',
          'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
          'rental_income_or_loss': 0,
          'expense_lines': [
            {'doc_id': 'd1', 'category': 'upkeep', 'amount': 100.0},
          ],
        }
      ],
    });
    expect(summary.totals.outstandingRent, 0.0);
    final block = summary.properties.single;
    expect(block.complete, isTrue);
    expect(block.outstandingRent, 0.0);
    expect(block.recoveredRent, isEmpty);
    expect(block.expenseLines.single.deductible, isTrue);
  });

  test('fromJson parses expected_categories', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2025,
      'totals': {
        'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
        'net_pl': 0, 'statutory_rental_income': 0,
        'statutory_note': 'Estimate — for your tax agent',
      },
      'properties': [
        {
          'property_id': 'p1', 'name': 'Ayer 8',
          'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
          'rental_income_or_loss': 0,
          'expected_categories': ['assessment', 'land_office_tax', 'maintenance'],
        }
      ],
    });
    expect(summary.properties.single.expectedCategories,
        ['assessment', 'land_office_tax', 'maintenance']);
  });

  test('parses two-tier fields', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2025,
      'totals': {'received_rent': 12000, 'derived_rent': 0, 'direct_expenses': 8000,
        'net_pl': -4200, 'statutory_rental_income': 4000, 'statutory_note': 'x'},
      'properties': [
        {'property_id': 'p1', 'name': 'Ayer 8', 'received_rent': 12000, 'derived_rent': 0,
         'direct_expenses': 8000, 'rental_income_or_loss': 4000,
         'net_pl': -4200, 'statutory_contribution': 4000,
         'units': [
           {'unit_id': 'u1', 'label': 'A', 'rented_months': 12, 'contribution': -4200,
            'statutory_contribution': 4000, 'months': [], 'expense_lines': [
              {'doc_id': 'd', 'category': 'loan', 'subtype': 'loan_principal',
               'amount': 8000, 'deductible': false, 'paid_by_landlord': true},
            ]},
         ],
         'expense_lines': [], 'property_expense_lines': []},
      ],
    });
    final prop = summary.properties.single;
    expect(prop.netPl, -4200);
    expect(prop.statutoryContribution, 4000);
    final unit = prop.units.single;
    expect(unit.statutoryContribution, 4000);
    expect(unit.expenseLines.single.paidByLandlord, true);
    expect(unit.expenseLines.single.deductible, false);
  });

  test('fromJson parses loan_status and manual_loan_incomplete', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2025,
      'totals': {'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
        'net_pl': 0, 'statutory_rental_income': 0, 'statutory_note': 'x'},
      'properties': [
        {
          'property_id': 'p1', 'name': 'Ayer 8',
          'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
          'rental_income_or_loss': 0,
          'manual_loan_incomplete': true,
          'units': [
            {'unit_id': 'u1', 'label': 'A', 'rented_months': 12, 'contribution': 0,
             'loan_status': 'no_loan', 'months': []},
          ],
        },
      ],
    });
    final block = summary.properties.single;
    expect(block.manualLoanIncomplete, isTrue);
    expect(block.units.single.loanStatus, 'no_loan');
  });

  test('fromJson defaults loan_status/manual_loan_incomplete when absent', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2025,
      'totals': {'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
        'net_pl': 0, 'statutory_rental_income': 0, 'statutory_note': 'x'},
      'properties': [
        {
          'property_id': 'p1', 'name': 'Ayer 8',
          'received_rent': 0, 'derived_rent': 0, 'direct_expenses': 0,
          'rental_income_or_loss': 0,
          'units': [
            {'unit_id': 'u1', 'label': 'A', 'rented_months': 12, 'contribution': 0, 'months': []},
          ],
        },
      ],
    });
    final block = summary.properties.single;
    expect(block.manualLoanIncomplete, isFalse);
    expect(block.units.single.loanStatus, isNull);
  });

  test('parses landlord_expenses and expense-line full_amount', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2026,
      'totals': {
        'received_rent': 500.0,
        'derived_rent': 0.0,
        'direct_expenses': 60.0,
        'net_pl': 440.0,
        'statutory_rental_income': 495.0,
        'statutory_note': '',
      },
      'properties': [
        {
          'property_id': 'p1',
          'name': 'Shared',
          'ownership_share': 0.5,
          'received_rent': 500.0,
          'derived_rent': 0.0,
          'direct_expenses': 60.0,
          'landlord_expenses': 60.0,
          'rental_income_or_loss': 440.0,
          'net_pl': 440.0,
          'expense_lines': [
            {'doc_id': 'd1', 'category': 'tax', 'amount': 60.0, 'full_amount': 120.0},
          ],
        },
      ],
    });
    final property = summary.properties.single;
    expect(property.landlordExpenses, 60.0);
    expect(property.expenseLines.single.fullAmount, 120.0);
  });

  test('full_amount is null when the landlord owns the whole property', () {
    final summary = FinanceSummaryModel.fromJson({
      'year': 2026,
      'totals': {
        'received_rent': 1000.0,
        'derived_rent': 0.0,
        'direct_expenses': 120.0,
        'net_pl': 880.0,
        'statutory_rental_income': 990.0,
        'statutory_note': '',
      },
      'properties': [
        {
          'property_id': 'p1',
          'name': 'Whole',
          'received_rent': 1000.0,
          'derived_rent': 0.0,
          'direct_expenses': 120.0,
          'rental_income_or_loss': 880.0,
          'net_pl': 880.0,
          'expense_lines': [
            {'doc_id': 'd1', 'category': 'tax', 'amount': 120.0},
          ],
        },
      ],
    });
    expect(summary.properties.single.expenseLines.single.fullAmount, isNull);
    // Absent landlord_expenses must default, never crash the Finance tab.
    expect(summary.properties.single.landlordExpenses, 0.0);
  });

  group('share-scaled unit figures', () {
    Map<String, dynamic> summaryJson(Map<String, dynamic> unit) => {
          'year': 2026,
          'properties': [
            {
              'property_id': 'p1',
              'name': 'Block',
              'units': [unit],
            }
          ],
        };

    test('maps gross_income and full_gross_income when both are present', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 12800.0,
        'full_gross_income': 25600.0,
      }));
      final unit = summary.properties.first.units.first;
      expect(unit.grossIncome, 12800.0);
      expect(unit.fullGrossIncome, 25600.0);
    });

    test('full_gross_income absent leaves fullGrossIncome null', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 25600.0,
      }));
      final unit = summary.properties.first.units.first;
      expect(unit.grossIncome, 25600.0);
      expect(unit.fullGrossIncome, isNull);
    });

    test('maps a month row full_amount and full_billed_amount', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 1600.0,
        'full_gross_income': 3200.0,
        'months': [
          {
            'month': 1,
            'source': 'actual',
            'amount': 1600.0,
            'full_amount': 3200.0,
          },
          {
            'month': 3,
            'source': 'unpaid',
            'amount': 0.0,
            'payment_state': 'written_off',
            'billed_amount': 1600.0,
            'full_billed_amount': 3200.0,
          },
        ],
      }));
      final months = summary.properties.first.units.first.months;
      expect(months.first.amount, 1600.0);
      expect(months.first.fullAmount, 3200.0);
      expect(months.last.billedAmount, 1600.0);
      expect(months.last.fullBilledAmount, 3200.0);
    });

    test('a month row without the full_ keys leaves them null', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson({
        'unit_id': 'u1',
        'label': 'A-1',
        'gross_income': 3200.0,
        'months': [
          {'month': 1, 'source': 'actual', 'amount': 3200.0},
        ],
      }));
      final month = summary.properties.first.units.first.months.first;
      expect(month.fullAmount, isNull);
      expect(month.fullBilledAmount, isNull);
    });
  });

  group('unit resolved ownership share', () {
    // Every map literal is explicitly <String, dynamic>: the parser casts
    // nested maps with `as Map<String, dynamic>`, and an inferred
    // Map<dynamic, dynamic> fails that cast at runtime.
    Map<String, dynamic> summaryJson(Map<String, dynamic> unit) =>
        <String, dynamic>{
          'year': 2025,
          'properties': [
            <String, dynamic>{
              'property_id': 'p1',
              'name': 'Block',
              'units': [unit],
            },
          ],
        };

    test('maps ownership_share off a unit block', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson(
        <String, dynamic>{'unit_id': 'u1', 'label': 'A-1', 'ownership_share': 0.5},
      ));

      expect(summary.properties.first.units.first.ownershipShare, 0.5);
    });

    test('an absent ownership_share defaults to full ownership', () {
      final summary = FinanceSummaryModel.fromJson(summaryJson(
        <String, dynamic>{'unit_id': 'u1', 'label': 'A-1'},
      ));

      expect(summary.properties.first.units.first.ownershipShare, 1.0);
    });
  });
}
