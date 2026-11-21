import 'package:flutter/material.dart';

/// Offline venue "photo" for the demo: theme-token gradient, a sports icon and the venue initials.
class GeneratedVenueImage extends StatelessWidget {
  const GeneratedVenueImage({super.key, required this.name});

  final String name;

  // Dedicated "pitch" palettes (not the button tokens: in dark mode `primary` is a neon green that
  // turned the whole card into a flat bright block). Text on every gradient passes WCAG AA.
  static const List<List<Color>> _lightPalettes = [
    [Color(0xFF0F2A44), Color(0xFF0A7D4B)],
    [Color(0xFF0A7D4B), Color(0xFF0F2A44)],
    [Color(0xFF0F2A44), Color(0xFF3B4A5C)],
    [Color(0xFF3B4A5C), Color(0xFF0A7D4B)],
  ];
  static const List<List<Color>> _darkPalettes = [
    [Color(0xFF173226), Color(0xFF0B1410)],
    [Color(0xFF14213D), Color(0xFF173226)],
    [Color(0xFF1C3326), Color(0xFF0E1A14)],
    [Color(0xFF13283A), Color(0xFF0B1410)],
  ];
  static const Color _lightInk = Color(0xFFFFFFFF);
  static const Color _darkInk = Color(0xFFE8F1EC);

  static List<List<Color>> palettesFor(Brightness b) => b == Brightness.dark ? _darkPalettes : _lightPalettes;
  static Color inkFor(Brightness b) => b == Brightness.dark ? _darkInk : _lightInk;

  /// First letters of the first two words, upper-cased ("Mavi Çim Spor" -> "MÇ").
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    return words.map((w) => w.substring(0, 1)).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final seed = name.codeUnits.fold<int>(0, (a, b) => (a + b) % 9973);
    final brightness = Theme.of(context).brightness;
    final palettes = palettesFor(brightness);
    final colors = palettes[seed % palettes.length];
    final ink = inkFor(brightness);
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
            child: Opacity(opacity: 0.18, child: Icon(Icons.sports_soccer, size: 140, color: ink)),
          ),
          Center(
            child: Text(
              initialsOf(name),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: ink,
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
