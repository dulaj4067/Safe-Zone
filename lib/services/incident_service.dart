import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/incident.dart';
import 'supabase_service.dart';

/// Handles fetching incidents from Supabase and local caching for the
/// offline-first fallback described in Story 1's AC.
class IncidentService {
  static const _cacheKey = 'cached_incidents_v1';

  /// Fetches incidents whose status is pending or verified via the
  /// `incidents_with_latlon` RPC (or view), which returns `lat` and `lng`
  /// as plain FLOAT8 columns instead of raw PostGIS WKB bytes.
  ///
  /// Add this to Supabase SQL editor:
  ///   create or replace view incidents_with_latlon as
  ///   select *, ST_Y(location) as lat, ST_X(location) as lng
  ///   from incidents;
  ///
  ///   grant select on incidents_with_latlon to anon, authenticated;
  Future<List<Incident>> fetchIncidents() async {
    final client = SupabaseService.client;

    final rows = await client
        .from('incidents_with_latlon')
        .select(
          'id, reporter_id, category, description, photo_url, video_url, '
          'status, credibility_score, is_sos, verified_by, created_at, updated_at, '
          'lat, lng',
        )
        .inFilter('status', ['pending', 'verified'])
        .order('is_sos', ascending: false)
        .order('created_at', ascending: false);

    final incidents = (rows as List)
        .map((row) => Incident.fromMap(row as Map<String, dynamic>))
        .toList();

    await _writeCache(incidents);
    return incidents;
  }

  Future<void> confirmIncident({
    required String incidentId,
    required String memberId,
  }) async {
    await SupabaseService.client.from('incident_confirmations').insert({
      'incident_id': incidentId,
      'member_id': memberId,
    });
  }

  Future<void> _writeCache(List<Incident> incidents) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(incidents
        .map((i) => {
              'id': i.id,
              'reporter_id': i.reporterId,
              'category': i.category.name,
              'description': i.description,
              'photo_url': i.photoUrl,
              'lat': i.latitude,
              'lng': i.longitude,
              'status': i.status.name,
              'credibility_score': i.credibilityScore,
              'is_sos': i.isSos,
              'created_at': i.createdAt.toIso8601String(),
              'updated_at': i.updatedAt.toIso8601String(),
            })
        .toList());
    await prefs.setString(_cacheKey, encoded);
    await prefs.setString(
      '${_cacheKey}_ts',
      DateTime.now().toIso8601String(),
    );
  }

  /// Returns (incidents, lastUpdated) from local cache, or (empty, null)
  /// if nothing has ever been cached.
  Future<(List<Incident>, DateTime?)> readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final ts = prefs.getString('${_cacheKey}_ts');
    if (raw == null) return (<Incident>[], null);

    final decoded = jsonDecode(raw) as List;
    final incidents = decoded.map((m) {
      return Incident(
        id: m['id'],
        reporterId: m['reporter_id'],
        category: IncidentCategory.fromDb(m['category']),
        description: m['description'],
        photoUrl: m['photo_url'],
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        status: IncidentStatus.fromDb(m['status']),
        credibilityScore: m['credibility_score'],
        isSos: m['is_sos'],
        createdAt: DateTime.parse(m['created_at']),
        updatedAt: DateTime.parse(m['updated_at']),
      );
    }).toList();

    return (incidents, ts != null ? DateTime.parse(ts) : null);
  }
}
