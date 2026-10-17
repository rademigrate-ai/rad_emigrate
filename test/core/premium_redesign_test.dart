import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/premium_tokens.dart';
import 'package:rad_emigrate/core/theme/app_theme.dart';
import 'package:rad_emigrate/core/widgets/secondary_destinations.dart';
import 'package:rad_emigrate/features/admin/data/admin_operations_repository.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:rad_emigrate/visual_qa_main.dart';

double contrast(Color a, Color b) =>
    (math.max(a.computeLuminance(), b.computeLuminance()) + .05) /
    (math.min(a.computeLuminance(), b.computeLuminance()) + .05);

void main() {
  test('semantic text and status foregrounds are readable in both themes', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final rail = theme.navigationRailTheme;
      expect(
        contrast(rail.selectedLabelTextStyle!.color!, rail.backgroundColor!),
        greaterThanOrEqualTo(4.5),
        reason: 'Selected desktop labels must remain readable outside the icon indicator',
      );
    }
    for (final tokens in [PremiumTokens.light, PremiumTokens.dark]) {
      for (final foreground in [
        tokens.text,
        tokens.mutedText,
        tokens.error,
        tokens.warning,
        tokens.success,
        tokens.information,
      ]) {
        expect(contrast(foreground, tokens.surface), greaterThanOrEqualTo(4.5));
      }
      expect(
        contrast(tokens.disabledText, tokens.disabledSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(tokens.onAccent, tokens.accent),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('new Persian resources retain Persian characters and mirrored keys', () {
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final fa = jsonDecode(
      File('lib/l10n/app_fa.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final key in [
      'expandNavigation',
      'editProfile',
      'birdThinking',
      'continentMiddleEast',
      'immigrationJourney',
      'meetingMinutes',
    ]) {
      expect(en[key], isA<String>());
      expect(fa[key], matches(RegExp(r'[\u0600-\u06ff]')));
      expect(fa[key], isNot(contains('???')));
    }
  });

  testWidgets(
    'secondary destinations are visible and navigate without a long press',
    (tester) async {
      final priorReflection = GoRouter.optionURLReflectsImperativeAPIs;
      GoRouter.optionURLReflectsImperativeAPIs = true;
      addTearDown(
        () => GoRouter.optionURLReflectsImperativeAPIs = priorReflection,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: SecondaryDestinations()),
            ),
          ),
          for (final path in [
            '/world-clock',
            '/feed',
            '/documents',
            '/consultation',
            '/notifications',
          ])
            GoRoute(path: path, builder: (_, _) => Text(path)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminSnapshotProvider.overrideWith(
              (_) async => AdminSnapshot(
                role: 'user',
                applications: 0,
                documents: 0,
                researchJobs: 0,
                aiRequests: 0,
                documentJobs: 0,
                openTasks: 0,
                auditEvents: 0,
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Admin'), findsNothing);
      await tester.tap(find.text('World Time'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/world-clock');
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      for (final destination in [
        ('Feed', '/feed'),
        ('Documents', '/documents'),
        ('Request consultation', '/consultation'),
        ('Notifications', '/notifications'),
      ]) {
        router.go('/');
        await tester.pumpAndSettle();
        await tester.tap(find.text(destination.$1));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, destination.$2);
      }
    },
  );

  for (final locale in ['en', 'fa']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final screen in [
        'admin',
        'dashboard',
        'visa',
        'ai',
        'ai-empty',
        'splash',
        'cases',
        'documents',
        'profile',
        'world-time',
        'login',
        'register',
        'otp',
        'forgot-password',
        'reset-password',
        'profile-completion',
        'consultation',
        'notifications',
        'not-found',
      ]) {
        testWidgets('$screen $locale ${mode.name} at 320px and 200% text', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 844);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            VisualQaApp(
              preferences: preferences,
              initialScreen: screen,
              locale: Locale(locale),
              themeMode: mode,
              textScale: 2,
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
