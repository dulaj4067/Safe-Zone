import 'package:flutter/material.dart';

import '../utils/map_tile_config.dart';

/// Circular +/- zoom button, styled to match the map card's floating
/// controls. Use one for zoom-in, one for zoom-out.
class ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const ZoomButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: const Color(0xFF2A2A2A)),
        ),
      ),
    );
  }
}

/// "My location" button, like the crosshair in Google Maps — recentres the
/// map on the device's live position.
class MyLocationButton extends StatelessWidget {
  final VoidCallback onTap;
  const MyLocationButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'My location',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.my_location, size: 20, color: Color(0xFF1A73E8)),
          ),
        ),
      ),
    );
  }
}

/// Toggles between the street and topo base map styles. Icon always shows
/// what tapping it will switch *to*.
class MapLayerToggleButton extends StatelessWidget {
  final BaseMapStyle style;
  final VoidCallback onTap;
  const MapLayerToggleButton({super.key, required this.style, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTopo = style == BaseMapStyle.topo;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isTopo ? Icons.map_outlined : Icons.terrain,
            size: 20,
            color: const Color(0xFF2A2A2A),
          ),
        ),
      ),
    );
  }
}