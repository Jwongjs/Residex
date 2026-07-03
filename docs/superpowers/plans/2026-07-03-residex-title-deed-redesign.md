# ResiDex "Title Deed" Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand and redesign the ResiDex Flutter app to the "Title Deed" visual system (paper/ink/brass palette, Fraunces + IBM Plex type), reduce navigation to 3 tabs (Dashboard, Documind, Portfolio), make auth landlord-only, and delete every screen with no working functionality.

**Architecture:** Because most surviving screens (`documind_screen.dart`, `landlord_portfolio_screen.dart`, and their sub-widgets) already route all color/type through `AppColors`/`AppTextStyles` static getters in `lib/core/theme/`, redefining those token files propagates the new look across the app without touching most screen files. The two auth screens and the dashboard are hand-styled with hardcoded hex values and need direct rewrites. Dead screens are deleted outright along with their routes/imports.

**Tech Stack:** Flutter 3.41.1, Riverpod, go_router, `google_fonts` (already a dependency — Fraunces/IBM Plex Sans/IBM Plex Mono are Google Fonts, no new package needed).

## Global Constraints

- `flutter analyze` must show 0 errors after every task (existing baseline: 0 errors, ~475 info/warning issues — acceptable to keep, do not introduce new errors)
- No hardcoded hex colors in screen files after this plan — all color/type through `AppColors`/`AppTextStyles`
- No references to tenant, lease generation, finance, or community may remain in UI copy or navigation after Task 2
- Every deleted screen's routes, `AppRoutes` constants, and imports must be removed in the same task as the deletion (no orphaned route strings)
- Sentence case copy; buttons name the action they perform (spec's writing rules)
- Respect `MediaQuery.of(context).disableAnimations` for the one signature motion moment (Documind answer card)
- `UserRole` enum keeps both values (`tenant`, `landlord`) for data-model compatibility — only UI selection of tenant is removed, not the enum itself

---

### Task 1: Rebuild design tokens (colors, text styles, theme)

**Files:**
- Modify: `residex_app/lib/core/theme/app_colors.dart` (full rewrite of color constants)
- Modify: `residex_app/lib/core/theme/app_theme.dart` (rewrite `AppTextStyles` class embedded here — this is the ONE actually imported by 33 files — and `AppTheme.darkTheme` → rename usage to a light theme; keep the class name `AppTheme` and getter name to minimize call-site churn, but change its content)
- Delete: `residex_app/lib/core/theme/app_gradients.dart` (neon gradient system — verify unused first)
- Delete: `residex_app/lib/core/theme/app_text_styles.dart` (dead duplicate class — zero imports found in codebase, confirmed via `grep -rl "app_text_styles.dart'" lib`)
- Modify: `residex_app/lib/core/theme/app_dimensions.dart` (update `AppShadows` — glow shadows don't fit Title Deed's flat-hairline aesthetic; replace with a single subtle `cardShadow`)
- Modify: `residex_app/pubspec.yaml` (no new dependency needed — `google_fonts: ^6.1.0` already present; verify Fraunces/IBM Plex Sans/IBM Plex Mono are available via `GoogleFonts.fraunces()`, `GoogleFonts.ibmPlexSans()`, `GoogleFonts.ibmPlexMono()` static methods, which `google_fonts` package generates for every font in the Google Fonts catalog)

**Interfaces:**
- Consumes: nothing (foundational task)
- Produces: `AppColors` static const `Color` fields: `paper`, `ink`, `brass`, `slate`, `deedGreen`, `sealRed`, `hairline`, `card` (new names) PLUS the existing field names that 49 files already reference (`background`, `surface`, `surfaceLight`, `textPrimary`, `textSecondary`, `textMuted`, `primaryCyan`, `primaryBlue`, `success`, `warning`, `error`, `info`, `purple`, `border`, `borderLight`, `cardBackground`, `cardBorder`, `orange`) — **these old names must be KEPT but repointed to new hex values**, so every existing call site (`AppColors.background`, `AppColors.primaryCyan`, etc.) automatically renders in the new palette with zero changes to the 33+ files that use them. `AppTextStyles` keeps its existing getter names (`displayLarge`, `headlineLarge`, `headlineMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelSmall`, `label`, `heading1`, `heading2`, `h1`-`h4`) but changes their font family/weights per the new type scale.

- [ ] **Step 1: Inventory every `AppColors.*` field name actually referenced across the app**

```bash
cd residex_app
grep -rhoE "AppColors\.[a-zA-Z0-9_]+" lib --include="*.dart" | sort -u
```

Expected: a list of ~20 field names (background, surface, surfaceLight, textPrimary, textSecondary, textMuted, primaryCyan, primaryBlue, success, warning, error, info, purple, border, borderLight, cardBackground, cardBorder, orange, deepSpace, etc.). Record this full list — every name in it MUST exist as a field in the rewritten file, or every call site referencing it becomes a compile error.

- [ ] **Step 2: Read the current full `app_colors.dart` to see all existing field names and their current hex mappings**

```bash
cat lib/core/theme/app_colors.dart
```

Cross-reference against Step 1's list — some fields in the file (the neon accent series: cyan300-500, emerald, rose, orange500, purple500, indigo300-500, green400-600, red400-600, blue400-600, syncedBlue, driftingAmber, outOfSyncRose, etc.) will NOT appear in Step 1's grep output, meaning they're unused (defined but never referenced) — these can be dropped in the rewrite. Only fields that DID appear in Step 1's grep must be preserved by name.

- [ ] **Step 3: Rewrite `app_colors.dart` with the Title Deed palette, mapping every field name from Step 1 to new hex values**

Create the new file. The 8 named tokens from the design spec are the canonical hex source; every legacy field name aliases to one of them:

```dart
import 'package:flutter/material.dart';

/// Title Deed color system.
/// Canonical tokens: paper, ink, brass, slate, deedGreen, sealRed, hairline, card.
/// All other fields alias to these for backward compatibility with existing call sites.
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
  static const Color textPrimary = ink;
  static const Color textSecondary = slate;
  static const Color textMuted = Color(0xFF9CA0AA); // lighter slate for tertiary text
  static const Color textTertiary = textMuted;
  static const Color primaryCyan = brass; // legacy "cyan" accent now maps to brass
  static const Color primaryBlue = brass; // legacy secondary accent also maps to brass (single-accent system)
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
}
```

If Step 1's grep found any field name NOT covered above, add it as an alias to the nearest canonical token (prefer `slate` for muted/secondary meanings, `brass` for accent/interactive meanings, `sealRed` for error/danger, `deedGreen` for success) — do not leave any name from Step 1's inventory undefined.

- [ ] **Step 4: Run flutter analyze to catch any missed `AppColors` field**

```bash
flutter analyze 2>&1 | grep -i "AppColors\|Undefined"
```

Expected: no output (no undefined-getter errors referencing AppColors). If any appear, add the missing alias to `app_colors.dart` from Step 3 and re-run.

- [ ] **Step 5: Rewrite the embedded `AppTextStyles` class in `app_theme.dart` with the new type scale**

Open `residex_app/lib/core/theme/app_theme.dart`. Replace the `AppTextStyles` class (currently using `GoogleFonts.inter` throughout) with:

```dart
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
```

- [ ] **Step 6: Rewrite `AppTheme.darkTheme` in the same file to a light theme (keep the getter name `darkTheme` to avoid touching `main.dart`'s theme wiring — verify in Step 8 whether renaming is actually free, and if so prefer a correctly-named `lightTheme` getter instead)**

First check how the theme getter is consumed:

```bash
grep -rn "AppTheme\." lib/main.dart lib --include="*.dart" | grep -v "app_theme.dart:"
```

If the only call site is something like `theme: AppTheme.darkTheme` in `main.dart`, rename the getter to `AppTheme.lightTheme` in both the definition and that one call site (cleaner than keeping a misleading name). Replace the theme body:

```dart
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
```

Delete the old `GlassDecoration` class entirely (glow/glass aesthetic doesn't fit Title Deed).

- [ ] **Step 7: Find and update every call site using the old `GlassDecoration` or `AppTheme.darkTheme` names**

```bash
grep -rln "GlassDecoration\|AppTheme.darkTheme" lib --include="*.dart"
```

For each file found, replace `GlassDecoration.card`/`GlassDecoration.cardHighlight` with `CardDecoration.flat`/`CardDecoration.flatHighlight`, and `AppTheme.darkTheme` with `AppTheme.lightTheme`.

- [ ] **Step 8: Verify `app_gradients.dart` and `app_text_styles.dart` are truly unused, then delete**

```bash
grep -rln "app_gradients.dart'" lib --include="*.dart"
grep -rln "app_text_styles.dart'" lib --include="*.dart"
```

Expected: no output for either (both unimported). If either shows a result, open that file and update its import to use the new theme system instead before deleting — do not delete a file that's still imported somewhere.

```bash
rm lib/core/theme/app_gradients.dart
rm lib/core/theme/app_text_styles.dart
```

- [ ] **Step 9: Update `AppShadows` in `app_dimensions.dart` to a single flat shadow**

Replace the `blueGlow`/`purpleGlow` glow shadows:

```dart
class AppShadows {
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];
}
```

Then find and update call sites:

```bash
grep -rln "AppShadows\.\(blueGlow\|purpleGlow\)" lib --include="*.dart"
```

Replace any `AppShadows.blueGlow`/`AppShadows.purpleGlow` reference with `AppShadows.cardShadow`.

- [ ] **Step 10: Run flutter analyze**

```bash
flutter analyze 2>&1 | tail -30
```

Expected: 0 errors. Warnings/info at or below the pre-existing baseline (~475) are acceptable; investigate any NEW error (not warning/info) before proceeding.

- [ ] **Step 11: Commit**

```bash
git add lib/core/theme/
git commit -m "feat: rebuild design tokens for Title Deed light theme"
```

---

### Task 2: Delete dead screens, routes, and providers; collapse to 3-tab shell

**Files:**
- Delete: `residex_app/lib/features/landlord/presentation/screens/2-Finance/` (entire directory)
- Delete: `residex_app/lib/features/landlord/presentation/screens/5-Community/` (entire directory)
- Delete: `residex_app/lib/features/landlord/presentation/screens/3-REX/rex_ai_main_menu_screen.dart`
- Delete: `residex_app/lib/features/landlord/presentation/screens/3-REX/rex_ai_tab_wrapper.dart`
- Delete: `residex_app/lib/features/landlord/presentation/screens/3-REX/landlord_rex_ai_screen.dart`
- Delete: `residex_app/lib/features/landlord/presentation/screens/3-REX/sub/lease_generator_screen.dart`
- Delete: `residex_app/lib/features/landlord/presentation/screens/3-REX/sub/maintenance_ai_screen.dart`
- Delete: `residex_app/lib/features/landlord/presentation/screens/3-REX/sub/revenue_analytics_screen.dart`
- Delete: `residex_app/lib/features/landlord/presentation/screens/1-Command/` sub-screens that are mock (verify first — see Step 1)
- Delete: `residex_app/lib/features/shared/presentation/screens/community/`, `gamification/`, `maintenance/` directories (verify no live usage first — see Step 2)
- Modify: `residex_app/lib/core/router/app_router.dart` (remove all routes/imports for deleted screens; collapse `AppRoutes` constants)
- Modify: `residex_app/lib/features/landlord/presentation/screens/landlord_home_screen.dart` (rewrite for 3-tab shell)
- Move: `residex_app/lib/features/landlord/presentation/screens/3-REX/sub/documind_screen.dart` → `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (also move `documind_chat_logic.dart` alongside it)
- Delete: `residex_app/lib/features/landlord/presentation/screens/1-Command/` and `3-REX/` directories once emptied of survivors
- Modify: any DI providers in `residex_app/lib/core/di/injection.dart` referencing deleted screens' data (verify — Task exploration found injection.dart currently has no references to Finance/Community/lease/maintenance, so this file likely needs NO changes; confirm in Step 1)

**Interfaces:**
- Consumes: nothing new
- Produces: `LandlordHomeScreen` with exactly 3 tabs: Dashboard (index 0), Documind (index 1), Portfolio (index 2). `AppRoutes` reduced to: `splash`, `login`, `register`, `landlordDashboard`, `landlordPortfolio`. The Dashboard screen itself is created fresh in Task 4 — this task only wires the tab shell to point at a placeholder or the renamed Command screen temporarily.

- [ ] **Step 1: Verify which Command sub-screens are mock vs. real before deleting**

```bash
cd residex_app
cat lib/features/landlord/presentation/screens/1-Command/sub/landlord_maintenance_screen.dart | head -40
cat lib/features/landlord/presentation/screens/1-Command/sub/landlord_system_health_screen.dart | head -40
cat lib/features/landlord/presentation/screens/1-Command/sub/maintenance_ticket_detail_screen.dart | head -40
```

Confirm each has no real Firestore/API data source (grep for `Firestore`, `http`, real repository providers vs hardcoded lists). Based on prior exploration this session, `landlord_command_screen.dart` (the parent) contained "FairFix Auditor"/"Ghost Overlay" Coming-Soon buttons and is the entry point to these subs — treat all three sub-screens as mock/dead unless this check shows otherwise. If any shows a real Firestore-backed data source, STOP and report NEEDS_CONTEXT rather than deleting real functionality.

- [ ] **Step 2: Verify shared community/gamification/maintenance screens have no live usage**

```bash
grep -rln "screens/community/\|screens/gamification/\|screens/maintenance/" lib/core/router/app_router.dart lib --include="*.dart" | grep -v "presentation/screens/community\|presentation/screens/gamification\|presentation/screens/maintenance"
```

This checks for imports of these shared screens from OUTSIDE their own directories (i.e., are they actually routed to or embedded anywhere). Expected: no results, or only results within `landlord_community_screen.dart` (which is being deleted anyway) and `landlord_command_screen.dart`'s maintenance sub-screen chain (also being deleted). If any survives-and-uses import is found from a screen that is NOT being deleted, STOP and report NEEDS_CONTEXT.

- [ ] **Step 3: Delete confirmed-dead screen directories**

```bash
rm -rf "lib/features/landlord/presentation/screens/2-Finance"
rm -rf "lib/features/landlord/presentation/screens/5-Community"
rm "lib/features/landlord/presentation/screens/3-REX/rex_ai_main_menu_screen.dart"
rm "lib/features/landlord/presentation/screens/3-REX/rex_ai_tab_wrapper.dart"
rm "lib/features/landlord/presentation/screens/3-REX/landlord_rex_ai_screen.dart"
rm "lib/features/landlord/presentation/screens/3-REX/sub/lease_generator_screen.dart"
rm "lib/features/landlord/presentation/screens/3-REX/sub/maintenance_ai_screen.dart"
rm "lib/features/landlord/presentation/screens/3-REX/sub/revenue_analytics_screen.dart"
rm -rf "lib/features/shared/presentation/screens/community"
rm -rf "lib/features/shared/presentation/screens/gamification"
rm -rf "lib/features/shared/presentation/screens/maintenance"
```

Only delete the `1-Command/sub/` files if Step 1 confirmed them mock:

```bash
rm -rf "lib/features/landlord/presentation/screens/1-Command"
```

- [ ] **Step 4: Move Documind screen to its own top-level directory**

```bash
mkdir -p "lib/features/landlord/presentation/screens/2-Documind"
git mv "lib/features/landlord/presentation/screens/3-REX/sub/documind_screen.dart" "lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart"
git mv "lib/features/landlord/presentation/screens/3-REX/sub/documind_chat_logic.dart" "lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart"
```

Open the moved `documind_screen.dart` and fix its relative import of `documind_chat_logic.dart` (should now be `'documind_chat_logic.dart'` since they're siblings — verify path depth changed correctly, e.g. `../../../providers/documind_provider.dart` may need one fewer `../` since the file moved up one directory level from `3-REX/sub/` to `2-Documind/`). Compare old path depth (`screens/3-REX/sub/` = 3 levels under `screens/`) to new (`screens/2-Documind/` = 1 level under `screens/`) and adjust all relative imports in the moved file accordingly.

- [ ] **Step 5: Delete now-empty `3-REX` directory**

```bash
rmdir "lib/features/landlord/presentation/screens/3-REX/sub" 2>/dev/null
rmdir "lib/features/landlord/presentation/screens/3-REX" 2>/dev/null
ls "lib/features/landlord/presentation/screens/"
```

Confirm only `2-Documind/`, `4-Portfolio/`, and `landlord_home_screen.dart` remain (Dashboard doesn't exist yet — created in Task 4).

- [ ] **Step 6: Rewrite `app_router.dart` — remove all imports/routes for deleted screens**

Replace the full file:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shared/presentation/screens/auth/login_screen.dart';
import '../../features/shared/presentation/screens/auth/register_screen.dart';
import '../../features/shared/presentation/screens/auth/new_splash_screen.dart';
import '../../features/landlord/presentation/screens/landlord_home_screen.dart';
import '../../features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart';
import '../../features/shared/domain/entities/users/app_user.dart';
import 'nav_direction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/shared/presentation/providers/auth_providers.dart';

/// Bridges Riverpod auth state to GoRouter's refreshListenable
class _RouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// App route names
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String landlordDashboard = '/landlord-dashboard';
  static const String landlordPortfolio = '/landlord-portfolio';
}

/// Custom page transition with slide animation
CustomTransitionPage<T> buildPageWithSlideTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  final enterBegin = NavDirection.slideFromRight
      ? const Offset(1.0, 0)
      : const Offset(-1.0, 0);
  final exitEnd = NavDirection.slideFromRight
      ? const Offset(-0.3, 0)
      : const Offset(0.3, 0);
  NavDirection.slideFromRight = true;

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const smoothCurve = Cubic(0.2, 0.8, 0.2, 1.0);
      final enterAnim = CurvedAnimation(
        parent: animation,
        curve: smoothCurve,
        reverseCurve: smoothCurve.flipped,
      );
      final exitAnim = CurvedAnimation(parent: secondaryAnimation, curve: smoothCurve);
      return SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: exitEnd).animate(exitAnim),
        child: SlideTransition(
          position: Tween<Offset>(begin: enterBegin, end: Offset.zero).animate(enterAnim),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(enterAnim),
            child: child,
          ),
        ),
      );
    },
  );
}

/// App router configuration
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();
  ref.onDispose(notifier.dispose);

  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, __) {
    notifier.notify();
  });

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final devRole = ref.read(devBypassProvider);
      if (devRole != null) return null;

      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;

      final user = authState.value;
      final isLoggedIn = user != null;
      final loc = state.matchedLocation;

      final isOnAuthRoute = loc == AppRoutes.splash ||
          loc == AppRoutes.login ||
          loc == AppRoutes.register;

      if (!isLoggedIn && !isOnAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isOnAuthRoute) return AppRoutes.landlordDashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const NewSplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.landlordDashboard,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.landlordPortfolio,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordPortfolioScreen(),
        ),
      ),
    ],
  );
});
```

Note: `TenantListScreen`/`TenantScoreDetailScreen` routes are dropped here since the spec flags them for likely deletion — Task 3 (Portfolio) will verify and finalize; if Task 3 finds them real and worth keeping, those two routes get re-added there, not in this task.

- [ ] **Step 7: Rewrite `landlord_home_screen.dart` for a 3-tab shell (Dashboard placeholder for now — real Dashboard built in Task 4)**

```dart
import 'package:flutter/material.dart';
import '2-Documind/documind_screen.dart';
import '4-Portfolio/landlord_portfolio_screen.dart';
import '../widgets/navigation/custom_bottom_nav_bar.dart';
import '../../../core/theme/app_colors.dart';

/// Temporary placeholder — replaced by the real dashboard in Task 4.
class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(child: Text('Dashboard — under construction')),
    );
  }
}

/// Landlord Home Screen with 3-tab bottom navigation.
///
/// Navigation Tabs:
/// 1. Dashboard - overview, recent Documind activity
/// 2. Documind - AI document Q&A (flagship feature)
/// 3. Portfolio - property management
class LandlordHomeScreen extends StatefulWidget {
  const LandlordHomeScreen({super.key});

  @override
  State<LandlordHomeScreen> createState() => _LandlordHomeScreenState();
}

class _LandlordHomeScreenState extends State<LandlordHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _DashboardPlaceholder(),
    DocuMindScreen(),
    LandlordPortfolioScreen(),
  ];

  final List<NavTab> _navTabs = const [
    NavTab(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      color: AppColors.brass,
      glowColor: AppColors.brass,
    ),
    NavTab(
      icon: Icons.auto_awesome_outlined,
      label: 'Documind',
      color: AppColors.brass,
      glowColor: AppColors.brass,
    ),
    NavTab(
      icon: Icons.business_outlined,
      label: 'Portfolio',
      color: AppColors.brass,
      glowColor: AppColors.brass,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        tabs: _navTabs,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
```

Check `custom_bottom_nav_bar.dart`'s `NavTab` constructor signature first — confirm `icon`/`label`/`color`/`glowColor` fields exist as shown (they did in the pre-redesign version per this session's earlier exploration); if the widget uses `glowColor` for an actual glow/blur effect that clashes with the flat Title Deed aesthetic, that's fine to leave for now — Task 6's final polish pass may simplify `custom_bottom_nav_bar.dart` itself if needed, but is not required by this task.

- [ ] **Step 8: Run flutter analyze**

```bash
flutter analyze 2>&1 | tail -40
```

Expected: 0 errors. Fix any import/reference errors from the deletions before proceeding (most likely culprits: leftover imports in `injection.dart` or other files referencing deleted screens — search and fix).

```bash
grep -rln "2-Finance\|5-Community\|rex_ai_main_menu\|rex_ai_tab_wrapper\|landlord_rex_ai_screen\|lease_generator_screen\|maintenance_ai_screen\|revenue_analytics_screen\|screens/community/\|screens/gamification/\|screens/maintenance/" lib --include="*.dart"
```

Expected: no output. If any file appears, open it and remove the dangling import/reference.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: delete dead screens, collapse to 3-tab shell, promote Documind"
```

---

### Task 3: Landlord-only auth (login + register rewrite)

**Files:**
- Modify: `residex_app/lib/features/shared/presentation/screens/auth/login_screen.dart` (full rewrite)
- Modify: `residex_app/lib/features/shared/presentation/screens/auth/register_screen.dart` (full rewrite)
- Modify: `residex_app/lib/features/shared/presentation/screens/auth/new_splash_screen.dart` (restyle to Title Deed; keep existing logic/timing)
- Read (no changes expected, verify only): `residex_app/lib/features/shared/domain/entities/users/app_user.dart` (confirm `UserRole` enum still has both `tenant`/`landlord` values — must NOT be removed as a Global Constraint)

**Interfaces:**
- Consumes: `AppColors`, `AppTextStyles`, `AppTheme` from Task 1; `authControllerProvider`, `authStateProvider`, `devBypassProvider` from `auth_providers.dart` (unchanged signatures — this task only changes UI, not auth logic)
- Produces: `LoginScreen` with one dev-bypass button (landlord only, labeled "Dev sign-in"), navigating via `AppRoutes.landlordDashboard` (not hardcoded `'/landlord-dashboard'` strings). `RegisterScreen` with no role selector, always constructing `role: UserRole.landlord`.

- [ ] **Step 1: Rewrite `login_screen.dart`**

Replace the entire file. Preserve all existing method logic (`_handleLogin`, `_handleGoogleSignIn`, the `ref.listen` auto-route-on-auth-resolve pattern) — only the `build()` method's widget tree and the dev-bypass section change:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../domain/entities/users/app_user.dart';
import '../../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password to continue.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleDevSignIn() {
    ref.read(devBypassProvider.notifier).bypass(UserRole.landlord);
    context.go(AppRoutes.landlordDashboard);
  }

  void _navigateToRegister() => context.go(AppRoutes.register);

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null && mounted) context.go(AppRoutes.landlordDashboard);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildLoginCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'ResiDex',
          style: AppTextStyles.displayLarge.copyWith(fontSize: 36),
        ),
        const SizedBox(height: 6),
        Text(
          "Your properties' paperwork, answered.",
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: CardDecoration.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            label: 'Email address',
            controller: _emailController,
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Password',
            controller: _passwordController,
            placeholder: 'Enter your password',
            isPassword: true,
          ),
          const SizedBox(height: 4),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.sealRed),
              ),
            ),
          const SizedBox(height: 16),
          _buildLoginButton(),
          const SizedBox(height: 12),
          _buildDevSignInButton(),
          const SizedBox(height: 20),
          _buildSignUpLink(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: AppTextStyles.labelSmall),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: placeholder,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Sign in'),
      ),
    );
  }

  Widget _buildDevSignInButton() {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: _handleDevSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.hairline),
          foregroundColor: AppColors.textSecondary,
        ),
        child: Text('Dev sign-in', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text("Don't have an account? ", style: AppTextStyles.bodySmall),
          GestureDetector(
            onTap: _navigateToRegister,
            child: Text(
              'Create one',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.brass,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

This drops the Google/Facebook social buttons and the `AmbientBackground`/`ResidexLogo` glow widgets (both belong to the old neon aesthetic and aren't part of the Title Deed spec — the spec calls for a plain paper background with a serif wordmark, nothing else). If `_handleGoogleSignIn` removal breaks a test or another call site, note it in your report — expected to be safe since `login_screen.dart` doesn't export that method.

- [ ] **Step 2: Rewrite `register_screen.dart`**

Same pattern — preserve `_performRegistration`/`_handleGoogleSignIn` logic conceptually but remove role selection, hardcode `role: UserRole.landlord`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../domain/entities/users/app_user.dart';
import '../../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showError('Fill in every field to create your account.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords don\'t match.');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError('Use a password with at least 6 characters.');
      return;
    }
    _performRegistration();
  }

  void _performRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider).signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
            role: UserRole.landlord,
            phoneNumber: '+60${_phoneController.text.trim()}',
          );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
        _showError(_errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.sealRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToLogin() => context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null && mounted) context.go(AppRoutes.landlordDashboard);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildRegisterCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('Create your account', style: AppTextStyles.displayMedium),
        const SizedBox(height: 6),
        Text('Set up ResiDex for your properties.', style: AppTextStyles.bodyMedium),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: CardDecoration.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(label: 'Full name', controller: _nameController, placeholder: 'e.g. Ali Rahman'),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Email address',
            controller: _emailController,
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildPhoneField(),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'Password',
            controller: _passwordController,
            obscure: _obscurePassword,
            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'Confirm password',
            controller: _confirmPasswordController,
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          const SizedBox(height: 20),
          _buildRegisterButton(),
          const SizedBox(height: 16),
          _buildLoginLink(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text(label, style: AppTextStyles.labelSmall)),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(hintText: placeholder),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text(label, style: AppTextStyles.labelSmall)),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'At least 6 characters',
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text('Phone number', style: AppTextStyles.labelSmall)),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text('+60', style: AppTextStyles.bodyLarge),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyLarge,
                decoration: const InputDecoration(hintText: '12 345 6789'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Create account'),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text('Already have an account? ', style: AppTextStyles.bodySmall),
          GestureDetector(
            onTap: _navigateToLogin,
            child: Text(
              'Sign in',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.brass, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Read and restyle `new_splash_screen.dart`**

```bash
cat lib/features/shared/presentation/screens/auth/new_splash_screen.dart
```

Read the full file first. Preserve its timing/navigation logic (whatever delay or auth-check it does before routing) exactly. Only change the visual tree: replace any dark background/glow/gradient with `AppColors.paper` background and a centered `Text('ResiDex', style: AppTextStyles.displayLarge)` with the tagline beneath in `AppTextStyles.bodyMedium`. If the file is short enough to show in full in your report, do so; otherwise describe the specific decoration/color changes made line-by-line.

- [ ] **Step 4: Verify `UserRole` enum unchanged**

```bash
grep -A 5 "enum UserRole" lib/features/shared/domain/entities/users/app_user.dart
```

Expected: enum still contains both `tenant` and `landlord`. Do NOT modify this file — Global Constraint requires the enum stay intact for data-model compatibility even though no UI ever selects `tenant` anymore.

- [ ] **Step 5: Run flutter analyze**

```bash
flutter analyze 2>&1 | tail -30
```

Expected: 0 errors.

- [ ] **Step 6: Manual verification — boot the app to login screen**

```bash
flutter analyze --no-fatal-infos
```

(If a running emulator is available, `flutter run` and visually confirm the login screen renders on paper background with brass button and no Tenant Dev button; if no emulator is available in this environment, skip live rendering and rely on `flutter analyze` + careful code review — note which you did in your report.)

- [ ] **Step 7: Commit**

```bash
git add lib/features/shared/presentation/screens/auth/
git commit -m "feat: landlord-only auth screens restyled to Title Deed"
```

---

### Task 4: Build real Dashboard tab

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/landlord_home_screen.dart` (replace `_DashboardPlaceholder` with the real screen)

**Interfaces:**
- Consumes: `propertiesStreamProvider` (from `property_providers.dart`, already used by `documind_screen.dart` and `landlord_portfolio_screen.dart` — confirmed real Firestore stream), `AppColors`/`AppTextStyles`/`CardDecoration` from Task 1
- Produces: `LandlordDashboardScreen` — a `ConsumerWidget` with no local mutable state needed (pure display of stream data + navigation)

- [ ] **Step 1: Check `propertiesStreamProvider`'s exact type and the `Property` entity's fields**

```bash
cd residex_app
grep -A 5 "propertiesStreamProvider" lib/features/landlord/presentation/providers/property_providers.dart | head -10
cat lib/features/landlord/domain/entities/property.dart | head -30
```

Record the `Property` entity's field names (expect at least `id`, `name`, possibly `address`) — use exact field names in Step 2, don't guess.

- [ ] **Step 2: Write the Dashboard screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/property_providers.dart';
import '../../domain/entities/property.dart';

class LandlordDashboardScreen extends ConsumerWidget {
  final VoidCallback onOpenDocumind;
  final VoidCallback onOpenPortfolio;

  const LandlordDashboardScreen({
    super.key,
    required this.onOpenDocumind,
    required this.onOpenPortfolio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('ResiDex', style: AppTextStyles.headlineMedium),
      ),
      body: propertiesAsync.when(
        data: (properties) => _buildContent(context, properties),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brass)),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Couldn't load your properties. Check your connection and try again.",
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Property> properties) {
    if (properties.isEmpty) {
      return _buildEmptyState(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good day', style: AppTextStyles.displayMedium),
          const SizedBox(height: 4),
          Text(
            '${properties.length} propert${properties.length == 1 ? 'y' : 'ies'} on file',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildDocumindEntryCard(context),
          const SizedBox(height: 24),
          Text('Your properties', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          ...properties.map((p) => _buildPropertyRow(context, p)),
        ],
      ),
    );
  }

  Widget _buildDocumindEntryCard(BuildContext context) {
    return GestureDetector(
      onTap: onOpenDocumind,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, color: AppColors.brass, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Documind', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Text('Get answers from your leases, warranties, and bills.', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyRow(BuildContext context, Property property) {
    return GestureDetector(
      onTap: onOpenPortfolio,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: CardDecoration.flat,
        child: Row(
          children: [
            const Icon(Icons.home_work_outlined, color: AppColors.brass, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(property.name, style: AppTextStyles.titleMedium),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No properties yet', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your first property to start filing its documents.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onOpenPortfolio,
              child: const Text('Add a property'),
            ),
          ],
        ),
      ),
    );
  }
}
```

If Step 1 revealed different field names than `name` (e.g., the entity uses `propertyName` or similar), adjust `property.name` references accordingly — use the exact name found.

- [ ] **Step 3: Wire the real Dashboard into `landlord_home_screen.dart`, replacing `_DashboardPlaceholder`**

Open `lib/features/landlord/presentation/screens/landlord_home_screen.dart`. Replace the placeholder import and usage:

```dart
import '1-Dashboard/landlord_dashboard_screen.dart';
```

Remove the `_DashboardPlaceholder` class entirely. In `_LandlordHomeScreenState`, the `_screens` list needs the dashboard to be able to switch tabs (it takes `onOpenDocumind`/`onOpenPortfolio` callbacks) — since `_screens` is currently a `const` list built once, convert it to a `late final` list initialized in `initState()` so it can close over `setState` while still preserving each tab's internal widget State across tab switches:

```dart
class _LandlordHomeScreenState extends State<LandlordHomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  final List<NavTab> _navTabs = const [
    NavTab(icon: Icons.dashboard_outlined, label: 'Dashboard', color: AppColors.brass, glowColor: AppColors.brass),
    NavTab(icon: Icons.auto_awesome_outlined, label: 'Documind', color: AppColors.brass, glowColor: AppColors.brass),
    NavTab(icon: Icons.business_outlined, label: 'Portfolio', color: AppColors.brass, glowColor: AppColors.brass),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      LandlordDashboardScreen(
        onOpenDocumind: () => setState(() => _currentIndex = 1),
        onOpenPortfolio: () => setState(() => _currentIndex = 2),
      ),
      const DocuMindScreen(),
      const LandlordPortfolioScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        tabs: _navTabs,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
```

This keeps each tab's `State` alive across switches (chat history in Documind, selected property, etc. all persist), since `_screens` is built once in `initState()` rather than rebuilt on every `build()` call.

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze 2>&1 | tail -30
```

Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/landlord/presentation/screens/1-Dashboard/ lib/features/landlord/presentation/screens/landlord_home_screen.dart
git commit -m "feat: build real Dashboard tab with live property data"
```

---

### Task 5: Documind citation-card signature element

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart` (add structured citation rendering; keep all existing state/logic/upload/delete flows unchanged)
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart` (add a new function that returns structured data instead of flattened text, used only for the newest assistant message)

**Interfaces:**
- Consumes: `DocuMindAnswer` (fields: `answer: String`, `confidence: double`, `citations: List<Citation>`, `searchedCategories`, `categoryFilterMode`, `userActionRequired`, `clarificationOptions`, `predictedCategories` — confirmed via Task exploration this session) where `Citation` has `category`, `filename`, `page` (confirmed fields used in existing `documind_chat_logic.dart`)
- Produces: the newest AI message renders as a "certified extract" card (hairline border, brass corner mark, citations as ledger lines with a relevance meter) instead of plain chat bubble text; all OLDER messages in the scroll history keep rendering as plain `DashChat` bubbles (no retroactive re-render of history — this task only changes how the LATEST answer displays)

- [ ] **Step 1: Check the `Citation` model for a numeric score field**

```bash
cd residex_app
grep -B 2 -A 10 "class Citation" lib/features/landlord/domain/entities/documind_document.dart
```

Confirm whether `Citation` has a `score`/`relevanceScore`/similar `double` field (the backend's `HybridRetriever` now populates `rerank_score`/`dense_score` per this session's earlier backend work — confirm the Flutter-side model was updated to receive it, or if it's missing, the relevance meter in Step 3 must gracefully omit itself rather than crash on a missing field).

- [ ] **Step 2: Add a structured-answer widget builder function to `documind_chat_logic.dart`**

Add this alongside the existing `buildDocuMindAssistantText` function (keep that function — it's still used for constructing the raw text that seeds `ChatMessage`, since `dash_chat_2`'s `ChatMessage` is text-based):

```dart
/// Whether this answer should render as a certified-extract card
/// rather than a plain chat bubble — true whenever the model produced
/// at least one citation to show.
bool shouldRenderAsCertifiedExtract(DocuMindAnswer answer) {
  return answer.citations.isNotEmpty;
}
```

- [ ] **Step 3: Add the certified-extract card widget to `documind_screen.dart`**

Add this new private widget-returning method to `_DocuMindScreenState` (place it near `_buildChatInterface`):

```dart
  Widget _buildCertifiedExtractCard(DocuMindAnswer answer) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppColors.brass),
              const SizedBox(width: 6),
              Text('DOCUMIND', style: AppTextStyles.labelSmall.copyWith(color: AppColors.brass)),
            ],
          ),
          const SizedBox(height: 10),
          Text(answer.answer, style: AppTextStyles.bodyLarge),
          if (answer.citations.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.hairline),
            const SizedBox(height: 10),
            ...answer.citations.take(3).map((c) => _buildCitationLine(c)),
          ],
        ],
      ),
    );
  }

  Widget _buildCitationLine(Citation citation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${citation.filename} · p.${citation.page ?? '—'}',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
```

Add `import 'package:google_fonts/google_fonts.dart';` to the top of `documind_screen.dart` if not already present (check first — it may already be imported for another reason; the existing file uses `AppTextStyles` throughout, so verify with `grep "^import" lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`).

If Step 1 found a real relevance-score field on `Citation`, extend `_buildCitationLine` to add a thin brass meter bar after the filename/page text — a `Container` with `width: 40, height: 3` and a `FractionallySizedBox` inside filled proportional to the score, in `AppColors.brass`. If no score field exists on the Flutter-side model, skip the meter and note in your report that it's a follow-up item (the Flutter `Citation` model would need a new field synced with the backend's `Citation` Pydantic model, which is out of scope for this frontend-only task).

- [ ] **Step 4: Wire the certified-extract card into the chat message flow**

This is the trickiest integration point: `dash_chat_2`'s `DashChat` widget renders `ChatMessage` objects as plain bubbles — it doesn't support arbitrary custom widgets per-message out of the box unless using its `messageBuilder` option. Check whether `DashChat` exposes a `messageBuilder`:

```bash
grep -rn "messageBuilder" ~/.pub-cache/hosted/pub.dev/dash_chat_2*/lib/ 2>/dev/null | head -5
```

(On Windows, the pub cache path may be `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\dash_chat_2*` — adjust the search path/command for this environment; use `Get-ChildItem` or a Windows-appropriate find if the Unix-style path doesn't resolve, or search the `.dart_tool/package_config.json` for the resolved package location.)

If `DashChat` has a `messageBuilder` parameter: use it. In `_buildChatInterface()`, add `messageBuilder: (message, previousMessage, nextMessage) { ... }` to the existing `DashChat(...)` widget call, returning `_buildCertifiedExtractCard(...)` for the latest AI message that has associated citations, and falling back to `DashChat`'s default rendering (or a simple bubble matching the existing `MessageOptions` styling) for all other messages.

If `DashChat` does NOT expose a usable `messageBuilder` for this dash_chat_2 version: fall back to a simpler integration — after the newest AI response arrives (in `_consumeAnswer`), if `shouldRenderAsCertifiedExtract(answer)` is true, additionally store the last `DocuMindAnswer` in a new state field (`DocuMindAnswer? _lastAnswerForCard`) and render `_buildCertifiedExtractCard(_lastAnswerForCard!)` as a widget ABOVE the `DashChat` list (e.g., in a `Column` wrapping the chat, showing the card only when `_lastAnswerForCard != null` and clearing it when the user sends a new message). Document which approach you used and why in your report — this is a real implementation decision the brief cannot fully resolve without knowing the installed package's exact API surface.

Whichever approach is used, keep the plain-text `ChatMessage` insert into `_messages` in `_consumeAnswer` UNCHANGED (via `buildDocuMindAssistantText`) — the certified-extract card is an ADDITIONAL visual layer for the latest answer, not a replacement for the scrollable history, so users can still scroll back through the conversation and see prior answers as text.

- [ ] **Step 5: Add the fade-in motion for the card (respecting reduced motion)**

Wrap the certified-extract card's appearance with a simple fade/scale-in using `flutter_animate` (already a dependency per `pubspec.yaml`):

```dart
import 'package:flutter_animate/flutter_animate.dart';
```

In `_buildCertifiedExtractCard`, wrap the returned `Container` with:

```dart
    ).animate(
      target: MediaQuery.of(context).disableAnimations ? 0 : 1,
    ).fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOut);
```

Note: `target: 0` with `flutter_animate`'s `.animate(target:)` shows the end-state immediately without animating when reduced motion is requested (verify this is correct usage by checking `flutter_animate`'s docs/examples in the package if uncertain — if `target:` doesn't behave as expected for skipping animation, an alternative is to conditionally skip the `.fadeIn()/.slideY()` chain entirely: `if (MediaQuery.of(context).disableAnimations) { return container; } return container.animate()...`).

- [ ] **Step 6: Run flutter analyze**

```bash
cd residex_app
flutter analyze 2>&1 | tail -40
```

Expected: 0 errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/landlord/presentation/screens/2-Documind/
git commit -m "feat: add certified-extract citation card to Documind answers"
```

---

### Task 6: Portfolio verification, rebrand metadata, and final cleanup

**Files:**
- Verify only (restyle is automatic via Task 1's token rebuild): `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart`, `residex_app/lib/features/landlord/presentation/widgets/common/property_card.dart`, `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`
- Decide + modify or delete: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/sub/tenant_list_screen.dart`, `tenant_score_detail_screen.dart`
- Modify: `residex_app/pubspec.yaml` (description field, app name context)
- Modify: `residex_app/android/app/src/main/AndroidManifest.xml` (`android:label`)
- Modify: any remaining "Residex"/"residential super app" copy strings found via final grep sweep
- Delete: `residex_app/lib/core/widgets/residex_logo.dart`, `residex_app/lib/core/widgets/animations.dart` (the `AmbientBackground`/`ResidexLogo` glow widgets — verify unused after Task 3's auth rewrite before deleting)

**Interfaces:**
- Consumes: nothing new
- Produces: fully rebranded app, zero references to tenant/lease/finance/community in UI copy, zero hardcoded hex colors in screen files

- [ ] **Step 1: Verify Portfolio renders correctly with new tokens (no code change expected)**

```bash
cd residex_app
grep -c "AppColors\.\|AppTextStyles\." lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart
```

Confirm a non-zero count (this screen was already confirmed to use the token system during plan research). If any hardcoded hex (`Color(0xFF...)`) appears in this file, replace it with the nearest `AppColors` token from Task 1.

```bash
grep -n "Color(0xFF" lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart lib/features/landlord/presentation/widgets/common/property_card.dart lib/features/landlord/presentation/widgets/common/add_property_dialog.dart
```

For each hit, replace with the semantically closest `AppColors` field.

- [ ] **Step 2: Decide fate of tenant sub-screens under Portfolio**

```bash
cat lib/features/landlord/presentation/screens/4-Portfolio/sub/tenant_list_screen.dart | head -50
```

Check whether `TenantListScreen` pulls from a real Firestore data source (a `tenant_repository` or similar with live queries) or mock data. Per the design spec, "Tenant list / tenant score sub-screens: DELETE if mock." If real (unlikely, given this session's earlier backend work scoped the whole product to landlord-only and found no live tenant repository), keep them and re-add their routes to `app_router.dart` (`AppRoutes.landlordTenantList`, `landlordTenantScoreDetail`) with the `TenantListScreen`/`TenantScoreDetailScreen` imports restored. If mock (expected outcome), delete both files:

```bash
rm -rf lib/features/landlord/presentation/screens/4-Portfolio/sub
```

And confirm no lingering import in `landlord_portfolio_screen.dart`:

```bash
grep -n "sub/tenant" lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart
```

If found, remove that import line and any UI element that navigated to it (e.g., a "View Tenants" button on a property card — replace with nothing, or leave the property card's tap action as-is if it does something else useful like opening an edit dialog).

- [ ] **Step 3: Verify `AmbientBackground`/`ResidexLogo` widgets are unused after Task 3, then delete**

```bash
grep -rln "AmbientBackground\|ResidexLogo" lib --include="*.dart"
```

Expected: no results (Task 3 removed both from login/register). If any file still references them, either restyle that usage to Title Deed or leave the widget files in place and skip this deletion — note which in your report.

```bash
rm lib/core/widgets/residex_logo.dart
rm lib/core/widgets/animations.dart
```

(Only run if the grep above confirmed zero remaining references.)

- [ ] **Step 4: Rebrand pubspec.yaml**

Open `pubspec.yaml`. Change:

```yaml
description: "Rental-lifecycle app for landlords — property portfolio and AI document management."
```

(Replacing the current `"Malaysian super residential appp."` — note the typo in the original, this fixes it too.)

- [ ] **Step 5: Rebrand Android app label**

```bash
grep -n "android:label" android/app/src/main/AndroidManifest.xml
```

Update the `android:label` attribute value to `"ResiDex"` if it currently says something else.

- [ ] **Step 6: Final copy sweep for stray old-brand or dead-feature text**

```bash
grep -rniE "residential super app|Coming Soon|sync-hub|tenant dev|FairFix|Ghost Overlay" lib --include="*.dart"
```

Expected: no results. Fix any remaining hit — most likely candidates are leftover snackbar strings or comments; if it's a comment only (not user-visible), it's lower priority but still clean up per the "surgical changes" principle if it's trivial to fix in the same pass.

- [ ] **Step 7: Full hardcoded-hex sweep across all surviving screens**

```bash
grep -rn "Color(0xFF" lib/features/landlord/presentation/screens/ lib/features/shared/presentation/screens/auth/ --include="*.dart"
```

Expected: no results (Global Constraint: no hardcoded hex in screen files). Replace any hit with the appropriate `AppColors` token.

- [ ] **Step 8: Run flutter analyze**

```bash
flutter analyze 2>&1 | tail -40
```

Expected: 0 errors, warning/info count at or below the ~475 baseline (fewer is fine and expected given deletions).

- [ ] **Step 9: Full app boot verification**

```bash
flutter pub get
flutter analyze --no-fatal-infos
```

If an emulator is available in this environment, additionally run `flutter run`, navigate splash → login → Dev sign-in → confirm 3-tab shell loads with Dashboard active, tap through to Documind and Portfolio tabs, confirm no crashes. If no emulator is available, note that in your report and rely on `flutter analyze` plus manual code review as the verification method.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "chore: rebrand to ResiDex, verify Portfolio styling, final cleanup sweep"
```

---

## Post-Implementation Verification Checklist

- [ ] `flutter analyze`: 0 errors
- [ ] No hardcoded hex colors remain in any screen file
- [ ] No references to tenant selection, lease generation, finance, or community remain in navigable UI
- [ ] `AppRoutes` contains only: splash, login, register, landlordDashboard, landlordPortfolio (plus tenant routes IF Task 6 Step 2 determined they're real)
- [ ] 3-tab shell: Dashboard, Documind, Portfolio — all reachable, all rendering with Title Deed palette
- [ ] Login screen has exactly one dev-bypass button, landlord-only
- [ ] Register screen has no role selector, always creates landlord accounts
- [ ] `UserRole` enum unchanged (still has both `tenant` and `landlord` values)
- [ ] Documind's latest answer renders as a certified-extract card with citations when citations exist
- [ ] App metadata (pubspec.yaml description, Android label) says "ResiDex"

## Rollback Plan

Each task is an isolated commit. If a later task reveals an earlier task's approach was wrong (e.g., Task 5's `messageBuilder` assumption doesn't hold for the installed `dash_chat_2` version), the fix happens as a new commit correcting that task's file — do not `git reset` earlier work. If Task 2's deletions turn out to remove something with real functionality (caught by Step 1/Step 2's verification greps), stop and restore that specific file from git history (`git show <commit>:<path> > <path>`) rather than reverting the whole task.

## Success Criteria

✅ Every screen visible in the app uses the Title Deed palette and type system
✅ 3-tab navigation with Documind promoted to flagship position
✅ Auth is landlord-only, zero tenant-selection UI
✅ Zero dead "Coming Soon" buttons or mock-data screens remain
✅ Documind answers display with the certified-extract signature element
✅ App is rebranded to ResiDex throughout metadata and copy
