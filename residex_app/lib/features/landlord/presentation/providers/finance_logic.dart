import '../../domain/entities/documind_document.dart';
import '../../domain/entities/finance_summary.dart';

/// Currency display: the app formats, never computes.
String formatRM(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}RM $buffer.${parts[1]}';
}

/// Display labels for the 7-category taxonomy (Finance-tab surfaces).
const Map<String, String> financeCategoryLabels = {
  'lease': 'Tenancy agreement',
  'insurance': 'Insurance policy',
  'loan': 'Loan interest statement',
  'tax': 'Assessment tax / quit rent',
  'upkeep': 'Upkeep receipt',
  'maintenance': 'Maintenance statement',
  'rental_invoice': 'Rent invoice',
};

/// Display labels for coverage-report entries, including fine tax
/// subtypes beyond the 7 broad upload categories in [financeCategoryLabels].
/// Must match backend `_TAX_LABELS`/labels in finance_engine.py exactly —
/// [recordCellFor] matches on this text.
const Map<String, String> coverageLabels = {
  ...financeCategoryLabels,
  'assessment': 'Assessment tax',
  'quit_rent': 'Quit rent',
  'parcel_rent': 'Parcel rent',
  'land_office_tax': 'Land-office tax (quit or parcel rent)',
};

/// A coverage-report label (e.g. 'quit_rent', 'land_office_tax') is not
/// itself a valid upload category — typed tax documents are uploaded as
/// 'tax' and the extractor reads the subtype off the bill. This maps a
/// coverage label to the upload category the backend expects.
const Map<String, String> _coverageLabelToUploadCategory = {
  'assessment': 'tax',
  'quit_rent': 'tax',
  'parcel_rent': 'tax',
  'land_office_tax': 'tax',
};

String uploadCategoryFor(String coverageLabel) =>
    _coverageLabelToUploadCategory[coverageLabel] ?? coverageLabel;

/// The coverage row for [year], or null when the property has no tracked
/// years yet (brand new, zero documents).
YearCoverage? yearCoverageFor(List<YearCoverage> coverage, int year) {
  for (final row in coverage) {
    if (row.year == year) return row;
  }
  return null;
}

/// Ranking for the landlord-facing "most damaging first" missing-document
/// ordering (spec §7.1). Lower index sorts first. 'upkeep' is deliberately
/// absent — it is never flagged missing.
const List<String> missingDocumentRank = [
  'lease', 'maintenance', 'loan', 'assessment', 'quit_rent',
  'parcel_rent', 'land_office_tax', 'tax', 'insurance',
];

const Map<String, String> _missingDocumentCostNote = {
  'lease': "derives every month's rent automatically",
  'maintenance': 'usually the largest recurring deduction for strata owners',
  'loan': 'usually the largest single deduction',
  'assessment': 'a required council bill',
  'quit_rent': 'a required land-office bill',
  'parcel_rent': 'a required land-office bill',
  'land_office_tax': 'a required land-office bill',
  'tax': 'a required tax bill',
  'insurance': 'protects against the largest one-off loss',
};

/// Missing-category/tax-subtype labels ordered by landlord impact, not
/// alphabetically. Unranked labels sort after ranked ones, alphabetically
/// among themselves, so a future subtype never disappears from the list.
List<String> rankMissingDocuments(List<String> missing) {
  final ranked = [...missing];
  ranked.sort((a, b) {
    final ra = missingDocumentRank.indexOf(a);
    final rb = missingDocumentRank.indexOf(b);
    if (ra == -1 && rb == -1) return a.compareTo(b);
    if (ra == -1) return 1;
    if (rb == -1) return -1;
    return ra.compareTo(rb);
  });
  return ranked;
}

/// The one-line "N is missing X — cost note" banner for the single most
/// damaging missing item, or null when nothing is missing.
String? topMissingDocumentBanner(int year, List<String> missing) {
  if (missing.isEmpty) return null;
  final top = rankMissingDocuments(missing).first;
  final label = coverageLabels[top] ?? top;
  final note = _missingDocumentCostNote[top];
  return note == null ? '$year is missing your $label' : '$year is missing your $label — $note';
}

const List<String> monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Year-selector options: every year an extracted fact mentions, plus the
/// current year, newest first.
List<int> financeYearOptions(List<DocuMindDocument> docs, int currentYear) {
  final years = <int>{currentYear};

  void addFromDateString(dynamic value) {
    if (value is String && value.length >= 4) {
      final year = int.tryParse(value.substring(0, 4));
      if (year != null && year > 1990 && year < 2200) years.add(year);
    }
  }

  for (final doc in docs) {
    final facts = doc.extractedFacts;
    if (facts == null) continue;
    addFromDateString(facts['period_month']);
    addFromDateString(facts['lease_start']);
    addFromDateString(facts['lease_end']);
    addFromDateString(facts['service_date']);
    addFromDateString(facts['period_start']);
    addFromDateString(facts['policy_start']);
    final periodYear = facts['period_year'];
    if (periodYear is int && periodYear > 1990 && periodYear < 2200) {
      years.add(periodYear);
    }
    final lines = facts['expense_lines'];
    if (lines is List) {
      for (final line in lines) {
        if (line is Map) {
          addFromDateString(line['date']);
          final lineYear = line['period_year'];
          if (lineYear is int && lineYear > 1990 && lineYear < 2200) {
            years.add(lineYear);
          }
        }
      }
    }
  }

  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}
