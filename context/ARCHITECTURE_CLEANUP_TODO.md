# Residex App — Architecture Cleanup: 3-Folder Role-Based Restructure
## Goal: `lib/features/` contains ONLY: `tenant/` · `landlord/` · `shared/`
*Revised: February 26, 2026*

---

## Folder Convention (applies everywhere)

After entering `data/`, `domain/`, or `presentation/`, the **next level is always a sublayer**, and the **level after that is a named feature folder** before the file:

```
{role}/
  data/
    datasources/{feature}/file.dart
    models/{feature}/file.dart
    repositories/{feature}/file.dart
  domain/
    entities/{feature}/file.dart
    repositories/{feature}/file.dart
    usecases/{feature}/file.dart
  presentation/
    screens/{feature}/file.dart
    widgets/{feature}/file.dart
    providers/{feature}/file.dart   ← or flat if only 1 provider per feature
```

---

## Feature-to-Role Mapping

| Current Standalone Folder | → Target | Rationale |
|---|---|---|
| `ai_assistant/` | `tenant/` | All 4 AI tools (Rex, FairFix, Sentinel, Logger) are tenant-facing |
| `auth/` | `shared/` | Splash/login/register are pre-role — used by both |
| `bills/` | `tenant/` | Bill splitting is a tenant group feature |
| `chores/` | `tenant/` | Chore scheduling is a tenant household feature |
| `community/` | `shared/` | Community board serves both tenant and landlord |
| `gamification/` | `shared/` | Achievement system spans both roles |
| `honor/` | `tenant/` | Resident honor/reputation is tenant-centric |
| `maintenance/` | `shared/` | Tenant creates tickets, landlord manages — both involved |
| `profile/` | `shared/` | Profile viewing spans both roles |
| `property/` | `landlord/` | Property data layer is landlord-owned infrastructure |
| `scores/` | `tenant/` | Resident scoring is a tenant-centric feature |
| `users/` | `shared/` | User entities/providers are cross-role |

---

## Final Target Directory Tree

```
lib/features/
│
├── shared/
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── maintenance/                    ← ✅ done (note: typo in actual folder name)
│   │   │   │   └── maintenance_local_datasource.dart
│   │   │   └── users/                          ← TODO
│   │   │       └── user_local_datasource.dart
│   │   ├── models/
│   │   │   ├── maintenance/                    ← ✅ done
│   │   │   │   ├── ticket_model.dart
│   │   │   │   ├── ticket_comment_model.dart
│   │   │   │   └── ticket_attachment_model.dart
│   │   │   └── users/                          ← ✅ done
│   │   │       └── app_user_model.dart
│   │   └── repositories/
│   │       ├── maintenance/                    ← ✅ done
│   │       │   └── maintenance_repository.dart
│   │       └── users/                          ← ✅ done
│   │           ├── user_local_datasource.dart
│   │           └── user_repository_impl.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── maintenance/                    ← ✅ done
│   │   │   │   ├── maintenance_ticket.dart
│   │   │   │   ├── ticket_comment.dart
│   │   │   │   └── ticket_attachment.dart
│   │   │   └── user/                           ← ✅ done
│   │   │       └── app_user.dart
│   │   ├── repositories/
│   │   │   ├── maintenance/                    ← ✅ done
│   │   │   │   └── maintenance_repository.dart
│   │   │   └── users/                          ← ✅ done
│   │   │       └── user_repository.dart
│   │   └── usecases/
│   │       └── maintenance/                    ← ✅ done
│   │           ├── create_ticket.dart
│   │           ├── update_ticket.dart
│   │           ├── get_tickets.dart
│   │           └── add_ticket_comment.dart
│   └── presentation/
│       ├── providers/
│       │   ├── users_provider.dart             ← ✅ done (flat OK for single files)
│       │   └── friends_provider.dart           ← ✅ done
│       ├── screens/
│       │   ├── auth/                           ← ✅ done
│       │   │   ├── new_splash_screen.dart
│       │   │   ├── splash_screen.dart
│       │   │   ├── login_screen.dart
│       │   │   └── register_screen.dart
│       │   ├── users/                          ← ✅ done
│       │   │   ├── profile_screen.dart
│       │   │   └── profile_editor_screen.dart
│       │   ├── community/                      ← ✅ done
│       │   │   └── community_board_screen.dart
│       │   ├── gamification/                   ← ✅ done
│       │   │   └── gamification_hub_screen.dart
│       │   └── maintenance/                    ← ✅ done
│       │       ├── maintenance_list_screen.dart
│       │       ├── create_ticket_screen.dart
│       │       └── ticket_detail_screen.dart
│       └── widgets/
│           ├── gamification/                   ← ✅ done
│           │   ├── post_card.dart
│           │   ├── post_type_badge.dart
│           │   ├── reaction_bar.dart
│           │   ├── achievement_card.dart
│           │   ├── badge_widget.dart
│           │   ├── trophy_unlock_overlay.dart
│           │   └── add_friend_modal.dart
│           └── maintenance/                    ← ✅ done
│               ├── attachment_picker.dart
│               ├── priority_badge.dart
│               └── ticket_card.dart
│
├── tenant/
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── bills/                         ← TODO (from bills/data/datasources/)
│   │   │   ├── chores/                        ← TODO (from chores/data/datasources/)
│   │   │   └── scores/                        ← TODO (from scores/data/datasources/)
│   │   ├── models/
│   │   │   ├── bills/                         ← TODO (from bills/data/models/)
│   │   │   ├── chores/                        ← TODO (from chores/data/models/)
│   │   │   └── scores/                        ← TODO (from scores/data/models/)
│   │   └── repositories/
│   │       ├── bills/                         ← TODO (from bills/data/repositories/)
│   │       ├── chores/                        ← TODO (from chores/data/repositories/)
│   │       └── scores/                        ← TODO (from scores/data/repositories/)
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── bills/                         ← TODO (from bills/domain/entities/)
│   │   │   ├── chores/                        ← TODO (from chores/domain/entities/)
│   │   │   └── scores/                        ← TODO (from scores/domain/entities/)
│   │   ├── repositories/
│   │   │   ├── bills/                         ← TODO (from bills/domain/repositories/)
│   │   │   ├── chores/                        ← TODO (from chores/domain/repositories/)
│   │   │   └── scores/                        ← TODO (from scores/domain/repositories/)
│   │   └── usecases/
│   │       ├── bills/                         ← TODO (from bills/domain/usecases/)
│   │       ├── chores/                        ← TODO (from chores/domain/usecases/)
│   │       └── scores/                        ← TODO (from scores/domain/usecases/)
│   └── presentation/
│       ├── providers/
│       │   ├── bills/                         ← TODO (from bills/presentation/providers/)
│       │   │   ├── bills_provider.dart
│       │   │   ├── balance_provider.dart
│       │   │   ├── bill_flow_provider.dart
│       │   │   └── bill_statistics_provider.dart
│       │   ├── chores/                        ← TODO
│       │   │   └── chore_provider.dart
│       │   └── scores/                        ← TODO
│       │       └── score_provider.dart
│       ├── screens/
│       │   ├── home/                          ← TODO (reorganize existing flat screens)
│       │   │   ├── tenant_dashboard_screen.dart
│       │   │   └── sync_hub_screen.dart
│       │   ├── tools/                         ← TODO (reorganize existing flat screens)
│       │   │   ├── support_center_screen.dart
│       │   │   ├── harmony_hub_screen.dart
│       │   │   ├── credit_bridge_screen.dart
│       │   │   ├── rental_resume_screen.dart
│       │   │   ├── rulebook_screen.dart
│       │   │   ├── property_pulse_detail_screen.dart
│       │   │   └── liquidity_screen.dart
│       │   ├── move_in/                       ← TODO (reorganize existing flat screens)
│       │   │   ├── ghost_overlay_screen.dart
│       │   │   ├── move_in_session_screen.dart
│       │   │   └── stewardship_protocol_screen.dart
│       │   ├── chores/                        ← TODO
│       │   │   ├── chore_scheduler_screen.dart   (already in tenant/, just move to subfolder)
│       │   │   └── create_chore_screen.dart      (migrate from chores/)
│       │   ├── scores/                        ← TODO
│       │   │   └── score_detail_screen.dart      (already in tenant/, just move to subfolder)
│       │   ├── bills/                         ← TODO (migrate from bills/)
│       │   │   ├── bill_dashboard_screen.dart
│       │   │   ├── bill_summary_screen.dart
│       │   │   ├── you_owe_screen.dart
│       │   │   ├── owed_to_you_screen.dart
│       │   │   ├── group_bills_screen.dart
│       │   │   └── bill_creation/
│       │   │       ├── assign_items_screen.dart
│       │   │       ├── assign_payment_methods_screen.dart
│       │   │       ├── edit_receipt_screen.dart
│       │   │       ├── new_bill_options_screen.dart
│       │   │       ├── payment_method_choice_screen.dart
│       │   │       ├── scan_camera_screen.dart
│       │   │       ├── select_members_screen.dart
│       │   │       └── select_single_payment_screen.dart
│       │   ├── ai/                            ← TODO (migrate from ai_assistant/)
│       │   │   ├── rex_interface_screen.dart
│       │   │   ├── lazy_logger_screen.dart
│       │   │   ├── fairfix_auditor_screen.dart
│       │   │   └── lease_sentinel_screen.dart
│       │   └── honor/                         ← TODO (migrate from honor/)
│       │       └── honor_history_screen.dart
│       └── widgets/
│           ├── home/                          ← TODO (reorganize existing flat widgets)
│           │   ├── balance_card.dart
│           │   ├── summary_cards.dart
│           │   ├── header.dart
│           │   ├── friends_list.dart
│           │   ├── friend_list.dart
│           │   ├── shared_residents.dart
│           │   ├── property_pulse_widget.dart
│           │   ├── toolkit_button.dart
│           │   └── toolkit_grid.dart
│           ├── tools/                         ← TODO (reorganize existing flat widgets)
│           │   ├── liquidity_widget.dart
│           │   └── report_widget.dart
│           ├── chores/                        ← TODO (reorganize + migrate)
│           │   └── calendar_widget.dart
│           ├── bills/                         ← TODO (migrate from bills/presentation/widgets/)
│           │   ├── bill_filter_modal.dart
│           │   ├── bill_header_card.dart
│           │   ├── bill_list_item.dart
│           │   ├── branching_tree.dart
│           │   ├── breakdown_filter_tabs.dart
│           │   ├── category_filter_chip.dart
│           │   ├── entity_selection_grid.dart
│           │   ├── friends_list_widget.dart
│           │   ├── group_selector_modal.dart
│           │   ├── ledger_summary_cards.dart
│           │   ├── net_amount_card.dart
│           │   ├── participant_payment_card.dart
│           │   └── payment_status_indicator/
│           └── navigation/                    ← TODO (new)
│               └── custom_bottom_nav_bar.dart
│
└── landlord/
    ├── data/
    │   ├── datasources/
    │   │   └── property/                      ← TODO (from property/data/)
    │   ├── models/
    │   │   └── property/                      ← TODO (from property/data/models/)
    │   └── repositories/
    │       └── property/                      ← TODO (from property/data/repositories/)
    ├── domain/
    │   ├── entities/
    │   │   └── property/                      ← TODO (from property/domain/entities/)
    │   ├── repositories/
    │   │   └── property/                      ← TODO (from property/domain/repositories/)
    │   └── usecases/
    │       └── property/                      ← TODO (new)
    └── presentation/
        ├── providers/
        │   └── (existing + from property/presentation/providers/)
        ├── screens/
        │   ├── landlord_dashboard_screen.dart    ← root level (entry shell)
        │   ├── 1-Command/
        │   │   └── landlord_command_screen.dart
        │   ├── 2-Finance/
        │   │   └── landlord_finance_screen.dart
        │   ├── 3-REX/
        │   │   └── landlord_rex_ai_screen.dart
        │   ├── 4-Portfolio/
        │   │   ├── landlord_portfolio_screen.dart
        │   │   └── sub/
        │   │       └── tenant_management_screen.dart
        │   └── 5-Community/
        │       └── landlord_community_screen.dart
        └── widgets/
            ├── AI/
            ├── common/
            ├── layouts/
            └── navigation/
```

---

## PHASE 0 — Quick Fixes

### 0.1 Delete empty stub files
- [x] Delete `lib/features/scores/presentation/screens/score_detail_screen.dart` *(1-line empty file)*
- [x] Delete `lib/features/chores/presentation/screens/chore_scheduler_screen.dart` *(1-line empty file)*

### 0.2 Fix filename with space
- [x] Rename `lib/core/widgets/tenants _shell.dart` → `lib/core/widgets/tenant_shell.dart`
- [x] Update import in `lib/core/router/app_router.dart`:
  - `'../../core/widgets/tenants _shell.dart'` → `'../../core/widgets/tenant_shell.dart'`

### 0.3 Fix class name mismatch in bill_dashboard_screen.dart
- [x] `class DashboardScreen` → `class BillDashboardScreen`
- [x] `const DashboardScreen({super.key})` → `const BillDashboardScreen({super.key})`
- [x] `ConsumerState<DashboardScreen>` → `ConsumerState<BillDashboardScreen>`
- [x] `_DashboardScreenState` → `_BillDashboardScreenState`
- [x] Update both `DashboardScreen()` usages in `app_router.dart` → `BillDashboardScreen()`

### 0.4 Remove flutter_tts (voice feature stripped)
- [ ] Remove `flutter_tts: ^4.2.0` from `pubspec.yaml` dependencies
- [ ] Run `flutter pub get` after removal

### 0.5 Fix typo in shared data folder
- [ ] Rename `lib/features/shared/data/datasources/maintenenance/` → `lib/features/shared/data/datasources/maintenance/`
  *(extra 'e' in the actual folder name on disk)*

### 0.6 Evaluate duplicate landlord widget file
- [ ] Compare `lib/features/landlord/presentation/widgets/revenue_chart.dart`
  vs `lib/features/landlord/presentation/widgets/common/revenue_chart.dart`
  — if identical, delete the outer one and update any imports

---

## PHASE 1 — `shared/` Migration (mostly done)

### 1.1 auth/ → shared/presentation/screens/auth/
- [x] new_splash_screen.dart
- [x] splash_screen.dart
- [x] login_screen.dart
- [x] register_screen.dart
- [x] Router imports updated
- [ ] Delete `lib/features/auth/` folder (verify empty first)

### 1.2 users/ → shared/
- [x] `shared/domain/entities/user/app_user.dart`
- [x] `shared/domain/repositories/users/user_repository.dart`
- [x] `shared/data/models/users/app_user_model.dart`
- [x] `shared/data/repositories/users/user_local_datasource.dart`
- [x] `shared/data/repositories/users/user_repository_impl.dart`
- [x] `shared/presentation/screens/users/profile_screen.dart`
- [x] `shared/presentation/screens/users/profile_editor_screen.dart`
- [x] `shared/presentation/providers/users_provider.dart`
- [x] `shared/presentation/providers/friends_provider.dart`
- [ ] Verify all `import features/users/` references updated across codebase (esp. `app_user.dart`)
- [ ] Delete `lib/features/users/` folder
- [ ] Delete `lib/features/profile/` folder

### 1.3 community/ → shared/presentation/screens/community/
- [x] `shared/presentation/screens/community/community_board_screen.dart`
- [ ] Move any `community/presentation/widgets/` → `shared/presentation/widgets/community/`
- [x] Router import updated
- [ ] Delete `lib/features/community/` folder

### 1.4 gamification/ → shared/presentation/screens/gamification/
- [x] `shared/presentation/screens/gamification/gamification_hub_screen.dart`
- [x] `shared/presentation/widgets/gamification/` (7 widget files)
- [x] Router import updated
- [ ] Delete `lib/features/gamification/` folder

### 1.5 maintenance/ → shared/
- [x] `shared/data/datasources/maintenance/maintenance_local_datasource.dart`
  *(note: folder currently named `maintenenance` — fix with Phase 0.5)*
- [x] `shared/data/models/maintenance/` (3 model files)
- [x] `shared/data/repositories/maintenance/maintenance_repository.dart`
- [x] `shared/domain/entities/maintenance/` (3 entity files)
- [x] `shared/domain/repositories/maintenance/maintenance_repository.dart`
- [x] `shared/domain/usecases/maintenance/` (4 usecase files)
- [x] `shared/presentation/screens/maintenance/maintenance_list_screen.dart`
- [x] `shared/presentation/screens/maintenance/create_ticket_screen.dart`
- [x] `shared/presentation/screens/maintenance/ticket_detail_screen.dart`
- [x] `shared/presentation/widgets/maintenance/` (3 widget files)
- [ ] Verify router imports for maintenance screens updated
- [ ] Delete `lib/features/maintenance/` folder

---

## PHASE 2 — `tenant/` Consolidation

### 2.1 Reorganize existing flat tenant screens into feature subfolders

All 12 existing flat screens in `tenant/presentation/screens/` need to move into subfolders:

**→ screens/home/**
- [ ] Move `tenant_dashboard_screen.dart` → `screens/home/tenant_dashboard_screen.dart`
- [ ] Move `sync_hub_screen.dart` → `screens/home/sync_hub_screen.dart`

**→ screens/tools/**
- [ ] Move `support_center_screen.dart` → `screens/tools/support_center_screen.dart`
- [ ] Move `harmony_hub_screen.dart` → `screens/tools/harmony_hub_screen.dart`
- [ ] Move `credit_bridge_screen.dart` → `screens/tools/credit_bridge_screen.dart`
- [ ] Move `rental_resume_screen.dart` → `screens/tools/rental_resume_screen.dart`
- [ ] Move `rulebook_screen.dart` → `screens/tools/rulebook_screen.dart`
- [ ] Move `property_pulse_detail_screen.dart` → `screens/tools/property_pulse_detail_screen.dart`
- [ ] Move `liquidity_screen.dart` → `screens/tools/liquidity_screen.dart`

**→ screens/move_in/**
- [ ] Move `ghost_overlay_screen.dart` → `screens/move_in/ghost_overlay_screen.dart`
- [ ] Move `move_in_session_screen.dart` → `screens/move_in/move_in_session_screen.dart`
- [ ] Move `stewardship_protocol_screen.dart` → `screens/move_in/stewardship_protocol_screen.dart`

**→ screens/chores/** (already in tenant, just move to subfolder)
- [ ] Move `chore_scheduler_screen.dart` → `screens/chores/chore_scheduler_screen.dart`

**→ screens/scores/** (already in tenant, just move to subfolder)
- [ ] Move `score_detail_screen.dart` → `screens/scores/score_detail_screen.dart`

- [ ] Update all router imports for all 14 moved screens

### 2.2 Reorganize existing flat tenant widgets into feature subfolders

All 9 existing flat widgets in `tenant/presentation/widgets/` need to move into subfolders:

**→ widgets/home/**
- [ ] Move `balance_card.dart` → `widgets/home/balance_card.dart`
- [ ] Move `summary_cards.dart` → `widgets/home/summary_cards.dart`
- [ ] Move `header.dart` → `widgets/home/header.dart`
- [ ] Move `friends_list.dart` → `widgets/home/friends_list.dart`
- [ ] Move `friend_list.dart` → `widgets/home/friend_list.dart`
- [ ] Move `shared_residents.dart` → `widgets/home/shared_residents.dart`
- [ ] Move `property_pulse_widget.dart` → `widgets/home/property_pulse_widget.dart`
- [ ] Move `toolkit_button.dart` → `widgets/home/toolkit_button.dart`
- [ ] Move `toolkit_grid.dart` → `widgets/home/toolkit_grid.dart`

**→ widgets/tools/**
- [ ] Move `liquidity_widget.dart` → `widgets/tools/liquidity_widget.dart`
- [ ] Move `report_widget.dart` → `widgets/tools/report_widget.dart`

**→ widgets/chores/**
- [ ] Move `calendar_widget.dart` → `widgets/chores/calendar_widget.dart`

- [ ] Update all import references to moved widget files

### 2.3 Migrate `bills/` into tenant/

**Data layer:**
- [ ] Move `bills/data/datasources/` → `tenant/data/datasources/bills/`
- [ ] Move `bills/data/local/` → `tenant/data/local/bills/`
- [ ] Move `bills/data/models/` → `tenant/data/models/bills/`
- [ ] Move `bills/data/repositories/` → `tenant/data/repositories/bills/`

**Domain layer:**
- [ ] Move `bills/domain/entities/` → `tenant/domain/entities/bills/`
- [ ] Move `bills/domain/repositories/` → `tenant/domain/repositories/bills/`
- [ ] Move `bills/domain/usecases/` → `tenant/domain/usecases/bills/`

**Presentation:**
- [ ] Move `bills/presentation/providers/` → `tenant/presentation/providers/bills/`
- [ ] Move `bills/presentation/screens/` (all 5 screens + bill_creation/) → `tenant/presentation/screens/bills/`
- [ ] Move `bills/presentation/widgets/` → `tenant/presentation/widgets/bills/`
- [ ] Move `bills/presentation/utils/` → `tenant/presentation/utils/bills/`

- [ ] Update all router imports for 10+ bill routes
- [ ] Update all internal cross-file imports within the bills layer
- [ ] Delete `lib/features/bills/` folder

### 2.4 Migrate `chores/` into tenant/

**Data layer:**
- [ ] Move `chores/data/datasources/` → `tenant/data/datasources/chores/`
- [ ] Move `chores/data/models/` → `tenant/data/models/chores/`
- [ ] Move `chores/data/repositories/` → `tenant/data/repositories/chores/`

**Domain layer:**
- [ ] Move `chores/domain/entities/` → `tenant/domain/entities/chores/`
- [ ] Move `chores/domain/repositories/` → `tenant/domain/repositories/chores/`
- [ ] Move `chores/domain/usecases/` → `tenant/domain/usecases/chores/`

**Presentation:**
- [ ] Move `chores/presentation/providers/chore_provider.dart` → `tenant/presentation/providers/chores/chore_provider.dart`
- [ ] Move `chores/presentation/screens/create_chore_screen.dart` → `tenant/presentation/screens/chores/create_chore_screen.dart`
- [ ] Move `chores/presentation/widgets/` → `tenant/presentation/widgets/chores/`

- [ ] Update all router imports
- [ ] Delete `lib/features/chores/` folder

### 2.5 Migrate `scores/` into tenant/

**Data layer:**
- [ ] Move `scores/data/datasources/` → `tenant/data/datasources/scores/`
- [ ] Move `scores/data/models/` → `tenant/data/models/scores/`
- [ ] Move `scores/data/repositories/` → `tenant/data/repositories/scores/`

**Domain layer:**
- [ ] Move `scores/domain/entities/` → `tenant/domain/entities/scores/`
- [ ] Move `scores/domain/repositories/` → `tenant/domain/repositories/scores/`
- [ ] Move `scores/domain/usecases/` → `tenant/domain/usecases/scores/`

**Presentation:**
- [ ] Move `scores/presentation/providers/score_provider.dart` → `tenant/presentation/providers/scores/score_provider.dart`
- [ ] Move `scores/presentation/widgets/` → `tenant/presentation/widgets/scores/`
- [ ] Check `scores/presentation/screens/leaderboard_screen.dart` — if has content, move to `tenant/presentation/screens/scores/`; if empty, delete

- [ ] Update all router imports
- [ ] Delete `lib/features/scores/` folder

### 2.6 Migrate `ai_assistant/` into tenant/presentation/screens/ai/

- [ ] Move `ai_assistant/presentation/screens/rex_interface_screen.dart` → `tenant/presentation/screens/ai/rex_interface_screen.dart`
- [ ] Move `ai_assistant/presentation/screens/lazy_logger_screen.dart` → `tenant/presentation/screens/ai/lazy_logger_screen.dart`
- [ ] Move `ai_assistant/presentation/screens/fairfix_auditor_screen.dart` → `tenant/presentation/screens/ai/fairfix_auditor_screen.dart`
- [ ] Move `ai_assistant/presentation/screens/lease_sentinel_screen.dart` → `tenant/presentation/screens/ai/lease_sentinel_screen.dart`
- [ ] Update router imports for all 4 AI screen routes
- [ ] Delete `lib/features/ai_assistant/` folder

### 2.7 Migrate `honor/` into tenant/presentation/screens/honor/

- [ ] Locate `honor_history_screen.dart` in `lib/features/honor/`
- [ ] Move to `tenant/presentation/screens/honor/honor_history_screen.dart`
- [ ] Update router import
- [ ] Delete `lib/features/honor/` folder

---

## PHASE 3 — `landlord/` Restructure

### 3.1 Migrate `property/` into landlord/

**Data layer:**
- [x] `property/data/` already moved → `landlord/data/`
  *(verify the feature subfolder convention: files should be in `landlord/data/datasources/property/`, `landlord/data/models/property/`, `landlord/data/repositories/property/`)*
- [ ] If not using feature subfolders yet, reorganize into `datasources/property/`, `models/property/`, `repositories/property/`

**Domain layer:**
- [ ] Move `property/domain/entities/` → `landlord/domain/entities/property/`
- [ ] Move `property/domain/repositories/` → `landlord/domain/repositories/property/`

**Presentation:**
- [ ] Move `property/presentation/providers/properties_provider.dart` → `landlord/presentation/providers/properties_provider.dart`
- [ ] Move `property/presentation/widgets/` (5 widgets) → `landlord/presentation/widgets/common/`
- [ ] Update all import references to `features/property/`
- [ ] Delete `lib/features/property/` folder

### 3.2 Reorganize landlord screens into numbered subfolders
- [ ] Move `landlord_command_screen.dart` → `screens/1-Command/landlord_command_screen.dart`
- [ ] Move `landlord_finance_screen.dart` → `screens/2-Finance/landlord_finance_screen.dart`
- [ ] Move `landlord_rex_ai_screen.dart` → `screens/3-REX/landlord_rex_ai_screen.dart`
- [ ] Move `landlord_portfolio_screen.dart` → `screens/4-Portfolio/landlord_portfolio_screen.dart`
- [ ] Move `landlord_community_screen.dart` → `screens/5-Community/landlord_community_screen.dart`
- [ ] Move `tenant_management_screen.dart` → `screens/4-Portfolio/sub/tenant_management_screen.dart`
- [ ] Keep `landlord_dashboard_screen.dart` at `screens/` root level
- [ ] Update all router imports for moved landlord screens

### 3.3 Reorganize landlord widgets into category subfolders
- [ ] Create `widgets/AI/` with `rex_card_widgets.dart`, `rex_message_bubble.dart`
- [ ] Create `widgets/layouts/` with `ambient_background.dart`
- [ ] Move flat widgets into `widgets/common/`: `expense_breakdown.dart`, `property_pulse_card.dart`, `reputation_card.dart`
- [ ] Delete duplicate `widgets/revenue_chart.dart` (keep `widgets/common/revenue_chart.dart`)

---

## PHASE 4 — Delete All Empty Standalone Folders

After Phases 1–3 complete, verify empty then delete:

- [ ] `lib/features/auth/`
- [ ] `lib/features/users/`
- [ ] `lib/features/profile/`
- [ ] `lib/features/community/`
- [ ] `lib/features/gamification/`
- [ ] `lib/features/maintenance/`
- [ ] `lib/features/bills/`
- [ ] `lib/features/chores/`
- [ ] `lib/features/scores/`
- [ ] `lib/features/ai_assistant/`
- [ ] `lib/features/honor/`
- [ ] `lib/features/property/`

**After each delete:** run `flutter analyze` — zero errors before moving on.

---

## PHASE 5 — Router Cleanup (after all moves)

- [ ] Full audit of `lib/core/router/app_router.dart` — verify every import path
- [ ] Wire `/landlord-maintenance` placeholder → actual landlord maintenance screen
- [ ] Wire `/lease-sentinel-landlord` placeholder → actual screen
- [ ] Add `LandlordShellRoute` wrapping the 5 landlord tabs
- [ ] Add routes for any new screens (leaderboard if kept, tenant_management, etc.)
- [ ] Create `tenant/presentation/widgets/navigation/custom_bottom_nav_bar.dart` (tenant nav widget)

---

## PHASE 6 — Core Cleanup (low priority)

- [ ] Create `lib/core/constants/api_constants.dart` (Gemini config)
- [ ] Create `lib/core/constants/app_constants.dart`
- [ ] Create `lib/core/providers/app_providers.dart`

---

## PHASE 7 — Docs Update

- [ ] Update `MEMORY.md` architecture tree with new 3-folder structure
- [ ] Update `context/project-memory.md` to reflect new file paths
- [ ] Update `context/residex-feature-list-v2.md` screen file references

---

## Priority Order

| Phase | Priority | Effort | Risk |
|-------|----------|--------|------|
| Phase 0 — Quick fixes | 🔴 Do first | Low | None |
| Phase 1 — shared/ cleanup | 🔴 High | Low (mostly done) | Low |
| Phase 2.1/2.2 — Reorganize existing tenant screens/widgets | 🔴 High | Medium | High (many router + widget imports) |
| Phase 2.3–2.7 — Migrate into tenant/ | 🟡 Medium | High | High |
| Phase 3 — landlord/ restructure | 🟡 Medium | Medium | Medium |
| Phase 4 — Delete empty folders | 🔴 After 1–3 | Low | None |
| Phase 5 — Router audit | 🔴 After every move | Medium | High |
| Phase 6 — Core cleanup | 🟢 Low | Low | Low |
| Phase 7 — Docs | 🟢 Low | Low | None |

**Rule:** `flutter analyze` after every file move. Never move 10 files then try to fix errors — move 2–3, verify, then continue.
