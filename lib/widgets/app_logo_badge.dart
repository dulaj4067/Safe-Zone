import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small rounded-square app logo badge, sized to sit next to the
/// notification bell in a header row.
///
/// Renders your logo image (see `assetPath`, default matches the pubspec
/// setup below). Falls back to a placeholder icon if the asset fails to
/// load — e.g. before you've added the file — so the app never crashes
/// on a missing asset, it just shows the fallback until you do.
class AppLogoBadge extends StatelessWidget {
  final double size;
  final String assetPath;

  const AppLogoBadge({
    super.key,
    this.size = 40,
    this.assetPath = 'assets/logo.png',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.deepEstuary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Shown if assetPath isn't registered in pubspec.yaml yet, or
          // the file isn't there — see the setup steps for this widget.
          return Icon(Icons.warning_rounded, color: AppColors.seafoam, size: size * 0.55);
        },
      ),
    );
  }
}