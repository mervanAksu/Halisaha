import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import 'support_contacts.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final contacts = buildSupportContacts();

    return Scaffold(
      appBar: AppBar(title: const Text(S.navSupport)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: tokens.primary,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent, size: 40, color: tokens.onPrimary),
                const SizedBox(width: AppSpacing.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.supportHeaderTitle,
                        style: theme.textTheme.titleMedium?.copyWith(color: tokens.onPrimary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        S.supportHeaderSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: tokens.onPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          if (contacts.isEmpty)
            Text(S.supportNoContacts, style: theme.textTheme.bodySmall)
          else
            SupportContactCard(contacts: contacts),
          const SizedBox(height: AppSpacing.xl),
          Text(S.faqTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: tokens.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Column(
                children: [
                  for (var i = 0; i < S.faqs.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                      childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.l),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      title: Text(S.faqs[i].question, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      children: [Text(S.faqs[i].answer, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary))],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}
