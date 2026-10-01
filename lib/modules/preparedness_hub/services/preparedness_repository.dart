import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/alert_service.dart';
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
  static const _guidesKey = 'preparedness.guides.v1';
  static const _routesKey = 'preparedness.routes.v1';
  static const _checklistItemsKey = 'preparedness.checklist.master.v1';
  static const _remindersKey = 'preparedness.reminders.v1';
  static const _riskProfilePrefix = 'preparedness.risk_profile.';
  static const _userChecklistPrefix = 'preparedness.user_checklist.';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<List<PreparednessGuide>> getGuides() async {
    final preferences = await _preferences;
    final cached = preferences.getString(_guidesKey);
    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map(
            (value) => PreparednessGuide.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    }
    final samples = _sampleGuides();
    await _writeGuides(preferences, samples);
    return samples;
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
    final preferences = await _preferences;
    final cached = preferences.getString(_routesKey);
    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map(
            (value) => EvacuationRoute.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    }
    final samples = _sampleRoutes();
    await _writeRoutes(preferences, samples);
    return samples;
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
  }

  @override
  Future<List<DisasterHistoryRecord>> getHistory(String zoneId) async =>
      _sampleHistory().where((record) => record.zoneId == zoneId).toList();

  @override
  Future<String?> getActiveAlertForZone(String zoneId) async {
    try {
      final service = AlertService();
      final (cachedAlerts, _) = await service.readCache();
      final active = cachedAlerts.isNotEmpty
          ? cachedAlerts
          : await service.fetchActiveAlerts();
      final filtered = active.where((alert) {
        final matchesZone =
            alert.affectedZoneId == zoneId ||
            (zoneId == 'default' && alert.affectedZoneId == null);
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
    final preferences = await _preferences;
    final cached = preferences.getString(_checklistItemsKey);
    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map(
            (value) =>
                ChecklistItem.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
    }
    final samples = _sampleChecklistItems();
    await preferences.setString(
      _checklistItemsKey,
      jsonEncode(samples.map((item) => item.toJson()).toList()),
    );
    return samples;
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
  }

  @override
  Future<List<PreparednessReminder>> getReminders() async {
    final preferences = await _preferences;
    final cached = preferences.getString(_remindersKey);
    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map(
            (value) => PreparednessReminder.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    }
    final samples = _sampleReminders();
    await preferences.setString(
      _remindersKey,
      jsonEncode(samples.map((reminder) => reminder.toJson()).toList()),
    );
    return samples;
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
  }

  @override
  Future<List<ChecklistItem>> getChecklistForUser(String userId) async {
    final preferences = await _preferences;
    final cached = preferences.getString('$_userChecklistPrefix$userId');
    if (cached == null) {
      final profile = await getRiskProfile(userId);
      final generated = await generateChecklistForProfile(profile);
      await saveChecklistForUser(userId, generated);
      return generated;
    }
    return (jsonDecode(cached) as List)
        .map(
          (value) =>
              ChecklistItem.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
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
    final householdSize = (profile['householdSize'] ?? '3-4').toString();
    if (householdSize == '5+') tags.add('large-household');
    if ((profile['hasElderlyMember'] as bool? ?? false))
      tags.add('elderly-household');
    if ((profile['hasDisabledMember'] as bool? ?? false))
      tags.add('disabled-household');
    if (!((profile['hasVehicle'] as bool? ?? true))) tags.add('no-vehicle');
    return tags;
  }

  List<PreparednessGuide> _sampleGuides() {
    final now = DateTime.now();
    return [
      PreparednessGuide(
        id: 'guide-flood-basics',
        title: 'Before the water rises',
        category: GuideCategory.flood,
        bodyContent:
            '# Before a flood\n\nMove valuables and documents to a high shelf. Pack medication, water, a torch and charged power banks.\n\n## When an alert arrives\n- Switch off electricity if it is safe.\n- Follow the marked route to your nearest safe zone.\n- Never walk or drive through floodwater.',
        coverImageUrl: '',
        zoneTags: const [],
        createdBy: 'SafeZone Authority',
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now,
        isArchived: false,
      ),
      PreparednessGuide(
        id: 'guide-family-kit',
        title: 'Build a family go-bag',
        category: GuideCategory.general,
        bodyContent:
            '# Keep essentials together\n\nStore a small bag near an exit. Include drinking water, shelf-stable food, first-aid supplies, copies of important documents and a written contact list.\n\nCheck the bag every six months and replace expired items.',
        coverImageUrl: '',
        zoneTags: const [],
        createdBy: 'SafeZone Authority',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
        isArchived: false,
      ),
    ];
  }

  List<EvacuationRoute> _sampleRoutes() {
    final now = DateTime.now();
    return [
      EvacuationRoute(
        id: 'route-colombo-demo',
        zoneId: 'zone-demo',
        startPoint: const LatLng(6.9344, 79.8500),
        safeZonePoint: const LatLng(6.9415, 79.8612),
        routePolyline: const [
          LatLng(6.9344, 79.8500),
          LatLng(6.9372, 79.8536),
          LatLng(6.9390, 79.8574),
          LatLng(6.9415, 79.8612),
        ],
        instructions: const [
          'Head east along the marked main road.',
          'Turn left at the community clinic.',
          'Continue to the elevated school safe zone.',
        ],
        lastUpdated: now,
      ),
      EvacuationRoute(
        id: 'route-default-demo',
        zoneId: 'default',
        startPoint: const LatLng(6.9344, 79.8500),
        safeZonePoint: const LatLng(6.9415, 79.8612),
        routePolyline: const [
          LatLng(6.9344, 79.8500),
          LatLng(6.9372, 79.8536),
          LatLng(6.9390, 79.8574),
          LatLng(6.9415, 79.8612),
        ],
        instructions: const [
          'Head east along the marked main road.',
          'Turn left at the community clinic.',
          'Continue to the elevated school safe zone.',
        ],
        lastUpdated: now,
      ),
    ];
  }

  List<DisasterHistoryRecord> _sampleHistory() {
    final now = DateTime.now();
    return [
      DisasterHistoryRecord(
        id: 'history-2024-flood',
        zoneId: 'zone-demo',
        disasterType: 'Urban flooding',
        date: DateTime(now.year - 1, 10, 18),
        severity: 'Orange',
        summary:
            'Heavy rainfall caused localized road flooding. Residents used the eastern school route.',
      ),
      DisasterHistoryRecord(
        id: 'history-2023-storm',
        zoneId: 'zone-demo',
        disasterType: 'Severe storm',
        date: DateTime(now.year - 2, 5, 7),
        severity: 'Yellow',
        summary:
            'Strong winds prompted a precautionary shelter notice. No injuries were reported.',
      ),
    ];
  }

  List<ChecklistItem> _sampleChecklistItems() {
    return [
      ChecklistItem(
        id: 'cnt-1',
        title: 'Review flood-safe locations and emergency contacts',
        description:
            'Confirm where your household will go and who to call first.',
        riskFactorTags: const ['riverside', 'low-lying', 'large-household'],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-2',
        title: 'Move valuables and documents to higher shelves',
        description:
            'Keep passports, IDs, and key documents above likely flood lines.',
        riskFactorTags: const ['riverside', 'low-lying'],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-3',
        title: 'Plan for elderly or high-needs household members',
        description:
            'Agree on who will help with mobility, medications, or transport.',
        riskFactorTags: const ['elderly-household', 'disabled-household'],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-4',
        title: 'Confirm a no-vehicle evacuation backup plan',
        description:
            'Identify a neighbour, carpool, or community pickup route.',
        riskFactorTags: const ['no-vehicle'],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-5',
        title: 'Keep your go-bag ready and accessible',
        description: 'Review food, water, medication, torch, radio, and cash.',
        riskFactorTags: const [],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-6',
        title: 'Charge torches, power banks, and radios',
        description:
            'Ensure every essential device is ready before the next rain event.',
        riskFactorTags: const [],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-7',
        title: 'Set a family reunion point',
        description:
            'Agree where everyone should meet if separated during an evacuation.',
        riskFactorTags: const ['large-household', 'elderly-household'],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-8',
        title: 'Check your vehicle, fuel, and safe-route plan',
        description: 'Keep your vehicle topped up and route options confirmed.',
        riskFactorTags: const ['large-household'],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-9',
        title: 'Review health and mobility support needs',
        description:
            'Confirm who will assist anyone with limited movement or medical needs.',
        riskFactorTags: const ['elderly-household', 'disabled-household'],
        isDone: false,
      ),
      ChecklistItem(
        id: 'cnt-10',
        title: 'Check local weather and seasonal forecast alerts',
        description: 'Keep an eye on seasonal, monsoon, or storm warnings.',
        riskFactorTags: const ['riverside', 'low-lying'],
        isDone: false,
      ),
    ];
  }

  List<PreparednessReminder> _sampleReminders() {
    final now = DateTime.now();
    return [
      PreparednessReminder(
        id: 'reminder-1',
        title: 'Monsoon season prep',
        message:
            'Check your go-bag and confirm flood-safe routes before the next storm front.',
        scheduledDate: now.add(const Duration(days: 2)),
        recurrence: ReminderRecurrence.seasonal,
        zoneTags: const ['zone-demo'],
      ),
      PreparednessReminder(
        id: 'reminder-2',
        title: 'Community drill reminder',
        message:
            'Join the neighbourhood evacuation drill and verify your plan with family members.',
        scheduledDate: now.add(const Duration(days: 12)),
        recurrence: ReminderRecurrence.monthly,
        zoneTags: const ['default'],
      ),
      PreparednessReminder(
        id: 'reminder-3',
        title: 'Emergency contact refresh',
        message:
            'Update emergency contacts and check the household check-in plan.',
        scheduledDate: now.add(const Duration(days: 7)),
        recurrence: ReminderRecurrence.none,
        zoneTags: const [],
      ),
    ];
  }
}
