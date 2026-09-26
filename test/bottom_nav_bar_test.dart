import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/widgets/bottom_nav_bar.dart';

void main() {
  testWidgets('member navigation fits one-line labels at 360px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavBar(
            currentIndex: 0,
            isAuthority: false,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigationBar.type, BottomNavigationBarType.fixed);
    expect(navigationBar.items, hasLength(5));
    expect(
      navigationBar.items.map((item) => item.label),
      ['Home', 'Incidents', 'Shelters', 'Prep Hub', 'Settings'],
    );

    for (final label in ['Home', 'Incidents', 'Shelters', 'Prep Hub', 'Settings']) {
      final labelWidget = tester.widget<Text>(
        find.descendant(
          of: find.byType(BottomNavBar),
          matching: find.text(label),
        ).first,
      );
      expect(labelWidget.maxLines, 1, reason: '$label should stay on one line');
      expect(labelWidget.overflow, TextOverflow.ellipsis);
    }
    expect(tester.takeException(), isNull);
  });
}