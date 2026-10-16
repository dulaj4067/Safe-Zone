import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Branded loading screen shown while the app resolves initial state —
/// e.g. [AppShell] fetching the signed-in citizen's profile and zones
/// before the first tab can render. Reuses the same navy logo mark shown
/// at launch so this screen reads as one continuous brand moment rather
/// than a generic spinner. The team name sits at the foot of the screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// The logo mark; large so the brand reads at a glance while loading.
  static const double logoSize = 160;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: isDark ? AppColors.deepWater : AppColors.mist,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        key: const Key('splash_logo'),
                        width: logoSize,
                        height: logoSize,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: context.brandInk,
                          borderRadius: BorderRadius.circular(44),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.warning_rounded,
                            color: AppColors.seafoam,
                            size: 80,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'SafeZone',
                        style: textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sri Lanka Disaster Early Warning',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: context.brandInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Built by',
                    style: textTheme.bodySmall?.copyWith(color: context.inkMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The Pioneers',
                    key: const Key('splash_company'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
