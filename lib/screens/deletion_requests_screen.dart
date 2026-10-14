import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/account_deletion_service.dart';
import '../theme/app_colors.dart';

/// Authority view of open account-deletion requests. "Delete account" runs
/// the process-account-deletion Edge Function; the row only disappears once
/// the server confirms the deletion completed.
class DeletionRequestsScreen extends StatefulWidget {
  final AccountDeletionService? service;
  const DeletionRequestsScreen({super.key, this.service});

  @override
  State<DeletionRequestsScreen> createState() => _DeletionRequestsScreenState();
}

class _DeletionRequestsScreenState extends State<DeletionRequestsScreen> {
  late final AccountDeletionService _service = widget.service ?? AccountDeletionService();
  late Future<List<OpenDeletionRequest>> _requests = _service.listOpen();
  final Set<String> _processing = {};

  void _reload() => setState(() => _requests = _service.listOpen());

  Future<void> _process(OpenDeletionRequest r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${r.name}\'s account?'),
        content: const Text(
          'This permanently deletes their account, profile, incident reports '
          'and uploaded media, messages they sent, feedback, family links and '
          'location history. Records other people rely on (alerts, verified '
          'incidents, shelters) are kept without their name. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.severityRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing.add(r.id));
    try {
      await _service.process(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r.name}\'s account was deleted.')),
      );
      _reload();
    } on DeletionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t reach the server. Nothing was deleted; try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deletion requests'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<OpenDeletionRequest>>(
        future: _requests,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Couldn\'t load deletion requests.'),
                    TextButton(onPressed: _reload, child: const Text('Try again')),
                  ],
                ),
              ),
            );
          }
          final requests = snap.data ?? const [];
          if (requests.isEmpty) {
            return const Center(child: Text('No open deletion requests.'));
          }
          return ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = requests[i];
              final busy = _processing.contains(r.id);
              final when = r.requestedAt == null ? '' : DateFormat.yMMMd().add_jm().format(r.requestedAt!);
              return ListTile(
                title: Text(r.name),
                subtitle: Text([
                  'Requested $when',
                  if (r.status == DeletionStatus.processing) 'Processing — a previous attempt stopped part-way',
                  if (r.reason != null && r.reason!.isNotEmpty) 'Reason: ${r.reason}',
                ].join('\n')),
                isThreeLine: r.reason != null || r.status == DeletionStatus.processing,
                trailing: busy
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: () => _process(r),
                        style: TextButton.styleFrom(foregroundColor: AppColors.severityRed),
                        child: const Text('Delete'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
