import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_tokens.dart';
import '../theme/app_spacing.dart';

/// Slim, persistent ribbon shown above every route in demo mode.
class DemoBannerFrame extends StatelessWidget {
  const DemoBannerFrame({super.key, required this.child});

  final Widget? child;

  /// Store-screenshot capture opens the web demo with `?shots=1`; the banner is hidden there only.
  static bool get hiddenForScreenshots => Uri.base.queryParameters['shots'] == '1';

  @override
  Widget build(BuildContext context) {
    if (hiddenForScreenshots) return child ?? const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final tokens = context.tokens;
    return Column(
      children: [
        Material(
          color: tokens.warningSoft,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(AppSpacing.l, media.padding.top + AppSpacing.xs, AppSpacing.l, AppSpacing.xs),
            alignment: Alignment.center,
            child: Text(
              S.demoBanner,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tokens.textPrimary, fontSize: 12),
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
