import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/incident.dart';
import 'supabase_service.dart';

/// Handles fetching incidents from Supabase and local caching for the
/// offline-first fallback described in Story 1's AC.
class IncidentService {
  static const _cacheKey = 'cached_incidents_v1';

  /// Fetches incidents via the `incidents_with_latlon` view.
  /// Optionally filters by [status], [category], or [sosOnly].
  /// When [includeAll] is true, fetches all statuses (for admin review).
  Future<List<Incident>> fetchIncidents({
    IncidentStatus? status,
    IncidentCategory? category,
    bool sosOnly = false,
    bool includeAll = false,
  }) async {
    final client = SupabaseService.client;

    var query = client.from('incidents_with_latlon').select(
      'id, reporter_id, category, description, photo_url, video_url, '
      'status, credibility_score, is_sos, verified_by, created_at, updated_at, '
      'lat, lng',
    );

    if (!includeAll && status == null) {
      query = query.inFilter('status', ['pending', 'verified']);
    }
    if (status != null) {
      query = query.eq('status', status.name);
    }
    if (category != null) {
      query = query.eq('category', category.dbValue);
    }
    if (sosOnly) {
      query = query.eq('is_sos', true);
    }

    final rows = await query
        .order('is_sos', ascending: false)
        .order('created_at', ascending: false);

    final incidents = (rows as List)
        .map((row) => Incident.fromMap(row as Map<String, dynamic>))
        .toList();

    await _writeCache(incidents);
    return incidents;
  }

  /// Submits a new incident to Supabase. Returns the created [Incident].
  Future<Incident> submitIncident(Incident draft) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw StateError('Must be signed in to report an incident.');
    }

    final inserted = await SupabaseService.client
        .from('incidents')
        .insert(draft.toInsertMap(reporterId: userId))
        .select(
          'id, reporter_id, category, description, photo_url, video_url, '
          'status, credibility_score, is_sos, verified_by, created_at, updated_at',
        )
        .single();

    // The insert response doesn't include lat/lng from the view, so
    // we manually set them from the draft.
    final map = Map<String, dynamic>.from(inserted);
    map['lat'] = draft.latitude;
    map['lng'] = draft.longitude;

    return Incident.fromMap(map);
  }

  /// Uploads a file to the `incident-media` storage bucket.
  /// Returns the public URL.
  Future<String> uploadEvidence(File file, String storagePath) async {
    await SupabaseService.client.storage
        .from('incident-media')
        .upload(storagePath, file);

    return SupabaseService.client.storage
        .from('incident-media')
        .getPublicUrl(storagePath);
  }

  /// Records a member confirmation on an incident.
  Future<void> confirmIncident({
    required String incidentId,
    required String memberId,
  }) async {
    await SupabaseService.client.from('incident_confirmations').insert({
      'incident_id': incidentId,
      'member_id': memberId,
    });
  }

  /// Checks whether the current user has already confirmed this incident.
  Future<bool> hasUserConfirmed({
    required String incidentId,
    required String userId,
  }) async {
    final rows = await SupabaseService.client
        .from('incident_confirmations')
        .select('id')
        .eq('incident_id', incidentId)
        .eq('member_id', userId);
    return (rows as List).isNotEmpty;
  }

  /// Updates the status of an incident (admin only — enforced by RLS).
  Future<void> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus newStatus,
    String? verifiedBy,
  }) async {
    final updates = <String, dynamic>{
      'status': newStatus.name,
    };
    if (verifiedBy != null) {
      updates['verified_by'] = verifiedBy;
    }
    await SupabaseService.client
        .from('incidents')
        .update(updates)
        .eq('id', incidentId);
  }

  Future<void> _writeCache(List<Incident> incidents) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(incidents
        .map((i) => {
              'id': i.id,
              'reporter_id': i.reporterId,
              'category': i.category.dbValue,
              'description': i.description,
              'photo_url': i.photoUrl,
              'video_url': i.videoUrl,
              'lat': i.latitude,
              'lng': i.longitude,
              'status': i.status.name,
              'credibility_score': i.credibilityScore,
              'is_sos': i.isSos,
              'verified_by': i.verifiedBy,
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
        videoUrl: m['video_url'],
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        status: IncidentStatus.fromDb(m['status']),
        credibilityScore: m['credibility_score'],
        isSos: m['is_sos'],
        verifiedBy: m['verified_by'],
        createdAt: DateTime.parse(m['created_at']),
        updatedAt: DateTime.parse(m['updated_at']),
      );
    }).toList();

    return (incidents, ts != null ? DateTime.parse(ts) : null);
  }
}
