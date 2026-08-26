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

  /// Database-ready snake_case value.
  String get dbValue {
    switch (this) {
      case IncidentCategory.waterlogging:
        return 'waterlogging';
      case IncidentCategory.blockedRoad:
        return 'blocked_road';
      case IncidentCategory.powerOutage:
        return 'power_outage';
      case IncidentCategory.trappedPerson:
        return 'trapped_person';
      case IncidentCategory.structuralDamage:
        return 'structural_damage';
      case IncidentCategory.other:
        return 'other';
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

  String get label {
    switch (this) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.rejected:
        return 'Rejected';
      case IncidentStatus.resolved:
        return 'Resolved';
    }
  }
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

  /// Reporter name — populated when the query joins on profiles.
  final String? reporterName;

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
    this.reporterName,
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
      reporterName: map['reporter_name'] as String?,
    );
  }

  /// Payload for inserting a new incident. Location is encoded as PostGIS
  /// EWKT so Supabase/PostGIS can parse it directly.
  Map<String, dynamic> toInsertMap({required String reporterId}) {
    return {
      'reporter_id': reporterId,
      'category': category.dbValue,
      'description': description,
      'photo_url': photoUrl,
      'video_url': videoUrl,
      'location': 'SRID=4326;POINT($longitude $latitude)',
      'status': 'pending',
      'credibility_score': 0,
      'is_sos': isSos,
    };
  }

  /// Payload for updating an existing incident.
  Map<String, dynamic> toUpdateMap() {
    return {
      'category': category.dbValue,
      'description': description,
      'photo_url': photoUrl,
      'video_url': videoUrl,
      'location': 'SRID=4326;POINT($longitude $latitude)',
      'is_sos': isSos,
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Incident copyWith({
    String? id,
    String? reporterId,
    IncidentCategory? category,
    String? description,
    String? photoUrl,
    String? videoUrl,
    double? latitude,
    double? longitude,
    IncidentStatus? status,
    int? credibilityScore,
    bool? isSos,
    String? verifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reporterName,
  }) {
    return Incident(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      category: category ?? this.category,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      credibilityScore: credibilityScore ?? this.credibilityScore,
      isSos: isSos ?? this.isSos,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reporterName: reporterName ?? this.reporterName,
    );
  }
}

