import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safezone/services/activity_history_service.dart';
import 'package:safezone/widgets/resume_dropdown.dart';

void main() {
  testWidgets('resume dropdown hides when empty and shows badge count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResumeDropdown(
          items: const [],
          onResume: (_) {},
        ),
      ),
    );

    expect(find.text('Resume where you left off'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: ResumeDropdown(
          items: [
            ResumeItem(
              id: 'route-1',
              type: ResumeItemType.route,
              title: 'Route in progress',
              subtitle: '4 min ago',
              timestamp: DateTime.now(),
              routeOrDraftRef: 'route-1',
            ),
            ResumeItem(
              id: 'hazard-204',
              type: ResumeItemType.report,
              title: 'Hazard report #204 — photo pending',
              subtitle: '2 min ago',
              timestamp: DateTime.now(),
              routeOrDraftRef: 'hazard-204',
            ),
          ],
          onResume: (_) {},
        ),
      ),
    );

    expect(find.text('Resume where you left off'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('resume dropdown stays collapsed when emergency alert is active', (tester) async {
    final items = [
      ResumeItem(
        id: 'route-1',
        type: ResumeItemType.route,
        title: 'Route in progress',
        subtitle: '4 min ago',
        timestamp: DateTime.now(),
        routeOrDraftRef: 'route-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ResumeDropdown(
          items: items,
          onResume: (_) {},
          hasEmergencyAlert: true,
        ),
      ),
    );

    expect(find.text('Route in progress'), findsNothing);
    expect(find.text('Resume where you left off'), findsOneWidget);
  });
}
