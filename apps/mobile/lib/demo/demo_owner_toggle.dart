import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_tokens.dart';
import '../features/profile/presentation/profile_providers.dart';
import 'demo_overrides.dart';

/// Profil switch of the web preview: "İşletmeci modunu dene (demo)". Makes the demo user an owner of
/// two demo venues so the in-app owner panel can be tried without a backend.
class DemoOwnerToggle extends ConsumerWidget {
  const DemoOwnerToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final enabled = ref.watch(profileProvider).valueOrNull?.isOwner ?? false;
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.border),
      ),
      child: SwitchListTile(
        secondary: Icon(Icons.storefront_outlined, color: tokens.brand),
        title: const Text(S.demoOwnerSwitch),
        subtitle: const Text(S.demoOwnerSwitchHint),
        value: enabled,
        onChanged: (value) {
          final store = ref.read(demoStoreProvider);
          store.setOwnerMode(value);
          ref.read(profileProvider.notifier).replace(store.profile);
        },
      ),
    );
  }
}
