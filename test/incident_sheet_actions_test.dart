import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/models/incident.dart';
import 'package:safezone/widgets/incident_detail_sheet.dart';

Incident _incident() => Incident(
      id: 'i1',
      reporterId: 'r1',
      category: IncidentCategory.waterlogging,
      latitude: 6.95,
      longitude: 79.92,
      status: IncidentStatus.pending,
      credibilityScore: 2,
      isSos: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onConfirm, VoidCallback? onVerify}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IncidentDetailSheet(
          incident: _incident(),
          onConfirm: onConfirm,
          onVerify: onVerify,
          onViewDetails: () {},
        ),
      ),
    ));
  }

  testWidgets('Confirm and Verify call their handlers', (tester) async {
    var confirmed = 0, verified = 0;
    await pump(tester, onConfirm: () => confirmed++, onVerify: () => verified++);

    await tester.tap(find.byKey(const Key('incident_confirm_button')));
    await tester.tap(find.byKey(const Key('incident_verify_button')));
    expect([confirmed, verified], [1, 1]);
  });

  testWidgets('buttons that do not apply are not shown', (tester) async {
    await pump(tester); // e.g. your own report, or a citizen
    expect(find.byKey(const Key('incident_confirm_button')), findsNothing);
    expect(find.byKey(const Key('incident_verify_button')), findsNothing);
    expect(find.text('View Details'), findsOneWidget);
  });
}
