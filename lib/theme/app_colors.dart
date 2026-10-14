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
  static const slateInk = Color(0xFF0B2545); // primary text (~12:1 on mist)
  static const slateMuted = Color(0xFF4A5560); // secondary text ≥ 4.5:1 on mist
  static const hairline = Color(0xFFE6E2DA); // card / input borders
  static const hairlineStrong = Color(0xFFB7B0A4); // glare-aware borders

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

/// Brand colours that work in both themes. The [AppColors] navy tokens are
/// tuned for the cream light theme and nearly vanish on the dark navy
/// background, so text, icons and borders should use these instead.
extension ThemedBrandColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Headings, icons, outlines (was [AppColors.deepEstuary]).
  Color get brandInk => isDarkMode ? const Color(0xFFA9CBEA) : AppColors.deepEstuary;

  /// Secondary accents (was [AppColors.riverTeal]).
  Color get brandAccent => isDarkMode ? const Color(0xFF7FB3D9) : AppColors.riverTeal;

  /// Body text (was [AppColors.slateInk]).
  Color get inkStrong => isDarkMode ? AppColors.foamText : AppColors.slateInk;

  /// Secondary text (was [AppColors.slateMuted]).
  Color get inkMuted => isDarkMode ? const Color(0xFFB9C6D3) : AppColors.slateMuted;

  /// Filled backgrounds that carry white text (buttons, chips).
  Color get brandFill => isDarkMode ? const Color(0xFF2F6690) : AppColors.deepEstuary;

  /// Page-tone panels (was [AppColors.mist]).
  Color get surfaceSoft => isDarkMode ? AppColors.harborSurface : AppColors.mist;

  /// Cards / chips on top of the page (was [AppColors.cloud] / white).
  Color get surfaceCard => isDarkMode ? AppColors.harborSurface : AppColors.cloud;

  /// Light brand tint (was [AppColors.seafoam]).
  Color get tintSoft => isDarkMode ? const Color(0xFF1E3D5C) : AppColors.seafoam;

  /// SOS / danger tint (was [AppColors.sosBackground]).
  Color get dangerTint => isDarkMode ? const Color(0xFF4A2226) : AppColors.sosBackground;

  /// Caution / offline tint (was [AppColors.offlineAmber]).
  Color get cautionTint => isDarkMode ? const Color(0xFF4A3D14) : AppColors.offlineAmber;
}
