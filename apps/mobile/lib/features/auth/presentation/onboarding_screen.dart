import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/urls.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/primary_button.dart';
import '../../profile/presentation/profile_providers.dart';
import 'auth_providers.dart';

/// First login: full name + KVKK aydınlatma acknowledgement (+ optional marketing consent).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _kvkkAck = false;
  bool _marketing = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_kvkkAck) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The router redirect moves on to the home screen once the profile is complete.
      await ref.read(profileProvider.notifier).completeOnboarding(
            fullName: _nameController.text,
            marketingConsent: _marketing,
          );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.onboardingTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => ref.read(authRepositoryProvider).signOut(),
            child: const Text(S.signOut),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.onboardingSubtitle, style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary)),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  maxLength: 80,
                  autofillHints: const [AutofillHints.name],
                  decoration: appInputDecoration(context, label: S.fullNameLabel, counterText: ''),
                  validator: (value) => (value ?? '').trim().length < 2 ? S.fullNameInvalid : null,
                ),
                const SizedBox(height: AppSpacing.l),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _kvkkAck,
                  onChanged: (v) => setState(() => _kvkkAck = v ?? false),
                  title: Text(S.kvkkAckText, style: theme.textTheme.bodyMedium),
                  subtitle: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 48)),
                      onPressed: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalKvkk)),
                      child: const Text(S.kvkkReadLink),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _marketing,
                  onChanged: (v) => setState(() => _marketing = v ?? false),
                  title: Text(S.marketingConsentText, style: theme.textTheme.bodyMedium),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.danger)),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: S.continueLabel,
                  loading: _busy,
                  onPressed: _kvkkAck ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
