import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Flood-risk severity for a mapped zone.
enum RiskLevel { low, moderate, high, severe }

/// A polygon area shown as a colored overlay on the SafeZone home map,
/// e.g. a flood-risk zone along a river basin.
class RiskZone {
  final String id;
  final String name;
  final RiskLevel level;

  /// Polygon boundary points, in order, forming a closed ring.
  final List<LatLng> boundary;

  const RiskZone({
    required this.id,
    required this.name,
    required this.level,
    required this.boundary,
  });

  /// Semi-transparent fill color for the polygon, keyed by severity.
  Color get fillColor {
    switch (level) {
      case RiskLevel.low:
        return const Color(0x66F5D48A); // soft yellow
      case RiskLevel.moderate:
        return const Color(0x66F0A868); // amber
      case RiskLevel.high:
        return const Color(0x66E8804A); // orange
      case RiskLevel.severe:
        return const Color(0x66D9502F); // red-orange
    }
  }

  /// Solid border color for the polygon outline.
  Color get borderColor {
    switch (level) {
      case RiskLevel.low:
        return const Color(0xFFE0B255);
      case RiskLevel.moderate:
        return const Color(0xFFD98A3D);
      case RiskLevel.high:
        return const Color(0xFFD1642E);
      case RiskLevel.severe:
        return const Color(0xFFB8391F);
    }
  }

  String get label {
    switch (level) {
      case RiskLevel.low:
        return 'Low risk';
      case RiskLevel.moderate:
        return 'Moderate risk';
      case RiskLevel.high:
        return 'High risk';
      case RiskLevel.severe:
        return 'Severe risk';
    }
  }
}

/// Sample zones along the Kelani River basin near Colombo, for layout/testing.
/// TODO: replace with zones fetched from your backend (e.g. a RiskZoneProvider
/// mirroring the pattern used by IncidentProvider).
final List<RiskZone> sampleRiskZones = [
  RiskZone(
    id: 'kelani-severe-1',
    name: 'Kelani River — Central Bend',
    level: RiskLevel.severe,
    boundary: const [
      LatLng(6.9615, 79.9010),
      LatLng(6.9640, 79.9060),
      LatLng(6.9605, 79.9110),
      LatLng(6.9560, 79.9075),
      LatLng(6.9575, 79.9020),
    ],
  ),
  RiskZone(
    id: 'kelani-high-1',
    name: 'North Bank — High Risk',
    level: RiskLevel.high,
    boundary: const [
      LatLng(6.9670, 79.8980),
      LatLng(6.9700, 79.9040),
      LatLng(6.9650, 79.9075),
      LatLng(6.9615, 79.9010),
      LatLng(6.9640, 79.8960),
    ],
  ),
  RiskZone(
    id: 'kelani-moderate-1',
    name: 'South Bank — Moderate Risk',
    level: RiskLevel.moderate,
    boundary: const [
      LatLng(6.9560, 79.9075),
      LatLng(6.9605, 79.9110),
      LatLng(6.9560, 79.9160),
      LatLng(6.9505, 79.9120),
      LatLng(6.9520, 79.9060),
    ],
  ),
  RiskZone(
    id: 'outer-low-1',
    name: 'Outer District — Low Risk',
    level: RiskLevel.low,
    boundary: const [
      LatLng(6.9750, 79.8900),
      LatLng(6.9780, 79.9050),
      LatLng(6.9700, 79.9130),
      LatLng(6.9640, 79.8960),
      LatLng(6.9670, 79.8980),
    ],
  ),
];