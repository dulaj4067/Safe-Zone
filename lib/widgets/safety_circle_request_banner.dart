import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/safety_circle_request.dart';
import '../providers/safety_provider.dart';
import '../theme/app_colors.dart';

/// App-wide banner (see AppShell's overlay Stack) asking the signed-in
/// user to confirm or decline being added to someone else's safety
/// circle. Shows one request at a time — if someone has several pending,
/// the rest appear as each one is resolved.
class SafetyCircleRequestBanner extends StatelessWidget {
  const SafetyCircleRequestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<SafetyProvider>().pendingRequests;
    if (requests.isEmpty) return const SizedBox.shrink();

    final request = requests.first;
    return Material(
      elevation: 4,
      color: AppColors.cloud,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.deepEstuary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.ownerName} wants to add you to their safety circle',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'As their "${request.relationship}", your live location will be '
                      'visible to them whenever you share it. Only confirm if you '
                      'recognize them.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _respond(context, request, false),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.deepEstuary,
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () => _respond(context, request, true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _respond(BuildContext context, SafetyCircleRequest request, bool accept) {
    context.read<SafetyProvider>().respondToPendingRequest(request.id, accept);
  }
}
