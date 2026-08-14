import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/focus_mode.dart';
import '../providers/session_provider.dart';
import '../constants/app_colors.dart';
import '../widgets/mode_card.dart';

/// Sprint 1 Settings: mode selection, plus completion sound/vibration
/// toggles. No themes, stats, accounts, or integrations — future sprints.
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
            const SizedBox(height: 28),
            Text(
              'SESSION COMPLETION',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondary, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              'Off by default, so a finished session never feels like an alarm.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _SettingsSwitchTile(
              title: 'Sound',
              subtitle: 'A soft chime when a session ends',
              value: focusState.soundEnabled,
              onChanged: focusState.setSoundEnabled,
            ),
            const SizedBox(height: 12),
            _SettingsSwitchTile(
              title: 'Vibration',
              subtitle: 'A gentle pulse when a session ends',
              value: focusState.vibrationEnabled,
              onChanged: focusState.setVibrationEnabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}