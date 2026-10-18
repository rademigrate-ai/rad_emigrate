import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/routing/app_router.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/login_page.dart';
import 'package:rad_emigrate/features/auth/presentation/pages/profile_completion_page.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthController extends AuthController {
  _TestAuthController({
    required bool isAuthenticated,
    required bool profileComplete,
  }) : super(_MockAuthRepository()) {
    state = AsyncData(
      UserSession(
        token: isAuthenticated ? 'test-token' : null,
        authenticated: isAuthenticated,
        profileComplete: profileComplete,
        userId: isAuthenticated ? 'test-user-id' : null,
        email: isAuthenticated ? 'test@example.com' : null,
      ),
    );
  }
}

late GoRouter _router;

Future<void> _pumpApp(
  WidgetTester tester, {
  bool isAuthenticated = false,
  bool profileComplete = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith(
          (ref) => _TestAuthController(
            isAuthenticated: isAuthenticated,
            profileComplete: profileComplete,
          ),
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
  group('E0-02 App Router Protected & Control Audit Matrix', () {
    const protectedRoutes = [
      '/applications',
      '/documents',
      '/documents/draft',
      '/notifications',
      '/admin',
      '/admin/ai-config',
      '/admin/operations',
      '/admin/ai-research',
      '/admin/consultations',
      '/admin/custom-sub-path',
    ];

    for (final route in protectedRoutes) {
      testWidgets('unauthenticated visitor to $route is redirected to login', (
        tester,
      ) async {
        await _pumpApp(tester, isAuthenticated: false);
        await _go(tester, route);

        expect(find.byType(LoginPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    const publicExploreRoutes = [
      '/dashboard',
      '/visa',
      '/feed',
      '/world-clock',
      '/profile',
      '/ai-assistant',
      '/consultation',
    ];

    for (final route in publicExploreRoutes) {
      testWidgets('unauthenticated visitor can explore $route as guest', (
        tester,
      ) async {
        await _pumpApp(tester, isAuthenticated: false);
        await _go(tester, route);

        expect(find.byType(LoginPage), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'authenticated user with incomplete profile goes to profile-completion',
      (tester) async {
        await _pumpApp(tester, isAuthenticated: true, profileComplete: false);
        await _go(tester, '/applications');

        expect(find.byType(ProfileCompletionPage), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    test('restoredProtectedDestination strips external URLs', () {
      expect(
        restoredProtectedDestination('https://evil.example.com/steal'),
        '/dashboard',
      );
      expect(
        restoredProtectedDestination('//evil.example.com/phish'),
        '/dashboard',
      );
      expect(
        restoredProtectedDestination('/applications?tab=active'),
        '/applications?tab=active',
      );
      expect(
        restoredProtectedDestination('/documents/draft'),
        '/documents/draft',
      );
    });

    test('isProtectedPath correctly classifies routes', () {
      expect(isProtectedPath('/applications'), isTrue);
      expect(isProtectedPath('/documents'), isTrue);
      expect(isProtectedPath('/documents/draft'), isTrue);
      expect(isProtectedPath('/admin'), isTrue);
      expect(isProtectedPath('/admin/ai-config'), isTrue);
      expect(isProtectedPath('/admin/unknown-nested'), isTrue);
      expect(isProtectedPath('/dashboard'), isFalse);
      expect(isProtectedPath('/visa'), isFalse);
      expect(isProtectedPath('/feed'), isFalse);
      expect(isProtectedPath('/world-clock'), isFalse);
    });
  });
}
