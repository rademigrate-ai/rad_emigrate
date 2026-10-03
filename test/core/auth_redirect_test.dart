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
        '/login',
      );
    });

    test('authenticated deep link waits for restoration and keeps destination', () {
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
    });

    test('expired session redirects to login after restoration', () {
      expect(
        authRedirect(
          uri: Uri.parse('/documents'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        '/login',
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
        '/profile-completion',
      );
    });

    test('restored public route resolves to dashboard or profile completion', () {
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
        '/profile-completion',
      );
    });

    test('invalid restored destinations fall back to dashboard', () {
      expect(restoredProtectedDestination('https://example.com/'), '/dashboard');
      expect(restoredProtectedDestination('/splash'), '/dashboard');
      expect(restoredProtectedDestination('/ai-assistant'), '/ai-assistant');
    });
  });
}
