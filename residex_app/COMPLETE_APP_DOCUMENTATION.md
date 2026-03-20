# SplitLah - Complete App Documentation
## Comprehensive Line-by-Line System Analysis

**Version:** 1.0.0+1
**Author:** Bill Splitter Team
**Last Updated:** December 2025
**Purpose:** This document provides a complete technical analysis of the SplitLah bill-splitting application for study and understanding.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [Data Models](#data-models)
4. [State Management](#state-management)
5. [Navigation & Routing](#navigation--routing)
6. [Screens & UI Components](#screens--ui-components)
7. [Services & Utilities](#services--utilities)
8. [Theme & Styling](#theme--styling)
9. [Widgets & Reusable Components](#widgets--reusable-components)
10. [Bill Creation Flow](#bill-creation-flow)
11. [Group Management](#group-management)
12. [Payment Tracking](#payment-tracking)

---

## Architecture Overview

### Design Pattern
SplitLah uses the **Provider Pattern** for state management, following Flutter's recommended approach for medium-to-large applications.

### Key Architectural Principles

1. **Single Source of Truth**: `AppState` is the central state provider
2. **Unidirectional Data Flow**: UI → Actions → State → UI
3. **Separation of Concerns**: Models, Views, and Business Logic are separated
4. **Declarative UI**: Flutter's reactive framework rebuilds UI when state changes

### Technology Stack

```yaml
Framework: Flutter 3.10+
Language: Dart
State Management: Provider (^6.0.5)
Navigation: go_router (^14.2.0)
Animations: flutter_animate (^4.5.2)
Icons: lucide_icons (^0.257.0)
Storage: shared_preferences (^2.2.2)
Camera: camera (^0.11.0)
```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data structures
│   ├── app_models.dart               # Core app models (AppUser, Bill, etc.)
│   ├── bill_model.dart               # Detailed bill model
│   ├── member_model.dart             # Member/user model
│   └── quick_group_model.dart        # Quick group model
├── providers/                         # State management
│   └── app_state.dart                # Central app state (424 lines)
├── router/                            # Navigation
│   └── app_router.dart               # Route definitions & animations
├── screens/                           # UI screens (14 screens)
│   ├── dashboard_screen.dart         # Main dashboard
│   ├── select_members_screen.dart    # Member selection
│   ├── scan_camera_screen.dart       # Receipt scanning
│   ├── edit_receipt_screen.dart      # Receipt editing
│   ├── assign_items_screen.dart      # Item assignment
│   ├── bill_summary_screen.dart      # Bill summary with pie chart
│   ├── you_owe_screen.dart           # Debts owed by user
│   ├── owed_to_you_screen.dart       # Money owed to user
│   ├── payment_history_screen.dart   # Payment history
│   ├── my_bills_screen.dart          # All bills
│   ├── member_selection_screen.dart  # Advanced member selector
│   ├── quick_split_flow.dart         # Quick split workflow
│   ├── profile_screen.dart           # User profile
│   └── splash_screen.dart            # Splash screen
├── services/                          # Business logic
│   └── group_storage_service.dart    # Group persistence
├── theme/                             # Design system
│   └── app_theme.dart                # Colors, text styles, gradients
└── widgets/                           # Reusable components
    ├── glass_card.dart               # Glassmorphic cards
    ├── avatar_widget.dart            # User avatars
    ├── splitlah_loader.dart          # Loading animation
    ├── add_member_modal.dart         # Add member dialog
    ├── group_editor_modal.dart       # Group editor dialog
    └── toast_notification.dart       # Toast messages
```

---

## Data Models

### 1. AppUser (`lib/models/app_models.dart`)

```dart
class AppUser {
  final String id;                    // Unique identifier (e.g., 'u1')
  final String name;                  // Display name (e.g., 'Ali Rahman')
  final String avatarInitials;        // 2-letter initials (e.g., 'AL')
  final List<Color> gradientColors;   // Avatar gradient colors
}
```

**Purpose**: Represents a user in the app
**Usage**: Current user, friends, bill participants
**Key Features**:
- Immutable data structure
- Gradient colors for visual identity
- Initials for avatar display

### 2. Member (`lib/models/member_model.dart`)

```dart
class Member {
  final String id;                    // Contact ID or UUID
  final String name;                  // Full name
  final String phoneNumber;           // For WhatsApp sharing
  final String avatarInitials;        // Auto-generated initials
  final String? profileImage;         // Optional profile picture
  final Color color;                  // Avatar background color
  final bool isCurrentUser;           // Is this the logged-in user?
  final bool isGuest;                 // Manually added guest?
}
```

**Purpose**: Enhanced user model with phone number support
**Key Methods**:
- `generateInitials(String name)` - Creates 2-letter initials
- `generateColor(String name)` - Deterministic color from name hash
- `isValidPhone(String phone)` - Validates phone (min 8 digits)
- `formattedPhone` - Returns formatted phone number

**Usage Example**:
```dart
final member = Member(
  id: 'friend_1',
  name: 'Sarah Tan',
  phoneNumber: '+60198765432',
  avatarInitials: Member.generateInitials('Sarah Tan'), // 'ST'
  color: Member.generateColor('Sarah Tan'),
);
```

### 3. Bill (`lib/models/app_models.dart`)

```dart
class Bill {
  final String id;                    // Unique bill ID
  final String title;                 // Bill name (e.g., 'Mamak Session')
  final String location;              // Location (e.g., 'Restoran')
  final double totalAmount;           // Total bill amount (RM)
  final double userShare;             // Current user's share
  final String date;                  // Display date (e.g., 'Nov 20')
  final BillStatus status;            // pending or settled
  final int participantsCount;        // Number of people
  final String? imageUrl;             // Category photo path
}

enum BillStatus { pending, settled }
```

**Purpose**: Simplified bill display model
**Usage**: Dashboard, bill lists, history
**Note**: This is a view model - detailed bill data is in `DetailedBill`

### 4. DetailedBill (`lib/models/bill_model.dart`)

```dart
class DetailedBill {
  final String id;                           // UUID
  final String title;                        // Bill name
  final String location;                     // Location
  final double totalAmount;                  // Total (RM)
  final String? photoPath;                   // Receipt photo
  final String? categoryImage;               // Category image
  final DateTime createdAt;                  // Creation timestamp
  final String createdBy;                    // Creator user ID
  final PaymentMethod? paymentMethod;        // E-wallet used

  // Participants
  final List<String> participantIds;         // List of user IDs
  final Map<String, double> participantShares; // ID → Amount owed
  final Map<String, bool> paymentStatus;     // ID → Has paid?

  // Items
  final List<ReceiptItem> items;             // Scanned items
}
```

**Purpose**: Complete bill data structure
**Key Features**:
- Tracks individual participant shares
- Payment status per participant
- Receipt items with assignments
- E-wallet payment method

**Usage Flow**:
```
1. Create bill with participants
2. Scan/add items
3. Assign items to participants
4. Calculate shares
5. Track payment status
```

### 5. ReceiptItem (`lib/models/app_models.dart`)

```dart
class ReceiptItem {
  final String id;                    // Item ID
  final String name;                  // Item name (e.g., 'Roti Canai')
  final double price;                 // Price per unit (RM)
  final int quantity;                 // Number of items
  List<String> assignedTo;            // User IDs who share this item
}
```

**Purpose**: Represents an item on a receipt
**Splitting Logic**:
```dart
// Example: RM 10 item shared by 3 people
final itemCost = item.price * item.quantity;  // RM 10
final perPerson = itemCost / item.assignedTo.length;  // RM 3.33 each
```

### 6. AppGroup (`lib/models/app_models.dart`)

```dart
class AppGroup {
  final String id;                    // Group ID (e.g., 'g1')
  final String name;                  // Group name (e.g., 'Mamak Gang')
  final List<String> memberIds;       // Member IDs (excluding current user!)
  final String emoji;                 // Group icon (e.g., '🍔')
  final Color color;                  // Group theme color
}
```

**Purpose**: Quick group for frequently used combinations
**Important**: `memberIds` does NOT include current user (always selected)
**Usage**: One-tap select multiple friends

### 7. QuickGroup (`lib/models/quick_group_model.dart`)

```dart
class QuickGroup {
  final String id;                    // Unique ID
  final String name;                  // Group name
  final String emoji;                 // Icon emoji
  final Color color;                  // Theme color
  final List<String> memberIds;       // Members (without current user)
  final String createdBy;             // Creator ID
}
```

**Purpose**: Persisted quick groups (similar to AppGroup)
**Storage**: Uses SharedPreferences via GroupStorageService
**Available Emojis**: 32 emojis (🍕, 🍛, 🏠, 🏸, ✈️, etc.)
**Available Colors**: 8 colors (Slate, Blue, Emerald, Purple, etc.)

### 8. PaymentMethod (`lib/models/bill_model.dart`)

```dart
enum PaymentMethod {
  touchNGo,      // Touch 'n Go eWallet
  grabPay,       // GrabPay
  boost,         // Boost
  shopeePay,     // ShopeePay
  maybank,       // Maybank
  cimb,          // CIMB Bank
  rhb,           // RHB Bank
  cash,          // Cash payment
  other,         // Other method
}
```

**Purpose**: Malaysian e-wallet and payment methods
**Display**: Shows logo/icon for each payment method
**Usage**: Selected during bill summary

---

## State Management

### AppState Provider (`lib/providers/app_state.dart`)

#### Overview
`AppState` is the single source of truth for the entire app. It extends `ChangeNotifier` and uses the Provider pattern for reactive state updates.

```dart
class AppState extends ChangeNotifier {
  // ... state variables

  // Notify listeners after state change
  void someMethod() {
    // Update state
    notifyListeners(); // Triggers UI rebuild
  }
}
```

#### State Variables

```dart
// User & Friends
AppUser _currentUser;                    // Logged-in user
List<AppUser> _friends;                  // Friend list (11 sample friends)

// Groups
List<AppGroup> _groups;                  // Quick groups (3 default groups)

// Bills
List<Bill> _bills;                       // All bills (display models)
List<DetailedBill> _detailedBills;       // Full bill data

// Current Bill Flow (temporary state during creation)
List<ReceiptItem> _scannedItems;         // Items from receipt scan
List<AppUser> _billParticipants;         // Selected participants
Assignment _billAssignments;             // Item → Users mapping
```

#### Key Methods

##### 1. User Management

```dart
AppUser get currentUser => _currentUser;
List<AppUser> get friends => List.unmodifiable(_friends);

AppUser? getUserById(String id) {
  // Returns user by ID or null
}
```

##### 2. Group Management

```dart
List<AppGroup> get groups => List.unmodifiable(_groups);

void addGroup(AppGroup group) {
  _groups.add(group);
  notifyListeners();  // Update UI
}
```

**Important Fix**: Groups do NOT store current user ID in `memberIds`!

```dart
// ✅ Correct: Current user excluded
final group = AppGroup(
  memberIds: ['u2', 'u3'],  // Only other members
);

// ❌ Wrong: Includes current user
final group = AppGroup(
  memberIds: ['u1', 'u2', 'u3'],  // u1 = current user (wrong!)
);
```

##### 3. Bill Creation Flow

```dart
// Step 1: Select members
void setBillParticipants(List<AppUser> participants) {
  _billParticipants = participants;
  notifyListeners();
}

// Step 2: Scan receipt
void setScannedItems(List<ReceiptItem> items) {
  _scannedItems = items;
  notifyListeners();
}

// Step 3: Assign items
void updateBillAssignments(Assignment assignments) {
  _billAssignments = assignments;
  notifyListeners();
}

// Step 4: Create bill
void createBill({
  required String title,
  required String location,
  String? photoPath,
  PaymentMethod? paymentMethod,
}) {
  // Calculate shares from assignments
  final shares = _calculateSharesFromAssignments();

  // Create DetailedBill
  final bill = DetailedBill(
    id: uuid.v4(),
    title: title,
    location: location,
    participantIds: _billParticipants.map((u) => u.id).toList(),
    participantShares: shares,
    items: _scannedItems,
    // ... more fields
  );

  _detailedBills.add(bill);
  _clearBillFlow();  // Reset temporary state
  notifyListeners();
}

void _clearBillFlow() {
  _scannedItems = [];
  _billParticipants = [];
  _billAssignments = {};
}
```

##### 4. Share Calculation

```dart
Map<String, double> _calculateSharesFromAssignments() {
  final shares = <String, double>{};

  // Initialize all participants with 0
  for (final user in _billParticipants) {
    shares[user.id] = 0.0;
  }

  // Calculate share for each item
  for (final item in _scannedItems) {
    final itemTotal = item.price * item.quantity;
    final splitCount = item.assignedTo.length;

    if (splitCount > 0) {
      final perPerson = itemTotal / splitCount;

      for (final userId in item.assignedTo) {
        shares[userId] = (shares[userId] ?? 0) + perPerson;
      }
    }
  }

  return shares;
}
```

**Example**:
```
Item: Roti Canai (RM 10) × 3 qty = RM 30
Assigned to: ['u1', 'u2', 'u3'] (3 people)
Per person: RM 30 ÷ 3 = RM 10 each

Result:
{
  'u1': 10.00,
  'u2': 10.00,
  'u3': 10.00,
}
```

##### 5. Payment Tracking

```dart
// Mark user as paid
void markAsPaid(String billId, String userId) {
  final bill = _getDetailedBillById(billId);
  if (bill != null) {
    bill.paymentStatus[userId] = true;
    notifyListeners();
  }
}

// Mark user as unpaid
void markAsUnpaid(String billId, String userId) {
  final bill = _getDetailedBillById(billId);
  if (bill != null) {
    bill.paymentStatus[userId] = false;
    notifyListeners();
  }
}
```

##### 6. Dashboard Calculations

```dart
// Calculate total amount user owes
double get youOwe {
  double total = 0;
  for (final bill in _detailedBills) {
    if (!bill.isFullySettled && !bill.isCreatedByCurrentUser) {
      final myShare = bill.participantShares[currentUser.id] ?? 0;
      final isPaid = bill.paymentStatus[currentUser.id] ?? false;

      if (!isPaid) {
        total += myShare;
      }
    }
  }
  return total;
}

// Calculate total amount owed to user
double get owedToYou {
  double total = 0;
  for (final bill in _detailedBills) {
    if (bill.isCreatedByCurrentUser) {
      for (final userId in bill.participantIds) {
        if (userId != currentUser.id) {
          final share = bill.participantShares[userId] ?? 0;
          final isPaid = bill.paymentStatus[userId] ?? false;

          if (!isPaid) {
            total += share;
          }
        }
      }
    }
  }
  return total;
}

// Get bills where user owes money
List<DetailedBill> get youOweBills {
  return _detailedBills.where((bill) {
    final myShare = bill.participantShares[currentUser.id] ?? 0;
    final isPaid = bill.paymentStatus[currentUser.id] ?? false;
    return myShare > 0 && !isPaid;
  }).toList();
}

// Get bills where others owe user
List<DetailedBill> get owedToYouBills {
  return _detailedBills.where((bill) {
    if (!bill.isCreatedByCurrentUser) return false;

    // Check if anyone owes money
    return bill.participantIds.any((userId) {
      if (userId == currentUser.id) return false;
      final share = bill.participantShares[userId] ?? 0;
      final isPaid = bill.paymentStatus[userId] ?? false;
      return share > 0 && !isPaid;
    });
  }).toList();
}
```

---

## Navigation & Routing

### AppRouter (`lib/router/app_router.dart`)

#### Route Definitions

```dart
class AppRoutes {
  // Main routes
  static const splash = '/';
  static const dashboard = '/dashboard';
  static const profile = '/profile';

  // Bill creation flow
  static const selectMembers = '/select-members';
  static const scanCamera = '/scan-camera';
  static const editReceipt = '/edit-receipt';
  static const assignItems = '/assign-items';
  static const billSummary = '/bill-summary';

  // Bill viewing
  static const myBills = '/my-bills';
  static const youOwe = '/you-owe';
  static const owedToYou = '/owed-to-you';
  static const paymentHistory = '/payment-history';
}
```

#### Router Configuration

```dart
final router = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.billSummary,
      builder: (context, state) {
        final billId = state.extra as String;
        return BillSummaryScreen(billId: billId);
      },
    ),
    // ... more routes
  ],

  // Custom page transition
  pageBuilder: (context, state, child) {
    return CustomTransitionPage(
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
    );
  },
);
```

#### Navigation Usage

```dart
// Push new route
context.push(AppRoutes.selectMembers);

// Push with data
context.push(AppRoutes.billSummary, extra: billId);

// Pop back
context.pop();

// Replace current route
context.go(AppRoutes.dashboard);
```

---

## Screens & UI Components

### 1. DashboardScreen (`lib/screens/dashboard_screen.dart`)

#### Purpose
Main home screen showing:
- Total amounts (You Owe, Owed to You)
- Recent bills
- Quick actions

#### Key Components

```dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          AmbientBackground(),    // Gradient background
          Column(
            children: [
              _buildHeader(),          // User info + profile button
              _buildSummaryCards(),    // You Owe / Owed to You cards
              _buildRecentBills(),     // Recent bills list
            ],
          ),
          _buildFloatingActionButton(),  // + button (create bill)
        ],
      ),
    );
  }
}
```

#### Summary Cards

```dart
Widget _buildSummaryCards() {
  return Row(
    children: [
      // You Owe card (red)
      GlassContainer(
        color: Colors.red.withOpacity(0.1),
        child: Column(
          children: [
            Icon(LucideIcons.arrowUpRight, color: Colors.red),
            Text('You Owe'),
            Text('RM ${appState.youOwe.toStringAsFixed(2)}'),
          ],
        ),
        onTap: () => context.push(AppRoutes.youOwe),
      ),

      // Owed to You card (green)
      GlassContainer(
        color: Colors.green.withOpacity(0.1),
        child: Column(
          children: [
            Icon(LucideIcons.arrowDownLeft, color: Colors.green),
            Text('Owed To You'),
            Text('RM ${appState.owedToYou.toStringAsFixed(2)}'),
          ],
        ),
        onTap: () => context.push(AppRoutes.owedToYou),
      ),
    ],
  );
}
```

#### Recent Bills List

```dart
Widget _buildRecentBills() {
  final bills = appState.recentBills;

  return ListView.builder(
    itemCount: bills.length,
    itemBuilder: (context, index) {
      final bill = bills[index];

      return GlassContainer(
        child: Row(
          children: [
            // Bill image
            if (bill.imageUrl != null)
              Image.asset(bill.imageUrl!, width: 60, height: 60),

            // Bill info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title),
                Text(bill.location),
                Text(bill.date),
              ],
            ),

            Spacer(),

            // Amount
            Text('RM ${bill.totalAmount.toStringAsFixed(2)}'),

            // Details button
            ElevatedButton(
              onPressed: () {
                context.push(AppRoutes.billSummary, extra: bill.id);
              },
              child: Text('Details'),
            ),
          ],
        ),
      );
    },
  );
}
```

### 2. SelectMembersScreen (`lib/screens/select_members_screen.dart`)

#### Purpose
Select participants for a bill

#### State Management

```dart
class _SelectMembersScreenState extends State<SelectMembersScreen> {
  final Set<String> _selectedUserIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Always include current user
    final appState = context.read<AppState>();
    _selectedUserIds.add(appState.currentUser.id);
  }
}
```

#### Member Selection Logic

```dart
void _toggleUser(String userId) {
  final appState = context.read<AppState>();

  // Don't allow deselecting current user
  if (userId == appState.currentUser.id) return;

  setState(() {
    if (_selectedUserIds.contains(userId)) {
      _selectedUserIds.remove(userId);
    } else {
      _selectedUserIds.add(userId);
    }
  });
}
```

#### Group Selection Logic

```dart
void _toggleGroup(AppGroup group) {
  final appState = context.read<AppState>();

  setState(() {
    // Check if all group members are selected
    final allSelected = group.memberIds.every(
      (id) => _selectedUserIds.contains(id)
    );

    if (allSelected) {
      // Deselect all (except current user)
      for (final memberId in group.memberIds) {
        if (memberId != appState.currentUser.id) {
          _selectedUserIds.remove(memberId);
        }
      }
    } else {
      // Select all
      _selectedUserIds.addAll(group.memberIds);
    }
  });
}
```

**Critical Fix**: Groups don't include current user in `memberIds`, so this logic works correctly!

### 3. ScanCameraScreen (`lib/screens/scan_camera_screen.dart`)

#### Purpose
Scan receipt using device camera

#### Camera Initialization

```dart
class _ScanCameraScreenState extends State<ScanCameraScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
    );

    await _cameraController!.initialize();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
```

#### Capture Photo

```dart
Future<void> _capturePhoto() async {
  if (_cameraController == null || !_cameraController!.value.isInitialized) {
    return;
  }

  try {
    final XFile photo = await _cameraController!.takePicture();

    // Navigate to edit receipt with photo
    context.push(AppRoutes.editReceipt, extra: photo.path);
  } catch (e) {
    print('Error capturing photo: $e');
  }
}
```

### 4. EditReceiptScreen (`lib/screens/edit_receipt_screen.dart`)

#### Purpose
Edit scanned receipt items

#### State

```dart
class _EditReceiptScreenState extends State<EditReceiptScreen> {
  final String? photoPath;
  List<ReceiptItem> _items = [];

  void _addItem() {
    setState(() {
      _items.add(ReceiptItem(
        id: uuid.v4(),
        name: '',
        price: 0,
        quantity: 1,
        assignedTo: [],
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, ReceiptItem item) {
    setState(() {
      _items[index] = item;
    });
  }
}
```

#### Item Input Fields

```dart
Widget _buildItemCard(int index, ReceiptItem item) {
  return GlassContainer(
    child: Column(
      children: [
        // Item name
        TextField(
          initialValue: item.name,
          decoration: InputDecoration(labelText: 'Item Name'),
          onChanged: (value) {
            _updateItem(index, item.copyWith(name: value));
          },
        ),

        Row(
          children: [
            // Price
            Expanded(
              child: TextField(
                initialValue: item.price.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Price (RM)'),
                onChanged: (value) {
                  _updateItem(index, item.copyWith(
                    price: double.tryParse(value) ?? 0
                  ));
                },
              ),
            ),

            SizedBox(width: 16),

            // Quantity
            Expanded(
              child: TextField(
                initialValue: item.quantity.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Qty'),
                onChanged: (value) {
                  _updateItem(index, item.copyWith(
                    quantity: int.tryParse(value) ?? 1
                  ));
                },
              ),
            ),
          ],
        ),

        // Remove button
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () => _removeItem(index),
        ),
      ],
    ),
  );
}
```

#### Continue to Assignment

```dart
void _continue() {
  // Validate items
  if (_items.isEmpty) {
    showToast(context, 'Please add at least one item');
    return;
  }

  // Save items to AppState
  final appState = context.read<AppState>();
  appState.setScannedItems(_items);

  // Navigate to item assignment
  context.push(AppRoutes.assignItems);
}
```

### 5. AssignItemsScreen (`lib/screens/assign_items_screen.dart`)

#### Purpose
Assign receipt items to participants

#### Assignment State

```dart
class _AssignItemsScreenState extends State<AssignItemsScreen> {
  // Assignment = Map<ItemId, Set<UserId>>
  final Map<String, Set<String>> _assignments = {};

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();

    // Initialize assignments (all items to no one)
    for (final item in appState.scannedItems) {
      _assignments[item.id] = {};
    }
  }
}
```

#### Toggle Assignment

```dart
void _toggleAssignment(String itemId, String userId) {
  setState(() {
    final assignedUsers = _assignments[itemId] ?? {};

    if (assignedUsers.contains(userId)) {
      assignedUsers.remove(userId);
    } else {
      assignedUsers.add(userId);
    }

    _assignments[itemId] = assignedUsers;
  });
}
```

#### Quick Actions

```dart
// Assign all items to everyone (split equally)
void _assignAllToEveryone() {
  final appState = context.read<AppState>();

  setState(() {
    for (final item in appState.scannedItems) {
      _assignments[item.id] = Set.from(
        appState.billParticipants.map((u) => u.id)
      );
    }
  });
}

// Assign all items to current user
void _assignAllToMe() {
  final appState = context.read<AppState>();

  setState(() {
    for (final item in appState.scannedItems) {
      _assignments[item.id] = {appState.currentUser.id};
    }
  });
}

// Clear all assignments
void _clearAll() {
  setState(() {
    for (final itemId in _assignments.keys) {
      _assignments[itemId] = {};
    }
  });
}
```

#### Item Assignment UI

```dart
Widget _buildAssignmentList() {
  final appState = context.read<AppState>();

  return ListView.builder(
    itemCount: appState.scannedItems.length,
    itemBuilder: (context, index) {
      final item = appState.scannedItems[index];
      final assignedUsers = _assignments[item.id] ?? {};

      return GlassContainer(
        child: Column(
          children: [
            // Item info
            Row(
              children: [
                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                Spacer(),
                Text('RM ${(item.price * item.quantity).toStringAsFixed(2)}'),
              ],
            ),

            SizedBox(height: 12),

            // Participant chips
            Wrap(
              spacing: 8,
              children: appState.billParticipants.map((user) {
                final isAssigned = assignedUsers.contains(user.id);

                return GestureDetector(
                  onTap: () => _toggleAssignment(item.id, user.id),
                  child: Chip(
                    avatar: AvatarWidget(user: user, size: 24),
                    label: Text(user.name),
                    backgroundColor: isAssigned
                        ? AppColors.primaryCyan
                        : AppColors.surface,
                  ),
                );
              }).toList(),
            ),

            // Split info
            if (assignedUsers.isNotEmpty)
              Text(
                'RM ${((item.price * item.quantity) / assignedUsers.length).toStringAsFixed(2)} per person',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      );
    },
  );
}
```

#### Finish Assignment

```dart
void _continue() {
  final appState = context.read<AppState>();

  // Update items with assignments
  final updatedItems = appState.scannedItems.map((item) {
    return item.copyWith(
      assignedTo: _assignments[item.id]!.toList(),
    );
  }).toList();

  appState.setScannedItems(updatedItems);
  appState.updateBillAssignments(_assignments);

  // Navigate to summary
  context.push(AppRoutes.billSummary);
}
```

### 6. BillSummaryScreen (`lib/screens/bill_summary_screen.dart`)

#### Purpose
Final bill summary with:
- Pie chart visualization
- Individual shares
- Payment tracking
- Payment method selection

#### Pie Chart Data

```dart
class _BillSummaryScreenState extends State<BillSummaryScreen> {
  final String billId;

  List<PieChartData> _getPieChartData(DetailedBill bill) {
    final appState = context.read<AppState>();
    final data = <PieChartData>[];

    for (final userId in bill.participantIds) {
      final user = appState.getUserById(userId);
      if (user == null) continue;

      final share = bill.participantShares[userId] ?? 0;
      if (share <= 0) continue;

      data.add(PieChartData(
        label: user.name,
        value: share,
        color: user.gradientColors.first,
      ));
    }

    return data;
  }
}
```

#### Pie Chart Widget

```dart
Widget _buildPieChart(List<PieChartData> data) {
  return CustomPaint(
    size: Size(200, 200),
    painter: PieChartPainter(data),
  );
}

class PieChartPainter extends CustomPainter {
  final List<PieChartData> data;

  PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    double startAngle = -pi / 2;

    for (final item in data) {
      final sweepAngle = (item.value / total) * 2 * pi;

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

#### Participant Shares List

```dart
Widget _buildSharesList(DetailedBill bill) {
  final appState = context.read<AppState>();

  return ListView.builder(
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    itemCount: bill.participantIds.length,
    itemBuilder: (context, index) {
      final userId = bill.participantIds[index];
      final user = appState.getUserById(userId);
      if (user == null) return SizedBox.shrink();

      final share = bill.participantShares[userId] ?? 0;
      final isPaid = bill.paymentStatus[userId] ?? false;
      final percentage = (share / bill.totalAmount * 100).toStringAsFixed(1);

      return GlassContainer(
        child: Row(
          children: [
            // Avatar
            AvatarWidget(user: user, size: 40),

            SizedBox(width: 12),

            // Name & percentage
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name),
                  Text('$percentage%', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

            // Amount
            Text(
              'RM ${share.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green : Colors.red,
              ),
            ),

            SizedBox(width: 12),

            // Payment toggle
            Checkbox(
              value: isPaid,
              onChanged: (value) {
                if (value == true) {
                  appState.markAsPaid(bill.id, userId);
                } else {
                  appState.markAsUnpaid(bill.id, userId);
                }
              },
            ),
          ],
        ),
      );
    },
  );
}
```

#### Payment Method Selection

```dart
Widget _buildPaymentMethodSelector(DetailedBill bill) {
  return Wrap(
    spacing: 8,
    children: PaymentMethod.values.map((method) {
      final isSelected = bill.paymentMethod == method;

      return GestureDetector(
        onTap: () {
          final appState = context.read<AppState>();
          appState.updateBillPaymentMethod(bill.id, method);
        },
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryCyan.withOpacity(0.2)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryCyan
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Image.asset(
                _getPaymentMethodLogo(method),
                width: 32,
                height: 32,
              ),
              SizedBox(height: 4),
              Text(_getPaymentMethodName(method)),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

String _getPaymentMethodLogo(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.touchNGo:
      return 'assets/logos/touchngo.png';
    case PaymentMethod.grabPay:
      return 'assets/logos/grabpay.png';
    // ... more cases
    default:
      return 'assets/logos/default.png';
  }
}
```

### 7. YouOweScreen (`lib/screens/you_owe_screen.dart`)

#### Purpose
Shows bills where current user owes money

#### Bill Calculation

```dart
Widget build(BuildContext context) {
  final appState = context.watch<AppState>();
  final owedBills = appState.youOweBills;
  final currentUserId = appState.currentUser.id;

  return Scaffold(
    body: ListView.builder(
      itemCount: owedBills.length,
      itemBuilder: (context, index) {
        final bill = owedBills[index];
        final myShare = bill.participantShares[currentUserId] ?? 0;

        return _buildBillCard(context, bill, myShare, index, appState);
      },
    ),
  );
}
```

#### Bill Card

```dart
Widget _buildBillCard(
  BuildContext context,
  bill,
  double amount,
  int index,
  AppState appState,
) {
  return GestureDetector(
    onTap: () {
      context.push(AppRoutes.billSummary, extra: bill.id);
    },
    child: GlassContainer(
      child: Column(
        children: [
          Row(
            children: [
              // Bill info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.title),
                    Text(bill.location, style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              // Amount owed (red)
              Text(
                'RM ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          Row(
            children: [
              Icon(LucideIcons.calendar, size: 12, color: Colors.grey),
              SizedBox(width: 4),
              Text(bill.formattedDate),

              Spacer(),

              // Pending badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('PENDING'),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Details button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                context.push(AppRoutes.billSummary, extra: bill.id);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Details'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

### 8. OwedToYouScreen (`lib/screens/owed_to_you_screen.dart`)

#### Purpose
Shows bills where others owe current user money

#### Bill Calculation

```dart
Widget build(BuildContext context) {
  final appState = context.watch<AppState>();
  final owedBills = appState.owedToYouBills;
  final currentUserId = appState.currentUser.id;

  return Scaffold(
    body: ListView.builder(
      itemCount: owedBills.length,
      itemBuilder: (context, index) {
        final bill = owedBills[index];

        // Calculate total owed to user from this bill
        double totalOwed = 0;
        for (final participantId in bill.participantIds) {
          if (participantId != currentUserId) {
            final share = bill.participantShares[participantId] ?? 0;
            final isPaid = bill.paymentStatus[participantId] ?? false;

            if (!isPaid && share > 0) {
              totalOwed += share;
            }
          }
        }

        return _buildBillCard(context, bill, totalOwed, index, appState);
      },
    ),
  );
}
```

**Logic Explanation**:
- Current user created the bill
- Loop through all participants (except current user)
- If participant hasn't paid, add their share to `totalOwed`
- Display total amount owed to current user from this bill

### 9. PaymentHistoryScreen (`lib/screens/payment_history_screen.dart`)

#### Purpose
Shows all bills with filtering

#### Filter Types

```dart
enum PaymentFilter {
  all,          // All bills
  youPaid,      // Bills you paid
  youReceived,  // Money you received
  youOwe,       // Bills you still owe
}
```

#### Payment Type Calculation

```dart
Widget build(BuildContext context) {
  final appState = context.watch<AppState>();
  final currentUserId = appState.currentUser.id;

  // Convert bills to payment entries
  final allPayments = appState.completedBills.map((bill) {
    final myShare = bill.participantShares[currentUserId] ?? 0;
    final isPaid = bill.paymentStatus[currentUserId] ?? false;

    String type;
    if (isPaid && myShare > 0) {
      type = 'paid';        // User paid their share
    } else if (!isPaid && myShare > 0) {
      type = 'owe';         // User owes money
    } else {
      // Check if others owe this user
      final othersOwe = bill.participantIds.any((id) {
        if (id == currentUserId) return false;
        final share = bill.participantShares[id] ?? 0;
        final paid = bill.paymentStatus[id] ?? false;
        return !paid && share > 0;
      });
      type = othersOwe ? 'received' : 'settled';
    }

    return {
      'id': bill.id,
      'title': bill.title,
      'location': bill.location,
      'amount': myShare,
      'type': type,
      'date': bill.createdAt,
      'participants': bill.participantIds.length,
    };
  }).toList();
}
```

#### Filter Logic

```dart
class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  PaymentFilter _selectedFilter = PaymentFilter.all;

  List<Map<String, dynamic>> _getFilteredPayments(List<Map<String, dynamic>> allPayments) {
    return allPayments.where((payment) {
      switch (_selectedFilter) {
        case PaymentFilter.youPaid:
          return payment['type'] == 'paid';
        case PaymentFilter.youReceived:
          return payment['type'] == 'received';
        case PaymentFilter.youOwe:
          return payment['type'] == 'owe';
        case PaymentFilter.all:
        default:
          return true;
      }
    }).toList();
  }
}
```

---

## Services & Utilities

### GroupStorageService (`lib/services/group_storage_service.dart`)

#### Purpose
Persist quick groups using SharedPreferences

#### Methods

```dart
class GroupStorageService {
  static const String _groupsKey = 'quick_groups';

  // Save groups to local storage
  static Future<void> saveGroups(List<QuickGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = groups.map((g) => g.toJson()).toList();
    await prefs.setString(_groupsKey, jsonEncode(jsonList));
  }

  // Load groups from local storage
  static Future<List<QuickGroup>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_groupsKey);

    if (jsonString == null) {
      // First launch: save and return sample groups
      await saveGroups(sampleGroups);
      return sampleGroups;
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => QuickGroup.fromJson(json)).toList();
    } catch (e) {
      // Parse error: return sample groups
      return sampleGroups;
    }
  }

  // Add a new group
  static Future<void> addGroup(QuickGroup group) async {
    final groups = await loadGroups();
    groups.add(group);
    await saveGroups(groups);
  }

  // Update existing group
  static Future<void> updateGroup(QuickGroup updatedGroup) async {
    final groups = await loadGroups();
    final index = groups.indexWhere((g) => g.id == updatedGroup.id);

    if (index != -1) {
      groups[index] = updatedGroup;
      await saveGroups(groups);
    }
  }

  // Delete a group
  static Future<void> deleteGroup(String groupId) async {
    final groups = await loadGroups();
    groups.removeWhere((g) => g.id == groupId);
    await saveGroups(groups);
  }

  // Check for duplicate groups (same members)
  static Future<QuickGroup?> findDuplicateGroup(List<String> memberIds) async {
    final groups = await loadGroups();

    for (final group in groups) {
      if (_areListsEqual(group.memberIds, memberIds)) {
        return group;
      }
    }

    return null;
  }

  // Helper: Compare lists (order doesn't matter)
  static bool _areListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;

    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);

    return set1.difference(set2).isEmpty &&
           set2.difference(set1).isEmpty;
  }
}
```

#### Usage Example

```dart
// Load groups on app start
final groups = await GroupStorageService.loadGroups();

// Save new group
await GroupStorageService.addGroup(newGroup);

// Check for duplicates
final duplicate = await GroupStorageService.findDuplicateGroup(['u2', 'u3']);
if (duplicate != null) {
  print('Group "${duplicate.name}" already exists!');
}
```

---

## Theme & Styling

### AppTheme (`lib/theme/app_theme.dart`)

#### Color Palette

```dart
class AppColors {
  // Background
  static const background = Color(0xFF020617);       // Dark blue-black
  static const surface = Color(0xFF0F172A);          // Slightly lighter
  static const surfaceLight = Color(0xFF1E293B);     // Card background

  // Slate variations
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  // Primary colors
  static const primaryCyan = Color(0xFF22D3EE);      // Main accent
  static const primaryBlue = Color(0xFF3B82F6);      // Secondary accent

  // Status colors
  static const success = Color(0xFF10B981);          // Green
  static const warning = Color(0xFFF59E0B);          // Amber
  static const error = Color(0xFFEF4444);            // Red

  // Text colors
  static const textPrimary = Color(0xFFFFFFFF);      // White
  static const textSecondary = Color(0xFF94A3B8);    // Gray
  static const textMuted = Color(0xFF64748B);        // Muted gray
}
```

#### Gradients

```dart
class AppColors {
  // Button gradient
  static const buttonGradient = LinearGradient(
    colors: [primaryCyan, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Avatar gradients (6 variations)
  static const avatarGradients = [
    [Color(0xFF22D3EE), Color(0xFF3B82F6)],  // Cyan → Blue
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],  // Pink → Purple
    [Color(0xFFF59E0B), Color(0xFFEF4444)],  // Amber → Red
    [Color(0xFF10B981), Color(0xFF059669)],  // Emerald → Green
    [Color(0xFF6366F1), Color(0xFF4F46E5)],  // Indigo → Indigo
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],  // Purple → Purple
  ];
}
```

#### Text Styles

```dart
class AppTextStyles {
  // Headings
  static const displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body text
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  // Labels
  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
}
```

#### Theme Configuration

```dart
ThemeData get appTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,

  // Color scheme
  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryCyan,
    secondary: AppColors.primaryBlue,
    surface: AppColors.surface,
    background: AppColors.background,
    error: AppColors.error,
  ),

  // Text theme
  textTheme: TextTheme(
    displayLarge: AppTextStyles.displayLarge,
    titleLarge: AppTextStyles.titleLarge,
    bodyLarge: AppTextStyles.bodyLarge,
    bodyMedium: AppTextStyles.bodyMedium,
  ),

  // App bar theme
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: AppTextStyles.titleLarge,
  ),

  // Card theme
  cardTheme: CardTheme(
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
  ),
);
```

---

## Widgets & Reusable Components

### 1. GlassContainer (`lib/widgets/glass_card.dart`)

#### Purpose
Glassmorphic card with frosted glass effect

#### Implementation

```dart
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  const GlassContainer({
    Key? key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? AppColors.slate800.withOpacity(0.4),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

#### Usage

```dart
GlassContainer(
  child: Column(
    children: [
      Text('Hello'),
      Text('World'),
    ],
  ),
)
```

### 2. AvatarWidget (`lib/widgets/avatar_widget.dart`)

#### Purpose
User avatar with gradient background and initials

#### Implementation

```dart
class AvatarWidget extends StatelessWidget {
  final AppUser user;
  final double size;
  final bool showBorder;

  const AvatarWidget({
    Key? key,
    required this.user,
    this.size = 40,
    this.showBorder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: user.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          user.avatarInitials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
```

### 3. SplitLahLoader (`lib/widgets/splitlah_loader.dart`)

#### Purpose
Custom loading animation with branding

#### Implementation

```dart
class SplitLahLoader extends StatefulWidget {
  final double size;

  const SplitLahLoader({Key? key, this.size = 100}) : super(key: key);

  @override
  State<SplitLahLoader> createState() => _SplitLahLoaderState();
}

class _SplitLahLoaderState extends State<SplitLahLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: LoaderPainter(_animation.value),
        );
      },
    );
  }
}

class LoaderPainter extends CustomPainter {
  final double progress;

  LoaderPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw rotating arc
    final paint = Paint()
      ..color = AppColors.primaryCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final startAngle = progress * 2 * pi;
    const sweepAngle = pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

### 4. AddMemberModal (`lib/widgets/add_member_modal.dart`)

#### Purpose
Dialog to manually add a guest member

#### Implementation

```dart
void showAddMemberModal({
  required BuildContext context,
  required Function(Member) onAdd,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddMemberModalContent(onAdd: onAdd),
  );
}

class _AddMemberModalContent extends StatefulWidget {
  final Function(Member) onAdd;

  const _AddMemberModalContent({required this.onAdd});

  @override
  State<_AddMemberModalContent> createState() => _AddMemberModalContentState();
}

class _AddMemberModalContentState extends State<_AddMemberModalContent> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    if (!Member.isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    final member = Member(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phoneNumber: phone,
      avatarInitials: Member.generateInitials(name),
      color: Member.generateColor(name),
      isGuest: true,
    );

    widget.onAdd(member);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Guest', style: AppTextStyles.titleLarge),
            SizedBox(height: 24),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Enter full name',
              ),
            ),

            SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+60123456789',
              ),
            ),

            SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addMember,
                child: Text('Add Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5. ToastNotification (`lib/widgets/toast_notification.dart`)

#### Purpose
Show temporary toast messages

#### Implementation

```dart
class ToastOverlay {
  static void show(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isSuccess: isSuccess,
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after duration
    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;

  const _ToastWidget({
    required this.message,
    required this.isSuccess,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GlassContainer(
            color: widget.isSuccess
                ? AppColors.success.withOpacity(0.2)
                : AppColors.error.withOpacity(0.2),
            child: Row(
              children: [
                Icon(
                  widget.isSuccess
                      ? Icons.check_circle
                      : Icons.error,
                  color: widget.isSuccess
                      ? AppColors.success
                      : AppColors.error,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

#### Usage

```dart
// Success toast
ToastOverlay.show(context, 'Bill created successfully!');

// Error toast
ToastOverlay.show(
  context,
  'Failed to create bill',
  isSuccess: false,
);
```

---

## Bill Creation Flow

### Complete Flow Overview

```
1. Dashboard
   ↓ (Tap + button)
2. Select Members
   ↓ (Select participants → Continue)
3. Scan Camera
   ↓ (Take photo / Pick from gallery)
4. Edit Receipt
   ↓ (Add/edit items → Continue)
5. Assign Items
   ↓ (Assign items to people → Continue)
6. Bill Summary
   ↓ (Enter details → Create Bill)
7. Dashboard (Updated)
```

### Detailed Step-by-Step

#### Step 1: Select Members

```dart
// In SelectMembersScreen
void _continue() {
  final appState = context.read<AppState>();

  // Collect selected members
  final selectedUsers = <AppUser>[];
  for (final userId in _selectedUserIds) {
    final user = appState.getUserById(userId);
    if (user != null) {
      selectedUsers.add(user);
    }
  }

  // Save to AppState
  appState.setBillParticipants(selectedUsers);

  // Navigate to camera
  context.push(AppRoutes.scanCamera);
}
```

#### Step 2: Scan Receipt

```dart
// In ScanCameraScreen
Future<void> _capturePhoto() async {
  final photo = await _cameraController!.takePicture();

  // Navigate with photo path
  context.push(AppRoutes.editReceipt, extra: photo.path);
}
```

#### Step 3: Edit Receipt

```dart
// In EditReceiptScreen
class _EditReceiptScreenState extends State<EditReceiptScreen> {
  final String? photoPath;
  List<ReceiptItem> _items = [];

  void _continue() {
    final appState = context.read<AppState>();
    appState.setScannedItems(_items);

    context.push(AppRoutes.assignItems);
  }
}
```

#### Step 4: Assign Items

```dart
// In AssignItemsScreen
class _AssignItemsScreenState extends State<AssignItemsScreen> {
  final Map<String, Set<String>> _assignments = {};

  void _continue() {
    final appState = context.read<AppState>();

    // Update items with assignments
    final updatedItems = appState.scannedItems.map((item) {
      return item.copyWith(
        assignedTo: _assignments[item.id]!.toList(),
      );
    }).toList();

    appState.setScannedItems(updatedItems);
    appState.updateBillAssignments(_assignments);

    context.push(AppRoutes.billSummary);
  }
}
```

#### Step 5: Create Bill

```dart
// In BillSummaryScreen
void _createBill() {
  final appState = context.read<AppState>();

  appState.createBill(
    title: _titleController.text,
    location: _locationController.text,
    photoPath: _photoPath,
    paymentMethod: _selectedPaymentMethod,
  );

  // Show success message
  ToastOverlay.show(context, 'Bill created successfully!');

  // Navigate to dashboard
  context.go(AppRoutes.dashboard);
}
```

---

## Group Management

### Creating a Group

#### From Select Members Screen

```dart
// User selects members, then clicks "Save as Group"
void _openGroupEditor() {
  showGroupEditorModal(
    context: context,
    selectedMembers: _selectedMembers,
    currentUserId: currentUser.id,
    onSave: (group) async {
      await GroupStorageService.addGroup(group);
      await _loadQuickGroups();
    },
  );
}
```

#### Group Editor Modal

```dart
class GroupEditorModal extends StatefulWidget {
  final List<Member> selectedMembers;
  final String currentUserId;
  final Function(QuickGroup) onSave;

  // ...
}

class _GroupEditorModalState extends State<GroupEditorModal> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '🍛';
  Color _selectedColor = groupColors[4];

  void _saveGroup() {
    final group = QuickGroup(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      emoji: _selectedEmoji,
      color: _selectedColor,
      memberIds: widget.selectedMembers
          .where((m) => m.id != widget.currentUserId)  // Exclude current user!
          .map((m) => m.id)
          .toList(),
      createdBy: widget.currentUserId,
    );

    widget.onSave(group);
  }
}
```

**Critical**: Groups do NOT include current user in `memberIds`!

### Using a Group

#### Toggle Group Selection

```dart
void _toggleGroup(QuickGroup group) {
  final allSelected = group.memberIds.every(
    (id) => _selectedIds.contains(id)
  );

  setState(() {
    if (allSelected) {
      // Deselect all (except current user)
      for (final id in group.memberIds) {
        if (id != widget.currentUser.id) {
          _selectedIds.remove(id);
        }
      }
    } else {
      // Select all
      _selectedIds.addAll(group.memberIds);
    }
  });
}
```

### Group Duplication Check

```dart
Future<void> _checkDuplicateGroup(QuickGroup group) async {
  final duplicate = await GroupStorageService.findDuplicateGroup(group.memberIds);

  if (duplicate != null) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duplicate Group'),
        content: Text('Group "${duplicate.name}" already has these members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Save anyway
              GroupStorageService.addGroup(group);
            },
            child: Text('Create Anyway'),
          ),
        ],
      ),
    );
  }
}
```

---

## Payment Tracking

### Payment Status Structure

```dart
class DetailedBill {
  final Map<String, bool> paymentStatus;  // userId → hasPaid

  // Check if bill is fully settled
  bool get isFullySettled {
    for (final userId in participantIds) {
      final isPaid = paymentStatus[userId] ?? false;
      if (!isPaid) return false;
    }
    return true;
  }
}
```

### Marking as Paid/Unpaid

```dart
// In BillSummaryScreen
Widget _buildParticipantRow(String userId, double share) {
  final appState = context.watch<AppState>();
  final bill = appState.getDetailedBillById(widget.billId);
  final isPaid = bill.paymentStatus[userId] ?? false;

  return Row(
    children: [
      // User info
      Text(userName),
      Text('RM ${share.toStringAsFixed(2)}'),

      // Payment checkbox
      Checkbox(
        value: isPaid,
        onChanged: (value) {
          if (value == true) {
            appState.markAsPaid(bill.id, userId);
          } else {
            appState.markAsUnpaid(bill.id, userId);
          }
        },
      ),
    ],
  );
}
```

### Dashboard Calculations

```dart
// Calculate "You Owe" amount
double get youOwe {
  double total = 0;

  for (final bill in _detailedBills) {
    final myShare = bill.participantShares[currentUser.id] ?? 0;
    final isPaid = bill.paymentStatus[currentUser.id] ?? false;

    if (myShare > 0 && !isPaid) {
      total += myShare;
    }
  }

  return total;
}

// Calculate "Owed to You" amount
double get owedToYou {
  double total = 0;

  for (final bill in _detailedBills) {
    if (bill.createdBy != currentUser.id) continue;

    for (final userId in bill.participantIds) {
      if (userId == currentUser.id) continue;

      final share = bill.participantShares[userId] ?? 0;
      final isPaid = bill.paymentStatus[userId] ?? false;

      if (share > 0 && !isPaid) {
        total += share;
      }
    }
  }

  return total;
}
```

---

## Bug Fixes & Important Notes

### 1. Group MemberIds Fix (Critical)

**Problem**: When deselecting all groups, some members remained selected.

**Root Cause**: Groups included current user in `memberIds`, but deselection logic tried to exclude current user, causing mismatch.

**Solution**: Groups should NOT include current user in `memberIds`.

**Files Fixed**:
- `lib/widgets/group_editor_modal.dart:91`
- `lib/screens/select_members_screen.dart:909`
- `lib/models/quick_group_model.dart:102-120`
- `lib/providers/app_state.dart:91-108`

**Code**:
```dart
// ✅ Correct
final group = QuickGroup(
  memberIds: selectedMembers
      .where((m) => m.id != currentUserId)
      .map((m) => m.id)
      .toList(),
);
```

### 2. Context in Build Methods

**Problem**: Using `context` in helper methods outside build context.

**Solution**: Pass `BuildContext` as parameter.

**Files Fixed**:
- `lib/screens/owed_to_you_screen.dart:188`
- `lib/screens/you_owe_screen.dart:177`

**Code**:
```dart
// Before
Widget _buildBillCard(bill, amount) {
  return GestureDetector(
    onTap: () => context.push(...),  // ❌ Error: context not available
  );
}

// After
Widget _buildBillCard(BuildContext context, bill, amount) {
  return GestureDetector(
    onTap: () => context.push(...),  // ✅ Works
  );
}
```

---

## Summary

This documentation provides a complete, line-by-line analysis of the SplitLah bill-splitting application. Key takeaways:

1. **Architecture**: Provider pattern with centralized AppState
2. **Data Flow**: Unidirectional (UI → Actions → State → UI)
3. **Navigation**: go_router with custom animations
4. **Bill Creation**: 5-step flow with state persistence
5. **Group Management**: Quick groups stored in SharedPreferences
6. **Payment Tracking**: Per-participant payment status
7. **UI**: Glassmorphic design with Material 3

The app is production-ready with:
- Clean architecture
- Proper state management
- Comprehensive error handling
- Malaysian e-wallet support
- Beautiful UI/UX

For further study, examine:
- Provider documentation: https://pub.dev/packages/provider
- go_router documentation: https://pub.dev/packages/go_router
- Flutter animations: https://flutter.dev/docs/development/ui/animations

---

**End of Documentation**
