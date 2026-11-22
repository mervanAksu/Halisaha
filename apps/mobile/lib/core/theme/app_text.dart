import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Barlow Condensed "scoreboard" style for times, prices and big numbers (docs/DESIGN.md "Tipografi").
TextStyle numericStyle(
  BuildContext context, {
  double size = 17,
  FontWeight weight = FontWeight.w600,
  FontStyle fontStyle = FontStyle.normal,
  Color? color,
}) {
  return GoogleFonts.barlowCondensed(
    fontSize: size,
    fontWeight: weight,
    fontStyle: fontStyle,
    height: 1.15,
    color: color ?? context.tokens.textPrimary,
  );
}
