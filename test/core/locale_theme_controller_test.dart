import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rad_emigrate/core/l10n/locale_controller.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLocale', () {
    test('FA is RTL and EN is LTR', () {
      expect(AppLocale.persian.isRtl, isTrue);
      expect(AppLocale.persian.textDirection.name, 'rtl');
      expect(AppLocale.english.isRtl, isFalse);
      expect(AppLocale.english.textDirection.name, 'ltr');
    });

    test('fromLanguageCode defaults to English', () {
      expect(AppLocale.fromLanguageCode(null).languageCode, 'en');
      expect(AppLocale.fromLanguageCode('fa').languageCode, 'fa');
    });
  });

  group('LocaleController', () {
    test('restores and persists locale', () async {
      SharedPreferences.setMockInitialValues({'rad_locale': 'fa'});
      final prefs = await SharedPreferences.getInstance();
      final controller = LocaleController(prefs);
      expect(controller.state.languageCode, 'fa');

      await controller.setLocale(AppLocale.english);
      expect(controller.state.languageCode, 'en');
      expect(prefs.getString('rad_locale'), 'en');
    });
  });

  group('ThemeController', () {
    test('restores and persists theme preference', () async {
      SharedPreferences.setMockInitialValues({'rad_theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);
      expect(controller.state, AppThemePreference.dark);
      expect(controller.state.themeMode.name, 'dark');

      await controller.setPreference(AppThemePreference.system);
      expect(controller.state, AppThemePreference.system);
      expect(prefs.getString('rad_theme_mode'), 'system');
    });
  });
}
