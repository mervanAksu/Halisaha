import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../support/presentation/support_contacts.dart';

/// "Rövanş'ta sahanı listelemek ister misin?" with the configured support contacts.
/// Renders nothing when no contact is configured.
class OwnerContactSection extends StatelessWidget {
  const OwnerContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    final contacts = buildSupportContacts(includeWebsite: false);
    if (contacts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.ownerListVenueTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(S.ownerListVenueBody, style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary)),
        const SizedBox(height: AppSpacing.m),
        SupportContactCard(contacts: contacts),
      ],
    );
  }
}
