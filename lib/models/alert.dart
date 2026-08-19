enum AlertSeverity {
  green,
  yellow,
  orange,
  red;

  static AlertSeverity fromDb(String value) => AlertSeverity.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AlertSeverity.yellow,
      );

  String get label => name[0].toUpperCase() + name.substring(1);

  /// Red alerts should bypass mute/DND on the client per Story 2 AC.
  bool get isCritical => this == AlertSeverity.red;
}

enum AlertStatus {
  active,
  escalated,
  deEscalated,
  archived;

  static AlertStatus fromDb(String value) {
    switch (value) {
      case 'de_escalated':
        return AlertStatus.deEscalated;
      case 'escalated':
        return AlertStatus.escalated;
      case 'archived':
        return AlertStatus.archived;
      default:
        return AlertStatus.active;
    }
  }
}

class DisasterAlert {
  final String id;
  final String title;
  final String alertType;
  final AlertSeverity severity;
  final AlertStatus status;
  final String? affectedZoneId;
  final double centerLat;
  final double centerLng;
  final int radiusMeters;
  final String? instructions;
  final String source;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  DisasterAlert({
    required this.id,
    required this.title,
    required this.alertType,
    required this.severity,
    required this.status,
    this.affectedZoneId,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    this.instructions,
    required this.source,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory DisasterAlert.fromMap(Map<String, dynamic> map) {
    final geo = map['center_point'];
    final lng = (geo?['coordinates']?[0] as num?)?.toDouble() ?? 0.0;
    final lat = (geo?['coordinates']?[1] as num?)?.toDouble() ?? 0.0;

    return DisasterAlert(
      id: map['id'] as String,
      title: map['title'] as String,
      alertType: map['alert_type'] as String,
      severity: AlertSeverity.fromDb(map['severity'] as String? ?? 'yellow'),
      status: AlertStatus.fromDb(map['status'] as String? ?? 'active'),
      affectedZoneId: map['affected_zone_id'] as String?,
      centerLat: lat,
      centerLng: lng,
      radiusMeters: (map['radius_meters'] as num?)?.toInt() ?? 2000,
      instructions: map['instructions'] as String?,
      source: map['source'] as String? ?? 'manual',
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(
        (map['updated_at'] ?? map['created_at']) as String,
      ),
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'] as String)
          : null,
    );
  }

  /// Payload for inserting a new alert (Story 3). `created_by` is set
  /// server-side expectation via auth.uid() default, but we pass it
  /// explicitly here since the schema requires it on insert.
  Map<String, dynamic> toInsertMap({required String createdBy}) {
    return {
      'title': title,
      'alert_type': alertType,
      'severity': severity.name,
      'affected_zone_id': affectedZoneId,
      'center_point': 'SRID=4326;POINT($centerLng $centerLat)',
      'radius_meters': radiusMeters,
      'instructions': instructions,
      'source': 'manual',
      'created_by': createdBy,
    };
  }
}
