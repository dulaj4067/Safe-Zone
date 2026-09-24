import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/models/alert_delivery_result.dart';
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
  bool shouldThrow = false;
  DisasterAlert? lastAlert;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> requestNotificationPolicyAccess() async {}

  @override
  Future<void> showCriticalAlert(DisasterAlert alert) async {
    if (shouldThrow) throw Exception('Simulated push notification channel failure');
    criticalCount++;
    lastAlert = alert;
  }

  @override
  Future<void> showNormalAlert(DisasterAlert alert) async {
    if (shouldThrow) throw Exception('Simulated push notification channel failure');
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
    String? affectedZoneId,
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
      instructions: 'Move to elevated ground immediately.',
      source: 'manual',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('Multi-Channel Fallback - Unit Tests', () {
    test('Requirement: OFF by default in AlertService and AlertProvider', () async {
      final service = AlertService();
      final defaultPref = await service.getMultiChannelFallback();
      expect(defaultPref, isFalse, reason: 'Multi-channel fallback must be OFF by default');

      final provider = AlertProvider(service: service);
      expect(provider.multiChannelFallback, isFalse,
          reason: 'AlertProvider.multiChannelFallback must be false by default');
    });

    test('Requirement: Save and retrieve preference using SharedPreferences', () async {
      final service = AlertService();

      await service.saveMultiChannelFallback(true);
      expect(await service.getMultiChannelFallback(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AlertService.prefMultiChannelFallback), isTrue);

      await service.saveMultiChannelFallback(false);
      expect(await service.getMultiChannelFallback(), isFalse);
      expect(prefs.getBool(AlertService.prefMultiChannelFallback), isFalse);
    });

    test('Requirement: Changes take effect immediately without restarting the app', () async {
      final provider = AlertProvider();

      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      // Toggling ON notifies listeners immediately
      await provider.setMultiChannelFallback(true);
      expect(notifyCount, greaterThan(0));
      expect(provider.multiChannelFallback, isTrue);

      // Toggling OFF notifies listeners immediately
      final countBefore = notifyCount;
      await provider.setMultiChannelFallback(false);
      expect(notifyCount, greaterThan(countBefore));
      expect(provider.multiChannelFallback, isFalse);
    });

    test('Multi-Channel Delivery: Primary push succeeds (fallback not triggered)', () async {
      final mockNotifier = _MockNotificationService();
      final provider = AlertProvider(notificationService: mockNotifier);
      await provider.setMultiChannelFallback(true);

      final alert = createAlert(id: 'alert-normal', title: 'Rising River Notice');
      final result = await provider.deliverAlert(alert);

      expect(result.primarySucceeded, isTrue);
      expect(result.fallbackTriggered, isFalse);
      expect(result.isDelivered, isTrue);
      expect(result.channelsUsed, contains(DeliveryChannel.push));
      expect(result.channelsUsed, contains(DeliveryChannel.inApp));
      expect(result.channelsUsed.contains(DeliveryChannel.sms), isFalse);
      expect(mockNotifier.normalCount, 1);
    });

    test('Multi-Channel Delivery: Primary push fails when fallback is OFF (no fallback)', () async {
      final mockNotifier = _MockNotificationService()..shouldThrow = true;
      final provider = AlertProvider(notificationService: mockNotifier);

      // Explicitly ensure fallback is OFF (default)
      await provider.setMultiChannelFallback(false);

      final alert = createAlert(id: 'alert-fail-off', title: 'Severe Storm Alert');
      final result = await provider.deliverAlert(alert);

      expect(result.primarySucceeded, isFalse);
      expect(result.fallbackTriggered, isFalse);
      expect(result.channelsUsed.contains(DeliveryChannel.sms), isFalse);
      expect(result.failureReason, isNotNull);
    });

    test('Multi-Channel Delivery: Primary push fails when fallback is ON (automatic fallback triggered)',
        () async {
      final mockNotifier = _MockNotificationService()..shouldThrow = true;
      final provider = AlertProvider(notificationService: mockNotifier);

      // Citizen opts into multi-channel fallback
      await provider.setMultiChannelFallback(true);

      final alert = createAlert(id: 'alert-fail-on', title: 'Critical Flash Flood');
      final result = await provider.deliverAlert(alert);

      // Citizen still receives warning via fallback channels!
      expect(result.primarySucceeded, isFalse);
      expect(result.fallbackTriggered, isTrue);
      expect(result.isDelivered, isTrue);
      expect(result.channelsUsed, contains(DeliveryChannel.sms));
      expect(result.channelsUsed, contains(DeliveryChannel.inApp));
      expect(provider.bannerAlert?.id, alert.id);
      expect(provider.lastDeliveryResult?.fallbackTriggered, isTrue);
    });
  });

  group('Multi-Channel Fallback - SettingsScreen Widget Tests', () {
    testWidgets('Renders single switch in SettingsScreen, OFF by default, toggles immediately without restart',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = AlertProvider();
      final zones = [
        Zone(id: 'zone-1', name: 'Kelani Basin Zone'),
      ];

      final user = AppUser(
        id: 'user-1',
        fullName: 'Citizen Dinuka',
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

      // Verify the single switch is present
      final switchFinder = find.byKey(const Key('multi_channel_fallback_switch'));
      expect(switchFinder, findsOneWidget);
      expect(find.text('Multi-Channel Alert Fallback'), findsOneWidget);

      // Verify requirement: OFF by default
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);

      // Tap to toggle ON
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify provider state updated immediately without restart
      expect(provider.multiChannelFallback, isTrue);
      final updatedSwitch = tester.widget<SwitchListTile>(switchFinder);
      expect(updatedSwitch.value, isTrue);

      // Tap to toggle OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify provider state is OFF again
      expect(provider.multiChannelFallback, isFalse);
      final offSwitch = tester.widget<SwitchListTile>(switchFinder);
      expect(offSwitch.value, isFalse);
    });
  });
}
