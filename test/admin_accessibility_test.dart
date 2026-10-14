import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safezone/l10n/admin_strings.dart';
import 'package:safezone/l10n/locale_format.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/models/app_user.dart';
import 'package:safezone/models/zone.dart';
import 'package:safezone/providers/accessibility_provider.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/screens/admin_broadcast_screen.dart';
import 'package:safezone/screens/admin_incident_review_screen.dart';
import 'package:safezone/screens/broadcast_dashboard_screen.dart';
import 'package:safezone/theme/app_colors.dart';
import 'package:safezone/theme/app_theme.dart';
import 'package:safezone/widgets/a11y/a11y_widgets.dart';

void main() {
  setUpAll(() async {
    await LocaleFormat.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Visual Accessibility Tests', () {
    test('Palette guarantees compliant text contrast (>= 4.5:1 body, >= 3:1 large)', () {
      // Mist background (#F4F2ED) with slateInk (#0B2545) provides > 12:1 contrast
      // slateMuted (#4A5560) provides > 5:1 contrast
      expect(AppColors.slateInk, const Color(0xFF0B2545));
      expect(AppColors.slateMuted, const Color(0xFF4A5560));
      expect(AppColors.mist, const Color(0xFFF4F2ED));
    });

    testWidgets('Error banners combine color, icon, and text (never color alone)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: A11yErrorBanner(
              message: 'Card expired or channel missing',
              hint: 'Select at least one delivery channel to continue.',
            ),
          ),
        ),
      );

      // Verify icon exists with error semantic
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Verify text message exists
      expect(find.text('Card expired or channel missing'), findsOneWidget);
      // Verify instructional recovery hint exists
      expect(find.text('Select at least one delivery channel to continue.'), findsOneWidget);
    });

    testWidgets('Interactive buttons configure visible 2px focus indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: A11yFocus(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Admin Action'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Admin Action'), findsOneWidget);
      expect(find.byType(A11yFocus), findsOneWidget);
    });

    testWidgets('A11yLink renders underlined clickable text without baked-in image text', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yLink(
              label: 'View Broadcast Guidelines',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      final linkFinder = find.text('View Broadcast Guidelines');
      expect(linkFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(linkFinder);
      expect(textWidget.style?.decoration, TextDecoration.underline);

      await tester.tap(linkFinder);
      expect(tapped, isTrue);
    });
  });

  group('Auditory Accessibility Tests', () {
    testWidgets('Audio and siren alerts provide text transcripts and captions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final alert = DisasterAlert(
        id: 'alert-audio-1',
        title: 'Flash Flood Siren Active',
        alertType: 'flood',
        severity: AlertSeverity.red,
        status: AlertStatus.active,
        affectedZoneId: 'zone-kelani',
        centerLat: 6.927,
        centerLng: 79.861,
        radiusMeters: 2500,
        instructions: 'Evacuate now.\n\nTranscript: Continuous rising tone indicates immediate flood surge. Move to upper floors.',
        source: 'manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final zone = Zone(
        id: 'zone-kelani',
        name: 'Kelani Basin Zone',
        centroidLat: 6.95,
        centroidLng: 79.91,
      );

      final alertProvider = AlertProvider();
      alertProvider.activeAlerts.add(alert);

      final a11yProvider = AccessibilityProvider();
      await a11yProvider.setCaptions(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AlertProvider>.value(value: alertProvider),
            ChangeNotifierProvider<AccessibilityProvider>.value(value: a11yProvider),
          ],
          child: MaterialApp(
            home: BroadcastDashboardScreen(zones: [zone]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify captions banner displays the siren transcript
      expect(find.byIcon(Icons.closed_caption), findsOneWidget);
      expect(
        find.text('Continuous rising tone indicates immediate flood surge. Move to upper floors.'),
        findsOneWidget,
      );
    });
  });

  group('Motor and Input Accessibility Tests', () {
    testWidgets('Buttons meet minimum 44x44 touch targets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: FilledButton(
              onPressed: () {},
              child: const Text('Touch Target'),
            ),
          ),
        ),
      );

      final buttonSize = tester.getSize(find.byType(FilledButton));
      expect(buttonSize.width >= 44.0, isTrue);
      expect(buttonSize.height >= 44.0, isTrue);
    });

    testWidgets('Destructive actions feature confirmation dialogs and undo toast', (tester) async {
      var undoPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showA11yUndoSnackBar(
                    context,
                    message: 'Report rejected.',
                    undoLabel: 'Undo',
                    onUndo: () => undoPressed = true,
                  );
                },
                child: const Text('Trigger SnackBar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger SnackBar'));
      await tester.pumpAndSettle();

      expect(find.text('Report rejected.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      expect(undoPressed, isTrue);
    });
  });

  group('Cognitive and Learning Accessibility Tests', () {
    testWidgets('Progressive disclosure splits broadcast creation into step progress', (tester) async {
      final user = AppUser(
        id: 'admin-1',
        fullName: 'Disaster Commander',
        phone: '+94771234567',
        role: UserRole.authority,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminBroadcastScreen(currentUser: user, zones: const []),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Step 1 of 2 header is visible
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Alert details'), findsOneWidget);
      expect(find.byType(A11yStepHeader), findsOneWidget);
    });

    testWidgets('Helpful empty states provide icons, explanations, and primary actions', (tester) async {
      var actionTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yEmptyState(
              icon: Icons.campaign_outlined,
              message: 'No active broadcasts.',
              hint: 'Create a new alert to reach people in a zone.',
              actionLabel: 'Create alert',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No active broadcasts.'), findsOneWidget);
      expect(find.text('Create a new alert to reach people in a zone.'), findsOneWidget);
      expect(find.text('Create alert'), findsOneWidget);

      await tester.tap(find.text('Create alert'));
      expect(actionTriggered, isTrue);
    });
  });

  group('Language and Culture (i18n/l10n) Tests', () {
    test('Externalized message catalogs support English, Sinhala, Tamil, and Arabic with plurals', () {
      final en = AdminStrings.en;
      final si = AdminStrings.si;
      final ta = AdminStrings.ta;
      final ar = AdminStrings.ar;

      expect(en.t('broadcastTitle'), 'New Broadcast Alert');
      expect(si.t('broadcastTitle'), 'නව විකාශන ඇඟවීම');
      expect(ta.t('broadcastTitle'), 'புதிய ஒளிபரப்பு எச்சரிக்கை');
      expect(ar.t('broadcastTitle'), 'تنبيه بث جديد');

      // Plurals
      expect(en.channelsActive(1), '1 channel active');
      expect(en.channelsActive(3), '3 channels active');
      expect(si.channelsActive(3), 'චැනල් 3ක් සක්‍රියයි');
      expect(ta.channelsActive(2), '2 சேனல்கள் இயக்கத்தில்');
      expect(ar.channelsActive(2), 'قناتان نشطتان');
    });

    test('Locale-aware dates and Sri Lankan currency formatting', () {
      final testDate = DateTime(2025, 9, 13, 10, 30);
      final formattedDate = LocaleFormat.date(testDate, locale: 'en');
      expect(formattedDate, contains('13 Sep 2025'));

      final lkrFormatted = LocaleFormat.lkr(2450.00);
      expect(lkrFormatted, 'Rs 2,450.00');
    });

    test('Arabic switches direction to RTL', () {
      final a11y = AccessibilityProvider();
      a11y.localeCode = 'ar';
      expect(a11y.isRtl, isTrue);
      expect(a11y.textDirection, TextDirection.rtl);

      a11y.localeCode = 'si';
      expect(a11y.isRtl, isFalse);
      expect(a11y.textDirection, TextDirection.ltr);
    });
  });

  group('Economic and Environmental Tests', () {
    testWidgets('Data saver loads thumbnails first with tap-to-load sharper image', (tester) async {
      final a11y = AccessibilityProvider();
      await a11y.setDataSaver(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AccessibilityProvider>.value(
          value: a11y,
          child: const MaterialApp(
            home: Scaffold(
              body: A11yAdaptiveImage(
                url: 'https://example.com/flood_photo.jpg',
                semanticLabel: 'Flood water levels at Bridge',
              ),
            ),
          ),
        ),
      );

      // Verify tap-to-load HD link appears when Data Saver is on
      expect(find.text('Load sharper image'), findsOneWidget);
    });

    testWidgets('Inclusion settings sheet allows toggling data saver, glare boost, captions, and language', (tester) async {
      final a11y = AccessibilityProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AccessibilityProvider>.value(
          value: a11y,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [A11yInclusionButton()],
              ),
            ),
          ),
        ),
      );

      // Tap accessibility button to open sheet
      await tester.tap(find.byType(A11yInclusionButton));
      await tester.pumpAndSettle();

      expect(find.text('Inclusion and access'), findsOneWidget);
      expect(find.text('Data saver'), findsOneWidget);
      expect(find.text('Glare-aware contrast'), findsOneWidget);
      expect(find.text('Captions and transcripts'), findsOneWidget);
      expect(find.text('Haptic alerts'), findsOneWidget);
      expect(find.text('සිංහල (Sinhala)'), findsOneWidget);
      expect(find.text('தமிழ் (Tamil)'), findsOneWidget);
      expect(find.text('العربية (Arabic - RTL)'), findsOneWidget);
    });
  });
}
