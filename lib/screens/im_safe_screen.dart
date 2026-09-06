import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/safety_provider.dart';
import '../models/risk_zone.dart';
import '../widgets/im_safe_broadcast_button.dart';

class ImSafeScreen extends StatefulWidget {
  final RiskZone? currentRiskZone;

  const ImSafeScreen({super.key, this.currentRiskZone});

  @override
  State<ImSafeScreen> createState() => _ImSafeScreenState();
}

class _ImSafeScreenState extends State<ImSafeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SafetyProvider>().loadSafetyCircle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('I\'m Safe')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text('Let your safety circle know you\'re okay',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('This sends one instant notification to everyone below.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 32),
              Center(
                child: ImSafeBroadcastButton(
                  onConfirmed: () => context
                      .read<SafetyProvider>()
                      .sendImSafeBroadcast(currentRiskZone: widget.currentRiskZone),
                ),
              ),
              const SizedBox(height: 32),
              if (safety.errorMessage != null)
                Text(safety.errorMessage!, style: const TextStyle(color: Colors.red)),
              if (safety.lastBroadcastAt != null)
                Text(
                  'Sent at ' + safety.lastBroadcastAt!.hour.toString().padLeft(2, '0') + ':' + safety.lastBroadcastAt!.minute.toString().padLeft(2, '0'),
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Your safety circle (' + safety.circle.length.toString() + ')',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: safety.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: safety.circle.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = safety.circle[i];
                          return ListTile(
                            leading: CircleAvatar(child: Text(c.initials)),
                            title: Text(c.name),
                            subtitle: Text(c.relationship),
                            trailing: safety.lastBroadcastAt != null
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
