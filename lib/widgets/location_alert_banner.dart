import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../providers/alert_provider.dart';
import 'alert_banner.dart';

/// A reusable, location-aware wrapper around your existing AlertBanner.
/// Drop this into any screen's widget tree — it reads AlertProvider via
/// Provider internally, picks the single most *relevant* active alert
/// for [userLocation] (combining severity and proximity — see
/// _relevanceScore below), and renders it using AlertBanner/SeverityBadge
/// exactly as they already look elsewhere — this widget doesn't draw its
/// own banner UI, it only adds:
///   - relevance ranking (a closer, more severe alert always outranks a
///     farther or milder one — not just "is the user literally inside
///     the geofence")
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

  /// Beyond this multiple of an alert's own radius, it's considered too
  /// far to be relevant at all — without this, a very severe but
  /// distant alert (e.g. across the whole district) would keep scoring
  /// above zero forever and never let the banner clear.
  static const double _relevanceRangeMultiplier = 6.0;

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

  static double _severityWeight(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.red:
        return 100;
      case AlertSeverity.orange:
        return 50;
      case AlertSeverity.yellow:
        return 20;
      case AlertSeverity.green:
        return 5;
    }
  }

  /// Combines severity and proximity so a closer, more severe alert
  /// always outranks a farther or milder one — e.g. a nearby orange
  /// alert can outrank a distant red one, and a red alert right on top
  /// of the user always wins over everything else.
  ///
  /// Proximity is 1.0 anywhere inside the alert's own radius (being
  /// "more inside" doesn't make it more relevant — inside is inside),
  /// then decays smoothly toward 0 the farther beyond that radius the
  /// user is, rather than dropping to 0 the instant they step outside
  /// the geofence line.
  static double? _relevanceScore(DisasterAlert alert, double distanceMeters) {
    if (distanceMeters > alert.radiusMeters * _relevanceRangeMultiplier) {
      return null; // too far away to matter at all
    }
    final proximity = distanceMeters <= alert.radiusMeters
        ? 1.0
        : alert.radiusMeters / distanceMeters;
    return _severityWeight(alert.severity) * proximity;
  }

  /// Picks the single most relevant alert for [userLocation] out of all
  /// currently active ones.
  DisasterAlert? _matchFor(List<DisasterAlert> alerts) {
    DisasterAlert? best;
    double bestScore = 0;

    for (final alert in alerts) {
      final d = _distance(widget.userLocation, LatLng(alert.centerLat, alert.centerLng));
      final score = _relevanceScore(alert, d);
      if (score != null && score > bestScore) {
        bestScore = score;
        best = alert;
      }
    }

    return best;
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
      // to show and when to shake. AlertBanner already renders the
      // severity label in a white pill on a solid severity-colored
      // background (severityColor()), so severity + its color are shown
      // automatically whenever this picks a match.
      child: AlertBanner(
        alert: match,
        onDismiss: () => setState(() => _dismissedAlertId = match.id),
        onTap: widget.onTap,
      ),
    );
  }
}