import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.isAuthority,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final bool isAuthority;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labelStyle = TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 11,
      height: 1.2,
    );

    final strings = appStringsOf(context);

    BottomNavigationBarItem item(IconData off, IconData on, String key) {
      final label = strings.t(key);
      return BottomNavigationBarItem(
        icon: _DestinationContent(icon: off, label: label, selected: false),
        activeIcon: _DestinationContent(icon: on, label: label, selected: true),
        label: label,
      );
    }

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onDestinationSelected,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      iconSize: 24,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      selectedLabelStyle: labelStyle,
      unselectedLabelStyle: labelStyle,
      selectedItemColor: colors.primary,
      unselectedItemColor: colors.onSurfaceVariant,
      backgroundColor: colors.surface,
      items: [
        item(Icons.home_outlined, Icons.home, 'navHome'),
        item(Icons.report_outlined, Icons.report, 'navIncidents'),
        item(Icons.alt_route_outlined, Icons.alt_route, 'navShelters'),
        item(Icons.health_and_safety_outlined, Icons.health_and_safety, 'navPrepHub'),
        if (isAuthority)
          item(Icons.dashboard_outlined, Icons.dashboard, 'navDashboard'),
        item(Icons.settings_outlined, Icons.settings, 'navSettings'),
      ],
    );
  }
}

class _DestinationContent extends StatelessWidget {
  const _DestinationContent({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              // The bar is a fixed 52dp tall; capping tab labels at 1.6x keeps
              // them inside it at the largest text size the app allows.
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
              style: TextStyle(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}