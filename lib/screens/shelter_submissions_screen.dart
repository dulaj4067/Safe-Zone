import 'package:flutter/material.dart';

import '../models/shelter.dart';
import '../services/profile_service.dart';
import '../services/shelter_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

/// Authority view of shelters waiting for verification. Each submission
/// shows what the citizen entered so it can be checked, then is approved
/// (goes public, the submitter becomes its manager) or rejected with a
/// reason the submitter sees.
class ShelterSubmissionsScreen extends StatefulWidget {
  const ShelterSubmissionsScreen({super.key});

  @override
  State<ShelterSubmissionsScreen> createState() => _ShelterSubmissionsScreenState();
}

class _ShelterSubmissionsScreenState extends State<ShelterSubmissionsScreen> {
  final ShelterService _service = ShelterService();
  List<Shelter>? _pending;
  Map<String, String> _names = {};
  bool _failed = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pending = await _service.fetchPendingShelters();
      final names = await ProfileService.fetchNames(
        pending.map((s) => s.submittedBy).whereType<String>(),
      );
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _names = names;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _decide(Shelter shelter, {required bool approve}) async {
    String? reason;
    if (!approve) {
      reason = await _askReason(shelter);
      if (reason == null) return;
    }
    setState(() => _busy.add(shelter.id));
    try {
      if (approve) {
        await _service.approveShelter(shelter.id);
      } else {
        await _service.rejectShelter(shelter.id, reason!);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? '"${shelter.name}" approved.' : '"${shelter.name}" rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is StateError ? e.message : 'Couldn\'t save the decision: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(shelter.id));
    }
  }

  Future<String?> _askReason(Shelter shelter) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject "${shelter.name}"?'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason (shown to the submitter)',
            ),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Give a short reason' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.severityRed),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;

    Widget body;
    if (_failed) {
      body = ListView(children: const [
        SizedBox(height: 120),
        Center(child: Text('Couldn\'t load submissions. Pull to retry.')),
      ]);
    } else if (pending == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (pending.isEmpty) {
      body = ListView(children: const [
        SizedBox(height: 120),
        Center(child: Text('No shelters are waiting for review.')),
      ]);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: pending.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final s = pending[i];
          final busy = _busy.contains(s.id);
          final textTheme = Theme.of(context).textTheme;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    [
                      s.typeLabel,
                      if (s.capacity != null) 'Capacity ${s.capacity}',
                      if (s.updatedAt != null) 'Submitted ${timeAgo(s.updatedAt!)}',
                    ].join(' · '),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  _Line(Icons.person_outline, 'By ${_names[s.submittedBy] ?? 'Unknown'}'),
                  if ((s.address ?? '').isNotEmpty) _Line(Icons.home_outlined, s.address!),
                  _Line(
                    Icons.place_outlined,
                    '${s.latitude.toStringAsFixed(5)}, ${s.longitude.toStringAsFixed(5)}',
                  ),
                  if ((s.contactPhone ?? '').isNotEmpty) _Line(Icons.phone_outlined, s.contactPhone!),
                  if ((s.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(s.description!, style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 14),
                  if (busy)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.severityRed,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: () => _decide(s, approve: false),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            onPressed: () => _decide(s, approve: true),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shelter submissions')),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Line(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.inkMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
