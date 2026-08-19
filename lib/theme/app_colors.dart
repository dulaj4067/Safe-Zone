import 'package:flutter/material.dart';

/// "Estuary" palette — a deep teal-blue civic identity for the disaster
/// network, kept deliberately out of the red/orange/yellow/green range so
/// it never competes with [AlertSeverity] colors, which must stay the only
/// thing in the app that means "urgency."
class AppColors {
  AppColors._();

  // Brand / primary — deep estuary teal. Calm-authority register: think
  // water agency or coastal weather service, not generic Material blue.
  static const deepEstuary = Color(0xFF0E4F56); // primary
  static const riverTeal = Color(0xFF1C7C89); // primary, lighter step
  static const seafoam = Color(0xFFBFE3E0); // primary container / tints

  // Neutrals — cool, not warm. Avoids the cream/terracotta AI-default.
  static const mist = Color(0xFFF4F7F7); // app background
  static const cloud = Color(0xFFFFFFFF); // surface / cards
  static const slateInk = Color(0xFF16262A); // primary text
  static const slateMuted = Color(0xFF5B6D70); // secondary text

  // Dark mode
  static const deepWater = Color(0xFF0A1F22); // dark background
  static const harborSurface = Color(0xFF122F33); // dark surface/cards
  static const foamText = Color(0xFFE3EEEE); // dark-mode primary text

  // Severity — the ONLY place these colors are allowed to mean something.
  // Kept exactly in sync with widgets/severity_badge.dart.
  static const severityGreen = Color(0xFF2E7D32);
  static const severityYellow = Color(0xFFF9A825);
  static const severityOrange = Color(0xFFEF6C00);
  static const severityRed = Color(0xFFC62828);

  // Utility
  static const offlineAmber = Color(0xFFFFF3CD); // cache/offline banner bg
  static const sosBackground = Color(0xFFFDECEA); // SOS row/card tint
}
