import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safezone/providers/incident_provider.dart';
import 'package:safezone/screens/sos_screen.dart';

void main() {
  testWidgets('report incident instead opens the form in SOS mode', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => IncidentProvider(),
        child: const MaterialApp(
          home: Scaffold(body: SosScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Report Incident Instead'));
    await tester.pumpAndSettle();

    expect(find.text('Report Incident'), findsOneWidget);
    expect(find.text("I'm Trapped / Emergency SOS"), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
  });
}