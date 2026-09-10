import 'package:flutter/material.dart';

class SessionHistoryEntry {
  final String id;
  final String title;
  final DateTime occurredAt;
  final String? subtitle;

  const SessionHistoryEntry({
    required this.id,
    required this.title,
    required this.occurredAt,
    this.subtitle,
  });
}

class SessionHistoryList extends StatefulWidget {
  final List<SessionHistoryEntry> sessions;
  final int pageSize;

  const SessionHistoryList({
    super.key,
    this.sessions = const [],
    this.pageSize = 3,
  });

  @override
  State<SessionHistoryList> createState() => _SessionHistoryListState();
}

class _SessionHistoryListState extends State<SessionHistoryList> {
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _visibleCount = _initialVisibleCount();
  }

  @override
  void didUpdateWidget(covariant SessionHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions || oldWidget.pageSize != widget.pageSize) {
      _visibleCount = _initialVisibleCount();
    }
  }

  int _initialVisibleCount() {
    if (widget.sessions.isEmpty) return 0;
    return widget.pageSize < 1 ? widget.sessions.length : (widget.pageSize > widget.sessions.length ? widget.sessions.length : widget.pageSize);
  }

  List<SessionHistoryEntry> _sortedSessions() {
    final copy = [...widget.sessions];
    copy.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedSessions();
    final visible = sorted.take(_visibleCount).toList();
    final hasMore = _visibleCount < sorted.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Session history',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Text('No recent sessions yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = visible[index];
                  final isNewest = index == visible.length - 1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      child: Text(isNewest ? 'NEW' : '${index + 1}'),
                    ),
                    title: Text(entry.title),
                    subtitle: Text(entry.subtitle ?? _formatDate(entry.occurredAt)),
                    trailing: Icon(
                      isNewest ? Icons.check_circle_rounded : Icons.access_time,
                      size: 18,
                      color: isNewest ? Colors.green : Colors.grey,
                    ),
                  );
                },
              ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        final nextCount = _visibleCount + widget.pageSize;
                        _visibleCount = nextCount > sorted.length ? sorted.length : nextCount;
                      });
                    },
                    child: const Text('Load more'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
