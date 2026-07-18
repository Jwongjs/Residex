import '../../domain/entities/documind_document.dart';

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
