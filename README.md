# Residex — Landlord Property Management OS
# Link for questionnaire responses collected: https://docs.google.com/spreadsheets/d/10jeovxl1__syRfBeqFp_1-RYJFhZuR7U/edit?usp=sharing&ouid=114163723031397476054&rtpof=true&sd=true
#Link for PowerPoint Presentation File: https://docs.google.com/presentation/d/1r5MoE1Z7d-xt2aSQY3yknFRID-aDd5Mr/edit?usp=sharing&ouid=114163723031397476054&rtpof=true&sd=true

> **Landlord-Only Scope** — Property Management Operating System
> A full-stack Flutter app for landlords to manage properties, authenticate securely, and use AI-powered document Q&A.

---

## Features

- **DocuMind RAG** — AI-powered document Q&A for leases, warranties, insurance, utilities, receipts
- **Property Management** — View, create, update properties; track documents per property
- **Authentication** — Secure login/registration for landlords

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
  - [DocuMind RAG Architecture (Flagship)](#27-documind-rag-architecture-flagship)
3. [Implementation Details](#3-implementation-details)
   - [Tech Stack](#31-tech-stack)
   - [Feature Modules](#32-feature-modules)
  - [AI Integration — Gemini 2.5 Flash + DocuMind RAG](#33-ai-integration--gemini-25-flash--documind-rag)
   - [Design System](#34-design-system)
   - [Animation System](#35-animation-system)
4. [Challenges Faced](#4-challenges-faced)
5. [Future Roadmap](#5-future-roadmap)
6. [Getting Started](#6-getting-started)

---

## 1. Project Overview

Residex (landlord scope) is a property management operating system that enables landlords to:

| Feature | Capability | Implementation |
|---|---|---|
| **DocuMind RAG** | AI-powered Q&A over property documents (leases, warranties, insurance, utilities, receipts) | FastAPI + Firestore Vector Search + Gemini |
| **Property Management** | Create, view, update rental properties and manage associated documents | Firebase Firestore + Flutter UI |
| **Authentication** | Secure landlord login and registration | Firebase Auth |

**Platform:** Flutter (iOS + Android + Web)
**Status:** Active development — Core landlord features
**Architecture:** Clean Architecture (Domain-Driven) with Riverpod state management

**Flagship intelligence layer:** **DocuMind RAG** (FastAPI + Firestore Vector Search + Gemini + LangGraph orchestration) provides landlords with AI-powered document Q&A including citations, category-aware retrieval, and multi-turn conversation support.

---

## 2. Technical Architecture

### 2.1 Repository Structure

```
backend/
├── main.py                        # FastAPI app entrypoint
├── api/rex_routes.py              # /api/rex/documind/* endpoints
├── rag/documind_service.py        # Firestore Vector Search RAG pipeline
├── rag/graph_orchestrator.py      # Conversational + retrieval orchestration
├── models/documind_models.py      # AskRequest/AskResponse contracts
└── tests/                          # DocuMind orchestration/API tests

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

### 2.7 DocuMind RAG Architecture (Flagship)

DocuMind is now a first-class backend service in this repo (`backend/`) and is not a mock placeholder.

**Core stack:**
- FastAPI service layer (`/api/rex/documind/*`)
- Firestore as both metadata store and vector index (`documind_docs`, `documind_chunks`)
- Gemini embeddings (`models/gemini-embedding-001`) + Gemini answer synthesis (`models/gemini-2.5-flash`)
- LangGraph-style orchestrator for intent routing + category clarification checkpoints

**Document lifecycle:**
1. Upload PDF to `/api/rex/documind/upload` with `(landlord_id, property_id, category)`.
2. Parse + chunk document text (`PyPDFLoader`, `RecursiveCharacterTextSplitter`).
3. Create embeddings and persist chunk vectors in Firestore.
4. Save per-document metadata for listing/deletion and citation traceability.

**Question-answer lifecycle:**
1. Receive `AskRequest` with optional `categories`, `session_id`, `user_action`.
2. Orchestrator classifies intent (conversation vs retrieval vs confirmation checkpoint).
3. Build scoped query (`landlord_id`, `property_id`, optional categories).
4. Run Firestore `find_nearest` vector search (COSINE distance).
5. Synthesize answer with citations and confidence.
6. Return structured `AskResponse` including follow-up action requirements.

**Supported categories:** `lease`, `warranty`, `insurance`, `utility`, `receipt`, `other`

**What makes this robust in practice:**
- Property-scoped retrieval prevents cross-property leakage.
- Category clarification flow reduces ambiguous retrieval.
- Session-aware follow-ups (`confirm`, `cancel`, `override:<category>`) improve multi-turn UX.
- Citation payload (`filename`, `page`, `snippet`, `score`) keeps answers auditable.
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

#### Landlord Features

**DocuMind RAG**
- `DocuMindScreen` — Document management + AI Q&A with citations
  - Upload PDFs (leases, warranties, insurance, utilities, receipts)
  - Category-aware document retrieval (6 categories)
  - Multi-turn conversation with session memory
  - Citation panel with source documents and page numbers
  - File picker integration

**Property Management**
- `LandlordPortfolioScreen` — Property listings with CRUD
  - Create, view, update, delete properties
  - Property editor modal (712 lines)
  - Track documents per property
  - Property metadata (location, units, documents)

**Authentication & User**
- `NewSplashScreen` — Animated splash with spring diamond animation
- `LoginScreen` — Email/password + Google Sign-In
- `RegisterScreen` — Landlord registration
- `ProfileScreen` — User profile management

### 3.3 AI Integration — Gemini 2.5 Flash + DocuMind RAG

**DocuMind uses Gemini 2.5 Flash for synthesis:**

```dart
final _landlordModel = GenerativeModel(
  model: 'gemini-2.5-flash',
  systemInstruction: Content.system('''
    You are DocuMind, an AI document assistant for property managers.
    Help landlords with: lease terms, warranty coverage, insurance details,
    utility agreements, and receipt analysis.
    Be authoritative, precise, and cite document pages where relevant.
  '''),
  generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 1024),
);
```

**Streaming response pattern (for multi-turn conversations):**
```dart
Stream<String> sendMessage(String userMessage) async* {
  _chatSession ??= _landlordModel.startChat();
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

**DocuMind RAG API surface (live):**

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/api/rex/documind/upload` | Upload + index landlord property document |
| `POST` | `/api/rex/documind/ask` | RAG Q&A with citations and orchestration |
| `GET` | `/api/rex/documind/documents` | List indexed docs (landlord/property-scoped) |
| `DELETE` | `/api/rex/documind/documents/{doc_id}` | Delete doc + associated chunks |

**DocuMind ask contract highlights:**
- Request: `landlord_id`, `property_id`, `question`, optional `categories`, `session_id`, `user_action`
- Response: `answer`, `confidence`, `citations`, `searched_categories`, `user_action_required`, `predicted_categories`

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

### Challenge 1 — Riverpod 3.x Migration Mid-Project

**Problem:** The project was initially built on Riverpod 2.x. Upgrading to 3.1.0 (required for `riverpod_annotation 4.0.0`) broke `StateNotifier`, `.valueOrNull`, and all family providers.

**Solution:** Migrated all `StateNotifier` classes to `AsyncNotifier`. Replaced `.valueOrNull` with `.value`. Updated family providers to use typed constructors. The `BillsNotifier` (the largest provider at 400+ lines) required the most refactoring to the new `AsyncNotifier` pattern.

---

### Challenge 2 — GoRouter + Riverpod Auth Guard

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

### Challenge 3 — `fl_chart` Dependency Conflict

**Problem:** The `RevenueAnalyticsScreen` used `fl_chart` which was not in the project's `pubspec.yaml`. Adding it conflicted with existing dependency constraints.

**Solution:** Replaced `fl_chart` entirely with a custom `_RevenueTrendPainter` (`CustomPainter`). Implemented the actual + dashed-predicted line chart, fill area, grid lines, and dot nodes manually using Canvas API. This reduced the dependency count and gave full visual control.

---

### Challenge 4 — `dash_chat_2` Replacement (DocuMind)

**Problem:** The `DocuMindScreen` depended on `dash_chat_2` for the Q&A chat interface, which was not available in the project.

**Solution:** Built a self-contained chat UI from scratch:
- Custom `_ChatMessage` model class
- `ListView.builder` for the message thread
- `_ThinkingDot` widget with staggered `AnimationController` for typing indicator
- `TextField` + send button input dock with `MediaQuery.viewInsets.bottom` keyboard handling
- Integration with FastAPI backend for DocuMind RAG responses

---

### Challenge 5 — Firebase Project Compatibility (Branch Merge)

**Problem:** Pravin's branch had its own Firebase project. Justin's branch had a different `google-services.json` pointing to `residex-2ebd8`. Merging required ensuring both Firestore schemas were compatible.

**Solution:** Field-by-field audit of Justin's `UserModel.toFirestore()` vs Pravin's `AppUserModel.fromFirestore()`. All 8 fields (`displayName`, `email`, `role`, `phoneNumber`, `photoURL`, `createdAt`, `updatedAt`) matched exactly. Pravin's implementation used null-safe fallbacks (`data['displayName'] ?? data['name'] ?? 'Unknown'`) which handled any missing fields gracefully. Updated `firebase_options.dart` and `google-services.json` to Justin's project.

---

### Challenge 6 — Animation Performance on Older Android

**Problem:** UI animations on mid-range devices caused jank during initial render.

**Solution:** Optimized animation rendering by moving particle generation to `initState()` (pre-computed, no per-frame allocation). Used `shouldRepaint` returning `true` only when `animationValue` changed. Eliminated GC pressure through value semantics and shared `Paint` objects.

---

### Challenge 7 — Deprecated `withOpacity()` API

**Problem:** Every inherited file from Justin's branch used `.withOpacity(x)` which Flutter 3.33+ deprecated, generating hundreds of analyzer warnings.

**Solution:** Systematic search-and-replace with the correct API:
- `color.withOpacity(x)` → `color.withValues(alpha: x)`

Applied across all 4 ported screens (revenue analytics, maintenance AI, lease generator, documind) and all landlord widget files during the UI overhaul phase.

---

## 5. Future Roadmap

### Phase 1 — DocuMind Enhancement (Priority: Critical)

Expand DocuMind capabilities:

| Feature | Status | Priority |
|---|---|---|
| Multi-document search | 🔄 In progress | High |
| Document summarization | ⏳ Planned | High |
| Lease clause highlighting | ⏳ Planned | High |
| Receipt OCR + parsing | ⏳ Planned | Medium |
| Document comparison | ⏳ Planned | Medium |
| Audit trail logging | ⏳ Planned | Medium |

---

### Phase 2 — Property Management Expansion

- **Tenant management:** Add tenant roster per property with contact tracking
- **Lease tracking:** Store and manage active leases per property
- **Document organization:** Folder structure and tagging for better document management
- **Expiry reminders:** Alert landlords about upcoming lease renewals, insurance expiry, warranty coverage end

---

### Phase 3 — Notification System

- **Firebase Cloud Messaging (FCM):** Push notifications for:
  - Document upload confirmations
  - Document expiry reminders (leases, insurance, warranties)
  - Property updates
  - Landlord announcements
- **In-app toast system:** Extend `ToastNotification` widget to show real-time Firestore change events

---

### Phase 4 — Production Hardening

- **App Check:** Already enabled in `debug` mode — switch to `deviceCheck` (iOS) + `playIntegrity` (Android) for production
- **Gemini API key security:** Rotate to Cloud Functions proxy so the API key is never embedded in the app binary
- **Firestore indexes:** Pre-create composite indexes for bills (groupId + status + createdAt), chores (groupId + dueDate), maintenance (propertyId + priority)
- **Crashlytics + Analytics:** Firebase Crashlytics for crash reporting, Analytics for user funnel tracking
- **Rate limiting:** Implement Firestore security rule rate limits on community post creation

---

### Phase 5 — Platform Expansion

- **Web:** Landlord portal optimised for desktop (dashboard analytics, bulk document management)
- **Notifications:** WhatsApp Business API integration for Malaysian landlords
- **Document APIs:** Integration with property marketplace APIs (PropertyGuru / IPropertyMY)
- **Multi-language:** Bahasa Malaysia localisation

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
cd residex

# Backend setup (DocuMind RAG)
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Frontend setup (new terminal)
cd ../residex_app

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

Backend requires `.env` in `backend/` for `GOOGLE_API_KEY` (Gemini). Keep `serviceAccountKey.json` secure and never expose production credentials in public repos.

Frontend currently uses `lib/core/services/gemini_api_key.dart` for app-side Gemini usage. Move to a backend proxy before production.

---

## Project Metrics

| Metric | Value |
|---|---|
| Landlord screens | 8+ |
| Total widgets | 40+ |
| GoRouter routes | 25+ |
| Riverpod providers | 12+ |
| Drift tables | 1 (for local caching) |
| Gemini AI models | 1 (DocuMind) |
| DocuMind RAG endpoints | 4 |
| Color tokens | 70+ |
| Lines of Dart code | ~12,000 (landlord scope) |
| Backend code | FastAPI + LangGraph |
| Supported platforms | Android · iOS · Web |
| Architecture | Clean Architecture (Domain-Driven) |

---

*Residex Landlord Scope — Property Management Operating System*
*Focused on landlord productivity, document management, and AI-powered insights.*
