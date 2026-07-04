import 'package:flutter/material.dart';

/// Title Deed color system — "Registry Green" palette.
/// Canonical tokens: paper, ink, registry, slate, deedGreen, sealRed, hairline, card.
/// All other fields alias to these for backward compatibility with existing call sites
/// (49+ files reference the legacy names below — do not rename or remove them).
class AppColors {
  // === CANONICAL TOKENS ===
  static const Color paper = Color(0xFFF6F7F5);
  static const Color ink = Color(0xFF101826);
  static const Color registry = Color(0xFF1D6A4E);
  static const Color slate = Color(0xFF57606E);
  static const Color deedGreen = Color(0xFF2E7D5B);
  static const Color sealRed = Color(0xFFA83A32);
  static const Color hairline = Color(0xFFD6DAD3);
  static const Color card = Color(0xFFFFFFFF);

  // === DOCUMENT CATEGORY COLORS (muted, documentary hues) ===
  static const Color catLease = registry; // deep green
  static const Color catWarranty = Color(0xFF44519E); // indigo
  static const Color catInsurance = Color(0xFF8C3A32); // oxblood
  static const Color catUtility = Color(0xFF96690F); // ochre
  static const Color catReceipt = Color(0xFF6E4A8C); // plum
  static const Color catOther = slate;

  // === LEGACY ALIASES (existing call sites across 33+ screen files) ===
  static const Color background = paper;
  static const Color surface = card;
  static const Color surfaceLight = Color(0xFFEDEFEA); // slightly deeper than paper, for nested surfaces
  static const Color surfaceVariant = Color(0xFFEDEFEA);
  static const Color textPrimary = ink;
  static const Color textSecondary = slate;
  static const Color textMuted = Color(0xFF6E7683); // darker slate for tertiary text (contrast fix)
  static const Color textTertiary = textMuted;
  static const Color textDisabled = Color(0xFFA8ADB5);
  static const Color primaryCyan = registry; // legacy "cyan" accent now maps to registry
  static const Color primaryBlue = registry; // legacy secondary accent also maps to registry (single-accent system)
  static const Color primary = registry;
  static const Color primaryLight = Color(0xFF3E8A6C); // lighter registry tint
  static const Color accent = registry;
  static const Color success = deedGreen;
  static const Color warning = Color(0xFF96690F); // ochre — a green "warning" reads wrong next to registry
  static const Color error = sealRed;
  static const Color info = registry;
  static const Color purple = registry; // legacy category-color variety collapses to registry; category badges use icon+label, not hue, to differentiate (see Task 5)
  static const Color orange = registry;
  static const Color border = hairline;
  static const Color borderLight = hairline;
  static const Color cardBackground = card;
  static const Color cardBorder = hairline;
  static const Color deepSpace = paper; // legacy dark-theme name, now light
  static const Color spaceBase = paper;

  // === LEGACY "NEON ACCENT SERIES" ALIASES ===
  // These were the dark-theme's hue-coded accent swatches (category colors, sync-state
  // indicators, avatar gradients, etc.), heavily referenced across maintenance, gamification,
  // community, and portfolio screens. Title Deed is a single-accent (registry) system, so all
  // hues collapse onto the nearest canonical token; visual differentiation in those screens
  // should move to icon/label (tracked in Task 5), not color, but the fields must keep working
  // today with zero call-site changes.
  static const Color amber500 = registry;
  static const Color blue400 = registry;
  static const Color blue500 = registry;
  static const Color blue600 = registry;
  static const Color cyan400 = registry;
  static const Color cyan500 = registry;
  static const Color emerald = deedGreen;
  static const Color emerald400 = deedGreen;
  static const Color emerald500 = deedGreen;
  static const Color indigo300 = registry;
  static const Color indigo400 = registry;
  static const Color indigo500 = registry;
  static const Color orange500 = registry;
  static const Color purple500 = registry;
  static const Color red400 = sealRed;
  static const Color red500 = sealRed;
  static const Color rose500 = sealRed;
  static const Color slate300 = Color(0xFFC9CDD3);
  static const Color slate400 = Color(0xFF9BA1AB);
  static const Color slate500 = slate;
  static const Color slate600 = Color(0xFF454D59);
  static const Color slate700 = Color(0xFF303743);
  static const Color slate800 = ink;
  static const Color slate900 = ink;

  // === SYNC STATE COLORS ===
  static const Color syncedBlue = registry;
  static const Color syncedPurple = registry;
  static const Color driftingAmber = registry;
  static const Color driftingOrange = registry;
  static const Color outOfSyncRose = sealRed;
  static const Color outOfSyncRed = sealRed;

  // === AVATAR GRADIENTS ===
  static const List<List<Color>> avatarGradients = [
    [registry, Color(0xFF14503A)],
    [deedGreen, Color(0xFF1D5A42)],
    [Color(0xFF3E8A6C), registry],
    [deedGreen, registry],
    [sealRed, Color(0xFF7A2A24)],
    [registry, deedGreen],
  ];

  // === GRADIENTS ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [registry, Color(0xFF14503A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
