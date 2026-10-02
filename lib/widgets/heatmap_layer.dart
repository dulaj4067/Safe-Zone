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
/// spot": a lone report stays green, and red only appears where several
/// reports genuinely overlap. (Normalising to the busiest spot made every
/// isolated report render as maximum red whenever no two were close.)
class HeatmapLayer extends StatelessWidget {
  final List<Incident> incidents;

  /// How far a report's influence reaches (Gaussian sigma).
  static const double bandwidthMetres = 1500;

  /// Weighted density at which the colour tops out at red — roughly four
  /// ordinary reports right on top of each other.
  static const double saturationDensity = 4.0;

  const HeatmapLayer({super.key, required this.incidents});

  /// SOS and trapped-person reports count more; unverified ones a bit
  /// less, so a pile of unconfirmed reports doesn't outweigh verified ones.
  static double weightOf(Incident i) {
    var w = 1.0;
    if (i.isSos || i.category == IncidentCategory.trappedPerson) w *= 1.5;
    if (i.status == IncidentStatus.pending) w *= 0.75;
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

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) return const SizedBox.shrink();
    final density = densities(incidents);

    // Draw the hottest last so they sit on top of cooler overlaps.
    final order = List.generate(incidents.length, (i) => i)
      ..sort((a, b) => density[a].compareTo(density[b]));

    final circles = <CircleMarker>[];
    for (final i in order) {
      final t = intensity(density[i]);
      final point = LatLng(incidents[i].latitude, incidents[i].longitude);
      final color = _heatColor(t);
      // Hotspots also grow, so a cluster reads as a bigger area of concern.
      circles
        ..add(
          CircleMarker(
            point: point,
            radius: 1200 + 1800 * t,
            useRadiusInMeter: true,
            color: color.withValues(alpha: 0.14 + t * 0.16),
            borderStrokeWidth: 0,
          ),
        )
        ..add(
          CircleMarker(
            point: point,
            radius: 450 + 550 * t,
            useRadiusInMeter: true,
            color: color.withValues(alpha: 0.30 + t * 0.30),
            borderStrokeWidth: 0,
          ),
        );
    }
    return CircleLayer(circles: circles);
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
