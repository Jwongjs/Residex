import 'package:intl/intl.dart';

  extension DoubleExtensions on double {
    String toCurrency() {
      return 'RM${toStringAsFixed(2)}';
    }
  }

  extension DateTimeExtensions on DateTime {
    String toShortDate() {
      return DateFormat('MMM dd').format(this);
    }

    String toLongDate() {
      return DateFormat('MMM dd, yyyy').format(this);
    }
  }

  extension StringExtensions on String {
    String capitalize() {
      if (isEmpty) return this;
      return '${this[0].toUpperCase()}${substring(1)}';
    }
  }
