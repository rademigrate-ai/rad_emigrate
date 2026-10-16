import 'package:flutter/material.dart';

/// Shared premium layout and surface tokens.
///
/// Keeping these values in a [ThemeExtension] makes high-impact pages adapt to
/// light/dark mode without copying color literals across features.
@immutable
class PremiumTokens extends ThemeExtension<PremiumTokens> {
  const PremiumTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.mutedText,
    required this.heroGradient,
    required this.shadow,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color mutedText;
  final LinearGradient heroGradient;
  final List<BoxShadow> shadow;

  static const light = PremiumTokens(
    canvas: Color(0xFFF6F7F9),
    surface: Colors.white,
    surfaceElevated: Color(0xFFFCFCFD),
    border: Color(0xFFE3E6EB),
    mutedText: Color(0xFF667080),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF111723), Color(0xFF27121A), Color(0xFF0A2029)],
    ),
    shadow: [
      BoxShadow(
        color: Color(0x14020A12),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
  );

  static const dark = PremiumTokens(
    canvas: Color(0xFF070A0F),
    surface: Color(0xFF10151D),
    surfaceElevated: Color(0xFF171D27),
    border: Color(0xFF29313D),
    mutedText: Color(0xFFAAB2BF),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF171019), Color(0xFF09141D), Color(0xFF1B0B11)],
    ),
    shadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );

  @override
  PremiumTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? mutedText,
    LinearGradient? heroGradient,
    List<BoxShadow>? shadow,
  }) {
    return PremiumTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      mutedText: mutedText ?? this.mutedText,
      heroGradient: heroGradient ?? this.heroGradient,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  PremiumTokens lerp(covariant PremiumTokens? other, double t) {
    if (other == null) return this;
    return PremiumTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      shadow: t < .5 ? shadow : other.shadow,
    );
  }
}

extension PremiumThemeContext on BuildContext {
  PremiumTokens get premium =>
      Theme.of(this).extension<PremiumTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? PremiumTokens.dark
          : PremiumTokens.light);
}

abstract final class AppBreakpoints {
  static const double tablet = 600;
  static const double desktop = 900;
  static const double wideDesktop = 1200;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}
