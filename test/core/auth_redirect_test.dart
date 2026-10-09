import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';

void main() {
  group('authRedirect', () {
    test('unauthenticated cold launch reaches login after restoration', () {
      expect(
        authRedirect(
          uri: Uri.parse('/splash'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
      expect(
        authRedirect(
          uri: Uri.parse('/applications'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        '/login?from=%2Fapplications',
      );
    });

    test(
      'authenticated deep link waits for restoration and keeps destination',
      () {
        final uri = Uri.parse('/documents?kind=passport');
        final redirected = authRedirect(
          uri: uri,
          isRestoring: true,
          isAuthenticated: false,
          profileComplete: false,
        );

        expect(redirected, isNotNull);
        final splashUri = Uri.parse(redirected!);
        expect(splashUri.path, '/splash');
        expect(
          restoredProtectedDestination(splashUri.queryParameters['from']),
          uri.toString(),
        );
        expect(
          authRedirect(
            uri: uri,
            isRestoring: false,
            isAuthenticated: true,
            profileComplete: true,
          ),
          isNull,
        );
      },
    );

    test(
      'login preserves query-bearing destination and rejects external from',
      () {
        final target = Uri.parse('/documents?kind=passport');
        final login = Uri.parse(
          authRedirect(
            uri: target,
            isRestoring: false,
            isAuthenticated: false,
            profileComplete: false,
          )!,
        );
        expect(login.path, '/login');
        expect(login.queryParameters['from'], target.toString());
        expect(
          authRedirect(
            uri: login,
            isRestoring: false,
            isAuthenticated: true,
            profileComplete: true,
          ),
          target.toString(),
        );
        expect(
          authRedirect(
            uri: Uri.parse('/login?from=https%3A%2F%2Fevil.example'),
            isRestoring: false,
            isAuthenticated: true,
            profileComplete: true,
          ),
          '/dashboard',
        );
      },
    );

    test('expired session redirects to login after restoration', () {
      expect(
        authRedirect(
          uri: Uri.parse('/documents'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        '/login?from=%2Fdocuments',
      );
    });

    test('incomplete profile routes to profile completion', () {
      expect(
        authRedirect(
          uri: Uri.parse('/applications'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: false,
        ),
        '/profile-completion?from=%2Fapplications',
      );
    });

    test(
      'restored public route resolves to dashboard or profile completion',
      () {
        expect(
          authRedirect(
            uri: Uri.parse('/login'),
            isRestoring: false,
            isAuthenticated: true,
            profileComplete: true,
          ),
          '/dashboard',
        );
        expect(
          authRedirect(
            uri: Uri.parse('/register'),
            isRestoring: false,
            isAuthenticated: true,
            profileComplete: false,
          ),
          '/profile-completion?from=%2Fdashboard',
        );
      },
    );

    test('forgot and reset password stay public', () {
      expect(
        authRedirect(
          uri: Uri.parse('/forgot-password'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
      expect(
        authRedirect(
          uri: Uri.parse('/reset-password'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
      // Recovery session may be authenticated; still stay on set-password.
      expect(
        authRedirect(
          uri: Uri.parse('/reset-password'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        isNull,
      );
    });

    test('invalid restored destinations fall back to dashboard', () {
      expect(
        restoredProtectedDestination('https://example.com/'),
        '/dashboard',
      );
      expect(restoredProtectedDestination('/splash'), '/dashboard');
      expect(restoredProtectedDestination('/ai-assistant'), '/ai-assistant');
      expect(restoredProtectedDestination('/admin'), '/admin');
      expect(restoredProtectedDestination('/feed'), '/feed');
      expect(restoredProtectedDestination('/world-clock'), '/world-clock');
    });

    test('world-clock is a protected route for deep-link restoration', () {
      final uri = Uri.parse('/world-clock');
      final redirected = authRedirect(
        uri: uri,
        isRestoring: true,
        isAuthenticated: false,
        profileComplete: false,
      );
      expect(redirected, isNotNull);
      final splashUri = Uri.parse(redirected!);
      expect(splashUri.path, '/splash');
      expect(
        restoredProtectedDestination(splashUri.queryParameters['from']),
        uri.toString(),
      );
      expect(
        authRedirect(
          uri: uri,
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        isNull,
      );
    });
  });
}
