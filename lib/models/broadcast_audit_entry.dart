import 'package:flutter/material.dart';
import 'alert.dart';

enum BroadcastAuditAction {
  created,
  dispatched,
  resolved,
  archived,
}

extension BroadcastAuditActionX on BroadcastAuditAction {
  String get label {
    switch (this) {
      case BroadcastAuditAction.created:
        return 'Created';
      case BroadcastAuditAction.dispatched:
        return 'Dispatched';
      case BroadcastAuditAction.resolved:
        return 'Resolved';
      case BroadcastAuditAction.archived:
        return 'Archived';
    }
  }

  IconData get icon {
    switch (this) {
      case BroadcastAuditAction.created:
        return Icons.add_circle_outline;
      case BroadcastAuditAction.dispatched:
        return Icons.send_rounded;
      case BroadcastAuditAction.resolved:
        return Icons.check_circle_outline;
      case BroadcastAuditAction.archived:
        return Icons.archive_outlined;
    }
  }

  Color get color {
    switch (this) {
      case BroadcastAuditAction.created:
        return Colors.blue;
      case BroadcastAuditAction.dispatched:
        return Colors.teal;
      case BroadcastAuditAction.resolved:
        return Colors.green;
      case BroadcastAuditAction.archived:
        return Colors.grey.shade700;
    }
  }
}

class BroadcastAuditEntry {
  final String id;
  final String alertId;
  final String alertTitle;
  final BroadcastAuditAction action;
  final String performedBy;
  final DateTime timestamp;
  final String details;
  final AlertSeverity? severity;
  final String? zoneName;

  BroadcastAuditEntry({
    required this.id,
    required this.alertId,
    required this.alertTitle,
    required this.action,
    required this.performedBy,
    required this.timestamp,
    required this.details,
    this.severity,
    this.zoneName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'alertId': alertId,
        'alertTitle': alertTitle,
        'action': action.name,
        'performedBy': performedBy,
        'timestamp': timestamp.toIso8601String(),
        'details': details,
        'severity': severity?.name,
        'zoneName': zoneName,
      };

  factory BroadcastAuditEntry.fromJson(Map<String, dynamic> json) {
    return BroadcastAuditEntry(
      id: json['id'] as String? ?? '',
      alertId: json['alertId'] as String? ?? '',
      alertTitle: json['alertTitle'] as String? ?? 'Broadcast Alert',
      action: BroadcastAuditAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => BroadcastAuditAction.created,
      ),
      performedBy: json['performedBy'] as String? ?? 'Authority Admin',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      details: json['details'] as String? ?? '',
      severity: json['severity'] != null
          ? AlertSeverity.values.firstWhere(
              (s) => s.name == json['severity'],
              orElse: () => AlertSeverity.yellow,
            )
          : null,
      zoneName: json['zoneName'] as String?,
    );
  }
}
