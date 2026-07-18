/// Pure helper: builds the upload confirmation line from extracted facts.
/// Returns null when nothing is worth confirming — the caller falls back to
/// the generic success message. No emoji (app convention).
String? uploadFactSummary(String category, Map<String, dynamic>? facts) {
  if (facts == null || facts.isEmpty) return null;

  String? money(dynamic value) =>
      value is num ? 'RM ${value.toStringAsFixed(2)}' : null;

  switch (category) {
    case 'lease':
      final end = facts['lease_end'];
      final rent = money(facts['monthly_rent']);
      if (rent != null && end is String) return 'Tenancy recorded — $rent/mo, ends $end';
      if (end is String) return 'Tenancy recorded — ends $end';
      if (rent != null) return 'Tenancy recorded — $rent/mo';
      return null;
    case 'rental_invoice':
      final amount = money(facts['amount']);
      final month = facts['period_month'];
      if (amount != null && month is String) {
        return 'Rent invoice recorded — $amount for $month';
      }
      return amount != null ? 'Rent invoice recorded — $amount' : null;
    case 'loan':
      final interest = money(facts['interest_paid']);
      final year = facts['period_year'];
      if (interest != null && year is int) return 'Loan interest recorded — $interest, $year';
      return interest != null ? 'Loan interest recorded — $interest' : null;
    case 'tax':
      final amount = money(facts['amount']);
      final year = facts['period_year'];
      final subtype = switch (facts['subtype']) {
        'assessment' => 'Assessment tax',
        'quit_rent' => 'Quit rent',
        'parcel_rent' => 'Parcel rent',
        _ => 'Tax bill',
      };
      if (amount != null && year is int) return '$subtype recorded — $amount, $year';
      return amount != null ? '$subtype recorded — $amount' : null;
    case 'upkeep':
      final amount = money(facts['amount']);
      return amount != null ? 'Upkeep expense recorded — $amount' : null;
    case 'maintenance':
      final amount = money(facts['amount']);
      return amount != null ? 'Maintenance charge recorded — $amount' : null;
    case 'insurance':
      final end = facts['policy_end'];
      final premium = money(facts['premium']);
      if (premium != null && end is String) return 'Policy recorded — $premium, expires $end';
      if (end is String) return 'Policy recorded — expires $end';
      return premium != null ? 'Policy recorded — $premium' : null;
    case 'expenses':
      final lines = facts['expense_lines'];
      if (lines is List && lines.isNotEmpty) {
        var total = 0.0;
        for (final line in lines) {
          final amount = line is Map ? line['amount'] : null;
          if (amount is num) total += amount;
        }
        final noun = lines.length == 1 ? 'expense' : 'expenses';
        return '${lines.length} $noun recorded — RM ${total.toStringAsFixed(2)} total';
      }
      return null;
  }
  return null;
}
