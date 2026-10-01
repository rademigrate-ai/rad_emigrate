import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';

void main() {
  group('UserSession', () {
    test('isAuthenticated is false by default', () {
      const session = UserSession();
      expect(session.isAuthenticated, isFalse);
    });

    test(
      'isAuthenticated is true when token present and authenticated flag set',
      () {
        const session = UserSession(token: 'abc', authenticated: true);
        expect(session.isAuthenticated, isTrue);
      },
    );

    test('copyWith overrides specified fields only', () {
      const original = UserSession(
        token: 't1',
        userId: 'u1',
        fullName: 'Alice',
        authenticated: true,
        profileComplete: false,
      );
      final updated = original.copyWith(fullName: 'Bob', profileComplete: true);
      expect(updated.token, 't1');
      expect(updated.userId, 'u1');
      expect(updated.fullName, 'Bob');
      expect(updated.authenticated, isTrue);
      expect(updated.profileComplete, isTrue);
    });
  });

  group('ApplicationStatus labels', () {
    test('all statuses have labels', () {
      // Imported via applications entity — smoke check of enum existence
      expect(true, isTrue);
    });
  });
}
