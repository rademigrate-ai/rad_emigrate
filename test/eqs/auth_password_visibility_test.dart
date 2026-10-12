import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/login_page.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

Future<void> frames(WidgetTester t, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

class _FakeAuth implements AuthRepository {
  const _FakeAuth();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final prev = FlutterError.onError;
  setUpAll(() {
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('A RenderFlex overflowed')) return;
      prev?.call(d);
    };
  });
  tearDownAll(() => FlutterError.onError = prev);

  testWidgets('EQS-AUTH password visibility toggles tooltip and icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appBootstrapProvider.overrideWith((ref) async {}),
          authRepositoryProvider.overrideWithValue(const _FakeAuth()),
          authControllerProvider.overrideWith(
            (ref) => AuthController(ref.watch(authRepositoryProvider)),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginPage(),
        ),
      ),
    );
    await frames(tester);

    expect(find.byTooltip(l10n.showPassword), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.showPassword));
    await frames(tester, 10);
    expect(find.byTooltip(l10n.hidePassword), findsOneWidget);
  });
}
