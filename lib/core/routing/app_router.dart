import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependencies.dart';
import '../../features/admin/presentation/pages/admin_ai_config_page.dart';
import '../../features/admin/presentation/pages/admin_ai_workspace_page.dart';
import '../../features/admin/presentation/pages/admin_hub_page.dart';
import '../../features/admin/presentation/pages/admin_operations_page.dart';
import '../../features/admin/presentation/pages/admin_consultations_page.dart';
import '../../features/admin/presentation/pages/admin_cms_articles_page.dart';
import '../../features/admin/presentation/pages/admin_cms_canonical_editor_page.dart';
import '../../features/admin/presentation/pages/admin_source_monitor_page.dart';
import '../../features/admin/presentation/pages/admin_source_diff_page.dart';
import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../features/applications/presentation/pages/applications_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/profile_completion_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/documents/presentation/pages/documents_page.dart';
import '../../features/documents/presentation/pages/document_draft_page.dart';
import '../../features/consultation/presentation/pages/consultation_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/feed/presentation/pages/feed_page.dart';
import '../../features/global_time/presentation/pages/world_clock_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/immigration_profile_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/visa/presentation/visa_routes.dart';
import '../../features/visa/presentation/pages/university_scholarship_page.dart';
import '../../features/visa/presentation/pages/visa_page.dart';
import '../../features/booking/presentation/pages/booking_page.dart';
import '../../features/interviews/presentation/pages/interviews_page.dart';
import '../../features/booking/presentation/pages/booking_service_page.dart';
import '../../features/cost_calculator/presentation/pages/cost_calculator_page.dart';
import '../../features/pathway_comparison/presentation/pages/pathway_comparison_page.dart';
import '../../features/university_comparison/presentation/pages/university_comparison_page.dart';
import '../widgets/not_found_page.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(authenticatedUserIdProvider, (_, _) => notifyListeners());
  }
}

final authRefreshNotifierProvider = Provider<AuthRefreshNotifier>(
  (ref) => AuthRefreshNotifier(ref),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  // Every pushed secondary destination is also a declared, deep-linkable route.
  // Retain its source page for Back without leaving the browser URL on that page.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: ref.watch(authRefreshNotifierProvider),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final identity = ref.read(authenticatedUserIdProvider);
      final bootstrap = ref.read(appBootstrapProvider);
      return authRedirect(
        uri: state.uri,
        isRestoring: bootstrap.isLoading,
        isAuthenticated:
            identity != null &&
            identity.isNotEmpty &&
            (auth.valueOrNull?.isAuthenticated ?? false) &&
            identity == auth.valueOrNull?.userId,
        profileComplete: auth.valueOrNull?.profileComplete ?? false,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, state) =>
            SplashPage(destination: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            LoginPage(destination: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (_, state) =>
            RegisterPage(destination: state.uri.queryParameters['from']),
      ),
      // BUG-002: /signup is a compatibility alias for /register.
      GoRoute(
        path: '/signup',
        builder: (_, state) =>
            RegisterPage(destination: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpPage(
          identifier: state.uri.queryParameters['identifier'],
          signup: state.uri.queryParameters['mode'] == 'signup',
          destination: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/profile-completion',
        builder: (_, state) => ProfileCompletionPage(
          destination: state.uri.queryParameters['from'],
        ),
      ),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          visaRoute(),
          // BUG-L01: /explore is a compatibility alias for the Visa explorer.
          // Nav labels use "Explore" while the canonical path remains /visa.
          GoRoute(path: '/explore', builder: (_, _) => const VisaPage()),
          GoRoute(
            path: '/applications',
            builder: (_, _) => const ApplicationsPage(),
          ),
          GoRoute(
            path: '/profile/cases',
            builder: (_, _) => const ApplicationsPage(),
          ),
          GoRoute(
            path: '/profile/cases/:applicationId',
            builder: (_, state) => ApplicationsPage(
              initialApplicationId: state.pathParameters['applicationId'],
            ),
          ),
          GoRoute(path: '/documents', builder: (_, _) => const DocumentsPage()),
          GoRoute(
            path: '/documents/draft',
            builder: (_, _) => const DocumentDraftPage(),
          ),
          GoRoute(
            path: '/consultation',
            builder: (context, state) => ConsultationPage(
              initialTopic: state.uri.queryParameters['topic'],
            ),
          ),
          GoRoute(path: '/booking', builder: (_, _) => const BookingPage()),
          GoRoute(
            path: '/booking/service/:serviceId',
            builder: (_, state) => BookingServicePage(
              serviceId: state.pathParameters['serviceId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/interview-scheduling',
            builder: (_, _) => const InterviewsPage(),
          ),
          GoRoute(
            path: '/interviews',
            builder: (_, _) => const InterviewsPage(),
          ),
          GoRoute(
            path: '/calculator/cost',
            builder: (_, _) => const CostCalculatorPage(),
          ),
          GoRoute(
            path: '/compare/pathways',
            builder: (_, _) => const PathwayComparisonPage(),
          ),
          GoRoute(
            path: '/compare/universities',
            builder: (_, _) => const UniversityComparisonPage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(
            path: '/profile/immigration',
            builder: (_, _) => const ImmigrationProfilePage(),
          ),
          GoRoute(
            path: '/universities',
            builder: (_, _) => const UniversityScholarshipPage(),
          ),
          GoRoute(
            path: '/ai-assistant',
            builder: (_, state) => AiAssistantPage(
              contextLabel: state.uri.queryParameters['context'],
            ),
          ),
          GoRoute(
            path: '/world-clock',
            builder: (_, _) => const WorldClockPage(),
          ),
          GoRoute(path: '/admin', builder: (_, _) => const AdminHubPage()),
          GoRoute(
            path: '/admin/ai-config',
            builder: (_, _) => const AdminAiConfigPage(),
          ),
          GoRoute(
            path: '/admin/operations',
            builder: (_, _) => const AdminOperationsPage(),
          ),
          GoRoute(
            path: '/admin/consultations',
            builder: (_, _) => const AdminConsultationsPage(),
          ),
          GoRoute(
            path: '/admin/ai-research',
            builder: (_, _) => const AdminAiWorkspacePage(),
          ),
          GoRoute(
            path: '/admin/cms',
            builder: (_, _) => const AdminCmsArticlesPage(),
          ),
          GoRoute(
            path: '/admin/cms/canonical/:id',
            builder: (_, state) => AdminCmsCanonicalEditorPage(
              articleId: state.pathParameters['id'] ?? '',
              locale: state.uri.queryParameters['locale'] == 'en' ? 'en' : 'fa',
            ),
          ),
          GoRoute(
            path: '/admin/sources',
            builder: (_, _) => const AdminSourceMonitorPage(),
          ),
          GoRoute(
            path: '/admin/sources/:sourceId/review',
            builder: (_, state) => AdminSourceDiffPage(
              sourceId: state.pathParameters['sourceId'] ?? '',
            ),
          ),
          GoRoute(path: '/feed', builder: (_, _) => const FeedPage()),
        ],
      ),
    ],
    errorBuilder: (_, _) => const NotFoundPage(),
  );
});
