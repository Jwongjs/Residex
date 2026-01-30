import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette - Dark theme with cyan/blue accents
class AppColors {
  // Background colors
  static const Color background = Color(0xFF000212); // Deep Midnight Blue
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceLight = Color(0xFF1E293B);

  // Slate colors for glass effects
  static Color get slate800 => const Color(0xFF1E293B);
  static Color get slate700 => const Color(0xFF334155);
  static Color get slate900 => const Color(0xFF0F172A);

  // Primary gradient colors
  static const Color primaryCyan = Color(0xFF06B6D4); // Cyan 500
  static const Color primaryBlue = Color(0xFF2563EB); // Blue 600
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan200 = Color(0xFFBAE6FD);

  // Accent colors
  static const Color success = Color(0xFF10B981);
  static const Color emerald = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);
  static const Color orange = Color(0xFFF97316);
  static const Color purple = Color(0xFFA855F7); // Purple 500
  static const Color green = Color(0xFF10B981); // Green (alias for emerald)

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color grey = Color(0xFF9CA3AF);

  // Border/divider
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF334155);

  // Card glassmorphism
  static const Color cardBackground = Color(0x0DFFFFFF); // 5% white
  static const Color cardBorder = Color(0x1A22D3EE); // 10% cyan

  // Avatar gradient colors
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF22D3EE), Color(0xFF2563EB)], // Cyan to Blue
    [Color(0xFFA855F7), Color(0xFF6366F1)], // Purple to Indigo
    [Color(0xFFF59E0B), Color(0xFFF97316)], // Amber to Orange
    [Color(0xFF10B981), Color(0xFF14B8A6)], // Emerald to Teal
    [Color(0xFFF43F5E), Color(0xFFEF4444)], // Rose to Red
    [Color(0xFFD946EF), Color(0xFFEC4899)], // Fuchsia to Pink
  ];

  // Primary gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Button gradient (Cyan to Blue)
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// App text styles
class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 1.2,
  );
}

/// App theme data
class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryCyan,
      secondary: AppColors.primaryBlue,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    textTheme: TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelSmall: AppTextStyles.labelSmall,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.headlineMedium,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
    ),
  );
}

/// Glassmorphism decoration helper
class GlassDecoration {
  static BoxDecoration get card => BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.cardBorder, width: 1),
  );

  static BoxDecoration get cardHighlight => BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.primaryCyan.withValues(alpha:0.3), width: 1),
  );

  static BoxDecoration get modal => BoxDecoration(
    color: AppColors.surface.withValues(alpha:0.95),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: AppColors.borderLight, width: 1),
  );
}
