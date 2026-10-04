import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/core/routing/app_shell.dart';
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

Future<void> _pumpShell(
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
          GoRoute(
            path: '/dashboard',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('Dashboard body'))),
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile More menu exposes every secondary destination', (
    tester,
  ) async {
    await _pumpShell(tester, role: 'admin', width: 360);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-admin mobile menu does not claim admin access', (
    tester,
  ) async {
    await _pumpShell(tester, role: 'user');

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Admin'), findsNothing);
    expect(find.text('AI Assistant'), findsOneWidget);
  });
}
