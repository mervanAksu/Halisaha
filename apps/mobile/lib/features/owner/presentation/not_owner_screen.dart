import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/auth_providers.dart';
import 'owner_contact_section.dart';

/// Signed in while in owner mode, but the account is not `owner`/`admin`.
class NotOwnerScreen extends ConsumerStatefulWidget {
  const NotOwnerScreen({super.key});

  @override
  ConsumerState<NotOwnerScreen> createState() => _NotOwnerScreenState();
}

class _NotOwnerScreenState extends ConsumerState<NotOwnerScreen> {
  bool _busy = false;

  /// Signs out; [mode] null keeps the owner mode (back to the owner login).
  Future<void> _leave(AppMode? mode) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await signOutAndSwitchMode(ref, mode);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Icon(Icons.storefront_outlined, size: 48, color: tokens.neutral),
              const SizedBox(height: AppSpacing.l),
              Text(S.notOwnerTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: S.notOwnerContinuePlayer,
                loading: _busy,
                onPressed: () => _leave(AppMode.player),
              ),
              const SizedBox(height: AppSpacing.m),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _busy ? null : () => _leave(null),
                child: const Text(S.notOwnerOtherAccount),
              ),
              const SizedBox(height: AppSpacing.xl),
              const OwnerContactSection(),
              const SizedBox(height: AppSpacing.l),
            ],
          ),
        ),
      ),
    );
  }
}
