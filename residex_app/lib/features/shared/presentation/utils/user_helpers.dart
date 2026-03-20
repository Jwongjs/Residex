  
  class UserHelpers {
    /// Create initials from name (2 letters)
    static String generateInitials(String name) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }

    /// Generate random color for avatar (returns List of int for gradientColorValues)
    static List<int> generateGradientColors(String name) {
      final colors = [
        [0xFF22D3EE, 0xFF06B6D4], // Cyan gradient
        [0xFFEC4899, 0xFFDB2777], // Pink gradient
        [0xFFF59E0B, 0xFFD97706], // Amber gradient
        [0xFF10B981, 0xFF059669], // Emerald gradient
        [0xFF6366F1, 0xFF4F46E5], // Indigo gradient
        [0xFF8B5CF6, 0xFF7C3AED], // Purple gradient
        [0xFFEF4444, 0xFFDC2626], // Red gradient
        [0xFF3B82F6, 0xFF2563EB], // Blue gradient
      ];
      return colors[name.hashCode % colors.length];
    }

    /// Validate phone number (basic - at least 8 digits)
    static bool isValidPhone(String phone) {
      final cleaned = phone.replaceAll(RegExp(r'\D'), '');
      return cleaned.length >= 8;
    }
  }