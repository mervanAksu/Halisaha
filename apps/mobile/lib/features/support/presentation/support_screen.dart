import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/urls.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = <_Contact>[
      if (AppConfig.supportEmail.isNotEmpty)
        const _Contact(Icons.mail_outline, S.contactEmail, AppConfig.supportEmail, 'mailto:${AppConfig.supportEmail}'),
      if (AppConfig.supportPhone.isNotEmpty)
        const _Contact(Icons.phone_outlined, S.contactPhone, AppConfig.supportPhone, 'tel:${AppConfig.supportPhone}'),
      if (AppConfig.supportWhatsapp.isNotEmpty)
        _Contact(
          Icons.chat_outlined,
          S.contactWhatsapp,
          S.contactWhatsappSubtitle,
          'https://wa.me/${AppConfig.supportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
        ),
      if (AppConfig.websiteUrl.isNotEmpty)
        const _Contact(Icons.language, S.contactWebsite, AppConfig.websiteUrl, AppConfig.websiteUrl),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(S.navSupport)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, size: 40, color: AppColors.onPrimary),
                const SizedBox(width: AppSpacing.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.supportHeaderTitle,
                        style: theme.textTheme.titleMedium?.copyWith(color: AppColors.onPrimary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        S.supportHeaderSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onPrimary),
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Column(
                  children: [
                    for (var i = 0; i < contacts.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: Icon(contacts[i].icon, color: AppColors.primary),
                        title: Text(contacts[i].title, style: theme.textTheme.bodyMedium),
                        subtitle: Text(contacts[i].subtitle, style: theme.textTheme.bodySmall),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.neutral),
                        onTap: () => openExternalOrWarn(context, contacts[i].url),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(S.faqTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
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
                      children: [Text(S.faqs[i].answer, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))],
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

class _Contact {
  const _Contact(this.icon, this.title, this.subtitle, this.url);

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
}
