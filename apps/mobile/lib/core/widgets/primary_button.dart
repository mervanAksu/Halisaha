import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-width primary button with an optional busy state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// When false the button is only as wide as needed (use inside Rows / centred columns).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: expand ? null : FilledButton.styleFrom(minimumSize: const Size(160, 52)),
      child: child,
    );
  }
}
