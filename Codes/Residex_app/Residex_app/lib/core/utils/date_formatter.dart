import 'package:intl/intl.dart';

/// Date formatting utilities
class DateFormatter {
  /// Format: Jan 28, 2024
  static String formatShort(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format: January 28, 2024
  static String formatLong(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  /// Format: 28/01/2024
  static String formatSlash(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format: 2h ago, 3d ago
  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Format: Monday, Jan 28
  static String formatDayMonth(DateTime date) {
    return DateFormat('EEEE, MMM dd').format(date);
  }
}