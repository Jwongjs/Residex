import 'package:equatable/equatable.dart';

/// User role enum - determines which dashboard and features user sees
enum UserRole {
  tenant,
  landlord;

  /// Convert enum to string for storage (Firestore / JSON)
  String toJson() => name;

  /// Convert string to enum from storage
  static UserRole fromJson(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => UserRole.tenant,
    );
  }
}

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

/// Pure domain entity for a user
/// Unified entity combining Residex features + Firebase-compatible fields
class AppUser extends Equatable {
  final String id;
  final String name;
  final String avatarInitials;
  final String? profileImage;

  // LEGACY: Color stored as int list (for backwards compatibility)
  final List<int>? gradientColorValues; // Store color values as ints (0xFFRRGGBB)

  // NEW: Color as hex string (preferred for new code)
  final String? gradientColor; // Hex string like "#FF6366F1"

  final bool isGuest;

  // Contact info (merged phoneNumber → phone, added email)
  final String? phone;
  final String? phoneNumber; // Alias for backwards compatibility
  final String? email;

  // LEGACY: Trust score (kept for compatibility)
  final int? trustScore;
  final String? rank; // 'BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND'

  // NEW: Residex role-based system
  final UserRole role;              // tenant or landlord
  final int fiscalScore;            // 0-1000 (financial reliability)
  final HonorLevel honorLevel;      // 0-5 tier (behavioral reputation)
  final double trustFactor;         // 0.0-1.0+ (reporter credibility k-factor)
  final SyncState syncState;        // synced, drifting, out_of_sync

  final UserStats? stats;           // Detailed statistics

  // Firebase-compatible timestamp fields
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.avatarInitials,
    this.profileImage,
    this.gradientColorValues,
    this.gradientColor,
    this.isGuest = false,
    this.phone,
    this.phoneNumber, // Kept for backwards compatibility
    this.email,
    this.trustScore,
    this.rank,
    this.role = UserRole.tenant,
    this.fiscalScore = 500,
    this.honorLevel = HonorLevel.neutral,
    this.trustFactor = 0.7,
    this.syncState = SyncState.synced,
    this.stats,
    this.createdAt,
    this.updatedAt,
  });

  // ============================================================================
  // Firebase field aliases (for data layer compatibility)
  // ============================================================================

  /// Firebase UID alias for id
  String get uid => id;

  /// Firebase displayName alias for name
  String get displayName => name;

  /// Firebase photoURL alias for profileImage
  String? get photoURL => profileImage;

  // ============================================================================
  // Computed properties
  // ============================================================================

  /// Get user initials from name
  String get initials {
    final names = name.trim().split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names.first[0]}${names.last[0]}'.toUpperCase();
  }

  /// Get display-friendly role name
  String get roleDisplay => role == UserRole.landlord ? 'Landlord' : 'Tenant';

  /// Check if profile is complete (for onboarding checks)
  bool get isProfileComplete {
    return name.isNotEmpty &&
        (email?.isNotEmpty ?? false) &&
        ((phone?.isNotEmpty ?? false) || (phoneNumber?.isNotEmpty ?? false));
  }

  // ============================================================================
  // Immutability helpers
  // ============================================================================

  AppUser copyWith({
    String? id,
    String? name,
    String? avatarInitials,
    String? profileImage,
    List<int>? gradientColorValues,
    String? gradientColor,
    bool? isGuest,
    String? phone,
    String? phoneNumber,
    String? email,
    int? trustScore,
    String? rank,
    UserRole? role,
    int? fiscalScore,
    HonorLevel? honorLevel,
    double? trustFactor,
    SyncState? syncState,
    UserStats? stats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      profileImage: profileImage ?? this.profileImage,
      gradientColorValues: gradientColorValues ?? this.gradientColorValues,
      gradientColor: gradientColor ?? this.gradientColor,
      isGuest: isGuest ?? this.isGuest,
      phone: phone ?? this.phone,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      trustScore: trustScore ?? this.trustScore,
      rank: rank ?? this.rank,
      role: role ?? this.role,
      fiscalScore: fiscalScore ?? this.fiscalScore,
      honorLevel: honorLevel ?? this.honorLevel,
      trustFactor: trustFactor ?? this.trustFactor,
      syncState: syncState ?? this.syncState,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    avatarInitials,
    profileImage,
    gradientColorValues,
    gradientColor,
    isGuest,
    phone,
    phoneNumber,
    email,
    trustScore,
    rank,
    role,
    fiscalScore,
    honorLevel,
    trustFactor,
    syncState,
    stats,
    createdAt,
    updatedAt,
  ];
}

/// User statistics for detailed metrics
class UserStats extends Equatable {
  final int streak;                    // Payment streak (days/months)
  final double avgConfirmationHours;   // Average time to confirm payments
  final int totalPayments;             // Total number of payments made
  final int disputes;                  // Number of disputes filed
  final int ranking;                   // Global ranking position

  const UserStats({
    required this.streak,
    required this.avgConfirmationHours,
    required this.totalPayments,
    required this.disputes,
    required this.ranking,
  });

  UserStats copyWith({
    int? streak,
    double? avgConfirmationHours,
    int? totalPayments,
    int? disputes,
    int? ranking,
  }) {
    return UserStats(
      streak: streak ?? this.streak,
      avgConfirmationHours: avgConfirmationHours ?? this.avgConfirmationHours,
      totalPayments: totalPayments ?? this.totalPayments,
      disputes: disputes ?? this.disputes,
      ranking: ranking ?? this.ranking,
    );
  }

  @override
  List<Object?> get props => [
    streak,
    avgConfirmationHours,
    totalPayments,
    disputes,
    ranking,
  ];
}
