import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../models/broadcast_audit_entry.dart';

class BroadcastAuditService {
  static const String _prefKey = 'safezone_broadcast_audit_logs_v1';

  /// Records an audit log entry for a broadcast action.
  Future<BroadcastAuditEntry> logAction({
    required String alertId,
    required String alertTitle,
    required BroadcastAuditAction action,
    String? performedBy,
    String? details,
    AlertSeverity? severity,
    String? zoneName,
  }) async {
    final entry = BroadcastAuditEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      alertId: alertId,
      alertTitle: alertTitle,
      action: action,
      performedBy: performedBy ?? 'Authority Admin',
      timestamp: DateTime.now(),
      details: details ?? _defaultDetails(action, alertTitle),
      severity: severity,
      zoneName: zoneName,
    );

    final logs = await getAuditLogs();
    logs.insert(0, entry);
    await _saveAuditLogs(logs);

    debugPrint(
      '📋 [AUDIT LOG] Recorded ${action.label} for "$alertTitle" by ${entry.performedBy}',
    );

    return entry;
  }

  /// Retrieves all recorded broadcast audit log entries.
  Future<List<BroadcastAuditEntry>> getAuditLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .map((item) => BroadcastAuditEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading broadcast audit logs: $e');
      return [];
    }
  }

  /// Filters audit logs by action type.
  Future<List<BroadcastAuditEntry>> getLogsByAction(
      BroadcastAuditAction action) async {
    final logs = await getAuditLogs();
    return logs.where((e) => e.action == action).toList();
  }

  /// Clears all recorded audit logs.
  Future<void> clearAuditLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  Future<void> _saveAuditLogs(List<BroadcastAuditEntry> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(logs.map((e) => e.toJson()).toList());
    await prefs.setString(_prefKey, encoded);
  }

  String _defaultDetails(BroadcastAuditAction action, String title) {
    switch (action) {
      case BroadcastAuditAction.created:
        return 'Broadcast alert created in command center.';
      case BroadcastAuditAction.dispatched:
        return 'Multi-channel broadcast dispatched across active alert channels.';
      case BroadcastAuditAction.resolved:
        return 'Broadcast alert marked resolved and de-escalated.';
      case BroadcastAuditAction.archived:
        return 'Broadcast alert archived from live active dashboard.';
    }
  }
}
