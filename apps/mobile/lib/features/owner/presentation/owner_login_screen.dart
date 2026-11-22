import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/auth_providers.dart';
import 'owner_contact_section.dart';

/// Basic e-mail shape check (the server is the real validator).
bool isPlausibleEmail(String value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

/// Owner sign-in with e-mail and password (same account as the web panel, ADR-12). On success the
/// router redirect moves on (owner shell, or the "not an owner" screen).
class OwnerLoginScreen extends ConsumerStatefulWidget {
  const OwnerLoginScreen({super.key});

  @override
  ConsumerState<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends ConsumerState<OwnerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
      TextInput.finishAutofillContext();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Icon(Icons.storefront_outlined, size: 48, color: tokens.accent),
                  const SizedBox(height: AppSpacing.l),
                  Text(S.ownerLoginTitle, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    S.ownerLoginSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: appInputDecoration(context, label: S.emailLabel),
                    validator: (value) => isPlausibleEmail(value ?? '') ? null : S.emailInvalid,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: appInputDecoration(
                      context,
                      label: S.passwordLabel,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? S.showPassword : S.hidePassword,
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) => (value ?? '').isEmpty ? S.passwordRequired : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.m),
                    Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(label: S.ownerLoginSubmit, loading: _busy, onPressed: _submit),
                  const SizedBox(height: AppSpacing.m),
                  Text(S.ownerLoginResetHint, style: theme.textTheme.bodySmall),
                  if (AppConfig.demoMode) ...[
                    const SizedBox(height: AppSpacing.s),
                    Text(S.ownerDemoLoginHint, style: theme.textTheme.bodySmall?.copyWith(color: tokens.textSecondary)),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () => ref.read(appModeProvider.notifier).set(AppMode.player),
                      child: const Text(S.ownerLoginNotOwner, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  const OwnerContactSection(),
                  const SizedBox(height: AppSpacing.l),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
