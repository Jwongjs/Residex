import 'package:flutter/material.dart';

/// Title Deed color system.
/// Canonical tokens: paper, ink, brass, slate, deedGreen, sealRed, hairline, card.
/// All other fields alias to these for backward compatibility with existing call sites
/// (49+ files reference the legacy names below — do not rename or remove them).
class AppColors {
  // === CANONICAL TOKENS ===
  static const Color paper = Color(0xFFFAFAF7);
  static const Color ink = Color(0xFF1A2438);
  static const Color brass = Color(0xFFB08D4A);
  static const Color slate = Color(0xFF6B7280);
  static const Color deedGreen = Color(0xFF2F7D5D);
  static const Color sealRed = Color(0xFFB4443C);
  static const Color hairline = Color(0xFFE7E5DF);
  static const Color card = Color(0xFFFFFFFF);

  // === LEGACY ALIASES (existing call sites across 33+ screen files) ===
  static const Color background = paper;
  static const Color surface = card;
  static const Color surfaceLight = Color(0xFFF3F1EA); // slightly deeper than paper, for nested surfaces
  static const Color surfaceVariant = Color(0xFFF3F1EA);
  static const Color textPrimary = ink;
  static const Color textSecondary = slate;
  static const Color textMuted = Color(0xFF9CA0AA); // lighter slate for tertiary text
  static const Color textTertiary = textMuted;
  static const Color textDisabled = Color(0xFFC3C6CC);
  static const Color primaryCyan = brass; // legacy "cyan" accent now maps to brass
  static const Color primaryBlue = brass; // legacy secondary accent also maps to brass (single-accent system)
  static const Color primary = brass;
  static const Color primaryLight = Color(0xFFC7A876); // lighter brass tint
  static const Color accent = brass;
  static const Color success = deedGreen;
  static const Color warning = Color(0xFFB08D4A); // brass doubles as warning (no separate amber in this palette)
  static const Color error = sealRed;
  static const Color info = brass;
  static const Color purple = brass; // legacy category-color variety collapses to brass; category badges use icon+label, not hue, to differentiate (see Task 5)
  static const Color orange = brass;
  static const Color border = hairline;
  static const Color borderLight = hairline;
  static const Color cardBackground = card;
  static const Color cardBorder = hairline;
  static const Color deepSpace = paper; // legacy dark-theme name, now light
  static const Color spaceBase = paper;

  // === LEGACY "NEON ACCENT SERIES" ALIASES ===
  // These were the dark-theme's hue-coded accent swatches (category colors, sync-state
  // indicators, avatar gradients, etc.), heavily referenced across maintenance, gamification,
  // community, and portfolio screens. Title Deed is a single-accent (brass) system, so all
  // hues collapse onto the nearest canonical token; visual differentiation in those screens
  // should move to icon/label (tracked in Task 5), not color, but the fields must keep working
  // today with zero call-site changes.
  static const Color amber500 = brass;
  static const Color blue400 = brass;
  static const Color blue500 = brass;
  static const Color blue600 = brass;
  static const Color cyan400 = brass;
  static const Color cyan500 = brass;
  static const Color emerald = deedGreen;
  static const Color emerald400 = deedGreen;
  static const Color emerald500 = deedGreen;
  static const Color indigo300 = brass;
  static const Color indigo400 = brass;
  static const Color indigo500 = brass;
  static const Color orange500 = brass;
  static const Color purple500 = brass;
  static const Color red400 = sealRed;
  static const Color red500 = sealRed;
  static const Color rose500 = sealRed;
  static const Color slate300 = Color(0xFFD1D3D8);
  static const Color slate400 = Color(0xFFAEB1B8);
  static const Color slate500 = slate;
  static const Color slate600 = Color(0xFF565A63);
  static const Color slate700 = Color(0xFF3F434D);
  static const Color slate800 = ink;
  static const Color slate900 = ink;

  // === SYNC STATE COLORS ===
  static const Color syncedBlue = brass;
  static const Color syncedPurple = brass;
  static const Color driftingAmber = brass;
  static const Color driftingOrange = brass;
  static const Color outOfSyncRose = sealRed;
  static const Color outOfSyncRed = sealRed;

  // === AVATAR GRADIENTS ===
  static const List<List<Color>> avatarGradients = [
    [brass, Color(0xFF8F7239)],
    [deedGreen, Color(0xFF255F47)],
    [Color(0xFFC7A876), brass],
    [deedGreen, brass],
    [sealRed, Color(0xFF8F332C)],
    [brass, deedGreen],
  ];

  // === GRADIENTS ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [brass, Color(0xFF8F7239)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
