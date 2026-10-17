import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/a11y/a11y_widgets.dart';
import '../l10n/ui_text.dart';

/// Requests a password-reset email. The link opens the app on this phone,
/// signs the user in with a recovery session, and [SetNewPasswordScreen]
/// asks for the new password.
///
/// The confirmation message is the same whether or not an account exists
/// for the address, so the screen can't be used to discover who has an
/// account.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  String? _sentTo;

  // The sign-in error lives in the shared AuthProvider, so without this a
  // "wrong password" banner from the login screen followed the person to
  // Register and back. Each of these screens starts with a clean slate and
  // clears the error when it closes.
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth.clearError());
  }

  @override
  void dispose() {
    _email.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth.clearError());
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final ok = await context.read<AuthProvider>().sendPasswordReset(email);
    if (ok && mounted) setState(() => _sentTo = email);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Reset password'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _sentTo != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(context.tr('Check your email'), style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(context.tr('If an account exists for {_sentTo}, we\'ve sent a link to reset the password. Open it on this phone — it brings you back to SafeZone to choose a new password. The link expires in an hour.', {'_sentTo': _sentTo}),
                        ),
                        const SizedBox(height: 8),
                        Text(context.tr('No email after a few minutes? Check your spam folder.'),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tr('Back to sign in')),
                        ),
                        TextButton(
                          onPressed: auth.isBusy ? null : _submit,
                          child: Text(context.tr('Send the link again')),
                        ),
                      ],
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(context.tr('Enter the email you signed up with and we\'ll send you a link to choose a new password.'),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              labelText: context.tr('Email'),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) => validateEmail(v, tr: context.tr),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: 12),
                            A11yErrorBanner(message: context.tr(auth.error!)),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const Key('send_reset_link'),
                            onPressed: auth.isBusy ? null : _submit,
                            child: auth.isBusy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(context.tr('Send reset link')),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
