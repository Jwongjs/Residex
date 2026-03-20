# RESIDEX - Architecture Migration & Implementation Todo List

**Project:** SplitLah → Residex (Production-Ready Architecture)
**Timeline:** 6 Weeks (Hackathon)
**Last Updated:** January 10, 2026

---

## 📋 PROGRESS OVERVIEW

- [ ] **Phase 0:** Project Setup & Planning (Day 1-2)
- [ ] **Phase 1:** Core Infrastructure (Week 1)
- [ ] **Phase 2:** Authentication & Property (Week 1-2)
- [ ] **Phase 3:** Digital Handover (Week 2)
- [ ] **Phase 4:** Bills Migration & Enhancement (Week 3)
- [ ] **Phase 5:** Scores & Chores (Week 4)
- [ ] **Phase 6:** Resources, Maintenance, Community (Week 4-5)
- [ ] **Phase 7:** Testing & Quality Assurance (Week 5-6)
- [ ] **Phase 8:** Polish & Deployment Prep (Week 6)

**Overall Completion:** 0%

---

## 🚀 PHASE 0: PROJECT SETUP & PLANNING (Day 1-2)

### **Environment Setup**
- [ ] Create new Firebase project: `residex-my`
- [ ] Enable Firebase services:
  - [ ] Firebase Authentication (Phone)
  - [ ] Cloud Firestore
  - [ ] Firebase Storage
  - [ ] Cloud Functions
  - [ ] Firebase Analytics
  - [ ] Firebase Crashlytics
  - [ ] Remote Config
- [ ] Set up Google Cloud project for ML services
- [ ] Enable Google ML Kit
- [ ] Enable Cloud Vision API (get API key)
- [ ] Set up environment files:
  - [ ] `.env.development`
  - [ ] `.env.staging`
  - [ ] `.env.production`
- [ ] Add `.env` files to `.gitignore`
- [ ] Create Firebase app configurations:
  - [ ] Android app
  - [ ] iOS app (future)
- [ ] Download `google-services.json` and place in `android/app/`

### **Git & Version Control**
- [ ] Create new branch: `feature/architecture-restructure`
- [ ] Set up `.gitignore` properly (exclude .env, secrets)
- [ ] Create GitHub repository (if not exists)
- [ ] Set up branch protection rules (main/develop)
- [ ] Create develop branch for active development

### **Documentation**
- [ ] Review complete architecture document
- [ ] Review feature specifications
- [ ] Create architecture diagram (draw.io or similar)
- [ ] Document API endpoints structure
- [ ] Document database schema (Drift + Firestore)

---

## 🏗️ PHASE 1: CORE INFRASTRUCTURE (Week 1)

### **Directory Structure Creation**
- [ ] Create main directory structure:
  ```bash
  mkdir -p lib/{app,core,shared,features,infrastructure,test}
  ```

- [ ] Create `app/` structure:
  - [ ] `app/app.dart`
  - [ ] `app/app_router.dart`
  - [ ] `app/app_theme.dart`
  - [ ] `app/observers/`
  - [ ] `app/providers/`

- [ ] Create `core/` structure:
  - [ ] `core/constants/`
  - [ ] `core/config/`
  - [ ] `core/extensions/`
  - [ ] `core/utils/`
  - [ ] `core/errors/`
  - [ ] `core/network/`
  - [ ] `core/storage/`
  - [ ] `core/services/`
  - [ ] `core/di/`

- [ ] Create `shared/` structure:
  - [ ] `shared/domain/`
  - [ ] `shared/data/`
  - [ ] `shared/presentation/widgets/`
  - [ ] `shared/presentation/theme/`
  - [ ] `shared/l10n/`

- [ ] Create `features/` structure (all 10 features):
  - [ ] `features/authentication/`
  - [ ] `features/property/`
  - [ ] `features/bills/`
  - [ ] `features/chores/`
  - [ ] `features/handover/`
  - [ ] `features/scores/`
  - [ ] `features/resources/`
  - [ ] `features/maintenance/`
  - [ ] `features/community/`
  - [ ] `features/user/`
  - [ ] `features/notifications/`

- [ ] Create `infrastructure/` structure:
  - [ ] `infrastructure/database/drift/`
  - [ ] `infrastructure/database/firebase/`
  - [ ] `infrastructure/ml/`
  - [ ] `infrastructure/external/`

- [ ] Create `test/` structure:
  - [ ] `test/unit/`
  - [ ] `test/widget/`
  - [ ] `test/integration/`

### **Core Constants**
- [ ] Create `core/constants/app_constants.dart`
  - [ ] App name, version
  - [ ] Default values
  - [ ] Timeout durations
- [ ] Create `core/constants/api_constants.dart`
  - [ ] Base URLs (dev, staging, prod)
  - [ ] API endpoints structure
- [ ] Create `core/constants/storage_constants.dart`
  - [ ] SharedPreferences keys
  - [ ] Secure storage keys
- [ ] Create `core/constants/route_constants.dart`
  - [ ] All route names
- [ ] Create `core/constants/error_constants.dart`
  - [ ] Error codes
  - [ ] Error messages

### **Core Config**
- [ ] Create `core/config/environment_config.dart`
  - [ ] Load environment variables
  - [ ] Environment detection (dev/staging/prod)
- [ ] Create `core/config/firebase_config.dart`
  - [ ] Firebase initialization
  - [ ] Platform-specific config
- [ ] Create `core/config/flavor_config.dart`
  - [ ] Flavor configuration
- [ ] Create `core/config/app_config.dart`
  - [ ] Runtime configuration

### **Core Extensions**
- [ ] Create `core/extensions/build_context_extension.dart`
  - [ ] MediaQuery helpers
  - [ ] Theme access
  - [ ] Navigation helpers
  - [ ] SnackBar helpers
- [ ] Create `core/extensions/date_time_extension.dart`
  - [ ] Date formatting
  - [ ] Relative time (e.g., "2 days ago")
  - [ ] Date comparisons
- [ ] Create `core/extensions/string_extension.dart`
  - [ ] Capitalization
  - [ ] Validation helpers
  - [ ] Formatting
- [ ] Create `core/extensions/number_extension.dart`
  - [ ] Currency formatting (RM)
  - [ ] Percentage formatting
  - [ ] Number abbreviation (1000 → 1k)
- [ ] Create `core/extensions/iterable_extension.dart`
  - [ ] Safe access
  - [ ] Grouping
  - [ ] Filtering helpers
- [ ] Create `core/extensions/widget_extension.dart`
  - [ ] Padding helpers
  - [ ] Conditional rendering

### **Core Utils**
- [ ] Create `core/utils/logger.dart`
  - [ ] Log levels (debug, info, warning, error)
  - [ ] Crashlytics integration
  - [ ] Development vs production logging
- [ ] Create `core/utils/validators.dart`
  - [ ] Phone number validation (+60)
  - [ ] Email validation
  - [ ] Amount validation
  - [ ] Required field validation
- [ ] Create `core/utils/formatters.dart`
  - [ ] Phone number formatter
  - [ ] Currency formatter
  - [ ] Date formatter
- [ ] Create `core/utils/debouncer.dart`
  - [ ] Debounce utility for search
- [ ] Create `core/utils/encryption.dart`
  - [ ] AES encryption
  - [ ] Decryption
- [ ] Create `core/utils/biometric_auth.dart`
  - [ ] Fingerprint authentication
  - [ ] Face ID (iOS future)
- [ ] Create `core/utils/image_processor.dart`
  - [ ] Image compression
  - [ ] Image resizing
  - [ ] Thumbnail generation
- [ ] Create `core/utils/pdf_generator.dart`
  - [ ] PDF creation utility
  - [ ] Template rendering
- [ ] Create `core/utils/qr_code_generator.dart`
  - [ ] QR code generation
  - [ ] QR code scanning helpers
- [ ] Create `core/utils/platform_utils.dart`
  - [ ] Platform detection
  - [ ] OS version checks

### **Core Errors**
- [ ] Create `core/errors/failures.dart`
  - [ ] `Failure` base class
  - [ ] `ServerFailure`
  - [ ] `CacheFailure`
  - [ ] `NetworkFailure`
  - [ ] `ValidationFailure`
  - [ ] `AuthenticationFailure`
- [ ] Create `core/errors/exceptions.dart`
  - [ ] `ServerException`
  - [ ] `CacheException`
  - [ ] `NetworkException`
  - [ ] Custom exceptions
- [ ] Create `core/errors/error_handler.dart`
  - [ ] Global error handler
  - [ ] Error to Failure mapper
- [ ] Create `core/errors/error_reporter.dart`
  - [ ] Crashlytics reporting
  - [ ] Error logging

### **Core Network**
- [ ] Create `core/network/api_client.dart`
  - [ ] HTTP client wrapper (Dio)
  - [ ] Request methods (GET, POST, PUT, DELETE)
- [ ] Create `core/network/api_interceptor.dart`
  - [ ] Request interceptor (add auth token)
  - [ ] Response interceptor (error handling)
  - [ ] Logging interceptor
- [ ] Create `core/network/network_info.dart`
  - [ ] Connectivity checker
  - [ ] Network type detection
- [ ] Create `core/network/dio_provider.dart`
  - [ ] Dio configuration
  - [ ] Base options
  - [ ] Timeout settings
- [ ] Create `core/network/retry_policy.dart`
  - [ ] Retry logic for failed requests
  - [ ] Exponential backoff

### **Core Storage**
- [ ] Create `core/storage/local_storage.dart`
  - [ ] SharedPreferences wrapper
  - [ ] Type-safe get/set methods
- [ ] Create `core/storage/secure_storage.dart`
  - [ ] FlutterSecureStorage wrapper
  - [ ] Encrypt/decrypt helpers
- [ ] Create `core/storage/cache_manager.dart`
  - [ ] Cache management
  - [ ] Cache invalidation
  - [ ] TTL support
- [ ] Create `core/storage/file_storage.dart`
  - [ ] File system operations
  - [ ] Directory helpers
  - [ ] File cleanup

### **Core Services**
- [ ] Create `core/services/analytics_service.dart`
  - [ ] Firebase Analytics wrapper
  - [ ] Event logging
  - [ ] Screen tracking
  - [ ] User properties
- [ ] Create `core/services/crashlytics_service.dart`
  - [ ] Crashlytics wrapper
  - [ ] Crash reporting
  - [ ] Custom logs
- [ ] Create `core/services/notification_service.dart`
  - [ ] FCM integration
  - [ ] Local notifications
  - [ ] Notification channels
  - [ ] Badge count management
- [ ] Create `core/services/deeplink_service.dart`
  - [ ] Deep link handling
  - [ ] Dynamic links
  - [ ] Route parsing
- [ ] Create `core/services/permission_service.dart`
  - [ ] Permission requests
  - [ ] Permission status checks
  - [ ] Settings navigation
- [ ] Create `core/services/location_service.dart`
  - [ ] Location access
  - [ ] Address lookup (future)
- [ ] Create `core/services/background_service.dart`
  - [ ] Background task scheduling
  - [ ] WorkManager integration

### **Dependency Injection**
- [ ] Create `core/di/injection_container.dart`
  - [ ] GetIt setup
  - [ ] Register core services
  - [ ] Register database
- [ ] Create `core/di/feature_injection.dart`
  - [ ] Feature-specific DI
  - [ ] Lazy loading support
- [ ] Create `core/di/service_injection.dart`
  - [ ] Service DI
- [ ] Initialize DI in `main.dart`

---

## 🎨 PHASE 1.5: SHARED COMPONENTS (Week 1)

### **Shared Domain**
- [ ] Create `shared/domain/entities/result.dart`
  - [ ] `Result<T>` wrapper (Success/Error)
- [ ] Create `shared/domain/entities/paginated_list.dart`
  - [ ] Pagination wrapper
- [ ] Create `shared/domain/entities/validation_result.dart`
  - [ ] Validation result wrapper
- [ ] Create `shared/domain/usecases/usecase.dart`
  - [ ] Base `UseCase<Type, Params>` class

### **Shared Data**
- [ ] Create `shared/data/models/api_response.dart`
  - [ ] Generic API response model
- [ ] Create `shared/data/models/error_response.dart`
  - [ ] Error response model
- [ ] Create `shared/data/repositories/base_repository.dart`
  - [ ] Base repository with common methods

### **Shared Widgets - Buttons**
- [ ] Create `shared/presentation/widgets/buttons/primary_button.dart`
- [ ] Create `shared/presentation/widgets/buttons/secondary_button.dart`
- [ ] Create `shared/presentation/widgets/buttons/text_button.dart`
- [ ] Create `shared/presentation/widgets/buttons/icon_button.dart`
- [ ] Create `shared/presentation/widgets/buttons/floating_action_button.dart`

### **Shared Widgets - Inputs**
- [ ] Create `shared/presentation/widgets/inputs/text_field.dart`
- [ ] Create `shared/presentation/widgets/inputs/search_field.dart`
- [ ] Create `shared/presentation/widgets/inputs/dropdown_field.dart`
- [ ] Create `shared/presentation/widgets/inputs/date_picker_field.dart`
- [ ] Create `shared/presentation/widgets/inputs/phone_input_field.dart`
- [ ] Create `shared/presentation/widgets/inputs/otp_input_field.dart`

### **Shared Widgets - Cards**
- [ ] Create `shared/presentation/widgets/cards/glass_card.dart`
  - [ ] Migrate from existing SplitLah
  - [ ] Enhance with new design system
- [ ] Create `shared/presentation/widgets/cards/elevated_card.dart`
- [ ] Create `shared/presentation/widgets/cards/info_card.dart`
- [ ] Create `shared/presentation/widgets/cards/stat_card.dart`

### **Shared Widgets - Lists**
- [ ] Create `shared/presentation/widgets/lists/list_tile.dart`
- [ ] Create `shared/presentation/widgets/lists/expandable_list_tile.dart`
- [ ] Create `shared/presentation/widgets/lists/swipe_list_tile.dart`
- [ ] Create `shared/presentation/widgets/lists/infinite_scroll_list.dart`

### **Shared Widgets - Dialogs**
- [ ] Create `shared/presentation/widgets/dialogs/confirmation_dialog.dart`
- [ ] Create `shared/presentation/widgets/dialogs/loading_dialog.dart`
- [ ] Create `shared/presentation/widgets/dialogs/error_dialog.dart`
- [ ] Create `shared/presentation/widgets/dialogs/bottom_sheet_dialog.dart`
- [ ] Create `shared/presentation/widgets/dialogs/fullscreen_dialog.dart`

### **Shared Widgets - Loaders**
- [ ] Create `shared/presentation/widgets/loaders/circular_loader.dart`
- [ ] Create `shared/presentation/widgets/loaders/linear_loader.dart`
- [ ] Create `shared/presentation/widgets/loaders/skeleton_loader.dart`
- [ ] Create `shared/presentation/widgets/loaders/shimmer_loader.dart`
- [ ] Create `shared/presentation/widgets/loaders/custom_loader.dart`
  - [ ] Migrate SplitLah loader animation

### **Shared Widgets - Avatars**
- [ ] Create `shared/presentation/widgets/avatars/user_avatar.dart`
  - [ ] Migrate from SplitLah
  - [ ] Gradient background generation
- [ ] Create `shared/presentation/widgets/avatars/group_avatar.dart`
- [ ] Create `shared/presentation/widgets/avatars/avatar_stack.dart`
- [ ] Create `shared/presentation/widgets/avatars/avatar_picker.dart`

### **Shared Widgets - Animations**
- [ ] Create `shared/presentation/widgets/animations/fade_in_animation.dart`
- [ ] Create `shared/presentation/widgets/animations/slide_animation.dart`
- [ ] Create `shared/presentation/widgets/animations/scale_animation.dart`
- [ ] Create `shared/presentation/widgets/animations/particle_animation.dart`
  - [ ] Migrate particle pool from SplitLah
- [ ] Create `shared/presentation/widgets/animations/lottie_animation.dart`

### **Shared Widgets - Overlays**
- [ ] Create `shared/presentation/widgets/overlays/toast.dart`
- [ ] Create `shared/presentation/widgets/overlays/snackbar.dart`
- [ ] Create `shared/presentation/widgets/overlays/banner.dart`
- [ ] Create `shared/presentation/widgets/overlays/tooltip.dart`

### **Shared Widgets - Layout**
- [ ] Create `shared/presentation/widgets/layout/responsive_builder.dart`
- [ ] Create `shared/presentation/widgets/layout/safe_area_wrapper.dart`
- [ ] Create `shared/presentation/widgets/layout/scrollable_wrapper.dart`
- [ ] Create `shared/presentation/widgets/layout/conditional_wrapper.dart`

### **Shared Theme**
- [ ] Create `shared/presentation/theme/app_colors.dart`
  - [ ] Color palette (Deep Blue + Purple gradient)
  - [ ] Semantic colors (success, error, warning, info)
- [ ] Create `shared/presentation/theme/app_typography.dart`
  - [ ] Text styles (Poppins headings, Inter body)
  - [ ] Font sizes, weights, line heights
- [ ] Create `shared/presentation/theme/app_spacing.dart`
  - [ ] Spacing constants (4, 8, 16, 24, 32, 40, 48, 64)
- [ ] Create `shared/presentation/theme/app_borders.dart`
  - [ ] Border radius constants
  - [ ] Border styles
- [ ] Create `shared/presentation/theme/app_shadows.dart`
  - [ ] Shadow definitions
- [ ] Create `shared/presentation/theme/app_animations.dart`
  - [ ] Animation duration constants
  - [ ] Animation curves
- [ ] Create `shared/presentation/theme/app_icons.dart`
  - [ ] Icon constants

### **Localization**
- [ ] Create `shared/l10n/app_en.arb` (English)
- [ ] Create `shared/l10n/app_ms.arb` (Malay)
- [ ] Create `shared/l10n/app_zh.arb` (Chinese - future)
- [ ] Add l10n to `pubspec.yaml`
- [ ] Generate localization files

---

## 🗄️ PHASE 1.6: DATABASE INFRASTRUCTURE (Week 1)

### **Drift Database Setup**
- [ ] Create `infrastructure/database/drift/app_database.dart`
  - [ ] Database class definition
  - [ ] Schema version management
  - [ ] Migration strategy

### **Drift Tables**
- [ ] Create `infrastructure/database/drift/tables/users_table.dart`
- [ ] Create `infrastructure/database/drift/tables/properties_table.dart`
- [ ] Create `infrastructure/database/drift/tables/bills_table.dart`
  - [ ] Migrate from existing SplitLah
- [ ] Create `infrastructure/database/drift/tables/bill_items_table.dart`
  - [ ] Migrate from existing SplitLah (receipt_items)
- [ ] Create `infrastructure/database/drift/tables/chores_table.dart`
- [ ] Create `infrastructure/database/drift/tables/chore_instances_table.dart`
- [ ] Create `infrastructure/database/drift/tables/handovers_table.dart`
- [ ] Create `infrastructure/database/drift/tables/handover_photos_table.dart`
- [ ] Create `infrastructure/database/drift/tables/tickets_table.dart`
- [ ] Create `infrastructure/database/drift/tables/community_posts_table.dart`
- [ ] Create `infrastructure/database/drift/tables/comments_table.dart`
- [ ] Create `infrastructure/database/drift/tables/votes_table.dart`
- [ ] Create `infrastructure/database/drift/tables/notifications_table.dart`
- [ ] Create supporting tables:
  - [ ] `chore_swaps_table.dart`
  - [ ] `resources_table.dart`
  - [ ] `resource_purchases_table.dart`
  - [ ] `shopping_list_table.dart`
  - [ ] `defects_table.dart`
  - [ ] `ticket_comments_table.dart`
  - [ ] `score_history_table.dart`

### **Drift DAOs**
- [ ] Create `infrastructure/database/drift/daos/user_dao.dart`
  - [ ] Migrate from SplitLah
- [ ] Create `infrastructure/database/drift/daos/property_dao.dart`
  - [ ] Adapt from groups_dao
- [ ] Create `infrastructure/database/drift/daos/bill_dao.dart`
  - [ ] Migrate from SplitLah
  - [ ] **Fix payment persistence bug**
- [ ] Create `infrastructure/database/drift/daos/chore_dao.dart`
- [ ] Create `infrastructure/database/drift/daos/handover_dao.dart`
- [ ] Create `infrastructure/database/drift/daos/ticket_dao.dart`
- [ ] Create `infrastructure/database/drift/daos/community_dao.dart`
- [ ] Create `infrastructure/database/drift/daos/notification_dao.dart`

### **Drift Converters**
- [ ] Create `infrastructure/database/drift/converters/date_time_converter.dart`
- [ ] Create `infrastructure/database/drift/converters/json_converter.dart`
- [ ] Create `infrastructure/database/drift/converters/enum_converter.dart`

### **Drift Code Generation**
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Verify generated `app_database.g.dart`

### **Firebase Database Setup**
- [ ] Create `infrastructure/database/firebase/firestore_service.dart`
  - [ ] Firestore wrapper
  - [ ] Collection references
  - [ ] Query builders
- [ ] Create `infrastructure/database/firebase/storage_service.dart`
  - [ ] Firebase Storage wrapper
  - [ ] Upload/download methods
  - [ ] URL generation

### **Firebase Collections**
- [ ] Create `infrastructure/database/firebase/collections/users_collection.dart`
- [ ] Create `infrastructure/database/firebase/collections/properties_collection.dart`
- [ ] Create `infrastructure/database/firebase/collections/bills_collection.dart`
- [ ] Create `infrastructure/database/firebase/collections/handovers_collection.dart`

### **Sync Infrastructure**
- [ ] Create `infrastructure/database/firebase/sync/sync_manager.dart`
  - [ ] Local to remote sync
  - [ ] Remote to local sync
  - [ ] Last sync timestamp tracking
- [ ] Create `infrastructure/database/firebase/sync/sync_queue.dart`
  - [ ] Offline queue for pending operations
  - [ ] Queue persistence
  - [ ] Auto-retry on connection
- [ ] Create `infrastructure/database/firebase/sync/conflict_resolver.dart`
  - [ ] Last-write-wins strategy
  - [ ] Conflict detection
  - [ ] Manual resolution UI (future)

---

## 🔐 PHASE 2: AUTHENTICATION FEATURE (Week 1)

### **Authentication Domain Layer**
- [ ] Create `features/authentication/domain/entities/auth_user.dart`
  - [ ] User ID, phone, name, email
  - [ ] Authentication status
- [ ] Create `features/authentication/domain/entities/auth_state.dart`
  - [ ] Authenticated/Unauthenticated states
- [ ] Create `features/authentication/domain/entities/phone_number.dart`
  - [ ] Country code, number
  - [ ] Validation
- [ ] Create `features/authentication/domain/repositories/auth_repository.dart`
  - [ ] Abstract interface
  - [ ] sendOtp, verifyOtp, signOut, getCurrentUser, refreshToken

### **Authentication Use Cases**
- [ ] Create `features/authentication/domain/usecases/send_otp.dart`
- [ ] Create `features/authentication/domain/usecases/verify_otp.dart`
- [ ] Create `features/authentication/domain/usecases/sign_out.dart`
- [ ] Create `features/authentication/domain/usecases/get_current_user.dart`
- [ ] Create `features/authentication/domain/usecases/refresh_token.dart`

### **Authentication Data Layer**
- [ ] Create `features/authentication/data/models/auth_user_model.dart`
  - [ ] Extends auth_user entity
  - [ ] toJson/fromJson
- [ ] Create `features/authentication/data/models/otp_response_model.dart`
- [ ] Create `features/authentication/data/datasources/auth_remote_datasource.dart`
  - [ ] Firebase Auth implementation
  - [ ] Phone authentication
  - [ ] OTP verification
- [ ] Create `features/authentication/data/datasources/auth_local_datasource.dart`
  - [ ] Token storage (secure storage)
  - [ ] User cache
- [ ] Create `features/authentication/data/repositories/auth_repository_impl.dart`
  - [ ] Implements auth_repository interface
  - [ ] Calls datasources
  - [ ] Error handling

### **Authentication Presentation Layer**
- [ ] Create `features/authentication/presentation/screens/splash_screen.dart`
  - [ ] Migrate from SplitLah
  - [ ] Update branding to Residex
- [ ] Create `features/authentication/presentation/screens/onboarding_screen.dart`
  - [ ] 3-4 slides explaining Residex value
- [ ] Create `features/authentication/presentation/screens/login_screen.dart`
  - [ ] Phone number input
  - [ ] Country code selector
  - [ ] "Send OTP" button
- [ ] Create `features/authentication/presentation/screens/otp_verification_screen.dart`
  - [ ] 6-digit OTP input
  - [ ] Resend OTP
  - [ ] Auto-verification
- [ ] Create `features/authentication/presentation/screens/profile_completion_screen.dart`
  - [ ] Name input
  - [ ] Avatar selection
  - [ ] Optional email

### **Authentication Widgets**
- [ ] Create `features/authentication/presentation/widgets/phone_input_widget.dart`
  - [ ] Country code dropdown
  - [ ] Phone number field
  - [ ] Validation
- [ ] Create `features/authentication/presentation/widgets/otp_input_widget.dart`
  - [ ] 6 separate boxes
  - [ ] Auto-focus
  - [ ] Auto-submit
- [ ] Create `features/authentication/presentation/widgets/country_picker_widget.dart`
  - [ ] Country list with flags
  - [ ] Search
  - [ ] Default to Malaysia (+60)

### **Authentication Providers**
- [ ] Create `features/authentication/presentation/providers/auth_provider.dart`
  - [ ] Current user stream
  - [ ] Authentication state
- [ ] Create `features/authentication/presentation/providers/auth_state_provider.dart`
  - [ ] Login/logout actions
  - [ ] OTP sending/verification

### **Authentication DI**
- [ ] Set up authentication dependency injection
- [ ] Register datasources, repositories, use cases
- [ ] Test authentication flow

---

## 🏠 PHASE 2.5: PROPERTY FEATURE (Week 1-2)

### **Property Domain Layer**
- [ ] Create `features/property/domain/entities/property.dart`
  - [ ] Migrate from groups entity
  - [ ] Add landlord info, address, lease dates
- [ ] Create `features/property/domain/entities/property_member.dart`
  - [ ] Member with role (Admin/Member/Landlord)
- [ ] Create `features/property/domain/entities/landlord.dart`
  - [ ] Landlord details
- [ ] Create `features/property/domain/entities/lease.dart`
  - [ ] Lease start/end dates, rent amount
- [ ] Create `features/property/domain/repositories/property_repository.dart`

### **Property Use Cases**
- [ ] Create `features/property/domain/usecases/create_property.dart`
- [ ] Create `features/property/domain/usecases/update_property.dart`
- [ ] Create `features/property/domain/usecases/delete_property.dart`
- [ ] Create `features/property/domain/usecases/get_property_by_id.dart`
- [ ] Create `features/property/domain/usecases/get_user_properties.dart`
- [ ] Create `features/property/domain/usecases/add_member.dart`
- [ ] Create `features/property/domain/usecases/remove_member.dart`
- [ ] Create `features/property/domain/usecases/invite_member.dart`

### **Property Data Layer**
- [ ] Create `features/property/data/models/property_model.dart`
- [ ] Create `features/property/data/models/property_member_model.dart`
- [ ] Create `features/property/data/models/landlord_model.dart`
- [ ] Create `features/property/data/datasources/property_remote_datasource.dart`
- [ ] Create `features/property/data/datasources/property_local_datasource.dart`
  - [ ] Migrate logic from groups datasource
- [ ] Create `features/property/data/repositories/property_repository_impl.dart`

### **Property Presentation Layer**
- [ ] Create `features/property/presentation/screens/property_dashboard_screen.dart`
  - [ ] Quick actions
  - [ ] Recent activity
  - [ ] Outstanding bills summary
  - [ ] Upcoming chores
  - [ ] Open tickets
- [ ] Create `features/property/presentation/screens/property_list_screen.dart`
  - [ ] List of user's properties
  - [ ] Switch property
- [ ] Create `features/property/presentation/screens/property_detail_screen.dart`
  - [ ] Property info
  - [ ] Member list
  - [ ] Statistics
- [ ] Create `features/property/presentation/screens/create_property_screen.dart`
  - [ ] Property name, address
  - [ ] Landlord info
  - [ ] Lease details
  - [ ] Add members
- [ ] Create `features/property/presentation/screens/property_settings_screen.dart`
  - [ ] Edit property
  - [ ] Manage members
  - [ ] Leave property

### **Property Widgets**
- [ ] Create `features/property/presentation/widgets/property_card.dart`
- [ ] Create `features/property/presentation/widgets/member_list_widget.dart`
- [ ] Create `features/property/presentation/widgets/property_stats_widget.dart`
- [ ] Create `features/property/presentation/widgets/invite_member_dialog.dart`

### **Property Providers**
- [ ] Create `features/property/presentation/providers/property_provider.dart`
- [ ] Create `features/property/presentation/providers/property_list_provider.dart`
- [ ] Create `features/property/presentation/providers/selected_property_provider.dart`

### **Property DI**
- [ ] Set up property dependency injection
- [ ] Test property CRUD operations

---

## 📸 PHASE 3: DIGITAL HANDOVER FEATURE (⭐ STAR FEATURE - Week 2)

### **Handover Domain Layer**
- [ ] Create `features/handover/domain/entities/handover.dart`
  - [ ] Move-in/move-out type
  - [ ] Property ID, date
  - [ ] Status (Draft/Pending Agreement/Locked)
- [ ] Create `features/handover/domain/entities/handover_photo.dart`
  - [ ] Photo URL, room, timestamp, watermark
- [ ] Create `features/handover/domain/entities/defect.dart`
  - [ ] Type, severity, description, annotation data
- [ ] Create `features/handover/domain/entities/room.dart`
  - [ ] Room name, photo count, defect count
- [ ] Create `features/handover/domain/entities/landlord_agreement.dart`
  - [ ] Status (Pending/Agreed/Disputed/Rejected)
  - [ ] Timestamp, notes
- [ ] Create `features/handover/domain/entities/comparison_result.dart`
  - [ ] Before/after photos, AI analysis, changes
- [ ] Create `features/handover/domain/repositories/handover_repository.dart`

### **Handover Use Cases - Move In**
- [ ] Create `features/handover/domain/usecases/move_in/create_handover.dart`
- [ ] Create `features/handover/domain/usecases/move_in/add_photo.dart`
- [ ] Create `features/handover/domain/usecases/move_in/annotate_defect.dart`
- [ ] Create `features/handover/domain/usecases/move_in/generate_report.dart`
  - [ ] PDF generation with watermarks
  - [ ] Crypto timestamps
- [ ] Create `features/handover/domain/usecases/move_in/send_to_landlord.dart`

### **Handover Use Cases - Agreement**
- [ ] Create `features/handover/domain/usecases/agreement/request_landlord_agreement.dart`
  - [ ] Send email/SMS/push notification
  - [ ] 7-day countdown
- [ ] Create `features/handover/domain/usecases/agreement/landlord_review.dart`
  - [ ] Landlord view interface
- [ ] Create `features/handover/domain/usecases/agreement/approve_report.dart`
  - [ ] Lock report as agreed
- [ ] Create `features/handover/domain/usecases/agreement/dispute_report.dart`
  - [ ] Open dispute flow
- [ ] Create `features/handover/domain/usecases/agreement/auto_lock_report.dart`
  - [ ] Auto-lock after 7 days

### **Handover Use Cases - Move Out**
- [ ] Create `features/handover/domain/usecases/move_out/create_comparison.dart`
- [ ] Create `features/handover/domain/usecases/move_out/ghost_overlay_capture.dart`
  - [ ] **Ghost overlay camera implementation**
  - [ ] Alignment detection
- [ ] Create `features/handover/domain/usecases/move_out/analyze_changes.dart`
  - [ ] AI damage detection (optional premium)
  - [ ] Change categorization
- [ ] Create `features/handover/domain/usecases/move_out/generate_comparison_report.dart`

### **Handover Use Cases - Dispute**
- [ ] Create `features/handover/domain/usecases/dispute/generate_dispute_letter.dart`
  - [ ] Legal template
  - [ ] Evidence attachment
- [ ] Create `features/handover/domain/usecases/dispute/calculate_fair_deduction.dart`
  - [ ] Compare damages
  - [ ] Normal wear vs actual damage
- [ ] Create `features/handover/domain/usecases/dispute/prepare_court_evidence.dart`
  - [ ] Evidence package
  - [ ] Court filing guide

### **Handover Data Layer**
- [ ] Create `features/handover/data/models/handover_model.dart`
- [ ] Create `features/handover/data/models/handover_photo_model.dart`
- [ ] Create `features/handover/data/models/defect_model.dart`
- [ ] Create `features/handover/data/models/agreement_model.dart`
- [ ] Create `features/handover/data/datasources/handover_remote_datasource.dart`
  - [ ] Firebase Storage for photos
  - [ ] Firestore for metadata
- [ ] Create `features/handover/data/datasources/handover_local_datasource.dart`
- [ ] Create `features/handover/data/datasources/pdf_generator_datasource.dart`
  - [ ] PDF creation
  - [ ] Watermarking
  - [ ] Crypto timestamps
- [ ] Create `features/handover/data/repositories/handover_repository_impl.dart`

### **Handover Presentation - Create Handover**
- [ ] Create `features/handover/presentation/screens/handover_dashboard_screen.dart`
  - [ ] List of handovers (move-in/move-out)
  - [ ] Agreement status
- [ ] Create `features/handover/presentation/screens/create_handover/room_selection_screen.dart`
  - [ ] Select rooms to document
  - [ ] Minimum photo requirements
- [ ] Create `features/handover/presentation/screens/create_handover/photo_capture_screen.dart`
  - [ ] Camera interface
  - [ ] Photo preview
  - [ ] Guidelines overlay
- [ ] Create `features/handover/presentation/screens/create_handover/defect_annotation_screen.dart`
  - [ ] **Annotation tools (Circle/Arrow/Text)**
  - [ ] Defect type selection
  - [ ] Severity selection
- [ ] Create `features/handover/presentation/screens/create_handover/review_screen.dart`
  - [ ] Review all photos
  - [ ] Defect summary
  - [ ] Add notes
- [ ] Create `features/handover/presentation/screens/create_handover/report_generation_screen.dart`
  - [ ] Loading progress
  - [ ] PDF preview
  - [ ] Share options

### **Handover Presentation - Move Out**
- [ ] Create `features/handover/presentation/screens/move_out/ghost_camera_screen.dart`
  - [ ] **Ghost overlay camera UI**
  - [ ] Opacity slider
  - [ ] Alignment indicator
  - [ ] Alignment score display
- [ ] Create `features/handover/presentation/screens/move_out/comparison_screen.dart`
  - [ ] Before/after side-by-side
  - [ ] Swipe overlay
  - [ ] Slider view
  - [ ] AI analysis results (if premium)
- [ ] Create `features/handover/presentation/screens/move_out/final_report_screen.dart`
  - [ ] Move-out report with comparisons
  - [ ] Damage summary
  - [ ] Suggested deductions

### **Handover Presentation - Agreement**
- [ ] Create `features/handover/presentation/screens/agreement/landlord_review_screen.dart`
  - [ ] Full report view for landlord
  - [ ] Agree/Dispute/Reject buttons
  - [ ] Add landlord notes
- [ ] Create `features/handover/presentation/screens/agreement/agreement_status_screen.dart`
  - [ ] **Status tracking (7-day countdown)**
  - [ ] Notification history
  - [ ] Lock status badge
- [ ] Create `features/handover/presentation/screens/agreement/dispute_resolution_screen.dart`
  - [ ] Dispute evidence comparison
  - [ ] Fair deduction calculator
  - [ ] Letter generator
  - [ ] Court guide

### **Handover Presentation - Detail**
- [ ] Create `features/handover/presentation/screens/handover_detail_screen.dart`
  - [ ] View completed handover
  - [ ] Download PDF
  - [ ] Share options
  - [ ] Verification QR code

### **Handover Widgets**
- [ ] Create `features/handover/presentation/widgets/photo_grid_widget.dart`
- [ ] Create `features/handover/presentation/widgets/ghost_overlay_camera_widget.dart`
  - [ ] **Core ghost overlay implementation**
  - [ ] Opacity control
  - [ ] Alignment helpers
- [ ] Create `features/handover/presentation/widgets/defect_annotation_tool_widget.dart`
  - [ ] **Circle tool**
  - [ ] **Arrow tool**
  - [ ] **Text tool**
  - [ ] Color picker
  - [ ] Undo/redo
- [ ] Create `features/handover/presentation/widgets/before_after_slider_widget.dart`
  - [ ] Image slider comparison
  - [ ] Swipe overlay
- [ ] Create `features/handover/presentation/widgets/agreement_status_widget.dart`
  - [ ] **7-day countdown timer**
  - [ ] Status badges
  - [ ] Lock icon
- [ ] Create `features/handover/presentation/widgets/countdown_timer_widget.dart`
  - [ ] Days/hours remaining
  - [ ] Warning states
- [ ] Create `features/handover/presentation/widgets/watermark_widget.dart`
  - [ ] Apply watermark to photos
  - [ ] Timestamp overlay

### **Handover Providers**
- [ ] Create `features/handover/presentation/providers/handover_provider.dart`
- [ ] Create `features/handover/presentation/providers/handover_flow_provider.dart`
  - [ ] Transient state for creating handover
- [ ] Create `features/handover/presentation/providers/photo_capture_provider.dart`
- [ ] Create `features/handover/presentation/providers/agreement_provider.dart`
  - [ ] Track agreement status
  - [ ] Countdown management
- [ ] Create `features/handover/presentation/providers/comparison_provider.dart`

### **Handover DI**
- [ ] Set up handover dependency injection
- [ ] Test complete handover flow

### **Handover Testing**
- [ ] Test move-in photo capture
- [ ] Test defect annotation
- [ ] Test PDF generation with watermarks
- [ ] Test landlord agreement flow (7-day countdown)
- [ ] Test auto-lock mechanism
- [ ] Test ghost overlay camera
- [ ] Test move-out comparison
- [ ] Test dispute tools

---

## 💰 PHASE 4: BILLS MIGRATION & ENHANCEMENT (Week 3)

### **Bills Domain Layer**
- [ ] Create `features/bills/domain/entities/bill.dart`
  - [ ] Migrate from existing SplitLah
  - [ ] Add property ID reference
- [ ] Create `features/bills/domain/entities/bill_item.dart`
  - [ ] Migrate from receipt_item
- [ ] Create `features/bills/domain/entities/bill_split.dart`
  - [ ] Split method, amounts per person
- [ ] Create `features/bills/domain/entities/payment.dart`
  - [ ] Payment status, method, date
- [ ] Create `features/bills/domain/entities/payment_method.dart`
  - [ ] Migrate from existing
- [ ] Create `features/bills/domain/entities/bill_enums.dart`
  - [ ] Migrate from existing
- [ ] Create `features/bills/domain/repositories/bill_repository.dart`
- [ ] Create `features/bills/domain/repositories/payment_repository.dart`

### **Bills Use Cases - Bills**
- [ ] Create `features/bills/domain/usecases/bills/create_bill.dart`
  - [ ] Migrate logic from existing
- [ ] Create `features/bills/domain/usecases/bills/update_bill.dart`
- [ ] Create `features/bills/domain/usecases/bills/delete_bill.dart`
- [ ] Create `features/bills/domain/usecases/bills/get_bill_by_id.dart`
  - [ ] Migrate from existing
- [ ] Create `features/bills/domain/usecases/bills/get_property_bills.dart`
  - [ ] Filter by property (new)

### **Bills Use Cases - Splitting**
- [ ] Create `features/bills/domain/usecases/splitting/calculate_equal_split.dart`
  - [ ] Migrate from existing
- [ ] Create `features/bills/domain/usecases/splitting/calculate_percentage_split.dart`
  - [ ] Migrate from existing
- [ ] Create `features/bills/domain/usecases/splitting/calculate_item_split.dart`
  - [ ] Migrate from existing
- [ ] Create `features/bills/domain/usecases/splitting/calculate_balances.dart`
  - [ ] Migrate from existing

### **Bills Use Cases - OCR**
- [ ] Create `features/bills/domain/usecases/ocr/scan_receipt.dart`
  - [ ] Camera integration
- [ ] Create `features/bills/domain/usecases/ocr/extract_receipt_data.dart`
  - [ ] Call OCR service
- [ ] Create `features/bills/domain/usecases/ocr/detect_bill_type.dart`
  - [ ] TNB, TM, Air Selangor detection

### **Bills Use Cases - Payments**
- [ ] Create `features/bills/domain/usecases/payments/mark_as_paid.dart`
  - [ ] **Fix payment persistence bug**
  - [ ] Update database (not just local state)
- [ ] Create `features/bills/domain/usecases/payments/send_reminder.dart`
  - [ ] Send notification/email/WhatsApp
- [ ] Create `features/bills/domain/usecases/payments/track_payment_status.dart`

### **Bills Data Layer**
- [ ] Create `features/bills/data/models/bill_model.dart`
  - [ ] Migrate from existing
- [ ] Create `features/bills/data/models/bill_item_model.dart`
  - [ ] Migrate from receipt_item_model
- [ ] Create `features/bills/data/models/payment_model.dart`
- [ ] Create `features/bills/data/models/receipt_ocr_result_model.dart`
- [ ] Create `features/bills/data/datasources/bill_remote_datasource.dart`
  - [ ] Firestore implementation
- [ ] Create `features/bills/data/datasources/bill_local_datasource.dart`
  - [ ] Migrate from existing
  - [ ] Fix payment update bug
- [ ] Create `features/bills/data/datasources/ocr_datasource.dart`
  - [ ] Google ML Kit integration
  - [ ] Cloud Vision API fallback
  - [ ] **Fix tax items filter bug**
- [ ] Create `features/bills/data/repositories/bill_repository_impl.dart`
  - [ ] Migrate & enhance from existing
- [ ] Create `features/bills/data/repositories/payment_repository_impl.dart`

### **Bills Presentation - Screens**
- [ ] Create `features/bills/presentation/screens/bills_dashboard_screen.dart`
  - [ ] Migrate from existing dashboard
  - [ ] Add property filter
- [ ] Create `features/bills/presentation/screens/bills_list_screen.dart`
  - [ ] Migrate from my_bills_screen
- [ ] Create `features/bills/presentation/screens/bill_detail_screen.dart`
  - [ ] Migrate from bill_summary_screen
- [ ] Migrate create bill flow screens:
  - [ ] `features/bills/presentation/screens/create_bill/bill_type_selection_screen.dart`
  - [ ] `features/bills/presentation/screens/create_bill/scan_receipt_screen.dart`
  - [ ] `features/bills/presentation/screens/create_bill/edit_items_screen.dart`
  - [ ] `features/bills/presentation/screens/create_bill/select_members_screen.dart`
  - [ ] `features/bills/presentation/screens/create_bill/split_method_screen.dart`
  - [ ] `features/bills/presentation/screens/create_bill/assign_splits_screen.dart`
  - [ ] `features/bills/presentation/screens/create_bill/payment_methods_screen.dart`
  - [ ] `features/bills/presentation/screens/create_bill/bill_summary_screen.dart`
- [ ] Migrate balance screens:
  - [ ] `features/bills/presentation/screens/you_owe_screen.dart`
    - [ ] **Fix payment persistence bug**
  - [ ] `features/bills/presentation/screens/owed_to_you_screen.dart`
  - [ ] `features/bills/presentation/screens/payment_history_screen.dart`

### **Bills Presentation - Widgets**
- [ ] Migrate widgets:
  - [ ] `features/bills/presentation/widgets/bill_card.dart`
  - [ ] `features/bills/presentation/widgets/bill_item_list.dart`
  - [ ] `features/bills/presentation/widgets/split_calculator_widget.dart`
  - [ ] `features/bills/presentation/widgets/payment_status_widget.dart`
  - [ ] `features/bills/presentation/widgets/ocr_preview_widget.dart`
  - [ ] `features/bills/presentation/widgets/balance_tree_widget.dart`
  - [ ] `features/bills/presentation/widgets/receipt_camera_widget.dart`

### **Bills Providers**
- [ ] Migrate providers:
  - [ ] `features/bills/presentation/providers/bill_provider.dart`
  - [ ] `features/bills/presentation/providers/bill_list_provider.dart`
  - [ ] `features/bills/presentation/providers/bill_flow_provider.dart`
  - [ ] `features/bills/presentation/providers/balance_provider.dart`
  - [ ] `features/bills/presentation/providers/ocr_provider.dart`

### **OCR Integration**
- [ ] Set up Google ML Kit
- [ ] Test on-device OCR with TNB bill
- [ ] Test on-device OCR with TM bill
- [ ] Test on-device OCR with Air Selangor bill
- [ ] Set up Cloud Vision API (backup)
- [ ] Test confidence scoring
- [ ] Test manual correction flow

### **Bills DI**
- [ ] Set up bills dependency injection
- [ ] Test complete bill creation flow
- [ ] Test payment marking (verify database persistence)
- [ ] Test OCR scanning

---

## 📊 PHASE 5: SCORES & CHORES (Week 4)

### **Scores Domain Layer**
- [ ] Create `features/scores/domain/entities/fiscal_score.dart`
  - [ ] Score value, tier, components
- [ ] Create `features/scores/domain/entities/harmony_score.dart`
  - [ ] Score value, tier, components
- [ ] Create `features/scores/domain/entities/score_component.dart`
  - [ ] Component name, value, max, weight
- [ ] Create `features/scores/domain/entities/score_history.dart`
  - [ ] Historical scores over time
- [ ] Create `features/scores/domain/entities/rental_resume.dart`
  - [ ] Resume data for PDF generation
- [ ] Create `features/scores/domain/repositories/score_repository.dart`

### **Scores Use Cases**
- [ ] Create `features/scores/domain/usecases/calculate_fiscal_score.dart`
  - [ ] **Implement fiscal score algorithm**
  - [ ] Payment punctuality (40%)
  - [ ] Payment consistency (25%)
  - [ ] Contribution fairness (20%)
  - [ ] Payment method reliability (10%)
  - [ ] Historical trend (5%)
- [ ] Create `features/scores/domain/usecases/calculate_harmony_score.dart`
  - [ ] **Implement harmony score algorithm**
  - [ ] Chore completion (35%)
  - [ ] Housemate ratings (30%)
  - [ ] House rule adherence (20%)
  - [ ] Tenure stability (10%)
  - [ ] Community contribution (5%)
- [ ] Create `features/scores/domain/usecases/get_score_breakdown.dart`
- [ ] Create `features/scores/domain/usecases/get_score_history.dart`
- [ ] Create `features/scores/domain/usecases/generate_rental_resume.dart`
  - [ ] PDF generation
- [ ] Create `features/scores/domain/usecases/update_privacy_settings.dart`

### **Scores Data Layer**
- [ ] Create `features/scores/data/models/fiscal_score_model.dart`
- [ ] Create `features/scores/data/models/harmony_score_model.dart`
- [ ] Create `features/scores/data/models/score_history_model.dart`
- [ ] Create `features/scores/data/datasources/score_remote_datasource.dart`
- [ ] Create `features/scores/data/datasources/score_local_datasource.dart`
- [ ] Create `features/scores/data/repositories/score_repository_impl.dart`

### **Scores Presentation**
- [ ] Create `features/scores/presentation/screens/scores_dashboard_screen.dart`
  - [ ] Both scores displayed
  - [ ] Quick stats
- [ ] Create `features/scores/presentation/screens/fiscal_score_detail_screen.dart`
  - [ ] Breakdown by component
  - [ ] Tips to improve
- [ ] Create `features/scores/presentation/screens/harmony_score_detail_screen.dart`
  - [ ] Breakdown by component
  - [ ] Tips to improve
- [ ] Create `features/scores/presentation/screens/score_history_screen.dart`
  - [ ] Graph over time
  - [ ] Trend analysis
- [ ] Create `features/scores/presentation/screens/rental_resume_screen.dart`
  - [ ] Resume preview
  - [ ] Download PDF
  - [ ] Share options

### **Scores Widgets**
- [ ] Create `features/scores/presentation/widgets/score_gauge_widget.dart`
  - [ ] Circular gauge
  - [ ] Color-coded by tier
- [ ] Create `features/scores/presentation/widgets/score_breakdown_widget.dart`
  - [ ] Component breakdown
  - [ ] Progress bars
- [ ] Create `features/scores/presentation/widgets/score_history_chart_widget.dart`
  - [ ] Line chart (fl_chart)
- [ ] Create `features/scores/presentation/widgets/resume_preview_widget.dart`
- [ ] Create `features/scores/presentation/widgets/privacy_settings_widget.dart`

### **Scores Providers**
- [ ] Create `features/scores/presentation/providers/fiscal_score_provider.dart`
- [ ] Create `features/scores/presentation/providers/harmony_score_provider.dart`
- [ ] Create `features/scores/presentation/providers/resume_provider.dart`

### **Scores DI**
- [ ] Set up scores dependency injection
- [ ] Test score calculation algorithms
- [ ] Test resume generation

---

### **Chores Domain Layer**
- [ ] Create `features/chores/domain/entities/chore.dart`
  - [ ] Name, frequency, points, assignment type
- [ ] Create `features/chores/domain/entities/chore_instance.dart`
  - [ ] Individual occurrence
  - [ ] Assigned to, due date, status
- [ ] Create `features/chores/domain/entities/chore_assignment.dart`
  - [ ] Assignment logic
- [ ] Create `features/chores/domain/entities/chore_verification.dart`
  - [ ] Photo, verified by, status
- [ ] Create `features/chores/domain/entities/chore_swap.dart`
  - [ ] Swap request details
- [ ] Create `features/chores/domain/repositories/chore_repository.dart`

### **Chores Use Cases**
- [ ] Create `features/chores/domain/usecases/create_chore.dart`
- [ ] Create `features/chores/domain/usecases/update_chore.dart`
- [ ] Create `features/chores/domain/usecases/delete_chore.dart`
- [ ] Create `features/chores/domain/usecases/assign_chore.dart`
- [ ] Create `features/chores/domain/usecases/complete_chore.dart`
  - [ ] Award points based on verification
- [ ] Create `features/chores/domain/usecases/verify_chore.dart`
- [ ] Create `features/chores/domain/usecases/request_swap.dart`
- [ ] Create `features/chores/domain/usecases/approve_swap.dart`
- [ ] Create `features/chores/domain/usecases/calculate_rotation.dart`
  - [ ] **Fair distribution algorithm**

### **Chores Data Layer**
- [ ] Create `features/chores/data/models/chore_model.dart`
- [ ] Create `features/chores/data/models/chore_instance_model.dart`
- [ ] Create `features/chores/data/models/chore_swap_model.dart`
- [ ] Create `features/chores/data/datasources/chore_remote_datasource.dart`
- [ ] Create `features/chores/data/datasources/chore_local_datasource.dart`
- [ ] Create `features/chores/data/repositories/chore_repository_impl.dart`

### **Chores Presentation**
- [ ] Create `features/chores/presentation/screens/chores_dashboard_screen.dart`
  - [ ] Today's chores
  - [ ] Your tasks vs housemates
  - [ ] Quick stats
- [ ] Create `features/chores/presentation/screens/chores_list_screen.dart`
  - [ ] All chores
  - [ ] Filter by status
- [ ] Create `features/chores/presentation/screens/chore_detail_screen.dart`
  - [ ] Chore info
  - [ ] Assignment history
  - [ ] Completion photos
- [ ] Create `features/chores/presentation/screens/create_chore_screen.dart`
  - [ ] Templates
  - [ ] Custom creation
- [ ] Create `features/chores/presentation/screens/chore_calendar_screen.dart`
  - [ ] Calendar view
  - [ ] Upcoming assignments
- [ ] Create `features/chores/presentation/screens/chore_statistics_screen.dart`
  - [ ] Monthly stats
  - [ ] Completion rates per person

### **Chores Widgets**
- [ ] Create `features/chores/presentation/widgets/chore_card.dart`
- [ ] Create `features/chores/presentation/widgets/chore_assignment_widget.dart`
- [ ] Create `features/chores/presentation/widgets/verification_photo_widget.dart`
- [ ] Create `features/chores/presentation/widgets/swap_request_dialog.dart`
- [ ] Create `features/chores/presentation/widgets/rotation_schedule_widget.dart`

### **Chores Providers**
- [ ] Create `features/chores/presentation/providers/chore_provider.dart`
- [ ] Create `features/chores/presentation/providers/chore_list_provider.dart`
- [ ] Create `features/chores/presentation/providers/chore_stats_provider.dart`

### **Chores DI**
- [ ] Set up chores dependency injection
- [ ] Test chore creation and assignment
- [ ] Test auto-rotation algorithm
- [ ] Test verification flow

---

## 🛒 PHASE 6: RESOURCES, MAINTENANCE, COMMUNITY (Week 4-5)

### **Resources Feature**
- [ ] Create domain layer (entities, repositories, use cases)
- [ ] Create data layer (models, datasources, repositories)
- [ ] Create presentation layer (screens, widgets, providers)
- [ ] Test resource tracking
- [ ] Test purchase logging
- [ ] Test contribution analytics

### **Maintenance Feature**
- [ ] Create domain layer (entities, repositories, use cases)
- [ ] Create data layer (models, datasources, repositories)
- [ ] Create presentation layer (screens, widgets, providers)
- [ ] Implement auto-escalation logic
- [ ] Test ticket creation
- [ ] Test escalation timing
- [ ] Test landlord rating

### **Community Feature**
- [ ] Create domain layer (entities, repositories, use cases)
- [ ] Create data layer (models, datasources, repositories)
- [ ] Create presentation layer (screens, widgets, providers)
- [ ] Test announcements
- [ ] Test Q&A (upvotes, best answer)
- [ ] Test polls
- [ ] Test events (RSVP)
- [ ] Test moderation tools

### **User Feature**
- [ ] Create domain layer (entities, repositories, use cases)
- [ ] Migrate from existing SplitLah users feature
- [ ] Create data layer (models, datasources, repositories)
- [ ] Create presentation layer (screens, widgets, providers)
- [ ] Test profile editing
- [ ] Test avatar upload
- [ ] Test friends management

### **Notifications Feature**
- [ ] Create domain layer (entities, repositories, use cases)
- [ ] Create data layer (models, datasources, repositories)
- [ ] Create presentation layer (screens, widgets, providers)
- [ ] Set up FCM
- [ ] Test push notifications
- [ ] Test local notifications
- [ ] Test notification settings

---

## 🧪 PHASE 7: TESTING & QUALITY ASSURANCE (Week 5-6)

### **Unit Tests**
- [ ] Write unit tests for core utilities
  - [ ] Validators
  - [ ] Formatters
  - [ ] Encryption
- [ ] Write unit tests for authentication use cases
- [ ] Write unit tests for property use cases
- [ ] Write unit tests for bills use cases
  - [ ] Split calculation tests
  - [ ] Balance calculation tests
- [ ] Write unit tests for handover use cases
  - [ ] Agreement logic tests
  - [ ] Auto-lock tests
- [ ] Write unit tests for scores use cases
  - [ ] Fiscal score algorithm tests
  - [ ] Harmony score algorithm tests
- [ ] Write unit tests for chores use cases
  - [ ] Rotation algorithm tests
- [ ] Aim for 80%+ coverage on business logic

### **Widget Tests**
- [ ] Test shared widgets
  - [ ] Buttons
  - [ ] Inputs
  - [ ] Cards
  - [ ] Dialogs
- [ ] Test authentication screens
- [ ] Test bills screens
- [ ] Test handover screens (critical)
- [ ] Test scores screens
- [ ] Aim for 60%+ coverage on UI

### **Integration Tests**
- [ ] Test authentication flow (login → OTP → profile)
- [ ] Test property creation flow
- [ ] Test bill creation flow (scan → edit → split → save)
  - [ ] Verify payment persistence fix
- [ ] Test handover creation flow (photos → annotate → generate → send)
- [ ] Test landlord agreement flow (request → review → lock)
- [ ] Test ghost overlay camera flow (move-out)
- [ ] Test chore creation and completion flow
- [ ] Test score calculation flow

### **Manual Testing**
- [ ] Test on Android device (real device + emulator)
- [ ] Test on different screen sizes
- [ ] Test offline functionality
  - [ ] Create bill offline
  - [ ] Sync when back online
- [ ] Test sync conflicts
- [ ] Test error scenarios
  - [ ] Network failure
  - [ ] Server error
  - [ ] Invalid data
- [ ] Test performance
  - [ ] App startup time (<3 seconds)
  - [ ] Screen navigation (<500ms)
  - [ ] Image loading
- [ ] Test memory usage
- [ ] Test battery consumption

### **Bug Fixing**
- [ ] Create bug tracking system (GitHub Issues or similar)
- [ ] Prioritize critical bugs
- [ ] Fix all critical bugs
- [ ] Fix major bugs
- [ ] Document known minor bugs

### **Code Quality**
- [ ] Run Flutter analyze
- [ ] Fix all errors
- [ ] Fix all warnings
- [ ] Run very_good_analysis linter
- [ ] Fix lint issues
- [ ] Format all code (`flutter format .`)
- [ ] Remove debug print statements
- [ ] Remove unused imports
- [ ] Remove dead code

---

## 🎨 PHASE 8: POLISH & DEPLOYMENT PREP (Week 6)

### **UI/UX Polish**
- [ ] Review all screens for consistency
- [ ] Consistent spacing across app
- [ ] Consistent colors (Residex branding)
- [ ] Consistent typography
- [ ] Add loading states everywhere
- [ ] Add empty states (no bills, no chores, etc.)
- [ ] Add error states
- [ ] Smooth animations (page transitions, micro-interactions)
- [ ] Add haptic feedback (button presses, success/error)
- [ ] Optimize images (compress, resize)
- [ ] Add app launcher icon (Residex logo)
- [ ] Add splash screen (Residex branding)

### **Performance Optimization**
- [ ] Profile app with DevTools
- [ ] Optimize expensive builds
- [ ] Add const constructors where possible
- [ ] Lazy load features
- [ ] Optimize image loading (cached_network_image)
- [ ] Reduce app size
  - [ ] Remove unused assets
  - [ ] Compress images
  - [ ] Enable code shrinking (ProGuard)

### **Analytics & Monitoring**
- [ ] Set up Firebase Analytics events
  - [ ] Screen views
  - [ ] Button clicks
  - [ ] Feature usage
  - [ ] Error events
- [ ] Set up Crashlytics
  - [ ] Catch and report errors
  - [ ] Add custom logs
- [ ] Set up Remote Config
  - [ ] Feature flags
  - [ ] Minimum supported version

### **Security Audit**
- [ ] Review all API keys (not in code)
- [ ] Verify encryption on sensitive data
- [ ] Verify secure storage usage
- [ ] Review permission requests
- [ ] Review data privacy compliance (PDPA)
- [ ] Add security headers (API)

### **Documentation**
- [ ] Update README.md
  - [ ] Project description
  - [ ] Setup instructions
  - [ ] Architecture overview
- [ ] Document API endpoints (if backend exists)
- [ ] Document database schema
- [ ] Create developer onboarding guide
- [ ] Document environment setup
- [ ] Document common issues and solutions

### **Demo Preparation**
- [ ] Create demo account with realistic data
  - [ ] 2-3 properties
  - [ ] 10+ bills
  - [ ] 3+ handovers (with landlord agreements)
  - [ ] 5+ chores
  - [ ] Scores calculated
- [ ] Create demo script (what to show)
- [ ] Practice demo (20+ times)
- [ ] Record demo video (2-3 minutes)
  - [ ] Showcase Digital Handover (ghost overlay + double-handshake)
  - [ ] Showcase Bill Splitter with OCR
  - [ ] Showcase Dual Scores
  - [ ] Showcase Chore Scheduler

### **App Store Preparation**
- [ ] Create app screenshots (5-7)
  - [ ] Digital Handover
  - [ ] Bill Splitter
  - [ ] Scores Dashboard
  - [ ] Chore Scheduler
- [ ] Write app description
  - [ ] Short (80 characters)
  - [ ] Long (4000 characters)
- [ ] Create feature graphic
- [ ] Prepare promotional text
- [ ] Create privacy policy URL
- [ ] Create terms of service URL

### **Beta Testing**
- [ ] Deploy to Firebase App Distribution
- [ ] Recruit 5-10 beta houses (25-50 users)
- [ ] Collect feedback via Google Forms
- [ ] Conduct user interviews
- [ ] Iterate based on feedback
- [ ] Fix critical issues
- [ ] Deploy updated beta build

### **Final Checks**
- [ ] Verify all Tier 1 features working
  - [ ] Authentication
  - [ ] Property Management
  - [ ] Digital Handover (with ghost overlay + double-handshake)
  - [ ] Bill Splitter + OCR
  - [ ] Dual Scores
  - [ ] Chore Scheduler
- [ ] Verify critical bugs fixed
  - [ ] Payment persistence
  - [ ] Tax filter
- [ ] Verify app compiles without errors
- [ ] Verify app runs on Android (emulator + device)
- [ ] App size < 50MB
- [ ] Startup time < 3 seconds
- [ ] Crash-free rate > 95%

---

## 🚢 DEPLOYMENT CHECKLIST (Post-Hackathon)

### **Firebase Production Setup**
- [ ] Create production Firebase project
- [ ] Set up production Firestore security rules
- [ ] Set up production Storage security rules
- [ ] Configure production API keys
- [ ] Set up Cloud Functions for production
- [ ] Enable billing (if needed)

### **Play Store Submission**
- [ ] Create Google Play Console account
- [ ] Create app listing
- [ ] Upload screenshots
- [ ] Upload app description
- [ ] Set up pricing & distribution
- [ ] Upload APK/App Bundle
- [ ] Submit for review

### **Post-Launch Monitoring**
- [ ] Monitor Crashlytics for crashes
- [ ] Monitor Analytics for usage
- [ ] Monitor user reviews
- [ ] Set up alerting for critical errors
- [ ] Plan first update

---

## 📝 NOTES & REMINDERS

### **Critical Path Items (Cannot Skip)**
1. Authentication (required for all features)
2. Property Management (foundation)
3. Digital Handover with Ghost Overlay + Double-Handshake (star feature, must demo)
4. Bills with OCR (existing strength, must enhance)
5. Dual Scores (core differentiator)
6. Fix payment persistence bug
7. Fix tax filter bug

### **Nice-to-Have (If Time Allows)**
- Resources feature
- Maintenance tickets feature
- Community board feature
- iOS support
- Web app

### **Future Enhancements (Post-Hackathon)**
- Visitor Pass Generator
- Guard Translation Chat
- Digital Rulebook
- Payment gateway integration (TNG, DuitNow)
- AI damage detection (premium)
- Landlord dashboard (B2B)
- Agency enterprise features

---

## 🎯 SUCCESS CRITERIA

**Minimum Viable Product (MVP) - Week 6:**
- [ ] 6+ core features working
- [ ] 0 critical bugs
- [ ] 5-10 beta houses using app
- [ ] 25-50 active users
- [ ] 20+ bills split
- [ ] 5+ handover reports (with landlord agreements)
- [ ] 100+ chores tracked
- [ ] Demo-ready for pitch

**Stretch Goals:**
- [ ] 8 core features working
- [ ] 10+ beta houses
- [ ] 50+ active users
- [ ] Resources or Maintenance feature working
- [ ] Community board working

---

**Last Updated:** January 10, 2026
**Total Tasks:** ~500+
**Estimated Completion:** 6 weeks (42 days)
**Team Size:** 2 developers

**Good luck! 🚀**
