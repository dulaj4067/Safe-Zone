import 'package:flutter/foundation.dart';

import '../models/incident.dart';
import '../services/incident_service.dart';

enum IncidentViewMode { map, list }

class IncidentProvider extends ChangeNotifier {
  final IncidentService _service;

  IncidentProvider({IncidentService? service})
      : _service = service ?? IncidentService();

  List<Incident> _incidents = [];
  bool _isLoading = false;
  bool _isOffline = false;
  DateTime? _lastUpdated;
  IncidentViewMode _viewMode = IncidentViewMode.map;
  String? _error;

  List<Incident> get incidents => _incidents;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  DateTime? get lastUpdated => _lastUpdated;
  IncidentViewMode get viewMode => _viewMode;
  String? get error => _error;

  /// SOS incidents surfaced first, per Story 1 AC.
  List<Incident> get sortedIncidents {
    final list = [..._incidents];
    list.sort((a, b) {
      if (a.isSos != b.isSos) return a.isSos ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  void setViewMode(IncidentViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _incidents = await _service.fetchIncidents();
      _isOffline = false;
      _lastUpdated = DateTime.now();
    } catch (e) {
      // Network/query failed — fall back to cache per Story 1's offline AC.
      final (cached, cachedAt) = await _service.readCache();
      _incidents = cached;
      _isOffline = true;
      _lastUpdated = cachedAt;
      _error = cached.isEmpty ? 'Unable to load incidents: $e' : null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> confirmIncident({
    required String incidentId,
    required String memberId,
  }) async {
    await _service.confirmIncident(
      incidentId: incidentId,
      memberId: memberId,
    );
    // Optimistically bump the local credibility score so the UI reflects
    // the change without waiting for a full reload.
    final index = _incidents.indexWhere((i) => i.id == incidentId);
    if (index != -1) {
      final old = _incidents[index];
      _incidents[index] = Incident(
        id: old.id,
        reporterId: old.reporterId,
        category: old.category,
        description: old.description,
        photoUrl: old.photoUrl,
        videoUrl: old.videoUrl,
        latitude: old.latitude,
        longitude: old.longitude,
        status: old.status,
        credibilityScore: old.credibilityScore + 1,
        isSos: old.isSos,
        verifiedBy: old.verifiedBy,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
      );
      notifyListeners();
    }
  }
}
