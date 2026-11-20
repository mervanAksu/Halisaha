import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_colors.dart';
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: AppSpacing.l),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: S.retry, icon: Icons.refresh, onPressed: onRetry, expand: false),
          ],
        ),
      ),
    );
  }
}
