/// One row from the `safety_circle_last_locations` view (see
/// sql/safety_circle_migration.sql) — a safety-circle contact who is also
/// a registered app user, with wherever they were last at, if anywhere.
class CircleMemberLocation {
  final String contactId;
  final String name;
  final String relationship;
  final double? lat;
  final double? lng;
  final bool isActive;
  final DateTime? lastSeenAt;

  CircleMemberLocation({
    required this.contactId,
    required this.name,
    required this.relationship,
    this.lat,
    this.lng,
    this.isActive = false,
    this.lastSeenAt,
  });

  /// True once this contact has ever shared a location — until then
  /// there's nothing to put a marker on the map for.
  bool get hasLocation => lat != null && lng != null;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory CircleMemberLocation.fromMap(Map<String, dynamic> map) {
    return CircleMemberLocation(
      contactId: map['contact_id'] as String,
      name: map['name'] as String,
      relationship: map['relationship'] as String? ?? 'Contact',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      isActive: map['is_active'] as bool? ?? false,
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'] as String)
          : null,
    );
  }
}
