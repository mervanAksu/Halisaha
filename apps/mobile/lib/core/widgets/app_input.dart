import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_spacing.dart';

/// Shared text-field look (kept as a function so no theme-type migrations can break it).
InputDecoration appInputDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  String? prefixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
  String? counterText,
}) {
  final tokens = context.tokens;
  OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    errorText: errorText,
    counterText: counterText,
    filled: true,
    fillColor: tokens.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
    border: border(tokens.border),
    enabledBorder: border(tokens.border),
    focusedBorder: border(tokens.primary, width: 1.5),
    errorBorder: border(tokens.danger),
    focusedErrorBorder: border(tokens.danger, width: 1.5),
  );
}
