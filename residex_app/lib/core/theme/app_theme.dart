import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
export 'app_colors.dart';

  /// App text styles
  class AppTextStyles {
    // === DISPLAY STYLES ===
    static TextStyle get displayLarge => GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    );

    static TextStyle get displayMedium => GoogleFonts.inter( // ✅ ADDED
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    );

    // === HEADLINE STYLES ===
    static TextStyle get headlineLarge => GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    static TextStyle get headlineMedium => GoogleFonts.inter( // ✅ ADDED
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    // === TITLE STYLES ===
    static TextStyle get titleLarge => GoogleFonts.inter( // ✅ ADDED
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    static TextStyle get titleMedium => GoogleFonts.inter( // ✅ ADDED
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );

    // === BODY STYLES ===
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

    // === LABEL STYLES ===
    static TextStyle get labelLarge => GoogleFonts.inter( // ✅ ADDED
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );

    static TextStyle get labelSmall => GoogleFonts.inter( // ✅ ADDED
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
      letterSpacing: 1.2,
    );

    // === ALIASES ===
    static TextStyle get label => labelLarge;
    static TextStyle get heading1 => displayLarge;
    static TextStyle get heading2 => displayMedium;
    static TextStyle get h1 => displayLarge;
    static TextStyle get h2 => displayMedium;
    static TextStyle get h3 => headlineLarge;
    static TextStyle get h4 => headlineMedium;
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
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryCyan, width: 2),
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
      border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.3), width: 1),
    );

    static BoxDecoration get modal => BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.borderLight, width: 1),
    );
  }