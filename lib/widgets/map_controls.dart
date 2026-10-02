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

/// Red emergency SOS button with a pulsing glow, like a siren light, so it
/// stands out from the plain white map controls. Larger than the others
/// because it's the one a panicking user has to hit first time.
class SosMapButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool busy;
  const SosMapButton({super.key, required this.onTap, this.busy = false});

  @override
  State<SosMapButton> createState() => _SosMapButtonState();
}

class _SosMapButtonState extends State<SosMapButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "remove animations" accessibility setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFD32F2F);
    return Tooltip(
      message: 'Emergency SOS',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: red.withValues(alpha: 0.5 * (1 - _pulse.value)),
                blurRadius: 4,
                spreadRadius: 10 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: Material(
          color: red,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.busy ? null : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.crisis_alert,
                      size: 22,
                      color: Colors.white,
                    ),
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