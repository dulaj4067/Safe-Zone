import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../providers/safety_provider.dart';
import '../models/risk_zone.dart';
import '../widgets/im_safe_broadcast_button.dart';
import '../l10n/ui_text.dart';

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
      context.read<SafetyProvider>().loadFamilyCircle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();
    final family = safety.confirmedFamily;
    final strings = appStringsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('imSafeTitle'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          // A ListView, not a Column: longer translations and large text
          // scale push the content past the screen, so the page must scroll.
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Text(strings.t('imSafeHeading'),
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(strings.t('imSafeSub'),
                  textAlign: TextAlign.center, style: TextStyle(color: context.inkMuted)),
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
                Text(context.tr(safety.errorMessage!), style: const TextStyle(color: Colors.red)),
              if (safety.lastBroadcastAt != null)
                Text(
                  strings.f('sentAt', {
                    'time': '${safety.lastBroadcastAt!.hour.toString().padLeft(2, '0')}:${safety.lastBroadcastAt!.minute.toString().padLeft(2, '0')}',
                  }),
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(strings.f('familyCount', {'n': family.length}),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              if (safety.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (family.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    strings.t('noFamily'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.inkMuted),
                  ),
                )
              else
                for (var i = 0; i < family.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(child: Text(family[i].initials)),
                    title: Text(family[i].name),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
