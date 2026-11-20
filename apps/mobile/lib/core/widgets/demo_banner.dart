import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Slim, persistent ribbon shown above every route in demo mode.
class DemoBannerFrame extends StatelessWidget {
  const DemoBannerFrame({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Column(
      children: [
        Material(
          color: AppColors.warning,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(AppSpacing.l, media.padding.top + AppSpacing.xs, AppSpacing.l, AppSpacing.xs),
            alignment: Alignment.center,
            child: Text(
              S.demoBanner,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          // The banner already covers the status-bar inset.
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child ?? const SizedBox.shrink()),
        ),
      ],
    );
  }
}
