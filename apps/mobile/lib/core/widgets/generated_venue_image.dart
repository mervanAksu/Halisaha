import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Offline venue "photo" for the demo: theme-token gradient, a sports icon and the venue initials.
class GeneratedVenueImage extends StatelessWidget {
  const GeneratedVenueImage({super.key, required this.name});

  final String name;

  static List<List<Color>> _palettes(AppTokens t) => [
        [t.primary, t.action],
        [t.action, t.primary],
        [t.primary, t.textSecondary],
        [t.textSecondary, t.action],
      ];

  /// First letters of the first two words, upper-cased ("Mavi Çim Spor" -> "MÇ").
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    return words.map((w) => w.substring(0, 1)).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final seed = name.codeUnits.fold<int>(0, (a, b) => (a + b) % 9973);
    final tokens = context.tokens;
    final palettes = _palettes(tokens);
    final colors = palettes[seed % palettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Opacity(opacity: 0.18, child: Icon(Icons.sports_soccer, size: 140, color: tokens.onPrimary)),
          ),
          Center(
            child: Text(
              initialsOf(name),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.onPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
