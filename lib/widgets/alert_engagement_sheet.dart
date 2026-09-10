import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/alert_engagement.dart';
import '../models/zone.dart';
import '../providers/alert_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'severity_badge.dart';

/// Authority Admin modal bottom sheet displaying in-depth resident seen and
/// acknowledged percentage analytics for a specific broadcast alert and zone.
class AlertEngagementSheet extends StatefulWidget {
  final DisasterAlert alert;
  final List<Zone> zones;

  const AlertEngagementSheet({
    super.key,
    required this.alert,
    this.zones = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required DisasterAlert alert,
    List<Zone> zones = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlertEngagementSheet(alert: alert, zones: zones),
    );
  }

  @override
  State<AlertEngagementSheet> createState() => _AlertEngagementSheetState();
}

class _AlertEngagementSheetState extends State<AlertEngagementSheet> {
  ResidentEngagementStatus? _filter;
  String _searchQuery = '';
  bool _isLoading = true;
  ZoneAlertEngagement? _engagement;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  Future<void> _loadEngagement() async {
    setState(() => _isLoading = true);
    final provider = context.read<AlertProvider>();
    final data = await provider.getEngagementForAlert(
      widget.alert.id,
      zoneId: widget.alert.affectedZoneId,
      knownZones: widget.zones,
    );
    if (mounted) {
      setState(() {
        _engagement = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engagement = _engagement;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SeverityBadge(severity: widget.alert.severity),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.alert.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 15, color: AppColors.deepEstuary),
                          const SizedBox(width: 4),
                          Text(
                            engagement?.zoneName ?? 'Zone Target',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.deepEstuary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading || engagement == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Primary Percentage Overview Cards
                      _buildMetricsRow(context, engagement),
                      const SizedBox(height: 16),

                      // 2. Action Advisory / Threshold Alert
                      _buildActionAdvisoryBanner(context, engagement),
                      const SizedBox(height: 16),

                      // 3. Quick Administrative Actions
                      _buildAdminActionsSection(context, engagement),
                      const SizedBox(height: 16),

                      // 4. Resident Response Simulation Tool (for Testing/Demo)
                      _buildSimulationSection(context, engagement),
                      const SizedBox(height: 20),

                      // 5. Resident Roster Header & Search
                      _buildResidentRosterHeader(context, engagement),
                      const SizedBox(height: 12),

                      // 6. Resident Roster List
                      ..._buildResidentList(context, engagement),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context, ZoneAlertEngagement eng) {
    return Row(
      children: [
        // Acknowledged Metric
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.severityGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.severityGreen.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 16, color: AppColors.severityGreen),
                    const SizedBox(width: 6),
                    const Text(
                      'Acknowledged',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.severityGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${eng.acknowledgedPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.severityGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${eng.acknowledgedCount} of ${eng.totalResidents} residents',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (eng.acknowledgedPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: AppColors.severityGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Seen Metric
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.deepEstuary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.deepEstuary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_rounded,
                        size: 16, color: AppColors.deepEstuary),
                    const SizedBox(width: 6),
                    Text(
                      'Seen / Viewed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepEstuary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${eng.seenPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepEstuary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${eng.seenCount} of ${eng.totalResidents} residents',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (eng.seenPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: AppColors.deepEstuary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionAdvisoryBanner(
      BuildContext context, ZoneAlertEngagement eng) {
    final isCritical = eng.urgency == EngagementUrgency.critical;
    final isWarning = eng.urgency == EngagementUrgency.warning;

    final bgColor = isCritical
        ? AppColors.severityRed.withValues(alpha: 0.10)
        : (isWarning
            ? AppColors.severityOrange.withValues(alpha: 0.10)
            : AppColors.severityGreen.withValues(alpha: 0.10));

    final borderColor = isCritical
        ? AppColors.severityRed.withValues(alpha: 0.4)
        : (isWarning
            ? AppColors.severityOrange.withValues(alpha: 0.4)
            : AppColors.severityGreen.withValues(alpha: 0.4));

    final icon = isCritical
        ? Icons.warning_amber_rounded
        : (isWarning ? Icons.info_outline_rounded : Icons.check_circle_outline);

    final iconColor = isCritical
        ? AppColors.severityRed
        : (isWarning ? AppColors.severityOrange : AppColors.severityGreen);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      eng.urgency.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: iconColor,
                      ),
                    ),
                    if (eng.needsFurtherAction) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.severityRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FURTHER ACTION NEEDED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  eng.actionRecommendation,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionsSection(
      BuildContext context, ZoneAlertEngagement eng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Further Actions',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.sms_outlined, size: 16),
                label: const Text('SMS Push', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Emergency SMS broadcast queued for ${eng.unreachedCount} unreached residents in ${eng.zoneName}.',
                      ),
                      backgroundColor: AppColors.deepEstuary,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.group_outlined, size: 16),
                label: const Text('Ground Team', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Ground volunteer response unit notified for ${eng.zoneName}.',
                      ),
                      backgroundColor: AppColors.deepEstuary,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimulationSection(
      BuildContext context, ZoneAlertEngagement eng) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 15, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                'Test / Response Simulation Tool',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Simulate zone response rates to test alert thresholds:',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _buildSimChip(context, label: 'Low (20%)', ack: 0.2, seen: 0.3),
              _buildSimChip(context, label: 'Moderate (50%)', ack: 0.5, seen: 0.65),
              _buildSimChip(context, label: 'High (80%)', ack: 0.8, seen: 0.9),
              _buildSimChip(context, label: 'Full (100%)', ack: 1.0, seen: 1.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimChip(
    BuildContext context, {
    required String label,
    required double ack,
    required double seen,
  }) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () async {
        final provider = context.read<AlertProvider>();
        await provider.simulateZoneEngagement(
          widget.alert.id,
          widget.alert.affectedZoneId,
          ackRate: ack,
          seenRate: seen,
        );
        await _loadEngagement();
      },
    );
  }

  Widget _buildResidentRosterHeader(
      BuildContext context, ZoneAlertEngagement eng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Resident Roster (${eng.totalResidents})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              '${eng.unreachedCount} Unreached',
              style: TextStyle(
                fontSize: 12,
                color: eng.unreachedCount > 0 ? AppColors.severityRed : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search resident by name or phone...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Acknowledged'),
                selected: _filter == ResidentEngagementStatus.acknowledged,
                onSelected: (_) => setState(() => _filter =
                    _filter == ResidentEngagementStatus.acknowledged
                        ? null
                        : ResidentEngagementStatus.acknowledged),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Seen Only'),
                selected: _filter == ResidentEngagementStatus.seen,
                onSelected: (_) => setState(() => _filter =
                    _filter == ResidentEngagementStatus.seen
                        ? null
                        : ResidentEngagementStatus.seen),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Pending'),
                selected: _filter == ResidentEngagementStatus.pending,
                onSelected: (_) => setState(() => _filter =
                    _filter == ResidentEngagementStatus.pending
                        ? null
                        : ResidentEngagementStatus.pending),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResidentList(
      BuildContext context, ZoneAlertEngagement eng) {
    final filtered = eng.residents.where((r) {
      if (_filter != null && r.status != _filter) return false;
      if (_searchQuery.isNotEmpty) {
        final matchesName = r.fullName.toLowerCase().contains(_searchQuery);
        final matchesPhone = r.phone.toLowerCase().contains(_searchQuery);
        if (!matchesName && !matchesPhone) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No residents match the selected filter.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ];
    }

    return filtered.map((res) {
      final isAck = res.status == ResidentEngagementStatus.acknowledged;
      final isSeen = res.status == ResidentEngagementStatus.seen;

      final statusColor = isAck
          ? AppColors.severityGreen
          : (isSeen ? AppColors.deepEstuary : Colors.grey.shade600);

      final statusIcon = isAck
          ? Icons.check_circle
          : (isSeen ? Icons.visibility : Icons.hourglass_top);

      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.12),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          title: Text(
            res.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            res.phone,
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              res.status.label,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
