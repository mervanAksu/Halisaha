import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final national = normalizeTrPhoneInput(_phoneController.text);
    if (national == null) return;
    final e164 = toE164Tr(national);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(e164);
      if (!mounted) return;
      context.push(AppRoutes.otpFor(e164));
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Icon(Icons.sports_soccer, size: 48, color: tokens.accent),
                const SizedBox(height: AppSpacing.l),
                Text(AppConfig.appName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.s),
                Text(
                  S.loginSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: appInputDecoration(
                    context,
                    label: S.phoneLabel,
                    hint: S.phoneHint,
                    prefixText: '${S.phonePrefix} ',
                  ),
                  validator: (value) => normalizeTrPhoneInput(value ?? '') == null ? S.phoneInvalid : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger)),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(label: S.sendCode, loading: _busy, onPressed: _submit),
                const SizedBox(height: AppSpacing.l),
                Text(S.loginSmsNote, style: theme.textTheme.bodySmall),
                if (AppConfig.demoMode) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(S.demoLoginHint, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
