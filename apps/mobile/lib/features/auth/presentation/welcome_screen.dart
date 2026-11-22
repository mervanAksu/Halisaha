import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'auth_providers.dart';

/// First launch: "Maç yapacağım" / "Sahamı yöneteceğim" (ADR-12). A brand screen: ink background in
/// light and dark. Picking a card only sets the mode; the router redirect does the navigation.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _choose(WidgetRef ref, AppMode mode) async {
    final signedIn = ref.read(currentUserIdProvider) != null;
    final isOwnerSession = ref.read(profileProvider).valueOrNull?.isOwner ?? false;
    final modeNotifier = ref.read(appModeProvider.notifier);
    // A session belongs to one audience (ADR-12): a customer session never carries into owner mode
    // and an owner session never carries into player mode.
    if (signedIn && (mode == AppMode.owner || isOwnerSession)) {
      // A leftover customer session (app update, demo) must not carry over into the owner mode.
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (_) {
        // The owner flow below shows "not an owner" if the session is still there.
      }
    }
    await modeNotifier.set(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTokens.ink,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Semantics(
                              header: true,
                              child: Text(
                                AppConfig.appName.toUpperCase(),
                                style: numericStyle(
                                  context,
                                  size: 56,
                                  weight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  color: AppTokens.onInk,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.s),
                            child: ExcludeSemantics(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: tokens.highlight, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Text(
                        S.welcomeTagline,
                        style: theme.textTheme.bodyLarge?.copyWith(color: AppTokens.onInkMuted),
                      ),
                      const Spacer(),
                      _RoleCard(
                        icon: Icons.sports_soccer,
                        title: S.welcomePlayerTitle,
                        subtitle: S.welcomePlayerSubtitle,
                        fill: tokens.highlight,
                        foreground: tokens.onHighlight,
                        onTap: () => _choose(ref, AppMode.player),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      _RoleCard(
                        icon: Icons.storefront_outlined,
                        title: S.welcomeOwnerTitle,
                        subtitle: S.welcomeOwnerSubtitle,
                        foreground: AppTokens.onInk,
                        outline: AppTokens.onInk,
                        onTap: () => _choose(ref, AppMode.owner),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        S.welcomeFooter,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppTokens.onInkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.onTap,
    this.fill,
    this.outline,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color foreground;
  final Color? fill;
  final Color? outline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: outline == null ? BorderSide.none : BorderSide(color: outline!, width: 1.5),
    );
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fill ?? context.tokens.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  Icon(icon, size: 36, color: foreground),
                  const SizedBox(width: AppSpacing.l),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
