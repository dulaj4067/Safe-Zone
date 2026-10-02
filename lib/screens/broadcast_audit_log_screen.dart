import 'package:flutter/material.dart';
import '../models/broadcast_audit_entry.dart';
import '../services/broadcast_audit_service.dart';
import '../widgets/severity_badge.dart';

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Audit Logs?'),
        content: const Text(
          'Are you sure you want to clear all authority broadcast audit history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auditService.clearAuditLogs();
      await _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Audit Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Audit Logs',
            onPressed: _allLogs.isEmpty ? null : _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
                  child: Text(
                    'Immutable audit trail for authority broadcast actions and accountability.',
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
                  label: const Text('All'),
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
                      label: Text(action.label),
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 56,
                                color: Theme.of(context).disabledColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedAction == null
                                    ? 'No broadcast audit logs recorded.'
                                    : 'No ${_selectedAction!.label.toLowerCase()} audit entries found.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Actions such as alert creation, multi-channel dispatch, resolution, and archival will be logged here automatically.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

class _AuditLogCard extends StatelessWidget {
  final BroadcastAuditEntry entry;

  const _AuditLogCard({required this.entry});

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                        _formatTimestamp(entry.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
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
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'By ${entry.performedBy}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (entry.zoneName != null && entry.zoneName!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          entry.zoneName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
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
