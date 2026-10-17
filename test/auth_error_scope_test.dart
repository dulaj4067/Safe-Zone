import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safezone/providers/auth_provider.dart';
import 'package:safezone/screens/login_screen.dart';
import 'package:safezone/screens/register_screen.dart';
import 'package:safezone/widgets/a11y/a11y_widgets.dart';

// An auth client pointed at an unreachable host, so a sign-in attempt fails
// quickly with a network error.
AuthProvider _offlineAuth() => AuthProvider(
      auth: GoTrueClient(url: 'http://127.0.0.1:9/auth/v1', autoRefreshToken: false),
    );

void main() {
  testWidgets('a sign-in error stays on the sign-in screen', (tester) async {
    final auth = _offlineAuth();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: auth,
      child: const MaterialApp(home: LoginScreen()),
    ));

    // Fail a sign-in.
    await tester.enterText(find.byType(TextField).at(0), 'someone@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(A11yErrorBanner), findsOneWidget);

    // Go to Register: the login error must not follow.
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(A11yErrorBanner), findsNothing);

    // And coming back, the login screen starts clean.
    Navigator.of(tester.element(find.byType(RegisterScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(A11yErrorBanner), findsNothing);
  });
}
