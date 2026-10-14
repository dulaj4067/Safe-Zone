import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../providers/accessibility_provider.dart';

class ImSafeBroadcastButton extends StatefulWidget {
  /// Returns true once the broadcast is actually saved. On false the button
  /// resets so the user can hold again.
  final Future<bool> Function() onConfirmed;
  final Duration holdDuration;

  const ImSafeBroadcastButton({
    super.key,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 900),
  });

  @override
  State<ImSafeBroadcastButton> createState() => _ImSafeBroadcastButtonState();
}

class _ImSafeBroadcastButtonState extends State<ImSafeBroadcastButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isSending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.holdDuration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_sent) _triggerBroadcast();
    });
  }

  Future<void> _triggerBroadcast() async {
    setState(() => _isSending = true);
    final ok = await widget.onConfirmed();
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _sent = ok;
    });
    if (ok) {
      // Optional vibration; the visible "Broadcast sent" state is the primary
      // confirmation and nothing relies on sound.
      pulseHapticOf(context);
    } else {
      _controller.reverse();
    }
  }

  void _onPressStart(_) {
    if (_sent) return;
    _controller.forward(from: 0);
  }

  void _onPressEnd(_) {
    if (_controller.status != AnimationStatus.completed) _controller.reverse();
  }

  /// Screen-reader / switch-access path: the visual control needs a 900ms
  /// press-and-hold, which assistive technology can't perform, so it also
  /// exposes tap and long-press as semantic actions that send right away.
  void _sendViaAssistiveAction() {
    if (_sent || _isSending) return;
    _triggerBroadcast();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = appStringsOf(context);
    if (_sent) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green.shade600),
        alignment: Alignment.center,
        // The circle is a fixed size; scaleDown keeps long labels inside it.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(strings.t('broadcastSent'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: strings.t('imSafeTitle'),
      hint: strings.t('imSafeHint'),
      onTap: _sendViaAssistiveAction,
      onLongPress: _sendViaAssistiveAction,
      child: GestureDetector(
      onLongPressStart: _onPressStart,
      onLongPressEnd: _onPressEnd,
      onLongPressCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEFF3EE)),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isSending ? Icons.hourglass_top : Icons.shield_outlined,
                            size: 40, color: Colors.green.shade700),
                        const SizedBox(height: 8),
                        Text(
                          _isSending ? strings.t('sending') : strings.t('holdToSay'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}
