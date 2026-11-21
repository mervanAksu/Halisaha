import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_tokens.dart';
import '../theme/app_spacing.dart';
import 'primary_button.dart';

/// Error message with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: tokens.danger),
            const SizedBox(height: AppSpacing.l),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: S.retry, icon: Icons.refresh, onPressed: onRetry, expand: false),
          ],
        ),
      ),
    );
  }
}
