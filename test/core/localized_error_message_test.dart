import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/errors/localized_error_message.dart';
import 'package:rad_emigrate/core/network/api_exception.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fa = lookupAppLocalizations(const Locale('fa'));

  test('unknown backend details are never returned to users', () {
    const error = ApiException(
      message: 'internal table profiles leaked sensitive detail',
      code: 'db_failure',
    );

    expect(localizedAuthError(error, en), en.errorGeneric);
    expect(localizedAuthError(error, en), isNot(contains('profiles')));
  });

  test('known auth failures map to localized safe messages', () {
    const network = ApiException(
      message: 'Socket connection failed',
      code: 'network_error',
    );
    const duplicate = ApiException(
      message: 'User already registered',
      code: 'user_already_exists',
    );
    const expiredOtp = ApiException(
      message: 'Token has expired',
      code: 'otp_expired',
    );

    expect(localizedAuthError(network, en), en.errorNetwork);
    expect(
      localizedAuthError(duplicate, en, context: AuthErrorContext.registration),
      en.accountAlreadyExists,
    );
    expect(
      localizedAuthError(expiredOtp, fa, context: AuthErrorContext.otp),
      fa.otpInvalidOrExpired,
    );
  });
}
