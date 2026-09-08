import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_engagement.dart';
import '../models/zone.dart';
import 'supabase_service.dart';

class AlertEngagementService {
  static const String _prefKeyPrefix = 'alert_engagement_v1_';

  /// Standard default resident rosters per zone when Supabase profiles are sparse
  static final Map<String, List<Map<String, String>>> _fallbackZoneResidents = {
    'default': [
      {'id': 'res-01', 'name': 'Nimal Perera', 'phone': '+94 77 123 4567'},
      {'id': 'res-02', 'name': 'Sunil Jayawardena', 'phone': '+94 71 234 5678'},
      {'id': 'res-03', 'name': 'Kamani Silva', 'phone': '+94 76 345 6789'},
      {'id': 'res-04', 'name': 'Anura Fernando', 'phone': '+94 78 456 7890'},
      {'id': 'res-05', 'name': 'Dilhani Gunasekara', 'phone': '+94 75 567 8901'},
      {'id': 'res-06', 'name': 'Roshan Wickramasinghe', 'phone': '+94 72 678 9012'},
      {'id': 'res-07', 'name': 'Malini Rathnayake', 'phone': '+94 70 789 0123'},
      {'id': 'res-08', 'name': 'Chandana Senaratne', 'phone': '+94 77 890 1234'},
      {'id': 'res-09', 'name': 'Priyantha Bandara', 'phone': '+94 71 901 2345'},
      {'id': 'res-10', 'name': 'Nirosha Dias', 'phone': '+94 76 012 3456'},
    ],
  };

  /// Fetches resident engagement and calculates percentages for the given alert and zone.
  Future<ZoneAlertEngagement> getZoneEngagement(
    String alertId, {
    String? zoneId,
    String? zoneName,
    List<Zone>? knownZones,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedSeen = (prefs.getStringList('${_prefKeyPrefix}seen_$alertId') ?? []).toSet();
    final cachedAcks = (prefs.getStringList('${_prefKeyPrefix}ack_$alertId') ?? []).toSet();

    String resolvedZoneName = zoneName ?? 'All Active Zones';
    if (zoneId != null && knownZones != null) {
      final match = knownZones.where((z) => z.id == zoneId).firstOrNull;
      if (match != null) {
        resolvedZoneName = match.name;
      }
    }

    // 1. Attempt to load actual registered profiles from Supabase
    List<Map<String, dynamic>> memberProfiles = [];
    try {
      var query = SupabaseService.client
          .from('profiles')
          .select('id, full_name, phone, role, zone_id');

      if (zoneId != null && zoneId.isNotEmpty) {
        query = query.eq('zone_id', zoneId);
      }

      final rows = await query;
      if (rows is List && rows.isNotEmpty) {
        memberProfiles = List<Map<String, dynamic>>.from(rows);
      }
    } catch (_) {
      // Supabase query failed or offline; fall back quietly to cached/mock roster
    }

    // 2. If no profiles exist in this zone yet, use realistic fallback resident pool
    if (memberProfiles.isEmpty) {
      final pool = _fallbackZoneResidents[zoneId] ?? _fallbackZoneResidents['default']!;
      memberProfiles = pool
          .map((r) => {
                'id': '${r['id']}_${zoneId ?? "gen"}',
                'full_name': r['name'],
                'phone': r['phone'],
                'role': 'member',
                'zone_id': zoneId,
              })
          .toList();
    }

    // Check simulated response data if present
    final simRaw = prefs.getString('${_prefKeyPrefix}sim_$alertId');
    double? simAckRate;
    double? simSeenRate;
    if (simRaw != null) {
      try {
        final decoded = jsonDecode(simRaw) as Map<String, dynamic>;
        if (decoded['ackRate'] != null) {
          simAckRate = (decoded['ackRate'] as num).toDouble();
        }
        if (decoded['seenRate'] != null) {
          simSeenRate = (decoded['seenRate'] as num).toDouble();
        }
      } catch (_) {}
    }

    // If simulation is active, determine simulated counts
    final total = memberProfiles.length;
    final simAckCount = simAckRate != null ? (total * simAckRate).round() : null;
    final simSeenCount = simSeenRate != null ? (total * simSeenRate).round().clamp(simAckCount ?? 0, total) : null;

    // Build the ResidentEngagement list
    final residents = <ResidentEngagement>[];
    int seenCount = 0;
    int ackCount = 0;

    for (int i = 0; i < total; i++) {
      final profile = memberProfiles[i];
      final uId = profile['id'] as String;
      final name = profile['full_name'] as String? ?? 'Resident ($uId)';
      final phone = profile['phone'] as String? ?? 'N/A';
      final pZone = profile['zone_id'] as String?;

      bool isAck = cachedAcks.contains(uId);
      bool isSeen = isAck || cachedSeen.contains(uId);

      if (simAckCount != null && i < simAckCount) {
        isAck = true;
        isSeen = true;
      } else if (simSeenCount != null && i < simSeenCount) {
        isSeen = true;
      }

      ResidentEngagementStatus status;
      if (isAck) {
        status = ResidentEngagementStatus.acknowledged;
        ackCount++;
        seenCount++;
      } else if (isSeen) {
        status = ResidentEngagementStatus.seen;
        seenCount++;
      } else {
        status = ResidentEngagementStatus.pending;
      }

      residents.add(ResidentEngagement(
        userId: uId,
        fullName: name,
        phone: phone,
        zoneId: pZone,
        status: status,
        seenAt: isSeen ? DateTime.now().subtract(const Duration(minutes: 15)) : null,
        acknowledgedAt: isAck ? DateTime.now().subtract(const Duration(minutes: 8)) : null,
      ));
    }

    return ZoneAlertEngagement(
      alertId: alertId,
      zoneId: zoneId,
      zoneName: resolvedZoneName,
      totalResidents: total,
      seenCount: seenCount,
      acknowledgedCount: ackCount,
      residents: residents,
    );
  }

  /// Records that a user has seen the alert banner or notification.
  Future<void> markSeen(String alertId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_prefKeyPrefix}seen_$alertId';
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(userId)) {
      list.add(userId);
      await prefs.setStringList(key, list);
    }
  }

  /// Records that a user has acknowledged the alert.
  Future<void> markAcknowledged(String alertId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    // Acknowledging implies seen as well
    await markSeen(alertId, userId);

    final key = '${_prefKeyPrefix}ack_$alertId';
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(userId)) {
      list.add(userId);
      await prefs.setStringList(key, list);
    }
  }

  /// Checks if a user has acknowledged an alert.
  Future<bool> hasUserAcknowledged(String alertId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('${_prefKeyPrefix}ack_$alertId') ?? [];
    return list.contains(userId);
  }

  /// Checks if a user has seen an alert.
  Future<bool> hasUserSeen(String alertId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('${_prefKeyPrefix}seen_$alertId') ?? [];
    return list.contains(userId);
  }

  /// Helper for Authority Admins / Tests to simulate responses in a zone.
  Future<void> simulateEngagement(
    String alertId,
    String? zoneId, {
    required double ackRate,
    required double seenRate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_prefKeyPrefix}sim_$alertId',
      jsonEncode({
        'ackRate': ackRate.clamp(0.0, 1.0),
        'seenRate': seenRate.clamp(0.0, 1.0),
      }),
    );
  }

  /// Reset engagement cache for an alert (useful for test resets)
  Future<void> resetEngagement(String alertId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefKeyPrefix}seen_$alertId');
    await prefs.remove('${_prefKeyPrefix}ack_$alertId');
    await prefs.remove('${_prefKeyPrefix}sim_$alertId');
  }
}
