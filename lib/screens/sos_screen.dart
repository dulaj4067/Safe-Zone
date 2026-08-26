import 'dart:async';
import 'package:flutter/material.dart';

/// SOS / Emergency Assistance tab content.
/// Meant to be used as one entry in AppShell's `tabs` list —
/// bottom navigation is already handled by AppShell's NavigationBar,
/// so this widget only renders the screen body.
///
/// No external packages required — only `flutter/material.dart`.
/// Swap the color constants below for your app's real theme tokens
/// once you wire this into your design system.

const _kNavy = Color(0xFF0B2A4A);
const _kRed = Color(0xFFB63A3A);
const _kCream = Color(0xFFF3F1EC);

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

    // Ambient glow behind the button, always gently pulsing.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _holdController.dispose();
    _pulseController.dispose();
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

    // TODO: Replace with your real SOS dispatch logic
    // (e.g. call a SupabaseService method, push a location ping, etc.)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS sent to emergency services.')),
    );
  }

  void _reportIncident() {
    // TODO: Replace with navigation to your report-incident flow,
    // e.g. Navigator.push(context, MaterialPageRoute(builder: (_) => ReportIncidentScreen()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening incident report…')),
    );
  }

  void _callEmergencyServices() {
    // TODO: Replace with url_launcher:
    // await launchUrl(Uri(scheme: 'tel', path: '119'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calling 119…')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
        ],
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
            // Ambient outer glow, pulses gently at rest, holds steady while pressed.
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
            // Progress ring showing hold completion.
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
            // Core button.
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