const Set<String> _publicRoutes = {
  '/splash',
  '/login',
  '/register',
  '/otp',
  '/forgot-password',
  '/reset-password',
};
const Set<String> _protectedRoutes = {
  '/dashboard',
  '/visa',
  '/applications',
  '/documents',
  '/profile',
  '/ai-assistant',
  '/consultation',
  '/notifications',
  '/profile-completion',
  '/admin',
  '/admin/ai-config',
  '/admin/operations',
  '/admin/ai-research',
  '/admin/consultations',
  '/feed',
};

/// Resolves auth routing while distinguishing session restoration from logout.
///
/// Authorization for `/admin` remains server-side (RLS + role). Including
/// `/admin` here only preserves deep-link restoration after session restore;
/// it does not grant data access.
///
/// `/reset-password` stays public so Supabase recovery sessions can complete
/// without being redirected away by the authenticated-public-route rule.
String? authRedirect({
  required Uri uri,
  required bool isRestoring,
  required bool isAuthenticated,
  required bool profileComplete,
}) {
  final location = uri.path;

  if (isRestoring &&
      location != '/splash' &&
      !_publicRoutes.contains(location)) {
    return Uri(
      path: '/splash',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }

  if (location == '/splash') return null;

  // Recovery deep-link: keep user on set-password even if a session exists.
  if (location == '/reset-password') return null;

  if (!isAuthenticated && !_publicRoutes.contains(location)) {
    return '/login';
  }

  if (isAuthenticated && _publicRoutes.contains(location)) {
    return profileComplete ? '/dashboard' : '/profile-completion';
  }

  if (isAuthenticated &&
      !profileComplete &&
      location != '/profile-completion' &&
      location != '/profile') {
    return '/profile-completion';
  }

  return null;
}

/// Accepts only known in-app protected routes from a pending deep link.
String restoredProtectedDestination(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !_protectedRoutes.contains(uri.path)) {
    return '/dashboard';
  }
  return uri.toString();
}
