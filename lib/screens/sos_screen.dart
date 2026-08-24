import 'dart:async';
import 'package:flutter/material.dart';

/// Standalone screen matching the "Emergency Assistance / SOS" mock.
/// Drop this file into your project and push/route to `SosScreen()`.
///
/// No external packages required — only `flutter/material.dart`.
/// Swap the color constants below for your app's real theme tokens
/// once you wire this into your design system.

const _kNavy = Color(0xFF0B2A4A);
const _kRed = Color(0xFFB63A3A);
const _kCream = Color(0xFFF3F1EC);
const _kMuted = Color(0xFF8A8A8A);

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with TickerProviderStateMixin {
  static const Duration _holdDuration = Duration(seconds: 3);

  late final AnimationController _holdController;
  late final AnimationController _pulseController;

  Timer? _completionGuard;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();

    _holdController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onSosTriggered();
        }
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _holdController.dispose();
    _pulseController.dispose();
    _completionGuard?.cancel();
    super.dispose();
  }

  void _startHold() {
    setState(() => _isHolding = true);
    _holdController.forward(from: _holdController.value);
  }

  void _cancelHold() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _holdController.reverse();
  }

  void _onSosTriggered() {
    setState(() => _isHolding = false);
    _holdController.value = 0;
    HapticFeedbackStub.notify();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS sent to emergency services.')),
    );
  }

  void _reportIncident() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening incident report…')),
    );
  }

  void _callEmergencyServices() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calling 119…')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Emergency Assistance',
              style: TextStyle(
                color: _kNavy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _kCream,
                  borderRadius: BorderRadius.circular(4),
                  border: Border(
                    left: BorderSide(color: _kNavy.withOpacity(0.6), width: 3),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: _SosHoldButton(
                          holdController: _holdController,
                          pulseController: _pulseController,
                          isHolding: _isHolding,
                          onHoldStart: _startHold,
                          onHoldEnd: _cancelHold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _callEmergencyServices,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kNavy,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.phone, size: 20),
                              label: const Text(
                                'Call Emergency Services (119)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _reportIncident,
                            child: const Text(
                              'Report Incident Instead',
                              style: TextStyle(
                                color: _kNavy,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: _kNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _BottomNavBar(
              currentIndex: 2,
              onTap: (i) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _SosHoldButton extends StatelessWidget {
  const _SosHoldButton({
    required this.holdController,
    required this.pulseController,
    required this.isHolding,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final AnimationController holdController;
  final AnimationController pulseController;
  final bool isHolding;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  static const double _size = 220;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onHoldStart(),
      onTapUp: (_) => onHoldEnd(),
      onTapCancel: onHoldEnd,
      child: SizedBox(
        width: _size + 60,
        height: _size + 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                final t = isHolding ? 1.0 : pulseController.value;
                final scale = 1.0 + (0.12 * t);
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: 0.18 + (0.10 * (1 - t)),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: _size + 40,
                height: _size + 40,
                decoration: const BoxDecoration(
                  color: _kRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: holdController,
              builder: (context, _) {
                return SizedBox(
                  width: _size + 14,
                  height: _size + 14,
                  child: CircularProgressIndicator(
                    value: holdController.value == 0
                        ? null
                        : holdController.value,
                    strokeWidth: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(
                      holdController.value > 0
                          ? Colors.white
                          : Colors.transparent,
                    ),
                  ),
                );
              },
            ),
            AnimatedScale(
              scale: isHolding ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: _size,
                height: _size,
                decoration: const BoxDecoration(
                  color: _kRed,
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'HOLD FOR SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3 SECONDS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (_NavIcon.home, 'Home'),
    (_NavIcon.alerts, 'Alerts'),
    (_NavIcon.sos, 'SOS'),
    (_NavIcon.shelters, 'Shelters'),
    (_NavIcon.hub, 'Hub'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final selected = i == currentIndex;
          final color = selected ? _kNavy : _kMuted;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconFor(_items[i].$1), color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  _items[i].$2,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  IconData _iconFor(_NavIcon icon) {
    switch (icon) {
      case _NavIcon.home:
        return Icons.home_outlined;
      case _NavIcon.alerts:
        return Icons.notifications_none;
      case _NavIcon.sos:
        return Icons.warning_amber_rounded;
      case _NavIcon.shelters:
        return Icons.cancel_outlined;
      case _NavIcon.hub:
        return Icons.menu;
    }
  }
}

enum _NavIcon { home, alerts, sos, shelters, hub }

/// Placeholder so this file has zero extra package dependencies.
/// Replace with `HapticFeedback.heavyImpact()` from `flutter/services.dart`
/// if you want real device vibration on trigger.
class HapticFeedbackStub {
  static void notify() {}
}