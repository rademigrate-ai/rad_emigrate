import '../network/api_exception.dart';

/// Builds the exact Flutter Web route used after a Supabase recovery callback.
///
/// Uses the exact hash callback currently allowlisted in Supabase Auth.
/// The Web bootstrap normalizes this legacy hash route to the canonical
/// path-based `/reset-password` *before* Supabase Flutter initializes, keeping
/// PKCE query parameters intact for `detectSessionInUri: true`.
/// Never switch the whole app to hash routing: other deep links use paths.
///
/// `/reset-password` remains a public route in [authRedirect] so an active
/// recovery session is never bounced to the dashboard.
String? passwordRecoveryRedirectTo(Uri currentUri) {
  if (!currentUri.hasScheme || currentUri.host.isEmpty) return null;
  final origin = currentUri.origin;
  if (origin.isEmpty || origin == 'null') return null;
  return '$origin/#/reset-password';
}

/// Identifies the safe, retryable error returned when Auth mail is throttled.
bool isPasswordRecoveryRateLimited(Object error) {
  if (error is ApiException && error.statusCode == 429) return true;

  final details = error is ApiException
      ? '${error.code ?? ''} ${error.message}'.toLowerCase()
      : error.toString().toLowerCase();
  return details.contains('over_email_send_rate_limit') ||
      details.contains('rate limit') ||
      details.contains('too many requests');
}

/// Identifies errors that mean a reset page has no usable recovery session.
bool isPasswordRecoverySessionError(Object error) {
  if (error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 403)) {
    return true;
  }

  final details = error is ApiException
      ? '${error.code ?? ''} ${error.message}'.toLowerCase()
      : error.toString().toLowerCase();
  return details.contains('recovery') ||
      details.contains('expired') ||
      details.contains('invalid token') ||
      details.contains('session missing');
}
