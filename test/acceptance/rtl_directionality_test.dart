import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/l10n/locale_controller.dart';
import 'package:rad_emigrate/core/widgets/directional_icons.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

/// Guards Persian/RTL wiring so screens cannot regress to LTR-only chrome.
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

  test('directional helpers flip chevron/back/forward for RTL', () {
    final icons = read('lib/core/widgets/directional_icons.dart');
    expect(icons, contains('directionalChevron'));
    expect(icons, contains('directionalBack'));
    expect(icons, contains('directionalForward'));
    expect(icons, contains('TextDirection.rtl'));
    expect(icons, contains('Icons.chevron_left'));
    expect(icons, contains('Icons.chevron_right'));
  });

  testWidgets('directionalChevron resolves from ambient Directionality', (
    tester,
  ) async {
    IconData? ltr;
    IconData? rtl;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ltr = directionalChevron(context);
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                builder: (rtlContext) {
                  rtl = directionalChevron(rtlContext);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(ltr, Icons.chevron_right);
    expect(rtl, Icons.chevron_left);
  });

  test('primary product pages use directional helpers not fixed arrows', () {
    final pages = [
      'lib/features/dashboard/presentation/pages/dashboard_page.dart',
      'lib/features/visa/presentation/pages/visa_page.dart',
      'lib/features/profile/presentation/pages/profile_page.dart',
    ];
    for (final path in pages) {
      final source = read(path);
      expect(
        source.contains('directionalChevron') ||
            source.contains('directionalBack') ||
            source.contains('directionalForward'),
        isTrue,
        reason: '$path should use directional_* helpers',
      );
      expect(source, isNot(contains('Icons.chevron_right')));
      expect(source, isNot(contains('Icons.arrow_back,')));
    }
  });

  test('EN and FA localizations remain non-empty and distinct for core keys', () {
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
