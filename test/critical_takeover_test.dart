import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/services/siren_player.dart';
import 'package:safezone/widgets/critical_alert_takeover.dart';

class _FakeSiren implements SirenPlayer {
  final events = <String>[];
  @override
  Future<void> start() async => events.add('start');
  @override
  Future<void> setMuted(bool muted) async => events.add(muted ? 'mute' : 'unmute');
  @override
  Future<void> stop() async => events.add('stop');
}

DisasterAlert _alert({AlertSeverity severity = AlertSeverity.red}) => DisasterAlert(
      id: 'a1',
      title: 'Severe Flooding: Colombo District',
      alertType: 'flood',
      severity: severity,
      status: AlertStatus.active,
      centerLat: 6.9553,
      centerLng: 79.9220,
      radiusMeters: 3000,
      instructions: 'Evacuate to higher ground.\n\nTranscript: Flood warning.',
      source: 'manual',
      createdAt: DateTime(2026, 10, 15),
      updatedAt: DateTime(2026, 10, 15),
    );

void main() {
  notificationLaunchTests();
  group('CriticalAlertTakeover', () {
    late int vibrations;

    setUp(() {
      vibrations = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') vibrations++;
          return null;
        },
      );
    });

    Widget host(_FakeSiren siren, {VoidCallback? onDismiss, VoidCallback? onShelter, bool sound = true}) {
      return MaterialApp(
        home: CriticalAlertTakeover(
          alert: _alert(),
          player: siren,
          sirenEnabled: sound,
          onDismiss: onDismiss ?? () {},
          onFindShelter: onShelter ?? () {},
        ),
      );
    }

    testWidgets('shows the alert, plays the siren and vibrates', (tester) async {
      final siren = _FakeSiren();
      await tester.pumpWidget(host(siren));
      expect(find.text('CRITICAL ALERT'), findsOneWidget);
      expect(find.text('Severe Flooding: Colombo District'), findsOneWidget);
      expect(find.text('Evacuate to higher ground.'), findsOneWidget);
      // The siren script has its own caption elsewhere, not in the body.
      expect(find.textContaining('Transcript'), findsNothing);
      expect(find.text('Find nearest shelter'), findsOneWidget);
      expect(find.text('Call emergency: 119'), findsOneWidget);
      expect(siren.events, ['start']);
      expect(vibrations, 1);

      await tester.pump(const Duration(milliseconds: 1300));
      expect(vibrations, 2, reason: 'repeats while the screen is up');

      await tester.pumpWidget(const SizedBox.shrink());
      expect(siren.events.last, 'stop');
    });

    testWidgets('mute toggles the siren; silent when the setting is off', (tester) async {
      final siren = _FakeSiren();
      await tester.pumpWidget(host(siren));
      await tester.tap(find.byKey(const Key('takeover_mute')));
      await tester.pump();
      expect(siren.events, ['start', 'mute']);
      await tester.tap(find.byKey(const Key('takeover_mute')));
      await tester.pump();
      expect(siren.events.last, 'unmute');

      final quiet = _FakeSiren();
      await tester.pumpWidget(host(quiet, sound: false));
      expect(quiet.events, isEmpty);
      expect(find.byKey(const Key('takeover_mute')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('dismiss and find-shelter call their callbacks', (tester) async {
      var dismissed = 0, shelter = 0;
      final siren = _FakeSiren();
      await tester.pumpWidget(host(siren, onDismiss: () => dismissed++, onShelter: () => shelter++));
      await tester.tap(find.byKey(const Key('takeover_find_shelter')));
      await tester.tap(find.byKey(const Key('takeover_dismiss')));
      expect([dismissed, shelter], [1, 1]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('fits a small phone at large text without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final siren = _FakeSiren();
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(2)),
        child: host(siren),
      ));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('AlertProvider proximity', () {
    test('unknown until there is a GPS fix, then near or far', () {
      final p = AlertProvider();
      final alert = _alert();
      expect(p.isNearby(alert), isNull);

      p.updateUserLocation(const LatLng(6.9615, 79.9010)); // inside
      expect(p.isNearby(alert), isTrue);
      p.updateUserLocation(const LatLng(6.9344, 79.8428)); // Colombo Fort, ~11 km
      expect(p.isNearby(alert), isFalse); // well outside the alert's own circle
      p.updateUserLocation(const LatLng(7.2906, 80.6337)); // Kandy
      expect(p.isNearby(alert), isFalse);
    });
  });
}

void notificationLaunchTests() {
  group('Opening an alert notification', () {
    test('a critical alert opens the takeover, others the banner', () {
      final p = AlertProvider();
      final red = _alert();
      final yellow = DisasterAlert(
        id: 'y1',
        title: 'Rain advisory',
        alertType: 'rain',
        severity: AlertSeverity.yellow,
        status: AlertStatus.active,
        centerLat: 6.9,
        centerLng: 79.9,
        radiusMeters: 1000,
        source: 'manual',
        createdAt: DateTime(2026, 10, 15),
        updatedAt: DateTime(2026, 10, 15),
      );
      p.activeAlerts.addAll([red, yellow]);

      p.openAlertFromNotification('a1');
      expect(p.criticalTakeover?.id, 'a1');

      p.dismissTakeover();
      p.openAlertFromNotification('y1');
      expect(p.criticalTakeover, isNull);
      expect(p.bannerAlert?.id, 'y1');

      // An alert that has since been resolved (or a reminder payload) is ignored.
      p.dismissBanner();
      p.openAlertFromNotification('gone');
      expect(p.bannerAlert, isNull);
      expect(p.criticalTakeover, isNull);
    });
  });
}
