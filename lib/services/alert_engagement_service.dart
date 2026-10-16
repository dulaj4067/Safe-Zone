import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_engagement.dart';
import '../models/zone.dart';
import 'supabase_service.dart';

/// Resident "seen" / "acknowledged" receipts for alerts.
///
/// Source of truth is the `alert_engagements` table (see
/// sql/privacy_consent_onboarding_migration.sql): each resident writes their
/// own row, and authorities read everyone's to see who an alert has reached.
/// A local copy is kept so a resident's own "acknowledged" state survives
/// being offline; marks that couldn't reach the server are retried on the
/// next mark.
///
/// Dashboard numbers are never invented: if no residents are registered in
/// a zone the dashboard shows zero. The response simulator exists only in
/// debug builds, and simulated residents are labelled as such.
class AlertEngagementService {
  static const String _prefKeyPrefix = 'alert_engagement_v1_';
  static const String _pendingKey = '${_prefKeyPrefix}pending_sync';

  /// Debug-only sample roster used by the response simulator.
  static final List<Map<String, String>> _simulatedResidents = [
    for (var i = 1; i <= 10; i++)
      {'id': 'sim-$i', 'name': 'Simulated resident $i', 'phone': '—'},
  ];

  /// Fetches resident engagement and calculates percentages for the given alert and zone.
  Future<ZoneAlertEngagement> getZoneEngagement(
    String alertId, {
    String? zoneId,
    String? zoneName,
    List<Zone>? knownZones,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    String resolvedZoneName = zoneName ?? 'All Active Zones';
    if (zoneId != null && knownZones != null) {
      final match = knownZones.where((z) => z.id == zoneId).firstOrNull;
      if (match != null) {
        resolvedZoneName = match.name;
      }
    }

    final simulation = kDebugMode ? _readSimulation(prefs, alertId) : null;

    // 1. Registered residents of the zone. RLS only lets authorities read
    //    other people's profiles, so a non-authority sees just themselves.
    List<Map<String, dynamic>> memberProfiles = [];
    try {
      memberProfiles = await _zoneProfiles(zoneId);
    } catch (e) {
      debugPrint('getZoneEngagement: profiles unavailable: $e');
    }

    if (memberProfiles.isEmpty && simulation != null) {
      memberProfiles = [
        for (final r in _simulatedResidents)
          {'id': r['id'], 'full_name': r['name'], 'phone': r['phone'], 'zone_id': zoneId},
      ];
    }

    // 2. Their real receipts for this alert.
    final receipts = <String, Map<String, dynamic>>{};
    try {
      final rows = await SupabaseService.client
          .from('alert_engagements')
          .select('user_id, seen_at, acknowledged_at')
          .eq('alert_id', alertId);
      for (final r in rows as List) {
        receipts[r['user_id'] as String] = Map<String, dynamic>.from(r as Map);
      }
    } catch (e) {
      debugPrint('getZoneEngagement: receipts unavailable: $e');
    }

    final total = memberProfiles.length;
    final simAckCount =
        simulation?.ackRate != null ? (total * simulation!.ackRate!).round() : null;
    final simSeenCount = simulation?.seenRate != null
        ? (total * simulation!.seenRate!).round().clamp(simAckCount ?? 0, total)
        : null;

    final residents = <ResidentEngagement>[];
    int seenCount = 0;
    int ackCount = 0;

    for (int i = 0; i < total; i++) {
      final profile = memberProfiles[i];
      final uId = profile['id'] as String;
      final receipt = receipts[uId];
      DateTime? seenAt = DateTime.tryParse(receipt?['seen_at'] as String? ?? '')?.toLocal();
      DateTime? ackAt =
          DateTime.tryParse(receipt?['acknowledged_at'] as String? ?? '')?.toLocal();

      if (simAckCount != null && i < simAckCount) {
        seenAt ??= DateTime.now();
        ackAt ??= DateTime.now();
      } else if (simSeenCount != null && i < simSeenCount) {
        seenAt ??= DateTime.now();
      }

      final ResidentEngagementStatus status;
      if (ackAt != null) {
        status = ResidentEngagementStatus.acknowledged;
        ackCount++;
        seenCount++;
      } else if (seenAt != null) {
        status = ResidentEngagementStatus.seen;
        seenCount++;
      } else {
        status = ResidentEngagementStatus.pending;
      }

      residents.add(ResidentEngagement(
        userId: uId,
        fullName: (profile['full_name'] as String?)?.trim().isNotEmpty == true
            ? profile['full_name'] as String
            : 'Unnamed resident',
        phone: profile['phone'] as String? ?? '—',
        zoneId: profile['zone_id'] as String?,
        status: status,
        seenAt: seenAt,
        acknowledgedAt: ackAt,
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

  // Several dashboard cards often ask about the same zone at once (and again on
  // every rebuild). The resident list barely changes, so share one query per
  // zone for a minute instead of re-reading every profile for every card.
  static final Map<String, ({DateTime at, Future<List<Map<String, dynamic>>> rows})>
      _profileCache = {};
  static const _profileCacheTtl = Duration(seconds: 60);

  Future<List<Map<String, dynamic>>> _zoneProfiles(String? zoneId) {
    final key = zoneId ?? '*';
    final hit = _profileCache[key];
    if (hit != null && DateTime.now().difference(hit.at) < _profileCacheTtl) {
      return hit.rows;
    }
    var query = SupabaseService.client
        .from('profiles')
        .select('id, full_name, phone, role, zone_id');
    if (zoneId != null && zoneId.isNotEmpty) {
      query = query.eq('zone_id', zoneId);
    }
    final rows = query.then((r) => List<Map<String, dynamic>>.from(r as List));
    _profileCache[key] = (at: DateTime.now(), rows: rows);
    // A failed query must not be cached for the next minute.
    rows.catchError((Object _) {
      _profileCache.remove(key);
      return <Map<String, dynamic>>[];
    });
    return rows;
  }

  /// Records that a user has seen the alert banner or notification.
  Future<void> markSeen(String alertId, String userId) =>
      _record(alertId, userId, acknowledged: false);

  /// Records that a user has acknowledged the alert (implies seen).
  Future<void> markAcknowledged(String alertId, String userId) =>
      _record(alertId, userId, acknowledged: true);

  Future<void> _record(String alertId, String userId, {required bool acknowledged}) async {
    final prefs = await SharedPreferences.getInstance();
    await _addToList(prefs, '${_prefKeyPrefix}seen_$alertId', userId);
    if (acknowledged) {
      await _addToList(prefs, '${_prefKeyPrefix}ack_$alertId', userId);
    }

    // Only the signed-in user's own receipts can go to the server (RLS).
    if (userId != SupabaseService.currentUserId) return;
    final pending = prefs.getStringList(_pendingKey) ?? [];
    pending.add(jsonEncode({'alert': alertId, 'ack': acknowledged}));
    await prefs.setStringList(_pendingKey, pending);
    await flushPending();
  }

  /// Sends receipts that couldn't reach the server earlier. Each write is an
  /// idempotent upsert keyed by (alert_id, user_id), so retrying is safe.
  Future<void> flushPending() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return;

    final remaining = <String>[];
    for (final raw in pending) {
      try {
        final item = jsonDecode(raw) as Map<String, dynamic>;
        final alertId = item['alert'] as String;
        final ack = item['ack'] == true;
        if (ack) {
          await SupabaseService.client.from('alert_engagements').upsert({
            'alert_id': alertId,
            'user_id': userId,
            'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'alert_id,user_id');
        } else {
          // Never overwrite an existing seen/acknowledged time with "seen".
          await SupabaseService.client.from('alert_engagements').upsert(
            {'alert_id': alertId, 'user_id': userId},
            onConflict: 'alert_id,user_id',
            ignoreDuplicates: true,
          );
        }
      } on FormatException {
        // Corrupt entry: drop it rather than retrying forever.
      } catch (e) {
        debugPrint('alert engagement sync failed, will retry: $e');
        remaining.add(raw);
      }
    }
    await prefs.setStringList(_pendingKey, remaining);
  }

  /// Checks if a user has acknowledged an alert (this device's record).
  Future<bool> hasUserAcknowledged(String alertId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('${_prefKeyPrefix}ack_$alertId') ?? [];
    return list.contains(userId);
  }

  /// Checks if a user has seen an alert (this device's record).
  Future<bool> hasUserSeen(String alertId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('${_prefKeyPrefix}seen_$alertId') ?? [];
    return list.contains(userId);
  }

  /// Debug builds only: overlays simulated response rates on the dashboard
  /// for testing the escalation UI. Does nothing in release builds.
  Future<void> simulateEngagement(
    String alertId,
    String? zoneId, {
    required double ackRate,
    required double seenRate,
  }) async {
    if (!kDebugMode) return;
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

  static Future<void> _addToList(SharedPreferences prefs, String key, String value) async {
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(value)) {
      list.add(value);
      await prefs.setStringList(key, list);
    }
  }

  static ({double? ackRate, double? seenRate})? _readSimulation(
    SharedPreferences prefs,
    String alertId,
  ) {
    final raw = prefs.getString('${_prefKeyPrefix}sim_$alertId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (
        ackRate: (decoded['ackRate'] as num?)?.toDouble(),
        seenRate: (decoded['seenRate'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
