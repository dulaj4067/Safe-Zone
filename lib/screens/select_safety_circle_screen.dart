import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/safety_provider.dart';
import '../models/risk_zone.dart';
import 'live_eta_sharing_screen.dart';

class SelectSafetyCircleScreen extends StatefulWidget {
  final RiskZone? currentRiskZone;

  const SelectSafetyCircleScreen({super.key, this.currentRiskZone});

  @override
  State<SelectSafetyCircleScreen> createState() => _SelectSafetyCircleScreenState();
}

class _SelectSafetyCircleScreenState extends State<SelectSafetyCircleScreen> {
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
    final selectedCount = safety.selectedContacts.length;
    final zone = widget.currentRiskZone;

    return Scaffold(
      appBar: AppBar(title: const Text('Share Live Location')),
      body: Column(
        children: [
          if (zone != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: zone.fillColor,
                border: Border.all(color: zone.borderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: zone.borderColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      zone.name + ' - ' + zone.label,
                      style: TextStyle(fontWeight: FontWeight.w600, color: zone.borderColor),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose who should see your live location and ETA while '
                'you travel through this risk zone.',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
          ),
          if (safety.isLoading) const LinearProgressIndicator(),
          if (safety.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(safety.errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: safety.circle.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = safety.circle[index];
                return CheckboxListTile(
                  value: contact.isSelected,
                  onChanged: (checked) => context
                      .read<SafetyProvider>()
                      .toggleContactSelection(contact.id, checked ?? false),
                  secondary: CircleAvatar(child: Text(contact.initials)),
                  title: Text(contact.name),
                  subtitle: Text(contact.relationship + ' - ' + contact.phoneNumber),
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_location),
                  label: Text(
                    selectedCount == 0
                        ? 'Select at least one contact'
                        : 'Start sharing with ' + selectedCount.toString() + ' contact' + (selectedCount == 1 ? '' : 's'),
                  ),
                  onPressed: selectedCount == 0
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveEtaSharingScreen(currentRiskZone: zone),
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
