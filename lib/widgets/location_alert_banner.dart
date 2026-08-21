import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../providers/alert_provider.dart';
import 'alert_banner.dart';

/// A reusable, location-aware wrapper around your existing AlertBanner.
/// Drop this into any screen's widget tree — it reads AlertProvider via
/// Provider internally, finds the one active alert (if any) whose
/// geofence (center + radiusMeters) covers [userLocation], and renders it
/// using AlertBanner/SeverityBadge exactly as they already look
/// elsewhere — this widget doesn't draw its own banner UI, it only adds:
///   - location filtering (only shows when actually relevant to where the
///     user is, not just "any" active alert)
///   - a shake animation on first appearance, repeating periodically for
///     critical (red) alerts specifically, to keep demanding attention
///
/// This is deliberately separate from AppShell's global AlertBanner
/// overlay (driven by AlertProvider.bannerAlert, an "unread" concept).
/// Dismissing this one only hides it locally in this widget's state — it
/// does not touch AlertProvider.bannerAlert or affect the global banner.
///
/// Usage: `LocationAlertBanner(userLocation: someLatLng)` on any screen
/// already sitting under the app's AlertProvider.
///
/// TODO: [userLocation] is currently supplied by the caller (e.g. a
/// hardcoded district center in HomeScreen). Wire this to the device's
/// real GPS position via the `geolocator` package once location
/// permissions are implemented.
class LocationAlertBanner extends StatefulWidget {
  final LatLng userLocation;

  /// Called when the banner is tapped. Typically navigates to a full
  /// alert-detail screen.
  final VoidCallback? onTap;

  const LocationAlertBanner({
    super.key,
    required this.userLocation,
    this.onTap,
  });

  @override
  State<LocationAlertBanner> createState() => _LocationAlertBannerState();
}

class _LocationAlertBannerState extends State<LocationAlertBanner>
    with SingleTickerProviderStateMixin {
  static const Distance _distance = Distance();

  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;
  Timer? _repeatTimer;
  String? _lastShownAlertId;
  String? _dismissedAlertId;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Decaying left-right shake: a few full swings that settle back to 0.
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _repeatTimer?.cancel();
    super.dispose();
  }

  /// An alert is "directed at" [userLocation] when the location falls
  /// inside the alert's own geofence — DisasterAlert already carries
  /// centerLat/centerLng/radiusMeters, exactly what's needed for a
  /// point-in-circle test, so no separate zone-boundary lookup is needed.
  DisasterAlert? _matchFor(List<DisasterAlert> alerts) {
    final matches = alerts.where((a) {
      final d = _distance(widget.userLocation, LatLng(a.centerLat, a.centerLng));
      return d <= a.radiusMeters;
    }).toList();

    if (matches.isEmpty) return null;

    // Most severe first, then most recently updated, so if two alerts
    // both cover this location the banner shows the one that matters most.
    matches.sort((a, b) {
      final severityCompare = b.severity.index.compareTo(a.severity.index);
      if (severityCompare != 0) return severityCompare;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return matches.first;
  }

  void _syncShakeWith(DisasterAlert? alert) {
    if (alert == null) {
      _repeatTimer?.cancel();
      _repeatTimer = null;
      _lastShownAlertId = null;
      return;
    }

    final isNewOrChanged = alert.id != _lastShownAlertId;
    _lastShownAlertId = alert.id;
    if (!isNewOrChanged) return;

    _shakeController.forward(from: 0);
    _repeatTimer?.cancel();
    if (alert.severity.isCritical) {
      _repeatTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) _shakeController.forward(from: 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertProvider>().activeAlerts;
    final match = _matchFor(alerts);
    _syncShakeWith(match);

    if (match == null || match.id == _dismissedAlertId) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _shakeOffset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeOffset.value, 0),
          child: child,
        );
      },
      // Reuses your existing AlertBanner/SeverityBadge exactly as they
      // already render elsewhere — this widget only supplies which alert
      // to show and when to shake.
      child: AlertBanner(
        alert: match,
        onDismiss: () => setState(() => _dismissedAlertId = match.id),
        onTap: widget.onTap,
      ),
    );
  }
}