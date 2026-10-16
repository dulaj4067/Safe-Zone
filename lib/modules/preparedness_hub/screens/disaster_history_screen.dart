import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_user.dart';
import '../../../models/zone.dart';
import '../models/disaster_history_record.dart';
import '../providers/preparedness_provider.dart';
import '../../../l10n/ui_text.dart';

class DisasterHistoryScreen extends StatefulWidget {
  const DisasterHistoryScreen({
    super.key,
    required this.zoneId,
    required this.currentUser,
    required this.zones,
  });

  final String zoneId;
  final AppUser? currentUser;
  final List<Zone> zones;

  @override
  State<DisasterHistoryScreen> createState() => _DisasterHistoryScreenState();
}

class _DisasterHistoryScreenState extends State<DisasterHistoryScreen> {
  late Future<List<DisasterHistoryRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = context.read<PreparednessProvider>().historyForZone(
      widget.zoneId,
    );
  }

  Future<void> _addRecord() async {
    final record = await showModalBottomSheet<DisasterHistoryRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DisasterHistoryEditor(zones: widget.zones),
    );
    if (record == null || !mounted) return;

    try {
      await context.read<PreparednessProvider>().saveHistoryRecord(record);
      if (!mounted) return;
      setState(() {
        _records = context.read<PreparednessProvider>().historyForZone(
          widget.zoneId,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disaster history record saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the record: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageHistory = widget.currentUser?.role.isAuthority == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Disaster history')),
      floatingActionButton: canManageHistory && widget.zones.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _addRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add record'),
            )
          : null,
      body: FutureBuilder<List<DisasterHistoryRecord>>(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load disaster history.'),
            );
          }
          final records = [...?snapshot.data]
            ..sort((a, b) => b.date.compareTo(a.date));
          if (records.isEmpty) {
            return const Center(
              child: Text('No past events are recorded for this zone.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: Text(record.disasterType),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(record.date)}  -  ${record.severity} severity',
                        ),
                        const SizedBox(height: 6),
                        Text(record.summary),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DisasterHistoryEditor extends StatefulWidget {
  const _DisasterHistoryEditor({required this.zones});

  final List<Zone> zones;

  @override
  State<_DisasterHistoryEditor> createState() => _DisasterHistoryEditorState();
}

class _DisasterHistoryEditorState extends State<_DisasterHistoryEditor> {
  final _formKey = GlobalKey<FormState>();
  final _disasterType = TextEditingController();
  final _summary = TextEditingController();
  late String? _zoneId;
  DateTime _date = DateTime.now();
  String _severity = 'moderate';

  @override
  void initState() {
    super.initState();
    _zoneId = widget.zones.first.id;
  }

  @override
  void dispose() {
    _disasterType.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add disaster history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _zoneId,
              decoration: const InputDecoration(labelText: 'Zone'),
              items: widget.zones
                  .map(
                    (zone) => DropdownMenuItem(
                      value: zone.id,
                      child: Text(zone.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _zoneId = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _disasterType,
              decoration: const InputDecoration(labelText: 'Disaster type'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a disaster type.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'severe', child: Text('Severe')),
              ],
              onChanged: (value) =>
                  setState(() => _severity = value ?? 'moderate'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summary,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Summary',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a summary.'
                  : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(
                  MaterialLocalizations.of(context).formatShortDate(_date),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate() || _zoneId == null) {
                    return;
                  }
                  Navigator.pop(
                    context,
                    DisasterHistoryRecord(
                      id: 'history-${DateTime.now().microsecondsSinceEpoch}',
                      zoneId: _zoneId!,
                      disasterType: _disasterType.text.trim(),
                      date: _date,
                      severity: _severity,
                      summary: _summary.text.trim(),
                    ),
                  );
                },
                child: const Text('Save record'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
