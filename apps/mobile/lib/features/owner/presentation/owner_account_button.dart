import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/urls.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../profile/presentation/profile_providers.dart';

/// AppBar action of the owner panel: opens the account sheet (profile, web panel, mode switch,
/// sign-out, legal links).
class OwnerAccountButton extends ConsumerWidget {
  const OwnerAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: S.ownerAccountTooltip,
      icon: const Icon(Icons.manage_accounts_outlined),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _AccountSheet(),
      ),
    );
  }
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  Future<void> _signOut(BuildContext context, WidgetRef ref, AppMode? mode) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await signOutAndSwitchMode(ref, mode);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final profile = ref.watch(profileProvider).valueOrNull;
    final name = profile?.fullName.trim() ?? '';
    final email = profile?.email ?? '';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty) Text(name, style: theme.textTheme.titleMedium),
                  if (email.isNotEmpty)
                    Text(email, style: theme.textTheme.bodySmall?.copyWith(color: tokens.textSecondary)),
                ],
              ),
            ),
            const Divider(),
            if (AppConfig.ownerPanelUrl.isNotEmpty)
              ListTile(
                leading: Icon(Icons.open_in_new, color: tokens.brand),
                title: const Text(S.ownerOpenWebPanel),
                onTap: () => openExternalOrWarn(context, AppConfig.ownerPanelUrl),
              ),
            ListTile(
              leading: Icon(Icons.sports_soccer_outlined, color: tokens.brand),
              title: const Text(S.ownerSwitchToPlayer),
              onTap: () => _signOut(context, ref, AppMode.player),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: tokens.warning),
              title: const Text(S.ownerSignOut),
              onTap: () => _signOut(context, ref, null),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: tokens.brand),
              title: const Text(S.legalPrivacy),
              onTap: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalPrivacy)),
            ),
            ListTile(
              leading: Icon(Icons.gavel_outlined, color: tokens.brand),
              title: const Text(S.legalKvkk),
              onTap: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalKvkk)),
            ),
          ],
        ),
      ),
    );
  }
}
