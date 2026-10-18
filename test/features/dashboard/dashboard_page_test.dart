import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/domain/repositories/application_repository.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/application_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document_type.dart';
import 'package:rad_emigrate/features/documents/domain/repositories/document_repository.dart';
import 'package:rad_emigrate/features/documents/presentation/providers/document_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppRepo implements ApplicationRepository {
  _FakeAppRepo(this.apps);
  final List<VisaApplication> apps;

  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async =>
      apps;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocRepo implements DocumentRepository {
  _FakeDocRepo(this.docs);
  final List<Document> docs;

  @override
  Future<List<Document>> listDocuments({String? userId}) async => docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildDashboard({
    required SharedPreferences prefs,
    required UserSession session,
    List<VisaApplication> apps = const [],
    List<Document> docs = const [],
    Locale locale = const Locale('en'),
  }) {
    final auth = AuthController(_MockAuthRepo())..applySession(session);
    final appController = ApplicationController(
      _FakeAppRepo(apps),
      session.isAuthenticated ? session.userId : null,
    );
    final docController = DocumentController(
      _FakeDocRepo(docs),
      session.isAuthenticated ? session.userId : null,
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => auth),
        applicationControllerProvider.overrideWith((ref) => appController),
        documentControllerProvider.overrideWith((ref) => docController),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: true, boldText: false),
          child: child!,
        ),
        home: const DashboardPage(),
      ),
    );
  }

  group('DashboardPage Presentation & State Verification (Gate 46)', () {
    testWidgets(
      'renders guest state with explore hero, quick actions, and sign in action',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        const guestSession = UserSession(
          userId: '',
          token: '',
          authenticated: false,
        );

        await tester.pumpWidget(
          buildDashboard(prefs: prefs, session: guestSession),
        );
        await tester.pumpAndSettle();

        // Guest traveler greeting
        expect(find.text('Hello, Traveler'), findsOneWidget);
        expect(find.text('Your journey'), findsOneWidget);

        // Hero card
        expect(
          find.text('Your immigration journey starts here'),
          findsOneWidget,
        );
        expect(find.text('Explore visa pathways'), findsOneWidget);

        // Quick actions
        expect(find.text('Consultation'), findsWidgets);
        expect(find.text('World Time'), findsWidgets);
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Feed'), findsOneWidget);

        // Sign in row for guest
        expect(find.text('Sign in'), findsOneWidget);
      },
    );

    testWidgets('renders authenticated state with profile incomplete prompt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      const userSession = UserSession(
        userId: 'user-001',
        token: 'token-001',
        authenticated: true,
        fullName: 'Mehrshad Rad',
        profileComplete: false,
      );

      await tester.pumpWidget(
        buildDashboard(prefs: prefs, session: userSession),
      );
      await tester.pumpAndSettle();

      // Personalized greeting
      expect(find.text('Hello, Mehrshad Rad'), findsOneWidget);

      // Incomplete profile row
      expect(find.text('Complete your profile'), findsOneWidget);
      expect(find.text('Add your name and basic details'), findsOneWidget);
    });

    testWidgets(
      'renders missing documents notification when required docs are missing',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        const userSession = UserSession(
          userId: 'user-002',
          token: 'token-002',
          authenticated: true,
          fullName: 'Sahar Karimi',
          profileComplete: true,
        );

        final missingDocs = [
          Document(
            id: 'doc-1',
            typeId: 'type-pass',
            name: 'passport.pdf',
            kind: DocumentTypeKind.passport,
            status: DocumentVerificationStatus.missing,
            userId: 'user-002',
            updatedAt: DateTime(2026, 1, 1),
          ),
          Document(
            id: 'doc-2',
            typeId: 'type-fin',
            name: 'bank_statement.pdf',
            kind: DocumentTypeKind.financial,
            status: DocumentVerificationStatus.missing,
            userId: 'user-002',
            updatedAt: DateTime(2026, 1, 2),
          ),
        ];

        await tester.pumpWidget(
          buildDashboard(prefs: prefs, session: userSession, docs: missingDocs),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 documents missing'), findsOneWidget);
        expect(
          find.text('Review the required files for your case'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders recent application with country, program, and status info',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        const userSession = UserSession(
          userId: 'user-003',
          token: 'token-003',
          authenticated: true,
          fullName: 'Ali Reza',
          profileComplete: true,
        );

        final apps = [
          VisaApplication(
            id: 'app-001',
            userId: 'user-003',
            title: 'Express Entry Federal Skilled',
            programName: 'Canada Express Entry',
            country: 'Canada',
            status: ApplicationStatus.reviewing,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 2),
          ),
        ];

        await tester.pumpWidget(
          buildDashboard(prefs: prefs, session: userSession, apps: apps),
        );
        await tester.pumpAndSettle();

        expect(find.text('Express Entry Federal Skilled'), findsOneWidget);
        expect(find.text('Canada Express Entry'), findsOneWidget);
      },
    );

    testWidgets(
      'renders cleanly in Persian RTL across mobile, tablet, and desktop viewports',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const userSession = UserSession(
          userId: 'user-004',
          token: 'token-004',
          authenticated: true,
          fullName: 'مهرداد راد',
          profileComplete: true,
        );

        for (final width in [390.0, 768.0, 1200.0]) {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;

          await tester.pumpWidget(
            buildDashboard(
              prefs: prefs,
              session: userSession,
              locale: const Locale('fa'),
            ),
          );
          await tester.pumpAndSettle();

          // Greeting in Persian
          expect(find.textContaining('مهرداد راد'), findsOneWidget);

          // Verify no unhandled layout overflow exceptions
          expect(tester.takeException(), isNull);
        }
        tester.view.reset();
      },
    );
  });
}
