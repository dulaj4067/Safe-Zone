import 'package:flutter/material.dart';

/// Minimal stand-ins for tabs that aren't built out yet. Replace each with
/// its real screen as you build it — the bottom nav wiring in
/// MainScaffold won't need to change.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: const Center(child: Text('Active alerts will show here.')),
    );
  }
}

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          ),
          onPressed: () {
            // TODO: trigger SOS flow (send location + report to backend).
          },
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('Send SOS', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class SheltersScreen extends StatelessWidget {
  const SheltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shelters')),
      body: const Center(child: Text('Nearby shelters will show here.')),
    );
  }
}