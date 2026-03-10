# RESIDEX - Residential Operating System - Project Memory

> **Last Updated:** January 30, 2026
> **Project Status:** Architecture Refactored ✅ | Clean Slate Build Phase
> **Phase:** Phase 0 - Core Infrastructure Established
> **Current Location:** `c:\Users\user\Downloads\Residex-main\Residex-main\Codes\Residex_app\Residex_app\`
> **Framework:** Flutter 3.24+ | **Database:** Drift 2.28.2 (SQLite) + Firebase Firestore | **State Management:** Riverpod 3.1.0
> **Architecture:** Clean Architecture + Role-Based Feature Structure
> **SDK:** Dart >=3.0.0 <4.0.0 (Fixed from invalid ^3.10.0)
> **Target:** Windows-first development, Android production deployment
> **Current Status:** Minimal skeleton with 5-tab navigation (Command, Finance, Rex AI, Portfolio, Community)

---

## 🎯 WHAT IS RESIDEX?

**Residex** (Resident Index) is Malaysia's first comprehensive residential super app that digitizes the entire rental lifecycle—from move-in to daily operations to move-out.

**Tagline:** "Index your rental life"

**One-Line Pitch:** Residex protects deposits through timestamped photos, splits bills fairly with receipt scanning, tracks chores automatically, and creates portable rental resumes—transforming chaotic shared housing into structured harmony.

---

## 🚨 THE PIVOT STORY (JANUARY 9, 2026)

### **From: SplitLah Bill Splitter**
- 97% complete UI for bill splitting only
- Malaysian-first bill splitting app
- 109 Dart files, 20,334 lines of code
- Working features: Bills, groups, users, gamification

### **To: Residex Residential Super App**
- Comprehensive rental lifecycle platform
- 7 core modules (not just bills)
- Repurposing 40% of existing codebase

### **Why We Pivoted:**
- Bill splitting is commoditized (Splitwise dominates)
- "No one cares about standalone bill splitters" (user insight)
- Bigger market opportunity in full rental management
- Deposit protection (Digital Handover) is killer feature

### **What We're Keeping:**
- ✅ Bill splitting logic (90% reuse)
- ✅ User/friends management (80% reuse)
- ✅ Groups system → Property system (85% reuse)
- ✅ UI components (avatars, cards, animations) (60-100% reuse)
- ✅ Drift database architecture (extend, not rebuild)
- ✅ Riverpod state management (reuse pattern)

### **What We're Removing:**
- ❌ Gamification badges system (stripped out for focus)
- ❌ Achievement showcase screens
- ❌ Badge widgets and painters
- ❌ Leaderboards
- **Reason:** Focus on practical utility over game mechanics

---

## 📊 CURRENT CODEBASE STATE (JANUARY 30, 2026)

### **Clean Slate Rebuild Status:**
- **Total Dart Files:** ~15 files (minimal skeleton)
- **App Name:** residex_app
- **Compilation Status:** ✅ 0 ERRORS - Builds successfully on Windows
- **UI Status:** 5-tab bottom navigation with placeholder screens
- **Architecture:** Clean Architecture fully implemented with core/ infrastructure

### **Architecture Transformation (January 29-30, 2026):**

**MAJOR REFACTORING COMPLETED:**
1. ✅ Fixed SDK constraint from invalid `^3.10.0` to `>=3.0.0 <4.0.0`
2. ✅ Cleaned up incomplete feature modules (8 folders removed)
3. ✅ Implemented role-based architecture (landlord/tenant/shared)
4. ✅ Extracted screens into proper feature folders
5. ✅ Created reusable bottom navigation component
6. ✅ Established core/ infrastructure (DI, routing, theming, error handling)
7. ✅ Fixed google_fonts corruption with cache repair

### **Current Directory Structure:**
```
lib/
├── main.dart                           # App entry point (simplified, 30 lines)
├── core/                               # 🔧 CRITICAL - Cross-cutting concerns
│   ├── di/injection.dart              # Dependency Injection (Riverpod providers)
│   ├── router/app_router.dart         # Centralized navigation
│   ├── theme/app_theme.dart           # Global theming (dark theme, colors)
│   ├── errors/error_handling.dart     # Failure/Exception patterns
│   ├── utils/                         # Constants, formatters, validators
│   └── widgets/                       # Shared UI components
│       └── custom_bottom_nav_bar.dart # Reusable nav bar (glass morphism)
│
└── features/                           # Feature modules (role-based)
    ├── landlord/                       # 🏠 Landlord-specific features
    │   ├── domain/                    # Business logic (empty, to be filled)
    │   │   ├── entities/
    │   │   ├── repositories/
    │   │   └── usecases/
    │   ├── data/                      # Data implementation (empty)
    │   │   ├── datasources/
    │   │   ├── models/
    │   │   └── repositories/
    │   └── presentation/              # UI layer
    │       ├── screens/               # All landlord screens
    │       │   ├── landlord_home_screen.dart         # Navigation shell (~95 lines)
    │       │   ├── landlord_command_screen.dart      # Dashboard (placeholder)
    │       │   ├── landlord_finance_screen.dart      # Finance (placeholder)
    │       │   ├── landlord_rex_ai_screen.dart       # Rex AI (placeholder)
    │       │   ├── landlord_portfolio_screen.dart    # Portfolio (placeholder)
    │       │   └── landlord_community_screen.dart    # Community (placeholder)
    │       ├── widgets/               # Landlord-specific widgets (empty)
    │       └── providers/             # Riverpod state management (empty)
    │
    ├── tenant/                         # 👤 Tenant-specific features (to be created)
    │   ├── domain/
    │   ├── data/
    │   └── presentation/
    │
    └── shared/                         # 🤝 Shared between roles
        ├── domain/                    # Shared business logic (to be filled)
        ├── data/                      # Shared data layer (to be filled)
        └── presentation/widgets/      # Shared UI components (empty)
│       ├── splitlah_loader.dart
│       ├── toast_notification.dart
│       ├── grid_overlay.dart
│       ├── scanline_effect.dart
│       ├── splitlah_logo.dart
│       └── badge_widget/          # Badge system (to be removed)
│
├── data/                          # Data layer
│   ├── database/                  # Drift database
│   │   ├── app_database.dart      # Database config (4 tables)
│   │   ├── tables/                # Table definitions
│   │   │   ├── users_table.dart
│   │   │   ├── groups_table.dart
│   │   │   ├── bills_table.dart
│   │   │   └── receipt_items_table.dart
│   │   └── daos/                  # Data access objects
│   │       ├── user_dao.dart
│   │       ├── group_dao.dart
│   │       └── bill_dao.dart
│   └── local/                     # Local data sources
│       └── demo_data.dart         # Demo data seeder
│
├── features/                      # Feature modules (6 features)
│   ├── auth/                      # Authentication (3 screens - visual only)
│   │   └── presentation/screens/
│   │       ├── splash_screen.dart
│   │       ├── new_splash_screen.dart
│   │       └── login_screen.dart
│   │
│   ├── bills/                     # Bill splitting (41 files) ✅
│   │   ├── domain/
│   │   │   ├── entities/          # Bill, ReceiptItem entities
│   │   │   ├── repositories/      # Abstract interfaces
│   │   │   └── usecases/          # Business logic (4 use cases)
│   │   │       ├── calculate_bill_splits.dart
│   │   │       ├── calculate_user_balances.dart
│   │   │       ├── save_completed_bill.dart
│   │   │       └── update_payment_status.dart
│   │   ├── data/
│   │   │   ├── models/            # Bill & ReceiptItem models
│   │   │   ├── datasources/       # Local data source
│   │   │   ├── repositories/      # Repository implementations
│   │   │   └── local/             # Payment methods data
│   │   └── presentation/
│   │       ├── providers/         # Riverpod providers
│   │       ├── screens/           # 12+ bill screens
│   │       │   ├── dashboard_screen.dart
│   │       │   ├── my_bills_screen.dart
│   │       │   ├── you_owe_screen.dart
│   │       │   ├── owed_to_you_screen.dart
│   │       │   ├── bill_summary_screen.dart
│   │       │   ├── payment_history_screen.dart
│   │       │   ├── group_bills_screen.dart
│   │       │   └── bill_creation/  # 7 bill creation screens
│   │       ├── widgets/           # Bill-specific widgets
│   │       └── utils/             # Payment method extensions
│   │
│   ├── property/                  # Properties (MIGRATED from groups) ⚠️ BROKEN
│   │   ├── domain/
│   │   │   ├── entities/property.dart  # Still uses AppGroup class name
│   │   │   └── repositories/property_repository.dart
│   │   ├── data/
│   │   │   ├── models/property_model.dart
│   │   │   ├── datasources/property_local_datasource.dart
│   │   │   ├── repositories/property_repository_impl.dart
│   │   │   └── local/property_constants.dart
│   │   └── presentation/
│   │       ├── providers/properties_provider.dart
│   │       └── widgets/
│   │           ├── add_member_modal.dart
│   │           ├── property_editor_modal.dart
│   │           ├── property_action_modal.dart
│   │           ├── duplicate_property_warning.dart
│   │           └── delete_property_confirmation.dart
│   │
│   ├── users/                     # User management ✅
│   │   ├── domain/
│   │   │   ├── entities/app_user.dart
│   │   │   └── repositories/user_repository.dart
│   │   ├── data/
│   │   │   ├── models/app_user_model.dart
│   │   │   ├── datasources/user_local_datasource.dart
│   │   │   └── repositories/user_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/users_provider.dart
│   │       ├── screens/profile_editor_screen.dart
│   │       └── utils/user_helpers.dart
│   │
│   ├── home/                      # Home feature (STUB - empty)
│   └── profile/                   # Profile feature (STUB - empty)
│
├── infrastructure/                # External integrations (EMPTY - created but not implemented)
│   ├── database/                  # Planned: Drift + Firebase sync
│   ├── ml/                        # Planned: OCR, image processing
│   └── external/                  # Planned: Payment, email, SMS
```

### **Key Files Implemented:**

**1. main.dart** (30 lines - simplified)
- Direct launch of LandlordHomeScreen
- No DI, database seeding, or error handling yet
- Uses AppTheme.darkTheme

**2. core/widgets/custom_bottom_nav_bar.dart** (~240 lines)
- Reusable navigation component for landlord/tenant
- Glass morphism effect on center button (Rex AI)
- Protruding circular button (64x64, elevated 28px)
- Gradient fade at top of nav bar
- Configurable tabs with icons, labels, colors
- Animated transitions (300ms)

**3. core/theme/app_theme.dart**
- Dark theme with blue/cyan/indigo/purple color scheme
- Glass morphism effects using BackdropFilter
- Consistent styling across app

**4. features/landlord/presentation/screens/landlord_home_screen.dart** (~95 lines)
- Navigation shell with IndexedStack
- 5 landlord-specific screens
- Custom bottom navigation configuration
- Tab management with setState

**5. Landlord Screen Files** (all ~40 lines each)
- landlord_command_screen.dart - Dashboard placeholder
- landlord_finance_screen.dart - Finance placeholder  
- landlord_rex_ai_screen.dart - Rex AI placeholder
- landlord_portfolio_screen.dart - Portfolio placeholder
- landlord_community_screen.dart - Community placeholder

### **What's NOT Implemented Yet:**
❌ Database (Drift) - No tables created
❌ Firebase integration - Not configured
❌ Authentication - No login/signup
❌ Dependency injection - injection.dart empty
❌ Navigation router - app_router.dart empty
❌ Error handling - error_handling.dart empty
❌ Domain/data layers - All empty folders
❌ Any actual feature functionality - All placeholders

### **Backed Up Files:**
- features_backup/ contains original 11 incomplete feature modules from previous attempt
- Error handling (exceptions & failures)
- Navigation (GoRouter with custom transitions, 18 routes)
- Theme system (AppTheme, colors, gradients)
- 8 shared widgets (Avatar, GlassCard, Loader, Toast, GridOverlay, ScanlineEffect, Logo, Animations)
- Extensions & utilities (performance_tier, particles_pool, constants)

✅ **Database (Drift)**
- 4 tables implemented:
  1. `users` - User profiles
  2. `groups` - Housemate groups (will become `properties`)
  3. `bills` - Bill records
  4. `receipt_items` - Line items from receipts
- 3 DAOs (UserDao, GroupDao, BillDao)
- Demo data seeder for first launch

❌ **Gamification Module (to be REMOVED)**
- Achievement entities
- Gamification hub screen
- Badge widgets & painters
- Checkpoint cards & trophy overlays

⚠️ **Auth Module (minimal - needs expansion)**
- 2 splash screens
- No actual authentication yet

❌ **NOT YET IMPLEMENTED (Residex-specific features):**
- Digital Handover (star feature)
- Chores system
- Scores system (Fiscal + Harmony)
- Resources monitor
- Maintenance tickets
- Community board
- Firebase integration (Auth, Firestore, Storage, etc.)
- OCR receipt scanning (Google ML Kit)
- Phone number authentication


---

## 🏛️ RESIDEX ARCHITECTURE (JANUARY 30, 2026)

### **Architecture Pattern: Clean Architecture + Role-Based Features**

Residex follows **Clean Architecture** principles with **role-based feature organization**:

```
┌─────────────────────────────────────────────────────────┐
│                 Presentation Layer                       │
│        (UI, Widgets, Screens, State Management)         │
├─────────────────────────────────────────────────────────┤
│                    Domain Layer                          │
│         (Business Logic, Entities, Use Cases)           │
├─────────────────────────────────────────────────────────┤
│                     Data Layer                           │
│    (Repositories, Data Sources, Models, External APIs)  │
└─────────────────────────────────────────────────────────┘
```

### **Why Role-Based Over Feature-Based?**

**OLD APPROACH (Feature-Based):**
```
features/
├── command/    # Dashboard
├── finance/    # Bills
├── rex_ai/     # AI Assistant
├── portfolio/  # Properties
└── community/  # Board
```
**Problem:** Same features need different content for landlord vs tenant

**NEW APPROACH (Role-Based):**
```
features/
├── landlord/   # Landlord-specific screens/logic
├── tenant/     # Tenant-specific screens/logic
└── shared/     # Shared business logic (bills, maintenance, scores)
```
**Benefits:**
- ✅ Clear separation: Landlord sees property income, tenant sees rent payments
- ✅ Reusable UI: Bottom nav bar in `core/widgets/` used by both roles
- ✅ DRY principle: Shared business logic in `shared/` (maintenance tickets, bills)
- ✅ Scalability: Easy to add new role-specific features

### **Core Infrastructure (`lib/core/`)**

**CRITICAL RULE:** Always check `core/` first before implementing features.

**1. Dependency Injection (`core/di/injection.dart`)**
- Central registry for all app dependencies
- Riverpod providers for repositories, use cases, services
- ALWAYS inject dependencies through here (no `new` keywords in features)

**2. Navigation (`core/router/app_router.dart`)**
- Type-safe, centralized routing
- Route definitions for all screens
- Authentication guards for protected routes

**3. Theme (`core/theme/app_theme.dart`)**
- Global dark theme with blue/cyan/indigo/purple color scheme
- AppColors constants for consistent styling
- Glass morphism support (BackdropFilter patterns)

**4. Error Handling (`core/errors/error_handling.dart`)**
- Failure/Exception pattern (Failure for domain, Exception for data)
- Standardized error responses
- Typed error handling (ServerFailure, CacheFailure, etc.)

**5. Utilities (`core/utils/`)**
- AppConstants - App-wide constants (API URLs, timeout durations)
- Formatters - Currency, date, phone number formatting (DRY)
- Validators - Input validation logic

**6. Shared Widgets (`core/widgets/`)**
- custom_bottom_nav_bar.dart - Reusable navigation (landlord/tenant)
- loading_overlay.dart - Loading states
- error_message.dart - Error displays
- **Rule:** Extract reusable UI components here, not in feature folders

### **Feature Development Workflow**

**When building a new feature (e.g., Property Portfolio):**

1. **Create Clean Architecture structure:**
```
features/landlord/portfolio/
├── domain/
│   ├── entities/property.dart          # Business objects
│   ├── repositories/property_repo.dart # Abstract interface
│   └── usecases/get_properties.dart    # Business logic
├── data/
│   ├── models/property_model.dart      # DTO
│   ├── datasources/property_ds.dart    # API/DB
│   └── repositories/property_repo_impl.dart
└── presentation/
    ├── providers/properties_provider.dart  # Riverpod
    ├── screens/portfolio_screen.dart
    └── widgets/property_card.dart
```

2. **Register in DI (`core/di/injection.dart`):**
```dart
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PropertyRepositoryImpl(PropertyLocalDataSource(db));
});
```

3. **Add route (`core/router/app_router.dart`):**
```dart
case '/landlord/portfolio':
  return MaterialPageRoute(builder: (_) => PortfolioScreen());
```

4. **Use shared theme (`core/theme/app_theme.dart`):**
```dart
color: AppColors.primary,
textStyle: AppTextStyles.heading,
```

5. **Reuse core widgets:**
```dart
import 'package:residex_app/core/widgets/loading_overlay.dart';
```

### **Design Patterns Used**

1. **Repository Pattern** - Abstracts data sources from business logic
2. **Dependency Injection** - Riverpod providers for all dependencies
3. **State Management** - Riverpod (FutureProvider, StateNotifier)
4. **Use Case Pattern** - Single-responsibility business logic classes
5. **MVVM** - Separation between UI and business logic

### **Testing Strategy**
```
test/
├── unit/          # Business logic tests (use cases, repositories)
├── widget/        # UI component tests
└── integration/   # Full flow tests
```

---

## 🎯 CURRENT IMPLEMENTATION STATUS (JANUARY 30, 2026)

### **Completed:**
✅ Fixed SDK constraint (^3.10.0 → >=3.0.0 <4.0.0)
✅ Cleaned up incomplete features (8 folders removed to features_backup/)
✅ Implemented role-based architecture (landlord/tenant/shared structure)
✅ Created landlord navigation shell with 5 tabs
✅ Extracted custom bottom nav bar to core/widgets/
✅ Established core/ infrastructure folders (DI, routing, theme, errors, utils)
✅ Fixed google_fonts corruption with flutter pub cache repair
✅ App builds successfully on Windows (0 errors)
✅ Documented architecture in "Architecture & Design Pattern Overview.txt"

### **In Progress:**
⚠️ Placeholder screens (all show "Coming Soon")
⚠️ Empty core/ files (injection.dart, app_router.dart, error_handling.dart)
⚠️ No database implementation yet
⚠️ No Firebase integration

### **Next Steps (Priority Order):**
1. **Initialize core/ infrastructure:**
   - Populate injection.dart with base providers
   - Set up app_router.dart with routes
   - Create error handling classes (Failures, Exceptions)
   - Add constants, formatters, validators to utils/

2. **Implement first feature (Property Portfolio):**
   - Create domain entities (Property)
   - Build data models and repositories
   - Set up Drift database table
   - Create functional portfolio screen
   - **Reason:** Foundation for all other features

3. **Set up Firebase:**
   - Configure Firebase project
   - Add firebase_core, firebase_auth packages
   - Implement phone number authentication
   - Set up Firestore sync

4. **Build Digital Handover (star feature):**
   - Photo capture with annotations
   - Timestamped reports
   - PDF generation
   - Move-in/move-out comparison

5. **Implement Bill Splitter:**
   - OCR receipt scanning (Google ML Kit)
   - Splitting logic
   - Payment tracking

6. **Develop Honor System:**
   - 5-tier level structure
   - Report/tribunal system
   - Rental resume generation

---

### **Existing Packages (pubspec.yaml):**
```yaml
dependencies:
  flutter_riverpod: ^3.1.0         # State management ✅
  riverpod_annotation: ^4.0.0      # Code generation ✅
  drift: ^2.28.2                   # Local database ✅
  sqlite3_flutter_libs: ^0.5.24    # SQLite support ✅
  camera: ^0.11.0+2                # Camera access ✅
  flutter_animate: ^4.5.2          # Animations ✅
  google_fonts: ^5.1.0             # Typography ✅ (downgraded from 8.0.0)
  lucide_icons_flutter: ^1.2.2     # Icons ✅
  intl: ^0.20.2                    # Internationalization ✅
  image_picker: ^1.1.2             # Image selection ✅
  path_provider: ^2.1.6            # File paths ✅
  flutter_contacts: ^1.1.9         # Contact access ✅

  # TO ADD for full Residex implementation:
  # firebase_core, firebase_auth, cloud_firestore, firebase_storage
  # firebase_messaging, firebase_analytics, firebase_crashlytics
  # google_ml_kit_text_recognition (OCR)
  # dartz (Either<Failure, Success> pattern)
  # equatable (Value equality)
  # uuid (ID generation)
  # go_router (Navigation - currently using MaterialApp)
```

### **MODULE A: CORE ENGINE (The "OS")**
**Purpose:** Transform tenant behavior into measurable, portable reputation

**Key Features:**
1. **Residex Honor System (Gamified Stewardship System)**
   *Inspired by competitive gaming honor systems (LoL, CS:GO)*

   - **5-Tier Honor Levels (0-5):**
     - **Level 5 (Paragon):** Elite - Top 5%, 6+ months clean, community contributions
     - **Level 4 (Exemplary):** Excellent - 3+ months clean, positive ratings
     - **Level 3 (Trusted):** Good - 1+ months clean, steady positive behavior
     - **Level 2 (Neutral):** Starting Point - Default for new users
     - **Level 1 (Rehabilitation):** Probation - Recovering from Level 0
     - **Level 0 (Restricted):** Lockout - Severe violations, limited features

   - **Report Categories (Evidence-Based):**
     - Griefing/Damage, Toxic/Noise, AFK/Non-Payment, Cheating/Lease Violation

   - **Verification ("Overwatch" Model):**
     - AI Triage → Evidence Review → Tribunal (Level 4-5 users) → Verdict

   - **Trust Factor (Hidden k-factor):** Weights report impact by reporter credibility

2. **Rental Resume:** Portable PDF/link with Honor Level, Fiscal Score, verified history, shareable with landlords

**LEGAL COMPLIANCE NOTE:**
- ✅ NOT a "credit score" system (avoids Credit Reporting Agencies Act 2010 regulation)
- ✅ Displays factual payment streaks ("Payment Streak: 12 Months Perfect") not risk assessments
- ✅ Consensual data sharing via "Share My Profile" button
- ✅ Terms of Service clarifies it's a "reputation system" for platform behavior, not financial solvency
- ✅ Uses qualitative badges/levels instead of numerical scores like "750"

**NOTE:** Achievement Badge System removed (gamification stripped out for focus)

---

### **⚖️ LEGAL COMPLIANCE: THE "UBER DEFENSE" APPROACH**

**Problem:** Malaysia's Credit Reporting Agencies Act 2010 requires a RM 50,000+ license from Bank Negara Malaysia if you operate a "credit scoring" system.

**Solution:** Residex uses the **"Uber Defense"** - we don't assess financial solvency, we rate platform behavior.

**Key Legal Distinctions:**

| ❌ AVOID (Triggers Regulation) | ✅ USE (Safe) |
|--------------------------------|---------------|
| "Fiscal Credit Score" | "Tenant Reliability Rating" |
| "750/1000" numerical score | "Rent Hero" badge level |
| "Creditworthiness assessment" | "Payment streak: 12 months perfect" |
| "Risk analysis" | "Factual payment history" |
| "Financial solvency rating" | "Platform behavior rating" |

**Implementation Rules:**
1. ✅ **Display Streaks, Not Scores:** "Payment Streak: 12 Months Perfect" (factual record)
2. ✅ **Use Qualitative Badges:** "Prompt Payer" / "Rent Hero" / "Laggy" (not 0-1000 numbers)
3. ✅ **Consensual Sharing:** User must hit "Share My Profile" button (explicit consent)
4. ✅ **Terms of Service Clarity:** State it's "internal payment history aggregated into Community Badge"
5. ✅ **Platform Behavior Only:** We rate "pays rent on time within Residex" not "can they afford a mortgage"

**What We Can Legally Display:**
- ✅ "Payment Streak: 6 Months Perfect"
- ✅ Honor Level: "Level 4 - Exemplary" (green badge icon)
- ✅ "Chore Completion Rate: 95% this month"
- ✅ "Time at Current Level: 3 months"
- ✅ "Average Payment Time: <24 hours"

**What We CANNOT Display:**
- ❌ "Fiscal Score: 850/1000"
- ❌ "Credit Risk: Low"
- ❌ "Recommended Maximum Rent: RM 1,500"
- ❌ "Loan Approval Likelihood: High"

**Precedent:** Uber/Grab rate driver behavior (5 stars), Airbnb rates guest behavior (Superhost status), Carousell has seller ratings. None need Bank Negara licenses because they don't assess financial solvency.

**Closed-Loop Consent:** Users agree in ToS that payment history within Residex can be shared with prospective landlords AS A CONVENIENCE FEATURE. This is not "credit reporting" - it's testimonial sharing.

---

### **MODULE B: OPERATIONS (Daily Life)**
**Purpose:** Manage day-to-day rental operations and finances

**Key Features:**
1. **Bill Splitter with Receipt Verification** (90% from existing code)
   - OCR receipt scanning (Google ML Kit + Cloud Vision API)
   - Malaysian bill templates (TNB, TM, Air Selangor)
   - Equal split / Custom % / Per-item assignment
   - Payment tracking + reminders

2. **Chore Scheduler with Accountability**
   - Auto-rotation (fair distribution)
   - Photo verification (optional)
   - Completion tracking + leaderboard

3. **Resource Monitor:** Track shared supplies (toilet paper, gas, detergent), reimbursement requests

4. **Property Dashboard:** Quick actions, recent activity feed, house scores

---

### **MODULE C: LIFECYCLE (Governance)**
**Purpose:** Legal protection and formal communication

**Key Features:**
1. **Digital Handover (STAR FEATURE - "Digital Lawyer")** 🌟
   - **Move-in:**
     - Multi-photo capture with room tagging
     - Defect annotation (circle damage, add notes)
     - Timestamp watermarking (crypto-verified)
     - PDF report generation (legal evidence)

   - **MECHANISM 1: Ghost Overlay (Perfect Alignment)** 👻
     - Move-out camera displays move-in photo as translucent overlay
     - Forces exact alignment of furniture/walls
     - Alignment detection (percentage match)
     - Creates perfect side-by-side comparison
     - No Small Claims Court can argue with this

   - **MECHANISM 2: Double-Handshake (Legal Lock)** 🔒
     - Landlord receives notification (email/SMS/push)
     - 7-day review window
     - Landlord must "AGREE", "DISPUTE", or "REJECT"
     - Auto-locks after 7 days if no response
     - Once locked: Read-only, tamper-proof, legally binding
     - Court-admissible evidence

   - **Move-out:** Before/After comparison with AI analysis
   - **Dispute Tools:** Letter generator, fair deduction calculator, Small Claims Court guidance

2. **Maintenance Ticket System**
   - Formal issue reporting (photo documentation)
   - Urgency levels (Low/Medium/High/Urgent)
   - Auto-escalation (no ghost landlords)
   - Landlord performance ratings

3. **Community Board (Property Forum)**
   - Management announcements (pinned)
   - Community Q&A (upvotes, best answers)
   - Polls (with live results)
   - Event planning (RSVP tracking)

---

## 📋 THE 6 PROBLEMS RESIDEX SOLVES

1. **The Deposit Trap** 💸
   - 78% of Malaysian tenants lose RM 800-2,000 per tenancy
   - Solution: Digital Handover with timestamped photos + legal PDF reports

2. **Bill Disputes** 🧾
   - 65% of shared housing has monthly bill arguments
   - Solution: Bill Splitter with OCR + payment tracking

3. **Chore Wars** 🧹
   - 82% cite chores as primary housemate friction
   - Solution: Chore Scheduler with auto-rotation + gamification

4. **Ghost Landlords** 👻
   - 21-day average response time for maintenance
   - Solution: Maintenance Tickets with auto-escalation + rating system

5. **Reputation Gap** 📊
   - Good tenants can't prove reliability to new landlords
   - Solution: Honor System (5-tier levels) + Fiscal Score + portable rental resume

6. **Communication Chaos** 📱
   - Important property updates get lost in WhatsApp groups
   - Solution: Community Board with structured announcements and Q&A

---

## 🛠️ TECHNICAL STACK

### **Frontend:**
- Flutter 3.10+ (Dart)
- Riverpod 2.5+ (State Management)
- Go Router 14.2+ (Navigation)
- Google Fonts (Typography)
- Flutter Animate 4.5+ (Animations)
- Lucide Icons 0.257.0

### **Backend (Google Tools Only - KitaHack Requirement):**
- **Firebase Authentication:** Phone number login (+60 Malaysia)
- **Firebase Firestore:** Cloud database sync
- **Firebase Storage:** Photos, PDFs, receipts
- **Firebase Cloud Messaging:** Push notifications
- **Firebase Cloud Functions:** Auto-escalation, reminders
- **Firebase Analytics:** User behavior tracking
- **Firebase Crashlytics:** Crash reporting

### **AI/ML (Google Tools):**
- **Google ML Kit:** On-device OCR (free, offline)
- **Google Cloud Vision API:** Advanced OCR backup (1,000 free/month)
- **Google Cloud Translation API:** Guard translation chat (500k chars free)
- **TensorFlow Lite:** AI damage detection (optional)

### **Local Database (Drift/SQLite):**
Offline-first architecture with 14 core tables:

1. **users** - profiles, badge levels, payment streaks
2. **properties** - houses/units with landlord info
3. **groups** - housemate groups (reuse existing)
4. **bills** - bills with splitting logic
5. **receipt_items** - line items from bills
6. **chores** - recurring chore definitions
7. **chore_instances** - individual chore occurrences
8. **handovers** - move-in/move-out reports
9. **handover_photos** - timestamped photos + annotations
10. **tickets** - maintenance issue tracking
11. **honor_events** - honor level changes, reports, tribunal verdicts
12. **community_posts** - announcements, questions, polls, events
13. **community_comments** - comments/answers on posts
14. **comment_votes** - upvote/downvote tracking

**Supporting Tables:** chore_swaps, resources, resource_purchases, shopping_list, defects, ticket_comments, notifications, payment_history (for streak calculations)

---

## 📊 FEATURE PRIORITY (FOR DEVELOPMENT)

### **TIER 1: MUST BUILD (Core Features)**
1. ✅ Property Management (foundation)
2. ✅ Digital Handover (star feature, biggest impact)
3. ✅ Bill Splitter + OCR (existing strength, daily use)
4. ✅ Honor System (defines Residex concept - 5-tier levels + Trust Factor)
5. ✅ Chore Scheduler (feeds Honor progression, solves friction)
6. ✅ Authentication (phone number login)

### **TIER 2: SHOULD BUILD IF TIME ALLOWS**
7. ⚠️ Resource Monitor (extends bills naturally)
8. ⚠️ Maintenance Tickets (shows lifecycle management)
9. ⚠️ Community Board (engagement, stickiness)

### **TIER 3: POST-HACKATHON**
10. ❌ Visitor Pass Generator
11. ❌ Guard Translation Chat
12. ❌ Digital Rulebook

---

## 🏛️ PRODUCTION-READY ARCHITECTURE (JANUARY 10, 2026)

### **Architectural Principles**

**1. Clean Architecture + Feature-First Design**
- **Layers:** Presentation → Domain → Data
- **Features:** Self-contained modules with minimal coupling (10 features)
- **Shared:** Common utilities, widgets, and services
- **Infrastructure:** Database, ML, external integrations

**2. Scalability & Modularity**
- Lazy loading for large features
- Code splitting by feature
- Modular state management (Riverpod)
- Independent feature deployment readiness
- Abstract interfaces for all external dependencies

**3. Feature Independence**
- Each feature is self-contained with own domain/data/presentation
- Features communicate via well-defined interfaces
- No direct dependencies between features
- Use shared domain entities

**4. Offline-First with Sync**
- Drift (SQLite) for local storage
- Firebase Firestore for cloud sync
- Sync manager with conflict resolution
- Offline queue for pending operations

---

### **Directory Structure Overview**

```
lib/
├── app/                    # Root app configuration, routing, theme
├── core/                   # Shared infrastructure
│   ├── constants/          # App-wide constants
│   ├── config/             # Environment config
│   ├── extensions/         # Dart extensions
│   ├── utils/              # Utilities (logger, validators, etc.)
│   ├── errors/             # Error handling
│   ├── network/            # API client, interceptors
│   ├── storage/            # Local & secure storage
│   ├── services/           # Analytics, notifications, etc.
│   └── di/                 # Dependency injection
│
├── shared/                 # Shared components
│   ├── domain/             # Base entities, use cases
│   ├── data/               # Base models, repositories
│   ├── presentation/
│   │   ├── widgets/        # Reusable UI components (60+ widgets)
│   │   └── theme/          # Design system
│   └── l10n/               # Localization
│
├── features/               # Feature modules (10 features)
│   ├── authentication/
│   ├── property/
│   ├── bills/
│   ├── chores/
│   ├── handover/           ⭐ Star feature
│   ├── honor/              # Honor System (5-tier levels + Trust Factor)
│   ├── resources/
│   ├── maintenance/
│   ├── community/
│   ├── user/
│   └── notifications/
│
├── infrastructure/         # External integrations
│   ├── database/
│   │   ├── drift/          # Local SQLite
│   │   └── firebase/       # Firestore sync
│   ├── ml/                 # OCR, image processing
│   └── external/           # Payment, email, SMS
│
└── test/                   # Tests
    ├── unit/
    ├── widget/
    └── integration/
```

**Each Feature Module Structure:**
```
features/[feature_name]/
├── domain/
│   ├── entities/
│   ├── repositories/       # Abstract interfaces
│   └── usecases/
├── data/
│   ├── models/
│   ├── datasources/
│   └── repositories/       # Implementations
└── presentation/
    ├── screens/
    ├── widgets/
    └── providers/
```

---

### **Key Architectural Decisions**

**1. Dependency Injection (GetIt)**
- Feature-specific DI setup
- Lazy singleton registration
- Easy to swap implementations

**2. Error Handling (Either<Failure, Success>)**
- Using `dartz` package
- All repositories return `Either<Failure, T>`
- Typed error handling
- No try-catch in presentation layer

**3. State Management (Riverpod)**
- `FutureProvider` for async data
- `StateNotifierProvider` for complex state
- `Provider` for singletons
- Family providers for parameterized data

**4. Navigation (GoRouter)**
- Declarative routing
- Type-safe navigation
- Deep linking support
- Authentication guards

**5. Database Strategy**
- **Local:** Drift (SQLite) - Primary data source
- **Remote:** Firebase Firestore - Cloud backup
- **Sync:** Bidirectional with conflict resolution
- **Offline Queue:** Pending operations stored locally

---

## 💾 CURRENT PROJECT STATUS

### **Overall Status (January 11, 2026):**
- **Residex Build:** 0% (architecture planned, implementation not started)
- **Existing Codebase (SplitLah):** 97% UI complete, fully functional bill splitter
- **Code Metrics:** 109 Dart files, ~28,722 lines of code
- **Reusable Code for Residex:** ~40% (bills, users, groups, core infrastructure)
- **Documentation:** 100% complete (10,000+ words in separate doc)
- **Team:** 2 developers committed
- **Timeline:** 6 weeks (KitaHack deadline)
- **Budget:** RM 0 (Google Cloud free tiers)

### **What's Already Working (From SplitLah):**
✅ **Bills Module (90% complete - 41 files)**
- Complete bill creation flow (7 screens)
- Receipt scanning with camera integration
- Item assignment & splitting logic (equal, custom %, per-item)
- Payment method selection (Malaysian e-wallets)
- Bill summary with calculations
- Payment tracking (You Owe / Owed to You screens)
- Payment history view
- Group bills listing
- Balance calculations (4 use cases)
- **Known Bugs:**
  - Payment persistence bug (line 1169 in you_owe_screen.dart)
  - Tax items filter bug (line 41 in assign_items_screen.dart)

✅ **Users Module (80% complete)**
- User entity & model with avatar system
- User repository with Drift DAO
- User provider (Riverpod state management)
- Profile editor screen
- User helpers & utilities

✅ **Groups Module (85% complete)**
- Group entity & model (will become Properties)
- Group repository with Drift DAO
- Group provider (Riverpod)
- Add member modal with validation
- Duplicate group warning
- Delete group confirmation

✅ **Core Infrastructure (70% complete)**
- Dependency injection (GetIt) with providers
- Error handling (Either<Failure, Success> pattern)
- Navigation (GoRouter with custom slide transitions)
- Theme system (dark theme, gradients, colors)
- 8 shared widgets (Avatar, GlassCard, Loader, Toast, etc.)
- Extensions & utilities
- Constants management

✅ **Database (Drift + SQLite)**
- 4 tables: users, groups, bills, receipt_items
- 3 DAOs with query methods
- Demo data seeder for first launch
- Offline-first architecture ready

### **Code Quality (Existing SplitLah):**
- **Compilation:** ✅ 0 errors
- **Warnings:** 4 (unused imports - cosmetic only)
- **UI Overflows:** ~1px (sub-pixel rounding, effectively 0) ✅
- **Null Safety:** 100% ✅
- **Total Files:** 109 Dart files
- **Total Lines:** ~28,722 lines (accurate count)
- **Architecture:** Clean Architecture pattern with domain/data/presentation layers
- **State Management:** Riverpod with providers
- **Navigation:** GoRouter with type-safe routing

---

## ✅ COMPILATION BLOCKERS RESOLVED (JANUARY 18, 2026)

### **STATUS: ✅ APP COMPILES SUCCESSFULLY - 0 ERRORS**

All previously documented blockers have been resolved:
- ✅ AppGroup constructor parameter mismatch - Fixed
- ✅ memberIds vs tenantIds confusion - Fixed
- ✅ PropertyModel inheritance issues - Fixed

**Current Build:** `build\app\outputs\flutter-apk\app-debug.apk` builds successfully

**Resolution Details:**
1. AppGroup constructor calls updated with correct parameters
2. All `memberIds` references replaced with `tenantIds`
3. PropertyModel super constructor parameters corrected
4. Verified with `flutter analyze` - 0 errors

---

## ✅ CRITICAL BUGS FIXED (JANUARY 18, 2026)

### **1. Payment Persistence Bug - FIXED ✅**
- **Location:** `lib/features/bills/presentation/screens/you_owe_screen.dart`
- **Issue:** Payment status only updated local state, not database
- **Fix Applied:** Added `updatePaymentStatus` calls to `_payNetAmount` (line ~1046) and `_paySelected` (line ~1107)
- **Note:** `_markBillAsPaid` was already correctly implemented

### **2. Tax Items Filter Bug - NOT A BUG ✅**
- **Location:** `lib/features/bills/presentation/screens/bill_creation/assign_items_screen.dart:41`
- **Analysis:** Logic was correct - `!= tax` for assignable items, `== tax` for tax items
- **Status:** No fix needed, documentation was incorrect

---

## 📁 KEY FILES & DOCUMENTATION

### **Current Project Location:**
- **Main App Directory:** `D:\Projects\Residex\Codes\Bill_Splitter_App\bill_splitter_app\`
- **Pubspec:** `D:\Projects\Residex\Codes\Bill_Splitter_App\bill_splitter_app\pubspec.yaml`
- **Context Folder:** `D:\Projects\Residex\Codes\Bill_Splitter_App\context\`
- **Database:** `splitlah.db` (4 tables: users, groups, bills, receipt_items)

### **Documentation Files:**

**1. Project Memory (This File - 9,000+ words)**
- **Path:** `D:\Projects\Residex\Codes\Bill_Splitter_App\context\project-memory.md`
- **Content:** Architectural decisions, Current codebase state, Implementation plans, Key context for AI
- **Updated:** January 11, 2026 (Added accurate codebase analysis)

**2. Complete App Documentation (from SplitLah)**
- **Path:** `D:\Projects\Residex\Codes\Bill_Splitter_App\bill_splitter_app\COMPLETE_APP_DOCUMENTATION.md`
- **Content:** Line-by-line analysis of SplitLah implementation, All models, screens, services
- **Purpose:** Understanding existing codebase for migration

**3. Complete Feature Specification (10,000+ words)**
- **Path:** `D:\Projects\Kongsi\Bill_Splitter_App\context\K-OS-Complete-Documentation.md` (old location)
- **Content:** All 8 modules fully specified, Technical architecture, Database schemas, UI specs, Business model
- **Updated:** January 10, 2026 (Ghost Overlay + Double-Handshake added)
- **Note:** May need to be copied to new context folder

**4. Summarized Overview (4,500+ words)**
- **Path:** `D:\Projects\Residex\Residex.docx`
- **Content:** Executive summary, All features, Technical stack, Business model, Roadmap
- **Updated:** January 10, 2026

**5. Implementation Todo List (~500+ tasks)**
- **Path:** `D:\Projects\Residex\to-do-list.md`
- **Content:** 8 phases, Checkboxes for all tasks, Critical path items, Testing checklist
- **Created:** January 10, 2026

**6. Optimization Summary**
- **Path:** `D:\Projects\Residex\Codes\Bill_Splitter_App\bill_splitter_app\OPTIMIZATION_SUMMARY.md`
- **Content:** Performance optimizations done on SplitLah

**7. Release Signing Guide**
- **Path:** `D:\Projects\Residex\Codes\Bill_Splitter_App\bill_splitter_app\RELEASE_SIGNING.md`
- **Content:** Android release build instructions

### **Key Directories to Reuse (From SplitLah):**
✅ **Highly Reusable (80-90% reuse):**
- `lib/features/bills/` → Bill Splitter module (41 files)
- `lib/features/users/` → User management
- `lib/features/groups/` → Convert to Properties (rename & extend)
- `lib/core/widgets/` → UI components (8 shared widgets)
- `lib/core/theme/` → Design system (colors, gradients, text styles)
- `lib/core/router/` → Navigation structure
- `lib/core/di/` → Dependency injection setup
- `lib/core/errors/` → Error handling patterns
- `lib/data/database/` → Drift foundation (extend with 10+ new tables)

❌ **To Be Removed:**
- `lib/features/gamification/` → Gamification system (not needed for Residex)
- `lib/core/widgets/badge_widget/` → Badge widgets
- `lib/test_badge_screen.dart` → Test screen

⚠️ **To Be Transformed:**
- `lib/features/groups/` → Rename to `lib/features/property/` and extend with landlord info, address, lease dates

### **Critical Files for Bug Fixes:**
1. `lib/features/bills/presentation/screens/you_owe_screen.dart:1169` - Payment persistence bug
2. `lib/features/bills/presentation/screens/bill_creation/assign_items_screen.dart:41` - Tax filter bug

---

## 🎯 TARGET MARKET

### **Primary: Students in Shared Housing**
- 18-25 years old, university students
- RM 300-600 rent budget
- Locations: Klang Valley (UM, UKM, Taylor's, Sunway, UTAR, MMU)
- Pain Points: Lost deposits, bill disputes, lazy housemates

### **Secondary: Young Professionals**
- 23-30 years old, first job
- RM 800-1,500 rent budget
- Pain Points: No rental history, ghost landlords

### **Tertiary: Landlords (Individual)**
- 35-60 years old, owns 1-3 rental properties
- Pain Points: Can't monitor tenants remotely, payment delays, property damage

---

## 🏆 COMPETITIVE ADVANTAGE

**Direct Competitors:**
- **Splitwise:** Bill splitting only, no Malaysian features
- **SpeedHome:** Digital tenancy agreements, no tenant scoring
- **PropertyGuru/iProperty:** Listings only, no operations management

**Residex Differentiators:**
1. ✅ **Digital Handover with Ghost Overlay + Double-Handshake** (NO competitor has this) 🌟
   - Ghost Overlay: Translucent photo alignment for perfect move-out comparison
   - Double-Handshake: Landlord agreement within 7 days, auto-locks as legally binding
   - Court-admissible evidence with crypto timestamps
   - **Patent potential** - This is completely unique
2. ✅ **Receipt-verified bill splitting** (Malaysian bills: TNB, TM, Air Selangor with OCR)
3. ✅ **Honor System with 5-tier levels** (rental resume = portable reputation, legally compliant)
4. ✅ **Chore + Resource + Ticket management** (all-in-one)
5. ✅ **Malaysian-first** (TNB, DuitNow, guardhouses, +60 phone)
6. ✅ **Community Board** (property-specific forum)

---

## 💼 BUSINESS MODEL (SUMMARY)

### **Revenue Streams:**
1. **Freemium Subscription:** Free tier + Premium (RM 9.90/month) + Annual (RM 99/year)
2. **Handover Reports:** RM 19.90 per handover (one-time, protects RM 2,000 deposit)
3. **Landlord Dashboard:** RM 299/year (multi-property view, tenant screening)
4. **Agency Enterprise:** RM 299/month (unlimited properties, API access)

### **Conservative Year 2 Projection:**
- 10,000 free users, 500 premium (5% conversion)
- Total: ~RM 113,140/year
- Path to RM 1M ARR: ~100,000 total users by Year 3

---

## 📝 ARCHITECTURE DECISIONS (UPDATED JANUARY 10, 2026)

### **Key Design Patterns:**
- **Architecture:** Clean Architecture + Feature-First Design
- **Offline-First:** Drift (SQLite) for local storage, Firebase for cloud sync
- **State Management:** Riverpod with abstract repositories
- **Navigation:** Go Router with type-safe routing
- **Error Handling:** Either<Failure, Success> pattern (dartz)
- **Dependency Injection:** GetIt with feature-specific modules
- **Image Storage:** Firebase Storage (new)
- **OCR:** Google ML Kit (on-device, free) + Cloud Vision API (backup)
- **Notifications:** Firebase Cloud Messaging
- **Analytics:** Firebase Analytics + Crashlytics

### **Design System:**
- **Colors:** Deep blue + electric purple gradient (tech platform vibe)
- **Typography:** Google Fonts (Poppins for headings, Inter for body)
- **Components:** 60+ shared widgets (buttons, inputs, cards, dialogs, loaders, etc.)
- **Icons:** Lucide Icons
- **Animations:** Flutter Animate

### **Testing Strategy:**
- **Unit Tests:** 80%+ coverage on business logic (use cases)
- **Widget Tests:** 60%+ coverage on UI components
- **Integration Tests:** Critical flows (auth, bills, handover)
- **Manual Testing:** Real devices, offline scenarios, performance

### **Naming Conventions:**
- **App Name:** Residex (Resident Index)
- **Full Name:** Residex - The Resident Index
- **Tagline:** "Index your rental life"
- **Domain:** residex.io / residex.app
- **Social:** @residex

---

## 🎓 KEY LESSONS LEARNED

### **From Pivot (January 9, 2026):**
1. **Standalone bill splitting is commoditized** - Splitwise dominates, people don't care about marginal improvements
2. **Bigger market in full rental management** - Deposit protection alone is worth building for
3. **Repurposing is faster than rewriting** - 40% codebase reuse = 3-4 week head start
4. **Malaysian-first positioning works** - TNB, DuitNow, guardhouses = clear differentiation
5. **Hackathons need scope discipline** - 6 core features > 12 half-baked features

### **From Architecture Planning (January 10, 2026):**
6. **Gamification can be a distraction** - Stripped out badges/leaderboards to focus on utility
7. **Legal mechanisms are the moat** - Ghost Overlay + Double-Handshake = patent potential
8. **Production architecture from day 1** - Clean Architecture + Feature-First prevents tech debt
9. **Feature independence enables scalability** - 10 self-contained features can be deployed separately
10. **Offline-first with sync is critical** - Malaysian internet reliability requires local-first approach

### **Name Selection Process:**
- Rejected: K-OS (too operating system-y, weird to say)
- Considered: Resido, HomePort, RumahOS, Rentex, Rentix
- **Chosen: Residex** (Resident Index)
  - Clear meaning (index your rental life)
  - Professional tech platform sound (like Coinbase, Robinhood)
  - Easy to say and spell
  - Works for B2C (tenants) AND B2B (agencies)

---

## 🚀 NEXT STEPS (UPDATED JANUARY 18, 2026)

### **Phase -1: EMERGENCY COMPILATION FIX - COMPLETED ✅ (January 18, 2026)**
- [x] **FIX BLOCKER 1:** AppGroup constructor calls - Fixed
- [x] **FIX BLOCKER 2:** memberIds → tenantIds - Fixed
- [x] **FIX BLOCKER 3:** PropertyModel inheritance - Fixed
- [x] **VERIFY:** Compilation succeeds with 0 errors ✅
- [x] **BUILD:** APK builds successfully ✅
- [x] **FIX SPLITLAH BUGS:**
  - [x] Payment persistence bug - Fixed (added database updates to `_payNetAmount` and `_paySelected`)
  - [x] Tax filter bug - Not a bug (logic was correct)

### **Phase 0: Project Setup (Day 1-2) - AFTER COMPILATION FIXED**
- [ ] Create Firebase project: `residex-my`
- [ ] Enable all Firebase services (Auth, Firestore, Storage, Functions, Analytics, Crashlytics)
- [ ] Add Firebase packages to pubspec.yaml
- [ ] Set up environment files (.env.development, .env.staging, .env.production)
- [ ] Create new Git branch: `feature/firebase-integration`
- [ ] Review complete todo list (D:\Projects\Residex\to-do-list.md)

### **Phase 1: Core Infrastructure (Week 1)**
- [ ] Create new directory structure (lib/app, lib/core, lib/shared, lib/features, lib/infrastructure)
- [ ] Build core utilities (constants, config, extensions, utils, errors, network, storage, services)
- [ ] Create 60+ shared widgets (buttons, inputs, cards, dialogs, loaders, avatars, animations, overlays)
- [ ] Set up Drift database with 14+ tables
- [ ] Set up Firebase sync infrastructure
- [ ] Configure dependency injection (GetIt)

### **Week 1 Focus (Authentication + Property):**
- [ ] Build authentication feature (phone login + OTP)
- [ ] Build property management feature (groups → properties transformation)
- [x] ~~Fix 2 critical bugs~~ - COMPLETED (January 18, 2026)

### **Week 2 Focus (Digital Handover - STAR FEATURE):**
- [ ] Build move-in photo capture + defect annotation
- [ ] **Implement Ghost Overlay camera** (translucent overlay for alignment)
- [ ] **Implement Double-Handshake workflow** (7-day landlord agreement)
- [ ] Build PDF report generation with crypto timestamps
- [ ] Build move-out comparison flow

### **Week 3 Focus (Bills Migration):**
- [ ] Migrate bills feature to new architecture
- [ ] Integrate Google ML Kit OCR
- [x] ~~Fix payment persistence bug~~ - COMPLETED
- [x] ~~Fix tax filter bug~~ - NOT A BUG (logic was correct)
- [ ] Test complete bill creation flow

### **Week 4 Focus (Honor System + Chores):**
- [ ] Implement Honor System algorithms:
  - [ ] Honor Level calculation (0-5 tiers based on behavior)
  - [ ] Trust Factor (k-factor) calculation for reporter credibility
  - [ ] Report verification pipeline (AI Triage → Evidence Review → Tribunal)
- [ ] Build Honor dashboards (display level, time at level, Trust Factor)
- [ ] Build chore scheduler with auto-rotation
- [ ] Test Honor Level progression and redemption mechanics

### **Week 5-6 Focus (Testing + Polish):**
- [ ] Optional Tier 2 features (Resources, Maintenance, Community)
- [ ] Beta testing with 5-10 houses (25-50 users)
- [ ] Fix bugs, optimize performance
- [ ] Prepare demo for pitch

---

## 🔗 USEFUL RESOURCES

**Firebase Setup:**
- Firebase Console: https://console.firebase.google.com
- Google Cloud Console: https://console.cloud.google.com

**Documentation:**
- Complete Feature Spec: `K-OS-Complete-Documentation.md`
- Project Memory (this file): `project-memory.md`

---

**Last Updated:** January 18, 2026
**Current Phase:** Phase 0 - Ready for Firebase Integration
**Next Milestone:** Firebase setup + Phone Authentication
**Team Status:** 2 developers ready, 6-week sprint
**Codebase Status:** Residex 97 files, ~24,908 lines - COMPILING ✅
**Architecture Status:** Clean Architecture + Feature-First design implemented
**Todo List Status:** ~500+ tasks across 8 phases (D:\Projects\Residex\to-do-list.md)
**Confidence Level:** HIGH
- ✅ Bills module: 90% production-ready (bugs fixed)
- ✅ Users module: 80% solid
- ✅ Property module: 70% functional
- ✅ Core infrastructure: 70% working
- ✅ Compilation: WORKING (0 errors, APK builds)
- ✅ Architecture: Clean Architecture pattern working
- ✅ State: Riverpod, GoRouter, Drift functional
- ⚠️ Firebase: Not integrated yet (next step)

---

## 📝 SESSION HISTORY

### **January 10, 2026 Session - Architecture Planning:**
✅ Designed production-ready Clean Architecture + Feature-First structure
✅ Defined 10 self-contained feature modules
✅ Created 60+ shared widget specifications
✅ Planned Drift + Firebase sync strategy with conflict resolution
✅ Documented dependency injection approach (GetIt)
✅ Designed error handling pattern (Either<Failure, Success>)
✅ Enhanced Digital Handover with Ghost Overlay + Double-Handshake mechanisms
✅ Removed gamification for focus on utility
✅ Created Production-Ready Architecture document (8,000+ words)
✅ Created Implementation Todo List (~500+ tasks)

---

## 📊 WHAT'S NEW (JANUARY 11, 2026 SESSION)

### **Codebase Analysis Complete:**
✅ Analyzed entire SplitLah codebase structure
✅ Counted accurate metrics (109 files, 28,722 lines)
✅ Documented all implemented features in detail
✅ Identified 7 feature modules (auth, bills, gamification, groups, users, home, profile)
✅ Listed all 8 core shared widgets
✅ Documented database schema (4 tables, 3 DAOs)
✅ Updated project paths to current location (`D:\Projects\Residex\Codes\Bill_Splitter_App\`)
✅ Identified which code to reuse (~40%) vs remove (gamification)
✅ Confirmed 2 critical bugs that need fixing

### **Memory File Enhancements:**
✅ Added comprehensive "Current Codebase State" section with:
  - Accurate file counts and line counts
  - Complete directory structure
  - Feature-by-feature breakdown of what's implemented
  - Package inventory (what's installed vs what's needed)
✅ Updated "Current Project Status" with accurate metrics
✅ Updated "Key Files & Documentation" with correct paths
✅ Clarified what's working vs what needs to be built
✅ Distinguished between SplitLah (97% complete) and Residex (0% started)

### **Key Insights Documented:**
1. **Bills Module is production-ready** - 41 files, 90% complete, just needs bug fixes
2. **Groups → Properties transformation** - 85% of code can be reused with renaming
3. **Core infrastructure is solid** - Riverpod, GoRouter, Drift, error handling all in place
4. **Gamification must be removed** - Badge system not needed for Residex utility focus
5. **Firebase integration is the next critical step** - Currently using only local Drift DB
6. **40% code reuse is conservative** - Could be higher if we're strategic

### **Action Items Identified:**
- [ ] Fix 2 critical bugs in SplitLah before migration
- [ ] Remove gamification feature (lib/features/gamification/)
- [ ] Add Firebase packages to pubspec.yaml
- [ ] Rename app from splitlah_app to residex_app
- [ ] Transform groups feature into properties feature
- [ ] Add 10+ new database tables for Residex features

---

## 📝 CRITICAL LEGAL PIVOT (JANUARY 11, 2026 - AFTERNOON SESSION)

### **Scoring System → Badge System Transformation**

**Reason:** Legal compliance with Malaysia's Credit Reporting Agencies Act 2010

**Changes Made:**
✅ Renamed "Dual Score System" → "Badge System (Gamified Reputation)"
✅ Removed all numerical scoring (0-1000) references
✅ "Fiscal Score" → "Payment Badge" with qualitative levels (Prompt Payer, Rent Hero, Laggy)
✅ "Harmony Score" → "Harmony Badge" with color coding (Green, Yellow, Red)
✅ Added comprehensive legal compliance section with "Uber Defense" approach
✅ Updated all 6 references across project memory (MODULE A, Problems, Priority, Advantage, Implementation, Database)
✅ Documented what can/cannot be displayed to avoid Bank Negara regulation

**Key Insight:** Without calling it a "score," we avoid needing a RM 50,000+ credit reporting license. We're rating platform behavior (like Uber), not financial solvency.

**Display Strategy:**
- Show: "Payment Streak: 12 Months Perfect" (factual record)
- Show: Badge level "Rent Hero" with green badge icon
- DON'T Show: "Fiscal Score: 850/1000" (looks like CTOS/CCRIS)

**Consensual Sharing:** User must explicitly hit "Share My Profile" button to share rental resume with landlords. This is testimonial sharing, not credit reporting.

**Legal Precedents:** Uber (driver ratings), Airbnb (Superhost status), Carousell (seller ratings) - all platform behavior ratings that don't require financial licenses.

**ToS Language:** "Payment history within Residex aggregated into Community Badge for convenience" (not "credit assessment")

---

## 📝 CODEBASE ANALYSIS SESSION (JANUARY 17, 2026)

### **Deep Dive Codebase Exploration:**
✅ Analyzed entire current codebase structure (97 files, ~24,908 LOC)
✅ Discovered compilation is BROKEN (46 errors, not 0 as previously documented)
✅ Identified property feature migration as incomplete and causing blockers
✅ Found memberIds vs tenantIds confusion across 7 files
✅ Documented 3 critical compilation blockers with fix estimates
✅ Verified infrastructure directory created but empty
✅ Updated metrics: 97 files (down from 109 - gamification removed)
✅ Confirmed app renamed from splitlah_app to residex_app
✅ Identified new utility files not in previous documentation

### **Key Findings:**
1. **Property Migration Incomplete** - Groups→Properties transformation started but not finished
2. **Parameter Mismatch Crisis** - AppGroup constructor signature changed, breaking 18+ call sites
3. **Database Migration Pending** - Still using `groups` table, not `properties`
4. **Infrastructure Empty** - Directory created but no Firebase/ML integration yet
5. **Bills Module Solid** - 90% production-ready (2 bugs to fix)

### **Critical Action Items Identified:**
- [ ] Fix 46 compilation errors (2-3 hours estimated)
- [ ] Complete property feature migration
- [ ] Rename database table: groups → properties
- [ ] Implement Firebase integration (infrastructure dir)
- [ ] Add Google ML Kit for OCR
- [ ] Fix 2 SplitLah bugs (payment persistence, tax filter)

### **Updated Priorities:**
1. **IMMEDIATE:** Fix compilation blockers (cannot proceed without this)
2. **SHORT TERM:** Complete property migration + 2 bug fixes
3. **MEDIUM TERM:** Firebase + Auth integration
4. **LONG TERM:** Digital Handover + Badge System + Chores

---

## 📝 SESSION: JANUARY 18, 2026 - BUG FIXES & COMPILATION

### **Completed:**
✅ Analyzed actual compilation status (2 errors in test file, not 46 as documented)
✅ Identified test file import as only real error (`splitlah_app` → `residex_app`)
✅ Fixed payment persistence bug in `_payNetAmount` function
✅ Fixed payment persistence bug in `_paySelected` function
✅ Verified tax filter bug was not a bug (logic was correct)
✅ Confirmed successful APK build

### **Key Findings:**
1. **Project memory was outdated** - documented 46 errors but only 2 existed (both in test file)
2. **Payment persistence was missing in 2 of 3 payment functions** - now fixed
3. **Tax filter logic was correct** despite documentation saying otherwise
4. **App now builds successfully** to APK

### **Current State:**
- **Compilation:** ✅ 0 errors
- **Build:** ✅ APK builds successfully
- **Bills Module:** 90% complete, bugs fixed
- **Property Module:** 70% functional
- **Next Step:** Firebase integration + Phone authentication

---

*This document is the single source of truth for the Residex project. Update after each major milestone or pivot.*
*Last comprehensive analysis: January 18, 2026 - Bug fixes and compilation verification*
*Last legal pivot: January 11, 2026 - Scoring System → Badge System for legal compliance*
*Current Status: COMPILATION WORKING ✅ - Ready for Phase 0 (Firebase Integration)*
