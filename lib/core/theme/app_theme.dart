import 'package:flutter/material.dart';

class AppColors {
  static const primaryRed = Color(0xFFE30613);
  static const darkRed = Color(0xFFB4000B);
  static const navy = Color(0xFF303642);
  static const charcoal = Color(0xFF1F1D1D);
  static const background = Color(0xFFF5F5F5);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        secondary: AppColors.navy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}
