import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/theme/contrast.dart';
import 'package:halisaha/core/widgets/generated_venue_image.dart';

void main() {
  for (final b in Brightness.values) {
    test('demo venue image initials are readable on every ${b.name} gradient stop (AA large text ≥ 3)', () {
      final ink = GeneratedVenueImage.inkFor(b);
      for (final palette in GeneratedVenueImage.palettesFor(b)) {
        for (final stop in palette) {
          expect(contrastRatio(ink, stop), greaterThanOrEqualTo(4.5), reason: '$ink on $stop');
        }
      }
    });
  }
}
