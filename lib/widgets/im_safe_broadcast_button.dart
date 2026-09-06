import 'package:flutter/material.dart';

class ImSafeBroadcastButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
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
    await widget.onConfirmed();
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _sent = true;
    });
  }

  void _onPressStart(_) {
    if (_sent) return;
    _controller.forward(from: 0);
  }

  void _onPressEnd(_) {
    if (_controller.status != AnimationStatus.completed) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green.shade600),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 48),
            SizedBox(height: 8),
            Text('Broadcast sent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return GestureDetector(
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isSending ? Icons.hourglass_top : Icons.shield_outlined,
                        size: 40, color: Colors.green.shade700),
                    const SizedBox(height: 8),
                    Text(
                      _isSending ? 'Sending...' : 'Hold to say\n"I\'m Safe"',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
