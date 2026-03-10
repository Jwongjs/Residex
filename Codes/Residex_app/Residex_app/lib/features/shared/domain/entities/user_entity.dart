/// Domain Entity: User
/// 
/// Pure business object representing a user in the system.
/// Contains NO external dependencies (no Firebase, no JSON).
/// Only business logic and immutable data.
class UserEntity {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? phoneNumber;
  final String? photoURL;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserEntity({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.phoneNumber,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
  });

  /// Business Logic: Get user initials
  String get initials {
    final names = displayName.trim().split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names.first[0]}${names.last[0]}'.toUpperCase();
  }

  /// Business Logic: Get display-friendly role name
  String get roleDisplay {
    return role == UserRole.landlord ? 'Landlord' : 'Tenant';
  }

  /// Business Logic: Check if profile is complete
  bool get isProfileComplete {
    return displayName.isNotEmpty && 
           email.isNotEmpty && 
           phoneNumber != null && 
           phoneNumber!.isNotEmpty;
  }

  /// Create a copy with updated fields (immutability pattern)
  UserEntity copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? phoneNumber,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserEntity(uid: $uid, email: $email, displayName: $displayName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserEntity && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}

/// User Role Enum
/// Type-safe representation of user roles
enum UserRole {
  landlord,
  tenant;

  /// Convert enum to string for storage
  String toJson() => name;

  /// Convert string to enum from storage
  static UserRole fromJson(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => UserRole.tenant,
    );
  }
}
