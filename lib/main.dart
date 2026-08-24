import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/alert_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/incident_provider.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      ],
      child: MaterialApp(
        title: 'Disaster & Flood Early-Warning Network',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const _AuthGate(),
      ),
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
