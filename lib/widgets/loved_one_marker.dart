import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Map marker for a safety-circle contact's last-known location — an
/// initials avatar in a pin, deliberately distinct from [LiveLocationMarker]
/// (that's always "you") and from [ShelterMarker]/incident markers (places
/// and events, not people). A small pulse ring on top means "actively
/// sharing their ETA right now"; without it, this is just where they were
/// last seen.
class LovedOneMarker extends StatelessWidget {
  final String initials;
  final bool isActive;

  const LovedOneMarker({
    super.key,
    required this.initials,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.riverTeal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (isActive)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppColors.severityGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
