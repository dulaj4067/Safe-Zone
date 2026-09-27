import 'package:flutter/material.dart';

import '../models/feedback_entry.dart';
import '../models/zone.dart';
import '../services/feedback_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

/// Authority view of citizen feedback: average rating, rating spread, and
/// every comment newest-first, filterable by zone.
class FeedbackOverviewScreen extends StatefulWidget {
  final List<Zone> zones;

  const FeedbackOverviewScreen({super.key, this.zones = const []});

  @override
  State<FeedbackOverviewScreen> createState() => _FeedbackOverviewScreenState();
}

class _FeedbackOverviewScreenState extends State<FeedbackOverviewScreen> {
  List<FeedbackEntry>? _entries;
  bool _failed = false;
  String? _zoneFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await FeedbackService().fetchRecent();
      if (mounted) {
        setState(() {
          _entries = entries;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _zoneName(String? id) =>
      widget.zones.where((z) => z.id == id).firstOrNull?.name ?? 'Unknown zone';

  @override
  Widget build(BuildContext context) {
    final all = _entries;
    final entries = all?.where((e) => _zoneFilter == null || e.zoneId == _zoneFilter).toList();

    Widget body;
    if (_failed) {
      body = const Center(child: Text('Couldn\'t load feedback.'));
    } else if (entries == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final zonesWithFeedback = {
        for (final e in all!)
          if (e.zoneId != null) e.zoneId!,
      };
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (zonesWithFeedback.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All zones'),
                      selected: _zoneFilter == null,
                      onSelected: (_) => setState(() => _zoneFilter = null),
                    ),
                  ),
                  for (final zoneId in zonesWithFeedback)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_zoneName(zoneId)),
                        selected: _zoneFilter == zoneId,
                        onSelected: (_) => setState(() => _zoneFilter = zoneId),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _SummaryCard(entries: entries),
          const SizedBox(height: 20),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (entries.where((e) => (e.needs ?? '').isNotEmpty).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No written feedback yet.')),
            )
          else
            for (final e in entries.where((e) => (e.needs ?? '').isNotEmpty))
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Stars(rating: e.rating ?? 0),
                          const Spacer(),
                          Text(
                            '${e.zoneId == null ? '' : '${_zoneName(e.zoneId)} · '}${timeAgo(e.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(e.needs!),
                    ],
                  ),
                ),
              ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Citizen Feedback')),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<FeedbackEntry> entries;

  const _SummaryCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rated = entries.where((e) => e.rating != null).toList();
    final average = rated.isEmpty
        ? null
        : rated.map((e) => e.rating!).reduce((a, b) => a + b) / rated.length;
    final counts = {
      for (var star = 5; star >= 1; star--) star: rated.where((e) => e.rating == star).length,
    };
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  average == null ? '–' : average.toStringAsFixed(1),
                  style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                _Stars(rating: average?.round() ?? 0),
                const SizedBox(height: 4),
                Text('${rated.length} response${rated.length == 1 ? '' : 's'}', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (final entry in counts.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 14, child: Text('${entry.key}', style: textTheme.bodySmall)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: maxCount == 0 ? 0 : entry.value / maxCount,
                                minHeight: 6,
                                color: entry.key <= 2 ? AppColors.severityOrange : AppColors.riverTeal,
                                backgroundColor: AppColors.hairline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            child: Text('${entry.value}', textAlign: TextAlign.end, style: textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;

  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: i <= rating ? AppColors.severityYellow : AppColors.slateMuted,
          ),
      ],
    );
  }
}
