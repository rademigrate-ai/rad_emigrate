/// Authentication flow routes (login, registration, password recovery).
const Set<String> _authRoutes = {
  '/login',
  '/register',
  // BUG-002: /signup is a compatibility alias for /register.
  '/signup',
  '/otp',
  '/forgot-password',
  '/reset-password',
};

/// Public in-app explore routes accessible to anonymous guest visitors.
const Set<String> _publicInAppRoutes = {
  '/dashboard',
  '/explore',
  '/visa',
  '/visa/search',
  '/feed',
  '/world-clock',
  '/profile',
  '/profile/immigration',
  '/universities',
  '/ai-assistant',
  '/consultation',
  '/booking',
  '/interview-scheduling',
  '/interviews',
  '/calculator/cost',
  '/compare/pathways',
  '/compare/universities',
};

/// Personal or administrative routes that strictly require authentication.
const Set<String> _protectedRoutes = {
  '/applications',
  '/profile/cases',
  '/documents',
  '/documents/draft',
  '/notifications',
  '/profile-completion',
  '/admin',
  '/admin/ai-config',
  '/admin/operations',
  '/admin/ai-research',
  '/admin/consultations',
  '/admin/cms',
  '/admin/sources',
};

/// True if the given path requires authentication.
bool isProtectedPath(String location) {
  if (_protectedRoutes.contains(location)) return true;
  // Nested Admin paths require authentication.
  if (location.startsWith('/admin/')) return true;
  if (location.startsWith('/profile/cases/')) return true;
  if (location.startsWith('/applications/')) return true;
  return false;
}

/// True when the location is a route declared by the application.
///
/// Unknown locations must fall through to the router's NotFound page instead
/// of redirecting visitors to login (BUG-003).
bool _isKnownLocation(String location) =>
    location == '/splash' ||
    _authRoutes.contains(location) ||
    _publicInAppRoutes.contains(location) ||
    _isBookingService(location) ||
    location.startsWith('/visa/') ||
    location.startsWith('/feed/') ||
    isProtectedPath(location);

/// True when an OTP page visit carries a pending verification flow.
///
/// The verification form may only be presented when a real flow handed over
/// an email identifier (register or login-with-OTP). Bare /otp visits have no
/// context and must not show a code-entry form.
bool hasOtpFlowContext(Uri uri) {
  final identifier = uri.queryParameters['identifier'] ?? '';
  return identifier.contains('@');
}

/// Resolves auth routing distinguishing session restoration, guest mode,
/// and protected route enforcement.
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

  // Unknown routes are never redirected for auth; the router renders its
  // NotFound page for them (BUG-003).
  if (!_isKnownLocation(location)) return null;

  if (isRestoring &&
      location != '/splash' &&
      !_authRoutes.contains(location) &&
      isProtectedPath(location)) {
    return Uri(
      path: '/splash',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }

  if (location == '/splash') return null;

  // Recovery deep-link: keep user on set-password even if a session exists.
  if (location == '/reset-password') return null;

  // BUG-004: /otp without a pending verification flow goes back to login
  // instead of presenting a code-entry form with no context.
  if (location == '/otp' && !hasOtpFlowContext(uri)) {
    return '/login';
  }

  // Unauthenticated guests: only force login for known protected routes.
  // Explore-First routes (/dashboard, /visa, /feed, /profile, /ai-assistant,
  // /consultation, /world-clock) remain accessible to guests.
  if (!isAuthenticated && isProtectedPath(location)) {
    return Uri(
      path: '/login',
      queryParameters: {'from': restoredProtectedDestination(uri.toString())},
    ).toString();
  }

  // Authenticated users on auth routes are redirected to their target destination.
  if (isAuthenticated && _authRoutes.contains(location)) {
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

  // Authenticated users with incomplete profile on protected routes must finish setup.
  if (isAuthenticated &&
      !profileComplete &&
      isProtectedPath(location) &&
      location != '/profile-completion' &&
      location != '/profile') {
    return Uri(
      path: '/profile-completion',
      queryParameters: {'from': restoredProtectedDestination(uri.toString())},
    ).toString();
  }

  return null;
}

/// Accepts known in-app destinations (public or protected) from a pending flow.
/// External URLs and unknown paths fall back to the explore home (/dashboard).
String restoredProtectedDestination(String? value) {
  final original = value ?? '';
  final rawPath = original.split(RegExp(r'[?#]')).first;
  if (rawPath.split('/').any((segment) => segment == '.' || segment == '..')) {
    return '/dashboard';
  }
  final uri = Uri.tryParse(original);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.path.isEmpty ||
      !uri.path.startsWith('/') ||
      uri.path.contains(RegExp(r'[\\%\x00-\x20]')) ||
      uri.path.split('/').any((s) => s == '.' || s == '..') ||
      !_isKnownInAppDestination(uri.path)) {
    return '/dashboard';
  }
  return uri.toString();
}

bool _isKnownInAppDestination(String path) {
  if (path == '/splash') return false;
  if (_publicInAppRoutes.contains(path) || _isBookingService(path)) return true;
  if (isProtectedPath(path)) return true;
  return false;
}

bool _isBookingService(String path) =>
    RegExp(r'^/booking/service/[a-zA-Z0-9_-]+$').hasMatch(path);
