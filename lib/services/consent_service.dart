import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/policy_documents.dart';
import 'supabase_service.dart';

/// Records which Terms / Privacy Policy versions a user accepted.
///
/// The server table `policy_acceptances` (append-only, server-timestamped)
/// is the audit record. A per-user local copy means an unchanged policy is
/// never re-asked on every launch, and an acceptance made while offline is
/// kept and uploaded later instead of being lost — the user isn't blocked
/// from a disaster app because the network is down.
class ConsentService {
  ConsentService({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  static String _acceptedKey(String userId) => 'consent_v1_accepted_$userId';
  static String _pendingKey(String userId) => 'consent_v1_pending_$userId';

  /// Versions this user has accepted, by document id (local view, merged
  /// with the server when reachable).
  Future<Map<String, String>> acceptedVersions(String userId) async {
    final prefs = await _prefs;
    final local = _decode(prefs.getString(_acceptedKey(userId)));

    try {
      final rows = await SupabaseService.client
          .from('policy_acceptances')
          .select('document, version')
          .eq('user_id', userId);
      for (final r in rows as List) {
        final doc = r['document'] as String;
        final version = r['version'] as String;
        // Keep whichever matches a current document, so an old server row
        // can't mask a newer local acceptance.
        if (_isCurrent(doc, version) || !local.containsKey(doc)) {
          local[doc] = version;
        }
      }
      await prefs.setString(_acceptedKey(userId), jsonEncode(local));
    } catch (e) {
      debugPrint('ConsentService: using local acceptances only: $e');
    }
    return local;
  }

  /// Documents whose current version this user still needs to accept.
  Future<List<PolicyDocument>> outstanding(String userId) async {
    final accepted = await acceptedVersions(userId);
    return [
      for (final doc in requiredPolicies)
        if (accepted[doc.id] != doc.version) doc,
    ];
  }

  /// Records acceptance of [docs] for [userId]. Always succeeds locally;
  /// returns true if the server also has the record now, false if it's
  /// queued for upload.
  Future<bool> accept(String userId, List<PolicyDocument> docs) async {
    final prefs = await _prefs;
    final accepted = _decode(prefs.getString(_acceptedKey(userId)));
    final pending = _decode(prefs.getString(_pendingKey(userId)));
    for (final doc in docs) {
      accepted[doc.id] = doc.version;
      pending[doc.id] = doc.version;
    }
    await prefs.setString(_acceptedKey(userId), jsonEncode(accepted));
    await prefs.setString(_pendingKey(userId), jsonEncode(pending));
    return syncPending(userId);
  }

  /// Uploads acceptances made while offline. Idempotent: the table is
  /// unique on (user, document, version), so a repeat is ignored.
  Future<bool> syncPending(String userId) async {
    if (SupabaseService.currentUserId != userId) return false;
    final prefs = await _prefs;
    final pending = _decode(prefs.getString(_pendingKey(userId)));
    if (pending.isEmpty) return true;
    try {
      await SupabaseService.client.from('policy_acceptances').upsert(
        [
          for (final e in pending.entries)
            {'user_id': userId, 'document': e.key, 'version': e.value},
        ],
        onConflict: 'user_id,document,version',
        ignoreDuplicates: true,
      );
      await prefs.remove(_pendingKey(userId));
      return true;
    } catch (e) {
      debugPrint('ConsentService: acceptance upload queued: $e');
      return false;
    }
  }

  static bool _isCurrent(String doc, String version) =>
      requiredPolicies.any((d) => d.id == doc && d.version == version);

  static Map<String, String> _decode(String? raw) {
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
