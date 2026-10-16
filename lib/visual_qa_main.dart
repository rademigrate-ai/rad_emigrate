import 'features/applications/presentation/pages/applications_page.dart';
import 'features/documents/presentation/pages/documents_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/otp_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/auth/presentation/pages/profile_completion_page.dart';
import 'core/widgets/not_found_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'app/dependencies.dart';
import 'core/constants/app_colors.dart';
import 'core/routing/app_shell.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/loading_state.dart';
import 'core/widgets/premium_visuals.dart';
import 'core/widgets/rad_loading.dart';
import 'core/widgets/rad_ai_bird.dart';
import 'features/admin/presentation/pages/admin_hub_page.dart';
import 'features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import 'features/applications/domain/entities/application_status.dart';
import 'features/applications/domain/entities/visa_application.dart';
import 'features/applications/domain/repositories/application_repository.dart';
import 'features/applications/presentation/providers/application_controller.dart';
import 'features/auth/domain/entities/user_session.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_controller.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/consultation/presentation/pages/consultation_page.dart';
import 'features/documents/domain/entities/document.dart';
import 'features/documents/domain/entities/document_type.dart';
import 'features/documents/domain/repositories/document_repository.dart';
import 'features/documents/presentation/providers/document_controller.dart';
import 'features/feed/data/feed_repository.dart';
import 'features/feed/presentation/pages/feed_page.dart';
import 'features/global_time/presentation/pages/world_clock_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'features/visa/domain/entities/visa_entities.dart';
import 'features/visa/presentation/pages/visa_page.dart';
import 'features/visa/presentation/providers/visa_catalog_provider.dart';
import 'l10n/app_localizations.dart';
import 'visual_qa_capture_signal_stub.dart'
    if (dart.library.js_interop) 'visual_qa_capture_signal_web.dart';

/// A separate, non-production entrypoint for repeatable visual QA.
///
/// It imports actual product screens, provides only synthetic non-customer
/// records, and is never referenced by the production main/router.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(VisualQaApp(preferences: preferences));
}

class VisualQaApp extends StatelessWidget {
  const VisualQaApp({
    super.key,
    required this.preferences,
    this.initialScreen,
    this.locale,
    this.themeMode,
    this.textScale = 1,
  });

  final SharedPreferences preferences;
  final String? initialScreen;
  final Locale? locale;
  final ThemeMode? themeMode;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final screen =
        initialScreen ?? Uri.base.queryParameters['screen'] ?? 'login';
    final requestedTheme = Uri.base.queryParameters['theme'];
    final requestedLocale = Uri.base.queryParameters['locale'];
    final fixtureFa = (locale?.languageCode ?? requestedLocale) == 'fa';
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => _visualAuthController(fa: fixtureFa),
        ),
        appBootstrapProvider.overrideWith((ref) {
          if (screen != 'splash') return Future<void>.value();
          final bootstrap = Completer<void>();
          ref.onDispose(bootstrap.complete);
          return bootstrap.future;
        }),
        sharedPreferencesProvider.overrideWithValue(preferences),
        applicationControllerProvider.overrideWith(
          (ref) => ApplicationController(
            _VisualApplications(fa: fixtureFa),
            'visual-qa',
          ),
        ),
        documentControllerProvider.overrideWith(
          (ref) =>
              DocumentController(_VisualDocuments(fa: fixtureFa), 'visual-qa'),
        ),
        feedProvider('en').overrideWith((ref) async => _visualFeed),
        visaCatalogProvider('en').overrideWith((ref) async => _visualCatalog),
        visaCatalogProvider('fa')
            .overrideWith((ref) async => _localizedVisualCatalog()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RAD Visual QA',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode:
            themeMode ??
            (requestedTheme == 'dark'
                ? ThemeMode.dark
                : requestedTheme == 'light'
                ? ThemeMode.light
                : ThemeMode.system),
        locale:
            locale ??
            (requestedLocale == 'fa'
                ? const Locale('fa')
                : requestedLocale == 'en'
                ? const Locale('en')
                : null),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: Uri.base.queryParameters['capture'] == '1',
            textScaler: TextScaler.linear(
              double.tryParse(Uri.base.queryParameters['scale'] ?? '') ??
                  textScale,
            ),
          ),
          child: Uri.base.queryParameters['capture'] == '1'
              ? _QaAssetReadiness(child: child!)
              : child!,
        ),
        home: _QaFrame(screen: screen),
      ),
    );
  }
}

/// QA-only readiness marker: never imported by the production entrypoint.
/// Decoding fixture photography and original branding before capture prevents
/// transient blank assets from being mistaken for accepted visual evidence.
class _QaAssetReadiness extends StatefulWidget {
  const _QaAssetReadiness({required this.child});
  final Widget child;
  @override
  State<_QaAssetReadiness> createState() => _QaAssetReadinessState();
}

class _QaAssetReadinessState extends State<_QaAssetReadiness> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _warmAssets();
  }

  Future<void> _warmAssets() async {
    // Required by the actual fixture pages; unrelated source/master artwork
    // must not evict visible assets from Flutter's bounded image cache.
    const assets = [
      'assets/branding/rad_flying_bird_128.png',
      'assets/branding/rad_flying_bird_512.png',
      'assets/branding/rad_official_logo_transparent.webp',
      'assets/images/destinations/ch.jpg',
      'assets/images/destinations/ca.jpg',
      'assets/images/destinations/de.jpg',
      'assets/images/destinations/jp.jpg',
      'assets/images/destinations/au.jpg',
      'assets/images/destinations/gb.jpg',
    ];
    var failed = false;
    await Future.wait(
      assets.map(
        (path) => precacheImage(
          AssetImage(path),
          context,
          onError: (error, _) {
            failed = true;
            debugPrint('Visual QA asset failed: $path: $error');
          },
        ),
      ),
    );
    if (!mounted || failed) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) markVisualQaAssetsReady();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _QaFrame extends StatelessWidget {
  const _QaFrame({required this.screen});

  final String screen;

  @override
  Widget build(BuildContext context) {
    final page = switch (screen) {
      'cases' => const ApplicationsPage(),
      'documents' => const DocumentsPage(),
      'notifications' => const NotificationsPage(),
      'register' => const RegisterPage(),
      'otp' => const OtpPage(identifier: 'visual.qa@example.test'),
      'forgot-password' => const ForgotPasswordPage(),
      'reset-password' => const ResetPasswordPage(),
      'profile-completion' => const ProfileCompletionPage(),
      'not-found' => const NotFoundPage(),
      'dashboard' => const DashboardPage(),
      'visa' => const VisaPage(),
      'ai' => const AiAssistantPage(visualQaDemo: true),
      'ai-empty' => const AiAssistantPage(),
      'feed' => const FeedPage(),
      'admin' => const AdminHubPage(),
      'profile' => const ProfilePage(),
      'consultation' => const ConsultationPage(),
      'world-time' => const WorldClockPage(),
      'bird-states' => const _BirdStatesQaPage(),
      'shell' => const _ShellQaApp(),
      'splash' => const SplashPage(),
      'loading' => const _LoadingMotionQaPage(),
      'loading-full' => const _FullLoadingQaPage(),
      'loading-section' => const _SectionLoadingQaPage(),
      'loading-section-dark' => const _SectionLoadingQaPage(dark: true),
      'loading-compact' => const _CompactLoadingQaPage(),
      _ => const LoginPage(),
    };
    if (Uri.base.queryParameters['dock'] == '1') {
      return _ShellQaApp(screen: screen);
    }
    return page;
  }
}

class _ShellQaApp extends StatefulWidget {
  const _ShellQaApp({this.screen = 'dashboard'});
  final String screen;

  @override
  State<_ShellQaApp> createState() => _ShellQaAppState();
}

class _ShellQaAppState extends State<_ShellQaApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: switch (widget.screen) {
      'visa' => '/visa',
      'ai' || 'ai-empty' => '/ai-assistant',
      'cases' => '/applications',
      'documents' => '/documents',
      'profile' => '/profile',
      'world-time' => '/world-clock',
      'feed' => '/feed',
      _ => '/dashboard',
    },
    routes: [
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          for (final path in [
            '/dashboard',
            '/visa',
            '/ai-assistant',
            '/applications',
            '/world-clock',
            '/feed',
            '/documents',
            '/profile',
          ])
            GoRoute(
              path: path,
              builder: (_, _) => switch (path) {
                '/visa' => const VisaPage(),
                '/ai-assistant' => AiAssistantPage(
                  visualQaDemo: widget.screen == 'ai',
                ),
                '/applications' => const ApplicationsPage(),
                '/documents' => const DocumentsPage(),
                '/profile' => const ProfilePage(),
                '/world-clock' => const WorldClockPage(),
                '/feed' => const FeedPage(),
                _ => const DashboardPage(),
              },
            ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      locale: Localizations.localeOf(context),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}

class _BirdStatesQaPage extends StatelessWidget {
  const _BirdStatesQaPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      appBar: AppBar(
        title: const Text('RAD Assistant states'),
        backgroundColor: const Color(0xFF070A0F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final state in RadAiBirdState.values)
                Container(
                  width: 210,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11161D),
                    border: Border.all(color: const Color(0xFF303743)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadAiBird(
                        state: state,
                        semanticLabel: 'Assistant ${state.name}',
                      ),
                      Text(
                        state.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingMotionQaPage extends StatelessWidget {
  const _LoadingMotionQaPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RAD loading motion')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF071D28),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: RadLoadingIndicator(
                    size: RadLoadingSize.fullScreen,
                    label: 'Preparing your RAD workspace',
                    message: 'Full-screen application initialization',
                    dark: true,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              const RadLoadingIndicator(
                size: RadLoadingSize.section,
                label: 'Loading case data',
                message: 'Section-level data loading',
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2430),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    RadInlineLoading(
                      label: 'Updating an application',
                      dark: true,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Compact pending-operation feedback',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullLoadingQaPage extends StatelessWidget {
  const _FullLoadingQaPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumCanvas(
        dark: true,
        accent: AppColors.teal,
        showEditorialRule: false,
        child: const SafeArea(
          child: LoadingState.fullScreen(
            message: 'Preparing your RAD workspace',
            semanticsLabel: 'Loading RAD workspace',
            dark: true,
          ),
        ),
      ),
    );
  }
}

class _SectionLoadingQaPage extends StatelessWidget {
  const _SectionLoadingQaPage({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final surface = dark ? const Color(0xFF071D28) : const Color(0xFFF4FBFC);
    final foreground = dark ? Colors.white : const Color(0xFF102B35);
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text('Section loading', style: TextStyle(color: foreground)),
        backgroundColor: surface,
        foregroundColor: foreground,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: LoadingState.section(
            message: 'Loading case information',
            semanticsLabel: 'Loading case information',
            dark: dark,
          ),
        ),
      ),
    );
  }
}

class _CompactLoadingQaPage extends StatelessWidget {
  const _CompactLoadingQaPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFC),
      appBar: AppBar(
        title: const Text('Compact loading'),
        backgroundColor: const Color(0xFFF4FBFC),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFB9D9DE)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    RadInlineLoading(label: 'Updating application'),
                    SizedBox(width: 14),
                    Expanded(child: Text('Updating your application')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2430),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    RadInlineLoading(
                      label: 'Updating application on dark surface',
                      dark: true,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Updating your application',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

AuthController _visualAuthController({bool fa = false}) {
  final controller = AuthController(_VisualAuthRepository());
  controller.applySession(
    UserSession(
      token: 'visual-qa-token',
      userId: 'visual-qa-user',
      fullName: fa ? 'مسافر آزمایشی' : 'Visual QA traveler',
      email: 'visual.qa@example.test',
      authenticated: true,
      profileComplete: true,
    ),
  );
  return controller;
}

class _VisualAuthRepository implements AuthRepository {
  @override
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async => const UserSession(
    token: 'visual-qa-token',
    authenticated: true,
    profileComplete: true,
  );
  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async => const UserSession(
    token: 'visual-qa-token',
    authenticated: true,
    profileComplete: true,
  );
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset({required String email}) async {}
  @override
  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  }) async => const UserSession(
    token: 'visual-qa-token',
    authenticated: true,
    profileComplete: false,
  );
  @override
  Future<void> resendOtp({
    required String identifier,
    bool signup = false,
  }) async {}
  @override
  Future<UserSession?> restoreSession() async => null;
  @override
  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
    bool signup = false,
  }) async => const UserSession(
    token: 'visual-qa-token',
    authenticated: true,
    profileComplete: true,
  );
}

class _VisualApplications implements ApplicationRepository {
  _VisualApplications({this.fa = false});
  final bool fa;
  static final _records = [
    VisaApplication(
      id: 'visual-app-1',
      title: 'Sample study pathway',
      programName: 'Visual QA example',
      country: 'Canada',
      status: ApplicationStatus.reviewing,
      updatedAt: DateTime.utc(2026, 10, 8),
      userId: 'visual-qa',
    ),
    VisaApplication(
      id: 'visual-app-2',
      title: 'Sample document review',
      programName: 'Visual QA example',
      country: 'Germany',
      status: ApplicationStatus.documentsRequired,
      updatedAt: DateTime.utc(2026, 10, 7),
      userId: 'visual-qa',
    ),
  ];

  @override
  Future<VisaApplication> createApplication(
    VisaApplication application,
  ) async => application;
  @override
  Future<VisaApplication?> getApplication(String id) async => null;
  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async => fa
      ? _records
            .map(
              (a) => a.copyWith(
                title: a.id == 'visual-app-1'
                    ? 'پرونده آزمایشی تحصیل'
                    : 'بررسی آزمایشی مدارک',
                programName: 'نمونه نمایشی',
              ),
            )
            .toList()
      : _records;
  @override
  Future<VisaApplication> updateApplication(
    VisaApplication application,
  ) async => application;
}

class _VisualDocuments implements DocumentRepository {
  _VisualDocuments({this.fa = false});
  final bool fa;
  static final _records = [
    Document(
      id: 'visual-doc-1',
      typeId: 'passport',
      name: 'Sample passport',
      kind: DocumentTypeKind.passport,
      status: DocumentVerificationStatus.missing,
      userId: 'visual-qa',
    ),
    Document(
      id: 'visual-doc-2',
      typeId: 'education',
      name: 'Sample academic record',
      kind: DocumentTypeKind.education,
      status: DocumentVerificationStatus.underReview,
      userId: 'visual-qa',
    ),
  ];

  @override
  Future<void> deleteDocument(Document document) async {}
  @override
  Future<Document?> getDocument(String id) async => null;
  @override
  Future<List<Document>> listDocuments({String? userId}) async => fa
      ? _records
            .map(
              (d) => d.copyWith(
                name: d.kind == DocumentTypeKind.passport
                    ? 'گذرنامه آزمایشی'
                    : 'مدرک تحصیلی آزمایشی',
              ),
            )
            .toList()
      : _records;
  @override
  Future<Document> uploadDocument({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async => document;
  @override
  Future<Document> upsertDocument(Document document) async => document;
}

const _visualFeed = [
  FeedEntry(
    id: 'visual-feed-1',
    slug: 'visual-checklist',
    category: 'Visual QA',
    title: 'Sample pathway checklist',
    summary: 'Synthetic review content used solely to verify the visual hierarchy of published-update cards.',
    saved: false,
    publishedAt: null,
  ),
  FeedEntry(
    id: 'visual-feed-2',
    slug: 'visual-source',
    category: 'Visual QA',
    title: 'Sample source review',
    summary: 'A controlled non-customer record for testing information grouping and scanability.',
    saved: true,
    publishedAt: null,
  ),
];

const _visualCountries = [
  Country(
    id: 'visual-ca',
    name: 'Canada',
    code: 'CA',
    flagEmoji: '🇨🇦',
    slug: 'canada',
    summary: 'Visual QA sample summary',
  ),
  Country(
    id: 'visual-de',
    name: 'Germany',
    code: 'DE',
    flagEmoji: '🇩🇪',
    slug: 'germany',
    summary: 'Visual QA sample summary',
  ),
  Country(
    id: 'visual-ae',
    name: 'United Arab Emirates',
    code: 'AE',
    flagEmoji: '🇦🇪',
    slug: 'united-arab-emirates',
    summary: 'Visual QA sample summary',
  ),
  Country(
    id: 'visual-jp',
    name: 'Japan',
    code: 'JP',
    flagEmoji: '🇯🇵',
    slug: 'japan',
    summary: 'Visual QA sample summary',
  ),
  Country(
    id: 'visual-au',
    name: 'Australia',
    code: 'AU',
    flagEmoji: '🇦🇺',
    slug: 'australia',
    summary: 'Visual QA sample summary',
  ),
];

final _visualCatalog = VisaCatalog(
  countries: _visualCountries,
  categories: [
    for (final entry in [
      'Study',
      'Work',
      'Investment',
      'Visit',
    ].asMap().entries)
      VisaCategory(
        id: 'visual-category-${entry.key + 1}',
        name: entry.value,
        description: 'Synthetic visual QA category only',
        slug: 'qa-${entry.key}',
      ),
  ],
  programs: [
    for (final country in _visualCountries)
      for (var category = 1; category <= 4; category++)
        VisaProgram(
          id: 'visual-program-${country.code.toLowerCase()}-$category',
          slug: 'sample-${country.slug}-pathway',
          title: 'Sample study pathway',
          countryId: country.id,
          categoryId: 'visual-category-$category',
          summary:
              'Synthetic non-customer catalogue content for visual QA only.',
          source: VisaSource(
            title: 'Visual QA source',
            url: 'https://example.test',
            publisher: 'RAD Visual QA',
            retrievedAt: DateTime.utc(2026, 10, 8),
          ),
        ),
  ],
);

VisaCatalog _localizedVisualCatalog() => VisaCatalog(
  countries: [
    for (final c in _visualCountries)
      Country(
        id: c.id,
        code: c.code,
        flagEmoji: c.flagEmoji,
        slug: c.slug,
        summary: 'نمونه نمایشی',
        name:
            {
              'CA': 'کانادا',
              'DE': 'آلمان',
              'AE': 'امارات',
              'JP': 'ژاپن',
              'AU': 'استرالیا',
            }[c.code] ??
            c.name,
      ),
  ],
  categories: [
    for (final c in _visualCatalog.categories)
      VisaCategory(
        id: c.id,
        name: {
          'visual-category-1': 'تحصیلی',
          'visual-category-2': 'کاری',
          'visual-category-3': 'سرمایه‌گذاری',
          'visual-category-4': 'گردشگری',
        }[c.id]!,
        description: 'نمونه نمایشی',
        slug: c.slug,
      ),
  ],
  programs: _visualCatalog.programs,
);
