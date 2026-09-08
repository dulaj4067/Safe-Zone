enum ResidentEngagementStatus {
  acknowledged,
  seen,
  pending;

  String get label {
    switch (this) {
      case ResidentEngagementStatus.acknowledged:
        return 'Acknowledged';
      case ResidentEngagementStatus.seen:
        return 'Seen (Unacknowledged)';
      case ResidentEngagementStatus.pending:
        return 'Pending (Not Seen)';
    }
  }
}

enum EngagementUrgency {
  critical,
  warning,
  optimal;

  String get label {
    switch (this) {
      case EngagementUrgency.critical:
        return 'Action Required';
      case EngagementUrgency.warning:
        return 'Follow-up Suggested';
      case EngagementUrgency.optimal:
        return 'Coverage On Track';
    }
  }
}

class ResidentEngagement {
  final String userId;
  final String fullName;
  final String phone;
  final String? zoneId;
  final ResidentEngagementStatus status;
  final DateTime? seenAt;
  final DateTime? acknowledgedAt;

  const ResidentEngagement({
    required this.userId,
    required this.fullName,
    required this.phone,
    this.zoneId,
    required this.status,
    this.seenAt,
    this.acknowledgedAt,
  });

  ResidentEngagement copyWith({
    String? userId,
    String? fullName,
    String? phone,
    String? zoneId,
    ResidentEngagementStatus? status,
    DateTime? seenAt,
    DateTime? acknowledgedAt,
  }) {
    return ResidentEngagement(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      zoneId: zoneId ?? this.zoneId,
      status: status ?? this.status,
      seenAt: seenAt ?? this.seenAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }
}

class ZoneAlertEngagement {
  final String alertId;
  final String? zoneId;
  final String zoneName;
  final int totalResidents;
  final int seenCount;
  final int acknowledgedCount;
  final List<ResidentEngagement> residents;

  const ZoneAlertEngagement({
    required this.alertId,
    this.zoneId,
    required this.zoneName,
    required this.totalResidents,
    required this.seenCount,
    required this.acknowledgedCount,
    this.residents = const [],
  });

  /// Percentage of residents in the zone who have viewed the alert (0.0 to 100.0).
  double get seenPercentage =>
      totalResidents > 0 ? (seenCount / totalResidents) * 100 : 0.0;

  /// Percentage of residents in the zone who have acknowledged the alert (0.0 to 100.0).
  double get acknowledgedPercentage =>
      totalResidents > 0 ? (acknowledgedCount / totalResidents) * 100 : 0.0;

  /// Number of residents who have not yet seen or acknowledged the alert.
  int get unreachedCount {
    final unreached = totalResidents - seenCount;
    return unreached < 0 ? 0 : unreached;
  }

  /// Percentage of residents who have not yet seen the alert.
  double get unreachedPercentage =>
      totalResidents > 0 ? (unreachedCount / totalResidents) * 100 : 0.0;

  /// Determines whether further authority admin action (e.g. SMS broadcast, ground units) is needed.
  bool get needsFurtherAction =>
      totalResidents > 0 && (acknowledgedPercentage < 50.0 || seenPercentage < 60.0);

  /// Urgency tier for visual indicators.
  EngagementUrgency get urgency {
    if (totalResidents == 0) return EngagementUrgency.optimal;
    if (acknowledgedPercentage < 40.0 || seenPercentage < 50.0) {
      return EngagementUrgency.critical;
    }
    if (acknowledgedPercentage < 75.0) {
      return EngagementUrgency.warning;
    }
    return EngagementUrgency.optimal;
  }

  /// Human-readable advice for the authority admin.
  String get actionRecommendation {
    if (totalResidents == 0) {
      return 'No registered residents detected in this zone.';
    }
    if (acknowledgedPercentage < 40.0) {
      return '🚨 Critical: Only ${acknowledgedPercentage.toStringAsFixed(1)}% of residents have acknowledged. Further action needed: initiate emergency SMS broadcast or dispatch volunteer ground teams.';
    }
    if (acknowledgedPercentage < 75.0) {
      return '⚠️ Moderate reach: ${acknowledgedPercentage.toStringAsFixed(1)}% acknowledged (${seenPercentage.toStringAsFixed(1)}% seen). Recommended: monitor incoming receipts and prepare secondary SMS push.';
    }
    return '✅ Optimal response: ${acknowledgedPercentage.toStringAsFixed(1)}% acknowledged (${seenPercentage.toStringAsFixed(1)}% seen). Target zone is well informed.';
  }
}
