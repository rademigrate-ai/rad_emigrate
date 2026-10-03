const Set<String> _publicRoutes = {'/splash', '/login', '/register', '/otp'};
const Set<String> _protectedRoutes = {
  '/dashboard',
  '/visa',
  '/applications',
  '/documents',
  '/profile',
  '/ai-assistant',
  '/profile-completion',
};

/// Resolves auth routing while distinguishing session restoration from logout.
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
