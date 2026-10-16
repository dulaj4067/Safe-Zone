import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../providers/accessibility_provider.dart';

/// Vibration patterns that tell severities apart by feel, so someone who
/// can't look at the screen (or hear it) still knows how serious it is:
///
/// - green  : one soft tick
/// - yellow : one firm pulse
/// - orange : two strong pulses
/// - red    : four strong pulses in quick succession
///
/// Orange and red are life-safety signals and always play. Green and yellow
/// are informational, so they follow the person's haptics setting
/// ([enabled]). Never throws: a device without a vibration motor (or a unit
/// test with no platform) just does nothing.
Future<void> playSeverityHaptic(
  AlertSeverity severity, {
  bool enabled = true,
}) async {
  try {
    switch (severity) {
      case AlertSeverity.green:
        if (enabled) await HapticFeedback.selectionClick();
      case AlertSeverity.yellow:
        if (enabled) await HapticFeedback.mediumImpact();
      case AlertSeverity.orange:
        await _pulses(2, const Duration(milliseconds: 220));
      case AlertSeverity.red:
        await _pulses(4, const Duration(milliseconds: 160));
    }
  } catch (_) {
    // No haptics available.
  }
}

Future<void> _pulses(int count, Duration gap) async {
  for (var i = 0; i < count; i++) {
    await HapticFeedback.heavyImpact();
    if (i < count - 1) await Future<void>.delayed(gap);
  }
}

/// [playSeverityHaptic] using the signed-in person's haptics setting; safe
/// to call where no AccessibilityProvider exists.
Future<void> severityHapticOf(BuildContext context, AlertSeverity severity) {
  var enabled = true;
  try {
    enabled = Provider.of<AccessibilityProvider>(context, listen: false).hapticsEnabled;
  } catch (_) {}
  return playSeverityHaptic(severity, enabled: enabled);
}
