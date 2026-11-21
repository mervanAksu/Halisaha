import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/theme/app_tokens.dart';
import 'package:halisaha/core/theme/contrast.dart';

void main() {
  group('contrastRatio', () {
    test('black on white is 21:1 and the function is symmetric', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);
      expect(contrastRatio(black, white), closeTo(21, 0.01));
      expect(contrastRatio(white, black), closeTo(21, 0.01));
      expect(contrastRatio(white, white), closeTo(1, 0.001));
    });

    test('white on accent #22B573 is the known 2.65:1 failure that DESIGN.md forbids', () {
      const white = Color(0xFFFFFFFF);
      expect(contrastRatio(white, AppTokens.light.accent), closeTo(2.65, 0.05));
    });
  });

  void checkPairs(String theme, AppTokens tokens) {
    group('$theme tokens', () {
      for (final pair in tokens.contrastPairs) {
        test('${pair.name} reaches WCAG AA (4.5:1)', () {
          final ratio = contrastRatio(pair.foreground, pair.background);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '${pair.name} is ${ratio.toStringAsFixed(2)}:1');
        });
      }
    });
  }

  checkPairs('light', AppTokens.light);
  checkPairs('dark', AppTokens.dark);

  group('token values follow docs/DESIGN.md', () {
    test('light "Temiz Çim"', () {
      const t = AppTokens.light;
      expect(t.primary, const Color(0xFF0F2A44));
      expect(t.action, const Color(0xFF0A7D4B));
      expect(t.accent, const Color(0xFF22B573));
      expect(t.accentSoft, const Color(0xFFE6F7EF));
      expect(t.surface, const Color(0xFFF5F7FA));
      expect(t.card, const Color(0xFFFFFFFF));
      expect(t.textPrimary, const Color(0xFF111827));
      expect(t.textSecondary, const Color(0xFF6B7280));
      expect(t.border, const Color(0xFFE5E7EB));
      expect(t.warning, const Color(0xFFB45309));
      expect(t.danger, const Color(0xFFC81E3A));
      expect(t.disabledSlot, const Color(0xFFF1F2F4));
    });

    test('dark "Gece Maçı"', () {
      const t = AppTokens.dark;
      expect(t.brand, const Color(0xFFE8F1EC));
      expect(t.primary, const Color(0xFF2EE08A));
      expect(t.onPrimary, const Color(0xFF06130D));
      expect(t.accentSoft, const Color(0xFF173226));
      expect(t.surface, const Color(0xFF0B1410));
      expect(t.card, const Color(0xFF14201A));
      expect(t.textSecondary, const Color(0xFF9FB3A8));
      expect(t.border, const Color(0xFF24342C));
      expect(t.warning, const Color(0xFFF5C84B));
      expect(t.danger, const Color(0xFFFF5C73));
      expect(t.disabledSlot, const Color(0xFF1E2A24));
      expect(t.onDisabledSlot, const Color(0xFF8FA89A));
    });

    test('lerp and copyWith keep the extension usable for theme animation', () {
      final mid = AppTokens.light.lerp(AppTokens.dark, 0.5);
      expect(mid.surface, isNot(AppTokens.light.surface));
      expect(AppTokens.light.lerp(AppTokens.dark, 0).surface, AppTokens.light.surface);
      expect(AppTokens.light.lerp(AppTokens.dark, 1).surface, AppTokens.dark.surface);
      expect(AppTokens.light.copyWith(surface: AppTokens.dark.surface).surface, AppTokens.dark.surface);
    });
  });
}
