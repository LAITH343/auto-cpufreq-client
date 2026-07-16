import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The design uses Fira Sans for UI text and Fira Code for numeric/monospace
/// readouts. These helpers centralize both so widgets stay terse.
class AppFonts {
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.firaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.firaCode(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// The uppercase, wide-tracked section labels used throughout the design.
  static TextStyle sectionLabel(Color color) => sans(
        size: 11,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: 0.7,
      );
}
