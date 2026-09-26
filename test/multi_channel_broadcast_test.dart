import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/models/app_user.dart';
import 'package:safezone/models/zone.dart';
import 'package:safezone/providers/alert_form_provider.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/screens/admin_broadcast_screen.dart';
import 'package:safezone/screens/broadcast_dashboard_screen.dart';
import 'package:safezone/services/alert_service.dart';
import 'package:safezone/services/notification_service.dart';

class _MockNotificationService implements NotificationService {
  int criticalCount = 0;
  int normalCount = 0;
  int sirenCount = 0;
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
  Future<void> triggerSirenAlert(DisasterAlert alert) async {
    sirenCount++;
    lastAlert = alert;
  }

  @override
  Future<void> cancelAlert(String alertId) async {}

  @override
  Future<void> cancelAll() async {}
}

class _MockAlertService extends AlertService {
  DisasterAlert? createdAlert;
  BroadcastDispatchResult? lastDispatchResult;

  @override
  Future<DisasterAlert> createAlert(DisasterAlert draft) async {
    createdAlert = DisasterAlert(
      id: 'mock-alert-123',
      title: draft.title,
      alertType: draft.alertType,
      severity: draft.severity,
      status: draft.status,
      affectedZoneId: draft.affectedZoneId,
      centerLat: draft.centerLat,
      centerLng: draft.centerLng,
      radiusMeters: draft.radiusMeters,
      instructions: draft.instructions,
      source: draft.source,
      createdBy: 'mock-user-admin',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return createdAlert!;
  }

  @override
  Future<BroadcastDispatchResult> dispatchMultiChannelBroadcast({
    required DisasterAlert alert,
    bool sendPush = true,
    bool sendSms = true,
    bool triggerSiren = true,
    NotificationService? notificationService,
  }) async {
    final res = await super.dispatchMultiChannelBroadcast(
      alert: alert,
      sendPush: sendPush,
      sendSms: sendSms,
      triggerSiren: triggerSiren,
      notificationService: notificationService,
    );
    lastDispatchResult = res;
    return res;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  DisasterAlert createSampleAlert({
    required String id,
    required String title,
    AlertSeverity severity = AlertSeverity.red,
  }) {
    return DisasterAlert(
      id: id,
      title: title,
      alertType: 'flood',
      severity: severity,
      status: AlertStatus.active,
      affectedZoneId: 'zone-kelani',
      centerLat: 6.95,
      centerLng: 79.91,
      radiusMeters: 3000,
      instructions: 'Evacuate immediately to higher ground.',
      source: 'manual',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('Multi-Channel Broadcast - AlertFormProvider Unit Tests', () {
    test('Push, SMS, and Siren channels are all enabled by default for maximum reach', () {
      final form = AlertFormProvider();

      expect(form.dispatchPush, isTrue, reason: 'Push notification channel must be active by default');
      expect(form.dispatchSms, isTrue, reason: 'SMS cellular channel must be active by default');
      expect(form.dispatchSiren, isTrue, reason: 'Siren-trigger channel must be active by default');
      expect(form.selectedChannelsCount, 3);
      expect(form.hasSelectedChannel, isTrue);
    });

    test('Can toggle individual channels on and off and select all', () {
      final form = AlertFormProvider();

      form.togglePush(false);
      expect(form.dispatchPush, isFalse);
      expect(form.selectedChannelsCount, 2);

      form.toggleSms(false);
      expect(form.dispatchSms, isFalse);
      expect(form.selectedChannelsCount, 1);

      form.toggleSiren(false);
      expect(form.dispatchSiren, isFalse);
      expect(form.selectedChannelsCount, 0);
      expect(form.hasSelectedChannel, isFalse);

      form.selectAllChannels();
      expect(form.dispatchPush, isTrue);
      expect(form.dispatchSms, isTrue);
      expect(form.dispatchSiren, isTrue);
      expect(form.selectedChannelsCount, 3);
      expect(form.hasSelectedChannel, isTrue);
    });

    test('Form validation requires at least one channel selected', () {
      final form = AlertFormProvider();
      form.updateTitle('Severe Flood Alert');
      form.setCustomCenter(6.9271, 79.8612);

      expect(form.isValid, isTrue);

      // Disable all channels
      form.togglePush(false);
      form.toggleSms(false);
      form.toggleSiren(false);

      expect(form.isValid, isFalse, reason: 'Form must be invalid when no delivery channels are selected');

      // Re-enable one channel
      form.togglePush(true);
      expect(form.isValid, isTrue);
    });

    test('Reset restores all channels to enabled state', () {
      final form = AlertFormProvider();
      form.togglePush(false);
      form.toggleSms(false);
      form.toggleSiren(false);
      expect(form.selectedChannelsCount, 0);

      form.reset();
      expect(form.dispatchPush, isTrue);
      expect(form.dispatchSms, isTrue);
      expect(form.dispatchSiren, isTrue);
      expect(form.selectedChannelsCount, 3);
    });
  });

  group('Multi-Channel Broadcast - AlertService & NotificationService Tests', () {
    test('dispatchMultiChannelBroadcast executes across Push, SMS, and Siren channels', () async {
      final mockNotifier = _MockNotificationService();
      final service = AlertService();
      final alert = createSampleAlert(id: 'alert-dispatch-1', title: 'Severe Cyclone Alert');

      final result = await service.dispatchMultiChannelBroadcast(
        alert: alert,
        sendPush: true,
        sendSms: true,
        triggerSiren: true,
        notificationService: mockNotifier,
      );

      expect(result.pushSent, isTrue);
      expect(result.smsDispatched, isTrue);
      expect(result.sirenTriggered, isTrue);
      expect(result.channelsCount, 3);
      expect(mockNotifier.criticalCount, 1);
      expect(mockNotifier.sirenCount, 1);
      expect(result.summary, contains('Push Notification'));
      expect(result.summary, contains('SMS Broadcast'));
      expect(result.summary, contains('Siren Trigger'));
    });

    test('dispatchMultiChannelBroadcast respects disabled channels', () async {
      final mockNotifier = _MockNotificationService();
      final service = AlertService();
      final alert = createSampleAlert(id: 'alert-dispatch-2', title: 'Minor Advisory', severity: AlertSeverity.yellow);

      final result = await service.dispatchMultiChannelBroadcast(
        alert: alert,
        sendPush: true,
        sendSms: false,
        triggerSiren: false,
        notificationService: mockNotifier,
      );

      expect(result.pushSent, isTrue);
      expect(result.smsDispatched, isFalse);
      expect(result.sirenTriggered, isFalse);
      expect(result.channelsCount, 1);
      expect(mockNotifier.normalCount, 1);
      expect(mockNotifier.criticalCount, 0);
      expect(mockNotifier.sirenCount, 0);
      expect(result.summary, equals('Dispatched across Push Notification'));
    });
  });

  group('Multi-Channel Broadcast - AdminBroadcastScreen Widget Tests', () {
    testWidgets('Renders Delivery Channels section with all 3 channels active by default',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final admin = AppUser(
        id: 'admin-1',
        fullName: 'Disaster Officer',
        phone: '0771234567',
        role: UserRole.authority,
        zoneId: 'zone-kelani',
      );

      final zone = Zone(
        id: 'zone-kelani',
        name: 'Kelani Basin Zone',
        centroidLat: 6.95,
        centroidLng: 79.91,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminBroadcastScreen(
            currentUser: admin,
            zones: [zone],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify delivery channel section elements
      expect(find.text('Delivery Channels'), findsOneWidget);
      expect(find.text('All Channels Active'), findsOneWidget);
      expect(find.text('Push Notification'), findsOneWidget);
      expect(find.text('SMS Cellular Broadcast'), findsOneWidget);
      expect(find.text('Siren-Trigger Channel'), findsOneWidget);

      // Verify submit button indicates all 3 channels
      expect(find.text('Dispatch Broadcast (All 3 Channels)'), findsOneWidget);
    });

    testWidgets('Toggling delivery channel updates channel count and submit button text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final admin = AppUser(
        id: 'admin-1',
        fullName: 'Disaster Officer',
        phone: '0771234567',
        role: UserRole.authority,
      );

      final zone = Zone(
        id: 'zone-kelani',
        name: 'Kelani Basin Zone',
        centroidLat: 6.95,
        centroidLng: 79.91,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminBroadcastScreen(
            currentUser: admin,
            zones: [zone],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Siren channel tile to turn it off
      final sirenTile = find.byKey(const Key('channel_siren_tile'));
      expect(sirenTile, findsOneWidget);
      await tester.tap(sirenTile);
      await tester.pumpAndSettle();

      // Channel count updates to 2/3 Active
      expect(find.text('2/3 Active'), findsOneWidget);
      expect(find.text('Dispatch Broadcast (2 Channels)'), findsOneWidget);
      expect(find.byKey(const Key('select_all_channels_btn')), findsOneWidget);

      // Tap Select All to restore all channels
      await tester.tap(find.byKey(const Key('select_all_channels_btn')));
      await tester.pumpAndSettle();

      expect(find.text('All Channels Active'), findsOneWidget);
      expect(find.text('Dispatch Broadcast (All 3 Channels)'), findsOneWidget);
    });
  });

  group('Multi-Channel Broadcast - BroadcastDashboardScreen Badges', () {
    testWidgets('Renders Push, SMS, and Siren delivery channel badges on active broadcast cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final alert = DisasterAlert(
        id: 'alert-card-1',
        title: 'Emergency River Warning',
        alertType: 'flood',
        severity: AlertSeverity.red,
        status: AlertStatus.active,
        affectedZoneId: 'zone-kelani',
        centerLat: 6.95,
        centerLng: 79.91,
        radiusMeters: 3000,
        instructions: 'Evacuate low lying areas immediately.',
        source: 'manual',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final zone = Zone(
        id: 'zone-kelani',
        name: 'Kelani Basin Zone',
        centroidLat: 6.95,
        centroidLng: 79.91,
      );

      final provider = AlertProvider();
      provider.activeAlerts.add(alert);

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider,
          child: MaterialApp(
            home: BroadcastDashboardScreen(zones: [zone]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify broadcast card rendered with delivery channel badges
      expect(find.text('Emergency River Warning'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Siren'), findsOneWidget);
    });
  });
}
