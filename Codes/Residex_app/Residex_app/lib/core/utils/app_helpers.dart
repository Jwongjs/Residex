import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Common helper functions
class AppHelpers {
  /// Get initials from name (e.g., "John Doe" → "JD")
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  /// Calculate percentage
  static double calculatePercentage(num value, num total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  /// Get color for health score
  static Color getHealthScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  /// Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
      case 'paid':
      case 'active':
        return AppColors.success;
      case 'vacant':
      case 'pending':
        return AppColors.warning;
      case 'maintenance':
      case 'overdue':
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}