import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_controller.dart';

const _kLocaleKey = 'rad_locale';

/// Supported app locales. FA uses RTL; EN uses LTR.
class AppLocale {
  const AppLocale(this.languageCode, this.countryCode);

  final String languageCode;
  final String? countryCode;

  Locale get locale => Locale(languageCode, countryCode);

  TextDirection get textDirection =>
      languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr;

  bool get isRtl => languageCode == 'fa';

  static const english = AppLocale('en', null);
  static const persian = AppLocale('fa', null);

  static const supported = [english, persian];

  static AppLocale fromLanguageCode(String? code) {
    return switch (code) {
      'fa' => persian,
      _ => english,
    };
  }

  String get storageValue => languageCode;
}

class LocaleController extends StateNotifier<AppLocale> {
  LocaleController(this._prefs) : super(AppLocale.english) {
    _restore();
  }

  final SharedPreferences _prefs;

  void _restore() {
    final stored = _prefs.getString(_kLocaleKey);
    state = AppLocale.fromLanguageCode(stored);
  }

  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    await _prefs.setString(_kLocaleKey, locale.storageValue);
  }

  Future<void> toggle() async {
    final next = state.languageCode == 'en'
        ? AppLocale.persian
        : AppLocale.english;
    await setLocale(next);
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, AppLocale>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return LocaleController(prefs);
    });
