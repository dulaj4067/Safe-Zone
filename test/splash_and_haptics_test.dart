import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/utils/severity_haptics.dart';
import 'package:safezone/widgets/splash_screen.dart';

void main() {
  testWidgets('splash shows a large logo and the company name at the bottom', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    final logo = tester.getSize(find.byKey(const Key('splash_logo')));
    expect(logo.width, SplashScreen.logoSize);
    expect(SplashScreen.logoSize, greaterThan(96));
    final company = tester.getCenter(find.byKey(const Key('splash_company')));
    final tagline = tester.getCenter(find.text('Sri Lanka Disaster Early Warning'));
    expect(company.dy, greaterThan(tagline.dy + 100), reason: 'company name sits at the foot');
    expect(find.text('The Pioneers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('severity haptics', () {
    late List<String> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
          return null;
        },
      );
    });

    test('each severity has its own pattern', () async {
      await playSeverityHaptic(AlertSeverity.green);
      expect(calls, ['HapticFeedbackType.selectionClick']);

      calls.clear();
      await playSeverityHaptic(AlertSeverity.yellow);
      expect(calls, ['HapticFeedbackType.mediumImpact']);

      calls.clear();
      await playSeverityHaptic(AlertSeverity.orange);
      expect(calls, ['HapticFeedbackType.heavyImpact', 'HapticFeedbackType.heavyImpact']);

      calls.clear();
      await playSeverityHaptic(AlertSeverity.red);
      expect(calls.length, 4);
      expect(calls.toSet(), {'HapticFeedbackType.heavyImpact'});
    });

    test('green and yellow respect the haptics setting; orange and red always play', () async {
      await playSeverityHaptic(AlertSeverity.green, enabled: false);
      await playSeverityHaptic(AlertSeverity.yellow, enabled: false);
      expect(calls, isEmpty);

      await playSeverityHaptic(AlertSeverity.orange, enabled: false);
      expect(calls.length, 2);
      calls.clear();
      await playSeverityHaptic(AlertSeverity.red, enabled: false);
      expect(calls.length, 4);
    });
  });
}
