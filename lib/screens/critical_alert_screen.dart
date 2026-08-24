import 'package:flutter/material.dart';
import 'app_shell.dart';

void main() {
  runApp(const CriticalAlertApp());
}

class CriticalAlertApp extends StatelessWidget {
  const CriticalAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const CriticalAlertScreen(),
    );
  }
}

class CriticalAlertScreen extends StatelessWidget {
  const CriticalAlertScreen({super.key});

  static const Color bgRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgRed,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Warning icon circle
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),

              const SizedBox(height: 28),

              // Title
              const Text(
                'CRITICAL ALERT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 20),

              // Headline
              const Text(
                'Severe Flooding: Colombo District.\nEvacuate immediately to higher ground.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 18),

              // Description
              Text(
                'The Kelani River has breached its critical '
                'threshold. Kaduwela, Hanwella and low-lying '
                'Colombo suburbs must relocate to safety hubs '
                'immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 36),

              // Find Nearest Shelter button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: navigate to shelter map
                  },
                  icon: const Icon(Icons.location_on, color: bgRed),
                  label: const Text(
                    'Find Nearest Shelter',
                    style: TextStyle(
                      color: bgRed,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Call Emergency button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: launch dialer with tel:119
                  },
                  icon: const Icon(Icons.call, color: Colors.white),
                  label: const Text(
                    'Call Emergency: 119',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Dismiss Alert
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AppShell()),
                  );
                },
                child: const Text(
                  'Dismiss Alert',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}