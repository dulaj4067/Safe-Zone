import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../providers/accessibility_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/a11y/a11y_widgets.dart';
import '../widgets/incident_card.dart';
import 'incident_detail_screen.dart';

class AdminIncidentReviewScreen extends StatefulWidget {
  final AppUser currentUser;

  const AdminIncidentReviewScreen({super.key, required this.currentUser});

  @override
  State<AdminIncidentReviewScreen> createState() => _AdminIncidentReviewScreenState();
}

class _AdminIncidentReviewScreenState extends State<AdminIncidentReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openDetail(Incident incident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailScreen(
          incident: incident,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _quickVerify(Incident incident) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final previous = incident.status;
    final strings = adminStringsOf(context);

    final success = await context.read<IncidentProvider>().verifyIncident(
          incident.id,
          userId,
        );

    if (!mounted) return;
    if (success) {
      showA11yUndoSnackBar(
        context,
        message: 'Incident verified successfully.',
        undoLabel: strings.t('undo'),
        onUndo: () {
          context.read<IncidentProvider>().restoreIncidentStatus(
                incidentId: incident.id,
                status: previous,
                verifiedBy: userId,
              );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('Could not verify this report. Try again.')),
            ],
          ),
          backgroundColor: AppColors.severityRed,
        ),
      );
    }
  }

  Future<void> _quickReject(Incident incident) async {
    final strings = adminStringsOf(context);
    final confirmed = await confirmDestructive(
      context,
      title: strings.t('reject'),
      body: strings.t('confirmReject'),
      confirmLabel: strings.t('reject'),
      cancelLabel: strings.t('cancel'),
    );
    if (!confirmed) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final previous = incident.status;

    final success = await context.read<IncidentProvider>().rejectIncident(
          incident.id,
          userId,
        );

    if (!mounted) return;
    if (success) {
      showA11yUndoSnackBar(
        context,
        message: 'Incident rejected.',
        undoLabel: strings.t('undo'),
        onUndo: () {
          context.read<IncidentProvider>().restoreIncidentStatus(
                incidentId: incident.id,
                status: previous,
                verifiedBy: userId,
              );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('Could not reject this report. Try again.')),
            ],
          ),
          backgroundColor: AppColors.severityRed,
        ),
      );
    }
  }

  Future<void> _quickResolve(Incident incident) async {
    final strings = adminStringsOf(context);
    final confirmed = await confirmDestructive(
      context,
      title: strings.t('resolve'),
      body: strings.t('confirmResolve'),
      confirmLabel: strings.t('resolve'),
      cancelLabel: strings.t('cancel'),
    );
    if (!confirmed) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final previous = incident.status;

    final success = await context.read<IncidentProvider>().resolveIncident(
          incident.id,
          userId,
        );

    if (!mounted) return;
    if (success) {
      showA11yUndoSnackBar(
        context,
        message: 'Incident marked as resolved.',
        undoLabel: strings.t('undo'),
        onUndo: () {
          context.read<IncidentProvider>().restoreIncidentStatus(
                incidentId: incident.id,
                status: previous,
                verifiedBy: userId,
              );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('Could not resolve this report. Try again.')),
            ],
          ),
          backgroundColor: AppColors.severityRed,
        ),
      );
    }
  }

  Future<void> _quickDelete(Incident incident) async {
    String selectedReason = 'Spam / Inappropriate';
    final reasons = [
      'Spam / Inappropriate',
      'Duplicate Incident Report',
      'False / Misleading Information',
      'Outdated / Incorrect Location',
      'Other Violation',
    ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gavel, color: AppColors.severityRed),
              SizedBox(width: 8),
              Text('Delete / Purge Report'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Permanently remove this report from the map to eliminate spam, duplicates, or false submissions.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text(
                'Moderation reason:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: reasons
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedReason = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.severityRed,
              ),
              icon: const Icon(Icons.delete_forever, size: 16),
              onPressed: () => Navigator.pop(ctx, true),
              label: const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await context.read<IncidentProvider>().deleteIncident(incident.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Incident removed as "$selectedReason".'
                : 'Failed to delete incident.',
          ),
          backgroundColor: AppColors.severityRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();
    final allIncidents = provider.sortedIncidents;

    final pendingIncidents = allIncidents.where((i) => i.status == IncidentStatus.pending).toList();
    final sosIncidents = allIncidents.where((i) => i.isSos && i.status == IncidentStatus.pending).toList();
    final verifiedIncidents = allIncidents.where((i) => i.status == IncidentStatus.verified).toList();

    final strings = adminStringsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('reviewTitle')),
        actions: const [A11yInclusionButton()],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: '${strings.t('pending')} (${pendingIncidents.length})',
            ),
            Tab(
              text: '${strings.t('sosPriority')} (${sosIncidents.length})',
            ),
            Tab(
              text: '${strings.t('activeVerified')} (${verifiedIncidents.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pending tab
          _buildReviewList(
            incidents: pendingIncidents,
            emptyMessage: strings.t('emptyPending'),
            showPendingActions: true,
          ),

          // SOS Priority tab
          _buildReviewList(
            incidents: sosIncidents,
            emptyMessage: strings.t('emptySos'),
            showPendingActions: true,
          ),

          // Verified tab
          _buildReviewList(
            incidents: verifiedIncidents,
            emptyMessage: strings.t('emptyVerified'),
            showResolveAction: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList({
    required List<Incident> incidents,
    required String emptyMessage,
    bool showPendingActions = false,
    bool showResolveAction = false,
  }) {
    if (incidents.isEmpty) {
      return A11yEmptyState(
        icon: Icons.check_circle_outline,
        message: emptyMessage,
      );
    }
    final strings = adminStringsOf(context);

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: incidents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final incident = incidents[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IncidentCard(
                  incident: incident,
                  onTap: () => _openDetail(incident),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.severityRed),
                      tooltip: strings.t('delete'),
                      onPressed: () => _quickDelete(incident),
                    ),
                    if (showPendingActions) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.severityRed,
                          side: const BorderSide(color: AppColors.severityRed),
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.close, size: 16),
                        label: Text(strings.t('reject')),
                        onPressed: () => _quickReject(incident),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.severityGreen,
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(strings.t('verify')),
                        onPressed: () => _quickVerify(incident),
                      ),
                    ],
                    if (showResolveAction) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF546E7A),
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.task_alt, size: 16),
                        label: Text(strings.t('resolve')),
                        onPressed: () => _quickResolve(incident),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
