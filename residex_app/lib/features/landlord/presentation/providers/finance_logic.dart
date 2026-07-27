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

/// Maps a coverage-report category code to the raw tax-subtype display
/// labels (`InstallmentGap.label`) that could produce a partial-installment
/// gap for it. Composite/fallback categories (a strata `land_office_tax`
/// slot, or the profile-less generic `tax` bucket) can be satisfied by more
/// than one raw subtype — matching only the composite's own display text
/// would silently miscount a real installment gap, since the backend never
/// emits a `land_office_tax`-labeled gap (only 'Assessment tax' / 'Quit
/// rent' / 'Parcel rent' / the 'Property tax' fallback, per `_TAX_LABELS`
/// in `finance_engine.py`). Shared by `recordCellFor` (records_grid.dart)
/// and `yearCompleteness` below — both need the identical match, not two
/// independently-maintained copies of it.
const Map<String, Set<String>> installmentLabelsForCategory = {
  'assessment': {'Assessment tax'},
  'quit_rent': {'Quit rent'},
  'parcel_rent': {'Parcel rent'},
  'land_office_tax': {'Quit rent', 'Parcel rent'},
  'tax': {'Assessment tax', 'Quit rent', 'Parcel rent', 'Property tax'},
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

/// Slot-level completeness for one year, used by the property-card
/// indicator ("2025: 8 of 14") — counts maintenance's 12 months and a
/// tax's N installments as separate slots, not one flat category each.
({int have, int expect}) yearCompleteness(
    YearCoverage coverage, List<String> expectedCategories) {
  var have = 0;
  var expect = 0;
  for (final category in expectedCategories) {
    if (coverage.unavailable.contains(category)) {
      expect += 1;
      have += 1;
      continue;
    }
    if (category == 'maintenance') {
      final partial = coverage.partialCategories.where((p) => p.category == 'maintenance');
      if (partial.isNotEmpty) {
        expect += partial.first.expect;
        have += partial.first.have;
      } else {
        expect += 12;
        have += coverage.missing.contains('maintenance') ? 0 : 12;
      }
      continue;
    }
    final matchLabels = installmentLabelsForCategory[category] ?? {coverageLabels[category] ?? category};
    final gap = coverage.partialInstallments.where((g) => matchLabels.contains(g.label));
    if (gap.isNotEmpty) {
      expect += gap.first.expect;
      have += gap.first.have;
      continue;
    }
    expect += 1;
    have += coverage.missing.contains(category) ? 0 : 1;
  }
  return (have: have, expect: expect);
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
  'rental_invoice': 'confirms rent actually received for the month',
  'upkeep': 'a minor repair cost, still deductible',
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

/// The cost-note subtitle for a single missing-category row (used by the
/// missing-documents sheet), or null when the category has none.
String? missingDocumentCostNote(String category) => _missingDocumentCostNote[category];

/// The one-line "N is missing X — cost note" banner for the single most
/// damaging missing item, or null when nothing is missing.
String? topMissingDocumentBanner(int year, List<String> missing) {
  if (missing.isEmpty) return null;
  final top = rankMissingDocuments(missing).first;
  final label = coverageLabels[top] ?? top;
  final note = _missingDocumentCostNote[top];
  return note == null ? '$year is missing your $label' : '$year is missing your $label — $note';
}

/// Presentation-only monthly net-movement shape for the hero sparkline.
/// Never rendered as a number anywhere — `totals.netPl` remains the only
/// displayed total.
List<double> monthlyNetSeries(FinanceSummary summary) {
  final months = List<double>.filled(12, 0.0);
  final activity = List<bool>.filled(12, false);

  for (final property in summary.properties) {
    for (final unit in property.units) {
      for (final month in unit.months) {
        if (month.source != 'actual' && month.source != 'derived') continue;
        final index = month.month - 1;
        if (index < 0 || index > 11) continue;
        months[index] += month.amount;
        activity[index] = true;
      }
    }
    for (final line in property.expenseLines) {
      final date = line.date;
      if (date == null || date.length < 7) continue;
      final year = int.tryParse(date.substring(0, 4));
      final month = int.tryParse(date.substring(5, 7));
      if (year != summary.year || month == null || month < 1 || month > 12) {
        continue;
      }
      final index = month - 1;
      months[index] -= line.amount;
      activity[index] = true;
    }
  }

  var lastActive = -1;
  for (var i = 0; i < 12; i++) {
    if (activity[i]) lastActive = i;
  }
  if (lastActive < 0) return const [];

  final trimmed = months.sublist(0, lastActive + 1);
  final activeCount = activity.sublist(0, lastActive + 1).where((a) => a).length;
  if (activeCount < 2) return const [];
  return trimmed;
}

const List<String> monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// How often a direct expense recurs, used to split the Direct Expenses
/// breakdown into sections: monthly strata charges (grouped by month),
/// semi-annual council bills, annual land-office/insurance bills, and any
/// one-off remainder. The extractor never emits an explicit cadence, so it
/// is derived from the line's subtype, falling back to its category.
enum ExpenseCadence { monthly, semiAnnual, annual, other }

const Map<String, ExpenseCadence> _cadenceBySubtype = {
  'maintenance': ExpenseCadence.monthly,
  'sinking_fund': ExpenseCadence.monthly,
  'management_fee': ExpenseCadence.monthly,
  'rent_collection': ExpenseCadence.monthly,
  'security_fee': ExpenseCadence.monthly,
  'assessment': ExpenseCadence.semiAnnual,
  'assessment_tax': ExpenseCadence.semiAnnual,
  'quit_rent': ExpenseCadence.annual,
  'parcel_rent': ExpenseCadence.annual,
  'insurance_premium': ExpenseCadence.annual,
};

const Map<String, ExpenseCadence> _cadenceByCategory = {
  'maintenance': ExpenseCadence.monthly,
  'insurance': ExpenseCadence.annual,
};

ExpenseCadence expenseCadence(ExpenseLine line) {
  final subtype = line.subtype;
  if (subtype != null && _cadenceBySubtype.containsKey(subtype)) {
    return _cadenceBySubtype[subtype]!;
  }
  return _cadenceByCategory[line.category] ?? ExpenseCadence.other;
}

/// The 1-12 month an expense line falls in, or null when its date carries no
/// month (a bare 'YYYY' string, as tax lines use).
int? expenseLineMonth(ExpenseLine line) {
  final date = line.date;
  if (date == null || date.length < 7) return null;
  final month = int.tryParse(date.substring(5, 7));
  if (month == null || month < 1 || month > 12) return null;
  return month;
}

/// One month's worth of monthly-cadence expense lines. [month] is null for
/// lines whose date carries no month; those sort last.
class ExpenseMonthGroup {
  final int? month;
  final List<ExpenseLine> lines;
  const ExpenseMonthGroup(this.month, this.lines);
}

/// The Direct Expenses breakdown split by cadence. Monthly charges are
/// grouped by month in calendar order (a null-month group, if any, sorts
/// last); the other three lists preserve input order. Duplicate collapsing
/// happens in the backend fold — this is display-shaping only.
class GroupedDirectExpenses {
  final List<ExpenseMonthGroup> monthly;
  final List<ExpenseLine> semiAnnual;
  final List<ExpenseLine> annual;
  final List<ExpenseLine> other;
  const GroupedDirectExpenses({
    this.monthly = const [],
    this.semiAnnual = const [],
    this.annual = const [],
    this.other = const [],
  });
}

GroupedDirectExpenses groupDirectExpenses(List<ExpenseLine> lines) {
  final byMonth = <int?, List<ExpenseLine>>{};
  final semiAnnual = <ExpenseLine>[];
  final annual = <ExpenseLine>[];
  final other = <ExpenseLine>[];

  for (final line in lines) {
    switch (expenseCadence(line)) {
      case ExpenseCadence.monthly:
        byMonth.putIfAbsent(expenseLineMonth(line), () => []).add(line);
        break;
      case ExpenseCadence.semiAnnual:
        semiAnnual.add(line);
        break;
      case ExpenseCadence.annual:
        annual.add(line);
        break;
      case ExpenseCadence.other:
        other.add(line);
        break;
    }
  }

  final months = byMonth.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });

  return GroupedDirectExpenses(
    monthly: [for (final m in months) ExpenseMonthGroup(m, byMonth[m]!)],
    semiAnnual: semiAnnual,
    annual: annual,
    other: other,
  );
}

/// The Direct Expenses figure shown in the accordion: the sum of only the
/// deductible lines. This must mirror the backend's net-contribution fold
/// (finance_engine `unit_expense_total`) so the displayed total, the listed
/// rows and net contribution all agree — the app never recomputes a figure
/// the backend already decided, and a non-deductible line (tenant-paid
/// utilities, a penalty, a capital cost) must never inflate this total.
double deductibleExpenseTotal(List<ExpenseLine> lines) {
  return lines
      .where((l) => l.deductible)
      .fold<double>(0, (sum, l) => sum + l.amount);
}

/// The Overall Net P/L direct-expenses figure: the sum of lines the landlord
/// actually pays (deductible or not). Mirrors the backend Net P/L fold; the
/// per-unit `contribution` equals gross minus this.
double landlordPaidExpenseTotal(List<ExpenseLine> lines) {
  return lines
      .where((l) => l.paidByLandlord)
      .fold<double>(0, (sum, l) => sum + l.amount);
}

// Why a non-deductible line is excluded, keyed off the same rules the backend
// applies (`_line_deductible`): utilities the tenant bears, statutory
// non-deductibles, capital outlay, and first-letting costs. Shown beside the
// line so an excluded charge stays visible and correctable rather than
// silently vanishing.
const Set<String> _firstLettingSubtypes = {
  'agent_commission', 'legal_fee', 'stamp_duty', 'advertising',
};

/// A short reason a line is kept out of the deductible total, or null when the
/// line is deductible. The line still renders (marked) so the landlord can
/// spot a mis-tagged charge.
String? expenseExclusionNote(ExpenseLine line) {
  if (line.deductible) return null;
  final subtype = line.subtype;
  if (subtype == 'utilities') return 'Tenant pays — excluded';
  if (subtype == 'late_penalty') return 'Penalty — not deductible';
  if (subtype == 'renovation' || subtype == 'loan_principal') {
    return 'Capital cost — not deductible';
  }
  if (subtype != null && _firstLettingSubtypes.contains(subtype)) {
    return 'First-letting cost — excluded';
  }
  return 'Not deductible';
}

/// One consistent display for an extracted date, whatever ISO precision it
/// carries: 'YYYY-MM-DD' -> '1 Mar 2025', 'YYYY-MM' -> 'Mar 2025', a bare
/// 'YYYY' -> '2025'. Anything else is returned unchanged (defensive). Storage
/// is normalised to ISO at extraction; this is the single reader-side format.
String formatExpenseDate(String raw) {
  final year = int.tryParse(raw.length >= 4 ? raw.substring(0, 4) : raw);
  if (year == null || year < 1990 || year > 2200) return raw;
  if (raw.length >= 7) {
    final month = int.tryParse(raw.substring(5, 7));
    if (month == null || month < 1 || month > 12) return raw;
    if (raw.length >= 10) {
      final day = int.tryParse(raw.substring(8, 10));
      if (day != null && day >= 1 && day <= 31) {
        return '$day ${monthAbbrev[month - 1]} $year';
      }
    }
    return '${monthAbbrev[month - 1]} $year';
  }
  if (raw.length == 4) return raw;
  return raw;
}

/// Year-selector options: every year an extracted fact mentions, plus the
/// current year, newest first. A document's years are filtered against its own
/// property's [trackFromByProperty] floor (the "show financials from year N"
/// setting), so e.g. a 2023 lease on a property tracked only from 2025 never
/// resurfaces 2023 in the selector. The floor is per-property; the current year
/// is always offered.
List<int> financeYearOptions(
  List<DocuMindDocument> docs,
  int currentYear, {
  Map<String, int?> trackFromByProperty = const {},
}) {
  final years = <int>{currentYear};

  for (final doc in docs) {
    final facts = doc.extractedFacts;
    if (facts == null) continue;

    final docYears = <int>{};
    void addFromDateString(dynamic value) {
      if (value is String && value.length >= 4) {
        final year = int.tryParse(value.substring(0, 4));
        if (year != null && year > 1990 && year < 2200) docYears.add(year);
      }
    }

    addFromDateString(facts['period_month']);
    addFromDateString(facts['lease_start']);
    addFromDateString(facts['lease_end']);
    addFromDateString(facts['service_date']);
    addFromDateString(facts['period_start']);
    addFromDateString(facts['policy_start']);
    final periodYear = facts['period_year'];
    if (periodYear is int && periodYear > 1990 && periodYear < 2200) {
      docYears.add(periodYear);
    }
    final lines = facts['expense_lines'];
    if (lines is List) {
      for (final line in lines) {
        if (line is Map) {
          addFromDateString(line['date']);
          final lineYear = line['period_year'];
          if (lineYear is int && lineYear > 1990 && lineYear < 2200) {
            docYears.add(lineYear);
          }
        }
      }
    }

    final floor = trackFromByProperty[doc.propertyId];
    for (final year in docYears) {
      if (floor == null || year >= floor) years.add(year);
    }
  }

  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}
