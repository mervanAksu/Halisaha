import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/auth_providers.dart';

/// TOTP step for owners whose account has a verified authenticator factor (server requires aal2).
/// On success [mfaPendingProvider] is invalidated and the router redirect moves on to /owner.
class OwnerMfaScreen extends ConsumerStatefulWidget {
  const OwnerMfaScreen({super.key});

  @override
  ConsumerState<OwnerMfaScreen> createState() => _OwnerMfaScreenState();
}

class _OwnerMfaScreenState extends ConsumerState<OwnerMfaScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = S.mfaCodeIncomplete);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // Read before the first await: the redirect may dispose this widget.
    final repo = ref.read(authRepositoryProvider);
    final container = ProviderScope.containerOf(context);
    try {
      await repo.verifyTotp(code);
      container.invalidate(mfaPendingProvider);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await signOutAndSwitchMode(ref, null);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Icon(Icons.verified_user_outlined, size: 48, color: tokens.accent),
                const SizedBox(height: AppSpacing.l),
                Text(S.mfaTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.s),
                Text(S.mfaSubtitle, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary)),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: appInputDecoration(context, label: S.mfaCodeLabel),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger)),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(label: S.mfaSubmit, loading: _busy, onPressed: _submit),
                const SizedBox(height: AppSpacing.m),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _busy ? null : _signOut,
                    child: const Text(S.mfaSignOut),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
