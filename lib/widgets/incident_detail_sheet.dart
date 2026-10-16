import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/incident.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/a11y/a11y_widgets.dart';
import '../widgets/status_badge.dart';
import '../widgets/incident_card.dart';

/// Lightweight bottom-sheet for map marker taps (HomeScreen, IncidentsScreen
/// map view). Shows a compact incident summary with a "View Details" button
/// that navigates to the full IncidentDetailScreen.
class IncidentDetailSheet extends StatelessWidget {
  final Incident incident;
  final VoidCallback? onConfirm;
  final VoidCallback? onViewDetails;

  /// Authorities only: marks a pending report as verified.
  final VoidCallback? onVerify;

  const IncidentDetailSheet({
    super.key,
    required this.incident,
    this.onConfirm,
    this.onViewDetails,
    this.onVerify,
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
              StatusBadge(status: incident.status),
            ],
          ),
          const SizedBox(height: 8),
          if (incident.description != null) Text(incident.description!),
          const SizedBox(height: 12),
          if (incident.photoUrl != null)
            A11yAdaptiveImage(
              url: incident.photoUrl!,
              height: 180,
              borderRadius: 8,
              semanticLabel: appStringsOf(context).t('photoEvidence'),
              errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
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
              Icon(
                categoryIcon(incident.category),
                size: 16,
                color: categoryColor(incident.category),
              ),
              const SizedBox(width: 4),
              Text(
                _timeAgo(incident.createdAt),
                style: AppTheme.dataText(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onViewDetails != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewDetails,
                    child: const Text('View Details'),
                  ),
                ),
              if (onViewDetails != null && onConfirm != null)
                const SizedBox(width: 12),
              if (onConfirm != null)
                Expanded(
                  child: FilledButton(
                    key: const Key('incident_confirm_button'),
                    onPressed: onConfirm,
                    child: const Text('Confirm'),
                  ),
                ),
            ],
          ),
          if (onVerify != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('incident_verify_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.severityGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: onVerify,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Verify report'),
              ),
            ),
          ],
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
