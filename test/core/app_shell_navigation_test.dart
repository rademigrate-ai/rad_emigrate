import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/core/routing/app_shell.dart';
import 'package:rad_emigrate/core/widgets/rad_ai_bird_nav_icon.dart';
import 'package:rad_emigrate/features/admin/data/admin_operations_repository.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

AdminSnapshot _snapshot(String role) => AdminSnapshot(
  role: role,
  applications: 0,
  documents: 0,
  researchJobs: 0,
  aiRequests: 0,
  documentJobs: 0,
  openTasks: 0,
  auditEvents: 0,
);

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  required String role,
  double width = 390,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/dashboard',
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
            '/admin',
          ])
            GoRoute(
              path: path,
              builder: (_, _) =>
                  Scaffold(body: Center(child: Text('$path body'))),
            ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminSnapshotProvider.overrideWith((ref) async => _snapshot(role)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

void main() {
  testWidgets('mobile primary destinations and bird route are available', (
    tester,
  ) async {
    final router = await _pumpShell(tester, role: 'user', width: 360);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.byType(RadAiBirdNavIcon));
    await tester.pump(const Duration(milliseconds: 400));

    expect(router.routeInformationProvider.value.uri.path, '/ai-assistant');
    expect(tester.takeException(), isNull);
  });

  testWidgets('bird long-press opens secondary destinations and admin', (
    tester,
  ) async {
    await _pumpShell(tester, role: 'admin', width: 360);

    await tester.longPress(find.byType(RadAiBirdNavIcon));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Cases'), findsOneWidget);
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('AI Assistant'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Profile'),
      ),
      findsNothing,
    );
    expect(find.text('Admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-admin overflow does not claim admin access', (tester) async {
    await _pumpShell(tester, role: 'user');

    await tester.longPress(find.byType(RadAiBirdNavIcon));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Admin'), findsNothing);
    expect(find.text('Docs'), findsOneWidget);
  });

  testWidgets('bird exposes localized tap and More semantics', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await _pumpShell(tester, role: 'user');

    final birdFinder = find.byType(RadAiBirdNavIcon);
    final data = tester.getSemantics(birdFinder).getSemanticsData();
    final customActions = tester
        .widgetList<Semantics>(
          find.descendant(of: birdFinder, matching: find.byType(Semantics)),
        )
        .map((semantics) => semantics.properties.customSemanticsActions)
        .firstWhere((actions) => actions != null);
    expect(data.label, 'AI Assistant');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(customActions, isNotNull);
    expect(customActions!.keys.map((action) => action.label), contains('More'));
    semanticsHandle.dispose();
  });

  testWidgets('wide layout retains the navigation rail', (tester) async {
    await _pumpShell(tester, role: 'user', width: 1000);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(RadAiBirdNavIcon), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('desktop rail can collapse without changing the route', (
    tester,
  ) async {
    final router = await _pumpShell(tester, role: 'user', width: 1200);

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    await tester.tap(find.byTooltip('Collapse navigation'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    expect(tester.takeException(), isNull);
  });

  for (final localeCode in ['en', 'fa']) {
    testWidgets(
      'mobile bottom navigation labels share identical vertical baselines ($localeCode)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);

        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            ShellRoute(
              builder: (_, _, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (_, _) => const Scaffold(),
                ),
                GoRoute(
                  path: '/ai-assistant',
                  builder: (_, _) => const Scaffold(),
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminSnapshotProvider.overrideWith(
                (ref) async => _snapshot('user'),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: Locale(localeCode),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final navTexts = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AppShell),
            matching: find.byType(Text),
          ),
        );
        final labelRects = <String, Rect>{};
        for (final text in navTexts) {
          final data = text.data ?? '';
          if (data.isEmpty) continue;
          final finder = find.text(data);
          if (finder.evaluate().isNotEmpty) {
            final rect = tester.getRect(finder.first);
            if (rect.top > 700) {
              labelRects[data] = rect;
            }
          }
        }

        expect(labelRects.length, 5);
        final firstBottom = labelRects.values.first.bottom;
        final firstTop = labelRects.values.first.top;
        for (final entry in labelRects.entries) {
          // Allow 1.5px: multi-line labels (AI Assistant) can differ by ~1px after
          // full-height hit-surface alignment without visual misalignment.
          expect(
            entry.value.bottom,
            closeTo(firstBottom, 1.5),
            reason: 'Label ${entry.key} bottom baseline must match precisely',
          );
          expect(
            entry.value.top,
            closeTo(firstTop, 1.5),
            reason: 'Label ${entry.key} top baseline must match precisely',
          );
        }
      },
    );
  }
}
