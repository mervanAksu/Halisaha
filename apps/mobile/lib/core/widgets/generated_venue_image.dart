import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Offline venue "photo" for the demo: theme-token gradient, a sports icon and the venue initials.
class GeneratedVenueImage extends StatelessWidget {
  const GeneratedVenueImage({super.key, required this.name});

  final String name;

  static const List<List<Color>> _palettes = [
    [AppColors.primary, AppColors.accent],
    [AppColors.accent, AppColors.primary],
    [AppColors.primary, AppColors.textSecondary],
    [AppColors.textSecondary, AppColors.accent],
  ];

  /// First letters of the first two words, upper-cased ("Mavi Çim Spor" -> "MÇ").
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    return words.map((w) => w.substring(0, 1)).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final seed = name.codeUnits.fold<int>(0, (a, b) => (a + b) % 9973);
    final colors = _palettes[seed % _palettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            right: -16,
            bottom: -16,
            child: Opacity(opacity: 0.18, child: Icon(Icons.sports_soccer, size: 140, color: AppColors.onPrimary)),
          ),
          Center(
            child: Text(
              initialsOf(name),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.onPrimary,
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
