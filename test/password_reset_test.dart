import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safezone/providers/auth_provider.dart';
import 'package:safezone/screens/forgot_password_screen.dart';
import 'package:safezone/screens/login_screen.dart';
import 'package:safezone/screens/set_new_password_screen.dart';

// A real GoTrueClient pointed at an unreachable host: no session, and every
// request fails like a network outage — enough to exercise the screens.
AuthProvider _offlineAuth() => AuthProvider(
      auth: GoTrueClient(
        url: 'http://127.0.0.1:9/auth/v1',
        autoRefreshToken: false,
      ),
    );

Widget _wrap(Widget child, AuthProvider auth) => ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('login screen links to password reset, prefilling the email', (tester) async {
    final auth = _offlineAuth();
    await tester.pumpWidget(_wrap(const LoginScreen(), auth));

    await tester.enterText(find.byType(TextField).first, 'someone@example.com');
    await tester.tap(find.byKey(const Key('forgot_password_link')));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('someone@example.com'), findsOneWidget);
    // No resend button until a sign-in actually fails as unconfirmed.
    expect(find.byKey(const Key('resend_confirmation')), findsNothing);
  });

  testWidgets('reset request validates the email before sending', (tester) async {
    final auth = _offlineAuth();
    await tester.pumpWidget(_wrap(const ForgotPasswordScreen(), auth));

    await tester.tap(find.byKey(const Key('send_reset_link')));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.byKey(const Key('send_reset_link')));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('a failed reset request shows an error, not "check your email"', (tester) async {
    final auth = _offlineAuth();
    await tester.pumpWidget(_wrap(const ForgotPasswordScreen(), auth));

    await tester.enterText(find.byType(TextFormField), 'someone@example.com');
    await tester.tap(find.byKey(const Key('send_reset_link')));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsNothing);
    expect(auth.error, isNotNull);
  });

  testWidgets('new password must be valid and match its confirmation', (tester) async {
    final auth = _offlineAuth();
    await tester.pumpWidget(_wrap(const SetNewPasswordScreen(), auth));
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), '123');
    await tester.tap(find.byKey(const Key('save_new_password')));
    await tester.pump();
    expect(find.textContaining('Use at least'), findsOneWidget);

    await tester.enterText(fields.at(0), 'a-good-password');
    await tester.enterText(fields.at(1), 'something-else');
    await tester.tap(find.byKey(const Key('save_new_password')));
    await tester.pump();
    expect(find.text("Passwords don't match"), findsOneWidget);
  });

  test('recovery mode is off without a session', () {
    expect(_offlineAuth().isPasswordRecovery, isFalse);
  });
}
