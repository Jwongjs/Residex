import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class GamificationTheme {
  // Colors
  static const Color gridOverlay = Color(0x0DFFFFFF); // 5% white
  static const Color scanlineColor = Color(0x08FFFFFF); // 3% white

  // Text styles with aggressive weights
  static TextStyle get protocolLabel => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w900, // 900 weight!
    letterSpacing: 4.0,
    color: AppColors.primaryCyan,
  );

  static TextStyle get massiveRank => GoogleFonts.inter(
    fontSize: 120,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    height: 0.85,
  );

  // Border radius - more extreme
  static const double extremeRadius = 32.0;

  // Shadows - more dramatic
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: AppColors.primaryCyan.withValues(alpha: 0.4),
      blurRadius: 30,
      spreadRadius: 5,
    ),
  ];
}