import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/theme_controller.dart';
import 'core/theme/app_theme.dart';
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
import 'features/documents/domain/entities/document.dart';
import 'features/documents/domain/entities/document_type.dart';
import 'features/documents/domain/repositories/document_repository.dart';
import 'features/documents/presentation/providers/document_controller.dart';
import 'features/feed/data/feed_repository.dart';
import 'features/feed/presentation/pages/feed_page.dart';
import 'features/visa/domain/entities/visa_entities.dart';
import 'features/visa/presentation/pages/visa_page.dart';
import 'features/visa/presentation/providers/visa_catalog_provider.dart';
import 'l10n/app_localizations.dart';

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
  const VisualQaApp({super.key, required this.preferences, this.initialScreen});

  final SharedPreferences preferences;
  final String? initialScreen;

  @override
  Widget build(BuildContext context) {
    final screen =
        initialScreen ?? Uri.base.queryParameters['screen'] ?? 'login';
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _visualAuthController()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        applicationControllerProvider.overrideWith(
          (ref) => ApplicationController(_VisualApplications(), 'visual-qa'),
        ),
        documentControllerProvider.overrideWith(
          (ref) => DocumentController(_VisualDocuments(), 'visual-qa'),
        ),
        feedProvider('en').overrideWith((ref) async => _visualFeed),
        visaCatalogProvider('en').overrideWith((ref) async => _visualCatalog),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RAD Visual QA',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _QaFrame(screen: screen),
      ),
    );
  }
}

class _QaFrame extends StatelessWidget {
  const _QaFrame({required this.screen});

  final String screen;

  @override
  Widget build(BuildContext context) {
    final page = switch (screen) {
      'dashboard' => const DashboardPage(),
      'visa' => const VisaPage(),
      'ai' => const AiAssistantPage(visualQaDemo: true),
      'feed' => const FeedPage(),
      'admin' => const AdminHubPage(),
      _ => const LoginPage(),
    };
    return Banner(
      message: 'SYNTHETIC VISUAL QA',
      location: BannerLocation.topStart,
      color: const Color(0xFF0B5260),
      child: page,
    );
  }
}

AuthController _visualAuthController() {
  final controller = AuthController(_VisualAuthRepository());
  controller.applySession(
    const UserSession(
      token: 'visual-qa-token',
      userId: 'visual-qa-user',
      fullName: 'Visual QA traveler',
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
  static final _records = [
    VisaApplication(
      id: 'visual-app-1',
      title: 'Sample study pathway',
      programName: 'Visual QA example',
      country: 'Sample destination',
      status: ApplicationStatus.reviewing,
      updatedAt: DateTime.utc(2026, 10, 8),
      userId: 'visual-qa',
    ),
    VisaApplication(
      id: 'visual-app-2',
      title: 'Sample document review',
      programName: 'Visual QA example',
      country: 'Sample destination',
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
  Future<List<VisaApplication>> listApplications({String? userId}) async =>
      _records;
  @override
  Future<VisaApplication> updateApplication(
    VisaApplication application,
  ) async => application;
}

class _VisualDocuments implements DocumentRepository {
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
  Future<List<Document>> listDocuments({String? userId}) async => _records;
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

final _visualCatalog = VisaCatalog(
  countries: const [
    Country(
      id: 'visual-country-1',
      name: 'Sample destination',
      code: 'SMP',
      flagEmoji: '◉',
      slug: 'sample-destination',
    ),
  ],
  categories: const [
    VisaCategory(
      id: 'visual-category-1',
      name: 'Sample pathway',
      description: 'Visual QA only',
      slug: 'sample-pathway',
    ),
  ],
  programs: [
    VisaProgram(
      id: 'visual-program-1',
      slug: 'sample-study-pathway',
      title: 'Sample study pathway',
      countryId: 'visual-country-1',
      categoryId: 'visual-category-1',
      summary: 'Synthetic non-customer catalogue content for visual QA only.',
      source: VisaSource(
        title: 'Visual QA source',
        url: 'https://example.test',
        publisher: 'RAD Visual QA',
        retrievedAt: DateTime.utc(2026, 10, 8),
      ),
    ),
    VisaProgram(
      id: 'visual-program-2',
      slug: 'sample-review-pathway',
      title: 'Sample review pathway',
      countryId: 'visual-country-1',
      categoryId: 'visual-category-1',
      summary: 'Synthetic non-customer catalogue content for visual QA only.',
      source: VisaSource(
        title: 'Visual QA source',
        url: 'https://example.test',
        publisher: 'RAD Visual QA',
        retrievedAt: DateTime.utc(2026, 10, 8),
      ),
    ),
  ],
);
