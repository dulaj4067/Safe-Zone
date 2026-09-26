import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/disaster_history_record.dart';
import '../providers/preparedness_provider.dart';

class DisasterHistoryScreen extends StatefulWidget {
  const DisasterHistoryScreen({super.key, required this.zoneId});
  final String zoneId;

  @override
  State<DisasterHistoryScreen> createState() => _DisasterHistoryScreenState();
}

class _DisasterHistoryScreenState extends State<DisasterHistoryScreen> {
  late Future<List<DisasterHistoryRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = context.read<PreparednessProvider>().historyForZone(widget.zoneId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Disaster history')),
        body: FutureBuilder<List<DisasterHistoryRecord>>(
          future: _records,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = [...?snapshot.data]..sort((a, b) => b.date.compareTo(a.date));
            if (records.isEmpty) return const Center(child: Text('No past events are recorded for this zone.'));
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
                          Text('${MaterialLocalizations.of(context).formatMediumDate(record.date)}  -  ${record.severity} severity'),
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