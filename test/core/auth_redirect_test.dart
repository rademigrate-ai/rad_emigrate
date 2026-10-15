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

    test('unknown path is not forced to login so NotFound can render', () {
      expect(
        authRedirect(
          uri: Uri.parse('/does-not-exist-xyz'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
    });

    test('unknown path during restore is not forced through splash', () {
      expect(
        authRedirect(
          uri: Uri.parse('/random-unknown'),
          isRestoring: true,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
    });
  });

  group('public compatibility, unknown routes, and OTP context', () {
    test('/signup behaves like /register', () {
      expect(
        authRedirect(
          uri: Uri.parse('/signup'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
      expect(
        authRedirect(
          uri: Uri.parse('/signup'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        '/dashboard',
      );
      expect(
        authRedirect(
          uri: Uri.parse('/signup'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: false,
        ),
        '/profile-completion?from=%2Fdashboard',
      );
    });

    test('unknown routes fall through to NotFound for every auth state', () {
      for (final path in ['/does-not-exist', '/totally/missing']) {
        expect(
          authRedirect(
            uri: Uri.parse(path),
            isRestoring: false,
            isAuthenticated: false,
            profileComplete: false,
          ),
          isNull,
          reason: path,
        );
      }
      expect(
        authRedirect(
          uri: Uri.parse('/does-not-exist'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        isNull,
      );
      expect(
        authRedirect(
          uri: Uri.parse('/does-not-exist'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: false,
        ),
        isNull,
      );
      expect(
        authRedirect(
          uri: Uri.parse('/does-not-exist'),
          isRestoring: true,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
    });

    test('known protected routes still enforce authentication', () {
      expect(
        authRedirect(
          uri: Uri.parse('/dashboard'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        '/login?from=%2Fdashboard',
      );
      expect(
        authRedirect(
          uri: Uri.parse('/admin/operations'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        '/login?from=%2Fadmin%2Foperations',
      );
    });

    test('/otp without a verification flow context redirects to login', () {
      for (final path in [
        '/otp',
        '/otp?mode=signup',
        '/otp?identifier=not-an-email',
      ]) {
        expect(
          authRedirect(
            uri: Uri.parse(path),
            isRestoring: false,
            isAuthenticated: false,
            profileComplete: false,
          ),
          '/login',
          reason: '$path has no flow context',
        );
      }
    });

    test('/otp with a pending verification flow stays available', () {
      expect(
        authRedirect(
          uri: Uri.parse('/otp?identifier=qa%40example.test'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
      expect(
        authRedirect(
          uri: Uri.parse('/otp?identifier=qa%40example.test&mode=signup'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );
    });
  });
}
