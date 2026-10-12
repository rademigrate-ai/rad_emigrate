import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/app_button.dart';
import 'package:rad_emigrate/core/widgets/premium_visuals.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

/// Regression: Auth CTA labels must not RenderFlex-overflow in constrained
/// form columns (Login/Register), including long FA labels and text scale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpConstrained(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(360, 800),
    double textScale = 1.0,
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(child: SizedBox(width: 320, child: child)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppButton expanded with long label does not overflow at 320px', (
    tester,
  ) async {
    await pumpConstrained(
      tester,
      child: AppButton(
        label: 'Continue with a very long authentication action label',
        icon: Icons.arrow_forward_rounded,
        onPressed: () {},
      ),
    );

    // Must not report layout overflow.
    expect(tester.takeException(), isNull);
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets(
    'AppButton expanded FA-length label + textScale 1.3 does not overflow',
    (tester) async {
      await pumpConstrained(
        tester,
        textScale: 1.3,
        direction: TextDirection.rtl,
        child: AppButton(
          label: 'ایجاد حساب کاربری و ادامه مسیر مهاجرت',
          icon: Icons.person_add_alt_1,
          onPressed: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('EditorialKicker long label does not overflow at 280px', (
    tester,
  ) async {
    await pumpConstrained(
      tester,
      size: const Size(280, 600),
      child: const SizedBox(
        width: 260,
        child: EditorialKicker(
          index: '02',
          label: 'ACCESS PORTAL WITH EXTENDED EDITORIAL COPY',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
