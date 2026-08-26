import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
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

    final success = await context.read<IncidentProvider>().verifyIncident(
          incident.id,
          userId,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Incident verified successfully.'
                : 'Failed to verify incident.',
          ),
          backgroundColor: success ? AppColors.severityGreen : AppColors.severityRed,
        ),
      );
    }
  }

  Future<void> _quickReject(Incident incident) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final success = await context.read<IncidentProvider>().rejectIncident(
          incident.id,
          userId,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Incident rejected.'
                : 'Failed to reject incident.',
          ),
          backgroundColor: success ? AppColors.severityRed : AppColors.severityRed,
        ),
      );
    }
  }

  Future<void> _quickResolve(Incident incident) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final success = await context.read<IncidentProvider>().resolveIncident(
          incident.id,
          userId,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Incident marked as resolved.'
                : 'Failed to resolve incident.',
          ),
          backgroundColor: success ? const Color(0xFF546E7A) : AppColors.severityRed,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Verification Queue'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Pending (${pendingIncidents.length})',
            ),
            Tab(
              text: 'SOS Priority (${sosIncidents.length})',
            ),
            Tab(
              text: 'Active Verified (${verifiedIncidents.length})',
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
            emptyMessage: 'No pending incidents awaiting review.',
            showPendingActions: true,
          ),

          // SOS Priority tab
          _buildReviewList(
            incidents: sosIncidents,
            emptyMessage: 'No high-priority SOS incidents currently pending.',
            showPendingActions: true,
          ),

          // Verified tab
          _buildReviewList(
            incidents: verifiedIncidents,
            emptyMessage: 'No verified incidents currently active.',
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: AppColors.severityGreen),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

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
                if (showPendingActions) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.severityRed,
                          side: const BorderSide(color: AppColors.severityRed),
                        ),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        onPressed: () => _quickReject(incident),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.severityGreen,
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Verify'),
                        onPressed: () => _quickVerify(incident),
                      ),
                    ],
                  ),
                ],
                if (showResolveAction) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF546E7A),
                      ),
                      icon: const Icon(Icons.task_alt, size: 16),
                      label: const Text('Mark Resolved'),
                      onPressed: () => _quickResolve(incident),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
