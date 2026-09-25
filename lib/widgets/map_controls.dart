import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';

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

/// Toggles the incident density heatmap overlay on the map.
///
/// When [active] is true the button is tinted with [AppColors.riverTeal]
/// so the user always knows at a glance whether the layer is on or off.
class HeatmapToggleButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const HeatmapToggleButton({
    super.key,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? 'Hide heatmap' : 'Show incident heatmap',
      child: Material(
        color: active ? AppColors.riverTeal : Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.blur_on_rounded,
              size: 20,
              color: active ? Colors.white : const Color(0xFF2A2A2A),
            ),
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