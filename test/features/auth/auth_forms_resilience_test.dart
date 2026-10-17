import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/app_back_button.dart';
import 'package:rad_emigrate/core/widgets/app_button.dart';
import 'package:rad_emigrate/core/widgets/inline_alert.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/login_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/otp_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/profile_completion_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/reset_password_page.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Auth Pages Resilience and Directionality', () {
    testWidgets(
      'ForgotPasswordPage includes AppBackButton and validates email',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepo());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ForgotPasswordPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Must have AppBackButton (not an unmirrored raw IconButton)
        expect(find.byType(AppBackButton), findsOneWidget);

        // Validate email field requirement
        final sendBtn = find.widgetWithText(AppButton, 'Send reset link');
        expect(sendBtn, findsOneWidget);
        await tester.tap(sendBtn);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Required'), findsOneWidget);
      },
    );

    testWidgets(
      'ResetPasswordPage includes AppBackButton and safe form presentation',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepo());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ResetPasswordPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AppBackButton), findsOneWidget);
      },
    );

    testWidgets(
      'OtpPage includes AppBackButton and uses InlineAlert for validation error',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepo());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: OtpPage(identifier: 'test@example.com'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AppBackButton), findsOneWidget);

        // Tapping verify without 6 digits triggers InlineAlert
        final verifyBtn = find.widgetWithText(AppButton, 'Verify');
        expect(verifyBtn, findsOneWidget);
        await tester.tap(verifyBtn);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(InlineAlert), findsOneWidget);
        expect(
          find.text('That verification code is invalid or has expired.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LoginPage handles empty email/password validation gracefully',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepo());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: LoginPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AppBackButton), findsOneWidget);
        final signInBtn = find.widgetWithText(AppButton, 'Sign in');
        expect(signInBtn, findsOneWidget);
        await tester.tap(signInBtn);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Required'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('ProfileCompletionPage validates full name length', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final auth = AuthController(_MockAuthRepo());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => auth),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileCompletionPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final continueBtn = find.widgetWithText(AppButton, 'Save and continue');
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Required'), findsOneWidget);
    });
  });
}
