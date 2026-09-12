import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/models/app_user.dart';
import 'package:safezone/models/zone.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/providers/auth_provider.dart';
import 'package:safezone/providers/incident_provider.dart';
import 'package:safezone/screens/settings_screen.dart';
import 'package:safezone/services/alert_service.dart';
import 'package:safezone/services/notification_service.dart';

class _MockNotificationService implements NotificationService {
  int criticalCount = 0;
  int normalCount = 0;
  DisasterAlert? lastAlert;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> requestNotificationPolicyAccess() async {}

  @override
  Future<void> showCriticalAlert(DisasterAlert alert) async {
    criticalCount++;
    lastAlert = alert;
  }

  @override
  Future<void> showNormalAlert(DisasterAlert alert) async {
    normalCount++;
    lastAlert = alert;
  }

  @override
  Future<void> cancelAlert(String alertId) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  DisasterAlert createAlert({
    required String id,
    required String title,
    required String? affectedZoneId,
    AlertSeverity severity = AlertSeverity.orange,
  }) {
    return DisasterAlert(
      id: id,
      title: title,
      alertType: 'flood',
      severity: severity,
      status: AlertStatus.active,
      affectedZoneId: affectedZoneId,
      centerLat: 6.9271,
      centerLng: 79.8612,
      radiusMeters: 2000,
      instructions: 'Evacuate low lying areas immediately.',
      source: 'manual',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('My Zone Alerts Only - Unit Tests', () {
    test('Requirement: OFF by default in AlertService and AlertProvider', () async {
      final service = AlertService();
      final defaultPref = await service.getMyZoneAlertsOnly();
      expect(defaultPref, isFalse, reason: 'Preference must be false by default');

      final provider = AlertProvider(service: service);
      expect(provider.myZoneOnly, isFalse, reason: 'AlertProvider.myZoneOnly must be false by default');
    });

    test('Requirement: Save and retrieve preference using SharedPreferences', () async {
      final service = AlertService();

      await service.saveMyZoneAlertsOnly(true);
      expect(await service.getMyZoneAlertsOnly(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AlertService.prefMyZoneAlertsOnly), isTrue);

      await service.saveMyZoneAlertsOnly(false);
      expect(await service.getMyZoneAlertsOnly(), isFalse);
      expect(prefs.getBool(AlertService.prefMyZoneAlertsOnly), isFalse);
    });

    test('Requirement: Filter alerts by citizen zone', () {
      final service = AlertService();
      final alert1 = createAlert(id: 'a1', title: 'Zone A Alert', affectedZoneId: 'zone-A');
      final alert2 = createAlert(id: 'a2', title: 'Zone B Alert', affectedZoneId: 'zone-B');
      final alert3 = createAlert(id: 'a3', title: 'Zone A Alert 2', affectedZoneId: 'zone-A');

      final allAlerts = [alert1, alert2, alert3];

      final filteredA = service.filterAlertsByZone(allAlerts, 'zone-A');
      expect(filteredA, [alert1, alert3]);

      final filteredB = service.filterAlertsByZone(allAlerts, 'zone-B');
      expect(filteredB, [alert2]);

      // If zoneId is null, returns all alerts
      expect(service.filterAlertsByZone(allAlerts, null), allAlerts);
    });

    test('Requirement: AlertProvider.activeAlerts filters when ON and returns all when OFF', () async {
      final alertA = createAlert(id: 'a1', title: 'Zone A Alert', affectedZoneId: 'zone-A');
      final alertB = createAlert(id: 'a2', title: 'Zone B Alert', affectedZoneId: 'zone-B');

      final provider = AlertProvider();
      provider.activeAlerts.addAll([alertA, alertB]);

      // OFF by default: shows all alerts
      expect(provider.myZoneOnly, isFalse);
      expect(provider.activeAlerts.length, 2);

      // Set user designated zone and turn ON
      await provider.setUserZoneId('zone-A');
      await provider.setMyZoneOnly(true);

      expect(provider.myZoneOnly, isTrue);
      expect(provider.activeAlerts.length, 1);
      expect(provider.activeAlerts.first.id, 'a1');
      expect(provider.activeAlerts.first.affectedZoneId, 'zone-A');

      // Turn OFF: immediately restores all alerts without restart
      await provider.setMyZoneOnly(false);
      expect(provider.activeAlerts.length, 2);
    });

    test('Requirement: Changes take effect immediately without restarting the app', () async {
      final alertA = createAlert(id: 'a1', title: 'Kelani Alert', affectedZoneId: 'zone-kelani');
      final alertB = createAlert(id: 'a2', title: 'Kaduwela Alert', affectedZoneId: 'zone-kaduwela');

      final provider = AlertProvider();
      provider.activeAlerts.addAll([alertA, alertB]);
      await provider.setUserZoneId('zone-kelani');

      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      // Toggling ON notifies listeners immediately
      await provider.setMyZoneOnly(true);
      expect(notifyCount, greaterThan(0));
      expect(provider.activeAlerts, [alertA]);

      // Toggling OFF notifies listeners immediately
      final countBefore = notifyCount;
      await provider.setMyZoneOnly(false);
      expect(notifyCount, greaterThan(countBefore));
      expect(provider.activeAlerts, [alertA, alertB]);
    });

    test('Requirement: Show and notify only alerts affecting the citizen zone when ON', () async {
      final mockNotifier = _MockNotificationService();
      final provider = AlertProvider(notificationService: mockNotifier);

      await provider.setUserZoneId('zone-colombo');
      await provider.setMyZoneOnly(true);

      final otherZoneAlert = createAlert(
        id: 'alert-kandy',
        title: 'Kandy Flood Warning',
        affectedZoneId: 'zone-kandy',
        severity: AlertSeverity.red,
      );

      expect(provider.alertAffectsMyZone(otherZoneAlert), isFalse);

      final myZoneAlert = createAlert(
        id: 'alert-colombo',
        title: 'Colombo Flash Flood',
        affectedZoneId: 'zone-colombo',
        severity: AlertSeverity.red,
      );
      expect(provider.alertAffectsMyZone(myZoneAlert), isTrue);
    });

    test('Requirement: Dismisses existing banner if toggled ON for an alert outside citizen zone', () async {
      final provider = AlertProvider();
      final outsideAlert = createAlert(id: 'out-1', title: 'Outside Zone Alert', affectedZoneId: 'zone-outside');

      // Banner was showing outside alert
      provider.activeAlerts.add(outsideAlert);
      // Turn ON with citizen zone 'zone-mine'
      await provider.setUserZoneId('zone-mine');
      await provider.setMyZoneOnly(true);

      // Verify banner sync cleared it
      expect(provider.bannerAlert, isNull);
    });
  });

  group('My Zone Alerts Only - SettingsScreen Widget Tests', () {
    testWidgets('Renders "My Zone Alerts Only" switch in SettingsScreen and toggles state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = AlertProvider();
      final zones = [
        Zone(id: 'zone-1', name: 'Kelani Basin Zone'),
        Zone(id: 'zone-2', name: 'Kalu Ganga Zone'),
      ];

      final user = AppUser(
        id: 'user-1',
        fullName: 'Perera Citizen',
        phone: '0771234567',
        role: UserRole.member,
        zoneId: 'zone-1',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AlertProvider>.value(value: provider),
            ChangeNotifierProvider<IncidentProvider>(create: (_) => IncidentProvider()),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: SettingsScreen(
              currentUser: user,
              zones: zones,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the switch is present
      final switchFinder = find.byKey(const Key('my_zone_alerts_only_switch'));
      expect(switchFinder, findsOneWidget);
      expect(find.text('My Zone Alerts Only'), findsOneWidget);

      // Verify it is OFF by default
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);

      // Tap to toggle ON
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify provider state updated
      expect(provider.myZoneOnly, isTrue);

      // Verify designated zone dropdown appears
      expect(find.byKey(const Key('designated_zone_dropdown')), findsOneWidget);
      expect(find.text('Kelani Basin Zone'), findsWidgets);

      // Tap to toggle OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify provider state is OFF again
      expect(provider.myZoneOnly, isFalse);
    });
  });
}
