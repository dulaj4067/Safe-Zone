import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/alert_service.dart';
import '../../../services/supabase_service.dart';
import '../models/checklist_item.dart';
import '../models/disaster_history_record.dart';
import '../models/evacuation_route.dart';
import '../models/preparedness_guide.dart';
import '../models/preparedness_reminder.dart';

abstract class PreparednessRepository {
  Future<List<PreparednessGuide>> getGuides();
  Future<void> saveGuide(PreparednessGuide guide);
  Future<void> archiveGuide(String guideId);
  Future<List<EvacuationRoute>> getRoutes();
  Future<void> saveRoute(EvacuationRoute route);
  Future<List<DisasterHistoryRecord>> getHistory(String zoneId);
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

  final bool syncWithSupabase;

  static const _guidesKey = 'preparedness.guides.v1';
  static const _routesKey = 'preparedness.routes.v1';
  static const _checklistItemsKey = 'preparedness.checklist.master.v1';
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
    return _readContent('guide', _guidesKey, PreparednessGuide.fromJson);
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
  Future<List<DisasterHistoryRecord>> getHistory(String zoneId) async =>
      (await _readContent(
        'history',
        'preparedness.history.v1',
        DisasterHistoryRecord.fromJson,
      )).where((record) => record.zoneId == zoneId).toList();

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
    return _readContent(
      'checklist_item',
      _checklistItemsKey,
      ChecklistItem.fromJson,
    );
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
    final householdSize = (profile['householdSize'] ?? '').toString();
    if (householdSize == '5+') tags.add('large-household');
    if (profile['hasElderlyMember'] as bool? ?? false) {
      tags.add('elderly-household');
    }
    if (profile['hasDisabledMember'] as bool? ?? false) {
      tags.add('disabled-household');
    }
    if (profile['hasVehicle'] == false) tags.add('no-vehicle');
    return tags;
  }
}
