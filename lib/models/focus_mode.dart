import 'package:flutter/material.dart';

/// The only three timer modes in scope for Sprint 1.
enum FocusMode { pomodoro, flowtime, fiftyTwoSeventeen }

extension FocusModeData on FocusMode {
  String get label {
    switch (this) {
      case FocusMode.pomodoro:
        return 'Pomodoro';
      case FocusMode.flowtime:
        return 'Flowtime';
      case FocusMode.fiftyTwoSeventeen:
        return '52/17 Rhythm';
    }
  }

  String get description {
    switch (this) {
      case FocusMode.pomodoro:
        return 'Structured intervals. Great for building starting momentum.';
      case FocusMode.flowtime:
        return 'No pressure clocks. Work until you feel ready for a break.';
      case FocusMode.fiftyTwoSeventeen:
        return 'A longer, steady rhythm for deep, sustained focus.';
    }
  }

  String get durationLabel {
    switch (this) {
      case FocusMode.pomodoro:
        return '25m focus • 5m rest';
      case FocusMode.flowtime:
        return 'Self-paced';
      case FocusMode.fiftyTwoSeventeen:
        return '52m focus • 17m rest';
    }
  }

  IconData get icon {
    switch (this) {
      case FocusMode.pomodoro:
        return Icons.timer_outlined;
      case FocusMode.flowtime:
        return Icons.explore_outlined;
      case FocusMode.fiftyTwoSeventeen:
        return Icons.wb_sunny_outlined;
    }
  }

  /// Fixed work duration in seconds. Null means open-ended (Flowtime),
  /// in which case the Focus screen counts time elapsed instead of
  /// counting down — there is no end time to count down to.
  int? get workDurationSeconds {
    switch (this) {
      case FocusMode.pomodoro:
        return 25 * 60;
      case FocusMode.flowtime:
        return null;
      case FocusMode.fiftyTwoSeventeen:
        return 52 * 60;
    }
  }

  bool get isCountdown => workDurationSeconds != null;
}