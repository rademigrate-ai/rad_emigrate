import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/app_text_field.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/immigration_profile_validator.dart';
import 'package:rad_emigrate/features/profile/domain/pathway_assessment.dart';
import 'package:rad_emigrate/features/profile/domain/repositories/immigration_profile_repository.dart';
import 'package:rad_emigrate/features/profile/presentation/pages/immigration_profile_page.dart';
import 'package:rad_emigrate/features/profile/presentation/providers/immigration_profile_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImmigrationProfileRepo implements ImmigrationProfileRepository {
  _FakeImmigrationProfileRepo({ImmigrationProfile? initial})
    : profile = initial ?? const ImmigrationProfile();

  ImmigrationProfile profile;
  int saveCount = 0;

  @override
  Future<ImmigrationProfile?> getImmigrationProfile(String userId) async =>
      profile;

  @override
  Future<ImmigrationProfile> saveImmigrationProfile(
    String userId,
    ImmigrationProfile p,
  ) async {
    saveCount++;
    return profile = p;
  }

  @override
  ImmigrationProfileValidationResult validate(ImmigrationProfile p) {
    return ImmigrationProfileValidator.validate(p);
  }

  @override
  PathwayAssessmentResult assessPathway({
    required ImmigrationProfile profile,
    required String programId,
    required List<PathwayEligibilityRule> rules,
    DateTime? now,
  }) {
    return const PathwayAssessmentService().assess(
      profile: profile,
      programId: programId,
      rules: rules,
      now: now,
    );
  }

  @override
  Future<void> clearLocalDraft(String userId) async {
    profile = const ImmigrationProfile();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({
    required SharedPreferences prefs,
    required _FakeImmigrationProfileRepo repo,
    Locale locale = const Locale('en'),
    bool syntheticApprovedRule = false,
  }) {
    final auth = AuthController(_MockAuthRepo())
      ..applySession(
        const UserSession(
          userId: 'test-user-001',
          token: 'token-001',
          authenticated: true,
          fullName: 'Sahar Rezai',
        ),
      );

    final controller = ImmigrationProfileController(
      repo,
      'test-user-001',
      approvedRules: () => syntheticApprovedRule
          ? [
              PathwayEligibilityRule(
                id: 'synthetic-rule',
                programId: 'express-entry',
                jurisdiction: 'ZZ',
                requiredFields: const {
                  ImmigrationProfileField.fullName,
                  ImmigrationProfileField.education,
                  ImmigrationProfileField.languages,
                },
                evidence: PathwayRuleEvidence(
                  jurisdiction: 'ZZ',
                  title: 'SYNTHETIC eligibility rule',
                  sourceUrl: 'https://example.gov/synthetic',
                  retrievedAt: DateTime.utc(2026, 10, 21),
                  publisher: 'SYNTHETIC TEST ONLY',
                ),
              ),
            ]
          : [],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => auth),
        immigrationProfileRepositoryProvider.overrideWithValue(repo),
        immigrationProfileControllerProvider.overrideWith((ref) => controller),
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
        home: const ImmigrationProfilePage(),
      ),
    );
  }

  group('E8-01 Immigration Profile UI & Pathway Assessment Tests', () {
    testWidgets('renders completeness gauge, form fields, and disclaimers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeImmigrationProfileRepo();

      await tester.pumpWidget(buildTestWidget(prefs: prefs, repo: repo));
      await tester.pumpAndSettle();

      // Title & Completeness
      expect(find.text('Immigration Profile & Assessment'), findsOneWidget);
      expect(find.text('Profile Completeness'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      // Section cards
      expect(find.text('Applicant Immigration Profile'), findsOneWidget);
      expect(find.text('Evidence-Grounded Pathway Assessment'), findsOneWidget);

      // Form text fields
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.widgetWithText(AppTextField, 'Full Name'), findsOneWidget);
      expect(
        find.widgetWithText(AppTextField, 'Email Address'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppTextField, 'Phone Number'), findsOneWidget);

      // Transparency notice
      expect(find.textContaining('Transparency Notice:'), findsOneWidget);
      expect(find.text('Book consultation'), findsOneWidget);
    });

    testWidgets(
      'toggling unknown field marks unknown and updates completeness',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeImmigrationProfileRepo();

        await tester.pumpWidget(buildTestWidget(prefs: prefs, repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('0%'), findsOneWidget);

        // Tap first unknown checkbox (for Full Name)
        final checkboxes = find.byType(Checkbox);
        expect(checkboxes, findsWidgets);
        await tester.tap(checkboxes.first);
        await tester.pumpAndSettle();

        // Completeness percentage increases from 0% to 11% (1/9 fields complete)
        expect(find.text('11%'), findsOneWidget);
      },
    );

    testWidgets('save draft button invokes repository and shows snackbar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeImmigrationProfileRepo();

      await tester.pumpWidget(buildTestWidget(prefs: prefs, repo: repo));
      await tester.pumpAndSettle();

      // Enter full name
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'Sahar Rezai');
      await tester.pumpAndSettle();

      // Save draft via AppBar icon
      final saveBtn = find.byIcon(Icons.save_outlined);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.profile.fullName, 'Sahar Rezai');
      expect(find.text('Profile draft saved locally.'), findsOneWidget);
    });

    testWidgets(
      'pathway assessment evaluates rules without hallucinating eligibility',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        // Incomplete profile
        final repo = _FakeImmigrationProfileRepo(
          initial: const ImmigrationProfile(nationality: 'IR'),
        );

        await tester.pumpWidget(buildTestWidget(prefs: prefs, repo: repo));
        await tester.pumpAndSettle();

        // Tap Assess Eligibility
        final assessBtn = find.text('Assess Eligibility');
        await tester.ensureVisible(assessBtn);
        await tester.tap(assessBtn);
        await tester.pumpAndSettle();

        // Must show Insufficient Information because education/languages etc are missing
        expect(find.text('Insufficient Verified Evidence'), findsOneWidget);
        expect(
          find.textContaining('IRCC Express Entry Criteria'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'assessing complete profile against verified rule yields potentially eligible',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeImmigrationProfileRepo(
          initial: const ImmigrationProfile(
            fullName: 'Sahar Rezai',
            email: 'sahar@example.com',
            phone: '+14165550199',
            nationality: 'IR',
            education: 'Master of Science in Software Engineering',
            workExperience: '5 years senior software engineer',
            languages: ['English', 'Persian'],
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(
            prefs: prefs,
            repo: repo,
            syntheticApprovedRule: true,
          ),
        );
        await tester.pumpAndSettle();

        final assessBtn = find.text('Assess Eligibility');
        await tester.ensureVisible(assessBtn);
        await tester.tap(assessBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Potentially Eligible (Verified Rules)'),
          findsOneWidget,
        );
        expect(
          find.textContaining('SYNTHETIC eligibility rule'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders cleanly in Persian RTL across multiple viewports', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeImmigrationProfileRepo(
        initial: const ImmigrationProfile(
          fullName: 'سحر رضایی',
          email: 'sahar@example.com',
          phone: '+989121112233',
          nationality: 'ایران',
          education: 'کارشناسی ارشد کامپیوتر',
          workExperience: '۵ سال مهندسی نرم‌افزار',
          languages: ['فارسی', 'انگلیسی'],
        ),
      );

      for (final width in [390.0, 768.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 2600);
        tester.view.devicePixelRatio = 1;

        await tester.pumpWidget(
          buildTestWidget(prefs: prefs, repo: repo, locale: const Locale('fa')),
        );
        await tester.pumpAndSettle();

        expect(find.text('پرونده مهاجرتی و سنجش مسیر'), findsOneWidget);
        expect(find.text('تکمیل پرونده'), findsOneWidget);
        expect(find.text('اطلاعات متقاضی مهاجرت'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.reset();
    });

    testWidgets(
      'renders evidence-grounded recommendations and supports clearDraft',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeImmigrationProfileRepo(
          initial: const ImmigrationProfile(
            fullName: 'Sahar Rezai',
            email: 'sahar@example.com',
            phone: '+14165550199',
            nationality: 'IR',
            education: 'Master of Science in Software Engineering',
            workExperience: '5 years senior software engineer',
            languages: ['English', 'Persian'],
          ),
        );

        final auth = AuthController(_MockAuthRepo())
          ..applySession(
            const UserSession(
              userId: 'test-user-001',
              token: 'token-001',
              authenticated: true,
              fullName: 'Sahar Rezai',
            ),
          );

        final controller = ImmigrationProfileController(repo, 'test-user-001');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => auth),
              immigrationProfileRepositoryProvider.overrideWithValue(repo),
              immigrationProfileControllerProvider.overrideWith(
                (ref) => controller,
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ImmigrationProfilePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Evidence-Grounded Pathway Recommendations'),
          findsOneWidget,
        );

        await controller.clearDraft();
        await tester.pumpAndSettle();

        expect(repo.profile.fullName, isNull);
        expect(find.text('0%'), findsOneWidget);
      },
    );
  });
}
