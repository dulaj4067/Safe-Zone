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
import '../l10n/ui_text.dart';
import '../utils/error_messages.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(doneMessage))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(e is StateError ? e.message : friendlyError(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyTaskIds.remove(taskId));
    }
  }

  /// Posts a new task, or edits [editing] when given. Same sheet for both.
  Future<void> _showTaskSheet({VolunteerTask? editing}) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: editing?.title);
    final descCtrl = TextEditingController(text: editing?.description);
    final neededCtrl = TextEditingController(text: '${editing?.volunteersNeeded ?? 5}');
    String? shelterId = editing != null ? editing.shelterId : widget.shelterId;
    String? zoneId = editing?.zoneId;
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
                  Text(editing == null ? 'New volunteer task' : 'Edit volunteer task',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleCtrl,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: context.tr('Title'), hintText: context.tr('Distribute food packs')),
                    validator: (v) =>
                        (v ?? '').trim().length < 3 ? context.tr('Give the task a short title') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: context.tr('What volunteers will do (optional)')),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: shelterId,
                    decoration: InputDecoration(labelText: context.tr('Shelter (optional)')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(context.tr('No specific shelter'))),
                      for (final s in _shelters) DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setSheetState(() => shelterId = v),
                  ),
                  if (widget.zones.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: zoneId,
                      decoration: InputDecoration(labelText: context.tr('Zone (optional)')),
                      items: [
                        DropdownMenuItem(value: null, child: Text(context.tr('Any zone'))),
                        for (final z in widget.zones) DropdownMenuItem(value: z.id, child: Text(z.name)),
                      ],
                      onChanged: (v) => setSheetState(() => zoneId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: neededCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: context.tr('Volunteers needed')),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return context.tr('At least 1');
                      if (n > 500) return context.tr('That is a lot. The maximum is 500.');
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
                              final description =
                                  descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
                              final needed = int.parse(neededCtrl.text.trim());
                              if (editing == null) {
                                await _service.createTask(
                                  title: titleCtrl.text.trim(),
                                  description: description,
                                  shelterId: shelterId,
                                  zoneId: zoneId,
                                  volunteersNeeded: needed,
                                );
                              } else {
                                await _service.updateTask(
                                  editing.id,
                                  title: titleCtrl.text.trim(),
                                  description: description,
                                  shelterId: shelterId,
                                  zoneId: zoneId,
                                  volunteersNeeded: needed,
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheetState(() => saving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(e is StateError
                                        ? e.message
                                        : 'Couldn\'t save the task: $e'),
                                  ),
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
                        : Text(editing == null ? 'Post task' : 'Save changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (created == true) {
      if (editing == null) setState(() => _statusFilter = VolunteerTaskStatus.open);
      _load();
    }
  }

  /// Asks before an irreversible action; returns true when confirmed.
  Future<bool> _confirm(String title, String message, String action,
      {bool destructive = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.severityRed)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final visible = tasks?.where((t) => _statusFilter == null || t.status == _statusFilter).toList();

    Widget body;
    if (_failed) {
      body = Center(child: Text(context.tr('Couldn\'t load volunteer tasks.')));
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
          onWithdraw: () async {
            // Volunteers leave on their own; just make sure it was on purpose.
            final task = visible[i];
            if (!await _confirm('Withdraw from this task?',
                'Your spot on "${task.title}" will be freed for someone else.', 'Withdraw')) {
              return;
            }
            await _run(task.id, () => _service.withdraw(task.id), 'You\'ve withdrawn from this task.');
          },
          onEdit: () => _showTaskSheet(editing: visible[i]),
          onDelete: () async {
            final task = visible[i];
            final signedUp = task.signedUpCount;
            if (!await _confirm(
              'Delete this task?',
              signedUp > 0
                  ? '"${task.title}" and the $signedUp volunteer sign-up${signedUp == 1 ? '' : 's'} on it will be removed.'
                  : '"${task.title}" will be removed.',
              'Delete',
              destructive: true,
            )) {
              return;
            }
            await _run(task.id, () => _service.deleteTask(task.id), 'Task deleted.');
          },
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
              onPressed: _showTaskSheet,
              icon: const Icon(Icons.add),
              label: Text(context.tr('New task')),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<VolunteerTaskStatus> onStatusChange;

  const _TaskCard({
    required this.task,
    required this.shelterName,
    required this.me,
    required this.canManage,
    required this.busy,
    required this.onSignUp,
    required this.onWithdraw,
    required this.onEdit,
    required this.onDelete,
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
      action = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: onWithdraw,
        child: Text(context.tr('Withdraw')),
      );
    } else if (task.status != VolunteerTaskStatus.open) {
      action = const SizedBox.shrink();
    } else if (task.isFull) {
      action = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: null,
        child: Text(context.tr('Full')),
      );
    } else {
      action = FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: onSignUp,
        child: Text(context.tr('Sign up')),
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
                    tooltip: context.tr('Change status'),
                    onSelected: onStatusChange,
                    itemBuilder: (_) => [
                      for (final s in VolunteerTaskStatus.values)
                        if (s != task.status)
                          PopupMenuItem(value: s, child: Text(context.tr('Mark {p0}', {'p0': s.label.toLowerCase()}))),
                    ],
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        widthFactor: 1,
                        child: _StatusChip(label: task.status.label, color: _statusColor, editable: true),
                      ),
                    ),
                  )
                else
                  _StatusChip(label: task.status.label, color: _statusColor),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: context.tr('Task options'),
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text(context.tr('Edit task')),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: AppColors.severityRed),
                          title: Text(context.tr('Delete task')),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
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
                          color: context.brandAccent,
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
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ink text keeps >= 4.5:1 on the tint in both themes; the status
          // colour stays in the border and arrow.
          Text(label,
              style: TextStyle(color: context.inkStrong, fontSize: 12, fontWeight: FontWeight.w700)),
          if (editable) Icon(Icons.arrow_drop_down, size: 16, color: color),
        ],
      ),
    );
  }
}
