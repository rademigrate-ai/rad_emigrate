import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/core/routing/app_shell.dart';
import 'package:rad_emigrate/core/theme/app_theme.dart';
import 'package:rad_emigrate/core/widgets/rad_ai_bird_nav_icon.dart';
import 'package:rad_emigrate/core/widgets/rad_ai_bird.dart';
import 'package:rad_emigrate/features/admin/data/admin_operations_repository.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

Future<GoRouter> _pump(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Locale locale = const Locale('fa'),
  bool dark = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  tester.view.padding = const FakeViewPadding(bottom: 34);
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
            '/profile',
          ])
            GoRoute(path: path, builder: (_, _) => const SizedBox.expand()),
        ],
      ),
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
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('web semantics coordinates are not mirrored by HTML RTL direction', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('<html lang="fa" dir="rtl">'));
    expect(html, contains('flt-semantics-host{direction:ltr}'));
  });
  testWidgets('navigation lays out with active semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
  for (final locale in ['fa', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'Phoenix $locale ${dark ? 'dark' : 'light'} safe-area geometry',
        (tester) async {
          await _pump(tester, locale: Locale(locale), dark: dark);
          final surface = tester.getRect(
            find.byKey(const ValueKey('rad-phoenix-navigation-surface')),
          );
          final phoenix = tester.getRect(find.byType(RadAiBirdNavIcon));
          expect(surface.bottom, lessThanOrEqualTo(844 - 34 - 8));
          expect(phoenix.center.dx, closeTo(195, 0.1));
          expect(phoenix.width, greaterThan(100));
          final shapeFinder = find.descendant(
            of: find.byKey(const ValueKey('rad-phoenix-navigation-surface')),
            matching: find.byType(PhysicalShape),
          );
          final shape = tester.widget<PhysicalShape>(shapeFinder);
          final path = shape.clipper.getClip(tester.getSize(shapeFinder));
          expect(
            path.contains(Offset(surface.width / 2, 6)),
            isFalse,
            reason: 'The continuous capsule must not regain a center hump',
          );
          expect(path.contains(const Offset(50, 18)), isTrue);
          expect(path.contains(Offset(surface.width / 2, 18)), isTrue);
          final bird = tester.widget<RadAiBird>(
            find.descendant(
              of: find.byType(RadAiBirdNavIcon),
              matching: find.byType(RadAiBird),
            ),
          );
          expect(bird.showBackgroundOrb, isFalse);
          expect(
            bird.size,
            greaterThan(24 * 2),
            reason: 'The unframed bird remains larger than neighboring icons',
          );
          final home = tester.getCenter(
            find.text(locale == 'fa' ? 'خانه' : 'Home'),
          );
          final profile = tester.getCenter(
            find.text(locale == 'fa' ? 'پروفایل' : 'Profile'),
          );
          expect(home.dx > profile.dx, locale == 'fa');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('320px and 200% text remain usable without overflow', (
    tester,
  ) async {
    await _pump(tester, width: 320, scale: 2);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(RadAiBirdNavIcon)).width,
      greaterThanOrEqualTo(80),
    );
    await tester.tap(find.text('پروفایل'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark selected label retains readable red contrast', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('en'));
    final color = tester.widget<Text>(find.text('Home')).style!.color!;
    const surface = Color(0xFF242329);
    final contrast =
        (color.computeLuminance() + 0.05) / (surface.computeLuminance() + 0.05);
    expect(contrast, greaterThanOrEqualTo(4.5));
  });

  testWidgets('Phoenix keyboard activation and More shortcut work', (
    tester,
  ) async {
    final router = await _pump(tester, locale: const Locale('en'));
    final focus = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byType(RadAiBirdNavIcon),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    // Use the real focus node owned by the focusable action detector.
    final element = tester.element(
      find
          .descendant(
            of: find.byType(RadAiBirdNavIcon),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    Focus.of(element).requestFocus();
    await tester.pump();
    expect(focus.enabled, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/ai-assistant');
    // GoRouter correctly focuses the newly navigated page. Return focus to the
    // Phoenix before testing its contextual keyboard action.
    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byType(RadAiBirdNavIcon),
              matching: find.byType(GestureDetector),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
