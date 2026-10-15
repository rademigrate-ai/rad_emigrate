import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/ai_assistant/data/ai_session_repository.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/providers/ai_prompt_draft_provider.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/consultation/presentation/pages/consultation_page.dart';
import 'package:rad_emigrate/features/consultation/presentation/providers/consultation_draft_provider.dart';
import 'package:rad_emigrate/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:rad_emigrate/features/feed/data/feed_repository.dart';
import 'package:rad_emigrate/features/feed/presentation/pages/feed_page.dart';
import 'package:rad_emigrate/features/profile/domain/entities/user_profile.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/profile_repository.dart';
import 'package:rad_emigrate/features/profile/presentation/pages/profile_page.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/profile_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> getProfile(String userId) async => null;
  @override
  Future<UserProfile> updateProfile(UserProfile value) async => value;
}

class _MockAiSessionRepository implements AiSessionRepository {
  int listCalls = 0;
  @override
  Future<List<AiSession>> listSessions(
    String userId, {
    String scope = 'user',
  }) async {
    listCalls++;
    return [];
  }

  @override
  Future<AiSession> createSession(
    String userId, {
    String scope = 'user',
  }) async {
    return AiSession(
      id: 'session-1',
      userId: userId,
      questionCount: 0,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<AiSessionMessage>> history(String sessionId) async => [];

  @override
  Future<void> saveMessage({
    required String sessionId,
    required String userId,
    required String role,
    required String content,
  }) async {}
}

Future<void> _pumpTicks(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Guest Mode & Progressive Auth Flow Tests', () {
    testWidgets(
      'Guest Profile renders polished guest state with login & register',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepository());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
              profileRepositoryProvider.overrideWithValue(
                _MockProfileRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ProfilePage(),
            ),
          ),
        );
        await _pumpTicks(tester);

        // Guest banner & info
        expect(find.text('Guest Visitor'), findsOneWidget);
        expect(
          find.text(
            'Sign in to access your personal roadmap, track cases, manage documents, and chat with AI.',
          ),
          findsOneWidget,
        );

        // Login & Register actions
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('Create an account'), findsOneWidget);

        // Feature preview cards
        expect(find.text('Explore with an account'), findsOneWidget);
        expect(find.text('Track Applications'), findsOneWidget);
        expect(find.text('Document Vault'), findsOneWidget);
        expect(find.text('AI Immigration Assistant'), findsOneWidget);
        expect(find.text('Specialist Consultation'), findsOneWidget);

        // Theme & Language switchers are present
        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);

        // Edit profile & Logout buttons must NOT be present
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.logout_rounded), findsNothing);
        expect(find.text('Sign out'), findsNothing);
      },
    );

    testWidgets(
      'Guest consultation form preserves draft and requires manual submit after login',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepository());

        late WidgetRef refCapture;

        final testRouter = GoRouter(
          initialLocation: '/consultation',
          routes: [
            GoRoute(
              path: '/consultation',
              builder: (context, state) => const ConsultationPage(),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) =>
                  const Scaffold(body: Text('Login Screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                refCapture = ref;
                return MaterialApp.router(
                  routerConfig: testRouter,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                );
              },
            ),
          ),
        );
        await _pumpTicks(tester);

        // Verify form is visible to guests
        expect(find.text('Submit request'), findsOneWidget);
        expect(
          find.text('Sign in to view your consultation history'),
          findsOneWidget,
        );

        // Enter topic and message
        final topicFinder = find.byType(TextField).at(0);
        final messageFinder = find.byType(TextField).at(1);

        await tester.enterText(topicFinder, 'Express Entry Canada');
        await tester.enterText(
          messageFinder,
          'I have questions about CRS points and language tests.',
        );
        await _pumpTicks(tester);

        // Check draft was preserved in provider
        final draft = refCapture.read(consultationDraftProvider);
        expect(draft.topic, 'Express Entry Canada');
        expect(
          draft.message,
          'I have questions about CRS points and language tests.',
        );
        expect(draft.pendingSubmit, false);

        // Submit as guest -> preserves draft and redirects to login without scheduling submission
        final submitButton = find.text('Submit request');
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await _pumpTicks(tester);

        // Verify redirected to login
        expect(find.text('Login Screen'), findsOneWidget);

        // Verify draft state has pendingSubmit = true and valid token
        final updatedDraft = refCapture.read(consultationDraftProvider);
        expect(updatedDraft.pendingSubmit, false);
        expect(updatedDraft.submissionToken, isNull);
        expect(updatedDraft.topic, 'Express Entry Canada');
        expect(updatedDraft.message, 'I have questions about CRS points and language tests.');
      },
    );

    testWidgets(
      'Guest AI Assistant allows browsing, context pills, and gates submit with prompt preservation',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepository());
        final sessions = _MockAiSessionRepository();

        late WidgetRef refCapture;

        final testRouter = GoRouter(
          initialLocation: '/ai-assistant',
          routes: [
            GoRoute(
              path: '/ai-assistant',
              builder: (context, state) =>
                  const AiAssistantPage(contextLabel: 'Canada Study Permit'),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) =>
                  const Scaffold(body: Text('Login Screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
              aiSessionRepositoryProvider.overrideWithValue(sessions),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                refCapture = ref;
                return MaterialApp.router(
                  routerConfig: testRouter,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                );
              },
            ),
          ),
        );
        await _pumpTicks(tester);

        // Sessions history must NOT be loaded for guest
        expect(sessions.listCalls, 0);

        // Context pill is visible
        expect(find.text('Canada Study Permit'), findsOneWidget);

        // Enter prompt
        final inputField = find.byType(TextField);
        expect(inputField, findsOneWidget);
        await tester.enterText(
          inputField,
          'What are the language requirements for a study permit?',
        );
        await _pumpTicks(tester);

        // Tap send button
        final sendButton = find.byTooltip('Send message');
        expect(sendButton, findsOneWidget);
        await tester.tap(sendButton);
        await _pumpTicks(tester);

        // Check draft prompt was saved with context
        final draft = refCapture.read(aiPromptDraftProvider);
        expect(
          draft.prompt,
          'What are the language requirements for a study permit?',
        );
        expect(draft.contextLabel, 'Canada Study Permit');

        // Redirected to login
        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'Feed bookmark button gates unauthenticated visitors to login',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepository());

        final testRouter = GoRouter(
          initialLocation: '/feed',
          routes: [
            GoRoute(
              path: '/feed',
              builder: (context, state) => const FeedPage(),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) =>
                  const Scaffold(body: Text('Login Screen')),
            ),
          ],
        );

        final sampleFeed = [
          FeedEntry(
            id: 'feed-1',
            slug: 'draw-1',
            category: 'canada',
            title: 'New Canadian Express Entry Draw',
            summary: 'Category-based selection draw details released.',
            saved: false,
            publishedAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
              feedProvider('en').overrideWith((ref) => sampleFeed),
            ],
            child: MaterialApp.router(
              routerConfig: testRouter,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await _pumpTicks(tester);

        expect(find.text('New Canadian Express Entry Draw'), findsOneWidget);

        // Tap bookmark icon
        final bookmarkButton = find.byIcon(Icons.bookmark_border);
        expect(bookmarkButton, findsOneWidget);
        await tester.tap(bookmarkButton);
        await _pumpTicks(tester);

        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets('Dashboard hero Sign In button navigates to login for guests', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final auth = AuthController(_MockAuthRepository());

      final testRouter = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Text('Login Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => auth),
            appBootstrapProvider.overrideWith((ref) async {}),
            feedProvider('en').overrideWith((ref) => const []),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await _pumpTicks(tester);

      // In guest mode, hero shows "Sign in"
      final signInHero = find.text('Sign in');
      expect(signInHero, findsOneWidget);

      await tester.tap(signInHero);
      await _pumpTicks(tester);

      expect(find.text('Login Screen'), findsOneWidget);
    });

    test('Destination preservation and sanitize checks', () {
      // In-app destinations are preserved
      expect(restoredProtectedDestination('/consultation'), '/consultation');
      expect(
        restoredProtectedDestination('/ai-assistant?prompt=test'),
        '/ai-assistant?prompt=test',
      );
      expect(restoredProtectedDestination('/profile'), '/profile');
      expect(restoredProtectedDestination('/applications'), '/applications');
      expect(
        restoredProtectedDestination('/documents?kind=cv'),
        '/documents?kind=cv',
      );

      // External or malicious destinations fall back to dashboard
      expect(
        restoredProtectedDestination('https://attacker.com'),
        '/dashboard',
      );
      expect(restoredProtectedDestination('javascript:alert(1)'), '/dashboard');
      expect(restoredProtectedDestination('//evil.example.org'), '/dashboard');
      expect(restoredProtectedDestination('/splash'), '/dashboard');
      expect(restoredProtectedDestination(null), '/dashboard');
      expect(restoredProtectedDestination(''), '/dashboard');
      expect(restoredProtectedDestination('/invalid-fake-route'), '/dashboard');
    });
  });
}
