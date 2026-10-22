import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/routing/app_router.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/not_found_page.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/login_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/otp_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/register_page.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/visa_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late GoRouter _router;

/// Pumps the real app router for an unauthenticated visitor. The bootstrap
/// future resolves immediately so restoration never blocks navigation.
Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith(
          (ref) => AuthController(_NoopAuthRepository()),
        ),
        appBootstrapProvider.overrideWith((ref) async {}),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          _router = ref.watch(appRouterProvider);
          return MaterialApp.router(
            routerConfig: _router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _go(WidgetTester tester, String location) async {
  _router.go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('/signup renders the register form as a /register alias', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _go(tester, '/signup');

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('/register keeps rendering the register form', (tester) async {
    await _pumpApp(tester);
    await _go(tester, '/register');

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/explore aliases the Visa explorer (BUG-L01)', (tester) async {
    await _pumpApp(tester);
    await _go(tester, '/explore');

    expect(find.byType(VisaPage), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
    expect(find.byType(LoginPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/visa remains the canonical explorer route', (tester) async {
    await _pumpApp(tester);
    await _go(tester, '/visa');

    expect(find.byType(VisaPage), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown routes reach NotFound for unauthenticated visitors', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _go(tester, '/no-such-page');

    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(RegisterPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown deep segments reach NotFound, not login', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _go(tester, '/dashboard/extra');

    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('known protected routes still enforce authentication', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _go(tester, '/applications');

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public in-app routes allow guest access without forcing login', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _go(tester, '/dashboard');

    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(NotFoundPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/otp without flow context never presents the code form', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _go(tester, '/otp');

    // LoginPage itself contains text fields; the guarantee is that no OTP
    // verification page (and its bare code-entry box) is presented.
    expect(find.byType(OtpPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/otp with a signup identifier keeps the verification form', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _go(tester, '/otp?identifier=qa%40example.test&mode=signup');

    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('qa@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
