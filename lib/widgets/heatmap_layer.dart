import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/incident.dart';

/// Renders a density heatmap of [incidents] as a [CircleLayer] on the map.
///
/// Algorithm:
///   1. Divide the map region into grid cells of [gridSizeDeg] degrees
///      (~1 km at Sri Lanka's latitude).
///   2. Count incidents per cell.
///   3. Normalize counts to [0, 1] relative to the busiest cell.
///   4. Draw two concentric translucent circles per non-empty cell:
///      - outer: large, very transparent "glow"
///      - inner: smaller, more opaque "core"
///   Color scale: green → yellow → orange → red matching app severity palette.
///
/// No new dependencies — relies entirely on the existing [flutter_map]
/// [CircleLayer] that is already in use on [HomeScreen].
class HeatmapLayer extends StatelessWidget {
  final List<Incident> incidents;

  /// Cell size in decimal degrees. ~0.009° ≈ 1 km at 7°N (Sri Lanka).
  static const double _gridSizeDeg = 0.009;

  const HeatmapLayer({super.key, required this.incidents});

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) return const SizedBox.shrink();

    // ── 1. Bucket incidents into grid cells ────────────────────────────────
    final Map<(int, int), int> grid = {};
    for (final incident in incidents) {
      final cellLat = (incident.latitude / _gridSizeDeg).floor();
      final cellLng = (incident.longitude / _gridSizeDeg).floor();
      grid[(cellLat, cellLng)] = (grid[(cellLat, cellLng)] ?? 0) + 1;
    }

    // ── 2. Normalise counts ────────────────────────────────────────────────
    final maxCount = grid.values.reduce(math.max).toDouble();

    // ── 3. Build circle markers ────────────────────────────────────────────
    final circles = <CircleMarker>[];
    for (final entry in grid.entries) {
      final (cellLat, cellLng) = entry.key;
      final count = entry.value;
      final t = (count / maxCount).clamp(0.0, 1.0);

      // Cell centroid
      final center = LatLng(
        (cellLat + 0.5) * _gridSizeDeg,
        (cellLng + 0.5) * _gridSizeDeg,
      );

      final color = _heatColor(t);

      // Outer glow — large radius, very transparent
      circles.add(
        CircleMarker(
          point: center,
          radius: 900, // metres
          useRadiusInMeter: true,
          color: color.withValues(alpha: 0.18 + t * 0.18),
          borderStrokeWidth: 0,
        ),
      );

      // Inner core — sharper, more opaque
      circles.add(
        CircleMarker(
          point: center,
          radius: 420, // metres
          useRadiusInMeter: true,
          color: color.withValues(alpha: 0.35 + t * 0.30),
          borderStrokeWidth: 0,
        ),
      );
    }

    return CircleLayer(circles: circles);
  }

  /// Maps a normalised value [t] ∈ [0, 1] to a risk colour.
  ///
  /// Uses the same palette as [AppColors] severity levels so the heatmap
  /// feels visually consistent with alert circles and severity badges.
  ///
  ///   0.0 – 0.25  →  green  (#2E7D32)
  ///   0.25 – 0.55 →  yellow (#F9A825)
  ///   0.55 – 0.80 →  orange (#EF6C00)
  ///   0.80 – 1.0  →  red    (#C62828)
  static Color _heatColor(double t) {
    if (t < 0.25) {
      return Color.lerp(
        const Color(0xFF2E7D32),
        const Color(0xFFF9A825),
        t / 0.25,
      )!;
    } else if (t < 0.55) {
      return Color.lerp(
        const Color(0xFFF9A825),
        const Color(0xFFEF6C00),
        (t - 0.25) / 0.30,
      )!;
    } else if (t < 0.80) {
      return Color.lerp(
        const Color(0xFFEF6C00),
        const Color(0xFFC62828),
        (t - 0.55) / 0.25,
      )!;
    } else {
      return const Color(0xFFC62828);
    }
  }
}
