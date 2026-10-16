import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/alert_service.dart';
import '../../../services/supabase_service.dart';
import '../models/checklist_item.dart';
import '../models/disaster_history_record.dart';
import '../models/evacuation_route.dart';
import '../models/preparedness_guide.dart';
import '../models/preparedness_reminder.dart';
import 'disaster_history_samples.dart';

abstract class PreparednessRepository {
  Future<List<PreparednessGuide>> getGuides();
  Future<void> saveGuide(PreparednessGuide guide);
  Future<void> archiveGuide(String guideId);
  Future<List<EvacuationRoute>> getRoutes();
  Future<void> saveRoute(EvacuationRoute route);
  Future<List<DisasterHistoryRecord>> getHistory(String zoneId);
  Future<List<DisasterHistoryRecord>> getCountryHistory();
  Future<void> saveHistoryRecord(DisasterHistoryRecord record);
  Future<String?> getActiveAlertForZone(String zoneId);
  Future<List<ChecklistItem>> getChecklistItems();
  Future<void> saveChecklistItem(ChecklistItem item);
  Future<void> deleteChecklistItem(String itemId);
  Future<List<PreparednessReminder>> getReminders();
  Future<void> saveReminder(PreparednessReminder reminder);
  Future<void> deleteReminder(String reminderId);
  Future<List<ChecklistItem>> generateChecklistForProfile(
    Map<String, dynamic> profile,
  );
  Future<Map<String, dynamic>> getRiskProfile(String userId);
  Future<void> saveRiskProfile(String userId, Map<String, dynamic> profile);
  Future<List<ChecklistItem>> getChecklistForUser(String userId);
  Future<void> saveChecklistForUser(String userId, List<ChecklistItem> items);
  Future<void> toggleChecklistItem(String userId, String itemId, bool isDone);
  List<PreparednessReminder> remindersForZone(
    List<PreparednessReminder> reminders,
    String? zoneId,
  );
}

class LocalPreparednessRepository implements PreparednessRepository {
  LocalPreparednessRepository({this.syncWithSupabase = false});

  // Local cache is the primary source of truth for the preparedness hub. When
  // Supabase sync is enabled, the repository replays queued mutations and keeps
  // the last successful response available offline.
  final bool syncWithSupabase;

  // Cache keys are versioned so schema changes can safely invalidate stale data.
  static const _guidesKey = 'preparedness.guides.v1';
  static const _routesKey = 'preparedness.routes.v1';
  static const _checklistItemsKey = 'preparedness.checklist.master.v1';
  static const _historyKey = 'preparedness.history.v1';
  static const _remindersKey = 'preparedness.reminders.v1';
  static const _riskProfilePrefix = 'preparedness.risk_profile.';
  static const _userChecklistPrefix = 'preparedness.user_checklist.';
  static const _pendingMutationsKey = 'preparedness.pending_mutations.v1';
  static const _demoContentIds = {
    'guide-flood-basics',
    'guide-family-kit',
    'route-colombo-demo',
    'route-default-demo',
    'history-2024-flood',
    'history-2023-storm',
    'reminder-1',
    'reminder-2',
    'reminder-3',
    'cnt-1',
    'cnt-2',
    'cnt-3',
    'cnt-4',
    'cnt-5',
    'cnt-6',
    'cnt-7',
    'cnt-8',
    'cnt-9',
    'cnt-10',
  };
  static const _starterChecklistItems = [
    ChecklistItem(
      id: 'starter-checklist-emergency-contacts',
      title: 'Keep emergency contacts available',
      description:
          'Write down important contacts and make sure household members know where to find them.',
      riskFactorTags: [],
    ),
    ChecklistItem(
      id: 'starter-checklist-household-meeting-place',
      title: 'Agree on a household meeting place',
      description:
          'Choose a safe place to meet if household members become separated.',
      riskFactorTags: [],
    ),
    ChecklistItem(
      id: 'starter-checklist-essential-supplies',
      title: 'Prepare essential emergency supplies',
      description:
          'Keep basic supplies, a flashlight, and necessary personal items easy to access.',
      riskFactorTags: [],
    ),
    ChecklistItem(
      id: 'starter-checklist-important-documents',
      title: 'Keep important documents accessible',
      description:
          'Store important documents securely and make copies available if you need to leave quickly.',
      riskFactorTags: [],
    ),
    ChecklistItem(
      id: 'starter-checklist-flood-route',
      title: 'Know your local flood evacuation route',
      description:
          'Check the evacuation guidance provided by your local authority and identify a safe route.',
      riskFactorTags: ['riverside', 'low-lying'],
    ),
    ChecklistItem(
      id: 'starter-checklist-household-support',
      title: 'Plan support for household members who need assistance',
      description:
          'Discuss communication, mobility, equipment, and transport needs with the people who may help.',
      riskFactorTags: ['elderly-household', 'disabled-household'],
    ),
    ChecklistItem(
      id: 'starter-checklist-no-vehicle-transport',
      title: 'Plan transport if you do not have a vehicle',
      description:
          'Ask your local authority about available evacuation transport and how to request assistance.',
      riskFactorTags: ['no-vehicle'],
    ),
    ChecklistItem(
      id: 'starter-checklist-large-household-checkin',
      title: 'Create a household check-in plan',
      description:
          'Choose how household members will contact each other and share updates during an emergency.',
      riskFactorTags: ['large-household'],
    ),
  ];
  static final _starterGuides = [
    PreparednessGuide(
      id: 'starter-guide-flood',
      title: 'Flood safety: before, during, and after',
      category: GuideCategory.flood,
      bodyContent: '''
# Flood safety

## Before flooding
- Follow local weather and authority alerts. Know your evacuation route and where higher ground is.
- Keep medicines, drinking water, a flashlight, a phone charger, and important documents ready to take with you.
- Move valuables and electrical items above expected flood levels if it is safe to do so.

## During flooding
- Evacuate promptly when authorities advise it. Move to higher ground and follow official routes.
- Never walk, swim, or drive through floodwater. It can hide hazards and move people or vehicles.
- If water is entering your home, move to a higher level and contact emergency services when safe.
- Do not touch electrical equipment while standing in water.

## After flooding
- Return only when authorities say it is safe. Avoid floodwater and damaged buildings.
- Treat water and food exposed to floodwater as unsafe until official guidance says otherwise.
''',
      coverImageUrl: '',
      zoneTags: const [],
      createdBy: 'preparedness-team',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isArchived: false,
    ),
    PreparednessGuide(
      id: 'starter-guide-fire',
      title: 'Fire safety and evacuation',
      category: GuideCategory.fire,
      bodyContent: '''
# Fire safety

## Be ready
- Identify two ways out of rooms where possible and agree on a meeting place outside.
- Keep exits clear and make sure everyone knows how to raise the alarm.
- Store matches, lighters, and flammable materials safely.

## If there is a fire
- Raise the alarm, leave immediately, and call the fire service from a safe place.
- Stay low under smoke. Use stairs, not lifts, and do not stop to collect belongings.
- If a door is hot or smoke is coming through it, use another exit. If trapped, close the door, block smoke gaps if possible, and signal for help.
- Never re-enter a burning building.

Follow emergency-service instructions and do not attempt to fight a fire that is spreading or blocking your exit.
''',
      coverImageUrl: '',
      zoneTags: const [],
      createdBy: 'preparedness-team',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isArchived: false,
    ),
    PreparednessGuide(
      id: 'starter-guide-earthquake',
      title: 'Earthquake safety',
      category: GuideCategory.earthquake,
      bodyContent: '''
# Earthquake safety

## During shaking
- Drop, cover, and hold on. Get under sturdy furniture if available and protect your head and neck.
- Stay indoors away from windows until shaking stops. Do not use lifts.
- If outdoors, move to an open area away from buildings, trees, and power lines.
- If in a vehicle, stop in a clear place and remain inside until shaking stops.

## After shaking
- Expect aftershocks. Check for injuries and provide help only when it is safe.
- Leave damaged buildings carefully and move away from walls and overhead hazards.
- If you smell gas or see damaged electrical lines, move away and report the danger; do not operate switches or use flames.
- Follow official updates and use text messages where possible to keep phone networks available.
''',
      coverImageUrl: '',
      zoneTags: const [],
      createdBy: 'preparedness-team',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isArchived: false,
    ),
    PreparednessGuide(
      id: 'starter-guide-landslide',
      title: 'Landslide awareness and response',
      category: GuideCategory.landslide,
      bodyContent: '''
# Landslide safety

## Be alert
- Pay attention to official warnings, especially during and after prolonged or heavy rain.
- Watch for new ground cracks, leaning trees or poles, unusual water flow, or rumbling sounds near slopes.
- Know safer places and evacuation routes away from steep slopes and drainage channels.

## If a slide may be happening
- Move away from the path of the slide immediately, following local emergency guidance.
- Do not cross an active slide area. If escape is not possible, protect your head and curl into a ball.
- Warn others only if doing so does not delay your escape, then contact emergency services from a safe location.

Do not return until authorities have assessed the area and said it is safe.
''',
      coverImageUrl: '',
      zoneTags: const [],
      createdBy: 'preparedness-team',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isArchived: false,
    ),
    PreparednessGuide(
      id: 'starter-guide-tsunami',
      title: 'Tsunami warning and evacuation',
      category: GuideCategory.tsunami,
      bodyContent: '''
# Tsunami safety

## Know when to move
- A strong or long earthquake near the coast, unusual sea-level changes, or a loud ocean roar can be natural warning signs.
- If you are near the coast and notice these signs, move immediately to higher ground or inland. Do not wait to see a wave.
- Follow marked evacuation routes and official tsunami alerts.

## During a warning
- Stay away from beaches, river mouths, and low-lying coastal areas.
- If you are on a boat, follow advice from maritime and emergency authorities; do not return to shore during a warning.
- Help children and people needing assistance if you can do so without delaying evacuation.

Remain in a safe location until authorities issue an all-clear. The first wave may not be the largest.
''',
      coverImageUrl: '',
      zoneTags: const [],
      createdBy: 'preparedness-team',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isArchived: false,
    ),
    PreparednessGuide(
      id: 'starter-guide-cyclone',
      title: 'Cyclone and severe weather readiness',
      category: GuideCategory.cyclone,
      bodyContent: '''
# Cyclone and severe weather safety

## Before severe weather
- Monitor official forecasts and evacuation instructions.
- Secure loose outdoor objects if it is safe and prepare water, medicines, a flashlight, and charged devices.
- Identify a sturdy shelter away from windows and know how to reach it.

## During severe weather
- Stay inside, away from windows and glass. Do not go outside during a temporary lull; conditions may worsen again.
- If authorities order evacuation, leave promptly using the recommended route.
- Avoid flooded roads, fallen power lines, and damaged structures.

## After the weather passes
- Wait for the official all-clear. Report hazards to authorities and keep clear of downed lines.
- Use generators only outdoors and away from doors and windows, following the manufacturer's safety directions.
''',
      coverImageUrl: '',
      zoneTags: const [],
      createdBy: 'preparedness-team',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isArchived: false,
    ),
  ];

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  bool get _canSync {
    try {
      return syncWithSupabase && SupabaseService.currentUserId != null;
    } catch (_) {
      return false;
    }
  }

  bool _canSyncUser(String userId) {
    try {
      return _canSync && SupabaseService.currentUserId == userId;
    } catch (_) {
      return false;
    }
  }

  // Content entries are read through the local cache first, and the backend is
  // used as a refresh source when the user is authenticated and sync is enabled.
  Future<List<T>> _readContent<T>(
    String type,
    String cacheKey,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final preferences = await _preferences;
    if (_canSync) {
      try {
        await _flushPendingContentMutations();
        final rows = await SupabaseService.client
            .from('preparedness_content')
            .select('payload')
            .eq('content_type', type)
            .order('updated_at');
        final values = rows
            .map((row) => Map<String, dynamic>.from(row['payload'] as Map))
            .where((value) => !_demoContentIds.contains(value['id']))
            .toList();
        final merged = await _overlayPendingContent(type, values);
        await preferences.setString(cacheKey, jsonEncode(merged));
        return merged.map(decode).toList();
      } catch (_) {
        // Keep serving the last cached copy while the backend is unavailable.
      }
    }

    final cached = preferences.getString(cacheKey);
    if (cached == null) return [];
    final values = (jsonDecode(cached) as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where((value) => !_demoContentIds.contains(value['id']))
        .toList();
    final merged = await _overlayPendingContent(type, values);
    await preferences.setString(cacheKey, jsonEncode(merged));
    return merged.map(decode).toList();
  }

  // Offline writes are queued locally and replayed later so the user can keep
  // working even when connectivity is temporarily unavailable.
  Future<List<Map<String, dynamic>>> _pendingMutations() async {
    final cached = (await _preferences).getString(_pendingMutationsKey);
    if (cached == null) return [];
    return (jsonDecode(cached) as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }

  Future<void> _savePendingMutations(
    List<Map<String, dynamic>> mutations,
  ) async {
    final preferences = await _preferences;
    await preferences.setString(_pendingMutationsKey, jsonEncode(mutations));
  }

  Future<void> _queueContentMutation(Map<String, dynamic> mutation) async {
    final pending = await _pendingMutations();
    pending.removeWhere((entry) => entry['key'] == mutation['key']);
    pending.add(mutation);
    await _savePendingMutations(pending);
  }

  Future<void> _removePendingMutation(String key) async {
    final pending = await _pendingMutations();
    pending.removeWhere((entry) => entry['key'] == key);
    await _savePendingMutations(pending);
  }

  Future<Map<String, dynamic>?> _pendingRow(String key) async {
    for (final mutation in await _pendingMutations()) {
      if (mutation['key'] == key && mutation['deleted'] != true) {
        return Map<String, dynamic>.from(mutation['row'] as Map);
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _overlayPendingContent(
    String type,
    List<Map<String, dynamic>> values,
  ) async {
    for (final mutation in await _pendingMutations()) {
      if (mutation['table'] != 'preparedness_content' ||
          mutation['contentType'] != type) {
        continue;
      }
      final id = mutation['id'] as String;
      values.removeWhere((value) => value['id'] == id);
      if (mutation['deleted'] != true) {
        values.add(Map<String, dynamic>.from(mutation['payload'] as Map));
      }
    }
    return values;
  }

  Future<void> _flushPendingContentMutations() async {
    final pending = await _pendingMutations();
    final remaining = <Map<String, dynamic>>[];
    for (final mutation in pending) {
      try {
        if (mutation['table'] == 'preparedness_content' &&
            mutation['deleted'] == true) {
          await SupabaseService.client
              .from('preparedness_content')
              .delete()
              .eq('content_type', mutation['contentType'])
              .eq('id', mutation['id']);
        } else if (mutation['table'] == 'preparedness_content') {
          await SupabaseService.client.from('preparedness_content').upsert({
            'content_type': mutation['contentType'],
            'id': mutation['id'],
            'zone_id': mutation['zoneId'],
            'payload': mutation['payload'],
            'updated_by': SupabaseService.currentUserId,
          }, onConflict: 'content_type,id');
        } else if (mutation['table'] == 'preparedness_risk_profiles' ||
            mutation['table'] == 'preparedness_user_checklists') {
          await SupabaseService.client
              .from(mutation['table'] as String)
              .upsert(mutation['row'] as Map<String, dynamic>);
        } else {
          remaining.add(mutation);
        }
      } catch (_) {
        remaining.add(mutation);
      }
    }
    await _savePendingMutations(remaining);
  }

  Future<void> _upsertContent(
    String type,
    String id,
    Map<String, dynamic> payload, {
    String? zoneId,
  }) async {
    if (!_canSync) return;
    final key = 'preparedness_content:$type:$id';
    try {
      await SupabaseService.client.from('preparedness_content').upsert({
        'content_type': type,
        'id': id,
        'zone_id': zoneId,
        'payload': payload,
        'updated_by': SupabaseService.currentUserId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'content_type,id');
      await _removePendingMutation(key);
    } catch (_) {
      await _queueContentMutation({
        'key': key,
        'table': 'preparedness_content',
        'contentType': type,
        'id': id,
        'zoneId': zoneId,
        'payload': payload,
        'deleted': false,
      });
    }
  }

  Future<void> _deleteContent(String type, String id) async {
    if (!_canSync) return;
    final key = 'preparedness_content:$type:$id';
    try {
      await SupabaseService.client
          .from('preparedness_content')
          .delete()
          .eq('content_type', type)
          .eq('id', id);
      await _removePendingMutation(key);
    } catch (_) {
      await _queueContentMutation({
        'key': key,
        'table': 'preparedness_content',
        'contentType': type,
        'id': id,
        'deleted': true,
      });
    }
  }

  @override
  Future<List<PreparednessGuide>> getGuides() async {
    final guides = await _readContent(
      'guide',
      _guidesKey,
      PreparednessGuide.fromJson,
    );
    final ids = guides.map((guide) => guide.id).toSet();
    return [
      ...guides,
      ..._starterGuides.where((guide) => !ids.contains(guide.id)),
    ];
  }

  @override
  Future<void> saveGuide(PreparednessGuide guide) async {
    final preferences = await _preferences;
    final guides = await getGuides();
    final index = guides.indexWhere((item) => item.id == guide.id);
    if (index < 0) {
      guides.insert(0, guide);
    } else {
      guides[index] = guide;
    }
    await _writeGuides(preferences, guides);
    await _upsertContent('guide', guide.id, guide.toJson());
  }

  @override
  Future<void> archiveGuide(String guideId) async {
    final guide = (await getGuides()).firstWhere((item) => item.id == guideId);
    await saveGuide(
      guide.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
  }

  @override
  Future<List<EvacuationRoute>> getRoutes() async {
    return _readContent('route', _routesKey, EvacuationRoute.fromJson);
  }

  @override
  Future<void> saveRoute(EvacuationRoute route) async {
    final preferences = await _preferences;
    final routes = await getRoutes();
    final index = routes.indexWhere((item) => item.id == route.id);
    if (index < 0) {
      routes.add(route);
    } else {
      routes[index] = route;
    }
    await _writeRoutes(preferences, routes);
    await _upsertContent(
      'route',
      route.id,
      route.toJson(),
      zoneId: route.zoneId,
    );
  }

  @override
  Future<List<DisasterHistoryRecord>> getHistory(
    String zoneId,
  ) async => _mergeHistorySamples(
    await _readContent('history', _historyKey, DisasterHistoryRecord.fromJson),
  ).where((record) => record.zoneId == zoneId || record.isNational).toList();

  @override
  Future<List<DisasterHistoryRecord>> getCountryHistory() async {
    final records = _mergeHistorySamples(
      await _readContent(
        'history',
        _historyKey,
        DisasterHistoryRecord.fromJson,
      ),
    );
    final uniqueEvents = <String, DisasterHistoryRecord>{};
    for (final record in records) {
      uniqueEvents.putIfAbsent(record.sourceEventId ?? record.id, () => record);
    }
    return uniqueEvents.values.toList();
  }

  List<DisasterHistoryRecord> _mergeHistorySamples(
    List<DisasterHistoryRecord> records,
  ) {
    final recordsById = {
      for (final sample in disasterHistorySamples) sample.id: sample,
      for (final record in records) record.id: record,
    };
    return recordsById.values.toList();
  }

  @override
  Future<void> saveHistoryRecord(DisasterHistoryRecord record) async {
    if (record.isSample) {
      throw StateError('Demo sample records cannot be saved or synced.');
    }
    final preferences = await _preferences;
    final records = await _readContent(
      'history',
      _historyKey,
      DisasterHistoryRecord.fromJson,
    );
    final index = records.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      records.insert(0, record);
    } else {
      records[index] = record;
    }
    await preferences.setString(
      _historyKey,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
    await _upsertContent(
      'history',
      record.id,
      record.toJson(),
      zoneId: record.zoneId,
    );
  }

  @override
  Future<String?> getActiveAlertForZone(String zoneId) async {
    try {
      final service = AlertService();
      final (cachedAlerts, _) = await service.readCache();
      final active = cachedAlerts.isNotEmpty
          ? cachedAlerts
          : await service.fetchActiveAlerts();
      final filtered = active.where((alert) {
        final matchesZone = alert.affectedZoneId == zoneId;
        return matchesZone &&
            (alert.status.name == 'active' || alert.status.name == 'escalated');
      }).toList();
      if (filtered.isEmpty) return null;
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered.first.title;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ChecklistItem>> getChecklistItems() async {
    final items = await _readContent(
      'checklist_item',
      _checklistItemsKey,
      ChecklistItem.fromJson,
    );
    if (items.isNotEmpty) return items;
    return List.of(_starterChecklistItems);
  }

  @override
  Future<void> saveChecklistItem(ChecklistItem item) async {
    final preferences = await _preferences;
    final items = await getChecklistItems();
    final index = items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      items.insert(0, item);
    } else {
      items[index] = item;
    }
    await preferences.setString(
      _checklistItemsKey,
      jsonEncode(items.map((entry) => entry.toJson()).toList()),
    );
    await _upsertContent('checklist_item', item.id, item.toJson());
  }

  @override
  Future<void> deleteChecklistItem(String itemId) async {
    final preferences = await _preferences;
    final items = await getChecklistItems();
    final filtered = items.where((item) => item.id != itemId).toList();
    await preferences.setString(
      _checklistItemsKey,
      jsonEncode(filtered.map((item) => item.toJson()).toList()),
    );
    await _deleteContent('checklist_item', itemId);
  }

  @override
  Future<List<PreparednessReminder>> getReminders() async {
    return _readContent(
      'reminder',
      _remindersKey,
      PreparednessReminder.fromJson,
    );
  }

  @override
  Future<void> saveReminder(PreparednessReminder reminder) async {
    final preferences = await _preferences;
    final reminders = await getReminders();
    final index = reminders.indexWhere((item) => item.id == reminder.id);
    if (index < 0) {
      reminders.insert(0, reminder);
    } else {
      reminders[index] = reminder;
    }
    await preferences.setString(
      _remindersKey,
      jsonEncode(reminders.map((item) => item.toJson()).toList()),
    );
    await _upsertContent('reminder', reminder.id, reminder.toJson());
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    final preferences = await _preferences;
    final reminders = await getReminders();
    final filtered = reminders.where((item) => item.id != reminderId).toList();
    await preferences.setString(
      _remindersKey,
      jsonEncode(filtered.map((item) => item.toJson()).toList()),
    );
    await _deleteContent('reminder', reminderId);
  }

  @override
  Future<List<ChecklistItem>> generateChecklistForProfile(
    Map<String, dynamic> profile,
  ) async {
    final tags = _riskTagsForProfile(profile);
    final items = await getChecklistItems();
    return items.where((item) {
      if (item.riskFactorTags.isEmpty) return true;
      return item.riskFactorTags.any(tags.contains);
    }).toList();
  }

  // User-specific safety data is stored under a per-user key so each profile can
  // be retrieved independently even when the app is offline.
  @override
  Future<Map<String, dynamic>> getRiskProfile(String userId) async {
    final preferences = await _preferences;
    if (_canSyncUser(userId)) {
      await _flushPendingContentMutations();
      final pending = await _pendingRow('preparedness_risk_profiles:$userId');
      if (pending != null) {
        final profile = Map<String, dynamic>.from(pending['profile'] as Map);
        await preferences.setString(
          '$_riskProfilePrefix$userId',
          jsonEncode(profile),
        );
        return profile;
      }
      try {
        final row = await SupabaseService.client
            .from('preparedness_risk_profiles')
            .select('profile')
            .eq('user_id', userId)
            .maybeSingle();
        final profile = row == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(row['profile'] as Map);
        await preferences.setString(
          '$_riskProfilePrefix$userId',
          jsonEncode(profile),
        );
        return profile;
      } catch (_) {
        // Use the local profile when the backend cannot be reached.
      }
    }
    final cached = preferences.getString('$_riskProfilePrefix$userId');
    if (cached == null) return {};
    return Map<String, dynamic>.from(jsonDecode(cached) as Map);
  }

  @override
  Future<void> saveRiskProfile(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    final preferences = await _preferences;
    await preferences.setString(
      '$_riskProfilePrefix$userId',
      jsonEncode(profile),
    );
    if (_canSyncUser(userId)) {
      final row = {'user_id': userId, 'profile': profile};
      try {
        await SupabaseService.client
            .from('preparedness_risk_profiles')
            .upsert(row);
        await _removePendingMutation('preparedness_risk_profiles:$userId');
      } catch (_) {
        await _queueContentMutation({
          'key': 'preparedness_risk_profiles:$userId',
          'table': 'preparedness_risk_profiles',
          'row': row,
        });
      }
    }
  }

  @override
  Future<List<ChecklistItem>> getChecklistForUser(String userId) async {
    final preferences = await _preferences;
    if (_canSyncUser(userId)) {
      await _flushPendingContentMutations();
      final pending = await _pendingRow('preparedness_user_checklists:$userId');
      if (pending != null) {
        final items = (pending['items'] as List)
            .map(
              (value) => ChecklistItem.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .where((item) => !_demoContentIds.contains(item.id))
            .toList();
        await preferences.setString(
          '$_userChecklistPrefix$userId',
          jsonEncode(items.map((item) => item.toJson()).toList()),
        );
        return items;
      }
      try {
        final row = await SupabaseService.client
            .from('preparedness_user_checklists')
            .select('items')
            .eq('user_id', userId)
            .maybeSingle();
        if (row != null) {
          final items = (row['items'] as List)
              .map(
                (value) => ChecklistItem.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              )
              .where((item) => !_demoContentIds.contains(item.id))
              .toList();
          await preferences.setString(
            '$_userChecklistPrefix$userId',
            jsonEncode(items.map((item) => item.toJson()).toList()),
          );
          return items;
        }
      } catch (_) {
        // Use the local checklist when the backend cannot be reached.
      }
    }
    final cached = preferences.getString('$_userChecklistPrefix$userId');
    if (cached == null) {
      final profile = await getRiskProfile(userId);
      final generated = await generateChecklistForProfile(profile);
      await saveChecklistForUser(userId, generated);
      return generated;
    }
    final items = (jsonDecode(cached) as List)
        .map(
          (value) =>
              ChecklistItem.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .where((item) => !_demoContentIds.contains(item.id))
        .toList();
    await preferences.setString(
      '$_userChecklistPrefix$userId',
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    return items;
  }

  @override
  Future<void> saveChecklistForUser(
    String userId,
    List<ChecklistItem> items,
  ) async {
    final preferences = await _preferences;
    await preferences.setString(
      '$_userChecklistPrefix$userId',
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    if (_canSyncUser(userId)) {
      final row = {
        'user_id': userId,
        'items': items.map((item) => item.toJson()).toList(),
      };
      try {
        await SupabaseService.client
            .from('preparedness_user_checklists')
            .upsert(row);
        await _removePendingMutation('preparedness_user_checklists:$userId');
      } catch (_) {
        await _queueContentMutation({
          'key': 'preparedness_user_checklists:$userId',
          'table': 'preparedness_user_checklists',
          'row': row,
        });
      }
    }
  }

  @override
  Future<void> toggleChecklistItem(
    String userId,
    String itemId,
    bool isDone,
  ) async {
    final items = await getChecklistForUser(userId);
    final updated = items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isDone: isDone);
      }
      return item;
    }).toList();
    await saveChecklistForUser(userId, updated);
  }

  // Only reminders tagged for the current zone or for all zones should appear in
  // the dashboard for a given area.
  @override
  List<PreparednessReminder> remindersForZone(
    List<PreparednessReminder> reminders,
    String? zoneId,
  ) {
    final filtered = reminders.where((reminder) {
      if (reminder.zoneTags.isEmpty) return true;
      if (zoneId == null) return false;
      return reminder.zoneTags.contains(zoneId);
    }).toList();
    filtered.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return filtered;
  }

  Future<void> _writeGuides(
    SharedPreferences preferences,
    List<PreparednessGuide> guides,
  ) async {
    await preferences.setString(
      _guidesKey,
      jsonEncode(guides.map((guide) => guide.toJson()).toList()),
    );
  }

  Future<void> _writeRoutes(
    SharedPreferences preferences,
    List<EvacuationRoute> routes,
  ) async {
    await preferences.setString(
      _routesKey,
      jsonEncode(routes.map((route) => route.toJson()).toList()),
    );
  }

  Set<String> _riskTagsForProfile(Map<String, dynamic> profile) {
    final tags = <String>{};
    final locationType = (profile['locationType'] ?? '').toString();
    if (locationType == 'riverside') tags.add('riverside');
    if (locationType == 'low-lying') tags.add('low-lying');
    if (locationType == 'hillside') tags.add('hillside');
    if (locationType == 'urban') tags.add('urban');
    final householdSize = (profile['householdSize'] ?? '').toString();
    if (householdSize == '1-2') tags.add('small-household');
    if (householdSize == '3-4') tags.add('medium-household');
    if (householdSize == '5+') tags.add('large-household');
    if (_profileFlag(profile['hasElderlyMember'])) {
      tags.add('elderly-household');
    }
    if (_profileFlag(profile['hasDisabledMember'])) {
      tags.add('disabled-household');
    }
    if (profile['hasVehicle'] == false || profile['hasVehicle'] == 'no') {
      tags.add('no-vehicle');
    }
    return tags;
  }

  bool _profileFlag(dynamic value) => value == true || value == 'yes';
}
