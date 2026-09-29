import 'package:flutter/material.dart';

/// SafeZone palette — a deep navy civic identity on a warm cream canvas,
/// kept deliberately out of the red/orange/yellow/green range so it never
/// competes with [AlertSeverity] colors, which must stay the only thing in
/// the app that means "urgency."
///
/// The original token names (deepEstuary, riverTeal, …) are kept so every
/// screen that already references them picks up the new look automatically.
class AppColors {
  AppColors._();

  // Brand / primary — deep navy. Buttons, headings, selected nav item.
  static const deepEstuary = Color(0xFF0B2545); // primary
  static const riverTeal = Color(0xFF1B4B6B); // primary, lighter step
  static const seafoam = Color(0xFFDDE6EE); // primary container / tints

  // Neutrals — warm cream canvas with white cards.
  static const mist = Color(0xFFF4F2ED); // app background
  static const cloud = Color(0xFFFFFFFF); // surface / cards
  static const slateInk = Color(0xFF0B2545); // primary text
  static const slateMuted = Color(0xFF6B7178); // secondary text
  static const hairline = Color(0xFFE6E2DA); // card / input borders

  // Dark mode
  static const deepWater = Color(0xFF07182C); // dark background
  static const harborSurface = Color(0xFF0F2A47); // dark surface/cards
  static const foamText = Color(0xFFE8EDF2); // dark-mode primary text

  // Severity — the ONLY place these colors are allowed to mean something.
  // Kept exactly in sync with widgets/severity_badge.dart.
  static const severityGreen = Color(0xFF2E8B6A); // Advisory / Safe
  static const severityYellow = Color(0xFFE9B800); // Watch
  static const severityOrange = Color(0xFFE5704F); // Warning
  static const severityRed = Color(0xFFC1272D); // Critical

  // Utility
  static const offlineAmber = Color(0xFFFFF3CD); // cache/offline banner bg
  static const offlineSlate = Color(0xFF5E6B78); // offline strip
  static const sosBackground = Color(0xFFFDECEA); // SOS row/card tint
}
