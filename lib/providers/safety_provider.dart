import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../models/circle_member_location.dart';
import '../models/family_member.dart';
import '../models/safety_circle_request.dart';
import '../models/risk_zone.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../utils/format_utils.dart';
import '../widgets/session_history_list.dart' show SessionHistoryEntry;

/// A family-circle action that failed, with a message safe to show as-is
/// (e.g. "This invite link has expired. Ask for a new one.").
class FamilyCircleException implements Exception {
  final String message;
  const FamilyCircleException(this.message);

  @override
  String toString() => message;
}

class LocationUpdate {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final Duration etaRemaining;
  final double distanceRemainingKm;

  LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.etaRemaining,
    required this.distanceRemainingKm,
  });
}

/// Handles live ETA/location sharing (now backed by real GPS via
/// LocationService) and one-tap "I'm Safe" broadcasts.
///
/// Also owns the family circle: invite links, members and their last-known
/// locations. Backed by safety_circle_contacts / family_invites /
/// location_shares / safety_broadcasts — see
/// sql/family_circle_invites_migration.sql.
///
/// ETA ASSUMPTION: there's no routing API wired up yet, so "distance
/// remaining" is computed as a straight-line (haversine) distance to an
/// optional destination, and ETA is estimated using a rough average
/// travel speed. Replace `_assumedSpeedKmh` or plug in a real routing
/// service (matching whatever your RouteProvider/routing_service.dart
/// already does) for an accurate ETA.
class SafetyProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  List<FamilyMember> _family = [];
  List<FamilyInvite> _openInvites = [];
  List<SafetyCircleRequest> _pendingRequests = [];
  bool _isSharing = false;
  String? _activeShareId;
  LocationUpdate? _latestUpdate;
  RiskZone? _activeRiskZone;
  DateTime? _lastBroadcastAt;
  String? _errorMessage;
  bool _isLoading = false;

  StreamSubscription<LatLng>? _positionSubscription;
  Timer? _circleLocationsRefreshTimer;
  LatLng? _destination;
  static const double _assumedSpeedKmh = 20; // rough avg travel speed estimate

  /// Marks an ETA session that only runs on this device because the server
  /// share couldn't be created (signed out, no permission, or offline).
  static const String _kLocalOnlyShare = 'local-only';

  /// True when family can actually see this ETA session.
  bool get isSharingWithFamily =>
      _isSharing && _activeShareId != null && _activeShareId != _kLocalOnlyShare;

  /// Everyone in your family circle: confirmed members, plus people who
  /// opened your invite and haven't confirmed yet. No demo placeholders —
  /// an empty circle is shown as empty.
  List<FamilyMember> get family => _family;

  List<FamilyMember> get confirmedFamily =>
      _family.where((m) => m.isConfirmed).toList();

  /// Invite links you've created that nobody has used yet.
  List<FamilyInvite> get openInvites => _openInvites;

  /// Where each confirmed family member was last seen — one marker each on
  /// the home and ETA maps.
  List<CircleMemberLocation> get circleLocations => [
    for (final m in _family)
      if (m.isConfirmed && m.hasLocation) m.toLocation(),
  ];

  /// Incoming "X wants to add you to their safety circle" requests, where
  /// this signed-in user is the one being added. Nothing in [circle] or
  /// [circleLocations] here — this is the other direction: people who want
  /// *this* user's location to show up on *their* map.
  List<SafetyCircleRequest> get pendingRequests => _pendingRequests;
  bool get isLoading => _isLoading;
  bool get isSharing => _isSharing;
  LocationUpdate? get latestUpdate => _latestUpdate;
  RiskZone? get activeRiskZone => _activeRiskZone;
  DateTime? get lastBroadcastAt => _lastBroadcastAt;
  String? get errorMessage => _errorMessage;

  /// Loads the family circle and your open invites. Shows a spinner on the
  /// first load only; later refreshes (the 45s timer) are silent.
  Future<void> loadFamilyCircle() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _family = [];
      _openInvites = [];
      notifyListeners();
      return;
    }

    _isLoading = _family.isEmpty;
    notifyListeners();

    try {
      final rows = await SupabaseService.client.rpc('my_family_circle');
      _family = (rows as List)
          .map((r) => FamilyMember.fromMap(r as Map<String, dynamic>))
          .toList();
      _family = await _withLastSafe(_family);

      final invites = await SupabaseService.client
          .from('family_invites')
          .select('code, expires_at')
          .eq('owner_id', userId)
          .isFilter('used_by', null)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);
      _openInvites = (invites as List)
          .map((r) => FamilyInvite.fromMap(r as Map<String, dynamic>))
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = "Couldn't load your family circle. Pull to retry.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _startCircleLocationsAutoRefresh();
  }

  /// Attaches each confirmed member's latest "I'm Safe" time. Best-effort:
  /// if the lookup fails the circle still shows, just without that line.
  Future<List<FamilyMember>> _withLastSafe(List<FamilyMember> members) async {
    final ids = [for (final m in members) if (m.isConfirmed) m.memberId];
    if (ids.isEmpty) return members;
    try {
      final rows = await SupabaseService.client
          .from('safety_broadcasts')
          .select('user_id, sent_at')
          .inFilter('user_id', ids)
          .gte(
            'sent_at',
            DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String(),
          )
          .order('sent_at', ascending: false);
      final latest = <String, DateTime>{};
      for (final r in rows as List) {
        final id = r['user_id'] as String;
        final at = DateTime.tryParse(r['sent_at'] as String? ?? '');
        if (at != null) latest.putIfAbsent(id, () => at);
      }
      return [for (final m in members) m.withLastSafeAt(latest[m.memberId])];
    } catch (_) {
      return members;
    }
  }

  /// Refreshes members' last-known locations (same RPC as the full load).
  Future<void> fetchCircleLocations() => loadFamilyCircle();

  /// Public https link for an invite code. Messaging apps only make https
  /// links tappable, so this points at the `family-invite` Edge Function,
  /// which redirects into the app.
  static Uri inviteLinkFor(String code) {
    final api = Uri.parse(SupabaseService.client.rest.url);
    return Uri.parse('${api.origin}/functions/v1/family-invite?code=$code');
  }

  /// Creates a single-use, 7-day invite and returns its shareable link.
  /// Throws with a user-readable message on failure.
  Future<Uri> createInvite() async {
    try {
      final code = await SupabaseService.client.rpc('create_family_invite');
      await loadFamilyCircle();
      return inviteLinkFor(code as String);
    } on PostgrestException catch (e) {
      throw FamilyCircleException(e.message);
    }
  }

  Future<void> revokeInvite(String code) async {
    await SupabaseService.client.from('family_invites').delete().eq('code', code);
    _openInvites = _openInvites.where((i) => i.code != code).toList();
    notifyListeners();
  }

  /// Accepts an invite as the signed-in user. This only creates a pending
  /// link: the server then emails them, and [pendingRequests] gets the
  /// in-app confirmation. Returns that pending request.
  Future<SafetyCircleRequest> acceptInvite(String code) async {
    if (SupabaseService.currentUserId == null) {
      throw const FamilyCircleException('Sign in to join a family circle.');
    }
    try {
      final result = await SupabaseService.client.rpc(
        'accept_family_invite',
        params: {'invite_code': code},
      );
      await loadPendingRequests();
      final map = result as Map;
      final linkId = map['link_id'] as String;
      return _pendingRequests.firstWhere(
        (r) => r.id == linkId,
        orElse: () => SafetyCircleRequest(
          id: linkId,
          ownerId: '',
          ownerName: map['inviter_name'] as String? ?? 'Someone',
          relationship: 'Family',
        ),
      );
    } on PostgrestException catch (e) {
      throw FamilyCircleException(e.message);
    }
  }

  /// Removes a member, or leaves their circle — either side can do this.
  Future<void> removeFamilyMember(String linkId) async {
    try {
      await SupabaseService.client.rpc(
        'remove_family_member',
        params: {'target_link_id': linkId},
      );
      _family = _family.where((m) => m.linkId != linkId).toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = "Couldn't remove that member. Try again.";
    }
    notifyListeners();
  }

  /// Keeps circle-member markers reasonably fresh while the home map is
  /// open, without needing a realtime subscription for what's a
  /// low-frequency "where are they" check.
  void _startCircleLocationsAutoRefresh() {
    _circleLocationsRefreshTimer?.cancel();
    _circleLocationsRefreshTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => fetchCircleLocations());
  }

  /// Loads requests where someone else has added *this* user to *their*
  /// circle and is waiting on consent. Until one is confirmed, the server
  /// side (the `safety_circle_last_locations` view and the RLS policy on
  /// `location_shares`) refuses to expose this user's location to that
  /// owner no matter what the client does — this list exists only so the
  /// user can see who's asking and act on it.
  Future<void> loadPendingRequests() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final rows = await SupabaseService.client
          .from('my_pending_safety_circle_requests')
          .select();
      _pendingRequests = (rows as List)
          .map((r) => SafetyCircleRequest.fromMap(r as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {
      // View not migrated yet, or none pending — leave whatever was there.
    }
  }

  /// Confirms or declines one pending request via a SECURITY DEFINER RPC
  /// (rather than an ordinary table update) so a client can only ever flip
  /// its *own* incoming request's status — never edit the owner's contact
  /// row directly.
  Future<void> respondToPendingRequest(String requestId, bool accept) async {
    try {
      await SupabaseService.client.rpc('respond_to_safety_circle_request', params: {
        'request_id': requestId,
        'accept': accept,
      });
    } catch (e) {
      _errorMessage = 'Could not respond to the request. Please try again.';
    }
    _pendingRequests = _pendingRequests.where((r) => r.id != requestId).toList();
    notifyListeners();
  }

  /// Starts sharing REAL live location/ETA using LocationService.
  /// [destination] is optional — if provided, distance/ETA are computed
  /// against it. If null, we still share live position, just without a
  /// meaningful ETA countdown.
  Future<void> startSharingEta({
    RiskZone? currentRiskZone,
    LatLng? destination,
  }) async {
    final userId = SupabaseService.currentUserId;
    final start = await _resolveStartLocation(currentRiskZone: currentRiskZone);

    _destination = destination;
    final initialDistanceKm = destination != null
        ? Geolocator_distanceKm(start, destination)
        : 0.0;
    final initialEta = destination != null
        ? Duration(seconds: ((initialDistanceKm / _assumedSpeedKmh) * 3600).round())
        : Duration.zero;

    _activeRiskZone = currentRiskZone;
    _isSharing = true;
    _latestUpdate = LocationUpdate(
      latitude: start.latitude,
      longitude: start.longitude,
      timestamp: DateTime.now(),
      etaRemaining: initialEta,
      distanceRemainingKm: initialDistanceKm,
    );
    _errorMessage = null;

    final hasLocationPermissions = await _hasLocationPermissions();
    if (userId != null && hasLocationPermissions) {
      try {
        final row = await SupabaseService.client
            .from('location_shares')
            .insert({
              'owner_id': userId,
              'zone_id': currentRiskZone?.id,
              'lat': start.latitude,
              'lng': start.longitude,
              'eta_seconds': initialEta.inSeconds,
              'distance_km': initialDistanceKm,
              'is_active': true,
            })
            .select()
            .single();

        _activeShareId = row['id'] as String;
      } catch (e) {
        // Keep the local ETA readout, but say plainly that family can't see
        // it — never imply a share that the server didn't accept.
        debugPrint('startSharingEta insert failed: $e');
        _activeShareId = _kLocalOnlyShare;
        _errorMessage = "Couldn't start sharing. Your family can't see your location. "
            'Check your connection and try again.';
      }
    } else {
      _activeShareId = _kLocalOnlyShare;
      _errorMessage = userId == null
          ? 'Sign in to share your location with your family.'
          : "Location permission is off, so your family can't see your location.";
    }

    _positionSubscription?.cancel();
    if (hasLocationPermissions) {
      try {
        _positionSubscription = _locationService.watchPosition().listen(
          (pos) => _onPositionUpdate(pos),
          onError: (_) {},
        );
      } catch (_) {
        _positionSubscription = null;
      }
    }

    notifyListeners();
  }

  Future<void> _onPositionUpdate(LatLng pos) async {
    if (!_isSharing || _activeShareId == null) return;

    final distanceKm = _destination != null ? Geolocator_distanceKm(pos, _destination!) : 0.0;
    final etaSeconds = _destination != null ? ((distanceKm / _assumedSpeedKmh) * 3600).round() : 0;

    final update = LocationUpdate(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      etaRemaining: Duration(seconds: etaSeconds),
      distanceRemainingKm: distanceKm,
    );
    _latestUpdate = update;
    notifyListeners();

    if (isSharingWithFamily) {
      try {
        await SupabaseService.client.from('location_shares').update({
          'lat': update.latitude,
          'lng': update.longitude,
          'eta_seconds': update.etaRemaining.inSeconds,
          'distance_km': update.distanceRemainingKm,
        }).eq('id', _activeShareId!);
        if (_errorMessage != null) {
          _errorMessage = null;
          notifyListeners();
        }
      } catch (e) {
        // Transient: the next position fix retries the same idempotent update.
        debugPrint('location share update failed: $e');
        _errorMessage =
            'Your family may be seeing an older location. Reconnecting...';
        notifyListeners();
      }
    }

    if (_destination != null && distanceKm <= 0.05) {
      // Within ~50m of destination — treat as arrived.
      await stopSharing();
    }
  }

  /// Ends the ETA session: stops GPS updates and marks the server share
  /// inactive, so family see "last seen" instead of "sharing now". A
  /// local-only session (the share never reached the server) has nothing to
  /// close remotely.
  Future<void> stopSharing() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_activeShareId != null && _activeShareId != _kLocalOnlyShare) {
      try {
        await SupabaseService.client
            .from('location_shares')
            .update({'is_active': false}).eq('id', _activeShareId!);
      } catch (e) {
        _errorMessage = 'Could not stop sharing. Please try again.';
      }
    }
    _isSharing = false;
    _activeShareId = null;
    _activeRiskZone = null;
    _destination = null;
    notifyListeners();
  }

  /// The signed-in user's own sharing activity from the last 30 days —
  /// live-location sessions and "I'm Safe" marks — newest first. Throws on
  /// a failed load so the UI can say so instead of showing an empty list.
  Future<List<SessionHistoryEntry>> loadMySessionHistory() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const [];
    final since =
        DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();

    final shares = await SupabaseService.client
        .from('location_shares')
        .select('id, created_at, updated_at, is_active, distance_km')
        .eq('owner_id', userId)
        .gte('created_at', since)
        .order('created_at', ascending: false)
        .limit(50);
    final broadcasts = await SupabaseService.client
        .from('safety_broadcasts')
        .select('id, sent_at')
        .eq('user_id', userId)
        .gte('sent_at', since)
        .order('sent_at', ascending: false)
        .limit(50);

    final entries = <SessionHistoryEntry>[
      for (final r in shares as List)
        if (DateTime.tryParse(r['created_at'] as String? ?? '') != null)
          SessionHistoryEntry(
            id: 'share-${r['id']}',
            title: 'Shared live location',
            occurredAt: DateTime.parse(r['created_at'] as String).toLocal(),
            subtitle: r['is_active'] == true
                ? 'Still sharing'
                : _endedLabel(r['updated_at'] as String?),
          ),
      for (final r in broadcasts as List)
        if (DateTime.tryParse(r['sent_at'] as String? ?? '') != null)
          SessionHistoryEntry(
            id: 'safe-${r['id']}',
            title: 'Marked yourself safe',
            occurredAt: DateTime.parse(r['sent_at'] as String).toLocal(),
          ),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return entries;
  }

  static String _endedLabel(String? updatedAt) {
    final at = DateTime.tryParse(updatedAt ?? '');
    return at == null ? 'Ended' : 'Ended ${timeAgo(at.toLocal())}';
  }

  /// Records an "I'm Safe" for the signed-in user. Returns true only once
  /// the row is actually saved — a safety status must never show as sent
  /// when it wasn't. Confirmed family see it in their Family circle.
  Future<bool> sendImSafeBroadcast({RiskZone? currentRiskZone}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _errorMessage = "Sign in to let your family know you're safe.";
      notifyListeners();
      return false;
    }
    try {
      await SupabaseService.client.from('safety_broadcasts').insert({
        'user_id': userId,
        'zone_id': currentRiskZone?.id,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
      });
      _lastBroadcastAt = DateTime.now();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('sendImSafeBroadcast failed: $e');
      _errorMessage =
          "Couldn't send \"I'm Safe\". Check your connection and try again.";
      notifyListeners();
      return false;
    }
  }

  Future<LatLng> _resolveStartLocation({RiskZone? currentRiskZone}) async {
    try {
      final granted = await _locationService.ensurePermission();
      if (!granted) return _fallbackLocation(currentRiskZone);
      final current = await _locationService.getCurrentLocation();
      if (current != null) return current;
    } catch (_) {
      return _fallbackLocation(currentRiskZone);
    }

    return _fallbackLocation(currentRiskZone);
  }

  Future<bool> _hasLocationPermissions() async {
    try {
      return await _locationService.ensurePermission();
    } catch (_) {
      return false;
    }
  }

  LatLng _fallbackLocation(RiskZone? zone) {
    if (zone != null && zone.boundary.isNotEmpty) {
      final totalLat = zone.boundary.fold<double>(0, (sum, point) => sum + point.latitude);
      final totalLng = zone.boundary.fold<double>(0, (sum, point) => sum + point.longitude);
      return LatLng(
        totalLat / zone.boundary.length,
        totalLng / zone.boundary.length,
      );
    }

    return const LatLng(6.9615, 79.9010);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _circleLocationsRefreshTimer?.cancel();
    super.dispose();
  }
}

/// Straight-line (haversine) distance in km between two points.
/// Uses the `Distance` calculator from latlong2, which is already a
/// dependency in this project (used by risk_zone.dart).
double Geolocator_distanceKm(LatLng a, LatLng b) {
  const calculator = Distance();
  return calculator.as(LengthUnit.Kilometer, a, b);
}