import 'package:flutter/material.dart';

/// One text/background pair that must pass WCAG AA (>= 4.5:1). Used by the contrast test.
class ContrastPair {
  const ContrastPair(this.name, this.foreground, this.background);

  final String name;
  final Color foreground;
  final Color background;
}

/// Semantic colour tokens of docs/DESIGN.md ("Renk tokenları") for the "Skorbord" design (ADR-10):
/// an ink-and-paper base with one volt accent, light by default and dark with the system. This file and `app_theme.dart` are the only places where colour
/// literals may appear; widgets read tokens with `context.tokens`.
///
/// `accent` is for icons, progress and the selection ring. `highlight` (volt) is the only fill that
/// carries the "available / selected" message; text on it is always `onHighlight` (ink).
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
    required this.highlight,
    required this.onHighlight,
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

  /// Volt fill: selected slot, "N boş saat" badge, rebook button. Text on it: [onHighlight].
  final Color highlight;
  final Color onHighlight;

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

  /// Brand ink and its text colours for the full-screen brand surface (welcome screen). The brand
  /// screen is ink in light AND dark mode, so it does not follow the themed tokens.
  static const Color ink = Color(0xFF0E0F0C);
  static const Color onInk = Color(0xFFFFFFFF);
  static const Color onInkMuted = Color(0xFFA4A69E);

  static const AppTokens light = AppTokens(
    brand: Color(0xFF0E0F0C),
    primary: Color(0xFF0E0F0C),
    onPrimary: Color(0xFFFFFFFF),
    action: Color(0xFF1E5A37),
    onAction: Color(0xFFFFFFFF),
    accent: Color(0xFF0E0F0C),
    accentSoft: Color(0xFFEEF7C8),
    highlight: Color(0xFFD4FF3A),
    onHighlight: Color(0xFF0E0F0C),
    surface: Color(0xFFF7F7F3),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0E0F0C),
    textSecondary: Color(0xFF5C5F57),
    border: Color(0xFFE3E3DC),
    warning: Color(0xFF8A5300),
    warningSoft: Color(0xFFFFF4D6),
    danger: Color(0xFFC4232F),
    dangerSoft: Color(0xFFFDE7E8),
    onDanger: Color(0xFFFFFFFF),
    disabledSlot: Color(0xFFF1F1EC),
    onDisabledSlot: Color(0xFF5C5F57),
    neutral: Color(0xFFA4A69E),
    overlay: Color(0x99000000),
    shadow: Color(0x14000000),
  );

  static const AppTokens dark = AppTokens(
    brand: Color(0xFFF4F4F0),
    primary: Color(0xFFF4F4F0),
    onPrimary: Color(0xFF0E0F0C),
    action: Color(0xFF8FE0A6),
    onAction: Color(0xFF0E0F0C),
    accent: Color(0xFFD4FF3A),
    accentSoft: Color(0xFF2A3012),
    highlight: Color(0xFFD4FF3A),
    onHighlight: Color(0xFF0E0F0C),
    surface: Color(0xFF0E0F0C),
    card: Color(0xFF1A1B17),
    textPrimary: Color(0xFFF4F4F0),
    textSecondary: Color(0xFFA4A69E),
    border: Color(0xFF2C2E27),
    warning: Color(0xFFF5C84B),
    warningSoft: Color(0xFF3A2F10),
    danger: Color(0xFFFF6B73),
    dangerSoft: Color(0xFF3A1A1D),
    onDanger: Color(0xFF0E0F0C),
    disabledSlot: Color(0xFF23241F),
    onDisabledSlot: Color(0xFF9A9C93),
    neutral: Color(0xFF6B6E64),
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
        ContrastPair('onHighlight on highlight', onHighlight, highlight),
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
    Color? highlight,
    Color? onHighlight,
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
      highlight: highlight ?? this.highlight,
      onHighlight: onHighlight ?? this.onHighlight,
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
      highlight: mix(highlight, other.highlight),
      onHighlight: mix(onHighlight, other.onHighlight),
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
