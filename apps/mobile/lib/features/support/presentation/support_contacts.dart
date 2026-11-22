import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/urls.dart';

/// One support contact row (e-mail, phone, WhatsApp, website).
class SupportContact {
  const SupportContact(this.icon, this.title, this.subtitle, this.url);

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
}

/// Contacts configured through AppConfig; empty when none is set.
List<SupportContact> buildSupportContacts({bool includeWebsite = true}) {
  return <SupportContact>[
    if (AppConfig.supportEmail.isNotEmpty)
      const SupportContact(Icons.mail_outline, S.contactEmail, AppConfig.supportEmail, 'mailto:${AppConfig.supportEmail}'),
    if (AppConfig.supportPhone.isNotEmpty)
      const SupportContact(Icons.phone_outlined, S.contactPhone, AppConfig.supportPhone, 'tel:${AppConfig.supportPhone}'),
    if (AppConfig.supportWhatsapp.isNotEmpty)
      SupportContact(
        Icons.chat_outlined,
        S.contactWhatsapp,
        S.contactWhatsappSubtitle,
        'https://wa.me/${AppConfig.supportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
      ),
    if (includeWebsite && AppConfig.websiteUrl.isNotEmpty)
      const SupportContact(Icons.language, S.contactWebsite, AppConfig.websiteUrl, AppConfig.websiteUrl),
  ];
}

/// Card with the contact rows; the caller decides what to show when [contacts] is empty.
class SupportContactCard extends StatelessWidget {
  const SupportContactCard({super.key, required this.contacts});

  final List<SupportContact> contacts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    // A Material (not a decorated Container) so ListTile ink splashes stay visible.
    return Material(
      color: tokens.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: tokens.border),
      ),
      child: Column(
          children: [
            for (var i = 0; i < contacts.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: Icon(contacts[i].icon, color: tokens.brand),
                title: Text(contacts[i].title, style: theme.textTheme.bodyMedium),
                subtitle: Text(contacts[i].subtitle, style: theme.textTheme.bodySmall),
                trailing: Icon(Icons.chevron_right, color: tokens.neutral),
                onTap: () => openExternalOrWarn(context, contacts[i].url),
              ),
            ],
          ],
        ),
    );
  }
}
