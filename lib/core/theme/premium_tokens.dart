import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

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

  bool get isDark => canvas.computeLuminance() < 0.1;
  Color get text => isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
  Color get disabledText => mutedText;
  Color get accent => AppColors.primaryRed;
  // The lighter foreground is reserved for small red text on dark surfaces.
  Color get accentForeground => isDark ? const Color(0xFFFF7685) : accent;
  Color get onAccent => Colors.white;
  Color get glass => surface.withValues(alpha: isDark ? .88 : .84);
  Color get success => isDark ? const Color(0xFF70D6A3) : AppColors.success;
  Color get warning => isDark ? const Color(0xFFF5CA77) : AppColors.warning;
  Color get error => isDark ? const Color(0xFFFF929A) : AppColors.error;
  Color get information => isDark ? const Color(0xFF88C9F7) : AppColors.info;
  Color get disabledSurface => surfaceElevated;
  Color get focus => accentForeground;

  static const light = PremiumTokens(
    canvas: AppColors.background,
    surface: Colors.white,
    surfaceElevated: AppColors.surfaceMuted,
    border: AppColors.border,
    mutedText: AppColors.textSecondary,
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFEDF3FA), Color(0xFFF8F1F4)],
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

abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double hero = 28;
  static const double pill = 999;
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
