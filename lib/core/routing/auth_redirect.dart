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
  '/world-clock',
};

bool _isProtectedPath(String location) {
  if (_protectedRoutes.contains(location)) return true;
  // Nested admin paths under /admin/
  if (location.startsWith('/admin/')) return true;
  return false;
}

/// Resolves auth routing while distinguishing session restoration from logout.
///
/// Unknown paths are left unhandled so GoRouter [errorBuilder] can show
/// NotFound instead of incorrectly sending users to login.
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
      !_publicRoutes.contains(location) &&
      _isProtectedPath(location)) {
    return Uri(
      path: '/splash',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }

  if (location == '/splash') return null;

  // Recovery deep-link: keep user on set-password even if a session exists.
  if (location == '/reset-password') return null;

  // Unauthenticated users: only force login for known protected routes.
  // Unknown routes fall through to GoRouter errorBuilder (NotFound).
  if (!isAuthenticated && _isProtectedPath(location)) {
    return Uri(
      path: '/login',
      queryParameters: {'from': restoredProtectedDestination(uri.toString())},
    ).toString();
  }

  if (isAuthenticated && _publicRoutes.contains(location)) {
    final destination = restoredProtectedDestination(
      uri.queryParameters['from'],
    );
    return profileComplete
        ? destination
        : Uri(
            path: '/profile-completion',
            queryParameters: {'from': destination},
          ).toString();
  }

  if (isAuthenticated &&
      !profileComplete &&
      location != '/profile-completion' &&
      location != '/profile' &&
      _isProtectedPath(location)) {
    return Uri(
      path: '/profile-completion',
      queryParameters: {'from': restoredProtectedDestination(uri.toString())},
    ).toString();
  }

  return null;
}

/// Accepts only known in-app protected routes from a pending deep link.
String restoredProtectedDestination(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !_isProtectedPath(uri.path)) {
    return '/dashboard';
  }
  return uri.toString();
}
