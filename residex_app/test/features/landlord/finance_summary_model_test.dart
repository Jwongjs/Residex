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
}
