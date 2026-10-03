import 'circle_member_location.dart';

/// One person in the signed-in user's family circle — a row from the
/// `my_family_circle()` RPC (see sql/family_circle_invites_migration.sql).
///
/// A link is created when someone opens your invite link, and stays
/// `pending` until they confirm. Once confirmed it's mutual: you each see
/// the other's location. Locations are only ever returned for confirmed
/// members — that's enforced server-side, not here.
class FamilyMember {
  /// The safety_circle_contacts row linking the two of you.
  final String linkId;
  final String memberId;
  final String name;
  final String status;

  /// True if you sent the invite they accepted.
  final bool invitedByMe;

  final double? lat;
  final double? lng;
  final bool isSharingNow;
  final DateTime? lastSeenAt;

  const FamilyMember({
    required this.linkId,
    required this.memberId,
    required this.name,
    required this.status,
    required this.invitedByMe,
    this.lat,
    this.lng,
    this.isSharingNow = false,
    this.lastSeenAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get hasLocation => lat != null && lng != null;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// The map-marker view of this member, for the home and ETA maps.
  CircleMemberLocation toLocation() => CircleMemberLocation(
    contactId: linkId,
    name: name,
    relationship: 'Family',
    lat: lat,
    lng: lng,
    isActive: isSharingNow,
    lastSeenAt: lastSeenAt,
  );

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      linkId: map['link_id'] as String,
      memberId: map['member_id'] as String,
      name: map['name'] as String? ?? 'Family member',
      status: map['status'] as String? ?? 'pending',
      invitedByMe: map['invited_by_me'] as bool? ?? false,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      isSharingNow: map['is_active'] as bool? ?? false,
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'] as String)
          : null,
    );
  }
}

/// An invite link you created that nobody has used yet.
class FamilyInvite {
  final String code;
  final DateTime expiresAt;

  const FamilyInvite({required this.code, required this.expiresAt});

  factory FamilyInvite.fromMap(Map<String, dynamic> map) => FamilyInvite(
    code: map['code'] as String,
    expiresAt: DateTime.parse(map['expires_at'] as String),
  );
}
