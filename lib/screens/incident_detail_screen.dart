import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/map_tile_sources.dart';
import '../widgets/incident_card.dart';
import '../widgets/status_badge.dart';
import 'edit_incident_screen.dart';

class IncidentDetailScreen extends StatefulWidget {
  final Incident incident;
  final AppUser? currentUser;

  const IncidentDetailScreen({
    super.key,
    required this.incident,
    this.currentUser,
  });

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  late Incident _incident;
  AppUser? _currentUser;
  bool _hasConfirmed = false;
  bool _checkingConfirmation = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
    _currentUser = widget.currentUser;
    _initUserAndConfirmation();
  }

  Future<void> _initUserAndConfirmation() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      setState(() => _checkingConfirmation = false);
      return;
    }

    if (_currentUser == null) {
      try {
        final profileRow = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (profileRow != null && mounted) {
          setState(() {
            _currentUser = AppUser.fromMap(profileRow);
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;

    final confirmed = await context
        .read<IncidentProvider>()
        .hasUserConfirmed(incidentId: _incident.id, userId: userId);

    if (mounted) {
      setState(() {
        _hasConfirmed = confirmed;
        _checkingConfirmation = false;
      });
    }
  }

  Future<void> _openEditScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditIncidentScreen(incident: _incident),
      ),
    );

    if (result == true && mounted) {
      final updatedList = context.read<IncidentProvider>().incidents;
      final updated = updatedList.firstWhere(
        (i) => i.id == _incident.id,
        orElse: () => _incident,
      );
      setState(() {
        _incident = updated;
      });
    }
  }

  Future<void> _resolveMyIncident() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Incident as Resolved?'),
        content: const Text(
          'Have conditions on the ground cleared (e.g. flood water receded, road cleared)? Marking this report as resolved will inform the community that the hazard is no longer active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF546E7A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Resolved'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoading = true);
    final provider = context.read<IncidentProvider>();
    final success = await provider.resolveMyIncident(_incident.id);

    if (mounted) {
      setState(() {
        _actionLoading = false;
        if (success) {
          _incident = _incident.copyWith(status: IncidentStatus.resolved);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Incident marked as Resolved.' : (provider.errorMessage ?? 'Failed to resolve incident.'),
          ),
          backgroundColor: success ? const Color(0xFF546E7A) : AppColors.severityRed,
        ),
      );
    }
  }

  Future<void> _reopenMyIncident() async {
    setState(() => _actionLoading = true);
    final provider = context.read<IncidentProvider>();
    final success = await provider.reopenMyIncident(_incident.id);

    if (mounted) {
      setState(() {
        _actionLoading = false;
        if (success) {
          _incident = _incident.copyWith(status: IncidentStatus.pending);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Incident re-opened as active.' : (provider.errorMessage ?? 'Failed to update incident.'),
          ),
          backgroundColor: success ? AppColors.severityGreen : AppColors.severityRed,
        ),
      );
    }
  }

  Future<void> _confirmReport() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    setState(() => _actionLoading = true);

    try {
      await context.read<IncidentProvider>().confirmIncident(
            incidentId: _incident.id,
            memberId: userId,
          );

      if (mounted) {
        setState(() {
          _hasConfirmed = true;
          // Bump local score optimistically so the detail screen reflects the
          // change immediately, without waiting for the next full refresh.
          _incident = _incident.copyWith(
            credibilityScore: _incident.credibilityScore + 1,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report confirmed! Credibility score updated.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Postgres unique-constraint violation — the user already confirmed this.
      final isAlreadyConfirmed = e.toString().contains('23505');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAlreadyConfirmed
                ? "You've already confirmed this report \u2014 your vote is counted!"
                : 'Could not confirm report: $e',
          ),
          backgroundColor: isAlreadyConfirmed ? null : Colors.red,
        ),
      );
      if (isAlreadyConfirmed) setState(() => _hasConfirmed = true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }


  Future<void> _handleAdminAction(IncidentStatus targetStatus) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${targetStatus.label} Incident?'),
        content: Text(
          'Are you sure you want to change the incident status to "${targetStatus.label}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: StatusBadge.backgroundColor(targetStatus),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(targetStatus.label),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoading = true);
    final provider = context.read<IncidentProvider>();
    bool success = false;

    if (targetStatus == IncidentStatus.verified) {
      success = await provider.verifyIncident(_incident.id, userId);
    } else if (targetStatus == IncidentStatus.rejected) {
      success = await provider.rejectIncident(_incident.id, userId);
    } else if (targetStatus == IncidentStatus.resolved) {
      success = await provider.resolveIncident(_incident.id, userId);
    }

    if (mounted) {
      setState(() => _actionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incident status updated to ${targetStatus.label}.'),
            backgroundColor: StatusBadge.backgroundColor(targetStatus),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to update status.'),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteCitizenReport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.severityRed),
            SizedBox(width: 8),
            Text('Delete Incident Report?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your incident report? This action cannot be undone and will remove the report from the live incident map and community feeds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.severityRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Report'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoading = true);
    final provider = context.read<IncidentProvider>();
    final success = await provider.deleteIncident(_incident.id);

    if (mounted) {
      setState(() => _actionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your incident report has been deleted.'),
            backgroundColor: AppColors.severityGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to delete incident.'),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteAdminReport() async {
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
              Text('Moderate / Delete Report'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'As an administrator/moderator, deleting this incident permanently purges it from the map to keep community data trustworthy.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for deletion:',
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

    setState(() => _actionLoading = true);
    final provider = context.read<IncidentProvider>();
    final success = await provider.deleteIncident(_incident.id);

    if (mounted) {
      setState(() => _actionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incident removed as "$selectedReason".'),
            backgroundColor: AppColors.severityRed,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to delete incident.'),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthority = _currentUser?.role.isAuthority ?? widget.currentUser?.role.isAuthority ?? false;
    final isReporter = widget.incident.reporterId == SupabaseService.currentUserId;
    final color = categoryColor(_incident.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        elevation: 0,
        actions: [
          if (isReporter) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Incident',
              onPressed: _openEditScreen,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.severityRed),
              tooltip: 'Delete Incident',
              onPressed: _actionLoading ? null : _deleteCitizenReport,
            ),
          ] else if (isAuthority) ...[
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined, color: AppColors.severityRed),
              tooltip: 'Delete as Spam / False',
              onPressed: _actionLoading ? null : _deleteAdminReport,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StatusBadge(status: _incident.status),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── SOS Critical Banner ───────────────────────────────────────
          if (_incident.isSos) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.severityRed.withValues(alpha: 0.2)
                    : AppColors.sosBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.severityRed),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.severityRed, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'HIGH PRIORITY: Trapped / Emergency SOS Report',
                      style: TextStyle(
                        color: AppColors.severityRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── Header Card: Category & Timestamp ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.harborSurface : AppColors.cloud,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.deepEstuary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon(_incident.category), color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _incident.category.label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reported ${_timeAgo(_incident.createdAt)} (${_formatDate(_incident.createdAt)})',
                        style: AppTheme.dataText(context).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Description Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.harborSurface : AppColors.cloud,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.deepEstuary.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _incident.description?.isNotEmpty == true
                      ? _incident.description!
                      : 'No description provided by the reporter.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Evidence: Photo & Video ───────────────────────────────────
          if (_incident.photoUrl != null || _incident.videoUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.harborSurface : AppColors.cloud,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.deepEstuary.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Evidence & Media',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  if (_incident.photoUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _incident.photoUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (ctx, err, st) => Container(
                          height: 100,
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Center(child: Text('Photo could not be loaded')),
                        ),
                      ),
                    ),
                  ],
                  if (_incident.videoUrl != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.seafoam.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.videocam, color: AppColors.deepEstuary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Video Evidence Attached',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Icon(Icons.open_in_new, size: 18, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── Location & Map ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.harborSurface : AppColors.cloud,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.deepEstuary.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${_incident.latitude.toStringAsFixed(4)}, ${_incident.longitude.toStringAsFixed(4)}',
                      style: AppTheme.dataText(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 160,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_incident.latitude, _incident.longitude),
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      ),
                      children: [
                        buildBaseTileLayer(BaseMapStyle.street),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_incident.latitude, _incident.longitude),
                              width: 36,
                              height: 36,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                  ],
                                ),
                                child: Icon(categoryIcon(_incident.category), color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Credibility & Community Confirmation ──────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.harborSurface : AppColors.cloud,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.deepEstuary.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 20, color: AppColors.deepEstuary),
                    const SizedBox(width: 8),
                    const Text(
                      'Community Credibility',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.deepEstuary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_incident.credibilityScore} Confirmations',
                        style: AppTheme.dataText(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepEstuary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Community members confirm if this incident is accurate and active.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (!isReporter) ...[
                  if (_checkingConfirmation)
                    const Center(child: CircularProgressIndicator())
                  else if (_hasConfirmed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.severityGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: AppColors.severityGreen, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'You confirmed this report',
                            style: TextStyle(
                              color: AppColors.severityGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.thumb_up_outlined, size: 18),
                        label: const Text('Confirm this Incident Report'),
                        onPressed: _actionLoading ? null : _confirmReport,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Citizen Reporter Controls ─────────────────────────────────
          if (isReporter) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.harborSurface : AppColors.cloud,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.deepEstuary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_circle_outlined, color: AppColors.deepEstuary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Your Incident Report Controls',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.deepEstuary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Reporter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepEstuary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _incident.status == IncidentStatus.resolved
                        ? 'You have marked this incident as resolved. If conditions change or flood hazards re-occur, you can edit or re-open it.'
                        : 'As the citizen reporter, you can update details as weather and flood conditions change, or mark this incident as resolved.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Details'),
                          onPressed: _actionLoading ? null : _openEditScreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _incident.status == IncidentStatus.resolved
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.severityGreen,
                                ),
                                icon: const Icon(Icons.replay, size: 18),
                                label: const Text('Reopen Incident'),
                                onPressed: _actionLoading ? null : _reopenMyIncident,
                              )
                            : FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF546E7A),
                                ),
                                icon: const Icon(Icons.task_alt, size: 18),
                                label: const Text('Mark Resolved'),
                                onPressed: _actionLoading ? null : _resolveMyIncident,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.severityRed,
                        side: BorderSide(color: AppColors.severityRed.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete This Incident Report'),
                      onPressed: _actionLoading ? null : _deleteCitizenReport,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── Authority / Admin Review Actions ──────────────────────────
          if (isAuthority) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.harborSurface : AppColors.cloud,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.riverTeal.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined, color: AppColors.riverTeal, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Authority Verification & Moderation',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_incident.status == IncidentStatus.pending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.severityGreen,
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Verify Report'),
                            onPressed: _actionLoading
                                ? null
                                : () => _handleAdminAction(IncidentStatus.verified),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.severityRed,
                            ),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject Report'),
                            onPressed: _actionLoading
                                ? null
                                : () => _handleAdminAction(IncidentStatus.rejected),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_incident.status == IncidentStatus.verified) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF546E7A),
                        ),
                        icon: const Icon(Icons.task_alt, size: 18),
                        label: const Text('Mark Incident as Resolved'),
                        onPressed: _actionLoading
                            ? null
                            : () => _handleAdminAction(IncidentStatus.resolved),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'This incident is currently ${_incident.status.label.toLowerCase()}.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.severityRed,
                        side: BorderSide(color: AppColors.severityRed.withValues(alpha: 0.6)),
                      ),
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: const Text('Delete as Spam, Duplicate or False'),
                      onPressed: _actionLoading ? null : _deleteAdminReport,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
