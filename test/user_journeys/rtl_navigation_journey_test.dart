import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/l10n/locale_controller.dart';
import 'package:rad_emigrate/core/widgets/directional_icons.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

/// Journey 10: Persian RTL layout helpers and locale direction.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UJ10 AppLocale persian is RTL and english is LTR', () {
    expect(AppLocale.persian.isRtl, isTrue);
    expect(AppLocale.persian.textDirection, TextDirection.rtl);
    expect(AppLocale.english.isRtl, isFalse);
    expect(AppLocale.english.textDirection, TextDirection.ltr);
  });

  testWidgets('UJ10b directionalBack flips under RTL Directionality', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: _BackProbe(),
        ),
      ),
    );
    await tester.pump();
    final ltr = tester.widget<Icon>(find.byType(Icon)).icon;

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: _BackProbe(),
        ),
      ),
    );
    await tester.pump();
    final rtl = tester.widget<Icon>(find.byType(Icon)).icon;

    expect(ltr, isNot(equals(rtl)), reason: 'Back icon must flip for RTL');
  });

  test('UJ10c FA and EN product strings differ for core nav labels', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fa = lookupAppLocalizations(const Locale('fa'));
    expect(en.visaPathways, isNot(fa.visaPathways));
    expect(en.signIn, isNot(fa.signIn));
    expect(en.consultationTitle, isNot(fa.consultationTitle));
  });
}

class _BackProbe extends StatelessWidget {
  const _BackProbe();
  @override
  Widget build(BuildContext context) => Icon(directionalBack(context));
}
