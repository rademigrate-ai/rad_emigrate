import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';

/// Acceptance coverage for protected-route rejection and session restoration.
void main() {
  group('authRedirect acceptance', () {
    test(
      'unauthenticated access to each protected route redirects to login',
      () {
        const protected = [
          '/dashboard',
          '/visa',
          '/applications',
          '/documents',
          '/profile',
          '/ai-assistant',
          '/profile-completion',
          '/admin',
        ];
        for (final path in protected) {
          expect(
            authRedirect(
              uri: Uri.parse(path),
              isRestoring: false,
              isAuthenticated: false,
              profileComplete: false,
            ),
            '/login',
            reason: path,
          );
        }
      },
    );

    test(
      'authenticated incomplete profile is forced to profile-completion',
      () {
        expect(
          authRedirect(
            uri: Uri.parse('/admin'),
            isRestoring: false,
            isAuthenticated: true,
            profileComplete: false,
          ),
          '/profile-completion',
        );
        expect(
          authRedirect(
            uri: Uri.parse('/ai-assistant'),
            isRestoring: false,
            isAuthenticated: true,
            profileComplete: false,
          ),
          '/profile-completion',
        );
      },
    );

    test('authenticated complete profile may stay on admin route', () {
      expect(
        authRedirect(
          uri: Uri.parse('/admin'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        isNull,
      );
    });

    test(
      'session restoration preserves deep-link for known protected routes',
      () {
        final redirected = authRedirect(
          uri: Uri.parse('/applications?id=abc'),
          isRestoring: true,
          isAuthenticated: false,
          profileComplete: false,
        );
        expect(redirected, isNotNull);
        final splash = Uri.parse(redirected!);
        expect(splash.path, '/splash');
        expect(
          restoredProtectedDestination(splash.queryParameters['from']),
          '/applications?id=abc',
        );
      },
    );

    test(
      'external or unknown restored destinations fall back to dashboard',
      () {
        expect(
          restoredProtectedDestination('https://evil.example/phish'),
          '/dashboard',
        );
        expect(
          restoredProtectedDestination('/unknown-route'),
          '/dashboard',
        );
        expect(restoredProtectedDestination(null), '/dashboard');
      },
    );

    test(
      'admin is not treated as a restorable protected deep-link destination',
      () {
        // Documented behavior: /admin is omitted from _protectedRoutes.
        // Unauthenticated deep-links to /admin still redirect to login via
        // the generic unauthenticated branch; restoration falls back safely.
        expect(restoredProtectedDestination('/admin'), '/dashboard');
      },
    );
  });
}
