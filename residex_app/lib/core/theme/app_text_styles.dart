import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // === HERO TEXT ===
  static TextStyle get hero => GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.0,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  // === HEADERS ===
  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  // ✅ ADD H4:
  static TextStyle get h4 => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  // ✅ ADD BODY TEXT STYLES:
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textTertiary,
  );

  // === LABELS (ALL CAPS) ===
  static TextStyle get sectionLabel => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    color: AppColors.textMuted,
  ).copyWith(textBaseline: TextBaseline.alphabetic);

  // === MONO (NUMBERS/SCORES) ===
  static TextStyle get scoreMono => GoogleFonts.robotoMono(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  // === DISPLAY TEXT (Extra Large) ===
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 57,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.5,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 45,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.0,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  static TextStyle get displaySmall => GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    color: AppColors.textPrimary,
  );

  // === HEADLINES ===
  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineSmall => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );
}