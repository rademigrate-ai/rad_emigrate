import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'rad_theme_mode';

enum AppThemePreference {
  light,
  dark,
  system;

  ThemeMode get themeMode => switch (this) {
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.system => ThemeMode.system,
      };

  static AppThemePreference fromStorage(String? value) {
    return switch (value) {
      'light' => AppThemePreference.light,
      'dark' => AppThemePreference.dark,
      'system' => AppThemePreference.system,
      _ => AppThemePreference.system,
    };
  }

  String get storageValue => name;
}

class ThemeController extends StateNotifier<AppThemePreference> {
  ThemeController(this._prefs) : super(AppThemePreference.system) {
    _restore();
  }

  final SharedPreferences _prefs;

  void _restore() {
    final stored = _prefs.getString(_kThemeModeKey);
    state = AppThemePreference.fromStorage(stored);
  }

  Future<void> setPreference(AppThemePreference preference) async {
    state = preference;
    await _prefs.setString(_kThemeModeKey, preference.storageValue);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main/bootstrap',
  );
});

final themeControllerProvider =
    StateNotifierProvider<ThemeController, AppThemePreference>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeController(prefs);
});
