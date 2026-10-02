import 'package:flutter/material.dart';

import '../models/shelter.dart';

/// Shared shelter pin, used on both the homepage map and the routing map
/// so shelters look identical everywhere they appear.
class ShelterMarker extends StatelessWidget {
  final Shelter shelter;
  final bool isSelected;
  final VoidCallback onTap;

  const ShelterMarker({
    super.key,
    required this.shelter,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32);
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: shelter.name,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: const Icon(Icons.night_shelter, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
