import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/incident.dart';
import '../services/incident_service.dart';

/// Which view IncidentsScreen is currently showing. Lives here (rather
/// than as screen-local state) so the choice survives screen rebuilds
/// and so other screens could read/drive it later if needed.
enum IncidentViewMode { map, list }

/// Owns incident state for the app: offline-first load (cache first,
/// then Supabase), pull-to-refresh, and the sort order the map/list
/// screens render incidents in.
class IncidentProvider extends ChangeNotifier {
  final IncidentService _service = IncidentService();

  List<Incident> _incidents = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isOffline = false;
  String? _errorMessage;
  DateTime? _lastUpdated;
  bool _hasLoadedOnce = false;
  IncidentViewMode _viewMode = IncidentViewMode.map;

  // Filtering state
  IncidentStatus? _statusFilter;
  IncidentCategory? _categoryFilter;
  bool _sosFilter = false;

  List<Incident> get incidents => List.unmodifiable(_incidents);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  IncidentViewMode get viewMode => _viewMode;
  IncidentStatus? get statusFilter => _statusFilter;
  IncidentCategory? get categoryFilter => _categoryFilter;
  bool get sosFilter => _sosFilter;

  /// True when the most recent Supabase fetch failed and we're showing
  /// stale (cached or previously-fetched) data instead.
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;

  /// SOS incidents first, then newest first. IncidentService.fetchIncidents()
  /// already asks Supabase for this order, but the local cache (read via
  /// SharedPreferences on cold start) makes no ordering guarantee, so we
  /// re-sort here to keep map markers and list screens consistent
  /// regardless of which source the data came from.
  List<Incident> get sortedIncidents {
    final list = List<Incident>.from(_incidents);
    list.sort((a, b) {
      if (a.isSos != b.isSos) return a.isSos ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Returns [sortedIncidents] filtered by the currently active filters.
  List<Incident> get filteredIncidents {
    var list = sortedIncidents;

    if (_statusFilter != null) {
      list = list.where((i) => i.status == _statusFilter).toList();
    }
    if (_categoryFilter != null) {
      list = list.where((i) => i.category == _categoryFilter).toList();
    }
    if (_sosFilter) {
      list = list.where((i) => i.isSos).toList();
    }

    return list;
  }

  // ─── Filter setters ────────────────────────────────────────────────────────

  void setStatusFilter(IncidentStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setCategoryFilter(IncidentCategory? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void setSosFilter(bool enabled) {
    _sosFilter = enabled;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _categoryFilter = null;
    _sosFilter = false;
    notifyListeners();
  }

  // ─── Load & Refresh ────────────────────────────────────────────────────────

  /// Offline-first load. Call once on screen init (HomeScreen already
  /// does this in its addPostFrameCallback). Paints cached incidents
  /// immediately if any exist, then fetches fresh data from Supabase.
  /// Safe to call multiple times — only does work on the first call
  /// unless [forceRefresh] is true.
  Future<void> load({bool forceRefresh = false}) async {
    if (_hasLoadedOnce && !forceRefresh) return;
    _hasLoadedOnce = true;

    final (cached, cachedAt) = await _service.readCache();
    if (cached.isNotEmpty) {
      _incidents = cached;
      _lastUpdated = cachedAt;
      notifyListeners();
    }

    await refresh();
  }

  /// Fetches fresh data from Supabase regardless of load state. Use this
  /// for pull-to-refresh. If the network call fails, whatever's already
  /// on screen (cache or a previous successful fetch) is left in place
  /// rather than cleared, so the map doesn't go blank on a dropped
  /// connection — [isOffline] flips to true so the UI can show a banner.
  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fresh = await _service.fetchIncidents(includeAll: true);
      _incidents = fresh;
      _lastUpdated = DateTime.now();
      _isOffline = false;
    } catch (e) {
      _isOffline = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches IncidentsScreen between its map and list views. No-op if
  /// [mode] is already the current mode, so this won't trigger a
  /// pointless rebuild if a caller sets it redundantly.
  void setViewMode(IncidentViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  /// Submits a new incident report. Handles media upload if files are
  /// provided, then creates the incident record.
  Future<bool> submitIncident({
    required IncidentCategory category,
    required String description,
    required double latitude,
    required double longitude,
    bool isSos = false,
    File? photoFile,
    File? videoFile,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? photoUrl;
      String? videoUrl;

      // Upload photo if provided
      if (photoFile != null) {
        final ext = photoFile.path.split('.').last;
        final path = 'photos/${DateTime.now().millisecondsSinceEpoch}.$ext';
        photoUrl = await _service.uploadEvidence(photoFile, path);
      }

      // Upload video if provided
      if (videoFile != null) {
        final ext = videoFile.path.split('.').last;
        final path = 'videos/${DateTime.now().millisecondsSinceEpoch}.$ext';
        videoUrl = await _service.uploadEvidence(videoFile, path);
      }

      // Build draft incident for submission
      final draft = Incident(
        id: '', // server-generated
        reporterId: '', // server-enforced via auth.uid()
        category: category,
        description: description,
        photoUrl: photoUrl,
        videoUrl: videoUrl,
        latitude: latitude,
        longitude: longitude,
        status: IncidentStatus.pending,
        credibilityScore: 0,
        isSos: isSos,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _service.submitIncident(draft);
      await refresh();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ─── Admin Actions ─────────────────────────────────────────────────────────

  /// Verifies a pending incident (admin only).
  Future<bool> verifyIncident(String incidentId, String adminId) async {
    try {
      await _service.updateIncidentStatus(
        incidentId: incidentId,
        newStatus: IncidentStatus.verified,
        verifiedBy: adminId,
      );
      await refresh();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Rejects a pending incident (admin only).
  Future<bool> rejectIncident(String incidentId, String adminId) async {
    try {
      await _service.updateIncidentStatus(
        incidentId: incidentId,
        newStatus: IncidentStatus.rejected,
        verifiedBy: adminId,
      );
      await refresh();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Resolves a verified incident (admin only).
  Future<bool> resolveIncident(String incidentId, String adminId) async {
    try {
      await _service.updateIncidentStatus(
        incidentId: incidentId,
        newStatus: IncidentStatus.resolved,
        verifiedBy: adminId,
      );
      await refresh();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Confirmations ─────────────────────────────────────────────────────────

  /// Records a member confirmation on an incident, then refreshes so the
  /// updated credibility_score (computed server-side, presumably via a
  /// trigger on incident_confirmations) shows up.
  Future<void> confirmIncident({
    required String incidentId,
    required String memberId,
  }) async {
    await _service.confirmIncident(
      incidentId: incidentId,
      memberId: memberId,
    );
    await refresh();
  }

  /// Checks if the given user has already confirmed the given incident.
  Future<bool> hasUserConfirmed({
    required String incidentId,
    required String userId,
  }) async {
    return _service.hasUserConfirmed(
      incidentId: incidentId,
      userId: userId,
    );
  }
}