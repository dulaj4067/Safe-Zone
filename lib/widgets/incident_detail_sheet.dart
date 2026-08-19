import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../theme/app_theme.dart';

class IncidentDetailSheet extends StatelessWidget {
  final Incident incident;
  final VoidCallback? onConfirm;

  const IncidentDetailSheet({
    super.key,
    required this.incident,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (incident.isSos)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red),
                ),
              Expanded(
                child: Text(
                  incident.category.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (incident.description != null) Text(incident.description!),
          const SizedBox(height: 12),
          if (incident.photoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                incident.photoUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${incident.credibilityScore} confirmations',
                  style: AppTheme.dataText(context)),
              const Spacer(),
              Text(
                _timeAgo(incident.createdAt),
                style: AppTheme.dataText(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (onConfirm != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onConfirm,
                child: const Text('Confirm this report'),
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
