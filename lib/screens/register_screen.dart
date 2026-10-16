import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../legal/policy_documents.dart';
import '../providers/auth_provider.dart';
import '../services/consent_service.dart';
import '../utils/validators.dart';
import '../widgets/a11y/a11y_widgets.dart';
import 'policy_screen.dart';
import '../l10n/ui_text.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _agreedToTerms = false; // must be ticked by the user, never preset
  bool _showTermsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Create account'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.tr('Citizen accounts only'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(context.tr('Authority and volunteer-org accounts are set up by an administrator, not through self-registration.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      maxLength: kMaxNameLength,
                      decoration: InputDecoration(labelText: context.tr('Full name'), counterText: ''),
                      validator: (v) => validateFullName(v, tr: context.tr),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: InputDecoration(
                        labelText: context.tr('Mobile number'),
                        hintText: '0771234567',
                      ),
                      validator: (v) => validatePhone(v, tr: context.tr),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: context.tr('Email')),
                      validator: (v) => validateEmail(v, tr: context.tr),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: context.tr('Password'),
                        helperText: context.tr('At least {kMinPasswordLength} characters', {'kMinPasswordLength': kMinPasswordLength}),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => validatePassword(v, tr: context.tr),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const Key('register_terms_checkbox'),
                      value: _agreedToTerms,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: auth.isBusy
                          ? null
                          : (v) => setState(() {
                                _agreedToTerms = v ?? false;
                                _showTermsError = false;
                              }),
                      title: Text(context.tr('I agree to the Terms of Use and have read the Privacy Policy')),
                      subtitle: _showTermsError
                          ? Text(context.tr('Please accept to create an account'),
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            )
                          : null,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => PolicyScreen.open(context, termsOfUse),
                          child: Text(context.tr('Terms of Use')),
                        ),
                        TextButton(
                          onPressed: () => PolicyScreen.open(context, privacyPolicy),
                          child: Text(context.tr('Privacy Policy')),
                        ),
                      ],
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      A11yErrorBanner(message: context.tr(auth.error!)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isBusy ? null : () => _submit(context),
                      child: auth.isBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.tr('Create account')),
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

  Future<void> _submit(BuildContext context) async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!_agreedToTerms) setState(() => _showTermsError = true);
    if (!formOk || !_agreedToTerms) return;

    final auth = context.read<AuthProvider>();
    final userId = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      phone: normalizePhone(_phoneController.text)!,
    );
    if (userId == null || !context.mounted) return;

    // Kept on this device and uploaded on first sign-in (there's no session
    // yet while email confirmation is pending).
    await ConsentService().accept(userId, requiredPolicies);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          auth.isSignedIn
              ? 'Account created.'
              : 'Account created. Check your email to confirm, then sign in.',
        ),
      ),
    );
    if (Navigator.of(context).canPop()) Navigator.pop(context);
  }
}
