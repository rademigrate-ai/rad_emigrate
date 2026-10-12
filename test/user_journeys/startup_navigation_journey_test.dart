import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';

/// Journey 1: Startup / navigation contracts.
///
/// Full [RadEmigrateApp] pump is covered by existing `test/widget_test.dart`.
/// Continuous splash animations + router bootstrap make unbounded settle
/// unreliable in CI without animation binding overrides; this file locks
/// redirect contracts that determine first-route behavior.
void main() {
  test(
    'UJ01 unauthenticated deep link to /visa redirects to login with from',
    () {
      final result = authRedirect(
        uri: Uri.parse('/visa'),
        isRestoring: false,
        isAuthenticated: false,
        profileComplete: false,
      );
      expect(result, isNotNull);
      final login = Uri.parse(result!);
      expect(login.path, '/login');
      expect(login.queryParameters['from'], '/visa');
    },
  );

  test(
    'UJ01b authenticated incomplete profile is sent to profile-completion',
    () {
      final result = authRedirect(
        uri: Uri.parse('/dashboard'),
        isRestoring: false,
        isAuthenticated: true,
        profileComplete: false,
      );
      expect(result, isNotNull);
      expect(Uri.parse(result!).path, '/profile-completion');
    },
  );

  test(
    'UJ01c external from query is rejected by restoredProtectedDestination',
    () {
      expect(
        restoredProtectedDestination('https://evil.example/phish'),
        '/dashboard',
      );
      expect(restoredProtectedDestination('/visa'), '/visa');
      expect(restoredProtectedDestination('/applications'), '/applications');
    },
  );

  test('UJ01d splash path does not redirect during restoration wait', () {
    expect(
      authRedirect(
        uri: Uri.parse('/splash'),
        isRestoring: true,
        isAuthenticated: false,
        profileComplete: false,
      ),
      isNull,
    );
  });
}
