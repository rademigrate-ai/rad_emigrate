import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/core/widgets/error_state.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/notifications/data/notification_reader.dart';
import 'package:rad_emigrate/features/notifications/presentation/pages/notifications_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

Widget _createTestApp({
  required Widget child,
  String? userId,
  NotificationReader? reader,
}) {
  return ProviderScope(
    overrides: [
      authenticatedUserIdProvider.overrideWithValue(userId),
      if (reader != null) notificationReaderProvider.overrideWithValue(reader),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );
}

void main() {
  group('NotificationsPage Acceptance Tests', () {
    testWidgets('unauthenticated visitor sees sign-in prompt', (tester) async {
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, state) => Scaffold(
              body: Text(
                'login-screen from=${state.uri.queryParameters['from']}',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authenticatedUserIdProvider.overrideWithValue(null)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('login-screen from=/notifications'), findsOneWidget);
    });

    testWidgets('displays empty state when user has no notifications', (
      tester,
    ) async {
      await tester.pumpWidget(
        _createTestApp(
          child: const NotificationsPage(),
          userId: 'user-empty',
          reader: (uid) async => [],
        ),
      );

      // Post-frame callback triggers load
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });

    testWidgets('renders list of notifications with unread indicators', (
      tester,
    ) async {
      final mockData = [
        {
          'id': 'notif-1',
          'type': 'status_update',
          'title': 'Visa Application Update',
          'body': 'Your Canada Express Entry application status changed to In Review.',
          'action_path': '/applications/ca-ee-1',
          'read_at': null, // unread
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'notif-2',
          'type': 'system',
          'title': 'Welcome to RAD Emigrate',
          'body':
              'Explore personalized pathways and consult licensed advisors.',
          'action_path': null,
          'read_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(), // read
          'created_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ];

      await tester.pumpWidget(
        _createTestApp(
          child: const NotificationsPage(),
          userId: 'user-with-items',
          reader: (uid) async => mockData,
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Visa Application Update'), findsOneWidget);
      expect(find.text('Welcome to RAD Emigrate'), findsOneWidget);
      expect(
        find.text(
          'Your Canada Express Entry application status changed to In Review.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays ErrorState with retry button when reader fails', (
      tester,
    ) async {
      int fetchCount = 0;
      await tester.pumpWidget(
        _createTestApp(
          child: const NotificationsPage(),
          userId: 'user-err',
          reader: (uid) async {
            fetchCount++;
            if (fetchCount == 1) {
              throw StateError('Simulated network error');
            }
            return [];
          },
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Could not load notifications.'), findsOneWidget);

      // Tap retry
      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();
      await tester.pumpAndSettle();

      // Successfully retrieved empty list
      expect(fetchCount, 2);
      expect(find.byType(EmptyState), findsOneWidget);
    });
  });
}
