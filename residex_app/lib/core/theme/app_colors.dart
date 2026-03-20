import 'package:flutter/material.dart';

class AppColors {

  // === PRIMARY COLORS (for compatibility) ===
  static const Color primaryCyan = cyan500;
  static const Color primaryBlue = blue600;

  // === BACKGROUND LAYERS ===
  static const Color deepSpace = Color(0xFF000212);
  static const Color spaceBase = Color(0xFF020617);
  static const Color spaceMid = Color(0xFF0a0a12);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceLight = Color(0xFF13131F);

  // === SYNC STATE COLORS ===
  static const Color syncedBlue = Color(0xFF3B82F6);
  static const Color syncedPurple = Color(0xFFA855F7);
  static const Color driftingAmber = Color(0xFFFBBF24);
  static const Color driftingOrange = Color(0xFFF59E0B);
  static const Color outOfSyncRose = Color(0xFFFB7185);
  static const Color outOfSyncRed = Color(0xFFE11D48);

  // === ACCENT COLORS ===
   // Cyan series
  static const Color cyan300 = Color(0xFF67E8F9);
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan500 = Color(0xFF06B6D4);

  // Emerald series
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);

  // Rose series
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose500 = Color(0xFFF43F5E);

  // Orange series
  static const Color orange500 = Color(0xFFF97316);

  // Purple series
  static const Color purple500 = Color(0xFFA855F7);

  // Indigo series
  static const Color indigo300 = Color(0xFFA5B4FC);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6F00FF);

   // ✅ ADD GREEN SERIES:
  static const Color green400 = Color(0xFF4ADE80);
  static const Color green500 = Color(0xFF10B981);  // For settled/success states
  static const Color green600 = Color(0xFF059669);

  // ✅ ADD RED SERIES:
  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFEF4444);    // For outstanding/error states
  static const Color red600 = Color(0xFFDC2626);

  // Blue series
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);

  // Amber series
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);

  // Slate series
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);  
  static const Color slate800 = Color(0xFF1E293B);  
  static const Color slate900 = Color(0xFF0F172A);

    // Pink series
  static const Color pink400 = Color(0xFFF472B6);
  static const Color pink500 = Color(0xFFEC4899);  // Standard pink
  static const Color pink600 = Color(0xFFDB2777);  // Darker pink
  static const Color pink = pink500;               // Default alias

  // === TEXT COLORS ===
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1); // slate-300
  static const Color textTertiary = Color(0xFF94A3B8);  // slate-400
  static const Color textMuted = Color(0xFF64748B);      // slate-500

  // === GLASSMORPHISM ===
  static const double glassOpacity5 = 0.05;
  static const double glassOpacity10 = 0.10;
  static const double glassOpacity20 = 0.20;

  
   static Color get border => Colors.white.withValues(alpha: 0.1);
   static Color get borderLight => Colors.white.withValues(alpha: 0.15);

   // === BACKGROUND ALIAS ===
   static const Color background = deepSpace;

   // === ADDITIONAL SLATE ===
   static const Color slate300 = Color(0xFFCBD5E1);

   // === ADDITIONAL CYAN ===
   static const Color cyan200 = Color(0xFFBAE6FD);

   // === SEMANTIC ALIASES ===
   static const Color success = emerald500;
   static const Color warning = amber500;
   static const Color error = red500;
   static const Color info = cyan500;
   static const Color orange = orange500;
   static const Color purple = purple500;
   static const Color emerald = emerald500;
   static const Color green = green500;

   // === ADDITIONAL TEXT COLORS ===
   static const Color textDisabled = Color(0xFF475569); // slate-600
   static const Color grey = Color(0xFF9CA3AF);

   // === COLOR ALIASES ===
   static const Color primary = primaryCyan;
   static const Color accent = purple500;
   static const Color primaryLight = cyan400;
   static const Color surfaceVariant = slate800; // Color(0xFF1E293B)

   // === CARD GLASSMORPHISM ===
   static const Color cardBackground = Color(0x0DFFFFFF);
   static const Color cardBorder = Color(0x1A22D3EE);

   // === AVATAR GRADIENTS ===
   static const List<List<Color>> avatarGradients = [
     [Color(0xFF22D3EE), Color(0xFF2563EB)],
     [Color(0xFFA855F7), Color(0xFF6366F1)],
     [Color(0xFFF59E0B), Color(0xFFF97316)],
     [Color(0xFF10B981), Color(0xFF14B8A6)],
     [Color(0xFFF43F5E), Color(0xFFEF4444)],
     [Color(0xFFD946EF), Color(0xFFEC4899)],
   ];

   // === GRADIENTS ===
   static const LinearGradient primaryGradient = LinearGradient(
     colors: [primaryCyan, primaryBlue],
     begin: Alignment.centerLeft,
     end: Alignment.centerRight,
   );

   static const LinearGradient buttonGradient = LinearGradient(
     colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
     begin: Alignment.centerLeft,
     end: Alignment.centerRight,
   );
 }