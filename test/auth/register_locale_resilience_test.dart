import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/l10n/locale_controller.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/register_page.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _email = 'qa@example.test';
const _phone = '+989121112233';
const _password = 'Str0ngPass!';

/// Mirrors the real app wiring: locale from [localeControllerProvider] plus an
/// explicit Directionality builder, exactly like `RadEmigrateApp`.
Future<void> _pumpRegister(
  WidgetTester tester, {
  required Size viewport,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith(
          (ref) => AuthController(_NoopAuthRepository()),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(localeControllerProvider);
          return MaterialApp(
            locale: locale.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => Directionality(
              textDirection: locale.textDirection,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const RegisterPage(),
          );
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _toggleLocale(WidgetTester tester) async {
  final toPersian = find.text('فارسی');
  final target = toPersian.evaluate().isNotEmpty
      ? toPersian
      : find.text('English');
  expect(target, findsOneWidget, reason: 'locale toggle control must be shown');
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  for (final viewport in {
    'desktop': const Size(1280, 900),
    'mobile': const Size(390, 844),
  }.entries) {
    testWidgets(
      '${viewport.key}: five consecutive locale toggles keep the register form and its state',
      (tester) async {
        await _pumpRegister(tester, viewport: viewport.value);

        expect(find.byType(TextFormField), findsNWidgets(3));

        await tester.enterText(find.byType(TextFormField).at(0), _email);
        await tester.enterText(find.byType(TextFormField).at(1), _phone);
        await tester.enterText(find.byType(TextFormField).at(2), _password);
        await tester.pump(const Duration(milliseconds: 300));

        for (var i = 0; i < 5; i++) {
          await _toggleLocale(tester);

          expect(
            tester.takeException(),
            isNull,
            reason: 'locale toggle ${i + 1} must not throw',
          );
          expect(
            find.byType(TextFormField),
            findsNWidgets(3),
            reason: 'all three fields must survive toggle ${i + 1}',
          );
          expect(find.text(_email), findsOneWidget);
          expect(find.text(_phone), findsOneWidget);
          expect(find.text(_password), findsOneWidget);
        }
      },
    );

    testWidgets(
      '${viewport.key}: form stays interactive and valid after locale churn',
      (tester) async {
        await _pumpRegister(tester, viewport: viewport.value);

        await tester.enterText(find.byType(TextFormField).at(0), _email);
        await tester.enterText(find.byType(TextFormField).at(1), _phone);
        await tester.enterText(find.byType(TextFormField).at(2), _password);

        for (var i = 0; i < 5; i++) {
          await _toggleLocale(tester);
        }

        // The Next button must still exist and validation must pass.
        final l10n = AppLocalizations.of(
          tester.element(find.byType(RegisterPage)),
        );
        await tester.ensureVisible(find.text(l10n.next));
        await tester.tap(find.text(l10n.next));
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        // Valid submit attempts navigation via the auth controller; the noop
        // repository throws noSuchMethod, which the page must catch and render
        // as an inline error instead of losing the form.
        expect(find.byType(TextFormField), findsNWidgets(3));
        expect(find.text(_email), findsOneWidget);
      },
    );
  }
}
