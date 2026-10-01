import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_placeholder.dart';
import 'app_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/visa/presentation/pages/visa_page.dart';
import '../../features/applications/presentation/pages/applications_page.dart';
import '../../features/documents/presentation/pages/documents_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

final ValueNotifier<bool> sessionNotifier = ValueNotifier<bool>(false);

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: sessionNotifier,
  redirect: (_, state) {
    final loggedIn = sessionNotifier.value;
    final publicRoutes = ['/splash', '/login', '/register', '/otp'];
    if (!loggedIn && !publicRoutes.contains(state.matchedLocation)) {
      return '/login';
    }
    if (loggedIn && publicRoutes.contains(state.matchedLocation)) {
      return '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(path: '/otp', builder: (_, __) => const OtpPage()),
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
