import 'package:intl/intl.dart';

/// Currency formatting utilities
class CurrencyFormatter {
  /// Format: RM 1,500.00
  static String format(double amount, {String currency = 'RM'}) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '$currency ${formatter.format(amount)}';
  }

  /// Format: RM 1.5k
  static String formatCompact(double amount, {String currency = 'RM'}) {
    if (amount >= 1000000) {
      return '$currency ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$currency ${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return format(amount, currency: currency);
    }
  }

  /// Format: +15.5% or -5.2%
  static String formatPercentage(double percentage) {
    final sign = percentage >= 0 ? '+' : '';
    return '$sign${percentage.toStringAsFixed(1)}%';
  }

  /// Format: 1,500 (no decimals)
  static String formatInteger(int amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount);
  }
}