import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/alert_provider.dart';
import 'providers/incident_provider.dart';
import 'screens/app_shell.dart';
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
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
      ],
      child: MaterialApp(
        title: 'Disaster & Flood Early-Warning Network',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        // Replace with your existing auth-gated router — this assumes the
        // user is already signed in by the time AppShell mounts.
        home: const AppShell(),
      ),
    );
  }
}
