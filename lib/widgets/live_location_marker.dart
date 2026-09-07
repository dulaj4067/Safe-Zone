import 'package:flutter/material.dart';

/// Standard "blue dot" marker for the device's own live position —
/// deliberately different from the pin-style markers used for a
/// manually-placed route origin/destination, so it's always clear which
/// one is "you" versus a point you tapped.
class LiveLocationMarker extends StatelessWidget {
  const LiveLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8).withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
        ),
      ],
    );
  }
}