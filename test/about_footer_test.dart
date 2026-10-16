import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:safezone/widgets/about_footer.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'SafeZone',
      packageName: 'com.example.focus_app',
      version: '2.4.1',
      buildNumber: '37',
      buildSignature: '',
    );
  });

  testWidgets('shows the logo, the real version, copyright and legal links', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AboutFooter()))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pioneers_logo')), findsOneWidget);
    expect(find.text('SafeZone · Version 2.4.1 (37)'), findsOneWidget);
    expect(find.textContaining('The Pioneers. All rights reserved.'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('legal links open the policy documents', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AboutFooter()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about_terms')));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsWidgets);
    expect(find.textContaining('Version'), findsWidgets);
  });
}
