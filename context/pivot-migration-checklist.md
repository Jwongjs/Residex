# Residex Pivot & Migration Checklist

**Created:** January 18, 2026
**Purpose:** Complete migration from SplitLah Bill Splitter to Residex Super App

---

> **IMPORTANT: See the comprehensive guide for full details:**
> - **`residex-full-migration-checklist.md`** - Complete guide with Tenant/Landlord dual-role system
> - **`phase3-database-schema.md`** - Detailed database table definitions and DAOs
>
> **Reference Materials:**
> - React UI: `D:\Projects\Residex\Codes\UI Reference\residex ui`
> - Screenshots: `D:\Projects\Residex\Codes\UI Reference\Screenshots`

---

## App Architecture: Dual Role System

The app has **two distinct user experiences**:

| Role | Home Screen | Bottom Nav | Key Features |
|------|-------------|------------|--------------|
| **Tenant** | SyncHub | Dashboard \| Sync \| Community | Bills, Chores, Scores, Community |
| **Landlord** | Asset Command | Overview \| Finance \| Properties \| AI | Maintenance, Finance, Tenants, AI Tools |

---

## Phase 1: Naming & Branding Changes

### 1.1 Code Renaming (BillSplitterApp → ResidexApp)

- [ ] **lib/main.dart**
  - Line 76: Change `child: const BillSplitterApp(),` → `child: const ResidexApp(),`
  - Line 81: Change `class BillSplitterApp` → `class ResidexApp`
  - Line 82: Change `const BillSplitterApp({super.key});` → `const ResidexApp({super.key});`

- [ ] **lib/features/auth/presentation/screens/new_splash_screen.dart**
  - Line 200: Change `'SplitLah',` → `'Residex',`

- [ ] **lib/features/auth/presentation/screens/splash_screen.dart**
  - Line 63: Update comment from `SplitLahLoader` → `ResidexLoader`

- [ ] **test/widget_test.dart**
  - Line 16: Change `const BillSplitterApp()` → `const ResidexApp()`

### 1.2 Verify Build After Renaming
- [ ] Run `flutter analyze` - should show 0 errors
- [ ] Run `flutter build apk --debug` - should build successfully

---

## Phase 2: Directory Restructuring

### 2.1 Current Feature Structure
```
lib/features/
├── auth/           # Keep - authentication screens
├── bills/          # Keep - bill splitting (core feature)
├── property/       # Keep - renamed from "groups"
└── users/          # Keep - user management
```

### 2.2 New Features to Add (per Residex spec)
```
lib/features/
├── auth/           # Existing
├── bills/          # Existing (Bill Splitter)
├── property/       # Existing
├── users/          # Existing
├── chores/         # NEW - Chore Scheduler
├── maintenance/    # NEW - Maintenance Tickets
├── handover/       # NEW - Digital Handover + Ghost Overlay
├── scores/         # NEW - Dual Score System
├── community/      # NEW - Community Board
└── dashboard/      # NEW - Central Dashboard Hub
```

### 2.3 Create New Feature Directories
For each new feature, create this structure:
```
feature_name/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```

- [ ] Create `lib/features/chores/` directory structure
- [ ] Create `lib/features/maintenance/` directory structure
- [ ] Create `lib/features/handover/` directory structure
- [ ] Create `lib/features/scores/` directory structure
- [ ] Create `lib/features/community/` directory structure
- [ ] Create `lib/features/dashboard/` directory structure

---

## Phase 3: Database Schema Extension

### 3.1 Current Tables (Drift/SQLite)
- `users` - User profiles
- `groups` - Properties/units
- `bills` - Bill records
- `receipt_items` - Bill line items

### 3.2 New Tables Required

#### Chore Scheduler Tables
- [ ] `chores` - Chore definitions
  - id, property_id, name, description, frequency, created_at
- [ ] `chore_assignments` - Who does what chore
  - id, chore_id, user_id, due_date, completed_at, status
- [ ] `chore_rotations` - Rotation schedules
  - id, chore_id, rotation_order, current_index

#### Maintenance Ticket Tables
- [ ] `maintenance_tickets` - Ticket records
  - id, property_id, reporter_id, title, description, category, priority, status, created_at, resolved_at
- [ ] `ticket_comments` - Comments/updates on tickets
  - id, ticket_id, user_id, content, created_at
- [ ] `ticket_attachments` - Photos/documents
  - id, ticket_id, file_path, file_type, created_at

#### Digital Handover Tables
- [ ] `handover_sessions` - Handover events
  - id, property_id, outgoing_user_id, incoming_user_id, status, created_at, completed_at
- [ ] `handover_items` - Items to hand over
  - id, session_id, category, item_name, condition, notes, photo_before, photo_after
- [ ] `ghost_overlays` - Reference photos for comparison
  - id, property_id, room_name, overlay_image_path, created_at

#### Score System Tables
- [ ] `resident_scores` - Individual resident scores
  - id, user_id, property_id, score, last_updated
- [ ] `unit_scores` - Overall unit/property scores
  - id, property_id, score, last_updated
- [ ] `score_events` - Score change history
  - id, user_id, property_id, event_type, points, reason, created_at

#### Community Board Tables
- [ ] `community_posts` - Community announcements/posts
  - id, property_id, user_id, title, content, post_type, created_at
- [ ] `post_reactions` - Likes/reactions
  - id, post_id, user_id, reaction_type, created_at
- [ ] `post_comments` - Comments on posts
  - id, post_id, user_id, content, created_at

### 3.3 Database Migration Steps
- [ ] Add new table definitions to `lib/data/database/app_database.dart`
- [ ] Create DAOs for each new table
- [ ] Increment database schema version
- [ ] Add migration scripts for existing users
- [ ] Test migration with existing data

---

## Phase 4: Navigation & Routing Updates

### 4.1 Update GoRouter Configuration
File: `lib/core/router/app_router.dart`

- [ ] Add routes for new features:
  - `/chores` - Chore scheduler main screen
  - `/chores/create` - Create new chore
  - `/chores/:id` - Chore detail
  - `/maintenance` - Maintenance tickets list
  - `/maintenance/create` - Create ticket
  - `/maintenance/:id` - Ticket detail
  - `/handover` - Handover sessions
  - `/handover/create` - Start new handover
  - `/handover/:id` - Handover detail with ghost overlay
  - `/scores` - Score dashboard
  - `/community` - Community board
  - `/community/post/:id` - Post detail

### 4.2 Update Bottom Navigation
- [ ] Update dashboard to show new feature modules
- [ ] Create feature cards/tiles for each module
- [ ] Implement navigation between features

---

## Phase 5: Core Feature Implementation

### 5.1 Chore Scheduler
- [ ] Create chore entity and model
- [ ] Implement chore repository
- [ ] Build chore list screen
- [ ] Build chore creation form
- [ ] Implement rotation logic
- [ ] Add notifications for due chores

### 5.2 Maintenance Tickets
- [ ] Create ticket entity and model
- [ ] Implement ticket repository
- [ ] Build ticket list screen with filters
- [ ] Build ticket creation form with photo upload
- [ ] Implement status workflow (Open → In Progress → Resolved)
- [ ] Add push notifications for updates

### 5.3 Digital Handover
- [ ] Create handover entity and model
- [ ] Implement handover repository
- [ ] Build handover session screen
- [ ] Implement camera integration for photos
- [ ] Build ghost overlay comparison view
- [ ] Create handover checklist UI
- [ ] Generate handover report PDF

### 5.4 Dual Score System
- [ ] Create score entities (resident + unit)
- [ ] Implement score calculation logic
- [ ] Build score dashboard widget
- [ ] Create score history view
- [ ] Implement score events tracking
- [ ] Add gamification elements (badges, achievements)

### 5.5 Community Board
- [ ] Create post entity and model
- [ ] Implement post repository
- [ ] Build community feed screen
- [ ] Build post creation form
- [ ] Implement reactions and comments
- [ ] Add post categories/filters

---

## Phase 6: Firebase Integration (Future)

### 6.1 Firebase Setup
- [ ] Create Firebase project
- [ ] Add Firebase to Flutter project
- [ ] Configure Android (google-services.json)
- [ ] Configure iOS (GoogleService-Info.plist)

### 6.2 Firebase Features
- [ ] Firebase Authentication (email, Google, Apple)
- [ ] Cloud Firestore (remote database sync)
- [ ] Firebase Storage (photos, documents)
- [ ] Firebase Cloud Messaging (push notifications)
- [ ] Firebase Analytics

---

## Phase 7: Testing & Quality

### 7.1 Unit Tests
- [ ] Test score calculation logic
- [ ] Test chore rotation logic
- [ ] Test handover workflow
- [ ] Test database migrations

### 7.2 Widget Tests
- [ ] Test new feature screens
- [ ] Test navigation flows
- [ ] Test form validations

### 7.3 Integration Tests
- [ ] Test end-to-end chore creation
- [ ] Test end-to-end ticket workflow
- [ ] Test handover process

---

## Phase 8: Final Cleanup

### 8.1 Remove Legacy Code
- [ ] Remove any remaining "SplitLah" references
- [ ] Remove unused bill splitter-only components
- [ ] Clean up unused imports

### 8.2 Documentation
- [ ] Update README.md
- [ ] Update project-memory.md
- [ ] Document new features
- [ ] Create user guide

### 8.3 App Store Preparation
- [ ] Update app name in pubspec.yaml
- [ ] Update app icon
- [ ] Update splash screen assets
- [ ] Prepare store listing screenshots

---

## Quick Reference: Files Modified in Phase 1

| File | Line(s) | Change |
|------|---------|--------|
| `lib/main.dart` | 76, 81, 82 | `BillSplitterApp` → `ResidexApp` |
| `lib/features/auth/presentation/screens/new_splash_screen.dart` | 200 | `'SplitLah'` → `'Residex'` |
| `lib/features/auth/presentation/screens/splash_screen.dart` | 63 | Comment update |
| `test/widget_test.dart` | 16 | `BillSplitterApp` → `ResidexApp` |

---

## Notes

- **Priority:** Phase 1 (renaming) should be completed first before any new feature work
- **Database:** Schema changes require careful migration planning to preserve existing data
- **Modular Approach:** Each feature module can be developed independently
- **KitaHack Deadline:** 6 weeks - prioritize MVP features first

---

*Last Updated: January 18, 2026*
