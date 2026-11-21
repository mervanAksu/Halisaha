import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spacing.dart';
import 'app_tokens.dart';

/// Material 3 themes built from [AppTokens]: "Skorbord" light (default) and dark (system dark mode).
abstract final class AppTheme {
  static ThemeData light() => _build(AppTokens.light, Brightness.light);

  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      secondary: t.action,
      onSecondary: t.onAction,
      secondaryContainer: t.highlight,
      onSecondaryContainer: t.onHighlight,
      error: t.danger,
      onError: t.onDanger,
      surface: t.card,
      onSurface: t.textPrimary,
      onSurfaceVariant: t.textSecondary,
      outline: t.border,
      outlineVariant: t.border,
      surfaceTint: t.transparent,
      shadow: t.shadow,
    );

    final textTheme = _textTheme(t, brightness);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.surface,
      canvasColor: t.card,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[t],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.brand,
        surfaceTintColor: t.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          disabledBackgroundColor: t.disabledSlot,
          disabledForegroundColor: t.onDisabledSlot,
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.primary,
          minimumSize: const Size.fromHeight(AppSizes.minTarget),
          side: BorderSide(color: t.border),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          minimumSize: const Size(AppSizes.minTarget, AppSizes.minTarget),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.card,
        selectedColor: t.accentSoft,
        checkmarkColor: t.action,
        side: BorderSide(color: t.border),
        labelStyle: textTheme.bodySmall?.copyWith(color: t.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.brand,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.surface),
        shape: buttonShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        modalBackgroundColor: t.card,
        surfaceTintColor: t.transparent,
        showDragHandle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.card,
        surfaceTintColor: t.transparent,
        indicatorColor: t.highlight,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.accent),
    );
  }

  /// Inter body, Barlow Condensed display (docs/DESIGN.md "Tipografi"):
  /// headlineLarge = hero title 34/800, headlineSmall = page title 24/800 condensed, titleMedium = section 17/600,
  /// bodyMedium = body 15/400, bodySmall = secondary 13/400, labelMedium = badge 13/700.
  static TextTheme _textTheme(AppTokens t, Brightness brightness) {
    final seed = ThemeData(brightness: brightness).textTheme;
    final base = GoogleFonts.interTextTheme(seed).apply(
      bodyColor: t.textPrimary,
      displayColor: t.textPrimary,
    );
    return base.copyWith(
      headlineLarge: GoogleFonts.barlowCondensed(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: 0.5,
        color: t.brand,
      ),
      headlineSmall: GoogleFonts.barlowCondensed(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: 0.3,
        color: t.brand,
      ),
      titleMedium: base.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.brand),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.textSecondary),
      labelMedium: base.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}
