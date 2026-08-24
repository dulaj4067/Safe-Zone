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

/// Shared shelter detail bottom sheet — shows name, address, and capacity
/// if known. Used wherever a shelter marker is tapped without a routing
/// action attached (e.g. the homepage map).
void showShelterDetailSheet(BuildContext context, Shelter shelter) {
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.night_shelter, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shelter.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (shelter.address != null) ...[
            const SizedBox(height: 8),
            Text(shelter.address!),
          ],
          if (shelter.capacity != null) ...[
            const SizedBox(height: 8),
            Text('Capacity: ${shelter.capacity}'),
          ],
        ],
      ),
    ),
  );
}