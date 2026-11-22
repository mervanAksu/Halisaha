import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/phone.dart';
import '../../../core/utils/urls.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/profile.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.navProfile)),
      body: AsyncValueWidget<Profile?>(
        value: profile,
        onRetry: () => ref.invalidate(profileProvider),
        data: (p) {
          if (p == null) return const SizedBox.shrink();
          return _ProfileBody(profile: p);
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _deleting = false;

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: widget.profile.fullName),
    );
    if (newName == null || newName == widget.profile.fullName) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileProvider.notifier).updateName(newName);
      messenger.showSnackBar(const SnackBar(content: Text(S.profileUpdated)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.signOutConfirmTitle),
        content: const Text(S.signOutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(S.cancelDismiss)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text(S.signOut)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Owner login: the session ends first (a session belongs to one audience, ADR-12), then the
  /// app switches to owner mode and the router shows the owner login.
  Future<void> _switchToOwner(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.switchToOwnerLogin),
        content: const Text(S.switchToOwnerBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(S.cancelDismiss)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text(S.continueLabel)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await signOutAndSwitchMode(ref, AppMode.owner);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Two explicit confirmations, then the `delete-account` edge function, then sign-out.
  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.deleteAccountTitle),
        content: const Text(S.deleteAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(S.cancelDismiss)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.tokens.danger),
            child: const Text(S.continueLabel),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.deleteAccountFinalTitle),
        content: const Text(S.deleteAccountFinalBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(S.cancelDismiss)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.danger,
              foregroundColor: context.tokens.onDanger,
              minimumSize: const Size(0, 48),
            ),
            child: const Text(S.deleteAccountConfirm),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      // The edge function deletes the auth user; signing out then lets the router go to /login.
      await ref.read(profileRepositoryProvider).deleteAccount();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final phone = formatPhoneDisplay(profile.phone);
    return AbsorbPointer(
      absorbing: _deleting,
      child: ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        if (_deleting) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.m),
        ],
        Container(
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: tokens.primary,
                child: Text(
                  profile.initials,
                  style: theme.textTheme.titleMedium?.copyWith(color: tokens.onPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName, style: theme.textTheme.titleMedium),
                    if (phone.isNotEmpty) Text(phone, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: S.editProfile,
                onPressed: () => _editName(context, ref),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        _Section(children: [
          _Tile(
            icon: Icons.notifications_none,
            label: S.notificationSettings,
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
        ]),
        const SizedBox(height: AppSpacing.l),
        _Section(children: [
          _Tile(
            icon: Icons.info_outline,
            label: S.legalAbout,
            onTap: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalAbout)),
          ),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            label: S.legalPrivacy,
            onTap: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalPrivacy)),
          ),
          _Tile(
            icon: Icons.description_outlined,
            label: S.legalTerms,
            onTap: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalTerms)),
          ),
          _Tile(
            icon: Icons.gavel_outlined,
            label: S.legalKvkk,
            onTap: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalKvkk)),
          ),
          _Tile(
            icon: Icons.receipt_long_outlined,
            label: S.legalDistanceSales,
            onTap: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalDistanceSales)),
          ),
        ]),
        const SizedBox(height: AppSpacing.l),
        _Section(children: [
          _Tile(
            icon: Icons.logout,
            iconColor: tokens.warning,
            label: S.signOut,
            onTap: () => _signOut(context, ref),
          ),
          _Tile(
            icon: Icons.delete_outline,
            iconColor: tokens.danger,
            labelColor: tokens.danger,
            label: S.deleteAccount,
            onTap: () => _deleteAccount(context, ref),
          ),
        ]),
        const SizedBox(height: AppSpacing.l),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: tokens.textSecondary,
              minimumSize: const Size(0, AppSizes.minTarget),
            ),
            onPressed: () => _switchToOwner(context, ref),
            child: const Text(S.switchToOwnerLogin),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Center(child: Text(S.appVersionLabel(AppConfig.appVersion), style: theme.textTheme.bodySmall)),
        const SizedBox(height: AppSpacing.l),
      ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) items.add(const Divider(height: 1));
    }
    final tokens = context.tokens;
    // A Material (not a decorated Container) so ListTile ink splashes stay visible.
    return Material(
      color: tokens.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: tokens.border),
      ),
      child: Column(children: items),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? tokens.brand),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: labelColor ?? tokens.textPrimary)),
      trailing: Icon(Icons.chevron_right, color: tokens.neutral),
      onTap: onTap,
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.editProfile),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: appInputDecoration(context, label: S.fullNameLabel, counterText: ''),
          validator: (v) => (v ?? '').trim().length < 2 ? S.fullNameInvalid : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(S.cancelDismiss)),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text(S.save),
        ),
      ],
    );
  }
}
