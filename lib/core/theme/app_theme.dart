import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static const _radius = 16.0;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Vazirmatn',
      visualDensity: VisualDensity.standard,
    );
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primaryRed,
      onPrimary: AppColors.white,
      secondary: AppColors.navy,
      onSecondary: AppColors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.white,
      outline: AppColors.border,
    );
    return _build(
      base: base,
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.background,
      appBarForeground: AppColors.textPrimary,
      appBarBackground: AppColors.background,
      systemOverlay: SystemUiOverlayStyle.dark,
      cardColor: AppColors.surface,
      inputFill: AppColors.surface,
      borderColor: AppColors.border,
      focusedBorder: AppColors.navy,
      labelColor: AppColors.textSecondary,
      hintColor: AppColors.textTertiary,
      navBarBackground: AppColors.surface,
      navIndicator: AppColors.primaryRed.withValues(alpha: 0.12),
      navSelected: AppColors.primaryRed,
      navUnselected: AppColors.textSecondary,
      railBackground: AppColors.navy,
      dividerColor: AppColors.borderSubtle,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textTertiary: AppColors.textTertiary,
    );
  }

  static ThemeData dark() {
    const darkBg = Color(0xFF0F1419);
    const darkSurface = Color(0xFF1A222D);
    const darkSurfaceMuted = Color(0xFF243041);
    const darkTextPrimary = Color(0xFFF0F3F7);
    const darkTextSecondary = Color(0xFFA8B3C1);
    const darkTextTertiary = Color(0xFF7A8694);
    const darkBorder = Color(0xFF2E3A4A);
    const darkBorderSubtle = Color(0xFF243041);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Vazirmatn',
      visualDensity: VisualDensity.standard,
    );
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.primaryRed,
      onPrimary: AppColors.white,
      secondary: Color(0xFF5B8DEF),
      onSecondary: AppColors.white,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      error: Color(0xFFE85A64),
      onError: AppColors.white,
      outline: darkBorder,
    );
    return _build(
      base: base,
      colorScheme: colorScheme,
      scaffoldBackground: darkBg,
      appBarForeground: darkTextPrimary,
      appBarBackground: darkBg,
      systemOverlay: SystemUiOverlayStyle.light,
      cardColor: darkSurface,
      inputFill: darkSurfaceMuted,
      borderColor: darkBorder,
      focusedBorder: AppColors.primaryRed,
      labelColor: darkTextSecondary,
      hintColor: darkTextTertiary,
      navBarBackground: darkSurface,
      navIndicator: AppColors.primaryRed.withValues(alpha: 0.18),
      navSelected: AppColors.primaryRed,
      navUnselected: darkTextSecondary,
      railBackground: const Color(0xFF121820),
      dividerColor: darkBorderSubtle,
      textPrimary: darkTextPrimary,
      textSecondary: darkTextSecondary,
      textTertiary: darkTextTertiary,
    );
  }

  static ThemeData _build({
    required ThemeData base,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color appBarForeground,
    required Color appBarBackground,
    required SystemUiOverlayStyle systemOverlay,
    required Color cardColor,
    required Color inputFill,
    required Color borderColor,
    required Color focusedBorder,
    required Color labelColor,
    required Color hintColor,
    required Color navBarBackground,
    required Color navIndicator,
    required Color navSelected,
    required Color navUnselected,
    required Color railBackground,
    required Color dividerColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    return base.copyWith(
      splashFactory: InkRipple.splashFactory,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: appBarForeground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Vazirmatn',
          letterSpacing: 0,
        ),
        systemOverlayStyle: systemOverlay,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: focusedBorder, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: labelColor),
        hintStyle: TextStyle(color: hintColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: AppColors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          minimumSize: const Size(48, 52),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarBackground,
        indicatorColor: navIndicator,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? navSelected
                : navUnselected,
          ),
        ),
        elevation: 0,
        height: 76,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: railBackground,
        indicatorColor: AppColors.primaryRed,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: const Color(0xFFBCC7D6)),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(color: Color(0xFFBCC7D6)),
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          fontFamily: 'Vazirmatn',
          letterSpacing: 0,
          color: textPrimary,
          height: 1.12,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          fontFamily: 'Vazirmatn',
          letterSpacing: 0,
          color: textPrimary,
          height: 1.18,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Vazirmatn',
          letterSpacing: 0,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Vazirmatn',
          letterSpacing: 0,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: textTertiary, height: 1.45),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ).apply(fontFamily: 'Vazirmatn', letterSpacingFactor: 0),
    );
  }
}
