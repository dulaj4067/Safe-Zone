import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/alert.dart';
import 'supabase_service.dart';

class AlertService {
  static const _cacheKey = 'cached_alerts_v1';

  RealtimeChannel? _channel;

  Future<List<DisasterAlert>> fetchActiveAlerts() async {
    final rows = await SupabaseService.client
        .from('alerts')
        .select()
        .inFilter('status', ['active', 'escalated'])
        .order('created_at', ascending: false);

    final alerts =
        (rows as List).map((r) => DisasterAlert.fromMap(r)).toList();
    await _writeCache(alerts);
    return alerts;
  }

  /// Subscribes to inserts/updates on `alerts` for Story 2's realtime AC.
  /// Remember to enable Realtime on the `alerts` table in the Supabase
  /// dashboard (Database > Replication) — this is a project setting, not
  /// something the SQL migration turns on by itself.
  void subscribeToAlerts({
    required void Function(DisasterAlert alert) onInsert,
    required void Function(DisasterAlert alert) onUpdate,
  }) {
    _channel = SupabaseService.client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            onInsert(DisasterAlert.fromMap(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            onUpdate(DisasterAlert.fromMap(payload.newRecord));
          },
        )
        .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  /// Story 3: insert a new geo-targeted broadcast. Relies on the
  /// "Authority can insert alerts" RLS policy for real enforcement —
  /// this will throw a PostgrestException if the caller isn't authority.
  Future<DisasterAlert> createAlert(DisasterAlert draft) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw StateError('Must be signed in to create an alert.');
    }

    final inserted = await SupabaseService.client
        .from('alerts')
        .insert(draft.toInsertMap(createdBy: userId))
        .select()
        .single();

    return DisasterAlert.fromMap(inserted);
  }

  /// Story 4: mark an alert resolved. RLS "Authority can update alerts"
  /// is the real enforcement — this will throw if the caller isn't
  /// authority.
  Future<void> resolveAlert(String alertId) async {
    await SupabaseService.client.from('alerts').update({
      'status': 'de_escalated',
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', alertId);
  }

  /// Story 4: archive an alert so it drops off the live dashboard.
  Future<void> archiveAlert(String alertId) async {
    await SupabaseService.client
        .from('alerts')
        .update({'status': 'archived'}).eq('id', alertId);
  }

  Future<void> _writeCache(List<DisasterAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(alerts
        .map((a) => {
              'id': a.id,
              'title': a.title,
              'alert_type': a.alertType,
              'severity': a.severity.name,
              'status': a.status.name,
              'affected_zone_id': a.affectedZoneId,
              'lat': a.centerLat,
              'lng': a.centerLng,
              'radius_meters': a.radiusMeters,
              'instructions': a.instructions,
              'source': a.source,
              'created_at': a.createdAt.toIso8601String(),
              'updated_at': a.updatedAt.toIso8601String(),
            })
        .toList());
    await prefs.setString(_cacheKey, encoded);
    await prefs.setString(
      '${_cacheKey}_ts',
      DateTime.now().toIso8601String(),
    );
  }

  Future<(List<DisasterAlert>, DateTime?)> readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final ts = prefs.getString('${_cacheKey}_ts');
    if (raw == null) return (<DisasterAlert>[], null);

    final decoded = jsonDecode(raw) as List;
    final alerts = decoded.map((m) {
      return DisasterAlert(
        id: m['id'],
        title: m['title'],
        alertType: m['alert_type'],
        severity: AlertSeverity.fromDb(m['severity']),
        status: AlertStatus.fromDb(m['status']),
        affectedZoneId: m['affected_zone_id'],
        centerLat: (m['lat'] as num).toDouble(),
        centerLng: (m['lng'] as num).toDouble(),
        radiusMeters: m['radius_meters'],
        instructions: m['instructions'],
        source: m['source'],
        createdAt: DateTime.parse(m['created_at']),
        updatedAt: DateTime.parse(m['updated_at']),
      );
    }).toList();

    return (alerts, ts != null ? DateTime.parse(ts) : null);
  }
}
