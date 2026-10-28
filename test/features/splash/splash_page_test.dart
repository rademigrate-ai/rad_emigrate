import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/splash/presentation/pages/splash_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _createTestApp({
  required GoRouter router,
  UserSession? session,
  Future<void> Function()? bootstrapOverride,
}) {
  return ProviderScope(
    overrides: [
      verifiedUserSessionProvider.overrideWithValue(session),
      appBootstrapProvider.overrideWith((ref) async {
        if (bootstrapOverride != null) {
          await bootstrapOverride();
        }
      }),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SplashPage Acceptance and Navigation Flow', () {
    testWidgets('renders brand typography and splash loading elements', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('dashboard-screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        _createTestApp(
          router: router,
          bootstrapOverride: () async {
            // Delay resolution to allow asserting splash state
            await Future<void>.delayed(const Duration(milliseconds: 100));
          },
        ),
      );

      // Verify splash presentation elements
      expect(find.text('RAD Emigrate'), findsOneWidget);
      expect(find.byType(SplashPage), findsOneWidget);

      // Let bootstrap complete
      await tester.pumpAndSettle();
      expect(find.text('dashboard-screen'), findsOneWidget);
    });

    testWidgets(
      'unauthenticated visitor without destination routes to /dashboard',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/splash',
          routes: [
            GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const Scaffold(body: Text('dashboard-screen')),
            ),
          ],
        );

        await tester.pumpWidget(_createTestApp(router: router));
        await tester.pumpAndSettle();

        expect(find.text('dashboard-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'unauthenticated visitor with protected destination routes to /login?from=...',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/splash',
          routes: [
            GoRoute(
              path: '/splash',
              builder: (_, _) => const SplashPage(destination: '/applications'),
            ),
            GoRoute(
              path: '/login',
              builder: (_, state) => Scaffold(
                body: Text(
                  'login-screen from=${state.uri.queryParameters['from']}',
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(_createTestApp(router: router));
        await tester.pumpAndSettle();

        expect(find.text('login-screen from=/applications'), findsOneWidget);
      },
    );

    testWidgets(
      'authenticated user navigates directly to requested destination',
      (tester) async {
        const userSession = UserSession(
          token: 'auth-jwt-token',
          userId: 'verified-user-123',
          authenticated: true,
          profileComplete: true,
        );

        final router = GoRouter(
          initialLocation: '/splash',
          routes: [
            GoRoute(
              path: '/splash',
              builder: (_, _) => const SplashPage(destination: '/applications'),
            ),
            GoRoute(
              path: '/applications',
              builder: (_, _) =>
                  const Scaffold(body: Text('applications-screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          _createTestApp(router: router, session: userSession),
        );
        await tester.pumpAndSettle();

        expect(find.text('applications-screen'), findsOneWidget);
      },
    );

    testWidgets('recovers safely when app bootstrap throws an error', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('dashboard-screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        _createTestApp(
          router: router,
          bootstrapOverride: () async {
            throw StateError('Simulated bootstrap network failure');
          },
        ),
      );
      await tester.pumpAndSettle();

      // Fails safe to unauthenticated dashboard
      expect(find.text('dashboard-screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
