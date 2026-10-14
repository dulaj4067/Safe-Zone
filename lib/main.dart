import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'l10n/locale_format.dart';
import 'providers/accessibility_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/incident_provider.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'providers/safety_provider.dart';
import 'providers/map_focus_provider.dart';
import 'providers/active_route_provider.dart';
import 'services/activity_history_service.dart';
import 'modules/preparedness_hub/providers/preparedness_provider.dart';
import 'modules/preparedness_hub/services/preparedness_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocaleFormat.ensureInitialized();
  // Warm script fonts so Sinhala/Tamil/Arabic glyphs stay legible at small sizes.
  GoogleFonts.notoSansSinhala();
  GoogleFonts.notoSansTamil();
  GoogleFonts.notoNaskhArabic();

  await SupabaseService.init(
    url: 'https://frkwsgriwdezkvrmgsgf.supabase.co',
    publishableKey: 'sb_publishable_1Ax1SZF9hldmiJ1kyi338w_BvOL4Gxd',
  );

  runApp(const DisasterApp());
}

class DisasterApp extends StatelessWidget {
  const DisasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthProvider must come first — other providers may depend on the
        // signed-in user's id.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => SafetyProvider()),
        ChangeNotifierProvider(create: (_) => MapFocusProvider()),
        ChangeNotifierProvider(create: (_) => ActiveRouteProvider()),
        ChangeNotifierProvider(
          create: (_) => PreparednessProvider(
            repository: LocalPreparednessRepository(syncWithSupabase: true),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ActivityHistoryService()..load()),
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final a11y = context.watch<AccessibilityProvider>();
    final light = a11y.glareBoost
        ? AppTheme.light.copyWith(
            scaffoldBackgroundColor: Colors.white,
            dividerColor: AppColors.hairlineStrong,
          )
        : AppTheme.light;

    return MaterialApp(
      title: 'Disaster & Flood Early-Warning Network',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: a11y.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('si'),
        Locale('ta'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            // Follow the system font size; cap runaway scale so admin layouts
            // stay usable while still allowing ~130%+ enlargement.
            textScaler: media.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 2.0,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AuthGate(),
    );
  }
}

/// Switches between [LoginScreen] and [AppShell] based on whether a Supabase
/// session exists. Reacts to sign-in / sign-out events automatically because
/// [AuthProvider] calls [notifyListeners] on every auth state change.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthProvider, bool>(
      (auth) => auth.isSignedIn,
    );

    return isSignedIn ? const AppShell() : const LoginScreen();
  }
}
