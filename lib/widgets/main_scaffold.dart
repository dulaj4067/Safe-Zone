import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/placeholder_screens.dart';
// TODO: adjust this import path to wherever IncidentsScreen actually lives
// in your project (it's the screen from your existing incidents_screen.dart).
import '../screens/alerts_screen.dart';

/// App root: bottom nav with Home, Alerts, SOS, Shelters, Hub.
/// Use this as (or inside) your MaterialApp's `home`.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  // IndexedStack keeps each tab's state (e.g. map camera position,
  // scroll position) alive when switching tabs.
  final _tabs = const [
    HomeScreen(),
    AlertsScreen(),
    SosScreen(),
    SheltersScreen(),
    IncidentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), selectedIcon: Icon(Icons.warning_amber_rounded), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.night_shelter_outlined), selectedIcon: Icon(Icons.night_shelter), label: 'Shelters'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Hub'),
        ],
      ),
    );
  }
}