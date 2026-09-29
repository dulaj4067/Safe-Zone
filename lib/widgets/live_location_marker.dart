import 'package:flutter/material.dart';

/// Standard "blue dot" marker for the device's own live position, in the
/// style of Google Maps — a solid blue dot with a white ring, a soft steady
/// halo, and a ring that keeps pulsing outward so it reads as "live".
///
/// Deliberately different from the pin-style markers used for a
/// manually-placed route origin/destination, so it's always clear which
/// one is "you" versus a point you tapped.
///
/// Sized to fit the 28×28 [Marker] boxes the screens already use; the pulse
/// draws outside that box without changing the marker's tap/layout area.
class LiveLocationMarker extends StatefulWidget {
  const LiveLocationMarker({super.key});

  @override
  State<LiveLocationMarker> createState() => _LiveLocationMarkerState();
}

class _LiveLocationMarkerState extends State<LiveLocationMarker>
    with SingleTickerProviderStateMixin {
  static const Color _blue = Color(0xFF1A73E8);
  static const double _maxPulse = 72;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Expanding ping — fades out as it grows.
          OverflowBox(
            maxWidth: _maxPulse,
            maxHeight: _maxPulse,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_pulse.value);
                final size = 20 + (_maxPulse - 20) * t;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _blue.withValues(alpha: 0.28 * (1 - t)),
                  ),
                );
              },
            ),
          ),
          // Steady halo.
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
          ),
          // The dot itself.
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
