import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/profile/presentation/pages/profile_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildGuestProfile({required SharedPreferences prefs, Size? size}) {
    final auth = AuthController(_MockAuthRepo())
      ..applySession(const UserSession(authenticated: false));

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => auth),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size ?? const Size(390, 844),
            disableAnimations: true,
          ),
          child: const ProfilePage(),
        ),
      ),
    );
  }

  testWidgets(
    'Guest profile stacks sign-in and create-account buttons vertically on narrow mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildGuestProfile(prefs: prefs, size: const Size(360, 800)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);

      final signInPos = tester.getTopLeft(find.text('Sign in'));
      final createPos = tester.getTopLeft(find.text('Create an account'));

      // On narrow viewport, buttons stack vertically: Create an account is below Sign in
      expect(createPos.dy, greaterThan(signInPos.dy));
    },
  );

  testWidgets(
    'Guest profile places sign-in and create-account buttons horizontally on desktop',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildGuestProfile(prefs: prefs, size: const Size(1280, 900)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);

      final signInPos = tester.getTopLeft(find.text('Sign in'));
      final createPos = tester.getTopLeft(find.text('Create an account'));

      // On wide viewport, buttons sit side by side: vertical centers are aligned
      expect((createPos.dy - signInPos.dy).abs(), lessThan(10));
    },
  );
}
