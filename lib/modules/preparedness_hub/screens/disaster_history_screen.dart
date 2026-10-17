import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/app_user.dart';
import '../../../models/zone.dart';
import '../models/disaster_history_record.dart';
import '../providers/preparedness_provider.dart';

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
  late bool _showCountryHistory;

  @override
  void initState() {
    super.initState();
    _showCountryHistory = widget.zoneId.isEmpty;
    _records = _loadRecords();
  }

  Future<List<DisasterHistoryRecord>> _loadRecords() {
    final provider = context.read<PreparednessProvider>();
    return _showCountryHistory
        ? provider.countryHistory()
        : provider.historyForZone(widget.zoneId);
  }

  void _changeHistoryScope(bool showCountryHistory) {
    setState(() {
      _showCountryHistory = showCountryHistory;
      _records = _loadRecords();
    });
  }

  Future<void> _addRecord() async {
    final record = await showModalBottomSheet<DisasterHistoryRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DisasterHistoryEditor(
        zones: widget.zones,
        initialZoneId: _showCountryHistory ? null : widget.zoneId,
      ),
    );
    if (record == null || !mounted) return;

    try {
      await context.read<PreparednessProvider>().saveHistoryRecord(record);
      if (!mounted) return;
      setState(() {
        _records = _loadRecords();
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
      floatingActionButton: canManageHistory
          ? FloatingActionButton.extended(
              onPressed: _addRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add record'),
            )
          : null,
      body: Column(
        children: [
          if (widget.zoneId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.location_on_outlined),
                    label: Text('My district'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.public),
                    label: Text('All Sri Lanka'),
                  ),
                ],
                selected: {_showCountryHistory},
                onSelectionChanged: (selection) =>
                    _changeHistoryScope(selection.first),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<DisasterHistoryRecord>>(
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
                  return Center(
                    child: Text(
                      _showCountryHistory
                          ? 'No past events are recorded for Sri Lanka.'
                          : 'No past events are recorded for this district.',
                    ),
                  );
                }
                return Column(
                  children: [
                    if (records.any((record) => record.isSample))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Demo preview includes fictional sample events. '
                          'They are not real or verified historical records.',
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return _historyRecordCard(record);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSource(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the source website.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the source website: $error')),
      );
    }
  }

  String _formatDate(DateTime date, DisasterDatePrecision precision) {
    final localizations = MaterialLocalizations.of(context);
    return switch (precision) {
      DisasterDatePrecision.day => localizations.formatMediumDate(date),
      DisasterDatePrecision.month => localizations.formatMonthYear(date),
      DisasterDatePrecision.year => date.year.toString(),
    };
  }

  Widget _historyRecordCard(DisasterHistoryRecord record) {
    final dateText = _formatDate(record.date, record.datePrecision);
    final endDate = record.endDate;
    final dateRange = endDate == null
        ? dateText
        : '$dateText – ${_formatDate(endDate, record.endDatePrecision)}';
    final impacts = <String>[
      if (record.totalDeaths != null) 'Deaths: ${record.totalDeaths}',
      if (record.totalInjured != null) 'Injured: ${record.totalInjured}',
      if (record.totalAffected != null) 'Affected: ${record.totalAffected}',
      if (record.totalHomeless != null) 'Homeless: ${record.totalHomeless}',
      if (record.adjustedDamageKusd != null)
        'Adjusted damage (USD thousands): ${record.adjustedDamageKusd}',
    ];

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
              if (record.isSample) ...[
                const Chip(
                  avatar: Icon(Icons.science_outlined, size: 18),
                  label: Text('SAMPLE · FICTIONAL'),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '$dateRange  -  ${record.severity == null ? 'Severity not assessed' : '${record.severity} severity'}',
              ),
              if (record.eventName?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(record.eventName!),
              ],
              if (record.disasterSubtype?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text('Type: ${record.disasterSubtype}'),
              ],
              if (record.locationDescription?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text('Reported area: ${record.locationDescription}'),
              ],
              if (record.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(record.summary),
              ],
              if (impacts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(impacts.join(' · ')),
              ],
              if (record.sourceName?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  'Source: ${record.sourceName}'
                  '${record.sourceEventId == null ? '' : ' · ${record.sourceEventId}'}'
                  '${record.sourceVersion == null ? '' : ' · dataset ${record.sourceVersion}'}',
                ),
              ],
              if (record.sourceUrl?.isNotEmpty == true)
                TextButton.icon(
                  onPressed: () => _openSource(record.sourceUrl!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open source'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisasterHistoryEditor extends StatefulWidget {
  const _DisasterHistoryEditor({
    required this.zones,
    required this.initialZoneId,
  });

  final List<Zone> zones;
  final String? initialZoneId;

  @override
  State<_DisasterHistoryEditor> createState() => _DisasterHistoryEditorState();
}

class _DisasterHistoryEditorState extends State<_DisasterHistoryEditor> {
  static const _nationalZone = '__national__';
  final _formKey = GlobalKey<FormState>();
  final _disasterType = TextEditingController();
  final _summary = TextEditingController();
  late String _zoneSelection;
  DateTime _date = DateTime.now();
  String _severity = 'moderate';

  @override
  void initState() {
    super.initState();
    final initialZoneExists = widget.zones.any(
      (zone) => zone.id == widget.initialZoneId,
    );
    _zoneSelection = initialZoneExists
        ? widget.initialZoneId!
        : widget.zones.isEmpty
        ? _nationalZone
        : widget.zones.first.id;
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
              initialValue: _zoneSelection,
              decoration: const InputDecoration(labelText: 'Area'),
              items: [
                const DropdownMenuItem(
                  value: _nationalZone,
                  child: Text('Sri Lanka (national)'),
                ),
                ...widget.zones.map(
                  (zone) =>
                      DropdownMenuItem(value: zone.id, child: Text(zone.name)),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _zoneSelection = value ?? _nationalZone),
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
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.pop(
                    context,
                    DisasterHistoryRecord(
                      id: 'history-${DateTime.now().microsecondsSinceEpoch}',
                      zoneId: _zoneSelection == _nationalZone
                          ? null
                          : _zoneSelection,
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
