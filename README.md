# Residex — The Shared Living Operating System
# Link for questionnaire responses collected: https://docs.google.com/spreadsheets/d/10jeovxl1__syRfBeqFp_1-RYJFhZuR7U/edit?usp=sharing&ouid=114163723031397476054&rtpof=true&sd=true
#Link for PowerPoint Presentation File: https://docs.google.com/presentation/d/1r5MoE1Z7d-xt2aSQY3yknFRID-aDd5Mr/edit?usp=sharing&ouid=114163723031397476054&rtpof=true&sd=true

> **KitaHack 2026** · SDG 11: Sustainable Cities and Communities
> A full-stack Flutter app that digitises, gamifies, and AI-powers the entire shared-living lifecycle for tenants and landlords in Malaysia.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technical Architecture](#2-technical-architecture)
   - [Repository Structure](#21-repository-structure)
   - [Clean Architecture Layers](#22-clean-architecture-layers)
   - [Database Schema (Drift ORM)](#23-database-schema-drift-orm)
   - [Firebase Integration](#24-firebase-integration)
   - [State Management](#25-state-management)
   - [Routing System](#26-routing-system)
3. [Implementation Details](#3-implementation-details)
   - [Tech Stack](#31-tech-stack)
   - [Feature Modules](#32-feature-modules)
   - [AI Integration — Gemini 2.5 Flash](#33-ai-integration--gemini-25-flash)
   - [Design System](#34-design-system)
   - [Animation System](#35-animation-system)
4. [Challenges Faced](#4-challenges-faced)
5. [Future Roadmap](#5-future-roadmap)
6. [Getting Started](#6-getting-started)

---

## 1. Project Overview

Residex solves three root problems of the Malaysian shared-living market:

| Problem | Who it Affects | Residex Solution |
|---|---|---|
| Opaque, manual bill splitting | Tenants | AI-powered bill splitter with receipt scanning |
| No portable tenant reputation | Tenants & Landlords | Dual Score System (Fiscal + Honor) |
| Landlords juggling multiple tools | Landlords | Unified portfolio command centre |

**Platform:** Flutter (iOS + Android + Web)
**Status:** ~96% complete — 59 screens · 62+ widgets · 50+ routes
**Roles:** Tenant · Landlord (separate UI, shared codebase)

---

## 2. Technical Architecture

### 2.1 Repository Structure

```
residex_app/
├── lib/
│   ├── core/                      # Shared infrastructure
│   │   ├── di/
│   │   │   └── injection.dart     # 12 global Riverpod providers
│   │   ├── errors/                # Failures & exceptions
│   │   ├── models/                # Cross-feature data models
│   │   ├── router/
│   │   │   ├── app_router.dart    # GoRouter config (50+ routes)
│   │   │   └── nav_direction.dart # Directional slide transitions
│   │   ├── services/
│   │   │   ├── gemini_service.dart       # 3 AI model instances
│   │   │   ├── gemini_api_key.dart
│   │   │   └── photo_storage_service.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart    # 70+ color tokens
│   │   │   └── app_theme.dart
│   │   └── widgets/               # 12 core reusable widgets
│   │       ├── residex_logo.dart  # Animated logo (SyncState enum)
│   │       ├── glass_card.dart
│   │       ├── tenants_shell.dart # ShellRoute wrapper
│   │       └── ...
│   │
│   ├── data/
│   │   └── database/              # Drift ORM (SQLite)
│   │       ├── app_database.dart  # 4 tables, 3 DAOs
│   │       ├── tables/            # users, groups, bills, receipt_items
│   │       └── daos/              # BillDao, UserDao, GroupDao
│   │
│   └── features/                  # 3 role-based modules
│       ├── shared/                # Auth, maintenance, community, gamification
│       ├── tenant/                # Residential living features
│       └── landlord/              # Property management features
│
├── android/
├── ios/
├── firebase.json
├── firebase_options.dart
└── pubspec.yaml
```

### 2.2 Clean Architecture Layers

Every feature module (`shared/`, `tenant/`, `landlord/`) strictly follows three layers with no cross-layer imports:

```
┌─────────────────────────────────────────────────────┐
│                  PRESENTATION                        │
│  Screens · Widgets · Riverpod Providers              │
│  (Flutter-aware, UI only)                            │
├─────────────────────────────────────────────────────┤
│                    DOMAIN                            │
│  Entities · Repository Interfaces · Use Cases        │
│  (Pure Dart — zero Flutter/Firebase/Drift imports)   │
├─────────────────────────────────────────────────────┤
│                     DATA                             │
│  Remote DataSources (Firebase) · Local DataSources   │
│  (Drift) · Models · Repository Implementations       │
└─────────────────────────────────────────────────────┘
```

**Domain Layer** enforces business rules:
```dart
// Pure Dart entity — no framework dependency
class AppUser {
  final String id;
  final String name;
  final UserRole role;      // tenant | landlord
  final int fiscalScore;    // 0–1000 payment reputation
  final int honorLevel;     // 0–5 behavioural tier

  // Firebase aliases (zero-cost getters)
  String get uid => id;
  String get displayName => name;
  String? get photoURL => profileImage;
}
```

**Use Cases** are single-responsibility:
```dart
class SignUpWithEmail {
  final AuthRepository _repo;
  SignUpWithEmail(this._repo);

  Future<void> call({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) => _repo.signUpWithEmail(
        email: email, password: password,
        displayName: displayName, role: role,
        phoneNumber: phoneNumber,
      );
}
```

**Repository pattern** decouples domain from data sources:
```dart
// Domain contract
abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  Future<void> signInWithEmail({required String email, required String password});
  Future<void> signUpWithEmail({...});
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

// Data implementation
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _authDataSource;   // Firebase Auth
  final UserRemoteDataSource _userDataSource;   // Firestore
  // ...
}
```

### 2.3 Database Schema (Drift ORM)

Local SQLite database (`residex.db`, schema version 2) provides offline-first access for all bill and user data.

**4 Tables:**

```dart
// Users — local cache of Firestore profiles
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarInitials => text()();
  TextColumn get profileImage => text().nullable()();
  TextColumn get gradientColorValues => text().nullable()(); // JSON
  BoolColumn get isGuest => boolean().withDefault(const Constant(false))();
  TextColumn get phoneNumber => text().nullable()();
}

// Bills — complete bill records with JSON relational data
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get participantIds => text()();   // JSON: ["u1","u2"]
  TextColumn get participantShares => text()(); // JSON: {"u1":50,"u2":50}
  TextColumn get paymentStatus => text()();    // JSON: {"u1":"paid"}
  TextColumn get category => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text()();
}

// Groups — housemate groups
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get members => text()(); // JSON array of user IDs
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

// ReceiptItems — line items within bills
class ReceiptItems extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()(); // FK → Bills.id
  TextColumn get item => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get assignedTo => text().nullable()(); // JSON
}
```

**3 DAOs** (auto-generated by `drift_dev`):
- `BillDao` — CRUD + filter by status, category, participant
- `UserDao` — local user cache reads/writes
- `GroupDao` — group membership management

### 2.4 Firebase Integration

**Services used:** Firebase Auth · Cloud Firestore · Firebase Storage · Firebase App Check

```
Firebase Auth ──────────────────────────────────────────┐
  Email/Password + Google Sign-In                        │
  authStateChanges stream → Riverpod authStateProvider   │
                                                         ▼
Cloud Firestore                              AuthRepositoryImpl
  collections/                                    ↕
  ├── users/{uid}                      FirebaseUserRepositoryImpl
  │   ├── displayName, email, role
  │   ├── fiscalScore, honorLevel
  │   ├── photoURL, phoneNumber
  │   └── createdAt, updatedAt
  ├── properties/{id}          ← Landlord portfolio
  ├── groups/{id}              ← Housemate groups
  ├── bills/{id}               ← (planned Phase 7)
  ├── maintenance_tickets/{id} ← Cross-role
  └── community_posts/{id}     ← Cross-role

Firebase Storage
  ├── move_in_photos/{sessionId}/
  ├── maintenance_attachments/{ticketId}/
  ├── community_posts/{postId}/
  └── avatars/{uid}/
```

**Dual repository strategy — local vs remote:**

| Data | Storage | Reason |
|---|---|---|
| User auth state | Firebase Auth stream | Real-time auth events |
| User profiles | Firestore + Drift cache | Offline reads |
| Bill splits | Drift SQLite | Compute-heavy, offline-first |
| Maintenance tickets | Firestore | Cross-role collaboration |
| Move-in photos | Firebase Storage | Large binary data |
| Community posts | Firestore | Real-time social |

### 2.5 State Management

**Riverpod 3.1.0** with `riverpod_annotation 4.0.0`

**Auth flow (11 providers, zero naming conflicts):**

```dart
// Layer 1 — raw Firebase
final firebaseAuthStateProvider = StreamProvider<firebase_auth.User?>(
  (ref) => ref.watch(authRemoteDataSourceProvider).authStateChanges,
);

// Layer 2 — domain entity
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

// Layer 3 — sync convenience
final authUserProvider = Provider<AppUser?>((ref) =>
  ref.watch(authStateProvider).value,
);

// Layer 4 — role check
final currentUserRoleProvider = FutureProvider<UserRole?>((ref) async {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return null;
  return ref.watch(firebaseUserRepositoryProvider).getUserRole(user.uid);
});
```

**Dev bypass for testing (skips Firebase entirely):**
```dart
class _DevBypassNotifier extends Notifier<UserRole?> {
  @override
  UserRole? build() => null;
  void bypass(UserRole role) => state = role;
}

final devBypassProvider = NotifierProvider<_DevBypassNotifier, UserRole?>(
  _DevBypassNotifier.new,
);

// In router redirect — checked FIRST before auth guard
final devRole = ref.read(devBypassProvider);
if (devRole != null) return null; // allow any navigation
```

**Async state patterns:**
```dart
// Bills — AsyncNotifier (Riverpod 3.x)
class BillsNotifier extends AsyncNotifier<List<Bill>> {
  @override
  Future<List<Bill>> build() =>
      ref.watch(billRepositoryProvider).getAllBills();

  Future<void> saveBill(Bill bill) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(billRepositoryProvider).saveBill(bill),
    );
  }
}
```

### 2.6 Routing System

**GoRouter 14.2.0** — `appRouterProvider = Provider<GoRouter>` (Riverpod-aware so `ref` is accessible inside `redirect`).

**Dual navigation architecture:**

```
GoRouter
├── /                       → NewSplashScreen
├── /login                  → LoginScreen
├── /register               → RegisterScreen
│
├── ShellRoute (TenantShell — 5-tab bottom nav)
│   ├── /tenant-dashboard   → TenantDashboardScreen
│   ├── /dashboard          → BillDashboardScreen
│   ├── /sync-hub           → SyncHubScreen (REX AI hub)
│   ├── /support-center     → SupportCenterScreen
│   └── /community          → CommunityBoardScreen
│
├── /landlord-dashboard     → LandlordHomeScreen
│   (manages 5 tabs via IndexedStack + CustomBottomNavBar)
│   ├── Tab 0: LandlordCommandScreen
│   ├── Tab 1: LandlordFinanceScreen
│   ├── Tab 2: RexAITabWrapper → RexAIMainMenuScreen
│   ├── Tab 3: LandlordPortfolioScreen
│   └── Tab 4: LandlordCommunityScreen
│
└── 40+ push routes (bill summary, maintenance, AI tools, ...)
```

**Auth redirect logic:**
```dart
redirect: (context, state) {
  // 1. Dev bypass — skip all auth for UI testing
  if (ref.read(devBypassProvider) != null) return null;

  // 2. Still loading — stay put
  if (ref.read(authStateProvider).isLoading) return null;

  final user = ref.read(authStateProvider).value;
  final onAuthRoute = ['/login', '/register', '/'].contains(loc);

  // 3. Not logged in → login
  if (user == null && !onAuthRoute) return AppRoutes.login;

  // 4. Logged in on auth route → role-based home
  if (user != null && onAuthRoute) {
    return user.role == UserRole.landlord
        ? AppRoutes.landlordDashboard
        : AppRoutes.syncHub;
  }
  return null;
},
```

**Page transitions — horizontal parallax slide:**
```dart
CustomTransitionPage(
  transitionDuration: const Duration(milliseconds: 350),
  transitionsBuilder: (context, animation, secondary, child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: NavDirection.slideFromRight
            ? const Offset(1, 0)   // push right→left
            : const Offset(-1, 0), // pop left→right
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.2, 0.8, 0.2, 1.0),
      )),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0), // parallax exit
        ).animate(secondary),
        child: child,
      ),
    );
  },
)
```

---

## 3. Implementation Details

### 3.1 Tech Stack

| Layer | Library | Version | Purpose |
|---|---|---|---|
| **Language** | Dart | ^3.10.0 | |
| **Framework** | Flutter | ^3.10.0 | Cross-platform UI |
| **State** | flutter_riverpod | 3.1.0 | Reactive state management |
| **State codegen** | riverpod_annotation | 4.0.0 | Provider generation |
| **Router** | go_router | 14.2.0 | Declarative navigation |
| **Local DB** | drift | 2.18.0 | SQLite ORM |
| **DB driver** | sqlite3_flutter_libs | 0.5.24 | Native SQLite binaries |
| **Auth** | firebase_auth | 6.1.4 | Email/Password + Google |
| **Database** | cloud_firestore | 6.1.2 | Remote data + real-time |
| **Storage** | firebase_storage | 13.0.6 | Photo uploads |
| **App Check** | firebase_app_check | 0.4.1+4 | API abuse prevention |
| **Google SSO** | google_sign_in | 6.2.2 | One-tap login |
| **AI** | google_generative_ai | 0.4.6 | Gemini 2.5 Flash |
| **Animations** | flutter_animate | 4.5.2 | Declarative animations |
| **Sensors** | sensors_plus | 5.0.1 | Magnetometer (Move-In Layer 1) |
| **Wi-Fi** | network_info_plus | 6.0.0 | SSID detection (Move-In Layer 3) |
| **Vibration** | vibration | 2.0.0 | Haptic feedback |
| **Camera** | camera | 0.11.0 | Live viewfinder |
| **Images** | image_picker | 1.0.7 | Gallery access |
| **Files** | file_picker | 8.1.2 | Document upload |
| **Contacts** | flutter_contacts | 1.1.7+1 | Housemate onboarding |
| **Icons** | lucide_icons | 0.257.0 | Consistent iconography |
| **Fonts** | google_fonts | 6.3.2 | Inter typeface |
| **Calendar** | table_calendar | 3.1.2 | Chore scheduler |
| **Charts** | CustomPainter | built-in | Revenue trend, score arc |
| **Glassmorphism** | glassmorphism | 3.0.0 | Frosted-glass cards |
| **Animations** | lottie | 3.1.2 | Complex celebration anims |
| **Confetti** | confetti | 0.7.0 | Achievement unlocks |

### 3.2 Feature Modules

#### Tenant Features (26 screens)

**Bill Splitter**
- `BillDashboardScreen` — Ledger view: You Owe / Owed To You / All Bills
- `BillSummaryScreen` — Per-bill breakdown with animated donut chart, participant payment rings
- `YouOweScreen / OwedToYouScreen / GroupBillsScreen` — Filtered bill views
- Receipt scanning via `camera` → Gemini Vision extracts line items
- Split algorithms: equal · proportional · per-item assignment
- Payment status tracking: pending → paid → overdue

**Chore Scheduler**
- `ChoreSchedulerScreen` — `table_calendar` weekly view with rotation assignments
- Per-chore completion tracking, automated rotation logic
- Honor score integration (completing chores earns Honor XP)

**AI Tools (4 screens)**

| Screen | AI Model | Function |
|---|---|---|
| `RexInterfaceScreen` | Gemini Chat | Tenant assistant — lease rights, bill disputes, maintenance advice |
| `LeaseSentinelScreen` | Gemini Chat | Lease agreement clause analyser — flags unfair terms |
| `LazyLoggerScreen` | Gemini Vision | Document evidence logger — auto-tags and categorises uploads |
| `FairFixAuditorScreen` | Gemini Vision | Move-in/out property comparison — baseline vs current photo diff |

**Move-In Session (3-layer sensor protocol)**
- `MoveInSessionScreen` — 3-layer onboarding:
  - Layer 1: Magnetometer sweep (anomaly detection via `sensors_plus`)
  - Layer 2: Baseline photo capture per room area (7 areas)
  - Layer 3: Wi-Fi environment fingerprint (`network_info_plus`)
- `GhostOverlayScreen` — Transparent AR-style overlay for move-out comparison
- `StewardshipProtocolScreen` — K-OS conflict engine (4-phase: nudge → cooldown → 3-strike → tribunal)

**Reputation & Gamification**
- `ScoreDetailScreen` — Fiscal Score breakdown (payment punctuality 40% · consistency 25% · fairness 20% · method 10% · trend 5%)
- `HonorHistoryScreen` — 5-tier honor progression with badge milestones
- `GamificationHubScreen` — Achievements, trophies, confetti unlock animations
- `RentalResumeScreen` — Portable reputation card (shareable PDF)

**Sync Hub (Jarvis-style AI Interface)**
- `SyncHubScreen` — Central animated hub featuring:
  - `ResidexLogo` (110px, animated, `SyncState.synced` glow)
  - 3 rotating rings: 260px/20s CW · 200px/15s CCW · 140px pulsing
  - 200-particle orbital field (60s AnimationController)
  - Voice activation via `speech_to_text`
  - REX AI quick-launch

**Toolkit**
- `LiquidityScreen` — Cash flow projection tool
- `HarmonyHubScreen` — Conflict resolution framework
- `CreditBridgeScreen` — Rent advance options
- `PropertyPulseDetailScreen` — Property health metrics (tenant view)
- `RulebookScreen` — House rules digital copy
- `SupportCenterScreen` — FAQ, direct landlord contact, escalation

---

#### Landlord Features (21 screens)

**Command (Dashboard)**
- `LandlordCommandScreen` (1,140 lines) — Stat cards, maintenance backlog, system health summary with `flutter_animate` entrance sequences
- `LandlordSystemHealthScreen` — Occupancy %, maintenance SLA compliance, tenant satisfaction index
- `LandlordMaintenanceScreen` — Maintenance request queue by urgency
- `MaintenanceTicketDetailScreen` — Per-ticket SLA tracking, status updates

**Finance**
- `LandlordFinanceScreen` (918 lines) — Revenue dashboard: hero financial card, custom revenue chart (CustomPainter), expense breakdown with progress bars

**REX AI (5 screens)**
- `RexAIMainMenuScreen` — Sync hub aesthetic: ResidexLogo centre + animated rings + 4 function cards
- `LandlordRexAIScreen` — Chat interface (streaming, landlord system prompt: lease drafting, screening, conflict resolution)
- `RevenueAnalyticsScreen` — Financial projections, AI predictions, property revenue breakdown (custom line chart replacing `fl_chart`)
- `MaintenanceAIScreen` — Predictive maintenance: health score arc (CustomPainter pulse), failure probability bars
- `LeaseGeneratorScreen` — AI-assisted tenancy agreement generation (Malaysian law)
- `DocuMindScreen` — Document management + AI Q&A (custom chat UI, 6 categories, `file_picker`)

**Portfolio**
- `LandlordPortfolioScreen` (796 lines) — Property listings, CRUD modals
- Property editor/action/delete/duplicate modals (712-line editor)
- `TenantListScreen` — Tenant roster with honor scores
- `TenantScoreDetailScreen` — Individual tenant reputation

**Community**
- `LandlordCommunityScreen` — Announcement board, FEED/EVENTS/MARKET tabs, engagement summary

---

#### Shared Features (11 screens)

- Auth: `NewSplashScreen` (spring diamond animation), `LoginScreen`, `RegisterScreen`
- `CommunityBoardScreen` — Social board with post reactions, comments, FEED/EVENTS/MARKET tabs
- `GamificationHubScreen` — Achievement system
- Maintenance: `CreateTicketScreen`, `MaintenanceListScreen`, `TicketDetailScreen`
- User: `ProfileScreen`, `ProfileEditorScreen`

### 3.3 AI Integration — Gemini 2.5 Flash

**3 distinct model instances** in `GeminiService`:

```dart
// Tenant assistant — conversational
final _model = GenerativeModel(
  model: 'gemini-2.5-flash',
  systemInstruction: Content.system('''
    You are REX, Residex's AI for Malaysian shared-living tenants.
    Help with: lease rights, bill disputes, maintenance issues,
    chore conflicts, rental law, and housemate communication.
    Be concise, empathetic, and cite Malaysian law where relevant.
  '''),
  generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 512),
);

// Landlord assistant — authoritative
final _landlordModel = GenerativeModel(
  model: 'gemini-2.5-flash',
  systemInstruction: Content.system('''
    You are REX, Residex's AI for Malaysian property managers.
    Help with: lease drafting, tenant screening, rent tracking,
    maintenance coordination, and dispute resolution.
    Be authoritative, precise, and reference Malaysian Housing Act.
  '''),
  generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 512),
);

// Vision model — property analysis
final _visionModel = GenerativeModel(
  model: 'gemini-2.5-flash',  // No system instruction — flexible
  generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: 4096),
);
```

**Streaming response pattern:**
```dart
Stream<String> sendMessage(String userMessage) async* {
  _chatSession ??= _model.startChat();
  final response = _chatSession!.sendMessageStream(
    Content.text(userMessage),
  );
  await for (final chunk in response) {
    if (chunk.text != null && chunk.text!.isNotEmpty) {
      yield chunk.text!; // Stream each word as it arrives
    }
  }
}
```

**Vision analysis (FairFix Auditor):**
```dart
Future<Map<String, dynamic>> analyzePropertyCondition(
  Uint8List moveInBytes,
  Uint8List currentBytes,
) async {
  final response = await _visionModel.generateContent([
    Content.multi([
      TextPart('''Compare these two property photos.
        Photo 1: Move-in baseline condition.
        Photo 2: Current condition.
        Return JSON: { "changedAreas": [], "severity": "minor|moderate|severe",
        "estimatedCost": 0, "tenantFault": true/false, "details": "" }'''),
      DataPart('image/jpeg', moveInBytes),
      DataPart('image/jpeg', currentBytes),
    ]),
  ]);
  return jsonDecode(response.text ?? '{"valid": true}');
}
```

### 3.4 Design System

**All colors defined in `app_colors.dart` (70+ tokens):**

```
Background layers         Accent palette
──────────────────        ─────────────────────────
deepSpace  #000212        cyan500   #06B6D4  (tenant)
spaceBase  #020617        blue500   #3B82F6  (landlord)
spaceMid   #0a0a12        indigo500 #6F00FF  (primary)
surface    #0F172A        purple500 #A855F7
                          emerald500 #10B981 (success)
Text hierarchy            red500    #EF4444  (error)
──────────────────        amber500  #F59E0B  (warning)
textPrimary   #FFFFFF
textSecondary #CBD5E1     Sync State colors
textTertiary  #94A3B8     ─────────────────────────
textMuted     #64748B     synced:    blue  + purple
                          drifting:  amber + orange
                          outOfSync: rose  + red
```

**Glassmorphism card pattern (universal):**
```dart
// Every card in the app follows this pattern
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [
      AppColors.blue500.withValues(alpha: 0.10),  // NOT withOpacity (deprecated)
      AppColors.blue600.withValues(alpha: 0.05),
    ]),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: content,
  ),
)
```

**Section label standard (ALL CAPS throughout):**
```dart
Text(
  'RECENT ACTIVITY',
  style: TextStyle(
    color: AppColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    fontFamily: GoogleFonts.inter().fontFamily,
  ),
)
```

### 3.5 Animation System

**`flutter_animate` — declarative chaining:**
```dart
// Entrance sequence on screen load
Column(children: [...])
  .animate()
  .fadeIn(duration: 400.ms)
  .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut)

// Perpetual shimmer on status labels
Text('SYSTEM ONLINE')
  .animate(onPlay: (c) => c.repeat())
  .shimmer(duration: 3.seconds, color: AppColors.blue400)

// Rotating rings (SyncHub + REX main menu)
Container(/* 260px ring */)
  .animate(onPlay: (c) => c.repeat())
  .rotate(duration: 20.seconds, curve: Curves.linear)

Container(/* 200px ring — counter-clockwise */)
  .animate(onPlay: (c) => c.repeat())
  .rotate(duration: 15.seconds, begin: 1.0, end: 0.0, curve: Curves.linear)
```

**Custom painters:**
- `_RevenueTrendPainter` — Line chart with dashed predicted segment, fill area, dot nodes
- `_HealthScorePainter` — Arc progress with pulse ring (MaintenanceAI)
- `_ArchPainter` — Animated arch drawing (Splash screen)
- `_ParticlePainter` — 200-particle orbital field (SyncHub/REX menu)
- `_LineLegendPainter` — Chart legend dashes

**AnimatedScale for interactive feedback:**
```dart
GestureDetector(
  onTapDown: (_) => setState(() => _pressed = true),
  onTapUp: (_) => setState(() => _pressed = false),
  child: AnimatedScale(
    scale: _pressed ? 0.97 : 1.0,
    duration: const Duration(milliseconds: 150),
    child: card,
  ),
)
```

---

## 4. Challenges Faced

### Challenge 1 — Dual-Role Architecture Without Code Duplication

**Problem:** Tenant and landlord have fundamentally different workflows but share entities (users, maintenance tickets, community posts). Naïve duplication would produce an unmaintainable codebase.

**Solution:** Three-layer feature organisation (`shared/`, `tenant/`, `landlord/`). Shared entities (AppUser, MaintenanceTicket) live in `shared/domain/entities/` and are imported by both roles. Role-specific entities (Bill, Property) live in their own module. This eliminated ~30% of code that would have been duplicated.

---

### Challenge 2 — Riverpod 3.x Migration Mid-Project

**Problem:** The project was initially built on Riverpod 2.x. Upgrading to 3.1.0 (required for `riverpod_annotation 4.0.0`) broke `StateNotifier`, `.valueOrNull`, and all family providers.

**Solution:** Migrated all `StateNotifier` classes to `AsyncNotifier`. Replaced `.valueOrNull` with `.value`. Updated family providers to use typed constructors. The `BillsNotifier` (the largest provider at 400+ lines) required the most refactoring to the new `AsyncNotifier` pattern.

---

### Challenge 3 — GoRouter + Riverpod Auth Guard

**Problem:** `GoRouter`'s `redirect` callback runs outside Riverpod context. Making it reactive to `authStateProvider` (a `StreamProvider`) required bridging two reactive systems.

**Solution:** Wrapped `GoRouter` itself in a `Provider<GoRouter>` so `ref` is accessible. Added a `_RouterNotifier extends ChangeNotifier` that listens to `authStateProvider` via `ref.listen` and calls `notifyListeners()`, which triggers GoRouter's `refreshListenable`. The dev bypass provider is checked first, before auth, allowing zero-Firebase UI testing.

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();
  ref.listen(authStateProvider, (_, __) => notifier.notify());
  return GoRouter(refreshListenable: notifier, redirect: (ctx, state) {
    if (ref.read(devBypassProvider) != null) return null;
    // ...auth logic
  });
});
```

---

### Challenge 4 — `fl_chart` Dependency Conflict

**Problem:** Justin's `RevenueAnalyticsScreen` used `fl_chart` which was not in the project's `pubspec.yaml`. Adding it conflicted with existing dependency constraints.

**Solution:** Replaced `fl_chart` entirely with a custom `_RevenueTrendPainter` (`CustomPainter`). Implemented the actual + dashed-predicted line chart, fill area, grid lines, and dot nodes manually using Canvas API. This reduced the dependency count and gave full visual control.

---

### Challenge 5 — `dash_chat_2` Replacement (DocuMind)

**Problem:** Justin's `DocuMindScreen` depended on `dash_chat_2` for the Q&A chat interface, which was not available in the project.

**Solution:** Built a self-contained chat UI from scratch:
- Custom `_ChatMessage` model class
- `ListView.builder` for the message thread
- `_ThinkingDot` widget with staggered `AnimationController` for typing indicator
- `TextField` + send button input dock with `MediaQuery.viewInsets.bottom` keyboard handling
- Mock AI responses with keyword matching (production: wire to Gemini)

---

### Challenge 6 — Firebase Project Compatibility (Branch Merge)

**Problem:** Pravin's branch had its own Firebase project. Justin's branch had a different `google-services.json` pointing to `residex-2ebd8`. Merging required ensuring both Firestore schemas were compatible.

**Solution:** Field-by-field audit of Justin's `UserModel.toFirestore()` vs Pravin's `AppUserModel.fromFirestore()`. All 8 fields (`displayName`, `email`, `role`, `phoneNumber`, `photoURL`, `createdAt`, `updatedAt`) matched exactly. Pravin's implementation used null-safe fallbacks (`data['displayName'] ?? data['name'] ?? 'Unknown'`) which handled any missing fields gracefully. Updated `firebase_options.dart` and `google-services.json` to Justin's project.

---

### Challenge 7 — Animation Performance on Older Android

**Problem:** The SyncHub particle field (200 particles, 60s AnimationController, `CustomPaint`) caused jank on mid-range devices during the initial render.

**Solution:** Moved particle generation to `initState()` (pre-computed, no per-frame allocation). Used `shouldRepaint` returning `true` only when `animationValue` changed. The `_Particle` class is `const`-constructable (value semantics), eliminating GC pressure. Particles use a single shared `Paint` object rather than creating one per particle.

---

### Challenge 8 — Deprecated `withOpacity()` API

**Problem:** Every inherited file from Justin's branch used `.withOpacity(x)` which Flutter 3.33+ deprecated, generating hundreds of analyzer warnings.

**Solution:** Systematic search-and-replace with the correct API:
- `color.withOpacity(x)` → `color.withValues(alpha: x)`

Applied across all 4 ported screens (revenue analytics, maintenance AI, lease generator, documind) and all landlord widget files during the UI overhaul phase.

---

## 5. Future Roadmap

### Phase 1 — Firebase Full Integration (Priority: Critical)

Replace all mock data with live Firestore streams:

| Collection | Status | Priority |
|---|---|---|
| `users` | ✅ Auth connected | Done |
| `properties` | 🔄 Local only | High |
| `groups` | 🔄 Drift only | High |
| `bills` | 🔄 Drift only | High |
| `maintenance_tickets` | 🔄 Local only | High |
| `community_posts` | 🔄 Mock only | Medium |
| `scores` | 🔄 Computed only | Medium |
| `move_in_sessions` | 🔄 Local only | Medium |

Security rules (Firestore + Storage) need review before production.

---

### Phase 2 — AI Deepening

- **DocuMind real backend:** Connect `DocuMindScreen` to a Cloud Function that uses Gemini's document understanding to actually parse uploaded PDFs and answer questions with citations
- **FairFix Auditor accuracy:** Fine-tune the vision prompt to distinguish tenant damage from normal wear using Malaysian property standards
- **REX voice routing:** Complete `speech_to_text` integration in SyncHub — route transcribed intent to the appropriate screen (bill summary, maintenance form, chore scheduler)
- **Lease Sentinel legal database:** Train on Malaysian Residential Tenancy Act clauses for clause-level flagging

---

### Phase 3 — Score System Completion

- **Fiscal Score live computation:** Wire `ScoreDetailScreen` to real payment history from Firestore (currently computed from local mock data)
- **Honor Score automation:** Auto-award honor XP when chores are marked complete, maintenance tickets resolved, or community posts are praised
- **Landlord rating of tenants:** Implement `LandlordRatingModal` to submit structured ratings that affect tenant Honor Score
- **Leaderboard:** Activate the leaderboard with real-time Firestore score ranking
- **Rental Resume PDF export:** Generate a shareable PDF from `RentalResumeScreen` using a Cloud Function

---

### Phase 4 — Move-In Protocol Completion

- **Ghost Overlay Layer 3 (Wi-Fi):** Complete the Wi-Fi fingerprint scan in `MoveInSessionScreen` using `network_info_plus` — compare SSID environment at move-in vs move-out to detect property changes
- **Sentinel Sweeper:** Persist anomaly detection results from the magnetometer sweep to Firestore as a tamper-proof baseline
- **Photo baseline sync:** Upload move-in baseline photos to Firebase Storage during the session, not just local state

---

### Phase 5 — Notification System

- **Firebase Cloud Messaging (FCM):** Push notifications for:
  - Bill due date reminders (3 days, 1 day, overdue)
  - Maintenance ticket status updates
  - Chore assignment reminders
  - Community post reactions/comments
  - Landlord announcements
- **In-app toast system:** Extend `ToastNotification` widget to show real-time Firestore change events

---

### Phase 6 — Production Hardening

- **App Check:** Already enabled in `debug` mode — switch to `deviceCheck` (iOS) + `playIntegrity` (Android) for production
- **Gemini API key security:** Rotate to Cloud Functions proxy so the API key is never embedded in the app binary
- **Firestore indexes:** Pre-create composite indexes for bills (groupId + status + createdAt), chores (groupId + dueDate), maintenance (propertyId + priority)
- **Crashlytics + Analytics:** Firebase Crashlytics for crash reporting, Analytics for user funnel tracking
- **Rate limiting:** Implement Firestore security rule rate limits on community post creation

---

### Phase 7 — Platform Expansion

- **Web:** Landlord portal optimised for desktop (dashboard analytics, bulk tenant management)
- **Notifications:** WhatsApp Business API integration for Malaysian landlords who prefer WhatsApp
- **Payment gateway:** FPX/DuitNow integration for in-app rent payment (linked to Fiscal Score)
- **Property marketplace:** Connect `LandlordPortfolioScreen` to a real listing API (PropertyGuru / IPropertyMY)
- **Multi-language:** Bahasa Malaysia localisation (target: 30M Malay-speaking users)

---

## 6. Getting Started

### Prerequisites

```
Flutter SDK ^3.10.0
Dart ^3.10.0
Android Studio / VS Code
Firebase project (residex-2ebd8)
```

### Setup

```bash
# Clone
git clone https://github.com/your-org/residex.git
cd residex/residex_app

# Install dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run
```

### Firebase Configuration

The project uses Firebase project `residex-2ebd8`. Configuration files are already present:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

> **For development:** Use the "Tenant Dev" / "Landlord Dev" buttons on the login screen to bypass Firebase authentication entirely and navigate directly to either role's UI.

### Environment

No `.env` file required — Gemini API key is currently stored in `lib/core/services/gemini_api_key.dart`. Rotate before production.

---

## Project Metrics

| Metric | Value |
|---|---|
| Total screens | 59 |
| Total widgets | 62+ |
| GoRouter routes | 50+ |
| Riverpod providers | 24 |
| Drift tables | 4 |
| Drift DAOs | 3 |
| Gemini AI models | 3 |
| Color tokens | 70+ |
| Lines of Dart code | ~25,000 |
| Supported platforms | Android · iOS · Web |
| Architecture | Clean Architecture (Domain-Driven) |
| Test coverage | Unit tests for use cases (planned) |

---

*Built for KitaHack 2026 · SDG 11: Sustainable Cities and Communities*
*Malaysia's first AI-powered shared-living operating system*
