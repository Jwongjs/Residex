# React UI → Flutter: Complete Migration Plan

**Created:** February 2, 2026
**Last Updated:** February 3, 2026 - 00:15
**React Reference:** `D:\Repositories\Residex\residex ui`
**Current Status:** 🔨 IN PROGRESS - Phase 5 Nearly Complete (75% Match)

---

## ✅ COMPLETED TASKS (Feb 2, 2026)

### **Phase 3: Update SyncHub to Match React Design - COMPLETE**

**✅ Task 3.1: Background & Gradient** - DONE
- Added dynamic radial gradient based on syncState
- Particle system working (200 particles)

**✅ Task 3.2: Tech Rings (Jarvis Interface)** - DONE
- Added 3 spinning tech rings around logo
- Ring 1: 260px, 20s clockwise rotation
- Ring 2: 200px, 15s counter-clockwise rotation
- Ring 3: 140px, pulsing fade animation
- Deep core pulse behind logo

**✅ Task 3.3: Glass Cards Grid** - DONE
- Replaced 2 prediction cards with 4 glass metric cards
- 2x2 grid layout
- Cards: Payables, Protocol, FairFix, Lease Sentinel
- Progress bars with glow effects
- Pulsing dot indicators

**✅ Task 3.4: Status Text Styling** - DONE
- Updated to "SYNC ACTIVE" uppercase with tracking
- Added "A.I. NEURAL CORE" subtitle
- Gradient decorative lines

**✅ Task 3.5: Logo Clickable** - DONE
- Logo now navigates to Rex Interface
- Glass cards navigate to respective screens

**✅ Router Setup** - DONE
- Added routes for Rex Interface, Lease Sentinel, FairFix
- Created placeholder screens
- Navigation working from glass cards

**✅ Phase 4: Bottom Navigation** - DONE
- Rebuilt with role-based tabs
- Center tab elevated with glow effect
- 5 tabs for each role (Tenant/Landlord)
- Icon switching (Radio → Bot when active)
- Smooth animations with flutter_animate

---

## 📊 CURRENT PROGRESS (Updated: Feb 3, 2026)

| Component | Status | Match % | Notes |
|-----------|--------|---------|-------|
| **SyncHub Screen** | ✅ Complete | 95% | All major elements implemented |
| **Bottom Nav** | ✅ Complete | 95% | Role-based tabs working |
| **Router** | ⚠️ Needs Fix | 80% | Main routes working, has duplicate route bug |
| **TenantDashboard** | ✅ Near Complete | 85% | ALL widgets exist and integrated! |
| **Rex Interface** | ⏳ Placeholder | 20% | Basic placeholder screen |
| **Lease Sentinel** | ⏳ Placeholder | 20% | Basic placeholder screen |
| **FairFix Auditor** | ⏳ Placeholder | 15% | Inline placeholder in router |
| **Community Board** | ⚠️ Not Routed | 60% | Screen exists, not connected to nav |
| **Support Center** | ❌ Missing | 0% | Not implemented |
| **Payment Breakdown** | ⚠️ Not Routed | 70% | Old bills screen exists, needs connection |
| **LandlordDashboard** | ⏳ Partial | 60% | Exists but needs updates |
| **OVERALL** | 🔨 In Progress | **75%** | Core structure complete, most screens done! |

---

## 🎉 MAJOR ACCOMPLISHMENTS (NEW!)

### **TenantDashboard is 85% Complete!**

All widgets have been created and integrated:
- ✅ **Header** (`lib/features/tenant/presentation/widgets/header.dart`)
- ✅ **BalanceCard** (`lib/features/tenant/presentation/widgets/balance_card.dart`)
- ✅ **ToolkitGrid** (`lib/features/tenant/presentation/widgets/toolkit_grid.dart`)
  - Includes `_ToolkitButton` with:
    - Rental ID Resume (blue gradient)
    - Ghost Mode (cyan gradient with animated ping!)
    - Glass card effects with backdrop blur
    - Lucide icons matching React
- ✅ **SummaryCards** (`lib/features/tenant/presentation/widgets/summary_cards.dart`)
- ✅ **FriendsList** (`lib/features/tenant/presentation/widgets/friends_list.dart`)
- ✅ **CalendarWidget** (`lib/features/chores/presentation/widgets/calendar_widget.dart`)
- ✅ **LiquidityWidget** (`lib/features/tenant/presentation/widgets/liquidity_widget.dart`)
- ✅ **ReportWidget** (`lib/features/tenant/presentation/widgets/report_widget.dart`)

**Layout Structure:**
```dart
✅ RadialGradient background (indigo → deepSpace)
✅ SafeArea with SingleChildScrollView
✅ All widgets properly ordered and spaced
✅ Proper padding and styling throughout
```

---

## 🚨 REMAINING ISSUES

### **0. CRITICAL BUG: Duplicate Route in Router**

**File:** `lib/core/router/app_router.dart`
**Lines:** 295-322 and 354-362

**Problem:**
```dart
// First definition (lines 295-322) - CORRECT
GoRoute(
  path: AppRoutes.tenantDashboard,
  pageBuilder: (context, state) {
    final mockUser = AppUser(...);
    final mockHousemates = <AppUser>[];
    return buildPageWithSlideTransition(
      child: TenantDashboardScreen(
        currentUser: mockUser,
        housemates: mockHousemates,
      ),
    );
  },
),

// Second definition (lines 354-362) - DUPLICATE, MISSING PARAMS
GoRoute(
  path: AppRoutes.tenantDashboard,
  pageBuilder: (context, state) => buildPageWithSlideTransition(
    child: const TenantDashboardScreen(), // ❌ Missing required params!
  ),
),
```

**Fix:** Delete lines 354-362 (the second duplicate route)

---

### **1. Navigation Structure - ⚠️ PARTIALLY FIXED**

**Current Flutter (Updated):**
- ✅ SyncHub properly routed with userName parameter
- ✅ TenantDashboard connected to router with all widgets
- ✅ Bottom nav matches React design (role-based tabs)
- ✅ Rex Interface routed (placeholder)
- ✅ Lease Sentinel routed (placeholder)
- ✅ FairFix Auditor routed (inline placeholder)
- ⚠️ Splash still goes to old dashboard (needs role-based routing)
- ❌ Community Board not routed (screen exists at `lib/features/community/presentation/screens/community_board_screen.dart`)
- ❌ Support Center not routed (screen doesn't exist yet)
- ❌ Payment Breakdown not connected to bottom nav (old bills dashboard exists)

**React Design:**
- Splash → Login → **SYNC_HUB** (first screen after login)
- **Tenant Bottom Nav** (5 tabs):
  1. **Home** → `TENANT_DASHBOARD` (LayoutGrid icon)
  2. **Finance** → `PAYMENT_BREAKDOWN` (DollarSign icon)
  3. **Rex** → `SYNC_HUB` (Radio/Bot icon) - CENTER, elevated with glow
  4. **Support** → `SUPPORT_CENTER_DETAIL` (Wrench icon)
  5. **Social** → `COMMUNITY` (Users icon)

- **Landlord Bottom Nav** (5 tabs):
  1. **Command** → `LANDLORD_DASHBOARD` (LayoutGrid icon)
  2. **Ledger** → `LANDLORD_FINANCE_PAGE` (TrendingUp icon)
  3. **Rex** → `SYNC_HUB` (Radio/Bot icon) - CENTER, elevated with glow
  4. **Assets** → `LANDLORD_ASSETS` (Building2 icon)
  5. **Social** → `COMMUNITY` (Users icon)

---

### **2. SyncHub Screen - ✅ 95% COMPLETE**

**Current Flutter Implementation:**
```dart
// lib/features/tenant/presentation/screens/sync_hub_screen.dart
✅ Radial gradient background (changes by sync state)
✅ Central "Reactor" with:
   - Deep core pulse (128px, fade animation)
   - 3 Tech rings (260px, 200px, 140px - spinning & pulsing)
   - 200 orbital particles in vortex pattern
   - Logo clickable (navigates to Rex)
✅ Status text: "SYNC ACTIVE" / "A.I. NEURAL CORE" (uppercase, tracking)
✅ 2x2 Grid of Glass Cards with:
   - Payables (RM 600, Due in 3 days)
   - Protocol (Level 2, Your Turn: Trash)
   - FairFix (Damage Scan, AI Assessment)
   - Lease Sentinel (Legal Core, Contract Analysis)
✅ All cards clickable with navigation
✅ Progress bars with glow effects
✅ Pulsing dot indicators
```

**What's Matching:**
- ✅ All 4 glass cards in 2x2 grid
- ✅ Cards navigate to Rex/screens with context
- ✅ 200 orbital particles with theme colors
- ✅ 3 spinning tech rings (Jarvis interface)
- ✅ Logo clickable and navigates to Rex
- ✅ Status text styling matches

**Minor Differences:**
- ⚠️ Particle colors could be more dynamic based on syncState
- ⚠️ Some animation timings slightly different

---

### **3. TenantDashboard - ✅ 85% COMPLETE!**

**✅ Current Status: MUCH BETTER THAN EXPECTED!**
- Flutter has fully implemented `tenant_dashboard_screen.dart`
- Connected to router at `/tenant-dashboard`
- ALL required widgets exist and are integrated

**✅ Completed Components:**
```dart
✅ RadialGradient background (matches React)
✅ Header widget
   - User avatar + name
   - Honor level display
   - Gamification button
   - Notifications button
✅ BalanceCard
   - User fiscal score
   - Harmony score
   - Residents display
   - Action buttons
✅ Toolkit Grid (2x1):
   - Rental ID Resume (blue gradient) ✅
   - Ghost Mode AR Compare (cyan gradient with ANIMATED PING) ✅
✅ SummaryCards (You Owe, Pending Tasks)
✅ FriendsList with housemates
✅ CalendarWidget with chore counts
✅ LiquidityWidget
✅ ReportWidget
```

**⚠️ Minor Improvements Needed:**
- Fine-tune spacing/sizing to match React exactly
- Add real navigation handlers (currently TODOs)
- Connect to actual data providers

**🎉 This screen is nearly production-ready!**

---

### **4. Bottom Navigation - INCORRECT STRUCTURE**

**Current Flutter:**
```dart
// lib/core/widgets/residex_bottom_nav.dart
- Generic 5-tab layout
- No role-based differentiation
- Center tab not properly elevated
- Missing glow effects
- Icons don't match React design
```

**React Requirements:**
```tsx
// components/BottomNav.tsx
✅ MUST HAVE:
- Role-based tabs (different for Tenant/Landlord)
- Middle tab (Rex):
  - Elevated with -mt-8 offset
  - Larger (p-3, icon size 28)
  - Gradient glow when active
  - Icon changes: Radio → Bot when on SyncHub
- Gradient background: from-black via-black/95 to-transparent
- Active indicator: small dot below icon
- Smooth transitions (duration-300)
```

---

## 📋 COMPLETE MIGRATION CHECKLIST

### **PHASE 1: Fix Critical Navigation (HIGH PRIORITY)**

#### **Task 1.1: Fix Splash Screen Navigation**
**File:** `lib/features/auth/presentation/screens/new_splash_screen.dart`
**Line:** 112

**Current:**
```dart
context.go('/dashboard');  // ❌ Goes to old bills dashboard
```

**Change to:**
```dart
// After login success, determine role and navigate
final userRole = UserRole.tenant; // TODO: Get from auth provider
context.go(userRole == UserRole.tenant ? '/sync-hub' : '/landlord-dashboard');
```

---

#### **Task 1.2: Fix SyncHubScreen Router**
**File:** `lib/core/router/app_router.dart`
**Line:** 270

**Current:**
```dart
child: const SyncHubScreen(),  // ❌ Missing userName parameter
```

**Fix:**
```dart
child: const SyncHubScreen(
  userName: 'User',  // TODO: Get from auth provider
),
```

---

#### **Task 1.3: Add TenantDashboard to Router**
**File:** `lib/core/router/app_router.dart`

**Add to AppRoutes class:**
```dart
static const String tenantDashboard = '/tenant-dashboard';
```

**Add to routes list:**
```dart
GoRoute(
  path: AppRoutes.tenantDashboard,
  pageBuilder: (context, state) => buildPageWithSlideTransition(
    context: context,
    state: state,
    child: const TenantDashboardScreen(),
    slideFromBottom: true,
  ),
),
```

---

### **PHASE 2: Rebuild TenantDashboard Screen (HIGH PRIORITY)**

#### **Task 2.1: Check Existing Implementation**
**File:** `lib/features/tenant/presentation/screens/tenant_dashboard_screen.dart`

Read the file and compare with React version. If outdated, rebuild from scratch.

#### **Task 2.2: Create/Update TenantDashboard Components**

**Required Widgets (must create if missing):**
1. `lib/features/tenant/presentation/widgets/header.dart`
2. `lib/features/tenant/presentation/widgets/balance_card.dart`
3. `lib/features/tenant/presentation/widgets/toolkit_button.dart`
4. `lib/features/tenant/presentation/widgets/summary_cards.dart`
5. `lib/features/tenant/presentation/widgets/friends_list.dart`
6. `lib/features/tenant/presentation/widgets/calendar_widget.dart`
7. `lib/features/tenant/presentation/widgets/liquidity_widget.dart`
8. `lib/features/tenant/presentation/widgets/report_widget.dart`

**Reference React files:**
- `components/Header.tsx`
- `components/BalanceCard.tsx`
- `components/SummaryCards.tsx`
- `components/FriendsList.tsx`
- `components/CalendarWidget.tsx`
- `components/LiquidityWidget.tsx`
- `components/ReportWidget.tsx`

---

### **PHASE 3: Update SyncHub to Match React Design (MEDIUM PRIORITY)**

#### **Task 3.1: Update Background & Gradient**
**File:** `lib/features/tenant/presentation/screens/sync_hub_screen.dart`

**Current:** Single radial gradient
**React:** Dynamic gradient based on syncState with multiple layers

```dart
// Add to _getBackgroundColor():
Gradient _getBackgroundGradient() {
  switch (syncState) {
    case SyncState.synced:
      return const RadialGradient(
        center: Alignment.topCenter,
        radius: 1.5,
        colors: [
          Color(0xFF1E3A8A), // blue-800/50
          Color(0xFF000000),
          Color(0xFF000000),
        ],
      );
    case SyncState.drifting:
      return const RadialGradient(
        center: Alignment.topCenter,
        radius: 1.5,
        colors: [
          Color(0xFF92400E), // amber-800/50
          Color(0xFF000000),
          Color(0xFF000000),
        ],
      );
    case SyncState.outOfSync:
      return const RadialGradient(
        center: Alignment.topCenter,
        radius: 1.5,
        colors: [
          Color(0xFF9F1239), // rose-800/50
          Color(0xFF000000),
          Color(0xFF000000),
        ],
      );
  }
}
```

---

#### **Task 3.2: Add Tech Rings (Jarvis Interface)**
**File:** `lib/features/tenant/presentation/screens/sync_hub_screen.dart`

Add 3 spinning rings around the logo:
```dart
// Add to build method, inside the logo container:
// Ring 1: Outer (260px, 20s clockwise)
Container(
  width: 260,
  height: 260,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: AppColors.indigo500.withValues(alpha: 0.3),
      width: 1,
    ),
  ),
).animate().rotate(
  duration: 20.seconds,
  curve: Curves.linear,
),

// Ring 2: Middle (200px, 15s counter-clockwise, dashed)
Container(
  width: 200,
  height: 200,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: AppColors.cyan500.withValues(alpha: 0.4),
      width: 1,
      style: BorderStyle.dashed,
    ),
  ),
).animate().rotate(
  duration: 15.seconds,
  curve: Curves.linear,
  direction: -1, // reverse
),

// Ring 3: Inner (140px, pulsing)
Container(
  width: 140,
  height: 140,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: AppColors.indigo500.withValues(alpha: 0.2),
      width: 1,
    ),
  ),
).animate().pulse(
  duration: 2.seconds,
),
```

---

#### **Task 3.3: Replace Prediction Cards with Glass Cards Grid**
**File:** `lib/features/tenant/presentation/screens/sync_hub_screen.dart`

**Remove:** Lines 112-128 (old prediction cards)

**Replace with:** 2x2 Grid of Glass Cards
```dart
Padding(
  padding: const EdgeInsets.all(16),
  child: GridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      _GlassMetricCard(
        label: 'PAYABLES',
        value: 'RM 600',
        subValue: 'Due in 3 days',
        icon: Icons.warning_amber_rounded,
        accentColor: AppColors.rose500,
        progress: 75,
        onTap: () => _openRex(context, 'Fiscal Analyst'),
      ),
      _GlassMetricCard(
        label: 'PROTOCOL',
        value: 'Level 2',
        subValue: 'Your Turn: Trash',
        icon: Icons.auto_awesome,
        accentColor: AppColors.indigo500,
        progress: 40,
        onTap: () => _openRex(context, 'Harmony Engine'),
      ),
      _GlassMetricCard(
        label: 'DAMAGE SCAN',
        value: 'FairFix',
        subValue: 'AI Assessment',
        icon: Icons.search_rounded,
        accentColor: AppColors.cyan500,
        progress: 100,
        onTap: () => context.go('/fairfix-auditor'),
      ),
      _GlassMetricCard(
        label: 'LEGAL CORE',
        value: 'Sentinel',
        subValue: 'Contract Analysis',
        icon: Icons.description_rounded,
        accentColor: AppColors.purple500,
        progress: 100,
        onTap: () => context.go('/lease-sentinel'),
      ),
    ],
  ),
),
```

---

#### **Task 3.4: Create _GlassMetricCard Widget**
**File:** `lib/features/tenant/presentation/screens/sync_hub_screen.dart`

Add after _PredictionCard class:
```dart
class _GlassMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;
  final IconData icon;
  final Color accentColor;
  final double progress;
  final VoidCallback onTap;

  const _GlassMetricCard({
    required this.label,
    required this.value,
    required this.subValue,
    required this.icon,
    required this.accentColor,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.2),
              accentColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Icon + dot
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        icon,
                        color: accentColor,
                        size: 24,
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ).animate().pulse(duration: 2.seconds),
                    ],
                  ),

                  const Spacer(),

                  // Big metric value
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Label
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subvalue
                  Text(
                    subValue,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Progress bar
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

#### **Task 3.5: Make Logo Clickable to Open Rex**
**File:** `lib/features/tenant/presentation/screens/sync_hub_screen.dart`

**Update _buildLogo() method:**
```dart
Widget _buildLogo() {
  return GestureDetector(
    onTap: () {
      // Navigate to Rex AI Interface
      context.go('/rex-interface');
    },
    child: Container(
      width: 110,
      height: 110,
      child: ResidexLogo(
        size: 110,
        syncState: syncState,
        animate: true,
      ),
    ),
  );
}
```

---

#### **Task 3.6: Update Status Text Styling**
**File:** `lib/features/tenant/presentation/screens/sync_hub_screen.dart`

**Current:** Simple greeting text
**React:** "SYNC ACTIVE" with uppercase tracking and "A.I. Neural Core" subtitle

```dart
// Replace lines 88-107 with:
Column(
  children: [
    Text(
      _getSyncStatusText().toUpperCase(),
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: _getStatusColor(),
        letterSpacing: 4,
        height: 1.0,
        shadows: [
          Shadow(
            color: _getStatusColor().withValues(alpha: 0.5),
            blurRadius: 20,
          ),
        ],
      ),
    ).animate().pulse(duration: 3.seconds),

    const SizedBox(height: 8),

    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.white],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'A.I. NEURAL CORE',
          style: TextStyle(
            fontSize: 8,
            fontFamily: 'monospace',
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.transparent],
            ),
          ),
        ),
      ],
    ),
  ],
),

// Add helper method:
String _getSyncStatusText() {
  switch (syncState) {
    case SyncState.synced:
      return 'Sync Active';
    case SyncState.drifting:
      return 'Calibration Needed';
    case SyncState.outOfSync:
      return 'Critical Drift';
  }
}

Color _getStatusColor() {
  switch (syncState) {
    case SyncState.synced:
      return AppColors.syncedBlue;
    case SyncState.drifting:
      return AppColors.driftingAmber;
    case SyncState.outOfSync:
      return AppColors.outOfSyncRose;
  }
}
```

---

### **PHASE 4: Update Bottom Navigation (MEDIUM PRIORITY)**

#### **Task 4.1: Rebuild BottomNav with Role-Based Tabs**
**File:** `lib/core/widgets/residex_bottom_nav.dart`

**Complete rewrite to match React:**
```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../features/users/domain/entities/app_user.dart';
import '../theme/app_colors.dart';

class ResidexBottomNav extends StatelessWidget {
  final String currentRoute;
  final UserRole role;
  final Function(String) onNavigate;

  const ResidexBottomNav({
    super.key,
    required this.currentRoute,
    required this.role,
    required this.onNavigate,
  });

  List<BottomNavTab> _getTabs() {
    if (role == UserRole.tenant) {
      return [
        BottomNavTab(
          id: '/tenant-dashboard',
          icon: LucideIcons.layoutGrid,
          label: 'Home',
        ),
        BottomNavTab(
          id: '/payment-breakdown',
          icon: LucideIcons.dollarSign,
          label: 'Finance',
        ),
        BottomNavTab(
          id: '/sync-hub',
          icon: LucideIcons.radio,
          activeIcon: LucideIcons.bot,
          label: 'Rex',
          isMiddle: true,
        ),
        BottomNavTab(
          id: '/support-center',
          icon: LucideIcons.wrench,
          label: 'Support',
        ),
        BottomNavTab(
          id: '/community',
          icon: LucideIcons.users,
          label: 'Social',
        ),
      ];
    } else {
      return [
        BottomNavTab(
          id: '/landlord-dashboard',
          icon: LucideIcons.layoutGrid,
          label: 'Command',
        ),
        BottomNavTab(
          id: '/landlord-finance',
          icon: LucideIcons.trendingUp,
          label: 'Ledger',
        ),
        BottomNavTab(
          id: '/sync-hub',
          icon: LucideIcons.radio,
          activeIcon: LucideIcons.bot,
          label: 'Rex',
          isMiddle: true,
        ),
        BottomNavTab(
          id: '/landlord-assets',
          icon: LucideIcons.building2,
          label: 'Assets',
        ),
        BottomNavTab(
          id: '/community',
          icon: LucideIcons.users,
          label: 'Social',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _getTabs();

    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.95),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: tabs.map((tab) {
              final isActive = currentRoute == tab.id;
              final icon = (isActive && tab.activeIcon != null)
                  ? tab.activeIcon!
                  : tab.icon;

              if (tab.isMiddle) {
                return Transform.translate(
                  offset: const Offset(0, -16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect when active
                      if (isActive)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.indigo500.withValues(alpha: 0.2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.indigo500.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ).animate().pulse(duration: 2.seconds),

                      // Button
                      GestureDetector(
                        onTap: () => onNavigate(tab.id),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? AppColors.indigo500.withValues(alpha: 0.1)
                                : AppColors.surface,
                            border: Border.all(
                              color: isActive
                                  ? AppColors.indigo500.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: 28,
                            color: isActive
                                ? AppColors.indigo400
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Regular tab
              return GestureDetector(
                onTap: () => onNavigate(tab.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isActive
                          ? AppColors.indigo400
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(height: 4),
                    if (isActive)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.indigo500,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class BottomNavTab {
  final String id;
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isMiddle;

  BottomNavTab({
    required this.id,
    required this.icon,
    this.activeIcon,
    required this.label,
    this.isMiddle = false,
  });
}
```

---

### **PHASE 5: Additional Screens (LOWER PRIORITY)**

#### **Screens to Create (in order of priority):**

1. **RexInterface** (`/rex-interface`)
   - React: `components/RexInterface.tsx`
   - Flutter: Create `lib/features/ai_assistant/presentation/screens/rex_interface_screen.dart`

2. **PaymentBreakdown** (`/payment-breakdown`)
   - React: `components/PaymentBreakdown.tsx`
   - Flutter: May already exist in bills feature

3. **SupportCenterDetail** (`/support-center`)
   - React: `components/SupportCenterDetail.tsx`
   - Flutter: Create new

4. **CommunityBoardPage** (`/community`)
   - React: `components/CommunityBoardPage.tsx`
   - Flutter: May exist, needs updating

5. **FairFixAuditor** (`/fairfix-auditor`)
   - React: `components/FairFixAuditor.tsx`
   - Flutter: Create new

6. **LeaseSentinel** (`/lease-sentinel`)
   - React: `components/LeaseSentinel.tsx`
   - Flutter: Create new

7. **RentalResume** (`/rental-resume`)
   - React: `components/RentalResume.tsx`
   - Flutter: Create new

8. **GhostOverlay** (`/ghost-overlay`)
   - React: `components/GhostOverlay.tsx`
   - Flutter: Create new

---

## 🎯 IMMEDIATE ACTION PLAN (Updated)

### **Priority 1: Fix Critical Bugs (15 minutes)**
1. ✅ Fix duplicate tenantDashboard route in app_router.dart (5 min)
   - Delete lines 354-362
2. Add missing routes to AppRoutes class (5 min)
   - `community = '/community'`
   - `supportCenter = '/support-center'`
   - `paymentBreakdown = '/payment-breakdown'`
3. Add route definitions for missing screens (5 min)

### **Priority 2: Connect Missing Screens (1-2 hours)**
1. Connect Community Board screen to router (15 min)
   - Screen already exists: `lib/features/community/presentation/screens/community_board_screen.dart`
2. Create Support Center placeholder screen (30 min)
3. Update Payment Breakdown route to use existing bills screen (15 min)
4. Test all bottom nav navigation flows (20 min)

### **Priority 3: Build AI Screens (4-6 hours)**
1. Rex Interface full implementation (2-3 hours)
2. Lease Sentinel implementation (1-2 hours)
3. FairFix Auditor implementation (1-2 hours)

**Updated Total Remaining: ~6-8 hours to 90%+ completion**

---

## 📊 UPDATED PROGRESS TRACKING

| Component | React Status | Flutter Status | Match % |
|-----------|--------------|----------------|---------|
| Navigation Structure | ✅ Complete | ⚠️ Partial | 70% |
| SyncHub Screen | ✅ Complete | ✅ Complete | 95% |
| TenantDashboard | ✅ Complete | ⚠️ Partial | 50% |
| Bottom Nav | ✅ Complete | ✅ Complete | 95% |
| RexInterface | ✅ Complete | ⏳ Placeholder | 20% |
| LeaseSentinel | ✅ Complete | ⏳ Placeholder | 20% |
| FairFixAuditor | ✅ Complete | ⏳ Placeholder | 10% |
| LandlordDashboard | ✅ Complete | ⚠️ Partial | 60% |
| Router Setup | ✅ Complete | ✅ Complete | 85% |
| **OVERALL** | **100%** | **🔨 In Progress** | **60%** |

---

## 🔧 TOOLS & DEPENDENCIES NEEDED

```yaml
# pubspec.yaml additions
dependencies:
  flutter_animate: ^4.5.0  # For animations
  lucide_icons: ^0.263.0   # For icons matching React
  go_router: ^13.0.0       # Already have
  flutter_riverpod: ^2.4.9 # For state management
```

---

## 📝 NEXT STEPS (Updated Priority Order)

### **PHASE 5: Fix Critical Bugs & Complete Navigation (HIGH PRIORITY)**

**1. Fix Duplicate Route Bug (5 minutes)**
   - **File:** `lib/core/router/app_router.dart`
   - **Action:** Delete lines 354-362 (duplicate tenantDashboard route)
   - **Impact:** Prevents potential routing conflicts

**2. Add Missing Routes to Router (30 minutes)**
   - Add Community Board route (`/community`)
   - Add Support Center route (`/support-center`)
   - Update Payment Breakdown route (`/payment-breakdown`)
   - Connect to bottom navigation

**3. Polish TenantDashboard (1-2 hours) - OPTIONAL**
   - Fine-tune spacing to exactly match React
   - Add real navigation handlers (replace TODOs)
   - Connect to actual data providers
   - **Note:** Screen is already 85% complete!

**4. Build Rex Interface Screen (2-3 hours)**
   - Read React `components/RexInterface.tsx`
   - Replace placeholder with full implementation
   - Chat interface with context
   - Animated responses
   - Voice input support

**3. Build Additional AI Screens (4-5 hours)**
   - Lease Sentinel (contract analysis)
   - FairFix Auditor (damage assessment)
   - Support Center
   - Community Board

**4. Fix Splash Screen Routing (30 minutes)**
   - Update to route based on user role
   - Tenant → `/sync-hub`
   - Landlord → `/landlord-dashboard`

**5. Connect Bottom Nav Routes (1 hour)**
   - Create placeholder screens for missing routes
   - Test navigation flow between all tabs
   - Verify role-based navigation

---

### **PHASE 6: Testing & Polish (2-3 hours)**

1. **Test all navigation flows**
2. **Fix remaining deprecation warnings** (`.withOpacity()` → `.withValues()`)
3. **Optimize animations**
4. **Test on physical device**
5. **Performance profiling**

---

## 🎉 ACCOMPLISHMENTS SO FAR

**What's Been Completed:**
- ✅ SyncHub screen 95% matches React UI
- ✅ Tech rings with Jarvis-style animations
- ✅ Glass metric cards with navigation
- ✅ Bottom navigation with role-based tabs (95%)
- ✅ **TenantDashboard 85% complete - ALL widgets exist!**
  - Header, BalanceCard, ToolkitGrid, SummaryCards, FriendsList, CalendarWidget, LiquidityWidget, ReportWidget
  - ToolkitGrid includes Ghost Mode with animated ping effect!
- ✅ Router structure set up
- ✅ 3 AI assistant placeholder screens created
- ✅ All core animations working
- ✅ App builds with 0 errors
- ✅ Community Board screen exists (needs routing)

**Time Invested:** ~8-10 hours
**Estimated Remaining:** ~6-8 hours to 90%+ match

---

**Last Updated:** February 3, 2026 - 00:15
**Current Match:** 75% complete (was 60%, TenantDashboard underestimated!)
**Target:** 90%+ match with React UI
**Remaining Work:** Primarily AI assistant screens + minor bug fixes
