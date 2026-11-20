import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.card,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      outline: AppColors.border,
    );

    final textTheme = _textTheme();
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.border),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.accentSoft,
        side: const BorderSide(color: AppColors.border),
        labelStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.onPrimary),
        shape: buttonShape,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    );
  }

  /// Inter, sizes per docs/DESIGN.md:
  /// headlineSmall = page title 22/700, titleMedium = section 17/600,
  /// bodyMedium = body 15/400, bodySmall = secondary 13/400, labelMedium = badge 13/700.
  static TextTheme _textTheme() {
    final base = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
      titleMedium: base.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primary),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelMedium: base.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}
