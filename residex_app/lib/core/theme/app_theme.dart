import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
export 'app_colors.dart';

  /// App text styles — Title Deed type system.
  /// Display: Fraunces (serif) for titles and big figures.
  /// Body: IBM Plex Sans for all readable text.
  /// Utility (mono): IBM Plex Mono for filenames, scores, category tags — used directly via GoogleFonts.ibmPlexMono() at call sites that need it, not aliased here.
  class AppTextStyles {
    // === DISPLAY STYLES (Fraunces) ===
    static TextStyle get displayLarge => GoogleFonts.fraunces(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    static TextStyle get displayMedium => GoogleFonts.fraunces(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    // === HEADLINE STYLES (Fraunces) ===
    static TextStyle get headlineLarge => GoogleFonts.fraunces(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    static TextStyle get headlineMedium => GoogleFonts.fraunces(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    // === TITLE STYLES (IBM Plex Sans, semibold — body face but heavier) ===
    static TextStyle get titleLarge => GoogleFonts.ibmPlexSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    static TextStyle get titleMedium => GoogleFonts.ibmPlexSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    // === BODY STYLES (IBM Plex Sans) ===
    static TextStyle get bodyLarge => GoogleFonts.ibmPlexSans(
      fontSize: 15,
      fontWeight: FontWeight.normal,
      color: AppColors.textPrimary,
      height: 1.5,
    );

    static TextStyle get bodyMedium => GoogleFonts.ibmPlexSans(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: AppColors.textSecondary,
      height: 1.4,
    );

    static TextStyle get bodySmall => GoogleFonts.ibmPlexSans(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: AppColors.textMuted,
      height: 1.3,
    );

    // === LABEL STYLES ===
    static TextStyle get labelLarge => GoogleFonts.ibmPlexSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );

    static TextStyle get labelSmall => GoogleFonts.ibmPlexSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
      letterSpacing: 0.4,
    );

    // === ALIASES (existing call sites) ===
    static TextStyle get label => labelLarge;
    static TextStyle get heading1 => displayLarge;
    static TextStyle get heading2 => displayMedium;
    static TextStyle get h1 => displayLarge;
    static TextStyle get h2 => displayMedium;
    static TextStyle get h3 => headlineLarge;
    static TextStyle get h4 => headlineMedium;
  }

  /// App theme data — Title Deed light theme.
  class AppTheme {
    static ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brass,
        secondary: AppColors.brass,
        surface: AppColors.card,
        error: AppColors.sealRed,
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
        backgroundColor: AppColors.paper,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineMedium,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brass,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brass, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  /// Hairline card decoration helper (replaces GlassDecoration)
  class CardDecoration {
    static BoxDecoration get flat => BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairline, width: 1),
    );

    static BoxDecoration get flatHighlight => BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.brass.withValues(alpha: 0.4), width: 1),
    );
  }
