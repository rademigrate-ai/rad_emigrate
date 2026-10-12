import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/login_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/register_page.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

Future<void> _pumpFrames(WidgetTester tester, {int n = 18}) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<Widget> _wrap(Widget child, {Locale locale = const Locale('en')}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appBootstrapProvider.overrideWith((ref) async {}),
      authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      authControllerProvider.overrideWith(
        (ref) => AuthController(ref.watch(authRepositoryProvider)),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('LoginPage has no RenderFlex overflow at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _wrap(const LoginPage()));
      await _pumpFrames(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Login must not overflow at $width',
      );
      expect(find.byType(Form), findsOneWidget);
    });
  }

  testWidgets(
    'LoginPage FA + textScale 1.3 has no RenderFlex overflow at 360',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: await _wrap(const LoginPage(), locale: const Locale('fa')),
        ),
      );
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Form), findsOneWidget);
    },
  );

  testWidgets('RegisterPage has no RenderFlex overflow at 360', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(const RegisterPage()));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(Form), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<UserSession?> restoreSession() async => null;

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async => const UserSession();

  @override
  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  }) async => const UserSession();

  @override
  Future<void> resendOtp({
    required String identifier,
    bool signup = false,
  }) async {}

  @override
  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
    bool signup = false,
  }) async => const UserSession();

  @override
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async => const UserSession();

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset({required String email}) async {}
}
