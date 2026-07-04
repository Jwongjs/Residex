# Round-3 UI Feedback — Quick Wins (Design)

**Date:** 2026-07-05
**Status:** Approved, pre-implementation
**Scope:** Items 1, 2, 5 from `HANDOFF.md` section 4 (user feedback round 3). Items 3, 4, 6, 7 are explicitly out of scope — they require further discussion and are deferred.

---

## 1. Restore & re-theme the ResiDex mark

### Background
`residex_logo.dart` (`ResidexLogo` widget) and `app_gradients.dart` were deleted in commit `ddc03ee` (rebrand cleanup). The widget draws an animated mark via `CustomPaint`: a 180° arch with vertical extensions plus a centered keystone diamond, a soft radial glow ring behind it, and a small fading sparkle accent. It previously took a `SyncState` enum (`synced` / `drifting` / `outOfSync`) to pick between three color gradients (blue/purple, amber/orange, rose/red) — a concept from the old dual-role sync architecture that no longer exists in the landlord-only app.

### Changes
- Recover both files from `ddc03ee^` via `git show`.
- In `residex_logo.dart`:
  - Remove the `syncState` field, the `SyncState` import, `_getStateColor()`, and `_getStateGradient()`.
  - Replace with one fixed `LinearGradient` (or reuse a single `AppGradients` constant) from `AppColors.registry` → `AppColors.deedGreen`.
  - Keep `size`, `animate`, `archProgress`, `diamondScale`, `diamondAngle` params — they're generic entrance-animation controls, not sync-state-specific.
  - Update the glow-ring color and sparkle color to use `AppColors.registry` / white, consistent with the rest of the Slate Teal system.
- In `app_gradients.dart`: drop the `synced`/`drifting`/`outOfSync`/`syncedBackground` gradients (dead concept). Keep only what the recolored logo needs, or inline the single gradient directly in `residex_logo.dart` and skip recreating this file if nothing else needs it.
- No changes to the `_LogoPainter` geometry (arch + diamond drawing logic stays identical).

### Placement
1. **Splash** (`new_splash_screen.dart`): add `ResidexLogo(size: ~96, animate: true)` above the existing "ResiDex" text/tagline column, fading/scaling in via the same `_textOpacity`/`_textSlide` animations already driving the text (or a matching interval on `_master`).
2. **Login** (`login_screen.dart`): add a small static mark (`animate: false`, size ~64) above the "ResiDex" headline in `_buildHeader()`.
3. **Dashboard** (`landlord_dashboard_screen.dart`): add a small static mark (`animate: false`, size ~28-32) as the `AppBar`'s `leading` widget (or inline in `title` next to the text), at `landlord_dashboard_screen.dart:34-44`.

### Out of scope
The old (dead, unrouted) `SplashScreen` + `ResidexLoader` widget are not touched — they're unreferenced by the router and not part of this work.

---

## 2. Remove Documind template questions

### Background
`documind_screen.dart` has two separate quick-question mechanisms:
- `_buildCenteredQuickQuestions()` + `_buildQuickQuestionCard()` — a 2-column grid of 5 emoji-prefixed sample questions, shown when `showEmptyPrompt` is true (no messages yet, not thinking).
- `_buildQuickQuestionsBar()` — a horizontal scrolling chip bar, shown once `hasUserMessages` is true. This bar already references dead legacy tokens (`AppColors.primaryCyan`, `AppColors.surface`, `AppColors.border`) that don't exist in the current Slate Teal palette proper (they're legacy aliases per the redesign's token file).

### Changes
Delete entirely:
- `_quickQuestions` (the source list)
- `_buildCenteredQuickQuestions()`
- `_buildQuickQuestionCard()`
- `_buildQuickQuestionsBar()`
- `_sendQuickQuestion()`
- The two call sites: `if (hasUserMessages) _buildQuickQuestionsBar()` and `_buildCenteredQuickQuestions()` inside `_buildChatInterface()`.

### Resulting empty state
`showEmptyPrompt` still renders the icon-in-circle (`Icons.chat_outlined`) + "Ask Me Anything" title + "Select a question below or type your own" subtitle — except the subtitle text no longer makes sense without cards below it. Update the subtitle to something that doesn't reference the (now-removed) cards, e.g. **"Type a question about your documents to get started."**

No other behavior changes — `_onSendMessage` and the DashChat input remain the only way to send a message.

---

## 3. Restyle add/edit property dialog + fix label truncation

### Background
`add_property_dialog.dart` was never touched by the Task 1-8 "Title Deed" redesign. It still uses the pre-redesign token set (`AppColors.primaryCyan`, `primaryBlue`, `background`, `border`, `surface`) and a cyan→blue gradient header, visually inconsistent with every other restyled screen (flat `paper`/`card`/`hairline`/`registry` system, no gradients per the panel idiom in `HANDOFF.md` section 3).

Label truncation root cause: `_buildTextField` and `_buildDropdown` never set an explicit `labelStyle`, so Flutter's default `InputDecoration` label sizing is used. Combined with 2-3-column `Row`+`Expanded` layouts (City/State/Zip; Purchase Price/Current Value) at narrower widths, longer labels like "Purchase Price" and "Current Value" get clipped.

### Changes
**Color/token pass** (mechanical swap, no layout change):
| Old | New |
|---|---|
| `AppColors.surface` (dialog bg) | `AppColors.paper` |
| Header gradient `[primaryCyan, primaryBlue]` | Solid `AppColors.registry` (no gradient) |
| `AppColors.background` (field fill) | `AppColors.card` |
| `AppColors.border` | `AppColors.hairline` |
| `AppColors.primaryCyan` (icons, focus border, submit button) | `AppColors.registry` |
| `AppColors.surfaceLight` (footer bg) | stays `AppColors.surfaceLight` (already correct token) |
| `AppColors.error` / `AppColors.success` | unchanged (already correct tokens) |

**Label truncation fix:**
- Add `labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)` and `isDense: true` to the `InputDecoration` in `_buildTextField` and `_buildDropdown`.
- Set `floatingLabelBehavior: FloatingLabelBehavior.auto` explicitly (default, but explicit for clarity) so the label shrinks and floats above the field once focused/filled rather than staying full-size inline.
- For the 3-column City/State/Zip row and 2-column Purchase Price/Current Value row: no structural change needed once the label font is smaller — verify with `flutter analyze` + a manual run that "Purchase Price," "Current Value," and "Occupied Units" no longer clip at default dialog width (`maxWidth: 600`).

### Out of scope
No data-model changes here (that's items 6/7, deferred). `monthlyRent` stays a property-level field for this pass — only visual/label fixes.

---

## Testing / verification

- `flutter analyze` — expect to stay at the current baseline (0 errors); fixing dead-token usage in the quick-question bar and dialog should not introduce new issues, may reduce info-level warnings.
- Manual run (Android emulator, per `HANDOFF.md` section 6): verify splash entrance shows the mark, login screen shows the static mark, dashboard app bar shows the small mark, Documind empty state has no cards, and the add/edit property dialog renders in Slate Teal with all labels fully readable at default size.
- No backend changes; no test suite impact expected.
