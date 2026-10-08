import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/auth/password_recovery.dart';
import 'package:rad_emigrate/core/network/api_exception.dart';

void main() {
  group('password recovery helpers', () {
    test('builds a path-based recovery redirect for path URL strategy', () {
      expect(
        passwordRecoveryRedirectTo(
          Uri.parse('https://rad-emigrate.onrender.com/forgot-password'),
        ),
        'https://rad-emigrate.onrender.com/reset-password',
      );
      // Origin is still derived correctly when the current page uses a hash.
      expect(
        passwordRecoveryRedirectTo(
          Uri.parse('https://rad-emigrate.onrender.com/#/forgot-password'),
        ),
        'https://rad-emigrate.onrender.com/reset-password',
      );
    });

    test('rejects origins unavailable to a browser build', () {
      expect(passwordRecoveryRedirectTo(Uri()), isNull);
    });

    test(
      'classifies Supabase recovery throttling without exposing details',
      () {
        const error = ApiException(
          message: 'Email rate limit exceeded',
          statusCode: 429,
          code: 'over_email_send_rate_limit',
        );

        expect(isPasswordRecoveryRateLimited(error), isTrue);
        expect(isPasswordRecoverySessionError(error), isFalse);
      },
    );

    test('classifies expired or missing recovery sessions', () {
      const error = ApiException(
        message: 'Auth session missing!',
        statusCode: 403,
        code: 'session_not_found',
      );

      expect(isPasswordRecoverySessionError(error), isTrue);
    });
  });
}
