import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_placeholder.dart';
import 'app_shell.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/profile_completion_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/visa/presentation/pages/visa_page.dart';
import '../../features/applications/presentation/pages/applications_page.dart';
import '../../features/documents/presentation/pages/documents_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

final authRefreshNotifierProvider = Provider<AuthRefreshNotifier>((ref) {
  return AuthRefreshNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: ref.watch(authRefreshNotifierProvider),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final authenticated = auth.valueOrNull?.isAuthenticated ?? false;
      final location = state.matchedLocation;
      const publicRoutes = {'/splash', '/login', '/register', '/otp'};

      if (location == '/splash') return null;
      if (!authenticated && !publicRoutes.contains(location)) return '/login';
      if (authenticated && publicRoutes.contains(location)) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/otp', builder: (_, state) => OtpPage(identifier: state.uri.queryParameters['identifier'])),
      GoRoute(path: '/profile-completion', builder: (_, __) => const ProfileCompletionPage()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/visa', builder: (_, __) => const VisaPage()),
          GoRoute(path: '/applications', builder: (_, __) => const ApplicationsPage()),
          GoRoute(path: '/documents', builder: (_, __) => const DocumentsPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ],
      ),
    ],
    errorBuilder: (_, __) => const AppPlaceholder(title: 'Page not found'),
  );
});
