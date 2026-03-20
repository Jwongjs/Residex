# Firebase Integration — Full To-Do List
*Residex App | Pre-existing Firebase Console*

> **Context:** Firebase console already exists but contains an outdated version of the codebase.
> Goal: Connect the current Flutter app to the existing project, replace all mock/Drift local data
> with live Firestore, set up Auth, Storage, and security rules.

---

## PHASE 0 — Audit Existing Firebase Console

Before touching any code, review the existing project state.

- [ ] **0.1** Log into Firebase console → confirm project ID and region
- [ ] **0.2** Check existing Firestore collections — document what's there and what's stale
- [ ] **0.3** Check existing Auth users — decide whether to keep or wipe them
- [ ] **0.4** Check Storage buckets — list existing folders
- [ ] **0.5** Check existing security rules — screenshot/copy them before overwriting
- [ ] **0.6** Check `google-services.json` (Android) and `GoogleService-Info.plist` (iOS/macOS) currently in the project — confirm they match the existing Firebase project ID
- [ ] **0.7** Decide: **wipe Firestore** and start fresh with correct schema, or **migrate** existing docs to new structure

---

## PHASE 1 — FlutterFire Setup & Configuration

### 1.1 — Install Firebase CLI + FlutterFire CLI

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Verify both are installed
firebase --version
flutterfire --version
```

- [ ] Firebase CLI installed and in PATH
- [ ] FlutterFire CLI installed and in PATH

### 1.2 — Authenticate and Link Project

```bash
firebase login
# Select your existing project when prompted
flutterfire configure
```

- [ ] Run `flutterfire configure` from the project root (`residex_app/`)
- [ ] Select the **existing** Firebase project (do NOT create a new one)
- [ ] Select target platforms: **Android**, **iOS**, **macOS**, **Windows** (as needed)
- [ ] Confirm `firebase_options.dart` is generated at `lib/firebase_options.dart`
- [ ] Confirm `google-services.json` is updated at `android/app/google-services.json`
- [ ] Confirm `GoogleService-Info.plist` is updated at `ios/Runner/GoogleService-Info.plist`

### 1.3 — Android Configuration Check

- [ ] Open `android/build.gradle` — confirm `google-services` classpath:
  ```groovy
  classpath 'com.google.gms:google-services:4.4.0'
  ```
- [ ] Open `android/app/build.gradle` — confirm plugin applied:
  ```groovy
  apply plugin: 'com.google.gms.google-services'
  ```
- [ ] `minSdkVersion` is **21** or higher (Firebase requires 21+)
- [ ] `AndroidManifest.xml` has `INTERNET` permission

### 1.4 — iOS / macOS Configuration Check (if targeting Apple)

- [ ] `GoogleService-Info.plist` is added to Xcode project (not just the folder)
- [ ] `ios/Podfile` platform is **iOS 12.0** or higher
- [ ] Run `cd ios && pod install` after adding packages

---

## PHASE 2 — Package Dependencies

Open `pubspec.yaml` and add the following under `dependencies`:

```yaml
dependencies:
  # Firebase core (required for all Firebase services)
  firebase_core: ^3.6.0

  # Authentication
  firebase_auth: ^5.3.1

  # Firestore database
  cloud_firestore: ^5.4.3

  # Storage (for move-in photos, maintenance attachments)
  firebase_storage: ^12.3.2

  # Cloud Messaging (push notifications — add later if needed)
  # firebase_messaging: ^15.1.3
```

- [ ] Add packages to `pubspec.yaml`
- [ ] Run `flutter pub get`
- [ ] Confirm no version conflicts with existing packages (especially Riverpod, GoRouter)
- [ ] Run `flutter analyze` — resolve any new warnings before proceeding

---

## PHASE 3 — Firebase Initialization

### 3.1 — Initialize in `main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: ResidexApp()));
}
```

- [ ] `WidgetsFlutterBinding.ensureInitialized()` is called before `Firebase.initializeApp()`
- [ ] `DefaultFirebaseOptions.currentPlatform` is imported from `firebase_options.dart`
- [ ] Hot restart (not hot reload) after this change — confirm app launches without crash

---

## PHASE 4 — Authentication

### 4.1 — Enable Auth Methods in Firebase Console

- [ ] Firebase Console → Authentication → Sign-in method
- [ ] Enable **Email/Password**
- [ ] (Optional) Enable **Google Sign-In** if needed later
- [ ] Set authorized domains if using web

### 4.2 — Create `AuthService`

Create `lib/core/services/auth_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user (sync)
  User? get currentUser => _auth.currentUser;

  // Register
  Future<UserCredential> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  // Login
  Future<UserCredential> loginWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  // Logout
  Future<void> signOut() => _auth.signOut();
}
```

- [ ] `AuthService` created at `lib/core/services/auth_service.dart`
- [ ] Riverpod provider created: `final authServiceProvider = Provider((_) => AuthService());`
- [ ] Auth state stream exposed: `final authStateProvider = StreamProvider((ref) => ref.watch(authServiceProvider).authStateChanges);`

### 4.3 — Connect Login Screen

File: `lib/features/auth/presentation/screens/login_screen.dart`

- [ ] Replace mock login logic with `AuthService.loginWithEmail(email, password)`
- [ ] Handle `FirebaseAuthException` — map error codes to user-readable messages:
  - `wrong-password` → "Incorrect password"
  - `user-not-found` → "No account found for this email"
  - `too-many-requests` → "Too many attempts. Try again later."
- [ ] Show loading state during auth call
- [ ] On success: navigate based on user role (see Phase 4.5)

### 4.4 — Connect Register Screen

File: `lib/features/auth/presentation/screens/register_screen.dart`

- [ ] Replace mock register with `AuthService.registerWithEmail(email, password)`
- [ ] After creating Auth user, write user doc to Firestore (see Phase 5.1)
- [ ] Set `displayName` via `user.updateDisplayName(name)`
- [ ] Handle `FirebaseAuthException` — `email-already-in-use`, `weak-password`

### 4.5 — Role-Based Routing After Login

- [ ] After login, read user doc from Firestore: `users/{uid}`
- [ ] Check `role` field: `'tenant'` or `'landlord'`
- [ ] Route accordingly:
  - Tenant → `/tenant-dashboard`
  - Landlord → `/landlord-home`
- [ ] Update `app_router.dart` redirect logic to check `authStateProvider`:
  - Unauthenticated → `/splash` or `/login`
  - Authenticated → role-based home

### 4.6 — Protect Routes

- [ ] Add `redirect` to GoRouter:
  ```dart
  redirect: (context, state) {
    final isLoggedIn = ref.read(authStateProvider).value != null;
    final isOnAuthPage = state.uri.toString().startsWith('/login') || ...;
    if (!isLoggedIn && !isOnAuthPage) return '/login';
    return null;
  },
  ```
- [ ] Test: unauthenticated user cannot access tenant/landlord screens

---

## PHASE 5 — Firestore Data Schema

### 5.1 — Collection: `users`

```
/users/{uid}
  - uid: string
  - name: string
  - email: string
  - role: 'tenant' | 'landlord'
  - avatarUrl: string?
  - propertyId: string?       // for tenants — which property they belong to
  - groupId: string?          // for tenants — housemate group
  - syncScore: int            // overall resident score
  - createdAt: timestamp
```

- [ ] Write user doc on registration
- [ ] Create `UserRepository` at `lib/features/shared/data/repositories/user_repository.dart`
- [ ] Methods: `getUser(uid)`, `updateUser(uid, data)`, `streamUser(uid)`

### 5.2 — Collection: `properties`

```
/properties/{propertyId}
  - landlordId: string        // uid of owning landlord
  - name: string
  - address: string
  - type: string              // 'apartment', 'house', etc.
  - unitCount: int
  - occupancyRate: double
  - monthlyRent: double
  - status: 'active' | 'vacant' | 'maintenance'
  - createdAt: timestamp
```

- [ ] Create in Firestore console (or via code on first landlord registration)
- [ ] `PropertyRepository`: `getProperties(landlordId)`, `addProperty()`, `updateProperty()`, `deleteProperty()`

### 5.3 — Collection: `groups`

```
/groups/{groupId}
  - propertyId: string
  - landlordId: string
  - name: string              // e.g. "Unit 4-2"
  - memberIds: string[]       // list of tenant uids
  - createdAt: timestamp
```

- [ ] `GroupRepository`: `getGroup(groupId)`, `addMember(groupId, uid)`, `removeMember()`

### 5.4 — Collection: `bills`

```
/bills/{billId}
  - groupId: string
  - createdBy: string         // uid
  - title: string
  - totalAmount: double
  - splitType: string         // 'equal' | 'item' | 'custom'
  - participants: map[]       // [{uid, amount, isPaid, paidAt}]
  - receiptItems: map[]
  - status: 'active' | 'settled'
  - createdAt: timestamp
```

- [ ] `BillRepository`: `getBills(groupId)`, `createBill()`, `markPaid(billId, uid)`, `settleBill()`
- [ ] Stream `bills` where groupId == currentGroupId

### 5.5 — Collection: `chores`

```
/chores/{choreId}
  - groupId: string
  - title: string
  - assignedTo: string        // uid
  - frequency: string         // 'daily' | 'weekly' | 'once'
  - dueDate: timestamp
  - isCompleted: bool
  - completedAt: timestamp?
  - createdAt: timestamp
```

- [ ] `ChoreRepository`: `getChores(groupId)`, `createChore()`, `completeChore(choreId)`, `reassignChore()`

### 5.6 — Collection: `maintenance_tickets`

```
/maintenance_tickets/{ticketId}
  - propertyId: string
  - groupId: string
  - reportedBy: string        // tenant uid
  - title: string
  - description: string
  - priority: 'low' | 'medium' | 'high' | 'urgent'
  - status: 'open' | 'in_progress' | 'resolved' | 'closed'
  - attachmentUrls: string[]  // Firebase Storage URLs
  - comments: subcollection
  - createdAt: timestamp
  - updatedAt: timestamp
```

**Subcollection:** `/maintenance_tickets/{ticketId}/comments/{commentId}`
```
  - authorId: string
  - text: string
  - createdAt: timestamp
```

- [ ] `MaintenanceRepository`: `getTickets(groupId)`, `createTicket()`, `updateStatus()`, `addComment()`

### 5.7 — Collection: `community_posts`

```
/community_posts/{postId}
  - groupId: string
  - authorId: string
  - type: 'general' | 'event' | 'market'
  - title: string
  - content: string
  - imageUrl: string?
  - reactions: map            // {'like': int, 'haha': int, ...}
  - userReactions: map        // {uid: reactionType}
  - commentCount: int
  - createdAt: timestamp
```

**Subcollection:** `/community_posts/{postId}/comments/{commentId}`

- [ ] `CommunityRepository`: `getPosts(groupId, type?)`, `createPost()`, `toggleReaction()`, `addComment()`

### 5.8 — Collection: `scores`

```
/scores/{uid}
  - uid: string
  - groupId: string
  - syncScore: int
  - billScore: int
  - choreScore: int
  - maintenanceScore: int
  - communityScore: int
  - events: subcollection
  - updatedAt: timestamp
```

- [ ] `ScoreRepository`: `getScore(uid)`, `streamLeaderboard(groupId)`, `addScoreEvent()`

### 5.9 — Collection: `move_in_sessions`

```
/move_in_sessions/{sessionId}
  - tenantId: string
  - propertyId: string
  - groupId: string
  - status: 'in_progress' | 'completed'
  - areas: map[]              // [{areaName, baselineUrl, currentUrl, analysisResult}]
  - createdAt: timestamp
  - completedAt: timestamp?
```

- [ ] Used by Ghost Overlay / FairFix Auditor feature

---

## PHASE 6 — Firebase Storage

### 6.1 — Enable Storage in Console

- [ ] Firebase Console → Storage → Get Started
- [ ] Choose region (same as Firestore — e.g. `asia-southeast1` for Malaysia)
- [ ] Note the bucket URL: `gs://your-project.appspot.com`

### 6.2 — Storage Folder Structure

```
/move_in_photos/{propertyId}/{tenantId}/{area}/
  baseline.jpg
  current.jpg

/maintenance_attachments/{ticketId}/
  attachment_0.jpg
  attachment_1.jpg

/community_posts/{postId}/
  image.jpg

/avatars/{uid}/
  profile.jpg
```

- [ ] Document the folder structure in a comment at the top of `StorageService`

### 6.3 — Create `StorageService`

Create `lib/core/services/storage_service.dart`:

```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref(path);
    final task = await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }
}
```

- [ ] `StorageService` created
- [ ] Riverpod provider: `final storageServiceProvider = Provider((_) => StorageService());`
- [ ] Connect to `GeminiService.analyzePropertyCondition()` — pass Firestore URLs instead of raw bytes where possible

---

## PHASE 7 — Replace Mock Data With Firestore

Work through each feature screen. For each one:
1. Find the `static const _mock...` data inside the screen or provider
2. Replace with a Firestore stream/future from the corresponding repository
3. Show loading state while data loads
4. Handle empty state (no docs yet)

### Priority Order

- [ ] **7.1** `users` → `UserRepository` (needed by almost everything)
- [ ] **7.2** `properties` → `PropertyRepository` (landlord portfolio)
- [ ] **7.3** `groups` → `GroupRepository` (needed by bills, chores, community)
- [ ] **7.4** `bills` → `BillRepository`
- [ ] **7.5** `chores` → `ChoreRepository`
- [ ] **7.6** `maintenance_tickets` → `MaintenanceRepository`
- [ ] **7.7** `community_posts` → `CommunityRepository`
- [ ] **7.8** `scores` → `ScoreRepository`
- [ ] **7.9** `move_in_sessions` → link Ghost Overlay photo uploads to Storage

### Riverpod Pattern for Firestore Streams

```dart
// In provider file:
final billsProvider = StreamProvider.family<List<Bill>, String>((ref, groupId) {
  return ref.watch(billRepositoryProvider).getBills(groupId);
});

// In screen:
final billsAsync = ref.watch(billsProvider(currentGroupId));
return billsAsync.when(
  data: (bills) => BillList(bills: bills),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

- [ ] Apply this pattern across all feature providers
- [ ] Remove all `Future.delayed` mock loading fakes
- [ ] Remove all `static const _mock...` data

---

## PHASE 8 — Security Rules

### 8.1 — Firestore Rules

In Firebase Console → Firestore → Rules, deploy:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: check if user is authenticated
    function isAuth() {
      return request.auth != null;
    }

    // Helper: get user role
    function userRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }

    // Helper: check if user belongs to a group
    function isGroupMember(groupId) {
      return request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.memberIds;
    }

    // Users — can only read/write own doc
    match /users/{uid} {
      allow read: if isAuth();
      allow write: if isAuth() && request.auth.uid == uid;
    }

    // Properties — landlord owns, tenants can read their own
    match /properties/{propertyId} {
      allow read: if isAuth();
      allow write: if isAuth() && userRole() == 'landlord' &&
                   resource.data.landlordId == request.auth.uid;
      allow create: if isAuth() && userRole() == 'landlord';
    }

    // Groups — members can read, landlord can write
    match /groups/{groupId} {
      allow read: if isAuth() && (
        isGroupMember(groupId) ||
        resource.data.landlordId == request.auth.uid
      );
      allow write: if isAuth() && userRole() == 'landlord';
    }

    // Bills — group members only
    match /bills/{billId} {
      allow read, write: if isAuth() && isGroupMember(resource.data.groupId);
      allow create: if isAuth() && isGroupMember(request.resource.data.groupId);
    }

    // Chores — group members only
    match /chores/{choreId} {
      allow read, write: if isAuth() && isGroupMember(resource.data.groupId);
      allow create: if isAuth() && isGroupMember(request.resource.data.groupId);
    }

    // Maintenance tickets — group members + landlord
    match /maintenance_tickets/{ticketId} {
      allow read: if isAuth() && (
        isGroupMember(resource.data.groupId) ||
        userRole() == 'landlord'
      );
      allow create: if isAuth() && isGroupMember(request.resource.data.groupId);
      allow update: if isAuth() && (
        isGroupMember(resource.data.groupId) ||
        userRole() == 'landlord'
      );
      match /comments/{commentId} {
        allow read, create: if isAuth() && (
          isGroupMember(get(/databases/$(database)/documents/maintenance_tickets/$(ticketId)).data.groupId) ||
          userRole() == 'landlord'
        );
      }
    }

    // Community posts — group members only
    match /community_posts/{postId} {
      allow read, write: if isAuth() && isGroupMember(resource.data.groupId);
      allow create: if isAuth() && isGroupMember(request.resource.data.groupId);
      match /comments/{commentId} {
        allow read, create: if isAuth();
      }
    }

    // Scores — authenticated users can read, only system writes (or self)
    match /scores/{uid} {
      allow read: if isAuth();
      allow write: if isAuth() && request.auth.uid == uid;
    }

    // Move-in sessions
    match /move_in_sessions/{sessionId} {
      allow read, write: if isAuth() && (
        resource.data.tenantId == request.auth.uid ||
        userRole() == 'landlord'
      );
      allow create: if isAuth();
    }
  }
}
```

- [ ] Paste rules into Firebase Console → Firestore → Rules
- [ ] Click **Publish**
- [ ] Test rules using the **Rules Playground** in the console

### 8.2 — Storage Rules

In Firebase Console → Storage → Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Move-in photos — tenant who owns + landlord
    match /move_in_photos/{propertyId}/{tenantId}/{area}/{file} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == tenantId;
    }

    // Maintenance attachments — authenticated users
    match /maintenance_attachments/{ticketId}/{file} {
      allow read, write: if request.auth != null;
    }

    // Community post images
    match /community_posts/{postId}/{file} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Avatars — user can write their own
    match /avatars/{uid}/{file} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

- [ ] Paste into Firebase Console → Storage → Rules → Publish

---

## PHASE 9 — Firestore Indexes

Composite indexes are needed for multi-field queries. Set them up as you encounter `failed-precondition` errors in debug — Firebase will provide a direct link to create the index.

Common indexes to pre-create:

- [ ] `bills` — composite: `groupId ASC`, `createdAt DESC`
- [ ] `chores` — composite: `groupId ASC`, `dueDate ASC`
- [ ] `maintenance_tickets` — composite: `groupId ASC`, `createdAt DESC`
- [ ] `community_posts` — composite: `groupId ASC`, `type ASC`, `createdAt DESC`
- [ ] `scores` — composite: `groupId ASC`, `syncScore DESC`

To create: Firebase Console → Firestore → Indexes → Add Index

---

## PHASE 10 — Wipe / Migrate Stale Data in Console

- [ ] **10.1** Export any data you want to keep from the old console (Firestore → Import/Export)
- [ ] **10.2** Delete all stale collections that don't match the new schema
- [ ] **10.3** Manually create 1 test landlord user (via Auth + users doc) to verify landlord flow
- [ ] **10.4** Manually create 1 test tenant user, link to a group and property
- [ ] **10.5** Manually insert 2-3 test bills, 2-3 chores, 1 maintenance ticket — confirm they appear in app

---

## PHASE 11 — Gemini API Key Security

Currently `gemini_api_key.dart` is hardcoded in the client. This is a security risk.

- [ ] **Option A (quick):** Move to `.env` + `flutter_dotenv` package — keep out of source control
- [ ] **Option B (secure):** Move Gemini calls to **Cloud Functions** — client calls function, function calls Gemini with server-side key
- [ ] Add `gemini_api_key.dart` to `.gitignore` immediately if not already there
- [ ] Rotate the API key if it has already been committed to git history

---

## PHASE 12 — Testing Checklist

Run through each user flow end-to-end:

### Auth
- [ ] Register new tenant → user doc created in Firestore → routed to tenant dashboard
- [ ] Register new landlord → user doc created → routed to landlord home
- [ ] Login → correct role → correct home screen
- [ ] Logout → redirected to login screen
- [ ] Unauthenticated deep link → redirected to login

### Tenant Flows
- [ ] Dashboard loads real group/property data
- [ ] Create bill → appears in Firestore → visible to housemates
- [ ] Mark bill paid → Firestore updated
- [ ] Create chore → assigned to member → completion updates score
- [ ] Submit maintenance ticket → appears for landlord
- [ ] Post to community board → visible to group members
- [ ] Score leaderboard reflects real Firestore scores

### Landlord Flows
- [ ] Portfolio shows real properties from Firestore
- [ ] Maintenance tickets visible (tenant-submitted)
- [ ] Community posts manageable
- [ ] REX AI chat works (Gemini — unchanged)

### Storage
- [ ] Move-in photo upload → stored in `move_in_photos/` → URL saved in Firestore
- [ ] GeminiService receives bytes from Storage URL for analysis
- [ ] Maintenance attachment upload → stored in `maintenance_attachments/`

---

## PHASE 13 — Production Readiness (Post-MVP)

- [ ] Enable **App Check** (Firebase console → App Check) to prevent API abuse
- [ ] Set up **Firebase Crashlytics** for crash reporting: `firebase_crashlytics: ^4.1.3`
- [ ] Set up **Firebase Analytics**: `firebase_analytics: ^11.3.3`
- [ ] Configure **Firebase Cloud Messaging** for push notifications
- [ ] Set Firestore to **production mode** (rules locked down — already done in Phase 8)
- [ ] Review Storage quota and set lifecycle rules for old photos
- [ ] Set up billing alerts on Firebase console (Spark → Blaze plan if Storage/Functions needed)

---

## Quick Reference — Key Files to Create/Modify

| File | Action |
|------|--------|
| `lib/firebase_options.dart` | Auto-generated by `flutterfire configure` |
| `lib/main.dart` | Add `Firebase.initializeApp()` |
| `lib/core/services/auth_service.dart` | Create |
| `lib/core/services/storage_service.dart` | Create |
| `lib/core/di/injection.dart` | Register new service providers |
| `lib/features/shared/data/repositories/user_repository.dart` | Create |
| `lib/features/landlord/data/repositories/property_repository.dart` | Replace mock |
| `lib/features/bills/data/repositories/bill_repository_impl.dart` | Replace mock |
| `lib/features/chores/data/repositories/chore_repository.dart` | Replace mock |
| `lib/features/maintenance/data/repositories/maintenance_repository.dart` | Replace mock |
| `lib/features/community/data/repositories/community_repository_impl.dart` | Replace mock |
| `lib/features/scores/data/repositories/score_repository_impl.dart` | Replace mock |
| `lib/features/auth/presentation/screens/login_screen.dart` | Connect to AuthService |
| `lib/features/auth/presentation/screens/register_screen.dart` | Connect to AuthService |
| `lib/core/router/app_router.dart` | Add auth redirect logic |
| `android/app/google-services.json` | Updated by FlutterFire CLI |
| `ios/Runner/GoogleService-Info.plist` | Updated by FlutterFire CLI |

---

## Recommended Execution Order

```
Phase 0  → Audit console (30 min)
Phase 1  → FlutterFire setup (1 hour)
Phase 2  → Packages (15 min)
Phase 3  → Firebase init in main.dart (15 min)
Phase 4  → Auth (2-3 hours)
Phase 5  → Design Firestore schema (1 hour — do on paper first)
Phase 8  → Security rules (1 hour — set early, avoids headaches)
Phase 6  → Storage service (1 hour)
Phase 7  → Replace mock data feature by feature (largest chunk — 1-2 days)
Phase 9  → Indexes as needed (ongoing)
Phase 10 → Wipe/migrate stale data (1 hour)
Phase 11 → API key security (1 hour)
Phase 12 → Full test pass (2-3 hours)
Phase 13 → Production hardening (after launch)
```

---

*Generated: Feb 28, 2026 | Residex App — Pravin's-Branch*
