import 'package:flutter/material.dart';

/// The set of accent colors offered in settings.
const List<Color> kAccentChoices = [
  Color(0xFF4C8CF5),
  Color(0xFF46B06E),
  Color(0xFFE95420),
  Color(0xFFC7A23A),
];

/// A full color token set for one theme, mirroring the design's `theme()`
/// object. Values are lifted verbatim from the reference design.
class Palette {
  final Color backdrop;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color hover;
  final Color border;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final List<BoxShadow> shadow;
  final bool isDark;

  const Palette({
    required this.backdrop,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.hover,
    required this.border,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.shadow,
    required this.isDark,
  });

  factory Palette.dark(Color accent) => Palette(
        backdrop: const Color(0xFF0B0C10),
        bg: const Color(0xFF14161C),
        surface: const Color(0xFF1B1E26),
        surface2: const Color(0xFF22262F),
        hover: const Color(0xFF2A2F3A),
        border: Colors.white.withValues(alpha: 0.09),
        text: const Color(0xFFF3F4F6),
        textDim: Colors.white.withValues(alpha: 0.62),
        textFaint: Colors.white.withValues(alpha: 0.38),
        accent: accent,
        accentSoft: accent.withValues(alpha: 0.16),
        success: const Color(0xFF2ECC71),
        successSoft: const Color(0xFF2ECC71).withValues(alpha: 0.14),
        warning: const Color(0xFFF5A524),
        warningSoft: const Color(0xFFF5A524).withValues(alpha: 0.14),
        danger: const Color(0xFFF16A6A),
        dangerSoft: const Color(0xFFF16A6A).withValues(alpha: 0.14),
        shadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
        isDark: true,
      );

  factory Palette.light(Color accent) => Palette(
        backdrop: const Color(0xFFE9E7E2),
        bg: const Color(0xFFF7F7F5),
        surface: const Color(0xFFFFFFFF),
        surface2: const Color(0xFFF0EFEC),
        hover: const Color(0xFFE9E8E4),
        border: Colors.black.withValues(alpha: 0.09),
        text: const Color(0xFF1C1D1F),
        textDim: Colors.black.withValues(alpha: 0.62),
        textFaint: Colors.black.withValues(alpha: 0.40),
        accent: accent,
        accentSoft: accent.withValues(alpha: 0.12),
        success: const Color(0xFF1A9B52),
        successSoft: const Color(0xFF1A9B52).withValues(alpha: 0.10),
        warning: const Color(0xFFA8660F),
        warningSoft: const Color(0xFFC67A11).withValues(alpha: 0.12),
        danger: const Color(0xFFD8453C),
        dangerSoft: const Color(0xFFD8453C).withValues(alpha: 0.10),
        shadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
        isDark: false,
      );

  /// Default accent for a mode when the user hasn't picked one.
  static Color defaultAccent(bool dark) =>
      dark ? const Color(0xFF4C8CF5) : const Color(0xFF2F6FED);
}
