# ResiDex "Title Deed" Frontend Redesign — Design Spec

**Date:** 2026-07-03
**Status:** Approved by user (visual direction, 3-tab structure, Finance deferred)

## Goal

Rebrand and redesign the ResiDex Flutter app as a landlord-only rental-lifecycle application whose flagship feature is Documind (document management + RAG Q&A). Modernize the visual system, make auth landlord-only, and remove every screen or element with no working functionality.

## Context (what is real today)

Only three feature areas have working data sources:

| Feature | Data source | Status |
|---|---|---|
| Documind | Backend API (`documind_remote_datasource.dart` → FastAPI `/api/rex/documind/*`) | Real — newly upgraded hybrid RAG |
| Portfolio (properties) | Firestore direct (`property_remote_datasource.dart`) | Real — live CRUD |
| Auth | Firebase Auth + dev bypass provider | Real, but still tenant-aware |

Everything else is mock or dead: Finance tab (hardcoded numbers), Community tab (all "Coming Soon"), Rex AI menu's siblings (Lease Generator — backend deleted, Maintenance AI, Revenue Analytics), Command tab's "FairFix Auditor"/"Ghost Overlay" buttons and mock sub-screens, shared community/gamification/maintenance screens.

## Scope

**In scope:**
1. New design-token system (palette, type, dimensions) replacing the neon multi-accent dark theme
2. 3-tab structure: Dashboard · Documind · Portfolio
3. Landlord-only auth (login + register)
4. Rebrand copy (wordmark, tagline, app metadata)
5. Deletion of all dead/mock screens and their routes/providers
6. Restyling of surviving screens to the new system

**Out of scope (explicitly deferred):**
- Finance tab with real income/expense tracking (future project; user wants a business-side discussion after this ships)
- Any new backend endpoints
- BM25/golden-dataset work (tracked in DOCUMIND_CHECKLIST.md)

## Design system — "Title Deed"

**Thesis:** a landlord's filing cabinet that answers questions. Materials of property ownership — paper, ink, a brass seal — executed as a modern, precise mobile app. The one aesthetic risk: serif display type (Fraunces) for headings and figures.

### Palette (replaces ALL existing accent colors)

| Token | Hex | Role |
|---|---|---|
| `paper` | `#FAFAF7` | App background |
| `ink` | `#1A2438` | Primary text, headings, icons |
| `brass` | `#B08D4A` | Single accent: primary actions, active tab, Documind mark |
| `slate` | `#6B7280` | Secondary text, captions, disabled |
| `deedGreen` | `#2F7D5D` | Success (indexed, confirmations) |
| `sealRed` | `#B4443C` | Errors, destructive actions |
| `hairline` | `#E7E5DF` | Card borders, dividers |
| `card` | `#FFFFFF` | Card surfaces |

Cards: white on paper, 1px hairline border, 12px radius, minimal shadow (elevation ≤ 1). Structure via hairline rules, not glows or gradients. The `app_gradients.dart` neon system is deleted.

### Typography (via `google_fonts` package — add to pubspec)

| Role | Face | Usage |
|---|---|---|
| Display | Fraunces | Screen titles, big figures ("3 Properties"), wordmark |
| Body | IBM Plex Sans | All body text, buttons, labels |
| Utility | IBM Plex Mono | Filenames, category tags, relevance scores |

Type scale: display 28/34, title 20/26, body 15/22, caption 12/16. Sentence case everywhere; no all-caps except small eyebrow labels.

### Signature element

Documind answers render as a **certified extract**: a hairline-bordered white card with a small brass mark (✦ or seal glyph) in the corner, the answer in body type, and citations as ledger lines beneath — `filename · p.N` in Plex Mono with a thin brass relevance meter (fill = rerank score). This is the app's one memorable visual moment; everything else stays quiet.

### Motion

One orchestrated moment: the answer card fades and settles in (~250ms, ease-out) on arrival. Respect `MediaQuery.disableAnimations` (reduced motion). No other decorative animation; no glow pulses.

## Structure & screens

### Navigation shell
- App bar: "ResiDex" wordmark (Fraunces), profile chip on the right → profile screen.
- Bottom nav: 3 tabs — Dashboard, Documind (center, brass-marked active state), Portfolio. The old 5-tab `CustomBottomNavBar` with per-tab glow colors is restyled or replaced with the new token system.

### 1. Dashboard (rebuilt from Command tab)
Real data only:
- Greeting ("Good morning, {name}" from auth user)
- Property count (live Firestore stream, same provider Portfolio uses)
- "Ask Documind…" entry card (brass accent) → switches to Documind tab
- Recent documents list (from Documind docs API, per property) — if it requires a property selection, show most recent across the landlord's properties or a simple per-property chooser; implementer may simplify to "recent uploads" if the API shape demands it
- DELETE: FairFix Auditor / Ghost Overlay buttons, maintenance + system-health mock sub-screens, any mock stat cards

Empty state (no properties yet): "Add your first property to start filing its documents." with a button to Portfolio.

### 2. Documind (promoted to top-level tab)
- `documind_screen.dart` becomes the tab root (no longer reached via Rex AI menu)
- Restyle chat UI to Title Deed: user messages as quiet ink-on-paper bubbles, answers as certified-extract cards (signature element above)
- Category filter chips: hairline outline, brass fill when active, Plex Mono labels
- Property selector (existing behavior preserved — Documind is property-scoped)
- Upload flow restyled; "indexed" confirmations in deed green
- Empty state (no documents for property): "Upload a lease, warranty, or bill to start asking questions."

### 3. Portfolio
- Property list as paper cards: name in Fraunces, address in body, document count chip
- Property CRUD flows keep existing functionality, restyled
- Tenant list / tenant score sub-screens: DELETE if mock (verify data source during planning; expectation: mock → delete)

### Auth (landlord-only)
- **Login:** remove "Tenant Dev" button; keep ONE dev bypass renamed "Dev sign-in" (still uses `devBypassProvider` with `UserRole.landlord`). Email/password login unchanged functionally. Restyle: wordmark, paper background, brass primary button.
- **Register:** remove the Tenant/Landlord role selector entirely; registration always creates `UserRole.landlord`. Restyle to match.
- **Splash:** restyle to embossed serif wordmark on paper with tagline.
- `UserRole` enum: keep the enum (data compatibility) but no UI surface ever exposes or selects tenant.

### Rebrand copy
- Wordmark: **ResiDex**
- Tagline (splash/login): "Your properties' paperwork, answered."
- pubspec.yaml description: "Rental-lifecycle app for landlords — property portfolio and AI document management."
- Android app label (AndroidManifest.xml): "ResiDex"
- All remaining copy follows: plain verbs, sentence case, buttons say what they do ("Upload document", not "Submit").

### Deletions (complete list)
- `lib/features/landlord/presentation/screens/2-Finance/` (entire)
- `lib/features/landlord/presentation/screens/5-Community/` (entire)
- `lib/features/landlord/presentation/screens/3-REX/rex_ai_main_menu_screen.dart`, `rex_ai_tab_wrapper.dart`, `landlord_rex_ai_screen.dart`, `sub/lease_generator_screen.dart`, `sub/maintenance_ai_screen.dart`, `sub/revenue_analytics_screen.dart` (documind_screen.dart survives, relocated/promoted)
- `lib/features/landlord/presentation/screens/1-Command/sub/` mock screens (maintenance, system health, ticket detail) — verify mock first
- `lib/features/shared/presentation/screens/community/`, `gamification/`, `maintenance/` (verify no live usage)
- `lib/core/theme/app_gradients.dart` (neon gradient system)
- All routes, DI providers, imports, and nav entries referencing deleted screens
- Tenant Dev button + register role selector

## Error & empty states

- Documind ask failure: "Couldn't reach Documind. Check that the backend is running, then try again." (sentence case, names the fix)
- Upload failure: "Upload didn't finish. Check your connection and try again."
- No citations found: existing "couldn't find relevant information" backend message displays in a quiet slate card, not an error style.
- Every deleted "Coming Soon" snackbar is gone — nothing in the shipped app references unbuilt features.

## Quality floor

- `flutter analyze`: 0 errors after every task
- App builds and boots to login; Landlord dev bypass reaches the 3-tab shell
- No hardcoded hex colors in screen files — all color/type through the token system
- Visible keyboard focus on inputs; reduced motion respected
- No references to tenant, lease generation, finance, or community remain in UI copy or navigation

## Testing approach

- `flutter analyze` gate per task
- Existing widget/unit tests (if any reference deleted screens) updated or removed with the screens they covered
- Manual smoke path: splash → login (dev bypass) → Dashboard → Documind tab → ask flow renders (backend optional; UI must handle backend-down gracefully per error states) → Portfolio list

## Build order (for the implementation plan)

1. Token system + google_fonts (theme files rebuilt; old tokens aliased temporarily to avoid a big-bang break)
2. Deletions (screens, routes, providers) + 3-tab shell
3. Auth screens (landlord-only + restyle)
4. Dashboard rebuild
5. Documind promotion + certified-extract styling
6. Portfolio restyle
7. Rebrand metadata + final copy pass + cleanup of temporary aliases
