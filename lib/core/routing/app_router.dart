import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_placeholder.dart';
import 'app_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/visa/presentation/pages/visa_page.dart';
import '../../features/applications/presentation/pages/applications_page.dart';
import '../../features/documents/presentation/pages/documents_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
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
