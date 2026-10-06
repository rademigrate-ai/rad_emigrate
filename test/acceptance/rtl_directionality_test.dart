import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/l10n/locale_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  final root = Directory.current.path;
  String read(String relative) => File('$root/$relative').readAsStringSync();

  test('AppLocale marks FA as RTL and EN as LTR', () {
    expect(AppLocale.persian.isRtl, isTrue);
    expect(AppLocale.persian.textDirection, TextDirection.rtl);
    expect(AppLocale.english.isRtl, isFalse);
    expect(AppLocale.english.textDirection, TextDirection.ltr);
  });

  test('app root applies Directionality from locale controller', () {
    final app = read('lib/app/app.dart');
    expect(app, contains('Directionality('));
    expect(app, contains('appLocale.textDirection'));
    expect(app, contains('supportedLocales'));
    expect(app, contains('AppLocalizations.delegate'));
  });

  test('directional helpers flip chevron back and forward for RTL', () {
    final icons = read('lib/core/widgets/directional_icons.dart');
    expect(icons, contains('directionalChevron'));
    expect(icons, contains('directionalBack'));
    expect(icons, contains('directionalForward'));
    expect(icons, contains('TextDirection.rtl'));
    expect(icons, contains('Icons.chevron_left'));
    expect(icons, contains('Icons.chevron_right'));
  });

  test('primary product pages use directional helpers not fixed arrows', () {
    final dashboard = read(
      'lib/features/dashboard/presentation/pages/dashboard_page.dart',
    );
    final visa = read('lib/features/visa/presentation/pages/visa_page.dart');
    final profile = read(
      'lib/features/profile/presentation/pages/profile_page.dart',
    );
    expect(dashboard, contains('directional'));
    expect(visa, contains('directional'));
    expect(profile, contains('directional'));
    expect(dashboard, isNot(contains('Icons.chevron_right')));
    expect(visa, isNot(contains('Icons.chevron_right')));
    expect(profile, isNot(contains('Icons.chevron_right')));
  });

  test('EN and FA core keys are non-empty and distinct', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fa = lookupAppLocalizations(const Locale('fa'));
    expect(en.appTitle.trim(), isNotEmpty);
    expect(fa.appTitle.trim(), isNotEmpty);
    expect(en.visaPathways, isNot(fa.visaPathways));
    expect(en.feedTitle, isNot(fa.feedTitle));
    expect(en.structuredDetailsPending.trim(), isNotEmpty);
    expect(fa.structuredDetailsPending.trim(), isNotEmpty);
  });
}
