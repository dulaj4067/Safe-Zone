import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type pairing: IBM Plex Sans for UI text (built for interface legibility,
/// reads as civic/institutional without feeling cold) + IBM Plex Mono for
/// data readouts — timestamps, coordinates, confirmation counts, radius
/// values. Rendering those as monospace is the app's one deliberate
/// typographic signature: it makes reported data read like an instrument
/// panel, which builds trust in exactly the numbers people are relying on
/// during a flood (how many confirmations, how long ago, how far away).
class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color textColor, Color mutedColor) {
    final base = GoogleFonts.ibmPlexSansTextTheme();
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          bodyLarge: base.bodyLarge?.copyWith(color: textColor),
          bodyMedium: base.bodyMedium?.copyWith(color: textColor),
          bodySmall: base.bodySmall?.copyWith(color: mutedColor),
        )
        .apply(bodyColor: textColor, displayColor: textColor);
  }

  /// Use for timestamps, lat/lng, radius, credibility counts — anywhere a
  /// number is a reported fact rather than UI chrome. Not part of the
  /// ThemeData's default TextTheme on purpose; call directly, e.g.
  /// `Text('4 confirmations', style: AppTheme.dataText(context))`.
  static TextStyle dataText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.ibmPlexMono(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? AppColors.foamText : AppColors.slateInk,
      letterSpacing: 0.2,
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepEstuary,
      brightness: Brightness.light,
      primary: AppColors.deepEstuary,
      secondary: AppColors.riverTeal,
      primaryContainer: AppColors.seafoam,
      surface: AppColors.cloud,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.mist,
      textTheme: _textTheme(AppColors.slateInk, AppColors.slateMuted),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.mist,
        foregroundColor: AppColors.slateInk,
        elevation: 0,
        titleTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.slateInk,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cloud,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.deepEstuary.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepEstuary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cloud,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.deepEstuary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.deepEstuary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cloud,
        indicatorColor: AppColors.seafoam,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.deepEstuary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.riverTeal,
      brightness: Brightness.dark,
      primary: AppColors.riverTeal,
      secondary: AppColors.seafoam,
      surface: AppColors.harborSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.deepWater,
      textTheme: _textTheme(AppColors.foamText, AppColors.foamText.withValues(alpha: 0.65)),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.deepWater,
        foregroundColor: AppColors.foamText,
        elevation: 0,
        titleTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.foamText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.harborSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.riverTeal.withValues(alpha: 0.25)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.riverTeal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.harborSurface,
        indicatorColor: AppColors.deepEstuary,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.riverTeal,
        foregroundColor: Colors.white,
      ),
    );
  }
}
