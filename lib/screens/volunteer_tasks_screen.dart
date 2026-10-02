import 'package:flutter/material.dart';

import '../models/shelter.dart';
import '../models/volunteer_task.dart';
import '../models/zone.dart';
import '../services/profile_service.dart';
import '../services/shelter_service.dart';
import '../services/supabase_service.dart';
import '../services/volunteer_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

/// Volunteer opportunities from `volunteer_tasks`. Citizens sign up or
/// withdraw; authorities and volunteer organisations also post new tasks
/// and move them through open → in progress → completed/cancelled.
class VolunteerTasksScreen extends StatefulWidget {
  /// Limits the list to one shelter's tasks (opened from its Shelter page).
  final String? shelterId;
  final String? shelterName;

  /// Offered as an optional target area when posting a task.
  final List<Zone> zones;

  const VolunteerTasksScreen({
    super.key,
    this.shelterId,
    this.shelterName,
    this.zones = const [],
  });

  @override
  State<VolunteerTasksScreen> createState() => _VolunteerTasksScreenState();
}

class _VolunteerTasksScreenState extends State<VolunteerTasksScreen> {
  final VolunteerService _service = VolunteerService();
  final String? _me = SupabaseService.currentUserId;

  List<VolunteerTask>? _tasks;
  List<Shelter> _shelters = [];
  bool _canManage = false;
  bool _failed = false;
  VolunteerTaskStatus? _statusFilter = VolunteerTaskStatus.open;
  final Set<String> _busyTaskIds = {};

  @override
  void initState() {
    super.initState();
    ProfileService.currentUserRole().then((role) {
      if (mounted) setState(() => _canManage = role?.isAuthority ?? false);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.fetchTasks(shelterId: widget.shelterId),
        ShelterService().fetchShelters(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<VolunteerTask>;
        _shelters = results[1] as List<Shelter>;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String? _shelterNameFor(String? id) =>
      _shelters.where((s) => s.id == id).firstOrNull?.name;

  Future<void> _run(String taskId, Future<void> Function() action, String doneMessage) async {
    setState(() => _busyTaskIds.add(taskId));
    try {
      await action();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is StateError ? e.message : 'Couldn\'t update the task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyTaskIds.remove(taskId));
    }
  }

  Future<void> _showCreateSheet() async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final neededCtrl = TextEditingController(text: '5');
    String? shelterId = widget.shelterId;
    String? zoneId;
    bool saving = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New volunteer task',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Title', hintText: 'Distribute food packs'),
                    validator: (v) => (v ?? '').trim().length < 3 ? 'Give the task a short title' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'What volunteers will do (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: shelterId,
                    decoration: const InputDecoration(labelText: 'Shelter (optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No specific shelter')),
                      for (final s in _shelters) DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setSheetState(() => shelterId = v),
                  ),
                  if (widget.zones.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: zoneId,
                      decoration: const InputDecoration(labelText: 'Zone (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Any zone')),
                        for (final z in widget.zones) DropdownMenuItem(value: z.id, child: Text(z.name)),
                      ],
                      onChanged: (v) => setSheetState(() => zoneId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: neededCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Volunteers needed'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return 'At least 1';
                      if (n > 500) return 'That\'s a lot — max 500';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) return;
                            setSheetState(() => saving = true);
                            try {
                              await _service.createTask(
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                shelterId: shelterId,
                                zoneId: zoneId,
                                volunteersNeeded: int.parse(neededCtrl.text.trim()),
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheetState(() => saving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Couldn\'t post the task: $e')),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Post task'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (created == true) {
      setState(() => _statusFilter = VolunteerTaskStatus.open);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final visible = tasks?.where((t) => _statusFilter == null || t.status == _statusFilter).toList();

    Widget body;
    if (_failed) {
      body = const Center(child: Text('Couldn\'t load volunteer tasks.'));
    } else if (visible == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (visible.isEmpty) {
      body = ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Text(
              _statusFilter == VolunteerTaskStatus.open
                  ? 'No open volunteer tasks right now.'
                  : 'Nothing here.',
            ),
          ),
        ],
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _TaskCard(
          task: visible[i],
          shelterName: _shelterNameFor(visible[i].shelterId),
          me: _me,
          canManage: _canManage,
          busy: _busyTaskIds.contains(visible[i].id),
          onSignUp: () => _run(visible[i].id, () => _service.signUp(visible[i].id),
              'You\'re signed up. Thank you for helping!'),
          onWithdraw: () => _run(visible[i].id, () => _service.withdraw(visible[i].id),
              'You\'ve withdrawn from this task.'),
          onStatusChange: (status) => _run(visible[i].id,
              () => _service.updateStatus(visible[i].id, status), 'Task marked ${status.label.toLowerCase()}.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shelterName == null ? 'Volunteer' : 'Volunteer · ${widget.shelterName}'),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _showCreateSheet,
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            )
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final status in [null, ...VolunteerTaskStatus.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status?.label ?? 'All'),
                      selected: _statusFilter == status,
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: RefreshIndicator(onRefresh: _load, child: body)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final VolunteerTask task;
  final String? shelterName;
  final String? me;
  final bool canManage;
  final bool busy;
  final VoidCallback onSignUp;
  final VoidCallback onWithdraw;
  final ValueChanged<VolunteerTaskStatus> onStatusChange;

  const _TaskCard({
    required this.task,
    required this.shelterName,
    required this.me,
    required this.canManage,
    required this.busy,
    required this.onSignUp,
    required this.onWithdraw,
    required this.onStatusChange,
  });

  Color get _statusColor => switch (task.status) {
        VolunteerTaskStatus.open => AppColors.severityGreen,
        VolunteerTaskStatus.inProgress => AppColors.riverTeal,
        VolunteerTaskStatus.completed => AppColors.slateMuted,
        VolunteerTaskStatus.cancelled => AppColors.severityRed,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final signedUp = task.isSignedUp(me);
    final fraction = (task.signedUpCount / task.volunteersNeeded).clamp(0.0, 1.0);

    Widget action;
    if (busy) {
      action = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (signedUp) {
      action = OutlinedButton(onPressed: onWithdraw, child: const Text('Withdraw'));
    } else if (task.status != VolunteerTaskStatus.open) {
      action = const SizedBox.shrink();
    } else if (task.isFull) {
      action = const OutlinedButton(onPressed: null, child: Text('Full'));
    } else {
      action = FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: onSignUp,
        child: const Text('Sign up'),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(task.title, style: textTheme.titleMedium)),
                if (canManage)
                  PopupMenuButton<VolunteerTaskStatus>(
                    tooltip: 'Change status',
                    onSelected: onStatusChange,
                    itemBuilder: (_) => [
                      for (final s in VolunteerTaskStatus.values)
                        if (s != task.status)
                          PopupMenuItem(value: s, child: Text('Mark ${s.label.toLowerCase()}')),
                    ],
                    child: _StatusChip(label: task.status.label, color: _statusColor, editable: true),
                  )
                else
                  _StatusChip(label: task.status.label, color: _statusColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [shelterName, 'Posted ${timeAgo(task.createdAt)}'].whereType<String>().join(' · '),
              style: textTheme.bodySmall,
            ),
            if (task.description != null && task.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(task.description!, style: textTheme.bodyMedium),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task.signedUpCount} of ${task.volunteersNeeded} volunteers'
                        '${signedUp ? ' · including you' : ''}',
                        style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          color: AppColors.riverTeal,
                          backgroundColor: AppColors.riverTeal.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                action,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool editable;

  const _StatusChip({required this.label, required this.color, this.editable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          if (editable) Icon(Icons.arrow_drop_down, size: 16, color: color),
        ],
      ),
    );
  }
}
