import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/alert_engagement.dart';
import '../models/zone.dart';
import '../providers/alert_provider.dart';
import '../l10n/locale_format.dart';
import '../providers/accessibility_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/a11y/a11y_widgets.dart';
import '../widgets/alert_engagement_sheet.dart';
import '../widgets/severity_badge.dart';
import 'broadcast_audit_log_screen.dart';
import 'feedback_overview_screen.dart';
import 'messages_screen.dart';
import 'volunteer_tasks_screen.dart';

/// Story 4 & Authority Dashboard: authority-only live view of every active/escalated broadcast,
/// with real-time zone resident seen and acknowledged percentage analytics, action threshold
/// indicators ("Further Action Needed"), resident roster inspection, and inline resolve/archive actions.
class BroadcastDashboardScreen extends StatefulWidget {
  final List<Zone> zones;

  const BroadcastDashboardScreen({super.key, this.zones = const []});

  @override
  State<BroadcastDashboardScreen> createState() =>
      _BroadcastDashboardScreenState();
}

class _BroadcastDashboardScreenState extends State<BroadcastDashboardScreen> {
  AlertSeverity? _filter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final alerts = _filter == null
        ? provider.allAlerts
        : provider.allAlerts.where((a) => a.severity == _filter).toList();

    // Highest severity first, then most recent — matches Story 4 AC.
    final sorted = [...alerts]
      ..sort((a, b) {
        final sevCompare = b.severity.index.compareTo(a.severity.index);
        if (sevCompare != 0) return sevCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

    final strings = adminStringsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('dashboardTitle')),
        actions: [
          const A11yInclusionButton(),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, semanticLabel: 'Audit log'),
            tooltip: 'Audit Log',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BroadcastAuditLogScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _CoordinationShortcuts(zones: widget.zones),
          _SeverityFilterRow(
            selected: _filter,
            onSelected: (s) => setState(() => _filter = s),
          ),
          if (provider.isOffline)
            Material(
              color: AppColors.offlineAmber,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 20, semanticLabel: 'Offline'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.t('offlineBanner'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: sorted.isEmpty
                ? A11yEmptyState(
                    icon: Icons.campaign_outlined,
                    message: strings.t('emptyBroadcasts'),
                    hint: strings.t('emptyBroadcastsHint'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _AlertDashboardCard(
                      alert: sorted[index],
                      zones: widget.zones,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Entry points to the coordination tools that sit alongside broadcasts:
/// posting/managing volunteer tasks, shelter message threads, and the
/// citizen feedback overview.
class _CoordinationShortcuts extends StatelessWidget {
  final List<Zone> zones;

  const _CoordinationShortcuts({required this.zones});

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _ShortcutButton(
              icon: Icons.volunteer_activism_outlined,
              label: 'Volunteers',
              onTap: () => open(VolunteerTasksScreen(zones: zones)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ShortcutButton(
              icon: Icons.chat_bubble_outline,
              label: 'Messages',
              onTap: () => open(const MessagesScreen()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ShortcutButton(
              icon: Icons.reviews_outlined,
              label: 'Feedback',
              onTap: () => open(FeedbackOverviewScreen(zones: zones)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(0, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SeverityFilterRow extends StatelessWidget {
  final AlertSeverity? selected;
  final ValueChanged<AlertSeverity?> onSelected;

  const _SeverityFilterRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            const SizedBox(width: 8),
            ...AlertSeverity.values.map((s) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: selected == s,
                  onSelected: (_) => onSelected(selected == s ? null : s),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AlertDashboardCard extends StatelessWidget {
  final DisasterAlert alert;
  final List<Zone> zones;

  const _AlertDashboardCard({
    required this.alert,
    this.zones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Severity + Title
            Row(
              children: [
                SeverityBadge(severity: alert.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.instructions ?? 'No instructions provided',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Builder(
              builder: (context) {
                var showCaptions = true;
                try {
                  showCaptions = context.watch<AccessibilityProvider>().captionsEnabled;
                } catch (_) {}
                final hasTranscript = alert.instructions?.contains('Transcript:') ?? false;
                if (!showCaptions || !hasTranscript) return const SizedBox.shrink();
                final transcriptText = alert.instructions!.split('Transcript:').last.trim();
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.seafoam,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.riverTeal.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.closed_caption,
                        size: 18,
                        color: AppColors.deepEstuary,
                        semanticLabel: 'Siren broadcast transcript',
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          transcriptText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepEstuary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${alert.alertType} · ${alert.radiusMeters}m · ${LocaleFormat.date(alert.createdAt, locale: localeCodeOf(context))}',
                    style: AppTheme.dataText(context),
                  ),
                ),
                Row(
                  children: [
                    _buildChannelBadge(
                      icon: Icons.notifications_active,
                      label: 'Push',
                      color: AppColors.riverTeal,
                    ),
                    const SizedBox(width: 4),
                    _buildChannelBadge(
                      icon: Icons.sms_outlined,
                      label: 'SMS',
                      color: AppColors.severityOrange,
                    ),
                    const SizedBox(width: 4),
                    _buildChannelBadge(
                      icon: Icons.volume_up,
                      label: 'Siren',
                      color: AppColors.severityRed,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Resident Seen & Acknowledged Reach Section
            FutureBuilder<ZoneAlertEngagement>(
              future: alertProvider.getEngagementForAlert(
                alert.id,
                zoneId: alert.affectedZoneId,
                knownZones: zones,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final engagement = snapshot.data;
                if (engagement == null) return const SizedBox.shrink();

                return _buildEngagementSummaryBox(context, engagement);
              },
            ),

            const SizedBox(height: 10),
            // Wrap rather than Row: all four actions don't fit on one line
            // on a phone, so Resolve/Archive drop to a second line.
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Resident Breakdown', style: TextStyle(fontSize: 12)),
                  onPressed: () => AlertEngagementSheet.show(
                    context,
                    alert: alert,
                    zones: zones,
                  ),
                ),
                OutlinedButton.icon(
                  key: Key('escalate_btn_${alert.id}'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    foregroundColor: AppColors.severityOrange,
                    side: BorderSide(
                      color: AppColors.severityOrange.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.trending_up_rounded, size: 16, semanticLabel: 'Escalate or edit this broadcast'),
                  label: const Text('Escalate', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showEscalateSheet(context, alert),
                ),
                TextButton(
                  onPressed: () => _confirmAndRun(
                    context,
                    title: 'Resolve alert?',
                    body: 'Citizens will see this as de-escalated.',
                    action: () =>
                        context.read<AlertProvider>().resolveAlert(alert.id),
                  ),
                  child: const Text('Resolve'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _confirmAndRun(
                    context,
                    title: 'Archive alert?',
                    body: 'This removes it from the live dashboard entirely.',
                    action: () =>
                        context.read<AlertProvider>().archiveAlert(alert.id),
                  ),
                  child: const Text('Archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementSummaryBox(
    BuildContext context,
    ZoneAlertEngagement engagement,
  ) {
    final isCritical = engagement.urgency == EngagementUrgency.critical;
    final isWarning = engagement.urgency == EngagementUrgency.warning;

    final badgeColor = isCritical
        ? AppColors.severityRed
        : (isWarning ? AppColors.severityOrange : AppColors.severityGreen);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone Target and Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_location, size: 14, color: AppColors.deepEstuary),
                  const SizedBox(width: 4),
                  Text(
                    engagement.zoneName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.deepEstuary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (engagement.needsFurtherAction) ...[
                      Icon(Icons.warning_amber_rounded, size: 11, color: badgeColor),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      engagement.needsFurtherAction
                          ? 'FURTHER ACTION NEEDED'
                          : 'ON TRACK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Percentage Metrics Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Acknowledged %
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.severityGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Acknowledged',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${engagement.acknowledgedPercentage.toStringAsFixed(1)}% (${engagement.acknowledgedCount}/${engagement.totalResidents})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.severityGreen,
                    ),
                  ),
                ],
              ),

              // Seen %
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.deepEstuary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Seen / Opened',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${engagement.seenPercentage.toStringAsFixed(1)}% (${engagement.seenCount}/${engagement.totalResidents})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepEstuary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-layer Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: (engagement.acknowledgedPercentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade300,
                color: engagement.needsFurtherAction
                    ? AppColors.severityOrange
                    : AppColors.severityGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String body,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await action();
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Shows the Escalate / Edit bottom sheet so the authority admin can raise
  /// the severity level, update the title, and edit the instructions.
  void _showEscalateSheet(BuildContext context, DisasterAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EscalateSheet(alert: alert, zones: zones),
    );
  }
}

// ─── Escalate / Edit Bottom Sheet ────────────────────────────────────────────

class _EscalateSheet extends StatefulWidget {
  final DisasterAlert alert;
  final List<Zone> zones;

  const _EscalateSheet({required this.alert, required this.zones});

  @override
  State<_EscalateSheet> createState() => _EscalateSheetState();
}

class _EscalateSheetState extends State<_EscalateSheet> {
  late AlertSeverity _severity;
  late TextEditingController _titleCtrl;
  late TextEditingController _instructionsCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _severity = widget.alert.severity;
    _titleCtrl = TextEditingController(text: widget.alert.title);
    _instructionsCtrl = TextEditingController(
      text: widget.alert.instructions ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _severity != widget.alert.severity ||
      _titleCtrl.text.trim() != widget.alert.title ||
      _instructionsCtrl.text.trim() != (widget.alert.instructions ?? '');

  Future<void> _submit() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AlertProvider>().escalateAlert(
            widget.alert.id,
            newSeverity: _severity,
            newTitle: _titleCtrl.text.trim(),
            newInstructions: _instructionsCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  color: Colors.white, size: 18, semanticLabel: 'Escalated'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Broadcast escalated to ${_severity.label}.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.severityOrange,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Could not save escalation. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHigher = _severity.index > widget.alert.severity.index;
    final isLower = _severity.index < widget.alert.severity.index;

    // Colour coding for the severity direction indicator.
    final directionColor = isHigher
        ? AppColors.severityOrange
        : (isLower ? AppColors.severityGreen : AppColors.slateMuted);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.severityOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.severityOrange,
                  size: 22,
                  semanticLabel: 'Escalate broadcast',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Escalate / Edit Broadcast',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slateInk,
                      ),
                    ),
                    Text(
                      'Changes are broadcast-wide immediately.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Severity picker
          Semantics(
            label: 'Severity level selector',
            child: DropdownButtonFormField<AlertSeverity>(
              key: const Key('escalate_severity_dropdown'),
              decoration: const InputDecoration(
                labelText: 'Severity *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber_rounded),
              ),
              value: _severity,
              items: AlertSeverity.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _severityColor(s),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(s.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _severity = v);
              },
            ),
          ),

          // Direction chip — shows whether this is an escalation or de-escalation.
          if (_severity != widget.alert.severity) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isHigher ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: directionColor,
                  semanticLabel: isHigher ? 'Escalating severity' : 'Reducing severity',
                ),
                const SizedBox(width: 4),
                Text(
                  isHigher
                      ? 'Escalating from ${widget.alert.severity.label} to ${_severity.label}'
                      : 'Reducing from ${widget.alert.severity.label} to ${_severity.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: directionColor,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Title field
          TextField(
            key: const Key('escalate_title_field'),
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alert title *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Instructions field
          TextField(
            key: const Key('escalate_instructions_field'),
            controller: _instructionsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Updated instructions',
              hintText: 'Example: Evacuate immediately via Route B.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          // Error banner
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.severityRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.severityRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.severityRed,
                      size: 18,
                      semanticLabel: 'Error'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.severityRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('escalate_cancel_btn'),
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('escalate_confirm_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.severityOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.trending_up_rounded,
                          semanticLabel: 'Confirm escalation'),
                  onPressed: (_submitting || !_hasChanges) ? null : _submit,
                  label: Text(
                    _submitting ? 'Saving…' : 'Confirm Escalation',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.green:
        return AppColors.severityGreen;
      case AlertSeverity.yellow:
        return AppColors.severityYellow;
      case AlertSeverity.orange:
        return AppColors.severityOrange;
      case AlertSeverity.red:
        return AppColors.severityRed;
    }
  }
}
