import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/zone.dart';
import '../providers/accessibility_provider.dart';
import '../providers/alert_provider.dart';
import '../providers/map_focus_provider.dart';
import '../providers/safety_provider.dart';
import '../services/activity_history_service.dart';
import '../services/onboarding_service.dart';
import '../services/supabase_service.dart';
import '../widgets/alert_banner.dart';
import '../widgets/critical_alert_takeover.dart';
import '../widgets/safety_circle_request_banner.dart';
import '../widgets/splash_screen.dart';
import 'admin_broadcast_screen.dart';
import 'broadcast_dashboard_screen.dart';
import 'family_circle_screen.dart';
import 'incidents_screen.dart';
import 'settings_screen.dart';
import 'shelters_screen.dart';
import 'home_screen.dart';
import '../modules/preparedness_hub/screens/preparedness_hub_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../l10n/ui_text.dart';

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
    final labels = ['Home', 'Incidents', 'Shelters', 'Prep Hub', if (_currentUser?.role.isAuthority ?? false) 'Dashboard', 'Settings'];
    final index = labels.indexOf(entry.section == 'Preparedness' ? 'Prep Hub' : entry.section);
    if (index >= 0) setState(() => _tabIndex = index);
  }
  List<Zone> _zones = [];
  int _tabIndex = 0;

  /// Incremented whenever the Home tab is selected so it refreshes shelters.
  int _homeVisits = 0;
  bool _loadingProfile = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late final InterruptionDetector _interruptionDetector;
  MapFocusProvider? _mapFocus;
  StreamSubscription<Uri>? _inviteLinkSubscription;

  /// app_links can deliver the launch link more than once (as the initial
  /// link and on the stream); each invite should only be accepted once.
  final Set<String> _handledInviteCodes = {};

  /// Family invite links (safezone://family-invite?code=...) — accepted
  /// here, once the user is signed in, then confirmed in a dialog.
  void _listenForInviteLinks() {
    _inviteLinkSubscription = AppLinks().uriLinkStream.listen((uri) {
      if (uri.scheme != 'safezone' || uri.host != 'family-invite') return;
      final code = uri.queryParameters['code'];
      if (code == null || !_handledInviteCodes.add(code) || !mounted) return;
      acceptFamilyInvite(context, code);
    }, onError: (_) {});
  }

  /// "Show on map" from anywhere → jump to the Home tab (index 0).
  void _onMapFocus() {
    if (mounted && _tabIndex != 0) setState(() => _tabIndex = 0);
  }

  @override
  void initState() {
    super.initState();
    _mapFocus = Provider.of<MapFocusProvider?>(context, listen: false)
      ?..addListener(_onMapFocus);
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
      final uid = SupabaseService.currentUserId;
      final declined = uid != null &&
          await OnboardingService().notificationsDeclined(uid);
      if (!mounted) return;
      // Green and yellow alert haptics follow the person's haptics setting.
      AccessibilityProvider? a11y;
      try {
        a11y = context.read<AccessibilityProvider>();
      } catch (_) {}
      context.read<AlertProvider>().hapticsEnabledResolver =
          () => a11y?.hapticsEnabled ?? true;
      await context.read<AlertProvider>().init(
        requestNotificationPermission: !declined,
      );
      await _loadProfileAndZones();
      // Loads circle-member "last known location" markers ahead of time so
      // they're ready as soon as the citizen looks at the home map, not
      // only after they happen to open the "I'm Safe" screen first.
      unawaited(context.read<SafetyProvider>().loadFamilyCircle());
      unawaited(context.read<SafetyProvider>().loadPendingRequests());
      if (mounted) _listenForInviteLinks();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _interruptionDetector.onLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapFocus?.removeListener(_onMapFocus);
    _connectivitySubscription?.cancel();
    _inviteLinkSubscription?.cancel();
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
        visitCount: _homeVisits,
      ),
      IncidentsScreen(currentUser: _currentUser),
      SheltersScreen(currentUser: _currentUser),
      PreparednessHubScreen(currentUser: _currentUser, zones: _zones),
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
              ? const SplashScreen()
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
          if (!_loadingProfile)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafetyCircleRequestBanner(),
            ),
          // Last, so it covers everything, including the nav bar's area.
          if (alertProvider.criticalTakeover != null)
            Positioned.fill(
              child: CriticalAlertTakeover(
                key: ValueKey(alertProvider.criticalTakeover!.id),
                alert: alertProvider.criticalTakeover!,
                sirenEnabled: alertProvider.sirenOverride,
                onDismiss: () => context.read<AlertProvider>().dismissTakeover(),
                onFindShelter: () {
                  context.read<AlertProvider>().dismissTakeover();
                  setState(() => _tabIndex = 2); // Shelters
                },
              ),
            ),
        ],
      ),
      // Home tab only — on the other tabs it covers list content.
      floatingActionButton: isAuthority && _tabIndex == 0 && !_loadingProfile
          ? FloatingActionButton.extended(
              heroTag: 'new-alert-fab',
              icon: const Icon(Icons.campaign),
              label: Text(context.tr('New Alert')),
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
      // Left side, so it doesn't cover the map's zoom controls.
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      // Hidden until the profile has loaded: the splash shouldn't look like
      // a usable app, and the tab set depends on the user's role.
      // Also hidden while the critical alert owns the screen.
      bottomNavigationBar: (_loadingProfile || alertProvider.criticalTakeover != null) ? null : BottomNavBar(
        currentIndex: _tabIndex >= tabs.length ? 0 : _tabIndex,
        isAuthority: isAuthority,
        onDestinationSelected: (i) {
          setState(() {
            _tabIndex = i;
            if (i == 0) _homeVisits++;
          });
        },
      ),
    );
  }
}
