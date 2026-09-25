import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InterruptionDetector {
  final VoidCallback onInterruption;

  const InterruptionDetector({required this.onInterruption});

  void onLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      onInterruption();
    }
  }

  void onConnectivityChanged(bool hasConnection) {
    if (!hasConnection) onInterruption();
  }
}

const int kActivityHistoryLimit = 4;
const String _activityHistoryKey = 'safezone_local_activity_history';

enum ResumeItemType { route, report, shelter, draft, screen }

class ActivityEntry {
  final String id;
  final String title;
  final String section;
  final ResumeItemType type;
  final String subtitle;
  final DateTime timestamp;
  final String routeOrDraftRef;
  final bool interrupted;

  ActivityEntry({
    String? id,
    required this.title,
    this.section = '',
    this.type = ResumeItemType.screen,
    this.subtitle = '',
    DateTime? timestamp,
    String? routeOrDraftRef,
    this.interrupted = false,
  })  : id = id ?? routeOrDraftRef ?? title,
        routeOrDraftRef = routeOrDraftRef ?? id ?? title,
        timestamp = timestamp ?? DateTime.now();

  DateTime get visitedAt => timestamp;

  ActivityEntry copyWith({
    bool? interrupted,
    DateTime? timestamp,
    String? subtitle,
  }) =>
      ActivityEntry(
        id: id,
        title: title,
        section: section,
        type: type,
        subtitle: subtitle ?? this.subtitle,
        timestamp: timestamp ?? this.timestamp,
        routeOrDraftRef: routeOrDraftRef,
        interrupted: interrupted ?? this.interrupted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'section': section,
        'type': type.name,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
        'routeOrDraftRef': routeOrDraftRef,
        'interrupted': interrupted,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'screen';
    final id = json['id'] as String? ?? json['routeOrDraftRef'] as String? ?? '';
    return ActivityEntry(
      id: id,
      title: json['title'] as String? ?? '',
      section: json['section'] as String? ?? '',
      type: ResumeItemType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => ResumeItemType.screen,
      ),
      subtitle: json['subtitle'] as String? ?? '',
      timestamp: DateTime.parse((json['timestamp'] ?? json['visitedAt']) as String),
      routeOrDraftRef: json['routeOrDraftRef'] as String? ?? id,
      interrupted: json['interrupted'] as bool? ?? false,
    );
  }
}

typedef ResumeItem = ActivityEntry;

class ActivityHistoryService extends ChangeNotifier {
  ActivityHistoryService({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;
  final List<ActivityEntry> _entries = [];
  bool _loaded = false;

  List<ActivityEntry> get entries => List.unmodifiable(_entries);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    final raw = _preferences!.getStringList(_activityHistoryKey) ?? [];
    _entries
      ..clear()
      ..addAll(raw.map((value) {
        try {
          return ActivityEntry.fromJson(jsonDecode(value) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      }).whereType<ActivityEntry>());
    _loaded = true;
    notifyListeners();
  }

  Future<void> record({
    required String id,
    required String title,
    required String section,
    ResumeItemType type = ResumeItemType.screen,
    String? subtitle,
    String? routeOrDraftRef,
  }) async {
    if (!_loaded) await load();

    final effectiveRef = routeOrDraftRef ?? id;
    _entries.removeWhere((entry) => entry.id == id || entry.routeOrDraftRef == effectiveRef);
    _entries.insert(
      0,
      ActivityEntry(
        id: id,
        title: title,
        section: section,
        type: type,
        subtitle: subtitle ?? '',
        routeOrDraftRef: effectiveRef,
        timestamp: DateTime.now(),
      ),
    );
    _trimAndNotify();
    await _persist();
  }

  Future<void> markInterrupted() async {
    if (!_loaded) await load();
    if (_entries.isEmpty) return;
    _entries[0] = _entries[0].copyWith(interrupted: true);
    _trimAndNotify();
    await _persist();
  }

  void _trimAndNotify() {
    if (_entries.length > kActivityHistoryLimit) {
      _entries.removeRange(kActivityHistoryLimit, _entries.length);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _preferences!.setStringList(
      _activityHistoryKey,
      _entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }
}
