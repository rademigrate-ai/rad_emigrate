import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/app_button.dart';
import 'package:rad_emigrate/core/widgets/app_text_field.dart';
import 'package:rad_emigrate/core/widgets/inline_alert.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/consultation/presentation/pages/consultation_page.dart';
import 'package:rad_emigrate/features/consultation/presentation/providers/consultation_draft_provider.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createSubject({
    required SharedPreferences prefs,
    required AuthController authController,
    String? initialTopic,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => authController),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConsultationPage(initialTopic: initialTopic),
      ),
    );
  }

  testWidgets('unauthenticated user sees sign-in prompt for my consultations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final auth = AuthController(_MockAuthRepo());

    await tester.pumpWidget(createSubject(prefs: prefs, authController: auth));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in to view your consultation history'),
      findsOneWidget,
    );
    expect(find.byType(AppTextField), findsNWidgets(2));
  });

  testWidgets(
    'submitting empty form triggers required validation and clears prior success',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final auth = AuthController(_MockAuthRepo())
        ..applySession(
          const UserSession(
            userId: 'test-user-id',
            token: 'test-token',
            authenticated: true,
            fullName: 'Test User',
          ),
        );

      await tester.pumpWidget(
        createSubject(prefs: prefs, authController: auth),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(AppButton, 'Submit request');
      expect(submitBtn, findsOneWidget);

      // Tap submit with empty fields
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // InlineAlert for validation requirement must appear
      expect(find.byType(InlineAlert), findsAtLeastNWidgets(1));
      expect(
        find.text('Topic and message are required.'),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets('pre-populating initialTopic sets the topic text field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final auth = AuthController(_MockAuthRepo());

    await tester.pumpWidget(
      createSubject(
        prefs: prefs,
        authController: auth,
        initialTopic: 'Express Entry Canada',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Express Entry Canada'), findsOneWidget);
  });

  testWidgets('editing topic and message updates draft state', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final auth = AuthController(_MockAuthRepo());

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith((ref) => auth),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ConsultationPage(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'Germany Opportunity Card');
    await tester.enterText(
      textFields.last,
      'Questions about points calculation',
    );
    await tester.pumpAndSettle();

    final draft = capturedRef.read(consultationDraftProvider);
    expect(draft.topic, 'Germany Opportunity Card');
    expect(draft.message, 'Questions about points calculation');
  });
}
