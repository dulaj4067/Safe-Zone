import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/focus_mode.dart';
import '../providers/session_provider.dart';  
import '../constants/app_colors.dart';       
import '../widgets/mode_card.dart';

/// Sprint 1 Settings: mode selection only. No notifications, sounds,
/// themes, stats, accounts, or integrations — all future sprints.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusState = context.watch<FocusState>();
    final isLocked = focusState.isActive;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the focus mode that fits today.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Text(
              'FOCUS MODE',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondary, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            ...FocusMode.values.map(
              (mode) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ModeCard(
                  mode: mode,
                  selected: focusState.selectedMode == mode,
                  onTap: isLocked ? null : () => focusState.selectMode(mode),
                ),
              ),
            ),
            if (isLocked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Finish or reset your current session to change modes.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}