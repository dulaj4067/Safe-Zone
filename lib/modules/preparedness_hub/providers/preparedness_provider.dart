import 'package:flutter/foundation.dart';

import '../../../services/notification_service.dart';
import '../models/checklist_item.dart';
import '../models/disaster_history_record.dart';
import '../models/evacuation_route.dart';
import '../models/preparedness_guide.dart';
import '../models/preparedness_reminder.dart';
import '../services/preparedness_repository.dart';

class PreparednessProvider extends ChangeNotifier {
  PreparednessProvider({required this._repository});

  final PreparednessRepository _repository;
  List<PreparednessGuide> _guides = [];
  List<EvacuationRoute> _routes = [];
  List<ChecklistItem> _masterChecklistItems = [];
  List<ChecklistItem> _personalChecklist = [];
  List<PreparednessReminder> _reminders = [];
  Map<String, dynamic> _riskProfile = {};
  bool _isLoading = false;
  bool _isOffline = false;

  List<PreparednessGuide> get guides => List.unmodifiable(_guides);
  List<EvacuationRoute> get routes => List.unmodifiable(_routes);
  List<ChecklistItem> get masterChecklistItems =>
      List.unmodifiable(_masterChecklistItems);
  List<ChecklistItem> get personalChecklist =>
      List.unmodifiable(_personalChecklist);
  List<PreparednessReminder> get reminders => List.unmodifiable(_reminders);
  Map<String, dynamic> get riskProfile => Map.unmodifiable(_riskProfile);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  List<PreparednessGuide> guidesForZone(String? zoneId) => _guides
      .where(
        (guide) =>
            !guide.isArchived &&
            (guide.zoneTags.isEmpty ||
                zoneId == null ||
                guide.zoneTags.contains(zoneId)),
      )
      .toList();

  List<PreparednessReminder> upcomingRemindersForZone(String? zoneId) =>
      _repository
          .remindersForZone(_reminders, zoneId)
          .where((reminder) => !reminder.scheduledDate.isBefore(DateTime.now()))
          .toList();

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _guides = await _repository.getGuides();
      _routes = await _repository.getRoutes();
      _masterChecklistItems = await _repository.getChecklistItems();
      _reminders = await _repository.getReminders();
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

  Future<void> saveChecklistItem(ChecklistItem item) async {
    await _repository.saveChecklistItem(item);
    _masterChecklistItems = await _repository.getChecklistItems();
    notifyListeners();
  }

  Future<void> deleteChecklistItem(String id) async {
    await _repository.deleteChecklistItem(id);
    _masterChecklistItems = await _repository.getChecklistItems();
    notifyListeners();
  }

  Future<void> saveReminder(PreparednessReminder reminder) async {
    await _repository.saveReminder(reminder);
    _reminders = await _repository.getReminders();
    try {
      await NotificationService().scheduleReminderNotification(reminder);
    } catch (_) {
      // The reminder still persists locally even if the device OS blocks scheduling.
    }
    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    await _repository.deleteReminder(id);
    _reminders = await _repository.getReminders();
    try {
      await NotificationService().cancelReminder(id);
    } catch (_) {
      // The reminder is removed locally even if OS cancellation fails.
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> getRiskProfile(String userId) async =>
      _repository.getRiskProfile(userId);

  Future<void> saveRiskProfile(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    await _repository.saveRiskProfile(userId, profile);
    _riskProfile = profile;
    final generated = await _repository.generateChecklistForProfile(profile);
    await _repository.saveChecklistForUser(userId, generated);
    _personalChecklist = generated;
    notifyListeners();
  }

  Future<void> loadUserChecklist(
    String userId, {
    Map<String, dynamic>? profile,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resolvedProfile = profile != null && profile.isNotEmpty
          ? profile
          : await _repository.getRiskProfile(userId);
      _riskProfile = resolvedProfile;
      if (resolvedProfile.isEmpty) {
        _personalChecklist = await _repository.getChecklistForUser(userId);
      } else {
        _personalChecklist = await _repository.getChecklistForUser(userId);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleChecklistItem(
    String userId,
    String itemId,
    bool isDone,
  ) async {
    await _repository.toggleChecklistItem(userId, itemId, isDone);
    _personalChecklist = await _repository.getChecklistForUser(userId);
    notifyListeners();
  }

  Future<List<DisasterHistoryRecord>> historyForZone(String zoneId) =>
      _repository.getHistory(zoneId);

  Future<String?> getActiveAlertForZone(String zoneId) =>
      _repository.getActiveAlertForZone(zoneId);
}
