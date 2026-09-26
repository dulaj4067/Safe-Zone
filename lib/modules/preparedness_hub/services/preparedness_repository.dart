import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/disaster_history_record.dart';
import '../models/evacuation_route.dart';
import '../models/preparedness_guide.dart';

abstract class PreparednessRepository {
  Future<List<PreparednessGuide>> getGuides();
  Future<void> saveGuide(PreparednessGuide guide);
  Future<void> archiveGuide(String guideId);
  Future<List<EvacuationRoute>> getRoutes();
  Future<void> saveRoute(EvacuationRoute route);
  Future<List<DisasterHistoryRecord>> getHistory(String zoneId);
  Future<String?> getActiveAlertForZone(String zoneId);
}

class LocalPreparednessRepository implements PreparednessRepository {
  static const _guidesKey = 'preparedness.guides.v1';
  static const _routesKey = 'preparedness.routes.v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<List<PreparednessGuide>> getGuides() async {
    final preferences = await _preferences;
    final cached = preferences.getString(_guidesKey);
    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map((value) => PreparednessGuide.fromJson(
              Map<String, dynamic>.from(value as Map)))
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
    await saveGuide(guide.copyWith(isArchived: true, updatedAt: DateTime.now()));
  }

  @override
  Future<List<EvacuationRoute>> getRoutes() async {
    final preferences = await _preferences;
    final cached = preferences.getString(_routesKey);
    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map((value) => EvacuationRoute.fromJson(
              Map<String, dynamic>.from(value as Map)))
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
  Future<String?> getActiveAlertForZone(String zoneId) async => null;

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

  List<PreparednessGuide> _sampleGuides() {
    final now = DateTime.now();
    return [
      PreparednessGuide(
        id: 'guide-flood-basics',
        title: 'Before the water rises',
        category: GuideCategory.flood,
        bodyContent: '# Before a flood\n\nMove valuables and documents to a high shelf. Pack medication, water, a torch and charged power banks.\n\n## When an alert arrives\n- Switch off electricity if it is safe.\n- Follow the marked route to your nearest safe zone.\n- Never walk or drive through floodwater.',
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
        bodyContent: '# Keep essentials together\n\nStore a small bag near an exit. Include drinking water, shelf-stable food, first-aid supplies, copies of important documents and a written contact list.\n\nCheck the bag every six months and replace expired items.',
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
        summary: 'Heavy rainfall caused localized road flooding. Residents used the eastern school route.',
      ),
      DisasterHistoryRecord(
        id: 'history-2023-storm',
        zoneId: 'zone-demo',
        disasterType: 'Severe storm',
        date: DateTime(now.year - 2, 5, 7),
        severity: 'Yellow',
        summary: 'Strong winds prompted a precautionary shelter notice. No injuries were reported.',
      ),
    ];
  }
}