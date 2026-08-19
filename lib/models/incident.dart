enum IncidentCategory {
  waterlogging,
  blockedRoad,
  powerOutage,
  trappedPerson,
  structuralDamage,
  other;

  static IncidentCategory fromDb(String value) {
    switch (value) {
      case 'waterlogging':
        return IncidentCategory.waterlogging;
      case 'blocked_road':
        return IncidentCategory.blockedRoad;
      case 'power_outage':
        return IncidentCategory.powerOutage;
      case 'trapped_person':
        return IncidentCategory.trappedPerson;
      case 'structural_damage':
        return IncidentCategory.structuralDamage;
      default:
        return IncidentCategory.other;
    }
  }

  String get label {
    switch (this) {
      case IncidentCategory.waterlogging:
        return 'Waterlogging';
      case IncidentCategory.blockedRoad:
        return 'Blocked Road';
      case IncidentCategory.powerOutage:
        return 'Power Outage';
      case IncidentCategory.trappedPerson:
        return 'Trapped Person';
      case IncidentCategory.structuralDamage:
        return 'Structural Damage';
      case IncidentCategory.other:
        return 'Other';
    }
  }
}

enum IncidentStatus {
  pending,
  verified,
  resolved,
  rejected;

  static IncidentStatus fromDb(String value) =>
      IncidentStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => IncidentStatus.pending,
      );
}

class Incident {
  final String id;
  final String reporterId;
  final IncidentCategory category;
  final String? description;
  final String? photoUrl;
  final String? videoUrl;
  final double latitude;
  final double longitude;
  final IncidentStatus status;
  final int credibilityScore;
  final bool isSos;
  final String? verifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Incident({
    required this.id,
    required this.reporterId,
    required this.category,
    this.description,
    this.photoUrl,
    this.videoUrl,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.credibilityScore,
    required this.isSos,
    this.verifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parses a row from `incidents_with_latlon` view which exposes
  /// `lat` = ST_Y(location) and `lng` = ST_X(location) as plain FLOAT8
  /// columns, or from the local cache which stores them the same way.
  factory Incident.fromMap(Map<String, dynamic> map) {
    final lat = (map['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (map['lng'] as num?)?.toDouble() ?? 0.0;

    return Incident(
      id: map['id'] as String,
      reporterId: map['reporter_id'] as String,
      category: IncidentCategory.fromDb(
        (map['category'] ?? map['label']) as String? ?? 'other',
      ),
      description: map['description'] as String?,
      photoUrl: map['photo_url'] as String?,
      videoUrl: map['video_url'] as String?,
      latitude: lat,
      longitude: lng,
      status: IncidentStatus.fromDb(
        (map['status'] ?? map['meta']) as String? ?? 'pending',
      ),
      credibilityScore: (map['credibility_score'] as num?)?.toInt() ?? 0,
      isSos: map['is_sos'] as bool? ?? false,
      verifiedBy: map['verified_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(
        (map['updated_at'] ?? map['created_at']) as String,
      ),
    );
  }
}
