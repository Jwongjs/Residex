# Residex Complete Migration Checklist

**Created:** January 18, 2026
**Last Updated:** January 22, 2026
**Reference:** React UI at `D:\Projects\Residex\Codes\UI Reference\residex ui`
**Screenshots:** `D:\Projects\Residex\Codes\UI Reference\Screenshots`

---

## Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | Core Renaming & Branding | ✅ COMPLETE |
| Phase 2 | Authentication & Role System | ✅ COMPLETE |
| Phase 3 | Directory Structure Reorganization | ✅ COMPLETE (partial - core done) |
| Phase 4 | Database Schema | ⏳ PENDING |
| Phase 5 | Navigation & Routing | ⏳ PENDING |
| Phase 6 | Screen Implementations | ⏳ PENDING |
| Phase 7 | Theme & Design System | ⏳ PENDING |
| Phase 8 | Providers & State Management | ⏳ PENDING |
| Phase 9 | Testing | ⏳ PENDING |
| Phase 10 | Final Cleanup & Polish | ⏳ PENDING |

---

## App Architecture Overview

### User Roles
The app has **two distinct user experiences**:
1. **Tenant** - Residents who live in rental units
2. **Landlord** - Property owners who manage units

### Navigation Structure

**Tenant Bottom Navigation:**
| Icon | Tab | Screen |
|------|-----|--------|
| LayoutGrid | Dashboard | TenantDashboard |
| Radio | Sync | SyncHub (Home) |
| Users | Community | CommunityBoard |

**Landlord Bottom Navigation:**
| Icon | Tab | Screen |
|------|-----|--------|
| LayoutGrid | Overview | LandlordDashboard |
| TrendingUp | Finance | LandlordFinance |
| Building | Properties | PortfolioView |
| Brain | AI Tools | AIToolsView |

---

## Phase 1: Core Renaming & Branding ✅ COMPLETE

### 1.1 Files Modified ✅

| File | Line | Change | Status |
|------|------|--------|--------|
| `lib/main.dart` | 76, 81, 82 | `BillSplitterApp` → `ResidexApp` | ✅ Done |
| `lib/features/auth/presentation/screens/new_splash_screen.dart` | 200 | `'SplitLah'` → `'Residex'` | ✅ Done |
| `lib/features/auth/presentation/screens/splash_screen.dart` | 63 | Update comment | ✅ Done |
| `test/widget_test.dart` | 16 | `BillSplitterApp` → `ResidexApp` | ✅ Done |

### 1.2 Verification ✅
```bash
flutter analyze  # PASSED
flutter build apk --debug  # PASSED
```

---

## Phase 2: Authentication & Role System ✅ COMPLETE

### 2.1 Update User Entity ✅
**File:** `lib/features/users/domain/entities/user.dart`

User entity fields (Honor System integrated):
```dart
import 'package:equatable/equatable.dart';

/// User role enum - determines which dashboard and features user sees
enum UserRole { tenant, landlord }

/// Sync state for the SyncHub home screen
enum SyncState { synced, drifting, outOfSync }

/// Honor Level tiers (0-5) - Gamified Stewardship System
/// Inspired by competitive gaming honor systems (LoL, CS:GO)
enum HonorLevel {
  restricted,    // Level 0 - Lockout
  rehabilitation, // Level 1 - Probation
  neutral,       // Level 2 - Starting Point (default)
  trusted,       // Level 3 - Good standing
  exemplary,     // Level 4 - Excellent
  paragon,       // Level 5 - Elite (top 5%)
}

class User extends Equatable {
  final String id;
  final String name;
  final String avatarInitials;
  final String? profileImage;
  final String? gradientColor;
  final String? phone;
  final String? email;
  final bool isGuest;

  // ROLE & SCORES
  final UserRole role;              // tenant or landlord
  final int fiscalScore;            // 0-1000 (financial reliability)
  final HonorLevel honorLevel;      // 0-5 tier (behavioral reputation)
  final double trustFactor;         // 0.0-1.0+ (reporter credibility k-factor)
  final SyncState syncState;        // synced, drifting, out_of_sync
  final UserStats? stats;           // Detailed statistics

  const User({
    required this.id,
    required this.name,
    required this.avatarInitials,
    this.profileImage,
    this.gradientColor,
    this.phone,
    this.email,
    this.isGuest = false,
    this.role = UserRole.tenant,
    this.fiscalScore = 500,
    this.honorLevel = HonorLevel.neutral,
    this.trustFactor = 0.7,
    this.syncState = SyncState.synced,
    this.stats,
  });

  @override
  List<Object?> get props => [id, name, role, fiscalScore, honorLevel];

  // ... copyWith method
}
```

### 2.2 Create Login Screen with Role Selection ✅
**File:** `lib/features/auth/presentation/screens/login_screen.dart`

**UI Elements (from screenshot):**
- ✅ Residex logo (gradient purple/blue)
- ✅ "The residential super app" tagline
- ✅ Full Name input field
- ✅ Email Address input field
- ✅ Phone Number input (MY +60 prefix)
- ✅ "Log In" button (gradient blue→purple)
- ✅ Two dev buttons: "Tenant Dev" (blue) | "Landlord Dev" (amber)
- ✅ Social login: Google, Facebook
- ✅ "Sign Up" link

**Login Flow:**
```
Login Screen
    ├── onLogin(role: TENANT) → SyncHub ✅
    └── onLogin(role: LANDLORD) → LandlordDashboard ✅
```

### 2.3 Create Register Screen ✅
**File:** `lib/features/auth/presentation/screens/register_screen.dart`

- ✅ Password field
- ✅ Confirm password
- ✅ Role selection (Tenant/Landlord toggle)

---

## Phase 3: Directory Structure Reorganization ✅ COMPLETE (Core)

### 3.1 New Feature Module Structure

**Status Legend:** ✅ Created | ⏳ Pending | 🔨 In Progress

```
lib/features/
├── auth/                    # ✅ EXISTING - Login, Register, Splash
│   ├── data/
│   ├── domain/
│   └── presentation/
│       └── screens/
│           ├── login_screen.dart        # ✅ Role selection added
│           ├── register_screen.dart     # ✅ Role field added
│           ├── splash_screen.dart       # ✅ KEEP
│           └── new_splash_screen.dart   # ✅ KEEP
│
├── users/                   # ✅ EXISTING - User management (Honor fields added)
│   └── ...
│
├── property/                # ✅ EXISTING (was "groups") - Property/Unit management
│   └── ...
│
├── bills/                   # ✅ EXISTING - Bill splitting
│   └── ...
│
├── tenant/                  # ✅ CREATED - Tenant-specific features
│   ├── data/
│   ├── domain/
│   └── presentation/
│       ├── screens/
│       │   ├── sync_hub_screen.dart          # Home for tenants
│       │   ├── tenant_dashboard_screen.dart  # Main dashboard
│       │   └── score_detail_screen.dart      # Fiscal/Harmony details
│       └── widgets/
│           ├── balance_card.dart             # Score display card
│           ├── summary_cards.dart            # You Owe / Tasks cards
│           ├── friends_list.dart             # Housemates list
│           └── liquidity_widget.dart         # Money flow widget
│
├── landlord/                # ✅ CREATED - Landlord-specific features
│   ├── data/
│   ├── domain/
│   └── presentation/
│       ├── screens/
│       │   ├── landlord_dashboard_screen.dart  # Asset Command
│       │   ├── property_pulse_screen.dart      # System health
│       │   ├── portfolio_screen.dart           # Property list
│       │   ├── landlord_finance_screen.dart    # Financial analytics
│       │   ├── tenant_management_screen.dart   # Manage tenants
│       │   └── ai_tools_screen.dart            # AI features
│       └── widgets/
│           ├── property_pulse_card.dart        # Health score card
│           ├── reputation_card.dart            # Landlord rating
│           ├── revenue_chart.dart              # Income chart
│           └── expense_breakdown.dart          # Pie chart
│
├── chores/                  # ✅ CREATED - Chore Scheduler
│   ├── data/
│   │   ├── datasources/
│   │   │   └── chore_local_datasource.dart
│   │   ├── models/
│   │   │   ├── chore_model.dart
│   │   │   └── chore_assignment_model.dart
│   │   └── repositories/
│   │       └── chore_repository_impl.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── chore.dart
│   │   │   └── chore_assignment.dart
│   │   ├── repositories/
│   │   │   └── chore_repository.dart
│   │   └── usecases/
│   │       ├── get_chores_by_property.dart
│   │       ├── create_chore.dart
│   │       ├── assign_chore.dart
│   │       └── complete_chore.dart
│   └── presentation/
│       ├── providers/
│       │   └── chore_provider.dart
│       ├── screens/
│       │   ├── chore_scheduler_screen.dart     # Full calendar view
│       │   └── create_chore_screen.dart        # Add new chore
│       └── widgets/
│           ├── calendar_widget.dart            # Week/Month calendar
│           ├── chore_tile.dart                 # Single chore item
│           └── chore_templates.dart            # Quick add templates
│
├── maintenance/             # ✅ CREATED - Maintenance Tickets
│   ├── data/
│   │   ├── datasources/
│   │   │   └── maintenance_local_datasource.dart
│   │   ├── models/
│   │   │   ├── ticket_model.dart
│   │   │   ├── ticket_comment_model.dart
│   │   │   └── ticket_attachment_model.dart
│   │   └── repositories/
│   │       └── maintenance_repository_impl.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── maintenance_ticket.dart
│   │   │   ├── ticket_comment.dart
│   │   │   └── ticket_attachment.dart
│   │   ├── repositories/
│   │   │   └── maintenance_repository.dart
│   │   └── usecases/
│   │       ├── get_tickets.dart
│   │       ├── create_ticket.dart
│   │       ├── update_ticket_status.dart
│   │       └── add_ticket_comment.dart
│   └── presentation/
│       ├── providers/
│       │   └── maintenance_provider.dart
│       ├── screens/
│       │   ├── maintenance_list_screen.dart    # Ticket list
│       │   ├── ticket_detail_screen.dart       # Single ticket view
│       │   └── create_ticket_screen.dart       # Report issue
│       └── widgets/
│           ├── ticket_card.dart                # Ticket list item
│           ├── priority_badge.dart             # HIGH/MEDIUM/LOW
│           └── attachment_picker.dart          # Photo upload
│
├── community/               # ⏳ PENDING - Community Board
│   ├── data/
│   │   ├── datasources/
│   │   │   └── community_local_datasource.dart
│   │   ├── models/
│   │   │   ├── post_model.dart
│   │   │   ├── post_reaction_model.dart
│   │   │   └── post_comment_model.dart
│   │   └── repositories/
│   │       └── community_repository_impl.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── community_post.dart
│   │   │   └── post_comment.dart
│   │   ├── repositories/
│   │   │   └── community_repository.dart
│   │   └── usecases/
│   │       ├── get_posts.dart
│   │       ├── create_post.dart
│   │       ├── toggle_reaction.dart
│   │       └── add_comment.dart
│   └── presentation/
│       ├── providers/
│       │   └── community_provider.dart
│       ├── screens/
│       │   ├── community_board_screen.dart     # Feed + Events tabs
│       │   ├── post_detail_screen.dart         # Single post
│       │   └── create_post_screen.dart         # New post
│       └── widgets/
│           ├── post_card.dart                  # Post in feed
│           ├── reaction_bar.dart               # Like/Comment/Share
│           └── post_type_badge.dart            # ALERT/EVENT/GENERAL
│
├── honor/                   # ⏳ PENDING - Honor System (replaces old scores)
│   ├── data/
│   ├── data/
│   │   ├── datasources/
│   │   │   └── honor_local_datasource.dart
│   │   ├── models/
│   │   │   ├── honor_profile_model.dart
│   │   │   ├── honor_report_model.dart
│   │   │   ├── honor_event_model.dart
│   │   │   ├── tribunal_session_model.dart
│   │   │   └── fiscal_score_model.dart
│   │   └── repositories/
│   │       └── honor_repository_impl.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── honor_profile.dart              # 5-tier levels + trust factor
│   │   │   ├── honor_report.dart               # Evidence-based reports
│   │   │   ├── honor_event.dart                # Level change audit
│   │   │   ├── tribunal_session.dart           # Severe case reviews
│   │   │   └── fiscal_score.dart               # Payment reliability
│   │   ├── repositories/
│   │   │   └── honor_repository.dart
│   │   └── usecases/
│   │       ├── get_honor_profile.dart
│   │       ├── submit_report.dart
│   │       ├── process_tribunal.dart
│   │       └── calculate_trust_factor.dart
│   └── presentation/
│       ├── providers/
│       │   └── honor_provider.dart
│       ├── screens/
│       │   ├── honor_detail_screen.dart        # Full Honor breakdown
│       │   ├── tribunal_screen.dart            # Severe case review (Level 4-5 users)
│       │   └── leaderboard_screen.dart         # Rankings
│       └── widgets/
│           ├── honor_level_badge.dart          # Level 0-5 display
│           ├── trust_factor_indicator.dart     # K-factor visual
│           ├── report_card.dart                # Report summary
│           └── redemption_progress.dart        # Recovery tracker
│
├── gamification/            # ⏳ PENDING - Achievements & Badges
│   ├── data/
│   │   └── ...
│   ├── domain/
│   │   └── entities/
│   │       ├── achievement.dart
│   │       └── badge.dart
│   └── presentation/
│       ├── screens/
│       │   └── gamification_hub_screen.dart    # Agent-style view
│       └── widgets/
│           ├── badge_widget.dart               # Trophy/Shield/etc
│           ├── achievement_card.dart           # Unlocked items
│           └── trophy_unlock_overlay.dart      # Celebration modal
│
├── ai_assistant/            # ⏳ PENDING - Rex AI Assistant
│   └── presentation/
│       ├── screens/
│       │   ├── rex_interface_screen.dart       # Chat with Rex
│       │   ├── lazy_logger_screen.dart         # Document AI
│       │   └── lease_sentinel_screen.dart      # Contract AI
│       └── widgets/
│           ├── ask_rex_button.dart             # Floating pill button
│           └── ai_response_card.dart           # AI message bubble
│
└── handover/                # ⏳ PENDING - Digital Handover (Future)
    └── ...
```

### 3.2 Create Feature Directories
For each new feature, run these commands:

```bash
# Tenant features
mkdir -p lib/features/tenant/data/datasources
mkdir -p lib/features/tenant/data/models
mkdir -p lib/features/tenant/data/repositories
mkdir -p lib/features/tenant/domain/entities
mkdir -p lib/features/tenant/domain/repositories
mkdir -p lib/features/tenant/domain/usecases
mkdir -p lib/features/tenant/presentation/providers
mkdir -p lib/features/tenant/presentation/screens
mkdir -p lib/features/tenant/presentation/widgets

# Landlord features
mkdir -p lib/features/landlord/data/datasources
mkdir -p lib/features/landlord/data/models
mkdir -p lib/features/landlord/data/repositories
mkdir -p lib/features/landlord/domain/entities
mkdir -p lib/features/landlord/domain/repositories
mkdir -p lib/features/landlord/domain/usecases
mkdir -p lib/features/landlord/presentation/providers
mkdir -p lib/features/landlord/presentation/screens
mkdir -p lib/features/landlord/presentation/widgets

# Chores
mkdir -p lib/features/chores/data/datasources
mkdir -p lib/features/chores/data/models
mkdir -p lib/features/chores/data/repositories
mkdir -p lib/features/chores/domain/entities
mkdir -p lib/features/chores/domain/repositories
mkdir -p lib/features/chores/domain/usecases
mkdir -p lib/features/chores/presentation/providers
mkdir -p lib/features/chores/presentation/screens
mkdir -p lib/features/chores/presentation/widgets

# Maintenance
mkdir -p lib/features/maintenance/data/datasources
mkdir -p lib/features/maintenance/data/models
mkdir -p lib/features/maintenance/data/repositories
mkdir -p lib/features/maintenance/domain/entities
mkdir -p lib/features/maintenance/domain/repositories
mkdir -p lib/features/maintenance/domain/usecases
mkdir -p lib/features/maintenance/presentation/providers
mkdir -p lib/features/maintenance/presentation/screens
mkdir -p lib/features/maintenance/presentation/widgets

# Community
mkdir -p lib/features/community/data/datasources
mkdir -p lib/features/community/data/models
mkdir -p lib/features/community/data/repositories
mkdir -p lib/features/community/domain/entities
mkdir -p lib/features/community/domain/repositories
mkdir -p lib/features/community/domain/usecases
mkdir -p lib/features/community/presentation/providers
mkdir -p lib/features/community/presentation/screens
mkdir -p lib/features/community/presentation/widgets

# Honor System (replaces old Scores)
mkdir -p lib/features/honor/data/datasources
mkdir -p lib/features/honor/data/models
mkdir -p lib/features/honor/data/repositories
mkdir -p lib/features/honor/domain/entities
mkdir -p lib/features/honor/domain/repositories
mkdir -p lib/features/honor/domain/usecases
mkdir -p lib/features/honor/presentation/providers
mkdir -p lib/features/honor/presentation/screens
mkdir -p lib/features/honor/presentation/widgets

# Gamification
mkdir -p lib/features/gamification/data/datasources
mkdir -p lib/features/gamification/data/models
mkdir -p lib/features/gamification/domain/entities
mkdir -p lib/features/gamification/presentation/screens
mkdir -p lib/features/gamification/presentation/widgets

# AI Assistant
mkdir -p lib/features/ai_assistant/presentation/screens
mkdir -p lib/features/ai_assistant/presentation/widgets
```

---

## Phase 4: Database Schema (Detailed) ⏳ NEXT

See separate file: `phase3-database-schema.md` (updated with Honor System)

**Summary of tables to create:**
- Chores (3 tables): `chores`, `chore_assignments`, `chore_rotations`
- Maintenance (3 tables): `maintenance_tickets`, `ticket_comments`, `ticket_attachments`
- Handover (3 tables): `handover_sessions`, `handover_items`, `ghost_overlays`
- **Honor System (6 tables):**
  - `honor_profiles` - User honor level + trust factor
  - `honor_reports` - Evidence-based reports against users
  - `honor_events` - Level change audit trail
  - `tribunal_sessions` - Panel reviews for severe cases
  - `redemption_programs` - Recovery tracking
  - `fiscal_scores` - Payment reliability scores
- Community (3 tables): `community_posts`, `post_reactions`, `post_comments`

**Total: 18 new tables**

---

## Phase 5: Navigation & Routing

### 5.1 Update GoRouter
**File:** `lib/core/router/app_router.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Auth screens
import 'package:residex_app/features/auth/presentation/screens/new_splash_screen.dart';
import 'package:residex_app/features/auth/presentation/screens/login_screen.dart';
import 'package:residex_app/features/auth/presentation/screens/register_screen.dart';

// Tenant screens
import 'package:residex_app/features/tenant/presentation/screens/sync_hub_screen.dart';
import 'package:residex_app/features/tenant/presentation/screens/tenant_dashboard_screen.dart';
import 'package:residex_app/features/scores/presentation/screens/score_detail_screen.dart';

// Bills screens (existing)
import 'package:residex_app/features/bills/presentation/screens/dashboard_screen.dart';
import 'package:residex_app/features/bills/presentation/screens/bill_detail_screen.dart';
import 'package:residex_app/features/bills/presentation/screens/bill_creation/create_bill_flow.dart';
import 'package:residex_app/features/bills/presentation/screens/you_owe_screen.dart';
import 'package:residex_app/features/bills/presentation/screens/owed_to_you_screen.dart';

// Chores screens
import 'package:residex_app/features/chores/presentation/screens/chore_scheduler_screen.dart';
import 'package:residex_app/features/chores/presentation/screens/create_chore_screen.dart';

// Community screens
import 'package:residex_app/features/community/presentation/screens/community_board_screen.dart';
import 'package:residex_app/features/community/presentation/screens/post_detail_screen.dart';
import 'package:residex_app/features/community/presentation/screens/create_post_screen.dart';

// Gamification screens
import 'package:residex_app/features/gamification/presentation/screens/gamification_hub_screen.dart';

// AI screens
import 'package:residex_app/features/ai_assistant/presentation/screens/rex_interface_screen.dart';

// Landlord screens
import 'package:residex_app/features/landlord/presentation/screens/landlord_dashboard_screen.dart';
import 'package:residex_app/features/landlord/presentation/screens/property_pulse_screen.dart';
import 'package:residex_app/features/landlord/presentation/screens/portfolio_screen.dart';
import 'package:residex_app/features/landlord/presentation/screens/landlord_finance_screen.dart';
import 'package:residex_app/features/landlord/presentation/screens/tenant_management_screen.dart';
import 'package:residex_app/features/landlord/presentation/screens/ai_tools_screen.dart';
import 'package:residex_app/features/ai_assistant/presentation/screens/lazy_logger_screen.dart';
import 'package:residex_app/features/ai_assistant/presentation/screens/lease_sentinel_screen.dart';

// Maintenance screens (shared)
import 'package:residex_app/features/maintenance/presentation/screens/maintenance_list_screen.dart';
import 'package:residex_app/features/maintenance/presentation/screens/ticket_detail_screen.dart';
import 'package:residex_app/features/maintenance/presentation/screens/create_ticket_screen.dart';

// Profile screens (shared)
import 'package:residex_app/features/users/presentation/screens/profile_screen.dart';
import 'package:residex_app/features/users/presentation/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Auth Routes
    GoRoute(path: '/splash', builder: (_, __) => const NewSplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

    // ==================
    // TENANT ROUTES
    // ==================
    GoRoute(path: '/sync-hub', builder: (_, __) => const SyncHubScreen()),
    GoRoute(path: '/tenant-dashboard', builder: (_, __) => const TenantDashboardScreen()),
    GoRoute(path: '/score-detail', builder: (_, __) => const ScoreDetailScreen()),

    // Bills (existing)
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/bill/:id', builder: (_, state) => BillDetailScreen(billId: state.pathParameters['id']!)),
    GoRoute(path: '/create-bill', builder: (_, __) => const CreateBillFlow()),
    GoRoute(path: '/you-owe', builder: (_, __) => const YouOweScreen()),
    GoRoute(path: '/owed-to-you', builder: (_, __) => const OwedToYouScreen()),

    // Chores
    GoRoute(path: '/chores', builder: (_, __) => const ChoreSchedulerScreen()),
    GoRoute(path: '/chores/create', builder: (_, __) => const CreateChoreScreen()),

    // Community
    GoRoute(path: '/community', builder: (_, __) => const CommunityBoardScreen()),
    GoRoute(path: '/community/post/:id', builder: (_, state) => PostDetailScreen(postId: state.pathParameters['id']!)),
    GoRoute(path: '/community/create', builder: (_, __) => const CreatePostScreen()),

    // Gamification
    GoRoute(path: '/gamification', builder: (_, __) => const GamificationHubScreen()),

    // AI
    GoRoute(path: '/rex', builder: (_, __) => const RexInterfaceScreen()),

    // ==================
    // LANDLORD ROUTES
    // ==================
    GoRoute(path: '/landlord-dashboard', builder: (_, __) => const LandlordDashboardScreen()),
    GoRoute(path: '/property-pulse', builder: (_, __) => const PropertyPulseScreen()),
    GoRoute(path: '/portfolio', builder: (_, __) => const PortfolioScreen()),
    GoRoute(path: '/landlord-finance', builder: (_, __) => const LandlordFinanceScreen()),
    GoRoute(path: '/tenants', builder: (_, __) => const TenantManagementScreen()),
    GoRoute(path: '/ai-tools', builder: (_, __) => const AIToolsScreen()),
    GoRoute(path: '/lazy-logger', builder: (_, __) => const LazyLoggerScreen()),
    GoRoute(path: '/lease-sentinel', builder: (_, __) => const LeaseSentinelScreen()),

    // Maintenance (shared)
    GoRoute(path: '/maintenance', builder: (_, __) => const MaintenanceListScreen()),
    GoRoute(path: '/maintenance/:id', builder: (_, state) => TicketDetailScreen(ticketId: state.pathParameters['id']!)),
    GoRoute(path: '/maintenance/create', builder: (_, __) => const CreateTicketScreen()),

    // Profile (shared)
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);
```

### 5.2 Create Bottom Navigation Widgets

**Tenant Navigation:**
**File:** `lib/core/widgets/tenant_bottom_nav.dart`
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:residex_app/core/theme/app_theme.dart';

/// Tenant bottom navigation bar
/// Tabs: Dashboard | Sync Hub | Community
class TenantBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const TenantBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.15,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.9),
            Colors.black,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.grid_view_rounded,
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.sensors_rounded, // Radio/Sync icon
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.people_rounded,
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: isActive
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tenantPrimary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              )
            : null,
        child: Icon(
          icon,
          size: isActive ? 28 : 24,
          color: isActive ? AppColors.tenantPrimary : Colors.grey,
        ),
      ),
    );
  }
}
```

**Landlord Navigation:**
**File:** `lib/core/widgets/landlord_bottom_nav.dart`
```dart
import 'package:flutter/material.dart';
import 'package:residex_app/core/theme/app_theme.dart';

/// Landlord tab enum
enum LandlordTab { overview, finance, properties, aiTools }

/// Landlord bottom navigation bar
/// Tabs: Overview | Finance | Properties | AI Tools
class LandlordBottomNav extends StatelessWidget {
  final LandlordTab activeTab;
  final Function(LandlordTab) onTabChange;

  const LandlordBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.12,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LandlordNavItem(
            icon: Icons.grid_view_rounded,
            label: 'Overview',
            isActive: activeTab == LandlordTab.overview,
            onTap: () => onTabChange(LandlordTab.overview),
          ),
          _LandlordNavItem(
            icon: Icons.trending_up_rounded,
            label: 'Finance',
            isActive: activeTab == LandlordTab.finance,
            onTap: () => onTabChange(LandlordTab.finance),
          ),
          _LandlordNavItem(
            icon: Icons.apartment_rounded,
            label: 'Properties',
            isActive: activeTab == LandlordTab.properties,
            onTap: () => onTabChange(LandlordTab.properties),
          ),
          _LandlordNavItem(
            icon: Icons.psychology_rounded, // Brain/AI icon
            label: 'AI Tools',
            isActive: activeTab == LandlordTab.aiTools,
            onTap: () => onTabChange(LandlordTab.aiTools),
          ),
        ],
      ),
    );
  }
}

class _LandlordNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LandlordNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: isActive ? 26 : 22,
            color: isActive ? AppColors.landlordPrimary : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.landlordPrimary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 6: Screen Implementations (Priority Order)

### 6.1 Tenant Screens

#### SyncHubScreen (Home)
**Reference:** `components/SyncHub.tsx`, Screenshot `125853.png`

**UI Elements:**
- Large Residex logo (animated, responsive to sync state)
- Greeting text based on SyncState:
  - SYNCED: "You are in Sync." (indigo theme)
  - DRIFTING: "Drifting slightly." (amber theme)
  - OUT_OF_SYNC: "Out of Sync." (rose theme)
- Two prediction cards:
  - Left: "Rent Due" with amount and deadline
  - Right: "Trash Duty" with assignment
- "Ask Rex" floating pill button (gradient blue→purple)
- Bottom navigation

#### TenantDashboardScreen
**Reference:** `components/TenantDashboard.tsx`, Screenshot `125806.png`

**UI Elements:**
- Header with user avatar, name, rank badge, streak
- BalanceCard:
  - "USER DASHBOARD" label
  - User name
  - "+ New Invoice" button
  - Fiscal Score (left card) - 0-1000 payment reliability
  - Honor Level (right card) - Level 0-5 with badge
- SummaryCards row:
  - "You Owe" amount
  - "Pending Tasks" count
- SharedResidents list (housemates with LVL badges)
- CalendarWidget (upcoming chores)
- LiquidityWidget (money flow)
- ReportWidget (maintenance issues)

#### HonorDetailScreen
**Reference:** `components/ScoreDetail.tsx` (updated for Honor System)

**UI Elements:**
- Honor Level badge (Level 0-5 with name)
- Fiscal Score display (0-1000)
- Trust Factor indicator (k-factor visual)
- Level progression bar (time to next level)
- Report history (against you / by you)
- Redemption progress (if applicable)
- Leaderboard position

### 6.2 Landlord Screens

#### LandlordDashboardScreen (Asset Command)
**Reference:** `components/LandlordDashboard.tsx`, Screenshots `125853.png`, `125927.png`

**UI Elements:**
- Header: "Asset Command" / "Portfolio Overview"
- User info row (avatar, name, "Property Owner" label)
- Notification bell button
- **OverviewView:**
  - Property Pulse Hero Card (score out of 100, Open Issues, Collections %)
  - Reputation Card (star rating, review count, badges: Steady Lah, Fast Fixer, Friendly)
  - Operations list:
    - Maintenance button (pending tickets count)
    - Tenants button (units occupied count)
  - Quick Actions Grid:
    - AI Assistant card
    - Financials card
- Bottom nav (4 tabs)

#### PropertyPulseScreen
**Reference:** `components/PropertyPulseDetail.tsx`, Screenshot `125927.png`

**UI Elements:**
- Large score display (87/100 "Excellent Condition")
- Vitals Check grid:
  - Bills: All Paid / X Pending
  - Tickets: X Open
  - Chores: X% Done
  - Rent: Due in Xd / Paid
- AI Insights section

#### LandlordFinanceScreen
**Reference:** `components/LandlordFinance.tsx`

**UI Elements:**
- Net Income card (large amount with percentage change)
- Stats grid: Collected / Pending amounts
- Revenue Trend chart (bar chart, 6 months)
- Expense Breakdown (horizontal bar chart):
  - Maintenance, Utilities, Insurance, Services

#### PortfolioScreen
**Reference:** `components/LandlordDashboard.tsx` PropertiesView, Screenshot `130026.png`

**UI Elements:**
- "Portfolio" header with "+ Add Unit" button
- Property cards:
  - Property name (Verdi Eco-Dominium)
  - Unit number (Unit 4-2)
  - Status badge (OCCUPIED / VACANT)
  - Tenant info (avatar, name)
  - Rent status (PAID / PENDING)

#### MaintenanceListScreen (Shared)
**Reference:** `components/MaintenanceManager.tsx`, Screenshot `125938.png`

**UI Elements:**
- "MAINTENANCE" header with back button
- Ticket cards:
  - Wrench icon (color based on status)
  - Title (Leaking Sink)
  - Unit/Location (Unit 4-2)
  - Priority badge (HIGH/MEDIUM/LOW with colors)
  - Date
  - "View Details" button

### 6.3 Shared Screens

#### CommunityBoardScreen
**Reference:** `components/CommunityBoardPage.tsx`

**UI Elements:**
- Header: "Community" / "Digital Board"
- Tab bar: Feed | Events
- Post cards:
  - Author avatar, name, time
  - Type badge (ALERT/EVENT/GENERAL)
  - Title and description
  - Action bar: Like count | Comment count | Share

#### ChoreSchedulerScreen
**Reference:** `components/ChoreScheduler.tsx`

**UI Elements:**
- "Shared Calendar" header with expand/add buttons
- Week strip (scrollable, 14 days)
- Full month calendar (expanded view)
- Tasks list for selected date:
  - Checkbox icon (status)
  - Chore name
  - Time
  - Assignee avatar
- Add Chore Modal:
  - Chore templates grid (icons)
  - Task name input
  - Assignee dropdown
  - Time picker
  - Create button

---

## Phase 7: Theme & Design System

### 7.1 Update App Theme
**File:** `lib/core/theme/app_theme.dart`

**Colors to add:**
```dart
import 'package:flutter/material.dart';

/// App color palette - Residex brand colors
class AppColors {
  // Prevent instantiation
  AppColors._();

  // ==================
  // EXISTING COLORS
  // ==================
  static const background = Color(0xFF000212);  // Deep black-blue
  static const primaryCyan = Color(0xFF22D3EE);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // ==================
  // NEW - Role-based colors
  // ==================
  static const tenantPrimary = Color(0xFF6366F1);   // Indigo
  static const tenantSecondary = Color(0xFF8B5CF6); // Purple
  static const landlordPrimary = Color(0xFF3B82F6); // Blue
  static const landlordSecondary = Color(0xFF06B6D4); // Cyan

  // ==================
  // Score colors
  // ==================
  static const fiscalGreen = Color(0xFF10B981);
  static const harmonyPurple = Color(0xFF8B5CF6);
  static const scorePositive = Color(0xFF22C55E);
  static const scoreNegative = Color(0xFFEF4444);

  // ==================
  // Sync state colors (for SyncHub)
  // ==================
  static const syncedIndigo = Color(0xFF6366F1);
  static const driftingAmber = Color(0xFFF59E0B);
  static const outOfSyncRose = Color(0xFFF43F5E);

  // ==================
  // Priority colors (for maintenance tickets)
  // ==================
  static const priorityHigh = Color(0xFFEF4444);    // Red
  static const priorityMedium = Color(0xFFF59E0B);  // Amber
  static const priorityLow = Color(0xFF6B7280);     // Gray

  // ==================
  // Status colors
  // ==================
  static const statusOpen = Color(0xFF3B82F6);      // Blue
  static const statusInProgress = Color(0xFFF59E0B); // Amber
  static const statusResolved = Color(0xFF10B981);   // Green
  static const statusPaid = Color(0xFF22D3EE);       // Cyan
  static const statusPending = Color(0xFFF59E0B);    // Amber
  static const statusOverdue = Color(0xFFEF4444);    // Red

  // ==================
  // Card backgrounds
  // ==================
  static const cardDark = Color(0xFF0F172A);
  static const cardGlass = Color(0x1AFFFFFF);  // white/10
  static const cardBorder = Color(0x1AFFFFFF); // white/10
  static const cardHover = Color(0x33FFFFFF);  // white/20

  // ==================
  // Rank colors (gamification)
  // ==================
  static const rankBronze = Color(0xFFCD7F32);
  static const rankSilver = Color(0xFFC0C0C0);
  static const rankGold = Color(0xFFFFD700);
  static const rankPlatinum = Color(0xFFE5E4E2);
  static const rankDiamond = Color(0xFFB9F2FF);
}
```

### 7.2 Gradient Definitions
```dart
import 'package:flutter/material.dart';

/// App gradient definitions
class AppGradients {
  // Prevent instantiation
  AppGradients._();

  /// Primary button gradient (blue → purple)
  static const primaryButton = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Secondary button gradient (cyan → blue)
  static const secondaryButton = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Tenant card background gradient
  static const tenantCard = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Landlord card background gradient
  static const landlordCard = LinearGradient(
    colors: [Color(0xFF1E3A5F), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Synced state background
  static const syncedBackground = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF020617), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Drifting state background
  static const driftingBackground = LinearGradient(
    colors: [Color(0xFF78350F), Color(0xFF020617), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Out of sync state background
  static const outOfSyncBackground = LinearGradient(
    colors: [Color(0xFF881337), Color(0xFF020617), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Score card gradient (fiscal)
  static const fiscalCard = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Score card gradient (harmony)
  static const harmonyCard = LinearGradient(
    colors: [Color(0xFF5B21B6), Color(0xFF000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
```

### 7.3 Border Radius Standards
```dart
import 'package:flutter/material.dart';

/// App border radius constants
class AppRadius {
  // Prevent instantiation
  AppRadius._();

  /// Small radius for buttons, inputs, chips
  static const double small = 12.0;

  /// Medium radius for small cards, list items
  static const double medium = 16.0;

  /// Large radius for standard cards (1.5rem)
  static const double large = 24.0;

  /// Extra large radius for large cards (2rem)
  static const double xl = 32.0;

  /// Extra extra large radius for hero cards (2.5rem)
  static const double xxl = 40.0;

  // BorderRadius instances for convenience
  static final BorderRadius smallRadius = BorderRadius.circular(small);
  static final BorderRadius mediumRadius = BorderRadius.circular(medium);
  static final BorderRadius largeRadius = BorderRadius.circular(large);
  static final BorderRadius xlRadius = BorderRadius.circular(xl);
  static final BorderRadius xxlRadius = BorderRadius.circular(xxl);
}

/// App spacing constants
class AppSpacing {
  // Prevent instantiation
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// App text styles
class AppTextStyles {
  // Prevent instantiation
  AppTextStyles._();

  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    color: Colors.white,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: Colors.white,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Colors.white,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF94A3B8),
  );

  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: Color(0xFF64748B),
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    color: Color(0xFF64748B),
  );
}
```

---

## Phase 8: Providers & State Management

### 8.1 New Providers to Create

**File:** `lib/core/di/injection.dart` (update)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// User entity and enums
import 'package:residex_app/features/users/domain/entities/user.dart';

// Honor System entities
import 'package:residex_app/features/honor/domain/entities/honor_profile.dart';
import 'package:residex_app/features/honor/domain/repositories/honor_repository.dart';

// Chore entities
import 'package:residex_app/features/chores/domain/entities/chore.dart';
import 'package:residex_app/features/chores/domain/entities/chore_assignment.dart';
import 'package:residex_app/features/chores/domain/repositories/chore_repository.dart';

// Maintenance entities
import 'package:residex_app/features/maintenance/domain/entities/maintenance_ticket.dart';
import 'package:residex_app/features/maintenance/domain/repositories/maintenance_repository.dart';

// Community entities
import 'package:residex_app/features/community/domain/entities/community_post.dart';
import 'package:residex_app/features/community/domain/repositories/community_repository.dart';

// ===================
// USER & AUTH PROVIDERS
// ===================

/// Current logged-in user
final currentUserProvider = StateProvider<User?>((ref) => null);

/// Current user's role (tenant or landlord)
final userRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(currentUserProvider)?.role ?? UserRole.tenant;
});

/// Check if current user is a landlord
final isLandlordProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == UserRole.landlord;
});

// ===================
// HONOR SYSTEM PROVIDERS
// ===================

/// Repository provider for honor system
final honorRepositoryProvider = Provider<HonorRepository>((ref) {
  throw UnimplementedError('Provide HonorRepository implementation');
});

/// Get honor profile by user ID
final honorProfileProvider = FutureProvider.family<HonorProfile?, String>((ref, userId) async {
  final repo = ref.watch(honorRepositoryProvider);
  return repo.getHonorProfile(userId);
});

/// Get current user's honor profile
final currentUserHonorProvider = FutureProvider<HonorProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(honorProfileProvider(user.id).future);
});

/// Get users eligible for Tribunal (Level 4-5)
final tribunalEligibleUsersProvider = FutureProvider<List<HonorProfile>>((ref) async {
  final repo = ref.watch(honorRepositoryProvider);
  return repo.getProfilesByLevel(4); // Level 4+ can participate
});

// ===================
// CHORE PROVIDERS
// ===================

/// Repository provider for chores (implement in chore feature)
final choreRepositoryProvider = Provider<ChoreRepository>((ref) {
  throw UnimplementedError('Provide ChoreRepository implementation');
});

/// Get all chores for a property
final choresByPropertyProvider = FutureProvider.family<List<Chore>, String>((ref, propertyId) async {
  final repo = ref.watch(choreRepositoryProvider);
  return repo.getChoresByProperty(propertyId);
});

/// Get pending chore assignments for a user
final pendingChoresProvider = FutureProvider.family<List<ChoreAssignment>, String>((ref, userId) async {
  final repo = ref.watch(choreRepositoryProvider);
  return repo.getPendingAssignments(userId);
});

/// Get chore count for current user
final pendingChoreCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  final chores = await ref.watch(pendingChoresProvider(user.id).future);
  return chores.length;
});

// ===================
// MAINTENANCE PROVIDERS
// ===================

/// Repository provider for maintenance (implement in maintenance feature)
final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  throw UnimplementedError('Provide MaintenanceRepository implementation');
});

/// Get all tickets for a property
final ticketsByPropertyProvider = FutureProvider.family<List<MaintenanceTicket>, String>((ref, propertyId) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getTicketsByProperty(propertyId);
});

/// Get open ticket count for a property
final openTicketCountProvider = FutureProvider.family<int, String>((ref, propertyId) async {
  final tickets = await ref.watch(ticketsByPropertyProvider(propertyId).future);
  return tickets.where((t) => t.status != 'resolved' && t.status != 'closed').length;
});

/// Get high priority tickets for a property
final highPriorityTicketsProvider = FutureProvider.family<List<MaintenanceTicket>, String>((ref, propertyId) async {
  final tickets = await ref.watch(ticketsByPropertyProvider(propertyId).future);
  return tickets.where((t) => t.priority == 'high' || t.priority == 'urgent').toList();
});

// ===================
// COMMUNITY PROVIDERS
// ===================

/// Repository provider for community (implement in community feature)
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  throw UnimplementedError('Provide CommunityRepository implementation');
});

/// Get all posts for a property
final communityPostsProvider = FutureProvider.family<List<CommunityPost>, String>((ref, propertyId) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getPostsByProperty(propertyId);
});

/// Get pinned posts only
final pinnedPostsProvider = FutureProvider.family<List<CommunityPost>, String>((ref, propertyId) async {
  final posts = await ref.watch(communityPostsProvider(propertyId).future);
  return posts.where((p) => p.isPinned).toList();
});

/// Get recent posts (last 10)
final recentPostsProvider = FutureProvider.family<List<CommunityPost>, String>((ref, propertyId) async {
  final posts = await ref.watch(communityPostsProvider(propertyId).future);
  return posts.take(10).toList();
});
```

---

## Phase 9: Testing Checklist

### 9.1 Unit Tests
- [ ] Honor Level progression logic
- [ ] Trust Factor (k-factor) calculation
- [ ] Report verification pipeline
- [ ] Tribunal voting logic
- [ ] Redemption mechanics
- [ ] Fiscal Score calculation
- [ ] Chore rotation algorithm
- [ ] Sync state determination
- [ ] Payment tracking

### 9.2 Widget Tests
- [ ] Login screen with role selection
- [ ] SyncHubScreen with all sync states
- [ ] TenantDashboardScreen
- [ ] LandlordDashboardScreen
- [ ] ChoreSchedulerScreen calendar
- [ ] MaintenanceListScreen with priorities
- [ ] CommunityBoardScreen tabs

### 9.3 Integration Tests
- [ ] Tenant login → SyncHub → Dashboard flow
- [ ] Landlord login → Dashboard → Finance flow
- [ ] Create chore → Assign → Complete flow
- [ ] Create maintenance ticket → Update → Resolve flow
- [ ] Create community post → React → Comment flow

---

## Phase 10: Final Cleanup & Polish

### 10.1 Remove Legacy References
- [ ] Search codebase for "SplitLah" - remove all
- [ ] Search codebase for "BillSplitter" - remove all
- [ ] Remove unused bill-splitter-only components
- [ ] Clean up unused imports

### 10.2 App Store Preparation
- [ ] Update `pubspec.yaml`:
  - name: residex_app
  - description: The residential super app
  - version: 1.0.0
- [ ] Update app icon (use Residex logo)
- [ ] Update splash screen assets
- [ ] Prepare Play Store / App Store metadata

---

## Quick Reference: React → Flutter Component Mapping

| React Component | Flutter Screen/Widget | Status |
|-----------------|----------------------|--------|
| `Login.tsx` | `login_screen.dart` | ✅ |
| `Register.tsx` | `register_screen.dart` | ✅ |
| `SyncHub.tsx` | `sync_hub_screen.dart` | ✅ Created |
| `TenantDashboard.tsx` | `tenant_dashboard_screen.dart` | ✅ Created |
| `LandlordDashboard.tsx` | `landlord_dashboard_screen.dart` | ✅ Created |
| `LandlordFinance.tsx` | `landlord_finance_screen.dart` | ✅ Created |
| `ChoreScheduler.tsx` | `chore_scheduler_screen.dart` | ✅ Created |
| `MaintenanceManager.tsx` | `maintenance_list_screen.dart` | ✅ Created |
| `CommunityBoardPage.tsx` | `community_board_screen.dart` | ⏳ Pending |
| `GamificationHub.tsx` | `gamification_hub_screen.dart` | ⏳ Pending |
| `ScoreDetail.tsx` | `honor_detail_screen.dart` | ⏳ Pending |
| `BalanceCard.tsx` | `balance_card.dart` | ✅ Created |
| `SummaryCards.tsx` | `summary_cards.dart` | ✅ Created |
| `CalendarWidget.tsx` | `calendar_widget.dart` | ✅ Created |
| `BottomNavBar.tsx` | `tenant_bottom_nav.dart` | ⏳ Pending |
| `LandlordBottomNavBar.tsx` | `landlord_bottom_nav.dart` | ⏳ Pending |
| `HonorLevelBadge.tsx` | `honor_level_badge.dart` | ⏳ Pending |
| `TrustFactorIndicator.tsx` | `trust_factor_indicator.dart` | ⏳ Pending |

---

## Implementation Priority (MVP)

### Sprint 1: Core Infrastructure ✅ COMPLETE
1. ✅ Phase 1: Renaming
2. ✅ Phase 2: Auth with role selection
3. ⏳ Phase 5: Basic routing

### Sprint 2: Tenant MVP 🔨 IN PROGRESS
1. ✅ SyncHubScreen (created)
2. ✅ TenantDashboardScreen (created)
3. ⏳ Honor System basics (5-tier levels)
4. ⏳ Bottom navigation

### Sprint 3: Landlord MVP
1. ✅ LandlordDashboardScreen (created)
2. ✅ PropertyPulseScreen (created)
3. ✅ LandlordFinanceScreen (created)
4. ✅ PortfolioScreen (created)

### Sprint 4: Chores & Maintenance
1. ✅ ChoreSchedulerScreen (created)
2. ✅ MaintenanceListScreen (created)
3. ⏳ Database tables for both

### Sprint 5: Honor System & Community
1. ⏳ Honor System implementation (Report, Tribunal, Redemption)
2. ⏳ CommunityBoardScreen
3. ⏳ Gamification basics

### Sprint 6: Polish & Testing
1. ⏳ Final UI polish
2. ⏳ Integration tests
3. ⏳ Performance optimization

---

*Last Updated: January 22, 2026*
*Updated: Honor System integration, Progress tracking added*
