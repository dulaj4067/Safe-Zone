import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/incident.dart';

/// Incident density heatmap for the home map, built from the incident
/// reports in the database (whatever the map's filters currently show).
///
/// Each report spreads a Gaussian "influence" around itself, so reports
/// near each other add up into a hotspot — independent of any grid lines.
/// Colour comes from a fixed scale rather than "relative to the busiest
/// spot": a lone report stays green, a handful close together reads
/// yellow to orange, and red only appears where a dozen or so reports
/// genuinely pile up. (Normalising to the busiest spot made every
/// isolated report render as maximum red whenever no two were close.)
class HeatmapLayer extends StatelessWidget {
  final List<Incident> incidents;

  /// How far a report's influence reaches (Gaussian sigma).
  static const double bandwidthMetres = 1500;

  /// Weighted density at which the colour tops out at red — roughly ten
  /// ordinary reports right on top of each other. (It was 4, which made a
  /// lone report read yellow and any group of four already full red, so
  /// small and large clusters looked the same.)
  static const double saturationDensity = 10.0;

  const HeatmapLayer({super.key, required this.incidents});

  /// How much one report heats the map. Only confirmed reports count in
  /// full:
  ///
  /// - **verified** (an authority confirmed it): 1.0, plus 0.1 for each
  ///   community confirmation (up to +0.5);
  /// - **pending**: a faint 0.2 on its own, rising 0.2 with each community
  ///   confirmation, so four neighbours confirming it makes it count as
  ///   much as an authority-verified one;
  /// - **rejected** or **resolved**: 0, since they are no longer a live
  ///   problem.
  ///
  /// SOS and trapped-person reports count 1.5 times as much.
  static double weightOf(Incident i) {
    final confirmations = i.credibilityScore < 0 ? 0 : i.credibilityScore;
    var w = switch (i.status) {
      IncidentStatus.verified => 1.0 + 0.1 * math.min(confirmations, 5),
      IncidentStatus.pending => math.min(0.2 + 0.2 * confirmations, 1.0),
      IncidentStatus.rejected || IncidentStatus.resolved => 0.0,
    };
    if (i.isSos || i.category == IncidentCategory.trappedPerson) w *= 1.5;
    return w;
  }

  /// Weighted kernel density at each incident's own location, in the same
  /// order as [incidents].
  static List<double> densities(List<Incident> incidents) {
    const twoSigmaSq = 2 * bandwidthMetres * bandwidthMetres;
    // Beyond 3 sigma the contribution is < 1.2% — skip it.
    const cutoffMetres = 3 * bandwidthMetres;
    const metresPerDegLat = 111320.0;

    return [
      for (final a in incidents)
        incidents.fold<double>(0, (sum, b) {
          // Equirectangular distance: accurate to well under 1% at these
          // ranges, and far cheaper than haversine for every pair.
          final dy = (b.latitude - a.latitude) * metresPerDegLat;
          if (dy.abs() > cutoffMetres) return sum;
          final dx =
              (b.longitude - a.longitude) *
              metresPerDegLat *
              math.cos(a.latitude * math.pi / 180);
          if (dx.abs() > cutoffMetres) return sum;
          final distSq = dx * dx + dy * dy;
          return sum + weightOf(b) * math.exp(-distSq / twoSigmaSq);
        }),
    ];
  }

  /// 0–1 colour position for a density value.
  static double intensity(double density) =>
      (density / saturationDensity).clamp(0.0, 1.0);

  // ─── Drawing ───────────────────────────────────────────────────────────────
  //
  // The heat is painted on screen, one soft cell at a time, instead of as map
  // circles. Circles were sized in metres, so zoomed in a single report's 1.5 km
  // circle filled the whole screen and overlapping circles piled up into solid
  // red. Painting cells keeps the glow a fixed number of pixels wide at any
  // zoom, and each spot is painted once, so overlaps cannot stack.

  /// How far a report's glow reaches on screen: its real 1.5 km reach, but
  /// never fainter than [minSigmaPx] when zoomed far out nor wider than
  /// [maxSigmaPx] when zoomed in.
  static const double minSigmaPx = 18;
  static const double maxSigmaPx = 40;

  /// Size of one painted cell, in pixels.
  static const double cellPx = 12;

  /// Cells cooler than this are not painted, so the glow ends cleanly.
  static const double minIntensity = 0.07;

  /// Screen width of a report's glow at the given zoom and latitude.
  static double sigmaPx(double zoom, double latitude) {
    final metresPerPixel =
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
    return (bandwidthMetres / metresPerPixel).clamp(minSigmaPx, maxSigmaPx);
  }

  /// The painted cells for reports at screen positions [points] (with their
  /// weights) inside a viewport of [size]: the centre of each cell and its
  /// 0-1 colour position. Cells below [minIntensity] are left out.
  static List<HeatCell> cells({
    required List<HeatPoint> points,
    required Size size,
    required double sigma,
  }) {
    if (points.isEmpty || size.isEmpty) return const [];
    final twoSigmaSq = 2 * sigma * sigma;
    final reach = 3 * sigma;
    final out = <HeatCell>[];
    for (var y = cellPx / 2; y < size.height; y += cellPx) {
      for (var x = cellPx / 2; x < size.width; x += cellPx) {
        var density = 0.0;
        for (final p in points) {
          final dx = p.position.dx - x;
          if (dx.abs() > reach) continue;
          final dy = p.position.dy - y;
          if (dy.abs() > reach) continue;
          density += p.weight * math.exp(-(dx * dx + dy * dy) / twoSigmaSq);
        }
        final t = intensity(density);
        if (t >= minIntensity) out.add(HeatCell(Offset(x, y), t));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // Rejected and resolved reports add no heat, so they are not drawn.
    final active = incidents.where((i) => weightOf(i) > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    // Reading the camera here rebuilds this layer as the map moves or zooms.
    final camera = MapCamera.of(context);
    final points = <HeatPoint>[
      for (final i in active)
        HeatPoint(
          camera.latLngToScreenPoint(LatLng(i.latitude, i.longitude)).toOffset(),
          weightOf(i),
        ),
    ];
    final sigma = sigmaPx(camera.zoom, camera.center.latitude);
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _HeatPainter(points: points, sigma: sigma),
        ),
      ),
    );
  }

  /// Green → yellow → orange → red, matching the app's severity palette.
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
    }
    return const Color(0xFFC62828);
  }
}

/// A report on screen: where it is drawn and how much heat it adds.
class HeatPoint {
  final Offset position;
  final double weight;
  const HeatPoint(this.position, this.weight);
}

/// One painted cell of the heat glow.
class HeatCell {
  final Offset center;

  /// 0-1 position on the green → red scale.
  final double intensity;
  const HeatCell(this.center, this.intensity);
}

class _HeatPainter extends CustomPainter {
  final List<HeatPoint> points;
  final double sigma;

  _HeatPainter({required this.points, required this.sigma});

  @override
  void paint(Canvas canvas, Size size) {
    final cells = HeatmapLayer.cells(points: points, size: size, sigma: sigma);
    // A blur turns the square cells into one soft glow.
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, HeatmapLayer.cellPx * 0.7);
    const half = HeatmapLayer.cellPx / 2;
    for (final c in cells) {
      paint.color = HeatmapLayer._heatColor(c.intensity)
          .withValues(alpha: 0.22 + 0.33 * c.intensity);
      canvas.drawRect(
        Rect.fromLTWH(c.center.dx - half, c.center.dy - half, HeatmapLayer.cellPx, HeatmapLayer.cellPx),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) {
    if (old.sigma != sigma || old.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (old.points[i].position != points[i].position ||
          old.points[i].weight != points[i].weight) {
        return true;
      }
    }
    return false;
  }
}
