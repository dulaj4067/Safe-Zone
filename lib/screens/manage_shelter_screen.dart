import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/shelter.dart';
import '../services/shelter_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'messages_screen.dart';
import 'shelter_detail_screen.dart';
import 'shelter_form_screen.dart';

/// "Manage your shelter": the shelters the signed-in user has submitted or
/// runs, with where each one is in the review process.
///
/// - Pending: awaiting an authority; can be edited or withdrawn.
/// - Rejected: shows the reason; fix and resubmit, or withdraw.
/// - Approved: live on the public page; open it to manage supplies, details,
///   volunteer needs and messages from the normal shelter page.
class ManageShelterScreen extends StatefulWidget {
  final AppUser? currentUser;

  const ManageShelterScreen({super.key, this.currentUser});

  @override
  State<ManageShelterScreen> createState() => _ManageShelterScreenState();
}

class _ManageShelterScreenState extends State<ManageShelterScreen> {
  final ShelterService _service = ShelterService();
  List<Shelter>? _shelters;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shelters = await _service.fetchMyShelters();
      if (!mounted) return;
      setState(() {
        _shelters = shelters;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openForm([Shelter? shelter]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ShelterFormScreen(shelter: shelter)),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shelter == null
                ? 'Submitted. An authority will review it shortly.'
                : 'Saved.'),
          ),
        );
      }
    }
  }

  Future<void> _withdraw(Shelter shelter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw this submission?'),
        content: Text('"${shelter.name}" will be removed. You can submit it again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.withdrawSubmission(shelter.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is StateError ? e.message : 'Couldn\'t withdraw it: $e')),
      );
    }
  }

  void _openShelter(Shelter shelter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShelterDetailScreen(shelter: shelter, currentUser: widget.currentUser),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final shelters = _shelters;

    Widget body;
    if (_failed) {
      body = ListView(children: const [
        SizedBox(height: 120),
        Center(child: Text('Couldn\'t load your shelters. Pull to retry.')),
      ]);
    } else if (shelters == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (shelters.isEmpty) {
      body = ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.night_shelter_outlined, size: 56, color: context.inkMuted),
          const SizedBox(height: 16),
          Text(
            'You haven\'t submitted a shelter yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Run a shelter, relief camp or medical point? Submit it here. Once an '
            'authority has verified it, it appears on the Shelters page and you can '
            'manage its supplies, details and messages.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.inkMuted),
          ),
        ],
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: shelters.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _MyShelterCard(
          shelter: shelters[i],
          onOpen: () => _openShelter(shelters[i]),
          onEdit: () => _openForm(shelters[i]),
          onWithdraw: () => _withdraw(shelters[i]),
          onMessages: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessagesScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manage your shelter')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text('Submit a shelter'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}

class _MyShelterCard extends StatelessWidget {
  final Shelter shelter;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onWithdraw;
  final VoidCallback onMessages;

  const _MyShelterCard({
    required this.shelter,
    required this.onOpen,
    required this.onEdit,
    required this.onWithdraw,
    required this.onMessages,
  });

  Color get _color => switch (shelter.approval) {
        ShelterApproval.approved => AppColors.severityGreen,
        ShelterApproval.pending => AppColors.severityOrange,
        ShelterApproval.rejected => AppColors.severityRed,
      };

  IconData get _icon => switch (shelter.approval) {
        ShelterApproval.approved => Icons.check_circle,
        ShelterApproval.pending => Icons.hourglass_top,
        ShelterApproval.rejected => Icons.cancel,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final approved = shelter.approval == ShelterApproval.approved;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(shelter.name, style: textTheme.titleMedium)),
                const SizedBox(width: 8),
                // Icon and words, not colour alone.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon, size: 14, color: _color),
                      const SizedBox(width: 4),
                      Text(
                        shelter.approval.label,
                        style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                shelter.typeLabel,
                if (shelter.capacity != null) 'Capacity ${shelter.capacity}',
                if (shelter.updatedAt != null) 'Updated ${timeAgo(shelter.updatedAt!)}',
              ].join(' · '),
              style: textTheme.bodySmall,
            ),
            if (shelter.approval == ShelterApproval.rejected &&
                (shelter.rejectionReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.severityRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Reason: ${shelter.rejectionReason}'),
              ),
            ],
            if (shelter.approval == ShelterApproval.pending) ...[
              const SizedBox(height: 10),
              Text(
                'An authority is verifying this shelter. It is not on the public page yet.',
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (approved) ...[
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Manage'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit details'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onMessages,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Messages'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(
                      shelter.approval == ShelterApproval.rejected ? 'Fix and resubmit' : 'Edit',
                    ),
                  ),
                  TextButton(onPressed: onWithdraw, child: const Text('Withdraw')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
