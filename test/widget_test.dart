// Basic smoke test — verifies the app starts without throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:focus_app/main.dart';

void main() {
  setUpAll(() async {
    // Initialise Supabase before the widget tree is pumped so that
    // SupabaseService.client is available during the test.
    await Supabase.initialize(
      url: 'https://frkwsgriwdezkvrmgsgf.supabase.co',
      anonKey: 'sb_publishable_1Ax1SZF9hldmiJ1kyi338w_BvOL4Gxd',
    );
  });

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const DisasterApp());
    // Let async init settle.
    await tester.pump(const Duration(seconds: 1));
    // The app should render without an unhandled exception.
    expect(tester.takeException(), isNull);
  });
}
