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
  if (error is! ApiException) return l10n.errorGeneric;

  final code = error.code?.toLowerCase() ?? '';
  final message = error.message.toLowerCase();
  final known = '$code $message';

  if (known.contains('network') ||
      known.contains('socket') ||
      known.contains('connection') ||
      known.contains('timeout')) {
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
      error.statusCode == 401) {
    return l10n.errorAuthSession;
  }
  if (context == AuthErrorContext.registration &&
      (known.contains('already') || known.contains('registered'))) {
    return l10n.accountAlreadyExists;
  }
  if (known.contains('invalid') ||
      known.contains('credentials') ||
      known.contains('wrong') ||
      known.contains('not found')) {
    return l10n.errorAuthInvalid;
  }
  return l10n.errorGeneric;
}
