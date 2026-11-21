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

    test('white on volt highlight #D4FF3A fails, which is why DESIGN.md puts only ink on it', () {
      const white = Color(0xFFFFFFFF);
      expect(contrastRatio(white, AppTokens.light.highlight), lessThan(1.5));
      expect(contrastRatio(AppTokens.light.onHighlight, AppTokens.light.highlight), greaterThan(15));
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

  group('token values follow docs/DESIGN.md (Skorbord, ADR-10)', () {
    test('light', () {
      const t = AppTokens.light;
      expect(t.primary, const Color(0xFF0E0F0C));
      expect(t.onPrimary, const Color(0xFFFFFFFF));
      expect(t.action, const Color(0xFF1E5A37));
      expect(t.highlight, const Color(0xFFD4FF3A));
      expect(t.onHighlight, const Color(0xFF0E0F0C));
      expect(t.surface, const Color(0xFFF7F7F3));
      expect(t.card, const Color(0xFFFFFFFF));
      expect(t.textSecondary, const Color(0xFF5C5F57));
      expect(t.danger, const Color(0xFFC4232F));
    });

    test('dark', () {
      const t = AppTokens.dark;
      expect(t.primary, const Color(0xFFF4F4F0));
      expect(t.onPrimary, const Color(0xFF0E0F0C));
      expect(t.highlight, const Color(0xFFD4FF3A));
      expect(t.surface, const Color(0xFF0E0F0C));
      expect(t.card, const Color(0xFF1A1B17));
    });
  });
}
