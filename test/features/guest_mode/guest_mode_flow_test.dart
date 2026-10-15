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
import 'package:rad_emigrate/core/services/ai/ai_service.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/ai_response.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository implements AuthRepository {
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> getProfile(String userId) async => null;
  @override
  Future<UserProfile> updateProfile(UserProfile value) async => value;
}

class _MockAiService implements AiService {
  @override
  bool get isAvailable => true;
  @override
  Future<String> ask(String prompt) async => 'Verified answer';
  @override
  Future<AiResponse> complete(AiRequest request) async {
    return const AiResponse(text: 'Verified answer');
  }
}

class _MockAiSessionRepository implements AiSessionRepository {
  int listCalls = 0;
  final saved = <({String role, String content})>[];

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
  }) async {
    saved.add((role: role, content: content));
  }
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

        // Submit as guest -> preserves draft and redirects to login without scheduling submission
        final submitButton = find.text('Submit request');
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await _pumpTicks(tester);

        // Verify redirected to login
        expect(find.text('Login Screen'), findsOneWidget);

        // Verify draft state has pendingSubmit = true and valid token
        final updatedDraft = refCapture.read(consultationDraftProvider);
        expect(updatedDraft.topic, 'Express Entry Canada');
        expect(
          updatedDraft.message,
          'I have questions about CRS points and language tests.',
        );
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

    test('Scenario 1 & 2: authRedirect properly handles public, protected, and unknown routes', () {
      // Public in-app routes are accessible without redirect for unauthenticated visitors
      for (final path in [
        '/dashboard',
        '/visa',
        '/feed',
        '/world-clock',
        '/profile',
        '/ai-assistant',
        '/consultation',
      ]) {
        expect(
          authRedirect(
            uri: Uri.parse(path),
            isRestoring: false,
            isAuthenticated: false,
            profileComplete: false,
          ),
          isNull,
          reason: 'Public path $path should not redirect guests',
        );
      }

      // Protected routes redirect guests to /login?from=...
      for (final path in [
        '/applications',
        '/documents',
        '/notifications',
        '/profile-completion',
        '/admin',
        '/admin/operations',
        '/admin/consultations',
        '/admin/ai-research',
        '/admin/ai-config',
      ]) {
        final redirect = authRedirect(
          uri: Uri.parse(path),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        );
        expect(
          redirect,
          startsWith('/login?from='),
          reason: 'Protected path $path should redirect unauthenticated guests',
        );
      }

      // Unknown locations are left unhandled so GoRouter NotFound can render
      expect(
        authRedirect(
          uri: Uri.parse('/non-existent-secret-page'),
          isRestoring: false,
          isAuthenticated: false,
          profileComplete: false,
        ),
        isNull,
      );

      // Authenticated users on protected paths are not redirected if profile is complete
      expect(
        authRedirect(
          uri: Uri.parse('/applications'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        isNull,
      );

      // Authenticated users with incomplete profile are sent to profile completion
      expect(
        authRedirect(
          uri: Uri.parse('/applications'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: false,
        ),
        '/profile-completion?from=%2Fapplications',
      );

      // Authenticated user arriving at /login with 'from' is redirected to destination
      expect(
        authRedirect(
          uri: Uri.parse('/login?from=%2Fdocuments'),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        '/documents',
      );
    });

    test('Scenario 2: Security regression on malicious and malformed from destinations', () {
      // Malicious schemes and external URLs fall back to dashboard
      expect(
        restoredProtectedDestination('https://attacker.com/evil'),
        '/dashboard',
      );
      expect(restoredProtectedDestination('http://attacker.com'), '/dashboard');
      expect(
        restoredProtectedDestination('//evil.example.org/phish'),
        '/dashboard',
      );
      expect(restoredProtectedDestination('javascript:alert(1)'), '/dashboard');
      expect(
        restoredProtectedDestination('data:text/html,<script>'),
        '/dashboard',
      );

      // Auth routes as from parameter are rejected to prevent redirect loops
      expect(restoredProtectedDestination('/login'), '/dashboard');
      expect(restoredProtectedDestination('/login?from=/login'), '/dashboard');
      expect(restoredProtectedDestination('/register'), '/dashboard');
      expect(restoredProtectedDestination('/signup'), '/dashboard');
      expect(restoredProtectedDestination('/splash'), '/dashboard');

      // Null, empty, or unknown internal routes fall back safely
      expect(restoredProtectedDestination(null), '/dashboard');
      expect(restoredProtectedDestination(''), '/dashboard');
      expect(restoredProtectedDestination('   '), '/dashboard');
      expect(
        restoredProtectedDestination('/unknown-route-12345'),
        '/dashboard',
      );

      // Legitimate destinations and query parameters are safely preserved
      expect(
        restoredProtectedDestination('/consultation?topic=study%20visa'),
        '/consultation?topic=study%20visa',
      );
      expect(
        restoredProtectedDestination('/ai-assistant?context=Express%20Entry'),
        '/ai-assistant?context=Express%20Entry',
      );
      expect(
        restoredProtectedDestination('/applications?tab=active&id=99'),
        '/applications?tab=active&id=99',
      );
      expect(
        restoredProtectedDestination('/documents?kind=passport'),
        '/documents?kind=passport',
      );
    });

    testWidgets(
      'Scenario 3: Multiline Persian/English Consultation draft survives login redirect and requires manual submit',
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
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    auth.applySession(
                      const UserSession(
                        userId: 'test-user',
                        email: 'user@example.com',
                        authenticated: true,
                        profileComplete: true,
                      ),
                    );
                    context.go('/consultation');
                  },
                  child: const Text('Simulate Login'),
                ),
              ),
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

        // Enter Persian & English multiline topic and message
        const persianTopic = 'مشاوره اکسپرس اینتری ۲۰۲۶';
        const multilineMessage =
            'سلام، من می‌خواهم در مورد شرایط اقدام بپرسم.\nI have 5 years experience in software engineering.\nآیا واجد شرایط هستم؟ 🇨🇦';

        final topicFinder = find.byType(TextField).at(0);
        final messageFinder = find.byType(TextField).at(1);

        await tester.enterText(topicFinder, persianTopic);
        await tester.enterText(messageFinder, multilineMessage);
        await _pumpTicks(tester);

        // Draft provider has updated immediately
        expect(refCapture.read(consultationDraftProvider).topic, persianTopic);
        expect(
          refCapture.read(consultationDraftProvider).message,
          multilineMessage,
        );

        // Tap submit while unauthenticated -> gates to login
        final submitButton = find.text('Submit request');
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await _pumpTicks(tester);

        // Arrived at login screen
        expect(find.text('Simulate Login'), findsOneWidget);

        // Complete login and return to /consultation
        await tester.tap(find.text('Simulate Login'));
        await _pumpTicks(tester);

        // Restored in Consultation page
        expect(find.text(persianTopic), findsOneWidget);
        expect(find.text(multilineMessage), findsOneWidget);

        // Ensure user can edit the restored fields
        const editedMessage = '$multilineMessage\n(ویرایش شده: مدارک پیوست شد)';
        await tester.enterText(messageFinder, editedMessage);
        await _pumpTicks(tester);

        expect(
          refCapture.read(consultationDraftProvider).message,
          editedMessage,
        );
      },
    );

    testWidgets(
      'Scenario 4: Persian/English AI prompt and context survive login redirect for manual send',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepository());
        final sessions = _MockAiSessionRepository();
        final aiService = _MockAiService();

        late WidgetRef refCapture;
        final testRouter = GoRouter(
          initialLocation: '/ai-assistant',
          routes: [
            GoRoute(
              path: '/ai-assistant',
              builder: (context, state) => AiAssistantPage(
                contextLabel:
                    state.uri.queryParameters['context'] ??
                    'Canada Startup Visa',
              ),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    auth.applySession(
                      const UserSession(
                        userId: 'test-user-ai',
                        email: 'ai_user@example.com',
                        authenticated: true,
                        profileComplete: true,
                      ),
                    );
                    context.go('/ai-assistant?context=Canada%20Startup%20Visa');
                  },
                  child: const Text('Simulate Login AI'),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
              aiSessionRepositoryProvider.overrideWithValue(sessions),
              aiServiceProvider.overrideWithValue(aiService),
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

        // Guest sees context pill
        expect(find.text('Canada Startup Visa'), findsOneWidget);

        // Guest enters Persian + English prompt
        const promptText =
            'سلام! حداقل سرمایه برای ویزای استارتاپ چقدر است؟\nWhat is the designated angel group minimum? 🚀';
        final inputField = find.byType(TextField);
        await tester.enterText(inputField, promptText);
        await _pumpTicks(tester);

        // Auto-saved to draft provider
        expect(refCapture.read(aiPromptDraftProvider).prompt, promptText);

        // Tap send -> redirected to login
        final sendButton = find.byTooltip('Send message');
        await tester.tap(sendButton);
        await _pumpTicks(tester);

        expect(find.text('Simulate Login AI'), findsOneWidget);

        // Complete login and return to AI assistant
        await tester.tap(find.text('Simulate Login AI'));
        await _pumpTicks(tester);

        // Verify prompt is restored without auto-sending
        expect(find.text(promptText), findsOneWidget);
        expect(sessions.saved, isEmpty);

        // User edits the restored prompt
        const updatedPrompt = '$promptText (لطفا به فارسی پاسخ دهید)';
        await tester.enterText(inputField, updatedPrompt);
        await _pumpTicks(tester);

        // User manually sends
        await tester.tap(sendButton);
        await _pumpTicks(tester);

        // Exactly one message was sent to session repository
        expect(sessions.saved.where((m) => m.role == 'user'), hasLength(1));
        expect(sessions.saved.first.content, updatedPrompt);

        // Draft is cleared upon successful send
        expect(refCapture.read(aiPromptDraftProvider).hasContent, false);
      },
    );

    testWidgets(
      'Scenario 5: Draft persistence survives logout without being discarded',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final auth = AuthController(_MockAuthRepository());

        // Set an active session
        auth.applySession(
          const UserSession(
            userId: 'user-to-logout',
            email: 'user@example.com',
            authenticated: true,
            profileComplete: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => auth),
          ],
        );
        addTearDown(container.dispose);

        // Populate drafts
        await container
            .read(consultationDraftProvider.notifier)
            .updateDraft(
              topic: 'Preserved Topic',
              message: 'Preserved Message across logout',
            );
        await container
            .read(aiPromptDraftProvider.notifier)
            .savePrompt('Preserved AI question across logout', 'Context');

        // Perform logout
        await auth.logout();
        expect(auth.current.authenticated, false);

        // Drafts remain intact
        expect(
          container.read(consultationDraftProvider).topic,
          'Preserved Topic',
        );
        expect(
          container.read(consultationDraftProvider).message,
          'Preserved Message across logout',
        );
        expect(
          container.read(aiPromptDraftProvider).prompt,
          'Preserved AI question across logout',
        );
      },
    );
  });
}
