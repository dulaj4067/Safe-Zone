import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import '../services/alert_service.dart';

class AlertProvider extends ChangeNotifier {
  final AlertService _service;

  AlertProvider({AlertService? service}) : _service = service ?? AlertService();

  List<DisasterAlert> _activeAlerts = [];
  DisasterAlert? _bannerAlert; // most recent unread alert, shown as banner
  bool _isOffline = false;
  DateTime? _lastUpdated;

  List<DisasterAlert> get activeAlerts => _activeAlerts;
  DisasterAlert? get bannerAlert => _bannerAlert;
  bool get isOffline => _isOffline;
  DateTime? get lastUpdated => _lastUpdated;

  Future<void> init() async {
    await _loadInitial();
    _service.subscribeToAlerts(
      onInsert: _handleRealtimeInsert,
      onUpdate: _handleRealtimeUpdate,
    );
  }

  Future<void> _loadInitial() async {
    try {
      _activeAlerts = await _service.fetchActiveAlerts();
      _isOffline = false;
      _lastUpdated = DateTime.now();
    } catch (e) {
      final (cached, cachedAt) = await _service.readCache();
      _activeAlerts = cached;
      _isOffline = true;
      _lastUpdated = cachedAt;
    }
    notifyListeners();
  }

  void _handleRealtimeInsert(DisasterAlert alert) {
    _activeAlerts.insert(0, alert);
    // Story 2 AC: show as in-app banner immediately, no restart required.
    _bannerAlert = alert;
    notifyListeners();
  }

  void _handleRealtimeUpdate(DisasterAlert alert) {
    final index = _activeAlerts.indexWhere((a) => a.id == alert.id);
    if (index != -1) {
      if (alert.status == AlertStatus.archived ||
          alert.resolvedAt != null) {
        _activeAlerts.removeAt(index);
        // Story 2 AC: clear any active banner tied to a now-resolved alert.
        if (_bannerAlert?.id == alert.id) {
          _bannerAlert = null;
        }
      } else {
        _activeAlerts[index] = alert;
      }
      notifyListeners();
    }
  }

  void dismissBanner() {
    _bannerAlert = null;
    notifyListeners();
  }

  /// Story 4: resolve/archive actions from the broadcast dashboard.
  /// The realtime UPDATE subscription (`_handleRealtimeUpdate`) removes
  /// the alert from `_activeAlerts` once the server confirms the status
  /// change, so we don't optimistically mutate local state here — it
  /// keeps a single source of truth and avoids the list flickering if
  /// the update is rejected by RLS.
  Future<void> resolveAlert(String alertId) => _service.resolveAlert(alertId);

  Future<void> archiveAlert(String alertId) => _service.archiveAlert(alertId);

  /// Call from a manual pull-to-refresh; also useful right after
  /// reconnecting so alerts missed while offline get synced in per the
  /// alert_offline_cache pattern described in Story 2.
  Future<void> refresh() => _loadInitial();

  @override
  void dispose() {
    _service.unsubscribe();
    super.dispose();
  }
}
