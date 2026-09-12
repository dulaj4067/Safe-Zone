import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import '../models/alert_engagement.dart';
import '../models/zone.dart';
import '../services/alert_engagement_service.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class AlertProvider extends ChangeNotifier {
  final AlertService _service;
  final NotificationService _notificationService;
  final AlertEngagementService _engagementService;

  AlertProvider({
    AlertService? service,
    NotificationService? notificationService,
    AlertEngagementService? engagementService,
  })  : _service = service ?? AlertService(),
        _notificationService = notificationService ?? NotificationService(),
        _engagementService = engagementService ?? AlertEngagementService();

  List<DisasterAlert> _activeAlerts = [];
  DisasterAlert? _bannerAlert; // most recent unread alert, shown as banner
  bool _isOffline = false;
  DateTime? _lastUpdated;
  bool _myZoneOnly = false;
  String? _userZoneId;

  /// Returns active alerts. When [myZoneOnly] is true and [userZoneId] is set,
  /// returns only alerts affecting the citizen's zone.
  List<DisasterAlert> get activeAlerts {
    if (!_myZoneOnly || _userZoneId == null || _userZoneId!.isEmpty) {
      return _activeAlerts;
    }
    return _service.filterAlertsByZone(_activeAlerts, _userZoneId);
  }

  /// Returns all active alerts without zone filtering (e.g. for authorities).
  List<DisasterAlert> get allAlerts => _activeAlerts;
  bool get myZoneOnly => _myZoneOnly;
  String? get userZoneId => _userZoneId;
  DisasterAlert? get bannerAlert => _bannerAlert;
  bool get isOffline => _isOffline;
  DateTime? get lastUpdated => _lastUpdated;
  NotificationService get notificationService => _notificationService;
  AlertEngagementService get engagementService => _engagementService;

  Future<void> init() async {
    await _notificationService.init();
    _myZoneOnly = await _service.getMyZoneAlertsOnly();
    _userZoneId = await _service.getSavedZoneId();
    await _loadInitial();
    _syncBannerWithFilter();
    _service.subscribeToAlerts(
      onInsert: _handleRealtimeInsert,
      onUpdate: _handleRealtimeUpdate,
    );
  }

  /// Sets whether the citizen only follows alerts affecting their zone.
  /// Persists immediately to SharedPreferences and updates all listeners without restarting.
  Future<void> setMyZoneOnly(bool enabled, {String? zoneId}) async {
    _myZoneOnly = enabled;
    if (zoneId != null && zoneId.isNotEmpty) {
      _userZoneId = zoneId;
      await _service.saveZoneId(zoneId);
    }
    await _service.saveMyZoneAlertsOnly(enabled);
    _syncBannerWithFilter();
    notifyListeners();
  }

  /// Updates the citizen's current zone ID.
  Future<void> setUserZoneId(String? zoneId) async {
    if (_userZoneId != zoneId) {
      _userZoneId = zoneId;
      if (zoneId != null && zoneId.isNotEmpty) {
        await _service.saveZoneId(zoneId);
      }
      _syncBannerWithFilter();
      notifyListeners();
    }
  }

  /// Checks if an alert affects the citizen's designated zone.
  bool alertAffectsMyZone(DisasterAlert alert) {
    if (!_myZoneOnly || _userZoneId == null || _userZoneId!.isEmpty) {
      return true;
    }
    return alert.affectedZoneId == _userZoneId;
  }

  void _syncBannerWithFilter() {
    if (_bannerAlert != null && !alertAffectsMyZone(_bannerAlert!)) {
      _bannerAlert = null;
    }
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
    _syncBannerWithFilter();
    notifyListeners();
  }

  void _handleRealtimeInsert(DisasterAlert alert) {
    _activeAlerts.insert(0, alert);

    final bool affectsCitizen = alertAffectsMyZone(alert);

    if (affectsCitizen) {
      // Story 2 AC: show as in-app banner immediately, no restart required.
      _bannerAlert = alert;

      // Trigger OS-level notification. Critical (red) bypasses DND/silent mode.
      if (alert.severity.isCritical) {
        _notificationService.showCriticalAlert(alert);
      } else {
        _notificationService.showNormalAlert(alert);
      }
    }

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
        _notificationService.cancelAlert(alert.id);
      } else {
        _activeAlerts[index] = alert;
        if (_bannerAlert?.id == alert.id) {
          if (!alertAffectsMyZone(alert)) {
            _bannerAlert = null;
          } else {
            _bannerAlert = alert;
          }
        }
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

  // ─── Engagement & Resident Reach Metrics ───────────────────────────────────

  /// Fetches resident seen/acknowledged engagement analytics for an alert.
  Future<ZoneAlertEngagement> getEngagementForAlert(
    String alertId, {
    String? zoneId,
    String? zoneName,
    List<Zone>? knownZones,
  }) {
    return _engagementService.getZoneEngagement(
      alertId,
      zoneId: zoneId,
      zoneName: zoneName,
      knownZones: knownZones,
    );
  }

  /// Citizen action: acknowledge receipt and safety for an active alert.
  Future<void> acknowledgeAlert(String alertId, {String? userId}) async {
    final uid = userId ?? SupabaseService.currentUserId ?? 'resident_local';
    await _engagementService.markAcknowledged(alertId, uid);
    notifyListeners();
  }

  /// Automatically marks an alert as seen by the current citizen.
  Future<void> markAlertSeen(String alertId, {String? userId}) async {
    final uid = userId ?? SupabaseService.currentUserId ?? 'resident_local';
    await _engagementService.markSeen(alertId, uid);
    notifyListeners();
  }

  /// Checks if current citizen has acknowledged the alert.
  Future<bool> hasAcknowledged(String alertId, {String? userId}) {
    final uid = userId ?? SupabaseService.currentUserId ?? 'resident_local';
    return _engagementService.hasUserAcknowledged(alertId, uid);
  }

  /// Demo/Simulation tool: adjust seen/ack percentages for testing & evaluation.
  Future<void> simulateZoneEngagement(
    String alertId,
    String? zoneId, {
    required double ackRate,
    required double seenRate,
  }) async {
    await _engagementService.simulateEngagement(
      alertId,
      zoneId,
      ackRate: ackRate,
      seenRate: seenRate,
    );
    notifyListeners();
  }

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
