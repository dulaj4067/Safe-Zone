import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/zone.dart';
import '../providers/alert_provider.dart';
import '../services/activity_history_service.dart';
import '../services/supabase_service.dart';
import '../widgets/alert_banner.dart';
import 'admin_broadcast_screen.dart';
import 'broadcast_dashboard_screen.dart';
import 'incidents_screen.dart';
import 'settings_screen.dart';
import 'shelters_screen.dart';
import 'home_screen.dart';

/// Top-level shell: fetches the signed-in user's profile (for role gating),
/// initializes the realtime alert subscription (Story 2), and overlays the
/// in-app banner above whatever the current tab is.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppUser? _currentUser;

  void _resumeActivity(ActivityEntry entry) {
    final labels = ['Home', 'Incidents', 'Shelters', if (_currentUser?.role.isAuthority ?? false) 'Dashboard', 'Settings'];
    final index = labels.indexOf(entry.section);
    if (index >= 0) setState(() => _tabIndex = index);
  }
  List<Zone> _zones = [];
  int _tabIndex = 0;
  bool _loadingProfile = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late final InterruptionDetector _interruptionDetector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _interruptionDetector = InterruptionDetector(
      onInterruption: () => context.read<ActivityHistoryService>().markInterrupted(),
    );
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) => _interruptionDetector.onConnectivityChanged(
        results.every((result) => result == ConnectivityResult.none) == false,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AlertProvider>().init();
      await _loadProfileAndZones();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _interruptionDetector.onLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileAndZones() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      setState(() => _loadingProfile = false);
      return;
    }

    try {
      final profileRow = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      final zoneRows = await SupabaseService.client.from('zones').select();

      setState(() {
        _currentUser = AppUser.fromMap(profileRow);
        _zones = (zoneRows as List).map((z) => Zone.fromMap(z)).toList();
        _loadingProfile = false;
      });
      if (mounted && _currentUser?.zoneId != null) {
        context.read<AlertProvider>().setUserZoneId(_currentUser!.zoneId);
      }
    } catch (_) {
      setState(() => _loadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();
    final isAuthority = _currentUser?.role.isAuthority ?? false;

    final tabs = <Widget>[
      HomeScreen(
        zones: _zones,
        currentUser: _currentUser,
        onResumeActivity: _resumeActivity,
      ),
      IncidentsScreen(currentUser: _currentUser),
      const RouteScreen(),
      if (isAuthority) BroadcastDashboardScreen(zones: _zones),
      SettingsScreen(
        currentUser: _currentUser,
        zones: _zones,
        onProfileUpdated: _loadProfileAndZones,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(index: _tabIndex, children: tabs),
          if (alertProvider.bannerAlert != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AlertBanner(
                alert: alertProvider.bannerAlert!,
                onDismiss: () => context.read<AlertProvider>().dismissBanner(),
              ),
            ),
        ],
      ),
      floatingActionButton: isAuthority
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.campaign),
              label: const Text('New Alert'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminBroadcastScreen(
                      currentUser: _currentUser!,
                      zones: _zones,
                    ),
                  ),
                );
              },
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex >= tabs.length ? 0 : _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'Incidents'),
          const NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route), label: 'Shelters'),
          if (isAuthority)
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
