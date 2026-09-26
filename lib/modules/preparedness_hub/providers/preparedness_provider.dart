import 'package:flutter/foundation.dart';

import '../models/disaster_history_record.dart';
import '../models/evacuation_route.dart';
import '../models/preparedness_guide.dart';
import '../services/preparedness_repository.dart';

class PreparednessProvider extends ChangeNotifier {
  PreparednessProvider({required this._repository});

  final PreparednessRepository _repository;
  List<PreparednessGuide> _guides = [];
  List<EvacuationRoute> _routes = [];
  bool _isLoading = false;
  bool _isOffline = false;

  List<PreparednessGuide> get guides => List.unmodifiable(_guides);
  List<EvacuationRoute> get routes => List.unmodifiable(_routes);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  List<PreparednessGuide> guidesForZone(String? zoneId) => _guides
      .where((guide) =>
          !guide.isArchived &&
          (guide.zoneTags.isEmpty ||
              zoneId == null ||
              guide.zoneTags.contains(zoneId)))
      .toList();

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _guides = await _repository.getGuides();
      _routes = await _repository.getRoutes();
      _isOffline = false;
    } catch (_) {
      _isOffline = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveGuide(PreparednessGuide guide) async {
    await _repository.saveGuide(guide);
    _guides = await _repository.getGuides();
    notifyListeners();
  }

  Future<void> archiveGuide(String id) async {
    await _repository.archiveGuide(id);
    _guides = await _repository.getGuides();
    notifyListeners();
  }

  Future<void> saveRoute(EvacuationRoute route) async {
    await _repository.saveRoute(route);
    _routes = await _repository.getRoutes();
    notifyListeners();
  }

  Future<List<DisasterHistoryRecord>> historyForZone(String zoneId) =>
      _repository.getHistory(zoneId);

  Future<String?> getActiveAlertForZone(String zoneId) =>
      _repository.getActiveAlertForZone(zoneId);
}