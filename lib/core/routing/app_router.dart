import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependencies.dart';

import 'auth_redirect.dart';

import '../widgets/not_found_page.dart';
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
import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
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
      final bootstrap = ref.read(appBootstrapProvider);
      return authRedirect(
        uri: state.uri,
        isRestoring: bootstrap.isLoading,
        isAuthenticated: auth.valueOrNull?.isAuthenticated ?? false,
        profileComplete: auth.valueOrNull?.profileComplete ?? false,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, state) =>
            SplashPage(destination: state.uri.queryParameters['from']),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/otp',
        builder: (_, state) =>
            OtpPage(identifier: state.uri.queryParameters['identifier']),
      ),
      GoRoute(
        path: '/profile-completion',
        builder: (_, _) => const ProfileCompletionPage(),
      ),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/visa', builder: (_, _) => const VisaPage()),
          GoRoute(
            path: '/applications',
            builder: (_, _) => const ApplicationsPage(),
          ),
          GoRoute(path: '/documents', builder: (_, _) => const DocumentsPage()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(
            path: '/ai-assistant',
            builder: (_, _) => const AiAssistantPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, _) => const NotFoundPage(title: 'Page not found'),
  );
});
