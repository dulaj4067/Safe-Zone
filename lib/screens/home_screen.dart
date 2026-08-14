import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../models/focus_mode.dart';
import '../constants/app_colors.dart';
import '../widgets/primary_button.dart';

/// Sprint 1 Home: intentionally minimal. Its only job is to get the
/// user into a focus session in one tap. No dashboards, stats, or
/// history here — those belong to future sprints.
class HomeScreen extends StatelessWidget {
  final VoidCallback? onStartFocus;

  const HomeScreen({super.key, this.onStartFocus});

  @override
  Widget build(BuildContext context) {
    final focusState = context.watch<FocusState>();
    final mode = focusState.selectedMode;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Good to see you',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a deep breath. Ready when you are.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(flex: 3),
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Start Focus',
                      onPressed: () {
                        focusState.startSession();
                        onStartFocus?.call();
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(mode.icon, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Current mode: ${mode.label}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}