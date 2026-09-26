import 'package:flutter/material.dart';

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
        const BottomNavigationBarItem(
          icon: _DestinationContent(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: false,
          ),
          activeIcon: _DestinationContent(
            icon: Icons.home,
            label: 'Home',
            selected: true,
          ),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: _DestinationContent(
            icon: Icons.report_outlined,
            label: 'Incidents',
            selected: false,
          ),
          activeIcon: _DestinationContent(
            icon: Icons.report,
            label: 'Incidents',
            selected: true,
          ),
          label: 'Incidents',
        ),
        const BottomNavigationBarItem(
          icon: _DestinationContent(
            icon: Icons.alt_route_outlined,
            label: 'Shelters',
            selected: false,
          ),
          activeIcon: _DestinationContent(
            icon: Icons.alt_route,
            label: 'Shelters',
            selected: true,
          ),
          label: 'Shelters',
        ),
        const BottomNavigationBarItem(
          icon: _DestinationContent(
            icon: Icons.health_and_safety_outlined,
            label: 'Prep Hub',
            selected: false,
          ),
          activeIcon: _DestinationContent(
            icon: Icons.health_and_safety,
            label: 'Prep Hub',
            selected: true,
          ),
          label: 'Prep Hub',
        ),
        if (isAuthority)
          const BottomNavigationBarItem(
            icon: _DestinationContent(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              selected: false,
            ),
            activeIcon: _DestinationContent(
              icon: Icons.dashboard,
              label: 'Dashboard',
              selected: true,
            ),
            label: 'Dashboard',
          ),
        const BottomNavigationBarItem(
          icon: _DestinationContent(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: false,
          ),
          activeIcon: _DestinationContent(
            icon: Icons.settings,
            label: 'Settings',
            selected: true,
          ),
          label: 'Settings',
        ),
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