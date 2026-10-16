import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safezone/models/family_member.dart';
import 'package:safezone/providers/safety_provider.dart';
import 'package:safezone/screens/family_circle_screen.dart';

/// Records start/stop calls instead of touching Supabase and GPS.
class _FakeSafety extends SafetyProvider {
  _FakeSafety(this._members);
  final List<FamilyMember> _members;
  bool _sharing = false;
  int starts = 0, stops = 0;

  @override
  List<FamilyMember> get confirmedFamily => _members.where((m) => m.isConfirmed).toList();
  @override
  List<FamilyMember> get family => _members;
  @override
  bool get isSharing => _sharing;
  @override
  Future<void> loadFamilyCircle() async {}
  @override
  Future<void> startSharingEta({dynamic currentRiskZone, dynamic destination}) async {
    starts++;
    _sharing = true;
    notifyListeners();
  }

  @override
  Future<void> stopSharing() async {
    stops++;
    _sharing = false;
    notifyListeners();
  }
}

FamilyMember _member(String status) => FamilyMember(
      linkId: 'l1', memberId: 'm1', name: 'Saman Perera', status: status, invitedByMe: true);

void main() {
  Future<void> pumpScreen(WidgetTester tester, _FakeSafety safety) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<SafetyProvider>.value(
      value: safety,
      child: const MaterialApp(home: FamilyCircleScreen()),
    ));
    await tester.pump();
  }

  testWidgets('one button starts sharing in place, then becomes Stop sharing', (tester) async {
    final safety = _FakeSafety([_member('confirmed')]);
    await pumpScreen(tester, safety);

    expect(find.byKey(const Key('start_sharing_button')), findsOneWidget);
    expect(find.text('Start sharing my location'), findsOneWidget);
    // The old "open another screen" wording is gone.
    expect(find.textContaining('Share my location with family'), findsNothing);
    expect(find.textContaining('Invite someone to start sharing'), findsNothing);

    await tester.tap(find.byKey(const Key('start_sharing_button')));
    await tester.pump();
    expect(safety.starts, 1);
    // Still on the same screen, now offering Stop.
    expect(find.byType(FamilyCircleScreen), findsOneWidget);
    expect(find.byKey(const Key('stop_sharing_button')), findsOneWidget);
    expect(find.byKey(const Key('start_sharing_button')), findsNothing);

    await tester.tap(find.byKey(const Key('stop_sharing_button')));
    await tester.pump();
    expect(safety.stops, 1);
    expect(find.byKey(const Key('start_sharing_button')), findsOneWidget);
  });

  testWidgets('with nobody in the circle the button is disabled and says why', (tester) async {
    final safety = _FakeSafety([_member('pending')]);
    await pumpScreen(tester, safety);

    final button = tester.widget<ElevatedButton>(find.byKey(const Key('start_sharing_button')));
    expect(button.onPressed, isNull);
    expect(find.textContaining('Invite a family member first'), findsOneWidget);
  });
}
