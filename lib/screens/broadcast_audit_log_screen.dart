import 'package:flutter/material.dart';
import '../l10n/admin_strings.dart';
import '../l10n/locale_format.dart';
import '../models/broadcast_audit_entry.dart';
import '../providers/accessibility_provider.dart';
import '../services/broadcast_audit_service.dart';
import '../theme/app_colors.dart';
import '../widgets/a11y/a11y_widgets.dart';
import '../widgets/severity_badge.dart';
import '../l10n/ui_text.dart';

class BroadcastAuditLogScreen extends StatefulWidget {
  final BroadcastAuditService? auditService;

  const BroadcastAuditLogScreen({super.key, this.auditService});

  @override
  State<BroadcastAuditLogScreen> createState() =>
      _BroadcastAuditLogScreenState();
}

class _BroadcastAuditLogScreenState extends State<BroadcastAuditLogScreen> {
  late final BroadcastAuditService _auditService;
  BroadcastAuditAction? _selectedAction;
  List<BroadcastAuditEntry> _allLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _auditService = widget.auditService ?? BroadcastAuditService();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _auditService.getAuditLogs();
    setState(() {
      _allLogs = logs;
      _isLoading = false;
    });
  }

  List<BroadcastAuditEntry> get _filteredLogs {
    if (_selectedAction == null) return _allLogs;
    return _allLogs.where((e) => e.action == _selectedAction).toList();
  }

  Future<void> _clearLogs() async {
    final confirmed = await confirmDestructive(
      context,
      title: context.tr('Clear Audit Logs?'),
      body: context.tr('Are you sure you want to clear all authority broadcast audit history? This action cannot be undone unless restored.'),
      confirmLabel: 'Clear All',
    );

    if (confirmed == true) {
      final backup = List<BroadcastAuditEntry>.from(_allLogs);
      await _auditService.clearAuditLogs();
      await _loadLogs();
      if (mounted) {
        showA11yUndoSnackBar(
          context,
          message: context.tr('Audit logs cleared.'),
          undoLabel: adminStringsOf(context).t('undo'),
          onUndo: () async {
            for (final log in backup) {
              await _auditService.logAction(
                alertId: log.alertId,
                alertTitle: log.alertTitle,
                severity: log.severity,
                action: log.action,
                performedBy: log.performedBy,
                details: log.details,
                zoneName: log.zoneName,
              );
            }
            await _loadLogs();
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;
    final strings = adminStringsOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('auditTitle')),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, semanticLabel: context.tr('Clear audit logs')),
            tooltip: context.tr('Clear Audit Logs'),
            onPressed: _allLogs.isEmpty ? null : _clearLogs,
          ),
          IconButton(
            icon: Icon(Icons.refresh, semanticLabel: context.tr('Refresh audit logs')),
            tooltip: context.tr('Refresh'),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(context.tr('Immutable audit trail for authority broadcast actions and accountability.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          // Filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(context.tr('All')),
                  selected: _selectedAction == null,
                  onSelected: (_) => setState(() => _selectedAction = null),
                ),
                const SizedBox(width: 8),
                ...BroadcastAuditAction.values.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        action.icon,
                        size: 16,
                        color: _selectedAction == action
                            ? Colors.white
                            : action.color,
                      ),
                      label: Text(context.tr(action.label)),
                      selected: _selectedAction == action,
                      onSelected: (_) => setState(() =>
                          _selectedAction = _selectedAction == action ? null : action),
                    ),
                  );
                }),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? A11yEmptyState(
                        icon: Icons.assignment_outlined,
                        message: _selectedAction == null
                            ? 'No broadcast audit logs recorded.'
                            : 'No ${entryActionName(_selectedAction)} audit entries found.',
                        hint: context.tr('Actions such as alert creation, multi-channel dispatch, resolution, and archival will be logged here automatically.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = filtered[index];
                          return _AuditLogCard(entry: log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  static String entryActionName(BroadcastAuditAction? action) {
    if (action == null) return '';
    return action.label.toLowerCase();
  }
}

class _AuditLogCard extends StatelessWidget {
  final BroadcastAuditEntry entry;

  const _AuditLogCard({required this.entry});

  String _formatTimestamp(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return LocaleFormat.dateTime(dt, locale: localeCodeOf(context));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: entry.action.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                entry.action.icon,
                color: entry.action.color,
                size: 20,
                semanticLabel: entry.action.label,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.action.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.action.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: entry.action.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (entry.severity != null)
                        SeverityBadge(severity: entry.severity!),
                      const Spacer(),
                      Text(
                        _formatTimestamp(context, entry.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.alertTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.details,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.inkStrong,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: context.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(context.tr('By {p0}', {'p0': entry.performedBy}),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.inkMuted,
                        ),
                      ),
                      if (entry.zoneName != null && entry.zoneName!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: context.inkMuted,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          entry.zoneName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
