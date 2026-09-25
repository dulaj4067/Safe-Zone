import 'package:flutter/material.dart';

import '../services/activity_history_service.dart';

class ResumeActivityCard extends StatelessWidget {
  final List<ActivityEntry> entries;
  final ValueChanged<ActivityEntry> onResume;

  const ResumeActivityCard({
    super.key,
    required this.entries,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resume where you left off', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final entry in entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.interrupted ? Icons.pause_circle_outline : Icons.history,
                  color: colors.primary,
                ),
                title: Text(entry.title),
                subtitle: Text(entry.interrupted ? 'Interrupted activity' : entry.section),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onResume(entry),
              ),
          ],
        ),
      ),
    );
  }
}
