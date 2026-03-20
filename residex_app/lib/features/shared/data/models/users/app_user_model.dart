import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/users/app_user.dart';

/// Data model that extends AppUser entity
/// Adds serialization for:
///   - Drift local database (fromDb / toDb)
///   - Firestore remote database (fromFirestore / toFirestore)
///   - JSON (fromJson / toJson)
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.name,
    required super.avatarInitials,
    super.profileImage,
    super.gradientColorValues,
    super.gradientColor,
    super.isGuest,
    super.phone,
    super.phoneNumber,
    super.email,
    super.trustScore,
    super.rank,
    super.role,
    super.fiscalScore,
    super.honorLevel,
    super.trustFactor,
    super.syncState,
    super.stats,
    super.createdAt,
    super.updatedAt,
  });

  // ============================================================================
  // Entity conversion
  // ============================================================================

  /// Create from domain entity
  factory AppUserModel.fromEntity(AppUser user) {
    return AppUserModel(
      id: user.id,
      name: user.name,
      avatarInitials: user.avatarInitials,
      profileImage: user.profileImage,
      gradientColorValues: user.gradientColorValues,
      gradientColor: user.gradientColor,
      isGuest: user.isGuest,
      phone: user.phone,
      phoneNumber: user.phoneNumber,
      email: user.email,
      trustScore: user.trustScore,
      rank: user.rank,
      role: user.role,
      fiscalScore: user.fiscalScore,
      honorLevel: user.honorLevel,
      trustFactor: user.trustFactor,
      syncState: user.syncState,
      stats: user.stats,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  /// Convert to domain entity
  AppUser toEntity() {
    return AppUser(
      id: id,
      name: name,
      avatarInitials: avatarInitials,
      profileImage: profileImage,
      gradientColorValues: gradientColorValues,
      gradientColor: gradientColor,
      isGuest: isGuest,
      phone: phone,
      phoneNumber: phoneNumber,
      email: email,
      trustScore: trustScore,
      rank: rank,
      role: role,
      fiscalScore: fiscalScore,
      honorLevel: honorLevel,
      trustFactor: trustFactor,
      syncState: syncState,
      stats: stats,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ============================================================================
  // Firestore serialization
  // ============================================================================

  /// Create AppUserModel from Firestore DocumentSnapshot
  factory AppUserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['displayName'] as String? ??
        data['name'] as String? ??
        'Unknown';
    return AppUserModel(
      id: doc.id,
      name: name,
      avatarInitials: _computeInitials(name),
      profileImage: data['photoURL'] as String?,
      email: data['email'] as String?,
      phone: data['phoneNumber'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      role: UserRole.fromJson(data['role'] as String? ?? 'tenant'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'email': email ?? '',
      'displayName': name,
      'role': role.toJson(),
      'phoneNumber': phone ?? phoneNumber ?? '',
      'photoURL': profileImage,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ============================================================================
  // JSON serialization (API / local storage)
  // ============================================================================

  /// From JSON
  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarInitials: json['avatarInitials'] as String,
      profileImage: json['profileImage'] as String?,
      gradientColorValues: json['gradientColorValues'] != null
          ? List<int>.from(json['gradientColorValues'] as List)
          : null,
      isGuest: json['isGuest'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarInitials': avatarInitials,
      'profileImage': profileImage,
      'gradientColorValues': gradientColorValues,
      'isGuest': isGuest,
      'phoneNumber': phoneNumber,
    };
  }

  // ============================================================================
  // Drift / SQLite serialization
  // ============================================================================

  /// From database row (Drift)
  factory AppUserModel.fromDb(Map<String, dynamic> row) {
    return AppUserModel(
      id: row['id'] as String,
      name: row['name'] as String,
      avatarInitials: row['avatarInitials'] as String,
      profileImage: row['profileImage'] as String?,
      gradientColorValues: row['gradientColorValues'] != null
          ? List<int>.from(jsonDecode(row['gradientColorValues'] as String))
          : null,
      isGuest: row['isGuest'] == 1,
      phoneNumber: row['phoneNumber'] as String?,
    );
  }

  /// To database format
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'avatarInitials': avatarInitials,
      'profileImage': profileImage,
      'gradientColorValues': gradientColorValues != null
          ? jsonEncode(gradientColorValues)
          : null,
      'isGuest': isGuest ? 1 : 0,
      'phoneNumber': phoneNumber,
    };
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  static String _computeInitials(String name) {
    final names = name.trim().split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names.first[0]}${names.last[0]}'.toUpperCase();
  }
}
