import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Branded loading screen shown while the app resolves initial state —
/// e.g. [AppShell] fetching the signed-in citizen's profile and zones
/// before the first tab can render. Reuses the same navy logo mark shown
/// at launch so this screen reads as one continuous brand moment rather
/// than a generic spinner.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.deepWater : AppColors.mist,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.deepEstuary,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.warning_rounded, color: AppColors.seafoam, size: 48),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SafeZone',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sri Lanka Disaster Early Warning',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.deepEstuary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
