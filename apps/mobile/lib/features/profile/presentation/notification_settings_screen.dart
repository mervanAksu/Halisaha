import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Placeholder: local toggles only. Real push preferences arrive with FCM
/// (see lib/features/notifications/README.md).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _confirmed = true;
  bool _reminder = true;
  bool _venueCancelled = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(S.notificationSettings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.accent),
                const SizedBox(width: AppSpacing.m),
                Expanded(child: Text(S.notificationsPlaceholderNote, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          SwitchListTile(
            value: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v),
            title: const Text(S.notifBookingConfirmed),
          ),
          SwitchListTile(
            value: _reminder,
            onChanged: (v) => setState(() => _reminder = v),
            title: const Text(S.notifReminder),
          ),
          SwitchListTile(
            value: _venueCancelled,
            onChanged: (v) => setState(() => _venueCancelled = v),
            title: const Text(S.notifVenueCancelled),
          ),
        ],
      ),
    );
  }
}
