import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';   
import '../models/focus_mode.dart';           
import '../constants/app_colors.dart';         
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';

/// Sprint 1's primary screen. Deliberately minimal: a large countdown,
/// the active mode, and session controls. No stats, no ambient
/// body-doubling, no companion counters — those are future sprints.
class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final focusState = context.watch<FocusState>();
    final mode = focusState.selectedMode;
    final status = focusState.status;

    final isRunning = status == SessionStatus.running;
    final isPaused = status == SessionStatus.paused;
    final isCompleted = status == SessionStatus.completed;

    final displaySeconds =
        status == SessionStatus.idle ? (mode.workDurationSeconds ?? 0) : focusState.seconds;

    String statusLabel;
    if (isRunning) {
      statusLabel = '${mode.label} Active';
    } else if (isPaused) {
      statusLabel = '${mode.label} Paused';
    } else if (isCompleted) {
      statusLabel = '${mode.label} Complete';
    } else {
      statusLabel = mode.label;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              statusLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isRunning ? AppColors.primaryDark : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(flex: 3),
            Text(
              _formatTime(displaySeconds),
              style: const TextStyle(
                fontSize: 68,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              mode.isCountdown ? 'Time remaining' : 'Time focused',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(flex: 4),
            if (isCompleted) ...[
              Text(
                'Nice work. Session complete.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Start Another',
                  onPressed: () {
                    focusState.resetSession();
                    focusState.startSession();
                  },
                ),
              ),
            ] else if (!focusState.isActive) ...[
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Start',
                  onPressed: focusState.startSession,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: isPaused ? 'Resume' : 'Pause',
                      icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      onPressed: isPaused ? focusState.resumeSession : focusState.pauseSession,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Complete',
                      icon: Icons.check_rounded,
                      onPressed: focusState.resetSession,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}