import 'package:flutter/material.dart';

/// One text/background pair that must pass WCAG AA (>= 4.5:1). Used by the contrast test.
class ContrastPair {
  const ContrastPair(this.name, this.foreground, this.background);

  final String name;
  final Color foreground;
  final Color background;
}

/// Semantic colour tokens of docs/DESIGN.md ("Renk tokenları") for the light theme "Temiz Çim"
/// and the dark theme "Gece Maçı". This file and `app_theme.dart` are the only places where colour
/// literals may appear; widgets read tokens with `context.tokens`.
///
/// `accent` is for fills, icons and rings only: never put text on it (white on #22B573 is 2.65:1).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brand,
    required this.primary,
    required this.onPrimary,
    required this.action,
    required this.onAction,
    required this.accent,
    required this.accentSoft,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.onDanger,
    required this.disabledSlot,
    required this.onDisabledSlot,
    required this.neutral,
    required this.overlay,
    required this.shadow,
  });

  /// Titles and logo text.
  final Color brand;

  /// Primary button fill.
  final Color primary;
  final Color onPrimary;

  /// Available slot, price badge fill.
  final Color action;
  final Color onAction;

  /// Icons, progress, selection ring. Never a text background.
  final Color accent;
  final Color accentSoft;

  /// Page background.
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  /// Payment pending. Text/icon colour; [warningSoft] is its tinted background.
  final Color warning;
  final Color warningSoft;

  /// Cancel, delete. [dangerSoft] is its tinted background, [onDanger] text on a [danger] fill.
  final Color danger;
  final Color dangerSoft;
  final Color onDanger;

  /// Booked slot background and its text.
  final Color disabledSlot;
  final Color onDisabledSlot;

  /// Decorative icons and placeholders (no text).
  final Color neutral;

  /// Scrims and shadows.
  final Color overlay;
  final Color shadow;

  /// Fully transparent colour (kept here so no literal is needed elsewhere).
  Color get transparent => const Color(0x00000000);

  static const AppTokens light = AppTokens(
    brand: Color(0xFF0F2A44),
    primary: Color(0xFF0F2A44),
    onPrimary: Color(0xFFFFFFFF),
    action: Color(0xFF0A7D4B),
    onAction: Color(0xFFFFFFFF),
    accent: Color(0xFF22B573),
    accentSoft: Color(0xFFE6F7EF),
    surface: Color(0xFFF5F7FA),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFC81E3A),
    dangerSoft: Color(0xFFFFE4EA),
    onDanger: Color(0xFFFFFFFF),
    disabledSlot: Color(0xFFF1F2F4),
    // DESIGN.md lists #6B7280 here, which is only 4.32:1 on #F1F2F4. Darkened to pass AA (4.72:1).
    onDisabledSlot: Color(0xFF656C78),
    neutral: Color(0xFF9CA3AF),
    overlay: Color(0x99000000),
    shadow: Color(0x14000000),
  );

  static const AppTokens dark = AppTokens(
    brand: Color(0xFFE8F1EC),
    primary: Color(0xFF2EE08A),
    onPrimary: Color(0xFF06130D),
    action: Color(0xFF2EE08A),
    onAction: Color(0xFF06130D),
    accent: Color(0xFF2EE08A),
    accentSoft: Color(0xFF173226),
    surface: Color(0xFF0B1410),
    card: Color(0xFF14201A),
    textPrimary: Color(0xFFE8F1EC),
    textSecondary: Color(0xFF9FB3A8),
    border: Color(0xFF24342C),
    warning: Color(0xFFF5C84B),
    warningSoft: Color(0xFF3A2F10),
    danger: Color(0xFFFF5C73),
    dangerSoft: Color(0xFF3A1A21),
    onDanger: Color(0xFF06130D),
    disabledSlot: Color(0xFF1E2A24),
    onDisabledSlot: Color(0xFF8FA89A),
    neutral: Color(0xFF6F8579),
    overlay: Color(0xB3000000),
    shadow: Color(0x66000000),
  );

  /// Every text-on-background combination the UI uses; each must reach 4.5:1.
  List<ContrastPair> get contrastPairs => <ContrastPair>[
        ContrastPair('brand on surface', brand, surface),
        ContrastPair('brand on card', brand, card),
        ContrastPair('onPrimary on primary', onPrimary, primary),
        ContrastPair('onAction on action', onAction, action),
        ContrastPair('onDanger on danger', onDanger, danger),
        ContrastPair('textPrimary on surface', textPrimary, surface),
        ContrastPair('textPrimary on card', textPrimary, card),
        ContrastPair('textPrimary on accentSoft', textPrimary, accentSoft),
        ContrastPair('textPrimary on warningSoft', textPrimary, warningSoft),
        ContrastPair('textPrimary on dangerSoft', textPrimary, dangerSoft),
        ContrastPair('textPrimary on disabledSlot', textPrimary, disabledSlot),
        ContrastPair('textSecondary on surface', textSecondary, surface),
        ContrastPair('textSecondary on card', textSecondary, card),
        ContrastPair('primary on card', primary, card),
        ContrastPair('primary on surface', primary, surface),
        ContrastPair('primary on accentSoft', primary, accentSoft),
        ContrastPair('action on card', action, card),
        ContrastPair('action on surface', action, surface),
        ContrastPair('action on accentSoft', action, accentSoft),
        ContrastPair('warning on card', warning, card),
        ContrastPair('warning on surface', warning, surface),
        ContrastPair('warning on warningSoft', warning, warningSoft),
        ContrastPair('danger on card', danger, card),
        ContrastPair('danger on surface', danger, surface),
        ContrastPair('danger on dangerSoft', danger, dangerSoft),
        ContrastPair('onDisabledSlot on disabledSlot', onDisabledSlot, disabledSlot),
      ];

  @override
  AppTokens copyWith({
    Color? brand,
    Color? primary,
    Color? onPrimary,
    Color? action,
    Color? onAction,
    Color? accent,
    Color? accentSoft,
    Color? surface,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? onDanger,
    Color? disabledSlot,
    Color? onDisabledSlot,
    Color? neutral,
    Color? overlay,
    Color? shadow,
  }) {
    return AppTokens(
      brand: brand ?? this.brand,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      onDanger: onDanger ?? this.onDanger,
      disabledSlot: disabledSlot ?? this.disabledSlot,
      onDisabledSlot: onDisabledSlot ?? this.onDisabledSlot,
      neutral: neutral ?? this.neutral,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppTokens(
      brand: mix(brand, other.brand),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      action: mix(action, other.action),
      onAction: mix(onAction, other.onAction),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      surface: mix(surface, other.surface),
      card: mix(card, other.card),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      border: mix(border, other.border),
      warning: mix(warning, other.warning),
      warningSoft: mix(warningSoft, other.warningSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      onDanger: mix(onDanger, other.onDanger),
      disabledSlot: mix(disabledSlot, other.disabledSlot),
      onDisabledSlot: mix(onDisabledSlot, other.onDisabledSlot),
      neutral: mix(neutral, other.neutral),
      overlay: mix(overlay, other.overlay),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension AppTokensContext on BuildContext {
  /// Tokens of the closest theme. Falls back to the light tokens when the theme does not carry
  /// them (for example a bare `MaterialApp` in a widget test).
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
