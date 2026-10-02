import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_user.dart';
import '../../../models/zone.dart';
import '../models/preparedness_reminder.dart';
import '../providers/preparedness_provider.dart';

class ManageRemindersScreen extends StatelessWidget {
  const ManageRemindersScreen({
    super.key,
    required this.currentUser,
    required this.zones,
  });

  final AppUser? currentUser;
  final List<Zone> zones;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreparednessProvider>();
    if (currentUser?.role.isAuthority != true) {
      return const _AccessDeniedView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manage reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('New reminder'),
      ),
      body: provider.reminders.isEmpty
          ? const Center(child: Text('No reminders created yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.reminders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final reminder = provider.reminders[index];
                return Card(
                  child: ListTile(
                    title: Text(reminder.title),
                    subtitle: Text(
                      '${reminder.message}\n${reminder.recurrence.label} • ${reminder.zoneTags.isEmpty ? 'All zones' : reminder.zoneTags.join(', ')}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') await _edit(context, reminder);
                        if (value == 'delete')
                          await provider.deleteReminder(reminder.id);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => _edit(context, reminder),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
    BuildContext context, [
    PreparednessReminder? reminder,
  ]) async {
    final provider = context.read<PreparednessProvider>();
    final result = await showModalBottomSheet<PreparednessReminder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderEditor(reminder: reminder, zones: zones),
    );
    if (!context.mounted || result == null) return;
    await provider.saveReminder(result);
  }
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({this.reminder, required this.zones});

  final PreparednessReminder? reminder;
  final List<Zone> zones;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late final TextEditingController _title;
  late final TextEditingController _message;
  late DateTime _scheduledDate;
  late ReminderRecurrence _recurrence;
  late Set<String> _zoneTags;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.reminder?.title);
    _message = TextEditingController(text: widget.reminder?.message);
    _scheduledDate =
        widget.reminder?.scheduledDate ??
        DateTime.now().add(const Duration(days: 7));
    _recurrence = widget.reminder?.recurrence ?? ReminderRecurrence.none;
    _zoneTags = {...?widget.reminder?.zoneTags};
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.reminder == null ? 'Create reminder' : 'Edit reminder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _scheduledDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _scheduledDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Scheduled date'),
                child: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatShortDate(_scheduledDate),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ReminderRecurrence>(
              value: _recurrence,
              decoration: const InputDecoration(labelText: 'Recurrence'),
              items: ReminderRecurrence.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _recurrence = value ?? ReminderRecurrence.none,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Zone tags'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All zones'),
                  selected: _zoneTags.isEmpty,
                  onSelected: (_) => setState(() => _zoneTags.clear()),
                ),
                ...widget.zones.map(
                  (zone) => FilterChip(
                    label: Text(zone.name),
                    selected: _zoneTags.contains(zone.id),
                    onSelected: (_) => setState(() {
                      if (_zoneTags.contains(zone.id)) {
                        _zoneTags.remove(zone.id);
                      } else {
                        _zoneTags.add(zone.id);
                      }
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _title.text.trim().isEmpty || _message.text.trim().isEmpty
                    ? null
                    : () {
                        final now = DateTime.now();
                        Navigator.pop(
                          context,
                          PreparednessReminder(
                            id:
                                widget.reminder?.id ??
                                'reminder-${now.microsecondsSinceEpoch}',
                            title: _title.text.trim(),
                            message: _message.text.trim(),
                            scheduledDate: _scheduledDate,
                            recurrence: _recurrence,
                            zoneTags: _zoneTags.toList(),
                          ),
                        );
                      },
                child: const Text('Save reminder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedView extends StatelessWidget {
  const _AccessDeniedView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Access denied')),
    body: const Center(
      child: Text('Only authority accounts can manage reminders.'),
    ),
  );
}
