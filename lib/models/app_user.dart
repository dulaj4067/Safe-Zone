enum UserRole {
  member,
  authority,
  volunteerOrg,
  admin;

  static UserRole fromDb(String value) {
    switch (value) {
      case 'authority':
        return UserRole.authority;
      case 'volunteer_org':
        return UserRole.volunteerOrg;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.member;
    }
  }

  /// Mirrors the `is_authority()` SQL helper — used for client-side UI
  /// gating only. The real enforcement is the RLS policy on the server.
  bool get isAuthority =>
      this == UserRole.authority ||
      this == UserRole.admin ||
      this == UserRole.volunteerOrg;
}

class AppUser {
  final String id;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? zoneId;

  AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.zoneId,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String,
      role: UserRole.fromDb(map['role'] as String? ?? 'member'),
      zoneId: map['zone_id'] as String?,
    );
  }
}
