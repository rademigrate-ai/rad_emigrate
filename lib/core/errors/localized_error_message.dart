import 'dart:async';

import '../../l10n/app_localizations.dart';
import '../network/api_exception.dart';

enum AuthErrorContext { signIn, registration, otp }

/// Converts known transport failures into safe, localized user messages.
///
/// Unknown exception details stay out of the presentation layer. Technical
/// errors remain available to the state/repository boundary for diagnostics.
String localizedAuthError(
  Object error,
  AppLocalizations l10n, {
  AuthErrorContext context = AuthErrorContext.signIn,
}) {
  if (error is TimeoutException) return l10n.errorNetwork;

  final errStr = error.toString().toLowerCase();
  String code = '';
  String message = errStr;
  int? statusCode;

  if (error is ApiException) {
    code = error.code?.toLowerCase() ?? '';
    message = error.message.toLowerCase();
    statusCode = error.statusCode;
  } else {
    try {
      final dynamic dyn = error;
      if (dyn.code != null) code = '${dyn.code}'.toLowerCase();
      if (dyn.message != null) message = '${dyn.message}'.toLowerCase();
      if (dyn.statusCode != null) {
        final sc = dyn.statusCode;
        if (sc is int) {
          statusCode = sc;
        } else if (sc is String) {
          statusCode = int.tryParse(sc);
        }
      }
    } catch (_) {}
  }

  final known = '$code $message $errStr';

  if (known.contains('network') ||
      known.contains('socket') ||
      known.contains('connection') ||
      known.contains('timeout') ||
      known.contains('failed host lookup') ||
      known.contains('xmlhttprequest') ||
      known.contains('clientexception') ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504) {
    return l10n.errorNetwork;
  }
  if (context == AuthErrorContext.otp &&
      (known.contains('expired') ||
          known.contains('invalid') ||
          known.contains('otp') ||
          known.contains('token'))) {
    return l10n.otpInvalidOrExpired;
  }
  if (known.contains('session') ||
      known.contains('expired token') ||
      code == 'unauthorized' ||
      statusCode == 401) {
    return l10n.errorAuthSession;
  }
  if (context == AuthErrorContext.registration &&
      (known.contains('already') || known.contains('registered'))) {
    return l10n.accountAlreadyExists;
  }
  if (known.contains('invalid') ||
      known.contains('credentials') ||
      known.contains('wrong') ||
      known.contains('not found') ||
      code == 'invalid_credentials' ||
      code == 'user_not_found') {
    return l10n.errorAuthInvalid;
  }
  return l10n.errorGeneric;
}

String localizedDataError(Object error, AppLocalizations l10n) {
  if (error is TimeoutException) return l10n.errorNetwork;
  if (error is ApiException) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return l10n.errorAuthSession;
    }
    return localizedAuthError(error, l10n);
  }
  return l10n.errorGeneric;
}
